// lib/main.dart
//
// ResumePilot 2.0 — App entry point.
//
// Initialises:
//   • Hive cache store (offline GET cache)
//   • app_links listener (routes resumepilot:// deep links into GoRouter)
//   • Portrait-lock + transparent status bar

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'core/network/api_client.dart';
import 'core/notifications/notification_service.dart';

// Global navigator key — gives app_links access to GoRouter navigation
// without needing a BuildContext.
final _appLinks = AppLinks();

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar, light icons (dark mode)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialise Hive for offline cache
  await Hive.initFlutter();
  String cacheDir = '';
  if (!kIsWeb) {
    cacheDir = (await getApplicationDocumentsDirectory()).path;
  }

  // Initialize notifications
  await NotificationService().init();

  runApp(
    ProviderScope(
      overrides: [
        cacheDirProvider.overrideWithValue(cacheDir),
      ],
      child: const ResumePilotApp(),
    ),
  );
}
