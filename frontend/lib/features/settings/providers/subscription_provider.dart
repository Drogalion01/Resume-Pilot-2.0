// lib/features/settings/providers/subscription_provider.dart
//
// Riverpod data layer for Paddle subscription plans and checkout.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;

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
  const PaddleConfig({required this.clientToken, required this.environment});
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
      clientToken: res.data['client_token'] as String,
      environment: res.data['environment'] as String,
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
      // If Paddle.js is initialized, use direct price-ID checkout (no backend call needed)
      if (PaddleService.instance.isInitialized) {
        PaddleService.instance.openCheckoutByPriceId(
          priceId,
          customerEmail: _userEmail,
        );
        state = state.copyWith(status: CheckoutStatus.success);
        return;
      }

      // Fallback: backend creates transaction → use transaction ID
      final result = await _repo.createCheckout(priceId);
      final transactionId = result['transaction_id'] as String?;

      if (transactionId != null &&
          PaddleService.instance.isInitialized) {
        PaddleService.instance.openCheckoutByTransactionId(transactionId);
        state = state.copyWith(status: CheckoutStatus.success);
      } else {
        // Last resort: open checkout URL in browser
        final checkoutUrl = result['checkout_url'] as String?;
        if (checkoutUrl != null) {
          if (kIsWeb) html.window.open(checkoutUrl, '_blank');
          state = state.copyWith(status: CheckoutStatus.success);
        } else {
          throw Exception('No checkout URL or transaction ID returned');
        }
      }
    } on DioException catch (e) {
      final msg = (e.error as dynamic)?.message as String? ??
          'Checkout failed. Please try again.';
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
