import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = _parse(prefs.getString('blosab_theme'));
    notifyListeners();
  }

  ThemeMode _parse(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setTheme(String value) async {
    final normalized = value == 'light' || value == 'dark' ? value : 'system';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('blosab_theme', normalized);
    _themeMode = _parse(normalized);
    notifyListeners();
  }
}