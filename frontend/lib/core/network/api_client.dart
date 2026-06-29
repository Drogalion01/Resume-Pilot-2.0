// lib/core/network/api_client.dart
//
// Dio HTTP client with:
//   1. AuthInterceptor  — injects Bearer token; on 401 silently refreshes ONCE
//                         and retries the original request; queues concurrent calls
//   2. ErrorInterceptor — maps HTTP errors to typed ApiException
//   3. LogInterceptor   — debug mode only
//
// Never use SharedPreferences for token storage — only flutter_secure_storage.



import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../storage/token_storage.dart';

// ── Providers ──────────────────────────────────────────────────────────────────

final cacheDirProvider = Provider<String>((ref) {
  throw UnimplementedError('cacheDirProvider must be overridden in main()');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final cacheDir = ref.watch(cacheDirProvider);
  return ApiClient(cacheDir: cacheDir);
});

// ── API Client ─────────────────────────────────────────────────────────────────

class ApiClient {
  late final Dio _dio;
  late final Dio _refreshDio; // separate Dio for refresh — avoids interceptor loop
  late final CacheOptions _cacheOptions;
  // Use platform-adaptive storage (localStorage on web, SecureStorage on native)
  final _storage = tokenStorage;

  String? _accessToken;

  ApiClient({required String cacheDir}) {
    final store = HiveCacheStore(cacheDir);

    _cacheOptions = CacheOptions(
      store: store,
      maxStale: AppConstants.cacheMaxAge,
      hitCacheOnErrorExcept: [401, 403],
    );

    _refreshDio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));

    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));

    _dio.interceptors.addAll([
      DioCacheInterceptor(options: _cacheOptions),
      _SilentRefreshInterceptor(_storage, _refreshDio, this),
      _ErrorInterceptor(),
      if (const bool.fromEnvironment('dart.vm.product') == false)
        LogInterceptor(requestBody: false, responseBody: false),
    ]);
  }

  Dio get dio => _dio;

  // ── Token management (in-memory + secure storage) ──────────────────────────

  void setToken(String token) {
    _accessToken = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearToken() {
    _accessToken = null;
    _dio.options.headers.remove('Authorization');
  }

  String? get currentToken => _accessToken;
}

// ── Silent Refresh Interceptor ─────────────────────────────────────────────────
// On 401: refresh ONCE using the stored refresh_token, update storage, retry.
// Queues concurrent requests so only ONE refresh is in-flight at a time.

class _SilentRefreshInterceptor extends QueuedInterceptorsWrapper {
  final TokenStorage _storage;
  final Dio _refreshDio;
  final ApiClient _client;

  _SilentRefreshInterceptor(this._storage, this._refreshDio, this._client);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: AppConstants.accessTokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    // Don't retry the refresh endpoint itself
    if (err.requestOptions.path.contains('/auth/token/refresh')) {
      handler.next(err);
      return;
    }

    try {
      final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null) {
        handler.next(err);
        return;
      }

      // Attempt silent refresh
      final response = await _refreshDio.post('/auth/token/refresh',
          data: {'refresh_token': refreshToken});

      final data = response.data as Map<String, dynamic>;
      final newAccess  = data['access_token'] as String;
      final newRefresh = data['refresh_token'] as String;

      // Persist rotated tokens
      await _storage.write(key: AppConstants.accessTokenKey,  value: newAccess);
      await _storage.write(key: AppConstants.refreshTokenKey, value: newRefresh);
      _client.setToken(newAccess);

      // Retry original request with new token
      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newAccess';
      final retryResponse = await _refreshDio.fetch(retryOptions);
      handler.resolve(retryResponse);
    } catch (_) {
      // Refresh failed — force logout
      await _storage.deleteAll();
      _client.clearToken();
      handler.next(err);
    }
  }
}

// ── Error Interceptor ──────────────────────────────────────────────────────────

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (response != null) {
      final data = response.data;
      String message = 'An unexpected error occurred.';
      String? code;

      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is Map<String, dynamic>) {
          message = detail['message'] as String? ?? message;
          code    = detail['error'] as String? ?? detail['code'] as String?;
        } else if (detail is String) {
          message = detail;
        }
      }

      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          response: response,
          error: ApiException(
              message: message, code: code, statusCode: response.statusCode),
          type: err.type,
        ),
      );
      return;
    }
    handler.next(err);
  }
}

// ── Exception ──────────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  const ApiException({required this.message, this.code, this.statusCode});

  bool get isUnauthorized        => statusCode == 401;
  bool get isForbidden           => statusCode == 403;
  bool get isPaymentRequired     => statusCode == 402;
  bool get isConflict            => statusCode == 409;
  bool get isGenerationLimitHit  => isPaymentRequired && code == 'generation_limit_exceeded';

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
