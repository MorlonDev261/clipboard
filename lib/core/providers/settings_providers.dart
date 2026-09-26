import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/enums/enums.dart';
import '../services/settings_service.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

/// Holds the persisted user preferences and exposes setters.
class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() {
    return ref.watch(settingsServiceProvider).load();
  }

  Future<void> _update(AppSettings settings) async {
    await ref.read(settingsServiceProvider).save(settings);
    state = AsyncData(settings);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final current = state.valueOrNull ?? const AppSettings();
    await _update(current.copyWith(themeMode: mode));
  }

  Future<void> setViewMode(ViewMode mode) async {
    final current = state.valueOrNull ?? const AppSettings();
    await _update(current.copyWith(viewMode: mode));
  }

  Future<void> setLanguage(String code) async {
    final current = state.valueOrNull ?? const AppSettings();
    await _update(current.copyWith(languageCode: code));
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
        SettingsController.new);

/// Convenience: current settings (defaults until loaded).
final settingsProvider = Provider<AppSettings>((ref) {
  return ref.watch(settingsControllerProvider).valueOrNull ??
      const AppSettings();
});
