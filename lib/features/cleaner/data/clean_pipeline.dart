import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/clean_options.dart';
import '../domain/clean_report.dart';
import 'format_detector.dart';
import 'format_handler.dart';
import 'formats/avi_handler.dart';
import 'formats/gif_handler.dart';
import 'formats/iso_bmff_handler.dart';
import 'formats/jpeg_handler.dart';
import 'formats/matroska_handler.dart';
import 'formats/pdf/pdf_handler.dart';
import 'formats/png_handler.dart';
import 'formats/tiff_handler.dart';
import 'formats/webp_handler.dart';
import 'signature_scanner.dart';
import 'unsupported_content.dart';

/// detect → strip → re-scan, in one place. Synchronous-looking, isolate-free:
/// [MetadataCleanerService] runs it off the UI thread; tests call it directly.
class CleanPipeline {
  const CleanPipeline();

  static const _handlers = <MediaFormat, FormatHandler>{
    MediaFormat.jpeg: JpegHandler(),
    MediaFormat.png: PngHandler(),
    MediaFormat.webp: WebpHandler(),
    MediaFormat.gif: GifHandler(),
    MediaFormat.avi: AviHandler(),
    MediaFormat.isoVideo: IsoBmffHandler(),
    MediaFormat.heif: IsoBmffHandler(heif: true),
    MediaFormat.matroska: MatroskaHandler(),
    MediaFormat.pdf: PdfHandler(),
    MediaFormat.tiff: TiffHandler(),
  };

  static const _imageFormats = {
    MediaFormat.jpeg,
    MediaFormat.png,
    MediaFormat.webp,
    MediaFormat.gif,
    MediaFormat.heif,
    MediaFormat.pdf,
    MediaFormat.tiff,
  };

  static const _canonicalExt = {
    MediaFormat.jpeg: '.jpg',
    MediaFormat.png: '.png',
    MediaFormat.webp: '.webp',
    MediaFormat.gif: '.gif',
    MediaFormat.pdf: '.pdf',
  };

  Future<CleanReport> run(
    String sourcePath,
    Directory outputDir, [
    CleanOptions options = const CleanOptions(),
  ]) async {
    final source = File(sourcePath);
    MediaFormat format = MediaFormat.unknown;
    File? output;
    try {
      format = await FormatDetector.detect(source);

      if (format == MediaFormat.unknown) {
        return CleanReport(
            status: CleanStatus.unsupported,
            format: format,
            sourcePath: sourcePath);
      }
      final handler = _handlers[format]!;
      final ext = _canonicalExt[format] ?? p.extension(sourcePath);
      output = File(p.join(
        outputDir.path,
        '${p.basenameWithoutExtension(sourcePath)}_clean_'
        '${DateTime.now().microsecondsSinceEpoch}$ext',
      ));

      final stripped = await handler.sanitize(source, output, options);

      // Independent verification: re-parse the *output* and cross-check with a
      // byte-signature scan that shares no code with the handlers.
      final after = [...(await handler.scan(output, options)).findings];
      if (_imageFormats.contains(format)) {
        final bytes = await output.readAsBytes();
        for (final sig in SignatureScanner.scan(bytes)) {
          if (!after.any((f) => f.category == sig.category && f.sensitive)) {
            after.add(sig);
          }
        }
      }

      final residual = after.any((f) => f.sensitive);
      return CleanReport(
        status: residual
            ? CleanStatus.residualFound
            : stripped.caveats.isEmpty
                ? CleanStatus.verifiedClean
                : CleanStatus.cleanedWithCaveats,
        format: format,
        sourcePath: sourcePath,
        outputPath: output.path,
        before: stripped.findings,
        after: after,
        caveats: stripped.caveats,
      );
    } on UnsupportedContent catch (e) {
      await _discard(output);
      return CleanReport(
        status: CleanStatus.unsupported,
        format: format,
        sourcePath: sourcePath,
        errorMessage: e.message,
      );
    } on FormatException catch (e) {
      await _discard(output);
      return CleanReport(
        status: CleanStatus.failed,
        format: format,
        sourcePath: sourcePath,
        errorMessage: e.message,
      );
    } catch (e) {
      // I/O errors and out-of-range reads on malformed input alike.
      await _discard(output);
      return CleanReport(
        status: CleanStatus.failed,
        format: format,
        sourcePath: sourcePath,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _discard(File? file) async {
    try {
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {
      // Best effort: a stray temp file must not mask the original error.
    }
  }
}
