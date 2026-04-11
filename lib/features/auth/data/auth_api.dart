import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_storage.dart';

// JETKIZ RESTAURANT APP
// Backend-first auth API for restaurant mobile app.
//
// IMPORTANT:
// - SMS code is requested through the shared endpoint: POST /auth/request-code
// - Regular login is completed through: POST /auth/verify-code
// - Restaurant registration is completed through: POST /restaurant-auth/register
//
// WHY THIS FILE EXISTS:
// - UI screens must NOT call ApiClient directly
// - all auth/registration HTTP logic stays here
// - if backend contract changes, update this file first
//
// CURRENT REGISTRATION PAYLOAD EXPECTED BY BACKEND:
// - phone
// - code
// - nameRu
// - nameKk
// - address
// - workingHoursFrom
// - workingHoursTo
//
// FUTURE GPT / DEV NOTE:
// If restaurant registration stops working:
// 1. check /auth/request-code
// 2. check /restaurant-auth/register
// 3. verify payload keys here before changing UI
class AuthApi {
  final ApiClient _client = ApiClient.instance;
  final AuthStorage _storage = AuthStorage();

  Future<void> requestCode({required String phone}) async {
    await _client.post(
      '/auth/request-code',
      {
        'phone': phone,
      },
      authRequired: false,
    );
  }

  Future<Map<String, dynamic>> verifyCode({
    required String phone,
    required String code,
  }) async {
    final response = await _client.post(
      '/auth/verify-code',
      {
        'phone': phone,
        'code': code,
      },
      authRequired: false,
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('Некорректный формат ответа verify-code');
    }

    final accessToken = response['accessToken']?.toString();
    final refreshToken = response['refreshToken']?.toString();

    if (accessToken != null &&
        accessToken.isNotEmpty &&
        refreshToken != null &&
        refreshToken.isNotEmpty) {
      await _storage.saveTokens(accessToken, refreshToken);
    }

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
      throw Exception('Некорректный формат ответа restaurant-auth/register');
    }

    final accessToken = response['accessToken']?.toString();
    final refreshToken = response['refreshToken']?.toString();

    if (accessToken != null &&
        accessToken.isNotEmpty &&
        refreshToken != null &&
        refreshToken.isNotEmpty) {
      await _storage.saveTokens(accessToken, refreshToken);
    }

    return response;
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _client.get('/auth/me');

    if (response is! Map<String, dynamic>) {
      throw Exception('Некорректный формат ответа users/me');
    }

    return response;
  }
}