import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/enums/enums.dart';

/// User preferences persisted between launches (theme, default view, language).
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.viewMode = ViewMode.grid,
    this.languageCode = 'fr',
  });

  final ThemeMode themeMode;
  final ViewMode viewMode;
  final String languageCode;

  AppSettings copyWith({
    ThemeMode? themeMode,
    ViewMode? viewMode,
    String? languageCode,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        viewMode: viewMode ?? this.viewMode,
        languageCode: languageCode ?? this.languageCode,
      );

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'viewMode': viewMode.name,
        'languageCode': languageCode,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == json['themeMode'],
          orElse: () => ThemeMode.system,
        ),
        viewMode: ViewMode.values.firstWhere(
          (v) => v.name == json['viewMode'],
          orElse: () => ViewMode.grid,
        ),
        languageCode: (json['languageCode'] as String?) ?? 'fr',
      );
}

/// Reads/writes [AppSettings] as JSON in the app support directory.
class SettingsService {
  static const _fileName = 'clipboard_settings.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<AppSettings> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const AppSettings();
      final data = jsonDecode(await file.readAsString());
      if (data is! Map<String, dynamic>) return const AppSettings();
      return AppSettings.fromJson(data);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(settings.toJson()));
  }
}
