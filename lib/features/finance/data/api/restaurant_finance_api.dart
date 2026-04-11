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

    final query = <String, String>{
      'period': resolvedPeriod,
    };

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

    final path = _buildPath(
      '/finance/restaurant/me',
      query,
    );

    final dynamic response = await _apiClient.get(path);

    if (response is Map<String, dynamic>) {
      return RestaurantFinanceResponse.fromJson(response);
    }

    if (response is Map) {
      return RestaurantFinanceResponse.fromJson(
        Map<String, dynamic>.from(response),
      );
    }

    throw Exception('Некорректный ответ сервера по финансам');
  }

  String _buildPath(String basePath, Map<String, String> query) {
    if (query.isEmpty) return basePath;

    final uri = Uri(
      path: basePath,
      queryParameters: query,
    );

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