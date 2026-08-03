import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_store.dart';
import '../storage/storage_keys.dart';

/// Light / dark / follow-the-system, persisted across launches.
///
/// The app was pinned to `ThemeMode.light` even though a full dark theme was
/// already defined and `StorageKeys.themeMode` already reserved — so a rep on a
/// phone in dark mode got a white screen in an otherwise dark home screen, and
/// the messaging screens they compare against Zalo were the worst of it.
///
/// Defaults to [ThemeMode.system]: matching the phone is what every messaging
/// app does, and it costs the user no decision.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref
        .read(preferencesStoreProvider)
        .getString(StorageKeys.themeMode);

    return _decode(stored);
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref
        .read(preferencesStoreProvider)
        .setString(StorageKeys.themeMode, _encode(mode));
  }

  /// One tap cycles system → light → dark → system, for a single-button toggle.
  Future<void> cycle() => set(switch (state) {
    ThemeMode.system => ThemeMode.light,
    ThemeMode.light => ThemeMode.dark,
    ThemeMode.dark => ThemeMode.system,
  });

  static ThemeMode _decode(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String _encode(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

/// Label + icon for the current mode, so the toggle and the settings row cannot
/// describe it differently.
({String label, IconData icon}) themeModeDisplay(ThemeMode mode) =>
    switch (mode) {
      ThemeMode.system => (
        label: 'Theo hệ thống',
        icon: Icons.brightness_auto_rounded,
      ),
      ThemeMode.light => (label: 'Sáng', icon: Icons.light_mode_rounded),
      ThemeMode.dark => (label: 'Tối', icon: Icons.dark_mode_rounded),
    };
