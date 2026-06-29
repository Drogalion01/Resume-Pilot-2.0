// lib/core/services/paddle_service.dart
//
// Dart wrapper around the Paddle.js v2 bridge defined in web/index.html.
// On non-web platforms every method is a no-op so mobile builds compile fine.
//
// Conditional imports resolve at compile time:
//   - Web    → dart:html + dart:js (real implementations)
//   - Mobile → html_stub.dart + js_stub.dart (no-ops)

import 'package:flutter/foundation.dart';

import '../web/html_stub.dart'
    if (dart.library.html) 'dart:html' as html;
import '../web/js_stub.dart'
    if (dart.library.js) 'dart:js' as js;

class PaddleService {
  PaddleService._();
  static final PaddleService instance = PaddleService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initialize Paddle.js with the client token and environment.
  /// Call this once after the user loads the app (or after auth).
  void initialize(String clientToken, {String environment = 'sandbox'}) {
    if (!kIsWeb) return;
    if (_initialized) return;
    try {
      js.context.callMethod('initPaddle', [clientToken, environment]);
      _initialized = true;
    } catch (e) {
      debugPrint('[PaddleService] initPaddle JS call failed: $e');
    }
  }

  /// Open the Paddle checkout overlay using a transaction ID returned
  /// by the backend POST /subscriptions/checkout endpoint.
  void openCheckoutByTransactionId(String transactionId) {
    if (!kIsWeb) return;
    if (!_initialized) {
      debugPrint('[PaddleService] Not initialized — call initialize() first');
      return;
    }
    try {
      js.context.callMethod('openPaddleCheckout', [transactionId]);
    } catch (e) {
      debugPrint('[PaddleService] openPaddleCheckout JS call failed: $e');
    }
  }

  /// Open the Paddle checkout overlay directly by price ID (client-side only,
  /// no backend call). Useful for simple upgrade flows.
  void openCheckoutByPriceId(String priceId, {String? customerEmail}) {
    if (!kIsWeb) return;
    if (!_initialized) {
      debugPrint('[PaddleService] Not initialized — call initialize() first');
      return;
    }
    try {
      js.context.callMethod(
          'openPaddleCheckoutByPriceId', [priceId, customerEmail ?? '']);
    } catch (e) {
      debugPrint(
          '[PaddleService] openPaddleCheckoutByPriceId JS call failed: $e');
    }
  }

  /// Listen for Paddle checkout events relayed via window.postMessage.
  /// Returns a Stream — subscribe and cancel on widget dispose.
  Stream<Map<String, dynamic>> get eventStream {
    if (!kIsWeb) return const Stream.empty();
    return html.window.onMessage
        .where((event) {
          try {
            final data = event.data;
            return data is Map && data['type'] == 'paddle_event';
          } catch (_) {
            return false;
          }
        })
        .map((event) {
          final data = event.data as Map;
          return {
            'event': data['event'] as String? ?? '',
            'data': data['data'],
          };
        });
  }
}
