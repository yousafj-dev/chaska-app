import 'package:flutter/material.dart';

/// Chaska dark theme — TikTok-style: near-black background,
/// white text, hot-pink accent.
class AppTheme {
  AppTheme._();

  static const Color bg = Color(0xFF0B0B10);
  static const Color card = Color(0xFF16161D);
  static const Color accent = Color(0xFFFF2D55); // chaska pink
  static const Color accent2 = Color(0xFF25F4EE); // cyan pop
  static const Color muted = Color(0xFF9A9AA5);

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: accent,
      secondary: accent2,
      surface: card,
      background: bg,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        hintStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bg,
        selectedItemColor: Colors.white,
        unselectedItemColor: muted,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
