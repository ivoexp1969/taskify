import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

class SettingsState {
  final bool isDarkMode;
  final Locale locale;

  SettingsState({
    required this.isDarkMode,
    required this.locale,
  });
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier()
      : super(SettingsState(isDarkMode: false, locale: const Locale('en')));

  void toggleTheme() {
    state = SettingsState(isDarkMode: !state.isDarkMode, locale: state.locale);
  }

  void changeLocale(Locale locale) {
    state = SettingsState(isDarkMode: state.isDarkMode, locale: locale);
  }
}
