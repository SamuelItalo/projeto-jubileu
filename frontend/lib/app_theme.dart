import 'package:flutter/material.dart';

abstract final class JubileuPalette {
  static const canvas = Color(0xFF17171B);
  static const panel = Color(0xFF212126);
  static const panelRaised = Color(0xFF29292F);
  static const line = Color(0xFF37373F);
  static const ink = Color(0xFFF5F4F1);
  static const muted = Color(0xFFA5A4AD);
  static const mint = Color(0xFF70D7A5);
  static const lilac = Color(0xFFAFA8FF);
  static const cream = Color(0xFFFAF9F6);
  static const darkInk = Color(0xFF17171B);
}

abstract final class JubileuTheme {
  static ThemeData dark() {
    final base = ThemeData.dark();
    final text = base.textTheme
        .apply(
          fontFamily: 'Ubuntu',
          bodyColor: JubileuPalette.ink,
          displayColor: JubileuPalette.ink,
        )
        .copyWith(
          displaySmall: const TextStyle(
            fontSize: 42,
            height: 1,
            fontWeight: FontWeight.w300,
            letterSpacing: -1.1,
          ),
          headlineSmall: const TextStyle(
            fontSize: 27,
            height: 1.15,
            fontWeight: FontWeight.w300,
            letterSpacing: -0.6,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
          titleMedium: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          labelLarge: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
          bodyMedium: const TextStyle(
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w300,
          ),
          bodySmall: const TextStyle(
            fontSize: 11,
            height: 1.35,
            color: JubileuPalette.muted,
          ),
        );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: JubileuPalette.mint,
        onPrimary: JubileuPalette.darkInk,
        secondary: JubileuPalette.lilac,
        surface: JubileuPalette.panel,
        onSurface: JubileuPalette.ink,
        outline: JubileuPalette.line,
      ),
      scaffoldBackgroundColor: JubileuPalette.canvas,
      textTheme: text,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: JubileuPalette.ink,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: JubileuPalette.panel,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: JubileuPalette.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: JubileuPalette.panelRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: JubileuPalette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: JubileuPalette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: JubileuPalette.lilac, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Ubuntu',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  static ThemeData login(BuildContext context) => ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: JubileuPalette.darkInk,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: JubileuPalette.darkInk,
      outline: Color(0xFFE7E4DE),
    ),
    scaffoldBackgroundColor: JubileuPalette.cream,
    textTheme: ThemeData.light().textTheme
        .apply(
          fontFamily: 'Ubuntu',
          bodyColor: JubileuPalette.darkInk,
          displayColor: JubileuPalette.darkInk,
        )
        .copyWith(
          headlineSmall: const TextStyle(
            fontSize: 34,
            height: 1.05,
            fontWeight: FontWeight.w300,
            letterSpacing: -1.1,
          ),
        ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF7F6F3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE7E4DE)),
      ),
    ),
  );
}

class JubileuMark extends StatelessWidget {
  const JubileuMark({super.key, this.small = false});
  final bool small;
  @override
  Widget build(BuildContext context) => Container(
    width: small ? 30 : 46,
    height: small ? 30 : 46,
    decoration: BoxDecoration(
      color: JubileuPalette.ink,
      borderRadius: BorderRadius.circular(small ? 9 : 14),
    ),
    child: Icon(
      Icons.bolt_rounded,
      size: small ? 18 : 26,
      color: JubileuPalette.canvas,
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
        colors: [Color(0xFF1B1B20), JubileuPalette.canvas],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: child,
  );
}

class LoginIllustration extends StatelessWidget {
  const LoginIllustration({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 184,
    height: 126,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: 12,
          top: 38,
          child: _Orbit(
            icon: Icons.forum_outlined,
            color: JubileuPalette.lilac,
          ),
        ),
        Positioned(
          right: 12,
          top: 26,
          child: _Orbit(icon: Icons.check_rounded, color: JubileuPalette.mint),
        ),
        Positioned(
          right: 24,
          bottom: 8,
          child: _Orbit(
            icon: Icons.bar_chart_rounded,
            color: const Color(0xFFF2C779),
          ),
        ),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF4),
            borderRadius: BorderRadius.circular(26),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            size: 38,
            color: JubileuPalette.darkInk,
          ),
        ),
        const Positioned(
          top: 2,
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 15,
            color: JubileuPalette.lilac,
          ),
        ),
      ],
    ),
  );
}

class _Orbit extends StatelessWidget {
  const _Orbit({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 35,
    height: 35,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.6)),
    ),
    child: Icon(icon, size: 17, color: JubileuPalette.darkInk),
  );
}
