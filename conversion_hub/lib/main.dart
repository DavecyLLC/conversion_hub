import 'package:flutter/material.dart';
import 'package:conversion_hub/app/home_shell.dart';
import 'package:conversion_hub/app/theme.dart';
import 'package:conversion_hub/state/app_state.dart';
import 'package:conversion_hub/state/models.dart';

void main() {
  final state = AppState(settings: const AppSettings());
  runApp(AppStateScope(notifier: state, child: const ConvertHubApp()));
}

class ConvertHubApp extends StatelessWidget {
  const ConvertHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return MaterialApp(
      title: 'Conversion Hub',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: state.settings.materialThemeMode,
      home: const HomeShell(),
    );
  }
}
