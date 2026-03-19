import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, eyecare }

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _mode = AppThemeMode.light;
  AppThemeMode get mode => _mode;

  ThemeProvider() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('themeMode') ?? 0;
    _mode = AppThemeMode.values[idx.clamp(0, 2)];
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
  }

  ThemeData get themeData {
    switch (_mode) {
      case AppThemeMode.light:
        return ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF007AFF), brightness: Brightness.light),
          scaffoldBackgroundColor: const Color(0xFFF2F2F7),
          useMaterial3: true,
          brightness: Brightness.light,
        );
      case AppThemeMode.dark:
        return ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF007AFF), brightness: Brightness.dark),
          scaffoldBackgroundColor: const Color(0xFF1C1C1E),
          useMaterial3: true,
          brightness: Brightness.dark,
        );
      case AppThemeMode.eyecare:
        return ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B7355), brightness: Brightness.light),
          scaffoldBackgroundColor: const Color(0xFFF5ECD7), // 暖黄护眼
          useMaterial3: true,
          brightness: Brightness.light,
          cardColor: const Color(0xFFFFF8E7),
        );
    }
  }
}
