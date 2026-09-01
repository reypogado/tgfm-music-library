import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide light/dark preference, remembered across launches.
///
/// Starts on [ThemeMode.system] and settles onto the saved value once
/// SharedPreferences answers — the splash covers the swap.
class ThemeModeController extends StateNotifier<ThemeMode> {
  static const _kPrefKey = 'theme_mode';

  ThemeModeController() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      state = _decode(sp.getString(_kPrefKey));
    } catch (_) {
      // A missing or unreadable store just means "use the system setting".
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kPrefKey, mode.name);
    } catch (_) {
      // The choice still applies for this session.
    }
  }

  /// Cycles system -> light -> dark -> system, so one button covers all three.
  Future<void> cycle() {
    return set(switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    });
  }

  static ThemeMode _decode(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController();
});

const themeModeLabels = {
  ThemeMode.system: 'System theme',
  ThemeMode.light: 'Light',
  ThemeMode.dark: 'Dark',
};

const themeModeIcons = {
  ThemeMode.system: Icons.brightness_auto,
  ThemeMode.light: Icons.light_mode,
  ThemeMode.dark: Icons.dark_mode,
};
