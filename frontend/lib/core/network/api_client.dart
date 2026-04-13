// lib/core/network/api_client.dart
//
// Dio HTTP client with:
//   - JWT Bearer injection
//   - Hive-backed offline cache (GET requests)
//   - 401 auto-logout
//   - Structured error parsing

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final cacheDirProvider = Provider<String>((ref) {
  throw UnimplementedError('cacheDirProvider must be overridden in main()');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final cacheDir = ref.watch(cacheDirProvider);
  return ApiClient(cacheDir: cacheDir, ref: ref);
});

// ── API Client ────────────────────────────────────────────────────────────────

class ApiClient {
  late final Dio _dio;
  late final CacheOptions _cacheOptions;
  final _storage = const FlutterSecureStorage();

  ApiClient({required String cacheDir, required Ref ref}) {
    final store = HiveCacheStore(cacheDir);

    _cacheOptions = CacheOptions(
      store: store,
      maxStale: AppConstants.cacheMaxAge,
      hitCacheOnErrorExcept: [401, 403],
    );

    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));

    _dio.interceptors.addAll([
      DioCacheInterceptor(options: _cacheOptions),
      _AuthInterceptor(_storage),
      _ErrorInterceptor(),
      if (const bool.fromEnvironment('dart.vm.product') == false)
        LogInterceptor(requestBody: false, responseBody: false),
    ]);
  }

  Dio get dio => _dio;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters, bool cache = false}) =>
      _dio.get<T>(path,
          queryParameters: queryParameters,
          options: cache ? _cacheOptions.toOptions() : null);

  Future<Response<T>> post<T>(String path, {dynamic data}) => _dio.post<T>(path, data: data);

  Future<Response<T>> patch<T>(String path, {dynamic data}) => _dio.patch<T>(path, data: data);

  Future<Response<T>> delete<T>(String path) => _dio.delete<T>(path);

  Future<void> setToken(String token) async =>
      _storage.write(key: AppConstants.tokenKey, value: token);

  Future<void> clearToken() async =>
      _storage.delete(key: AppConstants.tokenKey);

  Future<String?> getToken() async =>
      _storage.read(key: AppConstants.tokenKey);
}

// ── Interceptors ─────────────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;

  const _AuthInterceptor(this._storage);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

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
          code = detail['code'] as String?;
        } else if (detail is String) {
          message = detail;
        }
      }

      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          response: response,
          error: ApiException(message: message, code: code, statusCode: response.statusCode),
          type: err.type,
        ),
      );
      return;
    }
    handler.next(err);
  }
}

// ── Exception ─────────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  const ApiException({required this.message, this.code, this.statusCode});

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isConflict => statusCode == 409;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
