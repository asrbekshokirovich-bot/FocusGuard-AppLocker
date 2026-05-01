import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const String _themeKey = 'is_dark_mode';
  static const String _accentKey = 'accent_color';
  
  // ValueNotifiers allow the app to listen to changes
  final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
  final ValueNotifier<Color> accentColorNotifier = ValueNotifier(const Color(0xFF007AFF));

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Dark Mode
    final isDark = prefs.getBool(_themeKey) ?? false;
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    
    // Load Accent Color
    final colorValue = prefs.getInt(_accentKey) ?? 0xFF007AFF;
    accentColorNotifier.value = Color(colorValue);
  }

  bool get isDarkMode => themeNotifier.value == ThemeMode.dark;

  Future<void> toggleTheme(bool isDark) async {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
  }

  Future<void> setAccentColor(Color color) async {
    accentColorNotifier.value = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, color.value);
  }
}
