import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../features/workspace/presentation/providers/app_settings_provider.dart';
import '../features/workspace/presentation/screens/main_workspace_screen.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appSettingsProvider.select((s) => s.themeMode));
    return MaterialApp(
      title: 'Projector Grid',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const MainWorkspaceScreen(),
    );
  }
}
