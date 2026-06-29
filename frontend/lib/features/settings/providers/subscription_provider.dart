// lib/features/settings/providers/subscription_provider.dart
//
// Riverpod data layer for Paddle subscription plans and checkout.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Conditional import: on non-web platforms resolves to a no-op stub
import '../../../core/web/html_stub.dart'
    if (dart.library.html) 'dart:html' as html;

import '../../../core/network/api_client.dart';
import '../../../core/services/paddle_service.dart';

// ── Data models ──────────────────────────────────────────────────────────────

class SubscriptionPlan {
  final String id;
  final String priceId;
  final String name;
  final double price;
  final String interval;
  final List<String> features;

  const SubscriptionPlan({
    required this.id,
    required this.priceId,
    required this.name,
    required this.price,
    required this.interval,
    required this.features,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlan(
        id: json['id'] as String,
        priceId: json['price_id'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        interval: json['interval'] as String,
        features: (json['features'] as List)
            .map((e) => e as String)
            .toList(),
      );

  String get intervalLabel {
    switch (interval) {
      case 'month':
        return '/month';
      case 'year':
        return '/year';
      default:
        return ' one-time';
    }
  }
}

class PaddleConfig {
  final String clientToken;
  final String environment;
  final bool paddleConfigured;
  const PaddleConfig({
    required this.clientToken,
    required this.environment,
    this.paddleConfigured = false,
  });
}

// ── Repository ───────────────────────────────────────────────────────────────

class SubscriptionRepository {
  final Dio _dio;
  SubscriptionRepository(this._dio);

  Future<List<SubscriptionPlan>> fetchPlans() async {
    final res = await _dio.get('/subscriptions/plans');
    final list = (res.data['plans'] as List);
    return list
        .map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PaddleConfig> fetchPaddleConfig() async {
    final res = await _dio.get('/subscriptions/config');
    return PaddleConfig(
      clientToken: res.data['client_token'] as String? ?? '',
      environment: res.data['environment'] as String? ?? 'sandbox',
      paddleConfigured: res.data['paddle_configured'] as bool? ?? false,
    );
  }

  /// Backend creates a Paddle transaction, returns checkout_url + transaction_id.
  Future<Map<String, dynamic>> createCheckout(String priceId) async {
    final res = await _dio.post('/subscriptions/checkout', data: {
      'price_id': priceId,
    });
    return res.data as Map<String, dynamic>;
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final dio = ref.watch(apiClientProvider).dio;
  return SubscriptionRepository(dio);
});

/// Fetches and caches available plans from the backend.
final subscriptionPlansProvider =
    FutureProvider<List<SubscriptionPlan>>((ref) async {
  return ref.read(subscriptionRepositoryProvider).fetchPlans();
});

/// Fetches Paddle client config and initializes Paddle.js.
/// Should be watched once on app startup or on the settings screen.
final paddleInitProvider = FutureProvider<void>((ref) async {
  if (!kIsWeb) return;
  try {
    final config =
        await ref.read(subscriptionRepositoryProvider).fetchPaddleConfig();
    if (!config.paddleConfigured || config.clientToken.isEmpty) {
      debugPrint('[Paddle] Not configured — skipping initialization. '
          'Set PADDLE_CLIENT_TOKEN in backend env vars.');
      return;
    }
    PaddleService.instance.initialize(
      config.clientToken,
      environment: config.environment,
    );
  } catch (e) {
    debugPrint('[Paddle] Config fetch failed: $e');
  }
});

// ── Checkout notifier ─────────────────────────────────────────────────────────

enum CheckoutStatus { idle, loading, success, error }

class CheckoutState {
  final CheckoutStatus status;
  final String? error;
  const CheckoutState({this.status = CheckoutStatus.idle, this.error});

  CheckoutState copyWith({CheckoutStatus? status, String? error}) =>
      CheckoutState(
        status: status ?? this.status,
        error: error ?? this.error,
      );
}

class CheckoutNotifier extends StateNotifier<CheckoutState> {
  final SubscriptionRepository _repo;
  final String? _userEmail;

  CheckoutNotifier(this._repo, this._userEmail)
      : super(const CheckoutState());

  Future<void> openCheckout(String priceId) async {
    if (state.status == CheckoutStatus.loading) return;
    state = state.copyWith(status: CheckoutStatus.loading);

    if (!kIsWeb) {
      state = state.copyWith(
        status: CheckoutStatus.error,
        error: 'Payments are only available on the web app.',
      );
      return;
    }

    try {
      // Path A: Paddle.js is initialized → open overlay directly by price ID
      if (PaddleService.instance.isInitialized) {
        PaddleService.instance.openCheckoutByPriceId(
          priceId,
          customerEmail: _userEmail,
        );
        state = state.copyWith(status: CheckoutStatus.success);
        return;
      }

      // Path B: Paddle.js not ready → ask backend to create transaction + get URL
      // This covers the race condition where /config hasn't resolved yet,
      // AND the case where PADDLE_API_KEY is set but PADDLE_CLIENT_TOKEN isn't.
      final result = await _repo.createCheckout(priceId);
      final transactionId = result['transaction_id'] as String?;
      final checkoutUrl = result['checkout_url'] as String?;

      // If Paddle.js initialized by now (async), use overlay
      if (transactionId != null && PaddleService.instance.isInitialized) {
        PaddleService.instance.openCheckoutByTransactionId(transactionId);
        state = state.copyWith(status: CheckoutStatus.success);
        return;
      }

      // Path C: Open checkout URL in new tab as final fallback
      if (checkoutUrl != null) {
        if (kIsWeb) html.window.open(checkoutUrl, '_blank');
        state = state.copyWith(status: CheckoutStatus.success);
        return;
      }

      throw Exception('Checkout unavailable. Please try again.');
    } on DioException catch (e) {
      final apiErr = e.error is ApiException ? (e.error as ApiException) : null;
      final msg = apiErr?.message ??
          (e.response?.statusCode == 503
              ? 'Payment gateway is not configured yet. Please contact support.'
              : 'Checkout failed. Please try again.');
      state = state.copyWith(status: CheckoutStatus.error, error: msg);
    } catch (e) {
      state = state.copyWith(
        status: CheckoutStatus.error,
        error: e.toString(),
      );
    }
  }

  void reset() => state = const CheckoutState();
}

final checkoutProvider =
    StateNotifierProvider.family<CheckoutNotifier, CheckoutState, String?>(
  (ref, userEmail) {
    final repo = ref.read(subscriptionRepositoryProvider);
    return CheckoutNotifier(repo, userEmail);
  },
);
