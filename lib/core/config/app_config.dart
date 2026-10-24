/// Application Configuration
///
/// Centralizes compile-time environment definitions, API endpoints,
/// timeouts, pagination limits, and security configuration.
///
/// Configure values at build time with:
/// `--dart-define=API_BASE_URL=https://...`
/// `--dart-define=API_TOKEN=...`
/// `--dart-define=APP_ENV=production`
/// `--dart-define=ENABLE_ADMIN=true`
class AppConfig {
  AppConfig._();

  /// Default Apps Script Web App Base URL
  static const String defaultApiBaseUrl =
      'https://script.google.com/macros/s/AKfycby7LbZ7AB2FYYRIgbREXtEUlqg2eV6qzCmuE1cWqq80oGKlveJMTldqcIKiEAtzhTRa/exec';

  /// Compile-time configured base URL
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultApiBaseUrl,
  );

  /// Compile-time user API token (default for development testing)
  static const String defaultApiToken = String.fromEnvironment(
    'API_TOKEN',
    defaultValue: 'secret123',
  );

  /// Application environment: 'development', 'staging', 'production'
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  /// Feature flag: whether admin diagnostics screen is enabled
  static const bool enableAdmin = bool.fromEnvironment(
    'ENABLE_ADMIN',
    defaultValue: false,
  );

  /// Network connection timeout in milliseconds
  static const int connectTimeoutMs = 20000;

  /// Network receive timeout in milliseconds
  static const int receiveTimeoutMs = 25000;

  /// Maximum allowed redirects for Google Apps Script Web App redirect following
  static const int maxRedirects = 5;

  /// Default page size for history queries
  static const int defaultPageSize = 20;

  /// Maximum page size allowed by backend
  static const int maxPageSize = 100;

  /// Default timezone string for the application and backend
  static const String appTimeZone = 'Asia/Kolkata';

  /// Application version and build number
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 5;

  /// Check if running in production mode
  static bool get isProduction => environment == 'production';

  /// Check if running in development mode
  static bool get isDevelopment => environment == 'development';

  /// Device-specific and platform logo asset paths
  static const String logoDefault = 'asset/logo/time-table-logo.png';
  static const String logoMobile = 'asset/logo/time-table-mobile.png';
  static const String logoTablet = 'asset/logo/time-table-tablet.png';
  static const String logoWindows = 'asset/logo/time-table-windows.png';
  static const String logoWeb = 'asset/logo/time-table-logo.png';
}
