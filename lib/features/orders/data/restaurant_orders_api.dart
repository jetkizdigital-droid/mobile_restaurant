import 'package:jetkiz_restaurant/core/network/api_client.dart';

class RestaurantOrdersApi {
  RestaurantOrdersApi({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> getOrders({
    int page = 1,
    int limit = 20,
    String? q,
    String? status,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (q != null && q.trim().isNotEmpty) {
      query['q'] = q.trim();
    }

    if (status != null && status.trim().isNotEmpty && status != 'ALL') {
      query['status'] = status.trim();
    }

    final queryString = Uri(queryParameters: query).query;
    final path = queryString.isEmpty ? '/orders' : '/orders?$queryString';

    final dynamic response = await _apiClient.get(path);

    if (response is List) {
      return response
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (response is Map<String, dynamic>) {
      final dynamic items = response['items'];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      final dynamic data = response['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      final dynamic orders = response['orders'];
      if (orders is List) {
        return orders
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      final dynamic result = response['result'];
      if (result is List) {
        return result
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> getOrderById(String id) async {
    final path = '/orders/$id';

    final dynamic response = await _apiClient.get(path);

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception('Некорректный ответ сервера при загрузке заказа');
  }

  Future<Map<String, dynamic>> updateOrderStatus({
    required String id,
    required String status,
  }) async {
    final path = '/orders/$id/status';

    final dynamic response = await _apiClient.patch(path, <String, dynamic>{
      'status': status,
    });

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception('Некорректный ответ сервера при обновлении заказа');
  }

  Future<Map<String, dynamic>> verifyPickup({
    required String id,
    required String pickupCode,
  }) async {
    final normalizedCode = pickupCode.trim();
    if (normalizedCode.isEmpty) {
      throw Exception('Введите код клиента');
    }

    final path = '/orders/$id/verify-pickup';

    final dynamic response = await _apiClient.post(path, <String, dynamic>{
      'pickupCode': normalizedCode,
    });

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception('Некорректный ответ сервера при выдаче заказа');
  }

  Future<Map<String, dynamic>> assignCourier({
    required String id,
    required String courierUserId,
  }) async {
    final path = '/orders/$id/assign-courier';

    final dynamic response = await _apiClient.patch(path, <String, dynamic>{
      'courierUserId': courierUserId,
    });

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception('Некорректный ответ сервера при назначении курьера');
  }

  Future<Map<String, dynamic>> unassignCourier({required String id}) async {
    final path = '/orders/$id/unassign-courier';

    final dynamic response = await _apiClient.patch(path, <String, dynamic>{});

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception('Некорректный ответ сервера при снятии курьера');
  }

  Future<Map<String, dynamic>> autoAssignCourier({required String id}) async {
    final path = '/orders/$id/auto-assign';

    final dynamic response = await _apiClient.patch(path, <String, dynamic>{});

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception(
      'Некорректный ответ сервера при автоматическом назначении курьера',
    );
  }
}
