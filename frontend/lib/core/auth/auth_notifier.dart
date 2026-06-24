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

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../constants/app_constants.dart';
import '../models/user_model.dart';
import '../network/api_client.dart';
import 'auth_state.dart';

// ── Provider ───────────────────────────────────────────────────────────────────

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuthNotifier(client: client);
});

// ── Notifier ───────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _client;
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

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
        queryParameters: {'email': email},
      );
      state = AuthStateMagicLinkSent(email: email);
    } on DioException catch (e) {
      state = AuthStateError(message: _extractError(e, 'Failed to send magic link'));
    }
  }

  /// Step 2: Called from deep link — verifies token with backend.
  Future<void> verifyMagicLink(String token) async {
    state = const AuthStateLoading();
    try {
      final res = await _client.dio.post(
        '/auth/magic-link/verify',
        queryParameters: {'token': token},
      );
      _handleAuthResponse(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      state = AuthStateError(message: _extractError(e, 'Invalid or expired magic link'));
    }
  }

  // ── OAuth PKCE ───────────────────────────────────────────────────────────────

  /// Opens the provider OAuth page in a secure in-app browser,
  /// then posts the code + state to backend.
  Future<void> oauthAuthorize(String provider) async {
    state = const AuthStateLoading();
    try {
      // 1. Get the authorization URL from backend
      final String redirectUri = kIsWeb
          ? '${Uri.base.origin}/auth.html'
          : '${AppConstants.deepLinkBase}/auth/callback/$provider';

      final res = await _client.dio.get(
        '/auth/oauth/$provider/authorize',
        queryParameters: {
          'redirect_uri': redirectUri,
        },
      );
      final data = res.data as Map<String, dynamic>;
      final authUrl = data['authorization_url'] as String;
      final expectedState = data['state'] as String;

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
        state = const AuthStateError(message: 'OAuth state mismatch — possible CSRF');
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



  // ── Logout ───────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
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
      await _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken);
    }
    await _storage.write(key: AppConstants.userKey, value: jsonEncode(user.toJson()));
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
}
