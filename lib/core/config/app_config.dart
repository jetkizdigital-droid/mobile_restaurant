import 'package:flutter/foundation.dart';

class AppConfig {
  static const String productionBaseUrl = 'https://api.jetkiz.asia';

  static const String _configuredBaseUrl = String.fromEnvironment(
    'JETKIZ_API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    final configured = _configuredBaseUrl.trim();

    if (kReleaseMode) {
      if (configured.isEmpty) return productionBaseUrl;
      if (!_isProductionReleaseUrl(configured)) {
        throw StateError(
          'Release API origin does not match the JETKIZ production origin.',
        );
      }
      return productionBaseUrl;
    }

    return configured.isNotEmpty ? configured : 'http://127.0.0.1:3000';
  }

  static bool _isProductionReleaseUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return false;

    final normalizedPath = uri.path.isEmpty ? '/' : uri.path;
    return uri.scheme.toLowerCase() == 'https' &&
        uri.host.toLowerCase() == 'api.jetkiz.asia' &&
        (uri.port == 443) &&
        normalizedPath == '/' &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }
}
