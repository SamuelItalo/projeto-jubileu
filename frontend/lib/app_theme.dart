import 'package:flutter/material.dart';

abstract final class JubileuPalette {
  static const ink = Color(0xFF172119);
  static const forest = Color(0xFF123B35);
  static const forestSoft = Color(0xFFE6EEE9);
  static const gold = Color(0xFFB59255);
  static const ivory = Color(0xFFF7F5F0);
  static const paper = Color(0xFFFFFEFA);
  static const line = Color(0xFFE5E1D7);
}

abstract final class JubileuTheme {
  static ThemeData light() {
    final base = ThemeData.light();
    final text = base.textTheme
        .apply(
          fontFamily: 'Ubuntu',
          bodyColor: JubileuPalette.ink,
          displayColor: JubileuPalette.ink,
        )
        .copyWith(
          displaySmall: const TextStyle(
            fontSize: 46,
            height: 0.96,
            fontWeight: FontWeight.w300,
            letterSpacing: -1.4,
          ),
          headlineSmall: const TextStyle(
            fontSize: 28,
            height: 1.12,
            fontWeight: FontWeight.w300,
            letterSpacing: -0.7,
          ),
          titleLarge: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          labelLarge: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
          bodyMedium: const TextStyle(
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w300,
          ),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: JubileuPalette.forest,
        onPrimary: Colors.white,
        secondary: JubileuPalette.gold,
        surface: JubileuPalette.paper,
        onSurface: JubileuPalette.ink,
        outline: JubileuPalette.line,
      ),
      scaffoldBackgroundColor: JubileuPalette.ivory,
      textTheme: text,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: JubileuPalette.ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: JubileuPalette.paper,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: JubileuPalette.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.72),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: JubileuPalette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: JubileuPalette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: JubileuPalette.forest,
            width: 1.4,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Ubuntu',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class JubileuMark extends StatelessWidget {
  const JubileuMark({super.key, this.small = false});
  final bool small;

  @override
  Widget build(BuildContext context) => Container(
    width: small ? 34 : 52,
    height: small ? 34 : 52,
    decoration: BoxDecoration(
      color: JubileuPalette.forest,
      borderRadius: BorderRadius.circular(small ? 11 : 18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x20123B35),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Icon(
      Icons.auto_awesome_rounded,
      color: JubileuPalette.gold,
      size: small ? 18 : 26,
    ),
  );
}

class AppCanvas extends StatelessWidget {
  const AppCanvas({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFF9F7F2), JubileuPalette.ivory],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: child,
  );
}
