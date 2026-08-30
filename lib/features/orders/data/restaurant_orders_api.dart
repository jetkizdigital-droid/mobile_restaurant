import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/cms/data/restaurant_app_cms_session.dart';

class RestaurantOrdersApi {
  RestaurantOrdersApi({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> getOrders({
    int page = 1,
    int limit = 100,
    String? q,
    String? status,
    bool fetchAllPages = true,
  }) async {
    final safeLimit = limit.clamp(1, 100).toInt();
    final result = <Map<String, dynamic>>[];
    var currentPage = page < 1 ? 1 : page;

    // The restaurant order screen historically loaded only page 1. Fetch all
    // pages transparently so filters cannot silently hide older orders. The
    // upper bound prevents a malformed backend response from causing a loop.
    for (var requestIndex = 0; requestIndex < 20; requestIndex++) {
      final items = await _getOrdersPage(
        page: currentPage,
        limit: safeLimit,
        q: q,
        status: status,
      );

      result.addAll(items);

      if (!fetchAllPages || items.length < safeLimit) break;
      currentPage += 1;
    }

    return result;
  }

  Future<List<Map<String, dynamic>>> _getOrdersPage({
    required int page,
    required int limit,
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

    return _extractOrders(response);
  }

  List<Map<String, dynamic>> _extractOrders(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      for (final key in const ['items', 'data', 'orders', 'result']) {
        final dynamic raw = map[key];
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }

    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> getOrderById(String id) async {
    final dynamic response = await _apiClient.get('/orders/$id');

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception('Некорректный ответ сервера при загрузке заказа');
  }

  Future<Map<String, dynamic>> updateOrderStatus({
    required String id,
    required String status,
  }) async {
    final normalizedStatus = status.trim().toUpperCase();
    final cms = RestaurantAppCmsSession.instance;

    if (normalizedStatus == 'ACCEPTED' &&
        !cms.featureEnabled('ACCEPT_ORDERS_ENABLED')) {
      throw Exception(
        cms.featureReason('ACCEPT_ORDERS_ENABLED') ??
            'Приём заказов временно недоступен',
      );
    }

    if (normalizedStatus == 'REJECTED' &&
        !cms.featureEnabled('REJECT_ORDERS_ENABLED')) {
      throw Exception(
        cms.featureReason('REJECT_ORDERS_ENABLED') ??
            'Отклонение заказов временно недоступно',
      );
    }

    final dynamic response = await _apiClient.patch(
      '/orders/$id/status',
      <String, dynamic>{'status': normalizedStatus},
    );

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

    final dynamic response = await _apiClient.post(
      '/orders/$id/verify-pickup',
      <String, dynamic>{'code': normalizedCode},
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception('Некорректный ответ сервера при выдаче заказа');
  }

  Future<Map<String, dynamic>> assignCourier({
    required String id,
    required String courierUserId,
  }) async {
    final dynamic response = await _apiClient.patch(
      '/orders/$id/assign-courier',
      <String, dynamic>{'courierUserId': courierUserId},
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception('Некорректный ответ сервера при назначении курьера');
  }

  Future<Map<String, dynamic>> unassignCourier({required String id}) async {
    final dynamic response = await _apiClient.patch(
      '/orders/$id/unassign-courier',
      <String, dynamic>{},
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception('Некорректный ответ сервера при снятии курьера');
  }

  Future<Map<String, dynamic>> autoAssignCourier({required String id}) async {
    final dynamic response = await _apiClient.patch(
      '/orders/$id/auto-assign',
      <String, dynamic>{},
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception(
      'Некорректный ответ сервера при автоматическом назначении курьера',
    );
  }
}
