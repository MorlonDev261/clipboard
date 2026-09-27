import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:super_clipboard/super_clipboard.dart';

/// Writes [text] and the readable [imagePaths] to the system clipboard.
///
/// The text and the first image share one clipboard item (so a single paste
/// gives text in text fields and the image in image fields); any further images
/// are added as extra items. Returns the number of images written (0 = text
/// only). Falls back to plain text where the rich clipboard is unavailable.
Future<int> copyNoteToClipboard(String text, List<String> imagePaths) async {
  final clipboard = SystemClipboard.instance;
  if (clipboard == null) {
    await Clipboard.setData(ClipboardData(text: text));
    return 0;
  }

  final images = <(SimpleFileFormat, Uint8List)>[];
  for (final path in imagePaths) {
    final format = _formatFor(path);
    if (format == null) continue; // unsupported image type
    try {
      images.add((format, await File(path).readAsBytes()));
    } catch (_) {
      // Skip unreadable/missing files.
    }
  }

  if (images.isEmpty) {
    if (text.isNotEmpty) {
      await clipboard.write([DataWriterItem()..add(Formats.plainText(text))]);
    } else {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
    return 0;
  }

  final items = <DataWriterItem>[];
  final first = DataWriterItem();
  if (text.isNotEmpty) first.add(Formats.plainText(text));
  first.add(images.first.$1(images.first.$2));
  items.add(first);
  for (final image in images.skip(1)) {
    items.add(DataWriterItem()..add(image.$1(image.$2)));
  }
  await clipboard.write(items);
  return images.length;
}

/// The clipboard image format for [path], or null if unsupported.
SimpleFileFormat? _formatFor(String path) {
  switch (p.extension(path).toLowerCase()) {
    case '.png':
      return Formats.png;
    case '.jpg':
    case '.jpeg':
      return Formats.jpeg;
    case '.gif':
      return Formats.gif;
    case '.webp':
      return Formats.webp;
    case '.bmp':
      return Formats.bmp;
    case '.tif':
    case '.tiff':
      return Formats.tiff;
    default:
      return null;
  }
}
