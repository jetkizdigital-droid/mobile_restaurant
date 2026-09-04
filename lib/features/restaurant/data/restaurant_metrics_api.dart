import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/restaurant/domain/restaurant_metrics_data.dart';

class RestaurantMetricsApi {
  RestaurantMetricsApi({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<RestaurantMetricsData> getMetrics({
    required String restaurantId,
    int? days,
    String? from,
    String? to,
  }) async {
    final query = <String>[];

    if (days != null) {
      query.add('days=$days');
    }

    if (from != null && from.trim().isNotEmpty) {
      query.add('from=${Uri.encodeQueryComponent(from.trim())}');
    }

    if (to != null && to.trim().isNotEmpty) {
      query.add('to=${Uri.encodeQueryComponent(to.trim())}');
    }

    final path = query.isEmpty
        ? '/restaurants/$restaurantId/metrics'
        : '/restaurants/$restaurantId/metrics?${query.join('&')}';

    final response = await _apiClient.get(path);

    if (response is! Map) {
      throw Exception('Некорректный ответ сервера по статистике');
    }

    return RestaurantMetricsData.fromJson(Map<String, dynamic>.from(response));
  }
}
