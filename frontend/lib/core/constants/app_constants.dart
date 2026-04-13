// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // ── API ────────────────────────────────────────────────────────────────────
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1'; // Android emulator → localhost
  // static const String baseUrl = 'https://resumepilot-api.onrender.com/api/v1'; // Production

  static const String tokenKey = 'rp_access_token';
  static const String userKey = 'rp_user_json';

  // ── Timeouts ───────────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration cacheMaxAge = Duration(minutes: 5);

  // ── App ────────────────────────────────────────────────────────────────────
  static const String appName = 'ResumePilot';
  static const String appTagline = 'Land your dream job with AI';
  static const String appVersion = '2.0.0';

  // ── Plan gate messages ─────────────────────────────────────────────────────
  static const String proFeatureMessage =
      'This feature is available on the Pro plan. Upgrade to unlock unlimited AI rewrites, cover letters, and more.';
}
