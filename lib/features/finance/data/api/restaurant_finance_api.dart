import '../../../../core/network/api_client.dart';
import '../models/restaurant_finance_models.dart';

class RestaurantFinanceApi {
  const RestaurantFinanceApi(this._apiClient);

  final ApiClient _apiClient;

  Future<RestaurantFinanceResponse> getFinance({
    String period = '30d',
    String? startDate,
    String? endDate,
  }) async {
    final resolvedPeriod = _mapUiPeriodToBackend(period);

    final query = <String, String>{'period': resolvedPeriod};

    if (resolvedPeriod == 'custom') {
      final from = (startDate ?? '').trim();
      final to = (endDate ?? '').trim();

      if (from.isEmpty || to.isEmpty) {
        throw ArgumentError(
          'startDate and endDate are required for custom period',
        );
      }

      query['from'] = from;
      query['to'] = to;
    }

    final path = _buildPath('/finance/restaurant/me', query);

    final dynamic response = await _apiClient.get(path);
    final payload = _asMap(response);

    if (payload == null) {
      throw Exception('Некорректный ответ сервера по финансам');
    }

    await _mergeCurrentCommission(payload);
    return RestaurantFinanceResponse.fromJson(payload);
  }

  Future<void> _mergeCurrentCommission(Map<String, dynamic> payload) async {
    try {
      final dynamic profileResponse = await _apiClient.get('/restaurants/me');
      final profile = _asMap(profileResponse);
      if (profile == null) return;

      final restaurant = _asMap(payload['restaurant']) ?? <String, dynamic>{};
      if (profile.containsKey('restaurantCommissionPctOverride')) {
        restaurant['restaurantCommissionPctOverride'] =
            profile['restaurantCommissionPctOverride'];
      }
      if (profile.containsKey('effectiveRestaurantCommissionPct')) {
        restaurant['effectiveRestaurantCommissionPct'] =
            profile['effectiveRestaurantCommissionPct'];
      }
      payload['restaurant'] = restaurant;
    } catch (_) {
      // Finance data remains usable if the profile refresh is temporarily
      // unavailable. The screen will simply omit an unresolved current rate.
    }
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String _buildPath(String basePath, Map<String, String> query) {
    if (query.isEmpty) return basePath;

    final uri = Uri(path: basePath, queryParameters: query);

    return uri.toString();
  }

  String _mapUiPeriodToBackend(String value) {
    switch (value.trim().toLowerCase()) {
      case 'today':
        return 'today';
      case 'yesterday':
        return 'yesterday';
      case 'week':
      case '7d':
        return '7d';
      case 'month':
      case '30d':
        return '30d';
      case 'custom':
        return 'custom';
      default:
        return '30d';
    }
  }
}
