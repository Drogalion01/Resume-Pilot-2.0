// lib/app/app.dart
//
// Root MaterialApp.router — wires theme + navigation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/providers/theme_provider.dart';
import 'router/router.dart';
import 'theme/premium_theme.dart';

class ResumePilotApp extends ConsumerWidget {
  const ResumePilotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'ResumePilot',
      debugShowCheckedModeBanner: false,
      theme: PremiumTheme.lightMode,
      darkTheme: PremiumTheme.darkMode,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
