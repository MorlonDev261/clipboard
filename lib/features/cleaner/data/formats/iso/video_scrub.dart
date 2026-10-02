import 'dart:io';
import 'dart:typed_data';

import 'sample_table.dart';

enum VideoCodec { avc, hevc }

/// The samples of one H.264 / HEVC track.
class VideoTarget {
  VideoTarget(this.codec, this.lengthSize, this.samples);

  final VideoCodec codec;

  /// Size in bytes of the NAL length prefix (from avcC / hvcC).
  final int lengthSize;
  final List<ByteRange> samples;
}

/// Neutralises "user data unregistered" SEI messages — where x264 and friends
/// write their full encoder name and settings — without changing a single
/// offset: the SEI NAL unit is turned into a *filler data* NAL of the same
/// length (type 12 for H.264, 38 for HEVC; body 0xFF…, trailing 0x80), which
/// every decoder ignores. SEI NALs that also carry other messages (HDR
/// mastering display, timing…) are left alone, as they affect playback.
class VideoScrub {
  const VideoScrub._();

  static const _maxNal = 16 * 1024;
  static const _window = 8192;

  /// Returns how many SEI NALs were found. With [write] they are overwritten
  /// in place; [map] converts source offsets to offsets in [raf].
  static Future<int> run(
    RandomAccessFile raf,
    List<VideoTarget> targets,
    int Function(int) map, {
    required bool write,
    List<String>? texts,
  }) async {
    var found = 0;
    for (final t in targets) {
      for (final s in t.samples) {
        if (s.length < t.lengthSize + 2) continue;
        final base = map(s.offset);
        final n = s.length < _window ? s.length : _window;
        await raf.setPosition(base);
        final buf = await raf.read(n);
        if (buf.length < n) continue;
        var pos = 0;
        var dirty = false;
        while (pos + t.lengthSize + 2 <= buf.length) {
          var len = 0;
          for (var i = 0; i < t.lengthSize; i++) {
            len = (len << 8) | buf[pos + i];
          }
          final start = pos + t.lengthSize;
          final end = start + len;
          if (len < 2 || end > buf.length) break;
          final type = t.codec == VideoCodec.avc
              ? buf[start] & 0x1F
              : (buf[start] >> 1) & 0x3F;
          final isVcl =
              t.codec == VideoCodec.avc ? type >= 1 && type <= 5 : type < 32;
          if (isVcl) break;
          final isSei = t.codec == VideoCodec.avc ? type == 6 : type == 39;
          if (isSei && len <= _maxNal) {
            final header = t.codec == VideoCodec.avc ? 1 : 2;
            final text = _userDataText(buf, start + header, end);
            if (text != null) {
              found++;
              texts?.add(text);
              if (write) {
                if (t.codec == VideoCodec.avc) {
                  buf[start] = (buf[start] & 0xE0) | 12;
                } else {
                  buf[start] = (38 << 1) | (buf[start] & 1);
                }
                buf.fillRange(start + header, end - 1, 0xFF);
                buf[end - 1] = 0x80;
                dirty = true;
              }
            }
          }
          pos = end;
        }
        if (dirty) {
          await raf.setPosition(base);
          await raf.writeFrom(buf);
        }
      }
    }
    return found;
  }

  /// The printable text of the SEI when its payload consists solely of
  /// user_data_unregistered (payloadType 5) messages; `null` otherwise.
  static String? _userDataText(Uint8List b, int start, int end) {
    // Undo emulation prevention (00 00 03 → 00 00) to read payload sizes.
    final r = <int>[];
    var zeros = 0;
    for (var i = start; i < end; i++) {
      final v = b[i];
      if (zeros >= 2 && v == 3) {
        zeros = 0;
        continue;
      }
      zeros = v == 0 ? zeros + 1 : 0;
      r.add(v);
    }
    var i = 0;
    var any = false;
    final text = StringBuffer();
    while (i < r.length && !(i == r.length - 1 && r[i] == 0x80)) {
      var type = 0;
      while (i < r.length && r[i] == 0xFF) {
        type += 255;
        i++;
      }
      if (i >= r.length) return null;
      type += r[i++];
      var size = 0;
      while (i < r.length && r[i] == 0xFF) {
        size += 255;
        i++;
      }
      if (i >= r.length) return null;
      size += r[i++];
      if (type != 5 || i + size > r.length) return null;
      any = true;
      // 16-byte UUID, then the free-form payload (x264 puts its settings here).
      for (var k = i + 16; k < i + size && text.length < 160; k++) {
        final c = r[k];
        text.writeCharCode(c >= 32 && c < 127 ? c : 0x20);
      }
      i += size;
    }
    return any ? text.toString().replaceAll(RegExp(r' +'), ' ').trim() : null;
  }
}
