import 'package:flutter/material.dart';

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0B2A5B),
    secondary: const Color(0xFFFF7A00),
    brightness: Brightness.light,
  );
  return ThemeData(useMaterial3: true, colorScheme: scheme);
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0B2A5B),
    secondary: const Color(0xFFFF7A00),
    brightness: Brightness.dark,
  );
  return ThemeData(useMaterial3: true, colorScheme: scheme);
}
