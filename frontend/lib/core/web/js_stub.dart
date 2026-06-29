// lib/core/web/js_stub.dart
//
// Stub for dart:js used on non-web platforms.
// On web, the real dart:js is loaded via conditional import:
//   import '../web/js_stub.dart' if (dart.library.js) 'dart:js' as js;

class _JsContext {
  dynamic callMethod(String method, [List? args]) => null;
  dynamic operator [](String key) => null;
}

// ignore: library_private_types_in_public_api
final _JsContext context = _JsContext();
