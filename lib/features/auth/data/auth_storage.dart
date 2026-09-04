import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _accessTokenKey = 'restaurant_access_token';
  static const _refreshTokenKey = 'restaurant_refresh_token';
  static const _selectedRestaurantIdKey = 'restaurant_selected_restaurant_id';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(key: _refreshTokenKey);
  }

  Future<bool> hasSession() async {
    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();

    return (accessToken != null && accessToken.isNotEmpty) ||
        (refreshToken != null && refreshToken.isNotEmpty);
  }

  Future<void> saveSelectedRestaurantId(String restaurantId) async {
    final normalized = restaurantId.trim();

    if (normalized.isEmpty) {
      await clearSelectedRestaurantId();
      return;
    }

    await _storage.write(key: _selectedRestaurantIdKey, value: normalized);
  }

  Future<String?> getSelectedRestaurantId() async {
    final value = await _storage.read(key: _selectedRestaurantIdKey);
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  Future<void> clearSelectedRestaurantId() async {
    await _storage.delete(key: _selectedRestaurantIdKey);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await clearSelectedRestaurantId();
  }
}
