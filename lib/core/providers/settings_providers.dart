import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/enums/enums.dart';
import '../formatting/note_separator.dart';
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
    final current = state.value ?? SettingsService.defaultSettings();
    await _update(current.copyWith(themeMode: mode));
  }

  Future<void> setViewMode(ViewMode mode) async {
    final current = state.value ?? SettingsService.defaultSettings();
    await _update(current.copyWith(viewMode: mode));
  }

  Future<void> setLanguage(String code) async {
    final current = state.value ?? SettingsService.defaultSettings();
    await _update(
        current.copyWith(languageCode: resolveSupportedLanguageCode(code)));
  }

  /// Records (or clears) the hidden `reseller` flag. Ending the reseller
  /// session also drops the badge's reason to exist, but never forces the user
  /// out of the mode they are in.
  Future<void> setReseller(bool value) async {
    final current = state.value ?? SettingsService.defaultSettings();
    if (current.reseller == value) return;
    await _update(current.copyWith(reseller: value));
  }

  /// Leaves the reseller space for good: drops the hidden flag and returns to
  /// the clipboard space in a single write (never a half-signed-out state).
  Future<void> signOutReseller() async {
    final current = state.value ?? SettingsService.defaultSettings();
    await _update(
        current.copyWith(reseller: false, appMode: AppMode.clipboard));
  }

  Future<void> setAppMode(AppMode mode) async {
    final current = state.value ?? SettingsService.defaultSettings();
    if (current.appMode == mode) return;
    await _update(current.copyWith(appMode: mode));
  }

  Future<void> setNoteSeparator(String? separator) async {
    final current = state.value ?? SettingsService.defaultSettings();
    final value = NoteSeparator.normalize(separator);
    await _update(value == null || value.isEmpty
        ? current.copyWith(clearNoteSeparator: true)
        : current.copyWith(noteSeparator: value));
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
        SettingsController.new);

/// Convenience: current settings (defaults until loaded).
final settingsProvider = Provider<AppSettings>((ref) {
  return ref.watch(settingsControllerProvider).value ??
      SettingsService.defaultSettings();
});
