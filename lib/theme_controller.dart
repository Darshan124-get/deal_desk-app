import 'package:flutter/material.dart';
import 'data/db_helper.dart';
import 'models/app_settings.dart';

class ThemeController extends ChangeNotifier {
  bool _isDark = false;
  bool _isLoaded = false;

  bool get isDark => _isDark;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    final db = DbHelper();
    final settings = await db.fetchSettings();
    _isDark = settings.darkMode;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDark = !_isDark;
    final db = DbHelper();
    final settings = await db.fetchSettings();
    final newSettings = settings.copyWith(darkMode: _isDark);
    await db.saveSettings(newSettings);
    notifyListeners();
  }
}
