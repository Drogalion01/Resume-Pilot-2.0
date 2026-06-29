// lib/core/web/html_stub.dart
//
// Stub for dart:html types used on non-web platforms.
// On web, the real dart:html is loaded via conditional imports:
//   import '...html_stub.dart' if (dart.library.html) 'dart:html' as html;
//
// Every method/property here is a no-op so all platforms compile cleanly.

// ── MessageEvent stub ─────────────────────────────────────────────────────────
class MessageEvent {
  final dynamic data;
  const MessageEvent({this.data});
}

// ── BroadcastChannel stub (used in auth_notifier.dart) ───────────────────────
class BroadcastChannel {
  // ignore: avoid_unused_constructor_parameters
  BroadcastChannel(String name);
  Stream<MessageEvent> get onMessage => const Stream.empty();
  void close() {}
}

// ── Window stub (used in subscription_provider.dart + paddle_service.dart) ───
class _Window {
  Stream<MessageEvent> get onMessage => const Stream.empty();
  // ignore: avoid_unused_constructor_parameters
  void open(String url, String target) {}
}

// Top-level window object mirrors dart:html's global `window`
// ignore: library_private_types_in_public_api
final _Window window = _Window();
