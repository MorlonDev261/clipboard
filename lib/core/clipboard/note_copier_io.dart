import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:super_clipboard/super_clipboard.dart';

typedef _Image = ({String name, SimpleFileFormat format, Uint8List bytes});

/// Writes [text] and the readable [imagePaths] to the system clipboard.
///
/// Each image becomes its own clipboard item with a suggested file name, so it
/// pastes as an actual **file** (into a file manager, chat, etc.), not just as
/// an in-memory image. The text rides on the first item as an extra
/// representation, so a single paste gives the text in text fields and the
/// image/file elsewhere. Returns the number of images written (0 = text only).
Future<int> copyNoteToClipboard(String text, List<String> imagePaths) async {
  final clipboard = SystemClipboard.instance;
  if (clipboard == null) {
    await Clipboard.setData(ClipboardData(text: text));
    return 0;
  }

  final images = <_Image>[];
  for (final path in imagePaths) {
    final format = _formatFor(path);
    if (format == null) continue; // unsupported image type
    try {
      images.add((
        name: p.basename(path),
        format: format,
        bytes: await File(path).readAsBytes(),
      ));
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
  final firstImage = images.first;
  // suggestedName makes the receiving app treat the image data as a file.
  final first = DataWriterItem(suggestedName: firstImage.name);
  // HTML with the caption + every image inlined, so a single paste into an
  // HTML-aware composer (many social/web editors, Gmail, Docs…) inserts the
  // note together with its images.
  first.add(Formats.htmlText(_buildHtml(text, images)));
  if (text.isNotEmpty) first.add(Formats.plainText(text));
  first.add(firstImage.format(firstImage.bytes));
  items.add(first);
  for (final image in images.skip(1)) {
    items.add(
      DataWriterItem(suggestedName: image.name)..add(image.format(image.bytes)),
    );
  }
  await clipboard.write(items);
  return images.length;
}

/// Builds an HTML fragment: the caption (line breaks preserved) followed by
/// each image inlined as a base64 data URI.
String _buildHtml(String text, List<_Image> images) {
  final sb = StringBuffer();
  if (text.isNotEmpty) {
    sb.write('<div>${_escapeHtml(text).replaceAll('\n', '<br>')}</div>');
  }
  for (final image in images) {
    final data = base64Encode(image.bytes);
    sb.write('<div><img src="data:${_mime(image.name)};base64,$data"></div>');
  }
  return sb.toString();
}

String _escapeHtml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _mime(String name) {
  switch (p.extension(name).toLowerCase()) {
    case '.png':
      return 'image/png';
    case '.gif':
      return 'image/gif';
    case '.webp':
      return 'image/webp';
    case '.bmp':
      return 'image/bmp';
    case '.tif':
    case '.tiff':
      return 'image/tiff';
    default:
      return 'image/jpeg';
  }
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
