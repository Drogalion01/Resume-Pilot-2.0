// lib/core/services/paddle_service.dart
//
// Dart wrapper around the Paddle.js v2 bridge defined in web/index.html.
// On non-web platforms it is a no-op so mobile builds don't fail.
//
// Usage:
//   await PaddleService.instance.initialize(ref);          // called once in main / auth state
//   PaddleService.instance.openCheckout(transactionId);   // opens overlay

import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

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
    if (!kIsWeb) {
      debugPrint('[PaddleService] openCheckout is web-only');
      return;
    }
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
      js.context.callMethod('openPaddleCheckoutByPriceId', [priceId, customerEmail ?? '']);
    } catch (e) {
      debugPrint('[PaddleService] openPaddleCheckoutByPriceId JS call failed: $e');
    }
  }

  /// Listen for Paddle checkout events relayed via window.postMessage.
  /// Returns a StreamSubscription — cancel it when the widget disposes.
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
