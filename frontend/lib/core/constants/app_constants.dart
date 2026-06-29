// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // Use dart defines if provided (e.g. for Vercel deployment), otherwise fallback to production custom domain
  static const String _rawBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.resume-pilot.tech',
  );
  
  static String get baseUrl => '$_rawBaseUrl/api/v1'.replaceAll('//api/v1', '/api/v1');

  // ── Secure Storage Keys ────────────────────────────────────────────────────
  static const String accessTokenKey  = 'rp_access_token';
  static const String refreshTokenKey = 'rp_refresh_token';
  static const String userKey         = 'rp_user_json';

  // ── Deep Links ─────────────────────────────────────────────────────────────
  static const String deepLinkBase = 'resumepilot://app';
  // Magic link:  resumepilot://app/auth/verify?token=<token>
  // OAuth:       resumepilot://app/auth/callback/{provider}?code=...&state=...

  // ── Timeouts ───────────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 120);  // AI endpoints can take 60-90s
  static const Duration cacheMaxAge    = Duration(minutes: 5);

  // ── App ────────────────────────────────────────────────────────────────────
  static const String appName    = 'Resume Pilot';
  static const String appTagline = 'Land your dream job with AI';
  static const String appVersion = '2.0.0';

  // ── Plan gates ─────────────────────────────────────────────────────────────
  static const String proFeatureMessage =
      'This feature is available on the Pro plan. Upgrade to unlock unlimited AI rewrites, cover letters, and more.';

  // ── Auth rate limits (for UI cooldown timers) ──────────────────────────────
  static const Duration magicLinkResendCooldown = Duration(seconds: 60);
}
