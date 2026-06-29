// lib/core/auth/auth_notifier.dart
//
// Riverpod notifier managing the full passwordless authentication lifecycle.
//
//  Flows supported:
//   • Magic Link  — sendMagicLink() → verifyMagicLink(token)
//   • OAuth PKCE  — oauthAuthorize(provider) → oauthCallback(provider,code,state)
//   • TOTP        — verifyTotp(mfaToken, code)   [optional 2FA]
//   • Session     — restores on cold start, silent refresh via Dio interceptor
//   • Logout      — revokes refresh token + clears secure storage

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';
import '../models/user_model.dart';
import '../network/api_client.dart';
import '../storage/token_storage.dart';
import 'auth_state.dart';
// Conditional import: dart:html is only available on the web platform.
// On mobile/desktop this resolves to a no-op stub.
import '../web/html_stub.dart'
    if (dart.library.html) 'dart:html' as html;

// ── Provider ───────────────────────────────────────────────────────────────────

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuthNotifier(client: client);
});

// ── Notifier ───────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _client;
  // Use platform-adaptive storage: localStorage on web, SecureStorage on native.
  // See lib/core/storage/token_storage.dart for why we avoid flutter_secure_storage on web.
  final _storage = tokenStorage;

  AuthNotifier({required ApiClient client})
      : _client = client,
        super(const AuthStateInitial()) {
    _restoreSession();
  }

  // ── Session restoration ──────────────────────────────────────────────────────

  Future<void> _restoreSession() async {
    state = const AuthStateLoading();
    try {
      final token = await _storage.read(key: AppConstants.accessTokenKey);
      final userJson = await _storage.read(key: AppConstants.userKey);

      if (token != null && userJson != null) {
        final user = UserModel.fromJson(
          Map<String, dynamic>.from(
              const JsonDecoder().convert(userJson) as Map),
        );
        _client.setToken(token);
        state = AuthStateAuthenticated(token: token, user: user);
      } else {
        state = const AuthStateUnauthenticated();
      }
    } catch (_) {
      state = const AuthStateUnauthenticated();
    }
  }

  // ── Magic Link ───────────────────────────────────────────────────────────────

  /// Step 1: Send magic link email.
  Future<void> sendMagicLink(String email) async {
    state = const AuthStateLoading();
    try {
      await _client.dio.post(
        '/auth/magic-link/send',
        data: {'email': email},
      );
      state = AuthStateMagicLinkSent(email: email);
    } on DioException catch (e) {
      state = AuthStateError(
          message: _extractError(e, 'Failed to send magic link'));
    }
  }

  String? _verifyingToken;

  /// Step 2: Called from deep link — verifies token with backend.
  Future<void> verifyMagicLink(String token) async {
    if (state is AuthStateAuthenticated) return; // Already logged in
    if (_verifyingToken == token) return; // Prevent double verification
    _verifyingToken = token;

    state = const AuthStateLoading();
    try {
      // Token must go in the JSON body — backend reads MagicLinkVerifyRequest {token}
      final res = await _client.dio.post(
        '/auth/magic-link/verify',
        data: {'token': token},
      );
      _handleAuthResponse(res.data as Map<String, dynamic>);
      // Do NOT clear _verifyingToken on success to prevent remount race conditions
    } on DioException catch (e) {
      _verifyingToken = null;
      state = AuthStateError(
          message: _extractError(e, 'Invalid or expired magic link'));
    }
  }

  // ── OAuth PKCE ───────────────────────────────────────────────────────────────

  /// Opens the provider OAuth page in a secure in-app browser,
  /// then posts the code + state to backend.
  Future<void> oauthAuthorize(String provider) async {
    state = const AuthStateLoading();
    try {
      // 1. Get the authorization URL from backend
      // Note: We ALWAYS use the https web domain for OAuth callbacks because 
      // providers (GitHub, LinkedIn) do not allow custom schemes like resumepilot://.
      // The Android App intercepts the https://resume-pilot.tech URL via intent-filters.
      final String redirectUri = kIsWeb
          ? '${Uri.base.origin}/auth/callback/$provider'
          : 'https://resume-pilot.tech/auth/callback/$provider';

      final res = await _client.dio.get(
        '/auth/oauth/$provider/authorize',
        queryParameters: {
          'redirect_uri': redirectUri,
        },
      );
      final data = res.data as Map<String, dynamic>;
      final authUrl = data['authorization_url'] as String;
      final expectedState = data['state'] as String;

      if (kIsWeb) {
        // Open OAuth in a popup so the app state is preserved in the main tab.
        // auth.html on the callback URL posts the result via BroadcastChannel.
        final callbackUrl = '${Uri.base.origin}/auth/callback/$provider';
        final popupUrl = authUrl;

        // Open popup window
        await launchUrl(
          Uri.parse(popupUrl),
          webOnlyWindowName: '_blank',
        );

        // Listen for the callback message via BroadcastChannel
        state = AuthStateLoading();
        try {
          // Poll for BroadcastChannel message using dart:html
          // ignore: avoid_web_libraries_in_flutter
          final result = await _waitForOAuthPopupResult(provider);
          if (result == null) {
            state = const AuthStateError(message: 'OAuth popup was closed without completing sign-in');
            return;
          }
          final uri = Uri.parse(result);
          final code = uri.queryParameters['code'];
          final returnedState = uri.queryParameters['state'];
          if (code == null || code.isEmpty) {
            state = const AuthStateError(message: 'OAuth cancelled or failed');
            return;
          }
          final callbackRes = await _client.dio.post(
            '/auth/oauth/$provider/callback',
            data: {
              'code': code,
              'state': returnedState ?? '',
              'redirect_uri': callbackUrl,
            },
          );
          _handleAuthResponse(callbackRes.data as Map<String, dynamic>);
        } on DioException catch (e) {
          state = AuthStateError(message: _extractError(e, 'OAuth sign-in failed'));
        } catch (e) {
          state = AuthStateError(message: 'OAuth sign-in failed: $e');
        }
        return;
      }

      // 2. Open in-app browser (flutter_web_auth_2 — PKCE safe)
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: 'resumepilot',
      );

      // 3. Parse callback URL
      final uri = Uri.parse(result);
      final code = uri.queryParameters['code'];
      final returnedState = uri.queryParameters['state'];

      if (code == null) {
        state = const AuthStateError(message: 'OAuth cancelled or failed');
        return;
      }
      if (returnedState != expectedState) {
        state = const AuthStateError(
            message: 'OAuth state mismatch — possible CSRF');
        return;
      }

      // 4. Exchange code with backend
      final callbackRes = await _client.dio.post(
        '/auth/oauth/$provider/callback',
        data: {
          'code': code,
          'state': returnedState,
          'redirect_uri': redirectUri,
        },
      );
      _handleAuthResponse(callbackRes.data as Map<String, dynamic>);
    } on DioException catch (e) {
      state = AuthStateError(message: _extractError(e, 'OAuth sign-in failed'));
    } catch (e) {
      state = AuthStateError(message: 'OAuth was cancelled');
    }
  }

  Future<void> completeOAuthCallback({
    required String provider,
    required String code,
    required String stateParam,
  }) async {
    if (code.isEmpty || stateParam.isEmpty) {
      state = const AuthStateError(
          message: 'OAuth callback is missing code or state');
      return;
    }

    try {
      final callbackRes = await _client.dio.post(
        '/auth/oauth/$provider/callback',
        data: {
          'code': code,
          'state': stateParam,
          'redirect_uri': '${Uri.base.origin}/auth/callback/$provider',
        },
      );
      _handleAuthResponse(callbackRes.data as Map<String, dynamic>);
    } on DioException catch (e) {
      state = AuthStateError(message: _extractError(e, 'OAuth sign-in failed'));
    }
  }

  // ── Logout ───────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      final refreshToken =
          await _storage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken != null) {
        await _client.dio.post(
          '/auth/token/revoke',
          data: {'refresh_token': refreshToken},
        );
      }
    } catch (_) {
      // logout is best-effort
    }
    await _clearSession();
  }

  Future<void> logoutAllDevices() async {
    try {
      await _client.dio.post('/auth/token/revoke-all');
    } catch (_) {}
    await _clearSession();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  void resetState() {
    state = const AuthStateUnauthenticated();
  }

  /// Handles AuthResponse {access_token, refresh_token, user}
  void _handleAuthResponse(Map<String, dynamic> data) {
    _persistSession(data);
  }

  Future<void> _persistSession(Map<String, dynamic> data) async {
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String?;
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

    _client.setToken(accessToken);
    await _storage.write(key: AppConstants.accessTokenKey, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(
          key: AppConstants.refreshTokenKey, value: refreshToken);
    }
    await _storage.write(
        key: AppConstants.userKey, value: jsonEncode(user.toJson()));
    state = AuthStateAuthenticated(token: accessToken, user: user);
  }

  Future<void> _clearSession() async {
    _client.clearToken();
    await _storage.deleteAll();
    state = const AuthStateUnauthenticated();
  }

  String _extractError(DioException e, String fallback) {
    try {
      final body = e.response?.data;
      if (body is Map) return body['detail'] as String? ?? fallback;
    } catch (_) {}
    return fallback;
  }

  /// Waits for the OAuth popup to post its result via BroadcastChannel.
  /// Returns the full callback URL string, or null on timeout/error.
  Future<String?> _waitForOAuthPopupResult(String provider) async {
    if (!kIsWeb) return null;
    final completer = Completer<String?>();
    html.BroadcastChannel? channel;
    Timer? timer;
    try {
      channel = html.BroadcastChannel('flutter-web-auth-2');
      channel.onMessage.listen((event) {
        if (completer.isCompleted) return;
        try {
          final data = event.data;
          String? url;
          if (data is Map) {
            url = (data['flutter-web-auth-2'] as String?) ??
                (data['url'] as String?);
          } else if (data is String) {
            url = data;
          }
          if (url != null && url.contains('/auth/callback/$provider')) {
            completer.complete(url);
          }
        } catch (_) {}
      });
      // 5-minute timeout
      timer = Timer(const Duration(minutes: 5), () {
        if (!completer.isCompleted) completer.complete(null);
      });
      return await completer.future;
    } catch (e) {
      return null;
    } finally {
      timer?.cancel();
      channel?.close();
    }
  }
}
