import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialise the video backend (libmpv) used by the in-app video preview.
  MediaKit.ensureInitialized();
  runApp(
    const ProviderScope(
      child: ClipboardApp(),
    ),
  );
}
