// lib/app/app.dart
//
// Root MaterialApp.router — wires theme + navigation + deep link listener.

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/providers/theme_provider.dart';
import 'router/router.dart';
import 'theme/premium_theme.dart';

class ResumePilotApp extends ConsumerStatefulWidget {
  const ResumePilotApp({super.key});

  @override
  ConsumerState<ResumePilotApp> createState() => _ResumePilotAppState();
}

class _ResumePilotAppState extends ConsumerState<ResumePilotApp> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    // 1. Cold-start: app was launched by tapping the link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleLink(initialUri);
      }
    } catch (_) {}

    // 2. Warm-start: app was already running
    _linkSub = _appLinks.uriLinkStream.listen(
      _handleLink,
      onError: (_) {},
    );
  }

  void _handleLink(Uri uri) {
    final router = ref.read(routerProvider);
    // Convert both resumepilot:// and https://resume-pilot.tech paths to GoRouter paths
    String? path;

    if (uri.scheme == 'resumepilot') {
      // resumepilot://app/auth/verify?token=...
      // resumepilot://app/auth/callback/github?code=...&state=...
      path = uri.path; // e.g. /auth/verify
      final query = uri.query.isNotEmpty ? '?${uri.query}' : '';
      path = '$path$query';
    } else if (uri.scheme == 'https' && uri.host == 'resume-pilot.tech') {
      // https://resume-pilot.tech/auth/verify?token=...
      path = uri.path;
      final query = uri.query.isNotEmpty ? '?${uri.query}' : '';
      path = '$path$query';
    }

    if (path != null) {
      router.go(path);
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
