// lib/core/auth/auth_state.dart
//
// Sealed class representing every possible authentication state.
// Used by GoRouter redirect to guard routes.

import '../models/user_model.dart';

sealed class AuthState {
  const AuthState();
}

/// App just launched — checking stored token (shows splash).
class AuthStateInitial extends AuthState {
  const AuthStateInitial();
}

/// Async auth check in progress.
class AuthStateLoading extends AuthState {
  const AuthStateLoading();
}

/// User is fully authenticated with a valid JWT.
class AuthStateAuthenticated extends AuthState {
  final String token;
  final UserModel user;

  const AuthStateAuthenticated({required this.token, required this.user});
}

/// No valid token found — show login/welcome.
class AuthStateUnauthenticated extends AuthState {
  final String? message;

  const AuthStateUnauthenticated({this.message});
}

/// An auth operation failed (login error, etc.).
class AuthStateError extends AuthState {
  final String message;
  final String? code; // e.g. "INVALID_CREDENTIALS", "EMAIL_EXISTS"

  const AuthStateError({required this.message, this.code});
}
