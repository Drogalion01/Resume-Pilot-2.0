// lib/core/storage/token_storage.dart
//
// Platform-adaptive secure token storage.
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  WHY NOT flutter_secure_storage on web?                                │
// │                                                                         │
// │  flutter_secure_storage on web derives its PBKDF2 encryption key       │
// │  freshly on EVERY page load from a session-scoped random salt.         │
// │  This means the key changes between page loads → stored ciphertext     │
// │  becomes unreadable → read() returns null → user is logged out.        │
// │                                                                         │
// │  Fix: use window.localStorage directly on web. JWTs are already        │
// │  server-signed so browser-native storage is safe here.                 │
// │  On native (Android/iOS), flutter_secure_storage provides the OS       │
// │  Keychain/Keystore backed encryption we need.                          │
// └─────────────────────────────────────────────────────────────────────────┘

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Conditional import: on web, dart:html is available; on native, html_stub.
import '../web/html_stub.dart'
    if (dart.library.html) 'dart:html' as html;

// ── Public singleton ──────────────────────────────────────────────────────────

/// Use this instead of FlutterSecureStorage directly.
/// On web  → localStorage (persistent across page reloads, same-origin).
/// On native → FlutterSecureStorage (OS Keychain / Keystore).
final tokenStorage = TokenStorage._();

// ── Implementation ────────────────────────────────────────────────────────────

class TokenStorage {
  TokenStorage._();

  static const FlutterSecureStorage _native = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Read ────────────────────────────────────────────────────────────────────

  Future<String?> read({required String key}) async {
    if (kIsWeb) {
      try {
        return _webStorage[key];
      } catch (_) {
        return null;
      }
    }
    return _native.read(key: key);
  }

  // ── Write ───────────────────────────────────────────────────────────────────

  Future<void> write({required String key, required String value}) async {
    if (kIsWeb) {
      try {
        _webStorage[key] = value;
      } catch (_) {}
      return;
    }
    await _native.write(key: key, value: value);
  }

  // ── Delete single ───────────────────────────────────────────────────────────

  Future<void> delete({required String key}) async {
    if (kIsWeb) {
      try {
        _webStorage.remove(key);
      } catch (_) {}
      return;
    }
    await _native.delete(key: key);
  }

  // ── Delete all ──────────────────────────────────────────────────────────────

  Future<void> deleteAll() async {
    if (kIsWeb) {
      try {
        _webStorage.clear();
      } catch (_) {}
      return;
    }
    await _native.deleteAll();
  }
}

// ── Web localStorage accessor ─────────────────────────────────────────────────
// Uses dart:html on web, stub on native (never actually called on native).

html.Storage get _webStorage => html.window.localStorage;
