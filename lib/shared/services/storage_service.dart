import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';

/// Storage service providing persistent local settings and secure token storage
class StorageService {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  StorageService(this._prefs, this._secureStorage);

  static const String _keyApiToken = 'secure_api_token';
  static const String _keyAdminToken = 'secure_admin_token';
  static const String _keyBaseUrl = 'pref_api_base_url';
  static const String _keyThemeMode = 'pref_theme_mode';

  static Future<StorageService> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage(aOptions: AndroidOptions());
    return StorageService(prefs, secureStorage);
  }

  /// Get active API user token
  /// Precedence: User-saved token -> Compile-time defaultApiToken
  Future<String> getApiToken() async {
    try {
      final saved = await _secureStorage.read(key: _keyApiToken);
      if (saved != null && saved.trim().isNotEmpty) {
        return saved.trim();
      }
    } catch (_) {
      // Fallback on secure storage error
    }
    return AppConfig.defaultApiToken;
  }

  /// Save new API user token securely
  Future<void> saveApiToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      await _secureStorage.delete(key: _keyApiToken);
    } else {
      await _secureStorage.write(key: _keyApiToken, value: trimmed);
    }
  }

  /// Get active Admin token (only used in admin diagnostics)
  Future<String?> getAdminToken() async {
    try {
      return await _secureStorage.read(key: _keyAdminToken);
    } catch (_) {
      return null;
    }
  }

  /// Save admin token securely
  Future<void> saveAdminToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      await _secureStorage.delete(key: _keyAdminToken);
    } else {
      await _secureStorage.write(key: _keyAdminToken, value: trimmed);
    }
  }

  /// Get active Base URL
  /// Precedence: User-saved override -> Compile-time apiBaseUrl
  String getBaseUrl() {
    final saved = _prefs.getString(_keyBaseUrl);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim();
    }
    return AppConfig.apiBaseUrl;
  }

  /// Save Base URL override
  Future<void> saveBaseUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      await _prefs.remove(_keyBaseUrl);
    } else {
      await _prefs.setString(_keyBaseUrl, trimmed);
    }
  }

  /// Reset Base URL override to default
  Future<void> resetBaseUrl() async {
    await _prefs.remove(_keyBaseUrl);
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
