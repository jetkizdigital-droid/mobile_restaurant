import 'package:jetkiz_restaurant/core/network/api_client.dart';

class RestaurantStaffApi {
  RestaurantStaffApi({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<Map<String, dynamic>> list() async {
    final response = await _client.get('/restaurants/me/staff');
    return _asMap(response, 'Не удалось загрузить сотрудников.');
  }

  Future<Map<String, dynamic>> create({
    required String phone,
    required String firstName,
    String? lastName,
    required String role,
    required List<String> restaurantIds,
    required String temporaryPassword,
  }) async {
    final response = await _client.post('/restaurants/me/staff', {
      'phone': phone,
      'firstName': firstName,
      if ((lastName ?? '').trim().isNotEmpty) 'lastName': lastName!.trim(),
      'role': role,
      'restaurantIds': restaurantIds,
      'temporaryPassword': temporaryPassword,
    });
    return _asMap(response, 'Не удалось добавить сотрудника.');
  }

  Future<Map<String, dynamic>> update({
    required String userId,
    String? firstName,
    String? lastName,
    String? role,
    List<String>? restaurantIds,
    bool? isActive,
  }) async {
    final response = await _client.patch('/restaurants/me/staff/$userId', {
      if (firstName != null) 'firstName': firstName.trim(),
      if (lastName != null) 'lastName': lastName.trim(),
      if (role != null) 'role': role,
      if (restaurantIds != null) 'restaurantIds': restaurantIds,
      if (isActive != null) 'isActive': isActive,
    });
    return _asMap(response, 'Не удалось изменить сотрудника.');
  }

  Future<Map<String, dynamic>> deactivate(String userId) async {
    final response = await _client.post(
      '/restaurants/me/staff/$userId/deactivate',
      const <String, dynamic>{},
    );
    return _asMap(response, 'Не удалось отключить сотрудника.');
  }

  Future<Map<String, dynamic>> resetTemporaryPassword({
    required String userId,
    required String temporaryPassword,
  }) async {
    final response = await _client.post(
      '/restaurants/me/staff/$userId/reset-temporary-password',
      {'temporaryPassword': temporaryPassword},
    );
    return _asMap(response, 'Не удалось выдать новый временный пароль.');
  }

  Map<String, dynamic> _asMap(dynamic response, String message) {
    if (response is Map<String, dynamic>) return response;
    if (response is Map) return Map<String, dynamic>.from(response);
    throw Exception(message);
  }
}
