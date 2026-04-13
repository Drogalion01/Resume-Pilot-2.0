// lib/main.dart
//
// ResumePilot 2.0 — App entry point.
// Initialises Hive cache store, then mounts the ProviderScope.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'core/network/api_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait on phones
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialise Hive for offline cache
  await Hive.initFlutter();
  final cacheDir = (await getApplicationDocumentsDirectory()).path;

  runApp(
    ProviderScope(
      overrides: [
        cacheDirProvider.overrideWithValue(cacheDir),
      ],
      child: const ResumePilotApp(),
    ),
  );
}
