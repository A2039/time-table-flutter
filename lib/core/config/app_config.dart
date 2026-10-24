import 'dart:convert';
import 'package:flutter/services.dart';

/// Application Configuration
///
/// Centralizes compile-time environment definitions, API endpoints,
/// timeouts, pagination limits, and security configuration.
///
/// Automatically loads and parses `lib/config/app_config.json` at application startup.
class AppConfig {
  AppConfig._();

  /// Default Apps Script Web App Base URL fallback
  static const String defaultApiBaseUrl =
      'https://script.google.com/macros/s/AKfycby7LbZ7AB2FYYRIgbREXtEUlqg2eV6qzCmuE1cWqq80oGKlveJMTldqcIKiEAtzhTRa/exec';

  /// Compile-time user API token constant fallback
  static const String defaultApiTokenConstant = 'secret123';

  /// Compile-time admin API token constant fallback
  static const String defaultAdminApiTokenConstant = 'secret456';

  /// Active Base URL (loaded from lib/config/app_config.json, with compile-time fallback)
  static String apiBaseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultApiBaseUrl,
  );

  /// Active user API token (loaded from lib/config/app_config.json, with compile-time fallback)
  static String defaultApiToken = const String.fromEnvironment(
    'API_TOKEN',
    defaultValue: defaultApiTokenConstant,
  );

  /// Active admin API token (loaded from lib/config/app_config.json, with compile-time fallback)
  static String adminApiToken = const String.fromEnvironment(
    'ADMIN_API_TOKEN',
    defaultValue: defaultAdminApiTokenConstant,
  );

  /// API timeout in seconds
  static int apiTimeoutSeconds = 30;

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
  static String appVersion = '1.0.0';
  static int appBuildNumber = 5;

  /// Application name and bundle identifier
  static String appName = 'Time Table';
  static String appBundleIdentifier = 'com.timetable.app.timetable_app';
  static String appDescription = 'Daily timetable & activity tracker.';

  /// Device-specific and platform logo asset paths
  static String logoDefault = 'asset/logo/time-table-logo.png';
  static String logoMobile = 'asset/logo/time-table-mobile.png';
  static String logoTablet = 'asset/logo/time-table-tablet.png';
  static String logoWindows = 'asset/logo/time-table-windows.png';
  static String logoWeb = 'asset/logo/time-table-logo.png';

  /// Support contact information
  static String supportMail = 'support@timetable.com';
  static String supportNumber = '';

  /// Copyright template
  static String copyright =
      'Copyright © (auto fetch current year) com.timetable. All rights reserved.';

  /// UI typography & scaling
  static String fontFamily = 'Poppins';
  static double textScaleFactor = 0.84;

  /// Debug options
  static bool printCache = false;
  static int printCacheInterval = 20;
  static bool printRequestResponse = false;

  /// Complete raw parsed config dictionary
  static Map<String, dynamic> rawConfig = {};

  /// Check if running in production mode
  static bool get isProduction => environment == 'production';

  /// Check if running in development mode
  static bool get isDevelopment => environment == 'development';

  /// Automatically format copyright with current year
  static String get copyrightFormatted {
    final currentYear = DateTime.now().year.toString();
    return copyright
        .replaceAll('(auto fetch current year)', currentYear)
        .replaceAll('{year}', currentYear);
  }

  /// Initialize application configuration by loading `lib/config/app_config.json`
  static Future<void> initialize() async {
    try {
      final jsonString =
          await rootBundle.loadString('lib/config/app_config.json');
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        rawConfig = decoded;
        _parseConfig(decoded);
      }
    } catch (_) {
      // Safe fallback: preserves compile-time and default constant configurations
    }
  }

  static void _parseConfig(Map<String, dynamic> json) {
    // App top-level / nested metadata
    if (json['app_name'] is String && (json['app_name'] as String).isNotEmpty) {
      appName = json['app_name'] as String;
    }
    if (json['app_bundleIdentifier'] is String &&
        (json['app_bundleIdentifier'] as String).isNotEmpty) {
      appBundleIdentifier = json['app_bundleIdentifier'] as String;
    }

    if (json['app'] is Map) {
      final app = json['app'] as Map<String, dynamic>;
      if (app['displayName'] is String &&
          (app['displayName'] as String).isNotEmpty) {
        appName = app['displayName'] as String;
      } else if (app['name'] is String && (app['name'] as String).isNotEmpty) {
        appName = app['name'] as String;
      }
      if (app['description'] is String) {
        appDescription = app['description'] as String;
      }
      if (app['version'] is String && (app['version'] as String).isNotEmpty) {
        appVersion = app['version'] as String;
      }
      if (app['buildNumber'] is num) {
        appBuildNumber = (app['buildNumber'] as num).toInt();
      }
      if (app['bundleIdentifier'] is String &&
          (app['bundleIdentifier'] as String).isNotEmpty) {
        appBundleIdentifier = app['bundleIdentifier'] as String;
      }
    } else {
      if (json['version'] is String && (json['version'] as String).isNotEmpty) {
        appVersion = json['version'] as String;
      }
      if (json['buildNumber'] is num) {
        appBuildNumber = (json['buildNumber'] as num).toInt();
      }
    }

    // API settings
    if (json['api'] is Map) {
      final api = json['api'] as Map<String, dynamic>;
      if (api['baseApiUrl'] is String &&
          (api['baseApiUrl'] as String).trim().isNotEmpty) {
        apiBaseUrl = (api['baseApiUrl'] as String).trim();
      }
      if (api['apiTimeOut'] is num) {
        apiTimeoutSeconds = (api['apiTimeOut'] as num).toInt();
      }
    }

    // API Tokens
    if (json['apiToken'] is Map) {
      final tokens = json['apiToken'] as Map<String, dynamic>;
      if (tokens['apiToken'] is String &&
          (tokens['apiToken'] as String).trim().isNotEmpty) {
        defaultApiToken = (tokens['apiToken'] as String).trim();
      }
      if (tokens['adminApiToken'] is String &&
          (tokens['adminApiToken'] as String).trim().isNotEmpty) {
        adminApiToken = (tokens['adminApiToken'] as String).trim();
      }
    }

    // Logos
    final logoMap = json['logo'] ?? json['logos'];
    if (logoMap is Map) {
      if (logoMap['default'] is String) {
        logoDefault = logoMap['default'] as String;
      }
      if (logoMap['mobile'] is String) {
        logoMobile = logoMap['mobile'] as String;
      }
      if (logoMap['tablet'] is String) {
        logoTablet = logoMap['tablet'] as String;
      }
      if (logoMap['windows'] is String) {
        logoWindows = logoMap['windows'] as String;
      }
      if (logoMap['web'] is String) {
        logoWeb = logoMap['web'] as String;
      }
    }

    // Support
    if (json['support'] is Map) {
      final support = json['support'] as Map<String, dynamic>;
      if (support['support_mail'] is String) {
        supportMail = support['support_mail'] as String;
      }
      if (support['support_numer'] is String) {
        supportNumber = support['support_numer'] as String;
      }
    }

    // Copyright
    if (json['copyright'] is String &&
        (json['copyright'] as String).isNotEmpty) {
      copyright = json['copyright'] as String;
    }

    // UI
    if (json['ui'] is Map) {
      final ui = json['ui'] as Map<String, dynamic>;
      if (ui['fontFamily'] is String) {
        fontFamily = ui['fontFamily'] as String;
      }
      if (ui['textScaleFactor'] is num) {
        textScaleFactor = (ui['textScaleFactor'] as num).toDouble();
      }
    }

    // Debug
    if (json['debug'] is Map) {
      final debug = json['debug'] as Map<String, dynamic>;
      if (debug['printCache'] is bool) {
        printCache = debug['printCache'] as bool;
      }
      if (debug['printCacheInterval'] is num) {
        printCacheInterval = (debug['printCacheInterval'] as num).toInt();
      }
      if (debug['printRequestResponce'] is bool) {
        printRequestResponse = debug['printRequestResponce'] as bool;
      }
    }
  }
}
