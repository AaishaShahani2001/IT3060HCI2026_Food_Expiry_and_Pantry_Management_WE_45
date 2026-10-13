import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String themeModeStorageKey = 'theme_mode';

const String themeModeSystemValue = 'system';
const String themeModeLightValue = 'light';
const String themeModeDarkValue = 'dark';

/// Overridden in `main()` with a preloaded instance to avoid a theme flash.
/// Tests may leave this null; the app then stays on [ThemeMode.system].
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return themeModeFromStorage(prefs?.getString(themeModeStorageKey));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) return;

    state = mode;
    await ref
        .read(sharedPreferencesProvider)
        ?.setString(themeModeStorageKey, themeModeToStorage(mode));
  }
}

ThemeMode themeModeFromStorage(String? value) {
  switch (value) {
    case themeModeLightValue:
      return ThemeMode.light;
    case themeModeDarkValue:
      return ThemeMode.dark;
    case themeModeSystemValue:
    default:
      return ThemeMode.system;
  }
}

String themeModeToStorage(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return themeModeLightValue;
    case ThemeMode.dark:
      return themeModeDarkValue;
    case ThemeMode.system:
      return themeModeSystemValue;
  }
}
