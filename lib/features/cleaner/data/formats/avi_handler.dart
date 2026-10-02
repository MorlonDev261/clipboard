import 'dart:typed_data';

import '../../domain/clean_options.dart';
import '../../domain/clean_report.dart';
import '../binary.dart';
import '../format_handler.dart';

/// AVI (RIFF): removes the top-level `LIST INFO` (title, software, creation
/// date…) and `IDIT` date stamps. `idx1` offsets are relative to `movi`, so
/// dropping chunks that precede it keeps the index valid.
class AviHandler extends ByteFormatHandler {
  const AviHandler();

  @override
  MediaFormat get format => MediaFormat.avi;

  @override
  HandlerResult process(
    Uint8List b,
    CleanOptions options,
    BytesBuilder? out,
  ) {
    if (b.length < 12 ||
        !startsWithAscii(b, 0, 'RIFF') ||
        !startsWithAscii(b, 8, 'AVI ')) {
      throw const FormatException('Not an AVI');
    }
    final declared = u32le(b, 4) + 8;
    final fileEnd = declared < b.length ? declared : b.length;
    final findings = <MetadataFinding>[];
    final body = BytesBuilder(copy: false);
    var offset = 12;
    while (offset + 8 <= fileEnd) {
      final id = fourcc(b, offset);
      final size = u32le(b, offset + 4);
      final end = offset + 8 + size + (size.isOdd ? 1 : 0);
      if (offset + 8 + size > fileEnd) {
        throw const FormatException('Truncated AVI');
      }
      final isInfo =
          id == 'LIST' && size >= 4 && startsWithAscii(b, offset + 8, 'INFO');
      if (isInfo || id == 'IDIT') {
        findings.add(MetadataFinding(
          isInfo ? MetadataCategory.container : MetadataCategory.dateTime,
          isInfo ? 'LIST INFO' : 'IDIT',
          bytes: end - offset,
          entries: isInfo
              ? _infoEntries(b, offset + 12, offset + 8 + size)
              : [
                  MetadataEntry(
                      'IDIT', latin1Text(b, offset + 8, offset + 8 + size))
                ],
        ));
      } else {
        body.add(b.sublist(offset, end > fileEnd ? fileEnd : end));
      }
      offset = end;
    }
    if (out != null) {
      final payload = body.takeBytes();
      out
        ..add(ascii4('RIFF'))
        ..add(le32(payload.length + 4))
        ..add(ascii4('AVI '))
        ..add(payload);
    }
    return HandlerResult(findings);
  }

  /// Sub-chunks of a `LIST INFO` (INAM title, ISFT software, ICRD date…).
  static List<MetadataEntry> _infoEntries(Uint8List b, int from, int end) {
    const names = {
      'INAM': 'Title',
      'IART': 'Artist',
      'ISFT': 'Software',
      'ICRD': 'Creation date',
      'ICMT': 'Comment',
      'ICOP': 'Copyright',
      'IGNR': 'Genre',
      'ISRC': 'Source',
      'IENG': 'Engineer',
    };
    final out = <MetadataEntry>[];
    var o = from;
    while (o + 8 <= end && out.length < 20) {
      final id = fourcc(b, o);
      final size = u32le(b, o + 4);
      final dataEnd = o + 8 + size;
      if (dataEnd > end) break;
      out.add(MetadataEntry(names[id] ?? id, latin1Text(b, o + 8, dataEnd)));
      o = dataEnd + (size.isOdd ? 1 : 0);
    }
    return out;
  }
}
