import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  String    _language  = 'ar';
  String    _region    = 'SA';

  ThemeMode get themeMode => _themeMode;
  String    get language  => _language;
  String    get region    => _region;
  bool      get isArabic  => _language == 'ar';
  bool      get isDark    => _themeMode == ThemeMode.dark;
  bool      get isRTL     => _language == 'ar';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _themeMode = p.getBool('dark') == true ? ThemeMode.dark : ThemeMode.light;
    _language  = p.getString('lang')   ?? 'ar';
    _region    = p.getString('region') ?? 'SA';
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    final p = await SharedPreferences.getInstance();
    await p.setBool('dark', isDark);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    final p = await SharedPreferences.getInstance();
    await p.setString('lang', lang);
    notifyListeners();
  }

  Future<void> setRegion(String region) async {
    _region = region;
    final p = await SharedPreferences.getInstance();
    await p.setString('region', region);
    notifyListeners();
  }
}
