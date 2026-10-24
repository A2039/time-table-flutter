import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';

/// Storage service providing persistent local settings.
///
/// Base URL and API Tokens are read directly from `AppConfig` (configured via `lib/config/app_config.json`).
class StorageService {
  final SharedPreferences _prefs;
  // ignore: unused_field
  final FlutterSecureStorage _secureStorage;

  StorageService(this._prefs, this._secureStorage);

  static const String _keyThemeMode = 'pref_theme_mode';

  static Future<StorageService> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage(aOptions: AndroidOptions());
    return StorageService(prefs, secureStorage);
  }

  /// Get active API user token directly from AppConfig (configured via lib/config/app_config.json)
  Future<String> getApiToken() async {
    return AppConfig.defaultApiToken;
  }

  /// Save new API user token (deprecated: tokens are managed via app_config.json)
  Future<void> saveApiToken(String token) async {
    // Retained for backward interface compatibility
  }

  /// Get active Admin token directly from AppConfig (configured via lib/config/app_config.json)
  Future<String?> getAdminToken() async {
    return AppConfig.adminApiToken.isNotEmpty ? AppConfig.adminApiToken : null;
  }

  /// Save admin token (deprecated: tokens are managed via app_config.json)
  Future<void> saveAdminToken(String token) async {
    // Retained for backward interface compatibility
  }

  /// Get active Base URL directly from AppConfig (configured via lib/config/app_config.json)
  String getBaseUrl() {
    return AppConfig.apiBaseUrl;
  }

  /// Save Base URL override (deprecated: URLs are managed via app_config.json)
  Future<void> saveBaseUrl(String url) async {
    // Retained for backward interface compatibility
  }

  /// Reset Base URL override (deprecated: URLs are managed via app_config.json)
  Future<void> resetBaseUrl() async {
    // Retained for backward interface compatibility
  }

  /// Theme mode (System, Light, Dark)
  ThemeMode getThemeMode() {
    final mode = _prefs.getString(_keyThemeMode);
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    switch (mode) {
      case ThemeMode.light:
        await _prefs.setString(_keyThemeMode, 'light');
        break;
      case ThemeMode.dark:
        await _prefs.setString(_keyThemeMode, 'dark');
        break;
      case ThemeMode.system:
        await _prefs.setString(_keyThemeMode, 'system');
        break;
    }
  }
}
