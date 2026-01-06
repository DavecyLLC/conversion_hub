import 'package:flutter/material.dart';

ThemeData buildLightTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B2A5B)),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );

  // Some Flutter versions use CardThemeData instead of CardTheme.
  // To keep this compatible, we just configure via copyWith + CardThemeData.
  return base.copyWith(
    cardTheme: const CardThemeData(
      elevation: 0.5,
      margin: EdgeInsets.zero,
    ),
  );
}

ThemeData buildDarkTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B2A5B),
      brightness: Brightness.dark,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );

  return base.copyWith(
    cardTheme: const CardThemeData(
      elevation: 0.5,
      margin: EdgeInsets.zero,
    ),
  );
}
