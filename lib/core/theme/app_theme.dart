import 'package:flutter/material.dart';

/// Chaska dark theme — deep purple-black background, white text,
/// violet primary accent with a coral-pink pop. Gradients built from
/// [accent] → [accent2] give the violet-to-coral look used on the
/// splash and the centre upload button.
class AppTheme {
  AppTheme._();

  static const Color bg = Color(0xFF0D0A14);
  static const Color card = Color(0xFF1A1428);
  static const Color accent = Color(0xFF7C4DFF); // violet
  static const Color accent2 = Color(0xFFFF5C8A); // coral pink
  static const Color muted = Color(0xFF9E97B0);

  /// Primary violet → coral gradient.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accent, accent2],
  );

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: accent,
      secondary: accent2,
      surface: card,
      background: bg,
    );
    return ThemeData(
      useMaterial3: true,
      // Pin the clean default sans explicitly. Without this the app
      // inherits whatever font the phone's system theme uses, which on
      // some devices is an italic script font that looks unprofessional.
      fontFamily: 'Roboto',
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
