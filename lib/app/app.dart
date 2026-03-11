import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/workspace/presentation/screens/main_workspace_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panasonic Projectors Manager',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const MainWorkspaceScreen(),
    );
  }
}
