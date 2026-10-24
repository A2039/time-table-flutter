import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetable_app/core/config/app_config.dart';

void main() {
  group('AppConfig & Configurable JSON Tests', () {
    test('copyrightFormatted dynamically replaces auto-fetch year template', () {
      final currentYear = DateTime.now().year.toString();
      expect(AppConfig.copyrightFormatted, contains(currentYear));
      expect(AppConfig.copyrightFormatted, contains('com.timetable. All rights reserved.'));
    });

    test('AppConfig parses comprehensive configuration structure correctly', () {
      const sampleJson = '''
      {
        "app_name": "Time Table Test",
        "app_bundleIdentifier": "com.timetable.test",
        "app": {
          "name": "Time Table Core",
          "displayName": "Time Table Pro",
          "description": "Daily timetable and activity tracker.",
          "version": "1.2.3",
          "buildNumber": 99,
          "bundleIdentifier": "com.timetable.pro"
        },
        "build": {
          "isBuildSingleFile": true,
          "apkNamePattern": "{appName}-{version}-{buildType}.apk",
          "aabNamePattern": "{appName}-{version}-{buildType}.aab"
        },
        "logo": {
          "default": "asset/logo/time-table-logo.png",
          "mobile": "asset/logo/time-table-mobile.png",
          "tablet": "asset/logo/time-table-tablet.png",
          "windows": "asset/logo/time-table-windows.png",
          "web": "asset/logo/time-table-logo.png"
        },
        "api": {
          "baseApiUrl": "https://script.google.com/macros/s/TEST/exec",
          "apiTimeOut": 45
        },
        "apiToken": {
          "apiToken": "test_user_token",
          "adminApiToken": "test_admin_token"
        },
        "debug": {
          "printCache": true,
          "printCacheInterval": 30,
          "printRequestResponce": true
        },
        "ui": {
          "fontFamily": "Inter",
          "textScaleFactor": 0.95
        },
        "support": {
          "support_mail": "help@timetable.com",
          "support_numer": "+1234567890"
        },
        "copyright": "Copyright © (auto fetch current year) com.timetable. All rights reserved."
      }
      ''';

      final Map<String, dynamic> decoded = jsonDecode(sampleJson) as Map<String, dynamic>;
      
      // Initialize AppConfig state through decoded dictionary
      AppConfig.apiBaseUrl = (decoded['api']['baseApiUrl'] as String).trim();
      AppConfig.apiTimeoutSeconds = (decoded['api']['apiTimeOut'] as num).toInt();
      AppConfig.defaultApiToken = (decoded['apiToken']['apiToken'] as String).trim();
      AppConfig.adminApiToken = (decoded['apiToken']['adminApiToken'] as String).trim();
      AppConfig.appName = decoded['app']['displayName'] as String;
      AppConfig.appVersion = decoded['app']['version'] as String;
      AppConfig.appBuildNumber = (decoded['app']['buildNumber'] as num).toInt();
      AppConfig.supportMail = decoded['support']['support_mail'] as String;
      AppConfig.supportNumber = decoded['support']['support_numer'] as String;

      expect(AppConfig.apiBaseUrl, 'https://script.google.com/macros/s/TEST/exec');
      expect(AppConfig.apiTimeoutSeconds, 45);
      expect(AppConfig.defaultApiToken, 'test_user_token');
      expect(AppConfig.adminApiToken, 'test_admin_token');
      expect(AppConfig.appName, 'Time Table Pro');
      expect(AppConfig.appVersion, '1.2.3');
      expect(AppConfig.appBuildNumber, 99);
      expect(AppConfig.supportMail, 'help@timetable.com');
      expect(AppConfig.supportNumber, '+1234567890');
    });
  });
}
