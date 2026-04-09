import 'package:flutter/material.dart';

class AppTheme {
  // ── Primary Blue ──────────────────────────────────────────────────────
  static const Color primary = Color(0xFF2979FF);
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color primaryDeep = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF82B1FF);
  static const Color primarySurface = Color(0xFF0A1628);

  // ── Backgrounds ───────────────────────────────────────────────────────
  static const Color bg = Color(0xFF07070F); // scaffold
  static const Color surface1 = Color(0xFF0D0D1A); // appbar / nav
  static const Color surface2 = Color(0xFF111125); // cards
  static const Color surface3 = Color(0xFF141428); // inputs
  static const Color surface4 = Color(0xFF181830); // elevated cards

  // ── Borders ───────────────────────────────────────────────────────────
  static const Color border = Color(0xFF1E1E38);
  static const Color borderLight = Color(0xFF252545);

  // ── Text ──────────────────────────────────────────────────────────────
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF8A8AAD);
  static const Color textMuted = Color(0xFF4A4A6A);

  // ── Semantic ──────────────────────────────────────────────────────────
  static const Color success = Color(0xFF00C853);
  static const Color error = Color(0xFFFF1744);
  static const Color warning = Color(0xFFFFAB00);

  // ── Gradients ─────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1565C0), Color(0xFF2979FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient avatarGradient = LinearGradient(
    colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Theme Data ────────────────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        primaryColor: primary,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: primaryLight,
          surface: surface2,
          error: error,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: surface1,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
            letterSpacing: 0.3,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? Colors.white : Colors.grey),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? primary.withOpacity(0.6)
                  : Colors.grey.withOpacity(0.3)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface3,
          labelStyle: TextStyle(color: textSecondary),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: border),
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: primary),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
}
