import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const _accessTokenKey = 'restaurant_access_token';
  static const _refreshTokenKey = 'restaurant_refresh_token';

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  Future<bool> hasSession() async {
    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();
    return (accessToken != null && accessToken.isNotEmpty) ||
        (refreshToken != null && refreshToken.isNotEmpty);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }
}