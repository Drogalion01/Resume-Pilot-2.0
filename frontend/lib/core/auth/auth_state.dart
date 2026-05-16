// lib/core/auth/auth_state.dart
//
// Sealed class representing every possible authentication state.
// Matches the passwordless-first spec:
//   unauthenticated → (magic link or OAuth) → mfaPending → authenticated
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

/// Magic link email was sent — waiting for user to tap the link.
class AuthStateMagicLinkSent extends AuthState {
  final String email;
  const AuthStateMagicLinkSent({required this.email});
}

/// First factor complete (magic link or OAuth) but TOTP is required.
/// [mfaToken] is the short-lived JWT (scope=mfa_pending, 5 min).
class AuthStateMFAPending extends AuthState {
  final String mfaToken;
  const AuthStateMFAPending({required this.mfaToken});
}

/// User is fully authenticated with a valid JWT + optional TOTP.
class AuthStateAuthenticated extends AuthState {
  final String token;
  final UserModel user;
  const AuthStateAuthenticated({required this.token, required this.user});
}

/// No valid token found — show landing screen.
class AuthStateUnauthenticated extends AuthState {
  final String? message;
  const AuthStateUnauthenticated({this.message});
}

/// An auth operation failed (expired link, invalid code, network error, etc.).
class AuthStateError extends AuthState {
  final String message;
  final String? code;
  const AuthStateError({required this.message, this.code});
}
