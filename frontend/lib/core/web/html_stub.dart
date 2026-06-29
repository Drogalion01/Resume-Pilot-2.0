// lib/core/web/html_stub.dart
//
// Stub for dart:html types used in auth_notifier.dart on non-web platforms.
// On web, the real dart:html is used instead via the conditional import:
//   import '../web/html_stub.dart' if (dart.library.html) 'dart:html' as html;

// Minimal stubs so mobile builds compile without dart:html.

class BroadcastChannel {
  BroadcastChannel(String name);
  Stream<_MessageEvent> get onMessage => const Stream.empty();
  void close() {}
}

class _MessageEvent {
  final dynamic data = null;
}
