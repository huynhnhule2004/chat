import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  bool _isDarkMode = false;
  bool _isInitialized = false;

  bool get isDarkMode => _isDarkMode;
  bool get isInitialized => _isInitialized;

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_themeKey) ?? false;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('Error loading theme preference: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDarkMode);
    } catch (e) {
      print('Error saving theme preference: $e');
    }
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    
    _isDarkMode = value;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, value);
    } catch (e) {
      print('Error saving theme preference: $e');
    }
  }

  // Light Theme
  ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    primaryColor: Colors.blue,
    scaffoldBackgroundColor: Colors.white,
    
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    
    cardColor: Colors.white,
    
    colorScheme: ColorScheme.light(
      primary: Colors.blue,
      secondary: Colors.blueAccent,
      surface: Colors.white,
      background: Colors.grey[100]!,
      error: Colors.red,
    ),
    
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black54),
    ),
  );

  // Dark Theme
  ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primarySwatch: Colors.blue,
    primaryColor: Colors.blue[700],
    scaffoldBackgroundColor: const Color(0xFF121212),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    
    cardColor: const Color(0xFF1E1E1E),
    
    colorScheme: ColorScheme.dark(
      primary: Colors.blue[700]!,
      secondary: Colors.blue[400]!,
      surface: const Color(0xFF1E1E1E),
      background: const Color(0xFF121212),
      error: Colors.red[400]!,
    ),
    
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
    ),
  );
}
