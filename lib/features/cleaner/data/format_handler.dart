import 'dart:io';
import 'dart:typed_data';

import '../domain/clean_options.dart';
import '../domain/clean_report.dart';
import 'unsupported_content.dart';

/// What a handler found while reading (scan) or stripping (sanitize) a file.
class HandlerResult {
  HandlerResult(this.findings, [Set<CleanCaveat>? caveats])
      : caveats = caveats ?? <CleanCaveat>{};

  final List<MetadataFinding> findings;
  final Set<CleanCaveat> caveats;
}

/// Largest file the in-memory handlers (images, PDF, TIFF) accept. Reading a
/// bigger one into RAM (input + output + copies) would crash a phone.
const maxInMemoryBytes = 160 * 1024 * 1024;

/// One container format. A handler classifies every element of the container
/// against an allowlist of structurally essential elements; everything else is
/// reported by [scan] and dropped by [sanitize]. Malformed input throws a
/// [FormatException]: we never emit a half-cleaned file.
abstract class FormatHandler {
  const FormatHandler();

  MediaFormat get format;

  /// Read-only: reports every non-essential element still present.
  Future<HandlerResult> scan(File file, CleanOptions options);

  /// Writes a stripped copy of [input] to [output].
  Future<HandlerResult> sanitize(
    File input,
    File output,
    CleanOptions options,
  );
}

/// Handlers for small, fully in-memory formats (images). Subclasses implement a
/// single [process] pass; with `out == null` it only reports.
abstract class ByteFormatHandler extends FormatHandler {
  const ByteFormatHandler();

  /// Parses [input]. When [out] is non-null the cleaned bytes are appended.
  /// Returns the non-essential elements found in [input].
  HandlerResult process(
      Uint8List input, CleanOptions options, BytesBuilder? out);

  @override
  Future<HandlerResult> scan(File file, CleanOptions options) async {
    await _checkSize(file);
    return process(await file.readAsBytes(), options, null);
  }

  Future<void> _checkSize(File file) async {
    if (await file.length() > maxInMemoryBytes) {
      throw const UnsupportedContent(
          'File too large to clean safely in memory (limit 160 MB)');
    }
  }

  @override
  Future<HandlerResult> sanitize(
    File input,
    File output,
    CleanOptions options,
  ) async {
    await _checkSize(input);
    final out = BytesBuilder(copy: false);
    final result = process(await input.readAsBytes(), options, out);
    await output.writeAsBytes(out.takeBytes(), flush: true);
    return result;
  }
}
