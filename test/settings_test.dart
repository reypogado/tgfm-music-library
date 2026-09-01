import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgfm_music_library/core/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('starts on the system theme', () {
    expect(ThemeModeController().state, ThemeMode.system);
  });

  test('cycles system -> light -> dark -> system', () async {
    final c = ThemeModeController();

    await c.cycle();
    expect(c.state, ThemeMode.light);
    await c.cycle();
    expect(c.state, ThemeMode.dark);
    await c.cycle();
    expect(c.state, ThemeMode.system);
  });

  test('the choice is remembered', () async {
    await ThemeModeController().set(ThemeMode.dark);

    final restored = ThemeModeController();
    await Future<void>.delayed(Duration.zero);

    expect(restored.state, ThemeMode.dark);
  });

  test('every mode has a label and an icon', () {
    for (final m in ThemeMode.values) {
      expect(themeModeLabels[m], isNotNull, reason: '$m');
      expect(themeModeIcons[m], isNotNull, reason: '$m');
    }
  });
}
