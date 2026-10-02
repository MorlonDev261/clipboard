import 'dart:io';
import 'dart:isolate';

import 'package:path_provider/path_provider.dart';

import '../data/clean_pipeline.dart';
import '../data/stale_copies.dart';
import '../domain/clean_options.dart';
import '../domain/clean_report.dart';

/// Cleans a media file off the UI thread and returns a verified [CleanReport].
/// The original file is never modified; the cleaned copy lives in the temp
/// directory until the UI saves or discards it.
class MetadataCleanerService {
  const MetadataCleanerService();

  Future<CleanReport> clean(
    String sourcePath, {
    CleanOptions options = const CleanOptions(),
  }) async {
    // path_provider uses platform channels: resolve it on the main isolate.
    final dir = await getTemporaryDirectory();
    final outPath = dir.path;
    return Isolate.run(
      () => const CleanPipeline().run(sourcePath, Directory(outPath), options),
    );
  }

  /// Removes cleaned copies left in the temp folder by a previous run that was
  /// killed before the user saved or discarded them.
  Future<int> purgeStaleCopies() async =>
      purgeStaleCleanCopies(await getTemporaryDirectory());
}
