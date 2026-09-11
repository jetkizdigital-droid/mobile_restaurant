import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_storage.dart';

// JETKIZ RESTAURANT APP
// Backend-first auth API for restaurant mobile app.
class AuthApi {
  final ApiClient _client = ApiClient.instance;
  final AuthStorage _storage = AuthStorage();

  Future<void> requestCode({required String phone}) async {
    await _client.post(
      '/auth/request-code',
      {'phone': phone},
      authRequired: false,
    );
  }

  Future<Map<String, dynamic>> verifyCode({
    required String phone,
    required String code,
  }) async {
    final response = await _client.post(
      '/auth/verify-code',
      {'phone': phone, 'code': code},
      authRequired: false,
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('Не удалось выполнить вход. Попробуйте ещё раз.');
    }

    await _saveTokensFromResponse(response);
    await _syncSelectedRestaurantFromAuthPayload(response);
    return response;
  }

  Future<Map<String, dynamic>> loginRestaurantWithPassword({
    required String phone,
    required String password,
  }) async {
    final response = await _client.post(
      '/auth/restaurant/login-password',
      {'phone': phone, 'password': password},
      authRequired: false,
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('Не удалось выполнить вход. Попробуйте ещё раз.');
    }

    final passwordChangeRequired = response['passwordChangeRequired'] == true;
    if (!passwordChangeRequired) {
      await _saveTokensFromResponse(response);
      await _syncSelectedRestaurantFromAuthPayload(response);
    }

    return response;
  }

  Future<Map<String, dynamic>> changeRestaurantTemporaryPassword({
    required String phone,
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _client.post(
      '/auth/restaurant/change-password',
      {
        'phone': phone,
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
      authRequired: false,
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('Не удалось изменить пароль. Попробуйте ещё раз.');
    }

    await _saveTokensFromResponse(response);
    await _syncSelectedRestaurantFromAuthPayload(response);
    return response;
  }

  Future<Map<String, dynamic>> registerRestaurant({
    required String phone,
    required String code,
    required String nameRu,
    required String nameKk,
    required String address,
    required String workingHoursFrom,
    required String workingHoursTo,
  }) async {
    final response = await _client.post(
      '/restaurant-auth/register',
      {
        'phone': phone,
        'code': code,
        'nameRu': nameRu,
        'nameKk': nameKk,
        'address': address,
        'workingHoursFrom': workingHoursFrom,
        'workingHoursTo': workingHoursTo,
      },
      authRequired: false,
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('Не удалось завершить регистрацию. Попробуйте ещё раз.');
    }

    await _saveTokensFromResponse(response);
    await _syncSelectedRestaurantFromAuthPayload(response);
    return response;
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _client.get('/auth/me');

    if (response is! Map<String, dynamic>) {
      throw Exception('Не удалось загрузить данные аккаунта.');
    }

    await _syncSelectedRestaurantFromAuthPayload(response);
    return response;
  }

  Future<void> logout() async {
    await _client.post('/auth/logout', const <String, dynamic>{});
  }

  Future<void> _saveTokensFromResponse(Map<String, dynamic> response) async {
    final accessToken = response['accessToken']?.toString();
    final refreshToken = response['refreshToken']?.toString();

    if (accessToken != null &&
        accessToken.isNotEmpty &&
        refreshToken != null &&
        refreshToken.isNotEmpty) {
      await _storage.saveTokens(accessToken, refreshToken);
    }
  }

  Future<void> _syncSelectedRestaurantFromAuthPayload(
    Map<String, dynamic> payload,
  ) async {
    final restaurantIds = _extractRestaurantIds(payload);

    if (restaurantIds.isEmpty) {
      await _storage.clearSelectedRestaurantId();
      _client.clearSelectedRestaurantId();
      return;
    }

    final savedRestaurantId = await _storage.getSelectedRestaurantId();

    if (savedRestaurantId != null && restaurantIds.contains(savedRestaurantId)) {
      _client.setSelectedRestaurantId(savedRestaurantId);
      return;
    }

    final backendDefaultRestaurantId = _readString(payload['restaurantId']);

    final selectedRestaurantId =
        backendDefaultRestaurantId != null &&
                restaurantIds.contains(backendDefaultRestaurantId)
            ? backendDefaultRestaurantId
            : restaurantIds.first;

    await _storage.saveSelectedRestaurantId(selectedRestaurantId);
    _client.setSelectedRestaurantId(selectedRestaurantId);
  }

  List<String> _extractRestaurantIds(Map<String, dynamic> payload) {
    final ids = <String>{};

    final restaurantId = _readString(payload['restaurantId']);
    if (restaurantId != null) ids.add(restaurantId);

    final restaurantIdsRaw = payload['restaurantIds'];
    if (restaurantIdsRaw is List) {
      for (final item in restaurantIdsRaw) {
        final id = _readString(item);
        if (id != null) ids.add(id);
      }
    }

    final restaurantsRaw = payload['restaurants'];
    if (restaurantsRaw is List) {
      for (final item in restaurantsRaw) {
        if (item is Map) {
          final id = _readString(item['id']);
          if (id != null) ids.add(id);
        }
      }
    }

    final restaurantRaw = payload['restaurant'];
    if (restaurantRaw is Map) {
      final id = _readString(restaurantRaw['id']);
      if (id != null) ids.add(id);
    }

    final accessesRaw = payload['restaurantAccesses'];
    if (accessesRaw is List) {
      for (final item in accessesRaw) {
        if (item is Map) {
          final id = _readString(item['restaurantId']);
          if (id != null) ids.add(id);
        }
      }
    }

    return ids.toList();
  }

  String? _readString(dynamic value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }
}
