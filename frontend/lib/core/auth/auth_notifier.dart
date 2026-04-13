// lib/core/auth/auth_notifier.dart
//
// Riverpod notifier managing the full authentication lifecycle.
// Persists token in flutter_secure_storage, auto-restores on cold start.

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../constants/app_constants.dart';
import '../models/user_model.dart';
import '../network/api_client.dart';
import 'auth_state.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuthNotifier(client: client);
});

// ── Notifier ──────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _client;
  final _storage = const FlutterSecureStorage();
  final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  AuthNotifier({required ApiClient client})
      : _client = client,
        super(const AuthStateInitial()) {
    _restoreSession();
  }

  // ── Session restoration ────────────────────────────────────────────────────

  Future<void> _restoreSession() async {
    state = const AuthStateLoading();
    try {
      final token = await _storage.read(key: AppConstants.tokenKey);
      final userJson = await _storage.read(key: AppConstants.userKey);

      if (token != null && userJson != null) {
        final user = UserModel.fromJson(
          Map<String, dynamic>.from(const jsonDecoder.convert(userJson) as Map),
        );
        state = AuthStateAuthenticated(token: token, user: user);
      } else {
        state = const AuthStateUnauthenticated();
      }
    } catch (_) {
      state = const AuthStateUnauthenticated();
    }
  }

  // ── Register ──────────────────────────────────────────────────────────────

  Future<void> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    state = const AuthStateLoading();
    try {
      final response = await _client.post('/auth/register', data: {
        'email': email,
        'password': password,
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
      });
      await _persistSession(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final err = e.error;
      if (err is ApiException) {
        state = AuthStateError(message: err.message, code: err.code);
      } else {
        state = const AuthStateError(message: 'Registration failed. Please try again.');
      }
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<void> login({required String email, required String password}) async {
    state = const AuthStateLoading();
    try {
      final response = await _client.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      await _persistSession(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final err = e.error;
      if (err is ApiException) {
        state = AuthStateError(message: err.message, code: err.code);
      } else {
        state = const AuthStateError(message: 'Login failed. Please try again.');
      }
    }
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────

  Future<void> loginWithGoogle() async {
    state = const AuthStateLoading();
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        state = const AuthStateUnauthenticated();
        return;
      }

      final auth = await googleUser.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        state = const AuthStateError(message: 'Google sign-in failed. No token received.');
        return;
      }

      final response = await _client.post('/auth/google', data: {'id_token': idToken});
      await _persistSession(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final err = e.error;
      if (err is ApiException) {
        state = AuthStateError(message: err.message, code: err.code);
      } else {
        state = const AuthStateError(message: 'Google sign-in failed. Please try again.');
      }
    } catch (_) {
      state = const AuthStateError(message: 'Google sign-in was cancelled.');
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await _client.post('/auth/logout');
    } catch (_) {
      // Logout is best-effort
    }
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.userKey);
    await _googleSignIn.signOut();
    await _client.clearToken();
    state = const AuthStateUnauthenticated();
  }

  // ── Complete onboarding ────────────────────────────────────────────────────

  Future<void> completeOnboarding({
    required String fullName,
    List<String>? targetRoles,
  }) async {
    try {
      final response = await _client.post('/auth/onboarding', data: {
        'full_name': fullName,
        if (targetRoles != null) 'target_roles': targetRoles,
      });
      await _persistSession(response.data as Map<String, dynamic>);
    } catch (_) {
      // fail silently — user can update profile later
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _persistSession(Map<String, dynamic> data) async {
    final token = data['access_token'] as String;
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

    await _client.setToken(token);
    await _storage.write(key: AppConstants.tokenKey, value: token);
    await _storage.write(
      key: AppConstants.userKey,
      value: jsonEncode(user.toJson()),
    );
    state = AuthStateAuthenticated(token: token, user: user);
  }
}

const jsonDecoder = JsonDecoder();
