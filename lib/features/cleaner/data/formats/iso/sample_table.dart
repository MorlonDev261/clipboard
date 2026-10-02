import '../../binary.dart';
import 'iso_node.dart';

class ByteRange {
  const ByteRange(this.offset, this.length);

  final int offset;
  final int length;
}

/// Resolves a track's `stsz` / `stsc` / `stco|co64` into absolute byte ranges
/// inside `mdat`, which is what lets us blank the payload of a dropped track
/// and walk the first NAL units of video samples.
class SampleTable {
  const SampleTable._();

  /// ~55 h of 100 fps video. Anything above is treated as corrupt.
  static const maxSamples = 20 * 1000 * 1000;

  /// One range per sample.
  static List<ByteRange> samples(List<IsoNode> stbl) {
    final stsz = IsoNode.find(stbl, 'stsz')?.data;
    final stsc = IsoNode.find(stbl, 'stsc')?.data;
    final offsets = (IsoNode.find(stbl, 'co64') ?? IsoNode.find(stbl, 'stco'));
    if (IsoNode.find(stbl, 'stz2') != null) {
      throw const FormatException('Compact sample sizes (stz2) unsupported');
    }
    if (stsz == null || stsc == null || offsets == null) {
      throw const FormatException('Incomplete sample table');
    }
    if (stsz.length < 12 || stsc.length < 8 || offsets.data!.length < 8) {
      throw const FormatException('Corrupt sample table');
    }
    final fixed = u32be(stsz, 4);
    final count = u32be(stsz, 8);
    if (fixed == 0 && 12 + 4 * count > stsz.length) {
      throw const FormatException('Corrupt stsz');
    }
    // A crafted file can claim billions of samples; refuse instead of
    // allocating them (memory / CPU denial of service).
    if (u32be(stsz, 8) > maxSamples) {
      throw const FormatException('Implausible sample count');
    }
    final runs = u32be(stsc, 4);
    if (8 + 12 * runs > stsc.length) {
      throw const FormatException('Corrupt stsc');
    }
    final wide = offsets.type == 'co64';
    final od = offsets.data!;
    final chunks = u32be(od, 4);
    final step = wide ? 8 : 4;
    if (8 + chunks * step > od.length) {
      throw const FormatException('Corrupt chunk offsets');
    }

    final out = <ByteRange>[];
    var sample = 0;
    var run = 0;
    for (var c = 0; c < chunks && sample < count; c++) {
      while (run + 1 < runs && u32be(stsc, 8 + 12 * (run + 1)) <= c + 1) {
        run++;
      }
      final perChunk = runs == 0 ? 0 : u32be(stsc, 8 + 12 * run + 4);
      var off = wide ? u64be(od, 8 + c * 8) : u32be(od, 8 + c * 4);
      for (var k = 0; k < perChunk && sample < count; k++, sample++) {
        final size = fixed != 0 ? fixed : u32be(stsz, 12 + 4 * sample);
        out.add(ByteRange(off, size));
        off += size;
      }
    }
    return out;
  }

  /// Samples merged into contiguous runs (one per chunk, typically).
  static List<ByteRange> merged(List<IsoNode> stbl) {
    final out = <ByteRange>[];
    for (final s in samples(stbl)) {
      if (s.length == 0) continue;
      if (out.isNotEmpty && out.last.offset + out.last.length == s.offset) {
        out[out.length - 1] =
            ByteRange(out.last.offset, out.last.length + s.length);
      } else {
        out.add(s);
      }
    }
    return out;
  }
}
