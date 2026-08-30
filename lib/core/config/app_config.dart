import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'JETKIZ_API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    final configured = _configuredBaseUrl.trim();

    if (configured.isNotEmpty) {
      if (kReleaseMode && !_isSafeReleaseUrl(configured)) {
        throw StateError(
          'JETKIZ_API_BASE_URL must use HTTPS and must not point to localhost in release builds.',
        );
      }
      return configured;
    }

    return kReleaseMode
        ? 'https://api.jetkiz.asia'
        : 'http://127.0.0.1:3000';
  }

  static bool _isSafeReleaseUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty) {
      return false;
    }

    final host = uri.host.toLowerCase();
    return host != 'localhost' &&
        host != '127.0.0.1' &&
        host != '10.0.2.2' &&
        host != '0.0.0.0';
  }
}
