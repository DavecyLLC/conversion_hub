import 'package:flutter/material.dart';

/// App-wide theme choice.
enum AppThemeMode {
  system,
  light,
  dark,
}

/// Immutable app settings model.
/// This file must contain NO UI widgets.
class AppSettings {
  final int decimals;
  final String defaultLengthUnit;
  final bool haptics;
  final bool scientific;
  final AppThemeMode themeMode;

  const AppSettings({
    this.decimals = 4,
    this.defaultLengthUnit = 'mm',
    this.haptics = true,
    this.scientific = false,
    this.themeMode = AppThemeMode.system,
  });

  AppSettings copyWith({
    int? decimals,
    String? defaultLengthUnit,
    bool? haptics,
    bool? scientific,
    AppThemeMode? themeMode,
  }) {
    return AppSettings(
      decimals: decimals ?? this.decimals,
      defaultLengthUnit: defaultLengthUnit ?? this.defaultLengthUnit,
      haptics: haptics ?? this.haptics,
      scientific: scientific ?? this.scientific,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  /// Convert app theme to Flutter [ThemeMode]
  ThemeMode get materialThemeMode {
    switch (themeMode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }
}

/// What gets stored in "Recents"
class HistoryItem {
  final String toolId;
  final DateTime at;
  final String summary;
  final String copyText;

  const HistoryItem({
    required this.toolId,
    required this.at,
    required this.summary,
    required this.copyText,
  });
}
