# JETKIZ Restaurant App Audit Document

Generated at: 2026-05-03 00:09:49
Project root: D:\Projects\jetkiz_restaurant

## Audit goal

роверить ресторанское приложение перед релизом: авторизация ресторана, профиль, меню, заказы, статусы, push, API-интеграция, ошибки, безопасность и готовность к production.

## What to check

- Restaurant auth / login / token / refresh
- Restaurant profile / status / working hours
- Menu / products / availability
- Incoming orders
- Order details
- Accept / reject / cooking / ready flow
- Push notifications for restaurant
- API client and backend endpoints
- Empty/loading/error states
- Role protection and token handling
- Release risks

## Excluded intentionally

Secrets and platform keys are not included:
- .env
- firebase_options.dart
- google-services.json
- GoogleService-Info.plist
- keystore files
- signing configs

## Project file tree: restaurant-related files

- lib/app/app.dart
- lib/core/config/app_config.dart
- lib/core/navigation/app_page_route.dart
- lib/core/network/api_client.dart
- lib/features/auth/data/auth_api.dart
- lib/features/auth/data/auth_storage.dart
- lib/features/auth/presentation/pages/restaurant_auth_page.dart
- lib/features/auth/presentation/pages/restaurant_entry_page.dart
- lib/features/auth/presentation/pages/restaurant_sms_page.dart
- lib/features/finance/data/api/restaurant_finance_api.dart
- lib/features/finance/data/models/restaurant_finance_models.dart
- lib/features/finance/presentation/pages/restaurant_finance_page.dart
- lib/features/menu/data/restaurant_menu_api.dart
- lib/features/menu/domain/restaurant_menu_models.dart
- lib/features/menu/presentation/pages/createMenuCategoryPage.dart
- lib/features/menu/presentation/pages/restaurant_menu_page.dart
- lib/features/menu/presentation/pages/upsertMenuItemPage.dart
- lib/features/menu/presentation/widgets/menu_item_card.dart
- lib/features/menu/presentation/widgets/menuCreateActionSheet.dart
- lib/features/navigation/presentation/pages/restaurant_shell_page.dart
- lib/features/navigation/presentation/widgets/restaurant_bottom_bar.dart
- lib/features/orders/data/restaurant_orders_api.dart
- lib/features/orders/domain/restaurant_order.dart
- lib/features/orders/domain/restaurant_order_details.dart
- lib/features/orders/presentation/pages/restaurant_order_details_page.dart
- lib/features/orders/presentation/pages/restaurant_orders_page.dart
- lib/features/orders/presentation/widgets/order_card.dart
- lib/features/restaurant/data/restaurant_api.dart
- lib/features/restaurant/data/restaurant_metrics_api.dart
- lib/features/restaurant/domain/restaurant_metrics_data.dart
- lib/features/restaurant/domain/restaurant_profile_data.dart
- lib/features/restaurant_profile/domain/restaurant_profile_data.dart
- lib/features/restaurant_profile/presentation/pages/restaurant_profile_page.dart
- lib/features/restaurant_profile/widgets/restaurant_statistics_tab.dart
- lib/features/reviews/data/restaurant_reviews_api.dart
- lib/features/reviews/domain/restaurant_review.dart
- lib/features/reviews/presentation/pages/restaurant_reviews_page.dart
- lib/main.dart
- pubspec.yaml

# File contents


## FILE: lib\app\app.dart

- Size: 1211 bytes

``dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../features/auth/presentation/pages/restaurant_entry_page.dart';

class JetkizRestaurantApp extends StatelessWidget {
  const JetkizRestaurantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jetkiz Restaurant',
      locale: const Locale('ru'),
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFF0B0B0C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF489F2A),
          secondary: Color(0xFF489F2A),
          surface: Color(0xFF151517),
        ),
      ),
      home: const RestaurantEntryPage(),
    );
  }
}
``

## FILE: lib\core\config\app_config.dart

- Size: 551 bytes

``dart
class AppConfig {
  // JETKIZ RESTAURANT APP
  // Физическое Android-устройство через USB:
  // backend локально на ПК, доступ через adb reverse tcp:3000 tcp:3000
  static const String baseUrl = String.fromEnvironment(
    'JETKIZ_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3000',
  );

  // Для эмулятора Android:
  // static const String baseUrl = 'http://10.0.2.2:3000';

  // Для Wi-Fi теста:
  // static const String baseUrl = 'http://192.168.1.100:3000';
}

``

## FILE: lib\core\navigation\app_page_route.dart

- Size: 1058 bytes

``dart
import 'package:flutter/material.dart';

class AppPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  AppPageRoute({required this.page})
    : super(
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final offsetAnimation =
              Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );

          final fadeAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
      );
}



``

## FILE: lib\core\network\api_client.dart

- Size: 14118 bytes

``dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:jetkiz_restaurant/core/config/app_config.dart';
import '../../features/auth/data/auth_storage.dart';

class ApiClient {
  ApiClient._internal();

  static final ApiClient instance = ApiClient._internal();
  factory ApiClient() => instance;

  final http.Client _http = http.Client();
  final AuthStorage _storage = AuthStorage();

  Future<dynamic> get(String path, {bool authRequired = true}) async {
    return _send(method: 'GET', path: path, authRequired: authRequired);
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool authRequired = true,
  }) async {
    return _send(
      method: 'POST',
      path: path,
      body: body,
      authRequired: authRequired,
    );
  }

  Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    bool authRequired = true,
  }) async {
    return _send(
      method: 'PATCH',
      path: path,
      body: body,
      authRequired: authRequired,
    );
  }

  Future<dynamic> put(
    String path,
    Map<String, dynamic> body, {
    bool authRequired = true,
  }) async {
    return _send(
      method: 'PUT',
      path: path,
      body: body,
      authRequired: authRequired,
    );
  }

  Future<dynamic> delete(String path, {bool authRequired = true}) async {
    return _send(method: 'DELETE', path: path, authRequired: authRequired);
  }

  Future<dynamic> uploadFile(
    String path, {
    required File file,
    String fieldName = 'file',
    bool authRequired = true,
  }) async {
    return _sendMultipart(
      path: path,
      file: file,
      fieldName: fieldName,
      authRequired: authRequired,
    );
  }

  Future<dynamic> uploadFiles(
    String path, {
    File? mainFile,
    List<File> files = const [],
    String mainFieldName = 'main',
    String filesFieldName = 'files',
    bool authRequired = true,
    bool isRetryAfterRefresh = false,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}$path');

    developer.log(
      'API Multipart MULTI Request: POST ${uri.toString()}',
      name: 'ApiClient',
    );

    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = 'application/json';

      if (authRequired) {
        final accessToken = await _storage.getAccessToken();
        if (accessToken != null && accessToken.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $accessToken';
        }
      }

      if (mainFile != null) {
        developer.log(
          'API Multipart MAIN File: ${mainFile.path}',
          name: 'ApiClient',
        );
        request.files.add(
          await _createMultipart(mainFieldName, mainFile),
        );
      }

      for (final file in files) {
        developer.log(
          'API Multipart EXTRA File: ${file.path}',
          name: 'ApiClient',
        );
        request.files.add(
          await _createMultipart(filesFieldName, file),
        );
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception('Превышено время ожидания'),
      );

      final response = await http.Response.fromStream(streamedResponse);

      developer.log(
        'API Multipart MULTI Response [${response.statusCode}]: ${response.body}',
        name: 'ApiClient',
      );

      if (response.statusCode == 401 && authRequired && !isRetryAfterRefresh) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          return uploadFiles(
            path,
            mainFile: mainFile,
            files: files,
            mainFieldName: mainFieldName,
            filesFieldName: filesFieldName,
            authRequired: authRequired,
            isRetryAfterRefresh: true,
          );
        }
      }

      return _handleResponse(response);
    } on SocketException {
      throw Exception('Нет подключения к серверу');
    } on TimeoutException {
      throw Exception('Превышено время ожидания');
    } catch (e) {
      throw Exception('Ошибка загрузки файлов: ${e.toString()}');
    }
  }

  Future<dynamic> _send({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    required bool authRequired,
    bool isRetryAfterRefresh = false,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}$path');

    developer.log('API Request: $method ${uri.toString()}', name: 'ApiClient');
    if (body != null) {
      developer.log('API Payload: ${jsonEncode(body)}', name: 'ApiClient');
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (authRequired) {
      final accessToken = await _storage.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    }

    late http.Response response;

    try {
      switch (method) {
        case 'GET':
          response = await _http
              .get(uri, headers: headers)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw Exception('Превышено время ожидания'),
              );
          break;
        case 'POST':
          response = await _http
              .post(
                uri,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw Exception('Превышено время ожидания'),
              );
          break;
        case 'PATCH':
          response = await _http
              .patch(
                uri,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw Exception('Превышено время ожидания'),
              );
          break;
        case 'PUT':
          response = await _http
              .put(
                uri,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw Exception('Превышено время ожидания'),
              );
          break;
        case 'DELETE':
          response = await _http
              .delete(uri, headers: headers)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw Exception('Превышено время ожидания'),
              );
          break;
        default:
          throw Exception('Unsupported method: $method');
      }

      developer.log(
        'API Response [${response.statusCode}]: ${response.body}',
        name: 'ApiClient',
      );
    } on SocketException {
      throw Exception('Нет подключения к серверу');
    } on TimeoutException {
      throw Exception('Превышено время ожидания');
    } catch (e) {
      throw Exception('Ошибка сети: ${e.toString()}');
    }

    if (response.statusCode == 401 && authRequired && !isRetryAfterRefresh) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _send(
          method: method,
          path: path,
          body: body,
          authRequired: authRequired,
          isRetryAfterRefresh: true,
        );
      }
    }

    return _handleResponse(response);
  }

  Future<dynamic> _sendMultipart({
    required String path,
    required File file,
    required String fieldName,
    required bool authRequired,
    bool isRetryAfterRefresh = false,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}$path');

    developer.log(
      'API Multipart Request: POST ${uri.toString()}',
      name: 'ApiClient',
    );
    developer.log(
      'API Multipart File: ${file.path}',
      name: 'ApiClient',
    );

    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = 'application/json';

      if (authRequired) {
        final accessToken = await _storage.getAccessToken();
        if (accessToken != null && accessToken.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $accessToken';
        }
      }

      request.files.add(
        await _createMultipart(fieldName, file),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception('Превышено время ожидания'),
      );

      final response = await http.Response.fromStream(streamedResponse);

      developer.log(
        'API Multipart Response [${response.statusCode}]: ${response.body}',
        name: 'ApiClient',
      );

      if (response.statusCode == 401 && authRequired && !isRetryAfterRefresh) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          return _sendMultipart(
            path: path,
            file: file,
            fieldName: fieldName,
            authRequired: authRequired,
            isRetryAfterRefresh: true,
          );
        }
      }

      return _handleResponse(response);
    } on SocketException {
      throw Exception('Нет подключения к серверу');
    } on TimeoutException {
      throw Exception('Превышено время ожидания');
    } catch (e) {
      throw Exception('Ошибка загрузки файла: ${e.toString()}');
    }
  }

  Future<http.MultipartFile> _createMultipart(
    String field,
    File file,
  ) async {
    final fileName = file.path.split('/').last.toLowerCase();

    String mimeType = 'image/jpeg';
    String safeFileName = fileName;

    if (fileName.endsWith('.png')) {
      mimeType = 'image/png';
    } else if (fileName.endsWith('.webp')) {
      mimeType = 'image/webp';
    } else if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) {
      mimeType = 'image/jpeg';
    } else {
      safeFileName = '$fileName.jpg';
      mimeType = 'image/jpeg';
    }

    return http.MultipartFile.fromPath(
      field,
      file.path,
      filename: safeFileName,
      contentType: MediaType.parse(mimeType),
    );
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _storage.clearTokens();
      return false;
    }

    final uri = Uri.parse('${AppConfig.baseUrl}/auth/refresh');

    try {
      final response = await _http.post(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      final data = _decodeBody(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data is Map<String, dynamic>) {
        final accessToken = data['accessToken']?.toString();
        final newRefreshToken = data['refreshToken']?.toString();

        if (accessToken != null &&
            accessToken.isNotEmpty &&
            newRefreshToken != null &&
            newRefreshToken.isNotEmpty) {
          await _storage.saveTokens(accessToken, newRefreshToken);
          return true;
        }
      }
    } catch (_) {}

    await _storage.clearTokens();
    return false;
  }

  dynamic _handleResponse(http.Response response) {
    developer.log(
      'API Response: ${response.statusCode} for ${response.request?.url}',
      name: 'ApiClient',
    );

    final decoded = _decodeBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    String errorMessage;

    switch (response.statusCode) {
      case 400:
        errorMessage = 'Неверный запрос';
        break;
      case 401:
        errorMessage = 'Не авторизован';
        break;
      case 403:
        errorMessage = 'Доступ запрещён';
        break;
      case 404:
        errorMessage = 'Не найдено';
        break;
      case 408:
        errorMessage = 'Превышено время ожидания';
        break;
      case 422:
        errorMessage = 'Ошибка валидации';
        break;
      case 500:
        errorMessage = 'Ошибка сервера';
        break;
      case 502:
        errorMessage = 'Проблема шлюза';
        break;
      case 503:
        errorMessage = 'Сервис недоступен';
        break;
      default:
        errorMessage = 'Ошибка: ${response.statusCode}';
    }

    if (decoded is Map<String, dynamic>) {
      final serverMessage =
          decoded['message']?.toString() ??
          decoded['error']?.toString() ??
          decoded['detail']?.toString();

      if (serverMessage != null && serverMessage.isNotEmpty) {
        errorMessage = serverMessage;
      }
    }

    throw Exception(errorMessage);
  }

  dynamic _decodeBody(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }
}
``

## FILE: lib\features\auth\data\auth_api.dart

- Size: 3575 bytes

``dart
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
``

## FILE: lib\features\auth\data\auth_storage.dart

- Size: 1105 bytes

``dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _accessTokenKey = 'restaurant_access_token';
  static const _refreshTokenKey = 'restaurant_refresh_token';
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

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}

``

## FILE: lib\features\auth\presentation\pages\restaurant_auth_page.dart

- Size: 22015 bytes

``dart
import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_api.dart';
import 'restaurant_sms_page.dart';

enum RestaurantAuthTab { login, register }

class RestaurantAuthPage extends StatefulWidget {
  const RestaurantAuthPage({super.key});

  @override
  State<RestaurantAuthPage> createState() => _RestaurantAuthPageState();
}

class _RestaurantAuthPageState extends State<RestaurantAuthPage> {
  final AuthApi _authApi = AuthApi();

  RestaurantAuthTab _tab = RestaurantAuthTab.login;
  bool _isLoading = false;

  final TextEditingController _loginPhoneController = TextEditingController();
  final TextEditingController _registerPhoneController =
      TextEditingController();
  final TextEditingController _nameRuController = TextEditingController();
  final TextEditingController _nameKkController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  TimeOfDay _openTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 22, minute: 0);

  @override
  void dispose() {
    _loginPhoneController.dispose();
    _registerPhoneController.dispose();
    _nameRuController.dispose();
    _nameKkController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String _formatPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    String normalized = digits;
    if (normalized.startsWith('8')) {
      normalized = '7${normalized.substring(1)}';
    }
    if (!normalized.startsWith('7') && normalized.isNotEmpty) {
      normalized = '7$normalized';
    }
    if (normalized.length > 11) {
      normalized = normalized.substring(0, 11);
    }

    final buffer = StringBuffer('+7');
    if (normalized.length > 1) {
      buffer.write(
        ' (${normalized.substring(1, normalized.length >= 4 ? 4 : normalized.length)}',
      );
    }
    if (normalized.length >= 4) {
      buffer.write(')');
    }
    if (normalized.length >= 5) {
      buffer.write(
        ' ${normalized.substring(4, normalized.length >= 7 ? 7 : normalized.length)}',
      );
    }
    if (normalized.length >= 8) {
      buffer.write(
        '-${normalized.substring(7, normalized.length >= 9 ? 9 : normalized.length)}',
      );
    }
    if (normalized.length >= 10) {
      buffer.write(
        '-${normalized.substring(9, normalized.length >= 11 ? 11 : normalized.length)}',
      );
    }

    return buffer.toString();
  }

  String _normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return '';
    }

    String normalized = digits;

    if (normalized.startsWith('8')) {
      normalized = '7${normalized.substring(1)}';
    }

    if (!normalized.startsWith('7')) {
      normalized = '7$normalized';
    }

    if (normalized.length > 11) {
      normalized = normalized.substring(0, 11);
    }

    return '+$normalized';
  }

  bool _isValidPhone(String value) {
    return _normalizePhone(value).replaceAll('+', '').length == 11;
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _onPhoneChanged(TextEditingController controller, String raw) {
    final formatted = _formatPhone(raw);
    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _pickTime(bool isOpen) async {
    final initial = isOpen ? _openTime : _closeTime;

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF489F2A),
              surface: Color(0xFF121826),
              onPrimary: Colors.white,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isOpen) {
          _openTime = picked;
        } else {
          _closeTime = picked;
        }
      });
    }
  }

  Future<void> _submitLogin() async {
    final phone = _loginPhoneController.text.trim();

    if (!_isValidPhone(phone)) {
      _showError('Enter a valid phone number');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final normalizedPhone = _normalizePhone(phone);

      try {
        await _authApi.requestCode(phone: normalizedPhone);
      } catch (e, st) {
        debugPrint('ERROR in _submitLogin/requestCode: $e');
        debugPrintStack(stackTrace: st);
      }

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RestaurantSmsPage(
            phone: normalizedPhone,
            isNewUser: false,
            registerData: null,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitRegister() async {
    final phone = _registerPhoneController.text.trim();
    final nameRu = _nameRuController.text.trim();
    final nameKk = _nameKkController.text.trim();
    final address = _addressController.text.trim();
    final workingHoursFrom = _formatTime(_openTime);
    final workingHoursTo = _formatTime(_closeTime);

    if (!_isValidPhone(phone)) {
      _showError('Enter a valid phone number');
      return;
    }

    if (nameRu.isEmpty || nameKk.isEmpty || address.isEmpty) {
      _showError('Fill in all required fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final normalizedPhone = _normalizePhone(phone);

      try {
        await _authApi.requestCode(phone: normalizedPhone);
      } catch (e, st) {
        debugPrint('ERROR in _submitRegister/requestCode: $e');
        debugPrintStack(stackTrace: st);
      }

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RestaurantSmsPage(
            phone: normalizedPhone,
            isNewUser: true,
            registerData: {
              'nameRu': nameRu,
              'nameKk': nameKk,
              'address': address,
              'workingHoursFrom': workingHoursFrom,
              'workingHoursTo': workingHoursTo,
            },
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFB3261E),
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundTop = Color(0xFF0E1A2C);
    const backgroundBottom = Color(0xFF08101C);
    const panelColor = Color(0xFF121B2C);
    const borderColor = Color(0xFF22324A);
    const textMuted = Color(0xFF95A0B3);

    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundTop, Color(0xFF0B1524), backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: const Color(0xFF489F2A),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'jetkiz',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Jetkiz',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Restaurant account access',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: panelColor.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _AuthTabButton(
                              title: 'Login',
                              isActive: _tab == RestaurantAuthTab.login,
                              onTap: () {
                                setState(() {
                                  _tab = RestaurantAuthTab.login;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _AuthTabButton(
                              title: 'Register',
                              isActive: _tab == RestaurantAuthTab.register,
                              onTap: () {
                                setState(() {
                                  _tab = RestaurantAuthTab.register;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: panelColor.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _tab == RestaurantAuthTab.login
                            ? _buildLoginForm()
                            : _buildRegisterForm(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey('login_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Welcome back',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your phone number',
          style: TextStyle(color: Color(0xFF95A0B3), fontSize: 13),
        ),
        const SizedBox(height: 22),
        const _FieldLabel('Phone number'),
        const SizedBox(height: 8),
        _DarkTextField(
          controller: _loginPhoneController,
          hintText: '+7 (___) ___-__-__',
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          onChanged: (value) => _onPhoneChanged(_loginPhoneController, value),
        ),
        const SizedBox(height: 18),
        _GreenButton(
          text: _isLoading ? 'Sending...' : 'Send code',
          onPressed: _isLoading ? null : _submitLogin,
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      key: const ValueKey('register_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Register restaurant',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Fill in restaurant data',
          style: TextStyle(color: Color(0xFF95A0B3), fontSize: 13),
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Phone number'),
        const SizedBox(height: 8),
        _DarkTextField(
          controller: _registerPhoneController,
          hintText: '+7 (___) ___-__-__',
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          onChanged: (value) =>
              _onPhoneChanged(_registerPhoneController, value),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Restaurant name (RU)'),
                  const SizedBox(height: 8),
                  _DarkTextField(
                    controller: _nameRuController,
                    hintText: 'Restaurant name',
                    prefixIcon: Icons.storefront_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Restaurant name (KK)'),
                  const SizedBox(height: 8),
                  _DarkTextField(
                    controller: _nameKkController,
                    hintText: 'Restaurant name',
                    prefixIcon: Icons.storefront_outlined,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Address'),
        const SizedBox(height: 8),
        _DarkTextField(
          controller: _addressController,
          hintText: 'City, street, building',
          prefixIcon: Icons.location_on_outlined,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Open time'),
                  const SizedBox(height: 8),
                  _TimeField(
                    text: _formatTime(_openTime),
                    onTap: () => _pickTime(true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Close time'),
                  const SizedBox(height: 8),
                  _TimeField(
                    text: _formatTime(_closeTime),
                    onTap: () => _pickTime(false),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _GreenButton(
          text: _isLoading ? 'Sending...' : 'Continue',
          onPressed: _isLoading ? null : _submitRegister,
        ),
      ],
    );
  }
}

class _AuthTabButton extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _AuthTabButton({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 46,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF489F2A) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF95A0B3),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _DarkTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3950)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF6F7D91), fontSize: 14),
          prefixIcon: Icon(
            prefixIcon,
            color: const Color(0xFF8E9AAF),
            size: 20,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _TimeField({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF101827),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A3950)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.access_time_outlined,
              color: Color(0xFF8E9AAF),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Color(0xFF8E9AAF),
            ),
          ],
        ),
      ),
    );
  }
}

class _GreenButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const _GreenButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF489F2A),
          disabledBackgroundColor: const Color(0xFF489F2A).withValues(
            alpha: 0.6,
          ),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
``

## FILE: lib\features\auth\presentation\pages\restaurant_entry_page.dart

- Size: 1789 bytes

``dart
import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_api.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_storage.dart';
import 'package:jetkiz_restaurant/features/auth/presentation/pages/restaurant_auth_page.dart';
import 'package:jetkiz_restaurant/features/navigation/presentation/pages/restaurant_shell_page.dart';
import 'package:jetkiz_restaurant/core/navigation/app_page_route.dart';

class RestaurantEntryPage extends StatefulWidget {
  const RestaurantEntryPage({super.key});

  @override
  State<RestaurantEntryPage> createState() => _RestaurantEntryPageState();
}

class _RestaurantEntryPageState extends State<RestaurantEntryPage> {
  final AuthStorage _storage = AuthStorage();
  final AuthApi _authApi = AuthApi();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final bool hasSession = await _storage.hasSession();

    if (!hasSession) {
      _openLogin();
      return;
    }

    try {
      await _authApi.getMe();
      _openShell();
    } catch (_) {
      await _storage.clearTokens();
      _openLogin();
    }
  }

  void _openLogin() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      AppPageRoute<void>(
        page: const RestaurantAuthPage(),
      ),
    );
  }

  void _openShell() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      AppPageRoute<void>(
        page: const RestaurantShellPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0B0B0C),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF489F2A),
        ),
      ),
    );
  }
}

``

## FILE: lib\features\auth\presentation\pages\restaurant_sms_page.dart

- Size: 12738 bytes

``dart
// JETKIZ RESTAURANT APP
// SMS verification page for restaurant auth.
//
// FLOW:
// 1. request code on auth screen
// 2. open this page
// 3. verify code
// 4. if isNewUser == true -> backend finishes registration
// 5. if isNewUser == false -> normal login

import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/session/restaurant_context.dart';
import 'package:jetkiz_restaurant/core/session/session_manager.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_api.dart';
import 'package:jetkiz_restaurant/features/navigation/presentation/pages/restaurant_shell_page.dart';

class RestaurantSmsPage extends StatefulWidget {
  final String phone;
  final bool isNewUser;
  final Map<String, dynamic>? registerData;

  const RestaurantSmsPage({
    super.key,
    required this.phone,
    required this.isNewUser,
    this.registerData,
  });

  @override
  State<RestaurantSmsPage> createState() => _RestaurantSmsPageState();
}

class _RestaurantSmsPageState extends State<RestaurantSmsPage> {
  final AuthApi _authApi = AuthApi();
  final TextEditingController _codeController = TextEditingController();

  bool _isLoading = false;
  bool _isResending = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    debugPrint('[_verifyCode] code: $code');

    if (code.isEmpty) {
      _showError('Введите код');
      debugPrint('[_verifyCode] код пустой');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final normalizedPhone = widget.phone;
      final isNewUser = widget.isNewUser;
      final registerData = widget.registerData;

      debugPrint(
        '[_verifyCode] normalizedPhone: $normalizedPhone, isNewUser: $isNewUser',
      );

      if (isNewUser && registerData != null) {
        debugPrint('[_verifyCode] Registering restaurant...');
        await _authApi.registerRestaurant(
          phone: normalizedPhone,
          code: code,
          nameRu: (registerData['nameRu'] ?? '').toString(),
          nameKk: (registerData['nameKk'] ?? '').toString(),
          address: (registerData['address'] ?? '').toString(),
          workingHoursFrom: (registerData['workingHoursFrom'] ?? '').toString(),
          workingHoursTo: (registerData['workingHoursTo'] ?? '').toString(),
        );
        debugPrint('[_verifyCode] registerRestaurant success');
      } else {
        debugPrint('[_verifyCode] Verifying code...');
        await _authApi.verifyCode(
          phone: normalizedPhone,
          code: code,
        );
        debugPrint('[_verifyCode] verifyCode success');
      }

      final me = await _authApi.getMe();
      debugPrint('ME RESPONSE: $me');

      final restaurantId = resolveRestaurantIdFromMe(me);
      debugPrint('restaurantId: $restaurantId');

      if (restaurantId == null || restaurantId.isEmpty) {
        debugPrint('restaurantId is NULL/EMPTY > backend не вернул привязку');
        _showError('У аккаунта не найден ресторан');
        return;
      }

      SessionManager.restaurantId = restaurantId;

      if (!mounted) return;

      debugPrint('[_verifyCode] Navigation to RestaurantShellPage');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RestaurantShellPage()),
        (route) => false,
      );
    } catch (e, st) {
      debugPrint('[_verifyCode] ERROR: $e');
      debugPrintStack(stackTrace: st);
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);

    try {
      await _authApi.requestCode(phone: widget.phone);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Код отправлен повторно'),
        ),
      );
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFB3261E),
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundTop = Color(0xFF0E1A2C);
    const backgroundBottom = Color(0xFF08101C);
    const panelColor = Color(0xFF121B2C);
    const borderColor = Color(0xFF22324A);
    const textMuted = Color(0xFF95A0B3);

    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              backgroundTop,
              Color(0xFF0B1524),
              backgroundBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: panelColor.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Подтверждение',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Введите код из SMS, отправленный на номер ${widget.phone}',
                        style: const TextStyle(
                          color: textMuted,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _FieldLabel('Код подтверждения'),
                      const SizedBox(height: 8),
                      _DarkTextField(
                        controller: _codeController,
                        hintText: 'Введите код',
                        prefixIcon: Icons.sms_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 18),
                      _GreenButton(
                        text: _isLoading ? 'Проверка...' : 'Подтвердить',
                        onPressed: _isLoading ? null : _verifyCode,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _isResending ? null : _resendCode,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF2A3950)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            _isResending
                                ? 'Отправка...'
                                : 'Отправить код повторно',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Если код не пришёл, попробуйте запросить его ещё раз.',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType? keyboardType;

  const _DarkTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3950)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF6F7D91),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            prefixIcon,
            color: const Color(0xFF8E9AAF),
            size: 20,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

class _GreenButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const _GreenButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF489F2A),
          disabledBackgroundColor: const Color(0xFF489F2A).withValues(alpha: 0.6),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

``

## FILE: lib\features\finance\data\api\restaurant_finance_api.dart

- Size: 2005 bytes

``dart
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
``

## FILE: lib\features\finance\data\models\restaurant_finance_models.dart

- Size: 14934 bytes

``dart
class RestaurantFinanceResponse {
  const RestaurantFinanceResponse({
    required this.restaurant,
    required this.period,
    required this.summary,
    required this.allTime,
    required this.payouts,
    required this.recentDeliveredOrders,
  });

  final RestaurantFinanceRestaurant restaurant;
  final RestaurantFinancePeriod period;
  final RestaurantFinanceSummary summary;
  final RestaurantFinanceAllTime allTime;
  final RestaurantFinancePayouts payouts;
  final List<RestaurantFinanceOrder> recentDeliveredOrders;

  factory RestaurantFinanceResponse.fromJson(Map<String, dynamic> json) {
    return RestaurantFinanceResponse(
      restaurant: RestaurantFinanceRestaurant.fromJson(
        _asMap(json['restaurant']) ?? const <String, dynamic>{},
      ),
      period: RestaurantFinancePeriod.fromJson(
        _asMap(json['period']) ?? const <String, dynamic>{},
      ),
      summary: RestaurantFinanceSummary.fromJson(
        _asMap(json['summary']) ?? const <String, dynamic>{},
      ),
      allTime: RestaurantFinanceAllTime.fromJson(
        _asMap(json['allTime']) ?? const <String, dynamic>{},
      ),
      payouts: RestaurantFinancePayouts.fromJson(
        _asMap(json['payouts']) ?? const <String, dynamic>{},
      ),
      recentDeliveredOrders: _asList(json['recentDeliveredOrders'])
          .map(
            (e) => RestaurantFinanceOrder.fromJson(
              _asMap(e) ?? const <String, dynamic>{},
            ),
          )
          .toList(),
    );
  }

  double get availableToWithdraw => payouts.pendingPayoutAmount;
  double get paidAmount => payouts.paidPayoutAmount;
  double get assignedButUnpaidAmount => payouts.unpaidButAssignedAmount;
  double get grossRevenue => summary.grossTotal;
  double get commissionAmount => summary.commissionAmount;
  double get payoutAmount => summary.payoutAmount;
  int get deliveredOrdersCount => summary.deliveredOrdersCount;
}

class RestaurantFinanceRestaurant {
  const RestaurantFinanceRestaurant({
    required this.id,
    required this.slug,
    required this.nameRu,
    required this.nameKk,
    required this.number,
    required this.status,
    this.restaurantCommissionPctOverride,
  });

  final String id;
  final String slug;
  final String nameRu;
  final String nameKk;
  final int number;
  final String status;
  final int? restaurantCommissionPctOverride;

  factory RestaurantFinanceRestaurant.fromJson(Map<String, dynamic> json) {
    return RestaurantFinanceRestaurant(
      id: _toStringValue(json['id']),
      slug: _toStringValue(json['slug']),
      nameRu: _toStringValue(json['nameRu']),
      nameKk: _toStringValue(json['nameKk']),
      number: _toInt(json['number']),
      status: _toStringValue(json['status']),
      restaurantCommissionPctOverride: _toNullableInt(
        json['restaurantCommissionPctOverride'],
      ),
    );
  }

  String get displayName {
    final ru = nameRu.trim();
    if (ru.isNotEmpty) return ru;
    return nameKk.trim();
  }

  bool get hasIndividualCommission => restaurantCommissionPctOverride != null;
}

class RestaurantFinancePeriod {
  const RestaurantFinancePeriod({
    required this.key,
    required this.start,
    required this.end,
    required this.cutoffHour,
  });

  final String key;
  final DateTime? start;
  final DateTime? end;
  final int cutoffHour;

  factory RestaurantFinancePeriod.fromJson(Map<String, dynamic> json) {
    return RestaurantFinancePeriod(
      key: _toStringValue(json['key']),
      start: _toDateTime(json['start']),
      end: _toDateTime(json['end']),
      cutoffHour: _toInt(json['cutoffHour']),
    );
  }
}

class RestaurantFinanceSummary {
  const RestaurantFinanceSummary({
    required this.deliveredOrdersCount,
    required this.subtotal,
    required this.deliveryFee,
    required this.discountAmount,
    required this.deliveryDiscountAmount,
    required this.grossTotal,
    required this.commissionAmount,
    required this.payoutAmount,
    required this.averagePayoutPerOrder,
    required this.averageGrossOrderValue,
  });

  final int deliveredOrdersCount;
  final double subtotal;
  final double deliveryFee;
  final double discountAmount;
  final double deliveryDiscountAmount;
  final double grossTotal;
  final double commissionAmount;
  final double payoutAmount;
  final double averagePayoutPerOrder;
  final double averageGrossOrderValue;

  factory RestaurantFinanceSummary.fromJson(Map<String, dynamic> json) {
    return RestaurantFinanceSummary(
      deliveredOrdersCount: _toInt(json['deliveredOrdersCount']),
      subtotal: _toDouble(json['subtotal']),
      deliveryFee: _toDouble(json['deliveryFee']),
      discountAmount: _toDouble(json['discountAmount']),
      deliveryDiscountAmount: _toDouble(json['deliveryDiscountAmount']),
      grossTotal: _toDouble(json['grossTotal']),
      commissionAmount: _toDouble(json['commissionAmount']),
      payoutAmount: _toDouble(json['payoutAmount']),
      averagePayoutPerOrder: _toDouble(json['averagePayoutPerOrder']),
      averageGrossOrderValue: _toDouble(json['averageGrossOrderValue']),
    );
  }
}

class RestaurantFinanceAllTime {
  const RestaurantFinanceAllTime({
    required this.deliveredOrdersCount,
    required this.subtotal,
    required this.grossTotal,
    required this.commissionAmount,
    required this.payoutAmount,
  });

  final int deliveredOrdersCount;
  final double subtotal;
  final double grossTotal;
  final double commissionAmount;
  final double payoutAmount;

  factory RestaurantFinanceAllTime.fromJson(Map<String, dynamic> json) {
    return RestaurantFinanceAllTime(
      deliveredOrdersCount: _toInt(json['deliveredOrdersCount']),
      subtotal: _toDouble(json['subtotal']),
      grossTotal: _toDouble(json['grossTotal']),
      commissionAmount: _toDouble(json['commissionAmount']),
      payoutAmount: _toDouble(json['payoutAmount']),
    );
  }
}

class RestaurantFinancePayouts {
  const RestaurantFinancePayouts({
    required this.assignedPayoutAmount,
    required this.paidPayoutAmount,
    required this.unpaidButAssignedAmount,
    required this.pendingPayoutAmount,
    required this.rows,
  });

  final double assignedPayoutAmount;
  final double paidPayoutAmount;
  final double unpaidButAssignedAmount;
  final double pendingPayoutAmount;
  final List<RestaurantFinancePayoutRow> rows;

  factory RestaurantFinancePayouts.fromJson(Map<String, dynamic> json) {
    return RestaurantFinancePayouts(
      assignedPayoutAmount: _toDouble(json['assignedPayoutAmount']),
      paidPayoutAmount: _toDouble(json['paidPayoutAmount']),
      unpaidButAssignedAmount: _toDouble(json['unpaidButAssignedAmount']),
      pendingPayoutAmount: _toDouble(json['pendingPayoutAmount']),
      rows: _asList(json['rows'])
          .map(
            (e) => RestaurantFinancePayoutRow.fromJson(
              _asMap(e) ?? const <String, dynamic>{},
            ),
          )
          .toList(),
    );
  }

  bool get hasRows => rows.isNotEmpty;
}

class RestaurantFinancePayoutRow {
  const RestaurantFinancePayoutRow({
    required this.id,
    required this.periodFrom,
    required this.periodTo,
    required this.ordersCount,
    required this.grossSubtotal,
    required this.commissionAmount,
    required this.payoutAmount,
    required this.status,
    required this.paidAt,
    required this.note,
    required this.paymentReference,
    required this.paymentComment,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final DateTime? periodFrom;
  final DateTime? periodTo;
  final int ordersCount;
  final double grossSubtotal;
  final double commissionAmount;
  final double payoutAmount;
  final String status;
  final DateTime? paidAt;
  final String? note;
  final String? paymentReference;
  final String? paymentComment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RestaurantFinancePayoutRow.fromJson(Map<String, dynamic> json) {
    return RestaurantFinancePayoutRow(
      id: _toStringValue(json['id']),
      periodFrom: _toDateTime(json['periodFrom']),
      periodTo: _toDateTime(json['periodTo']),
      ordersCount: _toInt(json['ordersCount']),
      grossSubtotal: _toDouble(json['grossSubtotal']),
      commissionAmount: _toDouble(json['commissionAmount']),
      payoutAmount: _toDouble(json['payoutAmount']),
      status: _toStringValue(json['status']),
      paidAt: _toDateTime(json['paidAt']),
      note: _toNullableString(json['note']),
      paymentReference: _toNullableString(json['paymentReference']),
      paymentComment: _toNullableString(json['paymentComment']),
      createdAt: _toDateTime(json['createdAt']),
      updatedAt: _toDateTime(json['updatedAt']),
    );
  }

  bool get isPaid => status.toUpperCase() == 'PAID';
}

class RestaurantFinanceOrder {
  const RestaurantFinanceOrder({
    required this.id,
    required this.number,
    required this.subtotal,
    required this.deliveryFee,
    required this.discountAmount,
    required this.deliveryDiscountAmount,
    required this.total,
    required this.paymentStatus,
    required this.restaurantCommissionPctApplied,
    required this.restaurantCommissionAmount,
    required this.restaurantPayoutAmount,
    required this.deliveredAt,
    required this.createdAt,
    required this.restaurantPayoutId,
    required this.user,
    required this.itemsCount,
    required this.previewItems,
    required this.items,
  });

  final String id;
  final int number;
  final double subtotal;
  final double deliveryFee;
  final double discountAmount;
  final double deliveryDiscountAmount;
  final double total;
  final String paymentStatus;
  final double restaurantCommissionPctApplied;
  final double restaurantCommissionAmount;
  final double restaurantPayoutAmount;
  final DateTime? deliveredAt;
  final DateTime? createdAt;
  final String? restaurantPayoutId;
  final RestaurantFinanceOrderUser? user;
  final int itemsCount;
  final List<RestaurantFinanceOrderItem> previewItems;
  final List<RestaurantFinanceOrderItem> items;

  factory RestaurantFinanceOrder.fromJson(Map<String, dynamic> json) {
    return RestaurantFinanceOrder(
      id: _toStringValue(json['id']),
      number: _toInt(json['number']),
      subtotal: _toDouble(json['subtotal']),
      deliveryFee: _toDouble(json['deliveryFee']),
      discountAmount: _toDouble(json['discountAmount']),
      deliveryDiscountAmount: _toDouble(json['deliveryDiscountAmount']),
      total: _toDouble(json['total']),
      paymentStatus: _toStringValue(json['paymentStatus']),
      restaurantCommissionPctApplied: _toDouble(
        json['restaurantCommissionPctApplied'],
      ),
      restaurantCommissionAmount: _toDouble(
        json['restaurantCommissionAmount'],
      ),
      restaurantPayoutAmount: _toDouble(json['restaurantPayoutAmount']),
      deliveredAt: _toDateTime(json['deliveredAt']),
      createdAt: _toDateTime(json['createdAt']),
      restaurantPayoutId: _toNullableString(json['restaurantPayoutId']),
      user: _asMap(json['user']) == null
          ? null
          : RestaurantFinanceOrderUser.fromJson(
              _asMap(json['user']) ?? const <String, dynamic>{},
            ),
      itemsCount: _toInt(json['itemsCount']),
      previewItems: _asList(json['previewItems'])
          .map(
            (e) => RestaurantFinanceOrderItem.fromJson(
              _asMap(e) ?? const <String, dynamic>{},
            ),
          )
          .toList(),
      items: _asList(json['items'])
          .map(
            (e) => RestaurantFinanceOrderItem.fromJson(
              _asMap(e) ?? const <String, dynamic>{},
            ),
          )
          .toList(),
    );
  }

  bool get isAssignedToPayout => restaurantPayoutId != null;
}

class RestaurantFinanceOrderUser {
  const RestaurantFinanceOrderUser({
    required this.id,
    required this.phone,
    required this.firstName,
    required this.lastName,
  });

  final String id;
  final String phone;
  final String? firstName;
  final String? lastName;

  factory RestaurantFinanceOrderUser.fromJson(Map<String, dynamic> json) {
    return RestaurantFinanceOrderUser(
      id: _toStringValue(json['id']),
      phone: _toStringValue(json['phone']),
      firstName: _toNullableString(json['firstName']),
      lastName: _toNullableString(json['lastName']),
    );
  }

  String get displayName {
    final first = (firstName ?? '').trim();
    final last = (lastName ?? '').trim();
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    return phone;
  }
}

class RestaurantFinanceOrderItem {
  const RestaurantFinanceOrderItem({
    required this.id,
    required this.productId,
    required this.title,
    required this.price,
    required this.quantity,
  });

  final String id;
  final String productId;
  final String title;
  final double price;
  final int quantity;

  factory RestaurantFinanceOrderItem.fromJson(Map<String, dynamic> json) {
    return RestaurantFinanceOrderItem(
      id: _toStringValue(json['id']),
      productId: _toStringValue(json['productId']),
      title: _toStringValue(json['title']),
      price: _toDouble(json['price']),
      quantity: _toInt(json['quantity']),
    );
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<dynamic> _asList(dynamic value) {
  return value is List ? value : const <dynamic>[];
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _toNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString());
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _toStringValue(dynamic value, {String fallback = ''}) {
  final raw = value?.toString();
  if (raw == null) return fallback;
  return raw;
}

String? _toNullableString(dynamic value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  return raw;
}

DateTime? _toDateTime(dynamic value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
``

## FILE: lib\features\finance\presentation\pages\restaurant_finance_page.dart

- Size: 46700 bytes

``dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../data/api/restaurant_finance_api.dart';
import '../../data/models/restaurant_finance_models.dart';

enum FinancePeriod {
  today,
  yesterday,
  week,
  month,
  custom,
}

class RestaurantFinancePage extends StatefulWidget {
  const RestaurantFinancePage({super.key});

  @override
  State<RestaurantFinancePage> createState() => _RestaurantFinancePageState();
}

class _RestaurantFinancePageState extends State<RestaurantFinancePage> {
  late final RestaurantFinanceApi _api;

  FinancePeriod _period = FinancePeriod.today;
  bool _showDatePicker = false;
  String _customStartDate = '';
  String _customEndDate = '';
  String? _expandedOrderId;

  bool _loading = true;
  String? _error;
  RestaurantFinanceResponse? _data;

  final NumberFormat _moneyFormat = NumberFormat('#,##0', 'ru_RU');
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');
  final DateFormat _dateTimeFormat = DateFormat('dd.MM.yyyy HH:mm');

  @override
  void initState() {
    super.initState();

    _api = RestaurantFinanceApi(ApiClient());
    _loadFinance();
  }

  Future<void> _loadFinance() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _api.getFinance(
        period: _periodToApiValue(_period),
        startDate: _period == FinancePeriod.custom ? _customStartDate : null,
        endDate: _period == FinancePeriod.custom ? _customEndDate : null,
      );

      debugPrint('FINANCE OK: orders=${result.summary.deliveredOrdersCount}');
      debugPrint('FINANCE payout pending=${result.payouts.pendingPayoutAmount}');
      debugPrint('FINANCE payouts rows=${result.payouts.rows.length}');
      debugPrint(
        'FINANCE recent orders=${result.recentDeliveredOrders.length}',
      );

      if (!mounted) return;

      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('FINANCE LOAD ERROR: $e');
      debugPrint('$st');

      if (!mounted) return;

      setState(() {
        _error = '�� ������� ��������� �������: $e';
        _loading = false;
      });
    }
  }

  String _periodToApiValue(FinancePeriod period) {
    switch (period) {
      case FinancePeriod.today:
        return 'today';
      case FinancePeriod.yesterday:
        return 'yesterday';
      case FinancePeriod.week:
        return 'week';
      case FinancePeriod.month:
        return 'month';
      case FinancePeriod.custom:
        return 'custom';
    }
  }

  void _handlePeriodChange(FinancePeriod newPeriod) {
    setState(() {
      _period = newPeriod;
      _showDatePicker = newPeriod == FinancePeriod.custom;
    });

    if (newPeriod != FinancePeriod.custom) {
      _loadFinance();
    }
  }

  void _applyCustomDateRange() {
    if (_customStartDate.isEmpty || _customEndDate.isEmpty) return;

    setState(() {
      _showDatePicker = false;
    });

    _loadFinance();
  }

  void _toggleOrderExpand(String orderId) {
    setState(() {
      _expandedOrderId = _expandedOrderId == orderId ? null : orderId;
    });
  }

  String _periodLabel() {
    switch (_period) {
      case FinancePeriod.today:
        return '�������';
      case FinancePeriod.yesterday:
        return '�����';
      case FinancePeriod.week:
        return '7 ����';
      case FinancePeriod.month:
        return '30 ����';
      case FinancePeriod.custom:
        return '������';
    }
  }

  String _formatMoney(num value) {
    return '${_moneyFormat.format(value).replaceAll(',', ' ')} ?';
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '�';
    return _dateFormat.format(value.toLocal());
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '�';
    return _dateTimeFormat.format(value.toLocal());
  }

  String _formatPeriodRange(DateTime? start, DateTime? end) {
    return '${_formatDate(start)} � ${_formatDate(end)}';
  }

  String _payoutStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return '���������';
      case 'PENDING':
        return '�������';
      case 'CANCELED':
        return '��������';
      default:
        return status;
    }
  }

  Color _payoutStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return const Color(0xFF22C55E);
      case 'PENDING':
        return const Color(0xFFF59E0B);
      case 'CANCELED':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF030712);
    const headerGreen = Color(0xFF489F2A);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF489F2A), Color(0xFF3A7E21)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'jetkiz',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          '�������',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_data != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _periodLabel(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _FinancePeriodTabs(
                    selectedPeriod: _period,
                    onChanged: _handlePeriodChange,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: headerGreen),
                    )
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.white),
                          ),
                        )
                      : RefreshIndicator(
                          color: headerGreen,
                          onRefresh: _loadFinance,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            children: [
                              if (_showDatePicker)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _FinanceCustomPeriodPicker(
                                    startDate: _customStartDate,
                                    endDate: _customEndDate,
                                    onStartChanged: (value) {
                                      setState(() {
                                        _customStartDate = value;
                                      });
                                    },
                                    onEndChanged: (value) {
                                      setState(() {
                                        _customEndDate = value;
                                      });
                                    },
                                    onApply: _applyCustomDateRange,
                                  ),
                                ),
                              _FinanceRevenueCard(
                                title: '� ������',
                                amount: _data!.availableToWithdraw,
                                subtitle: '�� ${_periodLabel().toLowerCase()}',
                                money: _formatMoney,
                              ),
                              const SizedBox(height: 12),
                              _FinanceCommissionCard(
                                commissionType:
                                    _data!.restaurant.hasIndividualCommission
                                        ? '��������������'
                                        : '�����',
                                commissionRate: _data!
                                        .restaurant
                                        .restaurantCommissionPctOverride
                                        ?.toDouble() ??
                                    0,
                                commissionAmount: _data!.commissionAmount,
                                money: _formatMoney,
                              ),
                              const SizedBox(height: 12),
                              _FinanceBalancesCard(
                                data: _data!,
                                money: _formatMoney,
                              ),
                              const SizedBox(height: 12),
                              _FinanceStatsGrid(
                                data: _data!,
                                money: _formatMoney,
                              ),
                              const SizedBox(height: 16),
                              _SectionTitle(
                                title: '������� ������',
                                trailing: '${_data!.payouts.rows.length}',
                              ),
                              const SizedBox(height: 10),
                              _PayoutHistorySection(
                                rows: _data!.payouts.rows,
                                money: _formatMoney,
                                dateTime: _formatDateTime,
                                period: _formatPeriodRange,
                                statusLabel: _payoutStatusLabel,
                                statusColor: _payoutStatusColor,
                              ),
                              const SizedBox(height: 16),
                              _SectionTitle(
                                title: '��������� ������������ ������',
                                trailing:
                                    '${_data!.recentDeliveredOrders.length}',
                              ),
                              const SizedBox(height: 10),
                              _RecentOrdersSection(
                                orders: _data!.recentDeliveredOrders,
                                expandedOrderId: _expandedOrderId,
                                money: _formatMoney,
                                dateTime: _formatDateTime,
                                onToggleExpand: _toggleOrderExpand,
                              ),
                              const SizedBox(height: 16),
                              _FinanceSummarySection(
                                periodLabel: _periodLabel(),
                                data: _data!,
                                money: _formatMoney,
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinancePeriodTabs extends StatelessWidget {
  const _FinancePeriodTabs({
    required this.selectedPeriod,
    required this.onChanged,
  });

  final FinancePeriod selectedPeriod;
  final ValueChanged<FinancePeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <({FinancePeriod value, String label})>[
      (value: FinancePeriod.today, label: '�������'),
      (value: FinancePeriod.yesterday, label: '�����'),
      (value: FinancePeriod.week, label: '7 ����'),
      (value: FinancePeriod.month, label: '30 ����'),
      (value: FinancePeriod.custom, label: '������'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final selected = selectedPeriod == item.value;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(item.value),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: selected ? const Color(0xFF14532D) : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FinanceCustomPeriodPicker extends StatelessWidget {
  const _FinanceCustomPeriodPicker({
    required this.startDate,
    required this.endDate,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onApply,
  });

  final String startDate;
  final String endDate;
  final ValueChanged<String> onStartChanged;
  final ValueChanged<String> onEndChanged;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: '��',
                  value: startDate,
                  onChanged: onStartChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                  label: '��',
                  value: endDate,
                  onChanged: onEndChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF489F2A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '���������',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatefulWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _DateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: '2026-04-06',
        hintStyle: const TextStyle(color: Color(0xFF6B7280)),
        labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFF030712),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1F2937)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1F2937)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF489F2A)),
        ),
      ),
    );
  }
}

class _FinanceRevenueCard extends StatelessWidget {
  const _FinanceRevenueCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.money,
  });

  final String title;
  final double amount;
  final String subtitle;
  final String Function(num value) money;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF489F2A).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Color(0xFF86EFAC),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  money(amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceCommissionCard extends StatelessWidget {
  const _FinanceCommissionCard({
    required this.commissionType,
    required this.commissionRate,
    required this.commissionAmount,
    required this.money,
  });

  final String commissionType;
  final double commissionRate;
  final double commissionAmount;
  final String Function(num value) money;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.percent_rounded,
            color: Color(0xFFF59E0B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '�������� ���������',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$commissionType � ${commissionRate.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            money(commissionAmount),
            style: const TextStyle(
              color: Color(0xFFFBBF24),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceBalancesCard extends StatelessWidget {
  const _FinanceBalancesCard({
    required this.data,
    required this.money,
  });

  final RestaurantFinanceResponse data;
  final String Function(num value) money;

  @override
  Widget build(BuildContext context) {
    Widget item(String title, double value, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                money(value),
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        item('� ������', data.availableToWithdraw, const Color(0xFF86EFAC)),
        const SizedBox(width: 10),
        item('���������', data.paidAmount, const Color(0xFF93C5FD)),
        const SizedBox(width: 10),
        item(
          '���������',
          data.assignedButUnpaidAmount,
          const Color(0xFFFDE68A),
        ),
      ],
    );
  }
}

class _FinanceStatsGrid extends StatelessWidget {
  const _FinanceStatsGrid({
    required this.data,
    required this.money,
  });

  final RestaurantFinanceResponse data;
  final String Function(num value) money;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, String value})>[
      (
        label: '���������� �������',
        value: '${data.summary.deliveredOrdersCount}',
      ),
      (
        label: '������',
        value: money(data.summary.grossTotal),
      ),
      (
        label: '������� payout',
        value: money(data.summary.averagePayoutPerOrder),
      ),
      (
        label: '������� ���',
        value: money(data.summary.averageGrossOrderValue),
      ),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 96,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final item = items[index];

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                item.value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.trailing,
  });

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: Text(
            trailing,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PayoutHistorySection extends StatelessWidget {
  const _PayoutHistorySection({
    required this.rows,
    required this.money,
    required this.dateTime,
    required this.period,
    required this.statusLabel,
    required this.statusColor,
  });

  final List<RestaurantFinancePayoutRow> rows;
  final String Function(num value) money;
  final String Function(DateTime? value) dateTime;
  final String Function(DateTime? start, DateTime? end) period;
  final String Function(String status) statusLabel;
  final Color Function(String status) statusColor;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyCard(
        title: '������� ������ �����',
        subtitle: '���� ��� payout-������� �� ������� �� ���� ������',
      );
    }

    return Column(
      children: rows.map((row) {
        final chipColor = statusColor(row.status);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      money(row.payoutAmount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: chipColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel(row.status),
                      style: TextStyle(
                        color: chipColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '������: ${period(row.periodFrom, row.periodTo)}',
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '�������: ${row.ordersCount} � ����� ����: ${money(row.grossSubtotal)}',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '��������: ${money(row.commissionAmount)}',
                style: const TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              if ((row.paymentReference ?? '').isNotEmpty)
                Text(
                  '��������: ${row.paymentReference}',
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 12,
                  ),
                ),
              if ((row.paymentComment ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '�����������: ${row.paymentComment}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ),
              if ((row.note ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '�������: ${row.note}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                '�������: ${dateTime(row.createdAt)}',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                ),
              ),
              Text(
                row.paidAt != null
                    ? '��������: ${dateTime(row.paidAt)}'
                    : '��������: �',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _RecentOrdersSection extends StatelessWidget {
  const _RecentOrdersSection({
    required this.orders,
    required this.expandedOrderId,
    required this.money,
    required this.dateTime,
    required this.onToggleExpand,
  });

  final List<RestaurantFinanceOrder> orders;
  final String? expandedOrderId;
  final String Function(num value) money;
  final String Function(DateTime? value) dateTime;
  final ValueChanged<String> onToggleExpand;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const _EmptyCard(
        title: '��� ������������ �������',
        subtitle: '�� ��������� ������ ������� ���� ���',
      );
    }

    return Column(
      children: orders.map((order) {
        final expanded = expandedOrderId == order.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onToggleExpand(order.id),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '����� �${order.number}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.user?.displayName ?? '������',
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '���������: ${dateTime(order.deliveredAt)}',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            money(order.restaurantPayoutAmount),
                            style: const TextStyle(
                              color: Color(0xFF86EFAC),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.isAssignedToPayout
                                ? '�������� � payout'
                                : '������� �������',
                            style: TextStyle(
                              color: order.isAssignedToPayout
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFF93C5FD),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF6B7280),
                      ),
                    ],
                  ),
                ),
              ),
              if (expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(
                    children: [
                      const Divider(color: Color(0xFF1F2937)),
                      _DetailRow(label: 'Subtotal', value: money(order.subtotal)),
                      _DetailRow(
                        label: 'Delivery fee',
                        value: money(order.deliveryFee),
                      ),
                      _DetailRow(
                        label: 'Discount',
                        value: money(order.discountAmount),
                      ),
                      _DetailRow(
                        label: 'Delivery discount',
                        value: money(order.deliveryDiscountAmount),
                      ),
                      _DetailRow(
                        label: '���� ������',
                        value: money(order.total),
                      ),
                      _DetailRow(
                        label: '��������',
                        value: money(order.restaurantCommissionAmount),
                      ),
                      _DetailRow(
                        label: '������ ��������',
                        value:
                            '${order.restaurantCommissionPctApplied.toStringAsFixed(0)}%',
                      ),
                      const SizedBox(height: 10),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '�������',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...order.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    color: Color(0xFFCBD5E1),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Text(
                                '${item.quantity} ? ${money(item.price)}',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceSummarySection extends StatelessWidget {
  const _FinanceSummarySection({
    required this.periodLabel,
    required this.data,
    required this.money,
  });

  final String periodLabel;
  final RestaurantFinanceResponse data;
  final String Function(num value) money;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '���� �� $periodLabel',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _DetailRow(
            label: '������� ����������',
            value: '${data.summary.deliveredOrdersCount}',
          ),
          _DetailRow(
            label: '������',
            value: money(data.summary.grossTotal),
          ),
          _DetailRow(
            label: '�������� �������',
            value: money(data.summary.commissionAmount),
          ),
          _DetailRow(
            label: '��������� ���������',
            value: money(data.summary.payoutAmount),
          ),
          _DetailRow(
            label: '� ������',
            value: money(data.availableToWithdraw),
          ),
          _DetailRow(
            label: '��� ���������',
            value: money(data.paidAmount),
          ),
          _DetailRow(
            label: '��������� � payout',
            value: money(data.assignedButUnpaidAmount),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            color: Color(0xFF6B7280),
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

``

## FILE: lib\features\menu\data\restaurant_menu_api.dart

- Size: 3857 bytes

``dart
import 'dart:io';

import 'package:jetkiz_restaurant/core/network/api_client.dart';

class RestaurantMenuApi {
  final ApiClient _client;

  RestaurantMenuApi({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  Future<Map<String, dynamic>> getRestaurantMe() async {
    final response = await _client.get('/restaurants/me');
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> getMenu(String restaurantId) async {
    final response = await _client.get(
      '/restaurants/$restaurantId/menu?includeUnavailable=1',
    );

    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> deleteProduct(
    String restaurantId,
    String productId,
  ) async {
    await _client.delete(
      '/restaurants/$restaurantId/menu/products/$productId',
    );
  }

  Future<void> updateAvailability({
    required String restaurantId,
    required String productId,
    required bool value,
  }) async {
    await _client.patch(
      '/restaurants/$restaurantId/menu/products/$productId',
      {
        'isAvailable': value,
      },
    );
  }

  Future<Map<String, dynamic>> createProduct(
    String restaurantId,
    Map<String, dynamic> data,
  ) async {
    final response = await _client.post(
      '/restaurants/$restaurantId/menu/products',
      data,
    );

    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> updateProduct(
    String restaurantId,
    String productId,
    Map<String, dynamic> data,
  ) async {
    final response = await _client.patch(
      '/restaurants/$restaurantId/menu/products/$productId',
      data,
    );

    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> createCategory({
    required String restaurantId,
    required String title,
    int? sortOrder,
  }) async {
    final payload = <String, dynamic>{
      'restaurantId': restaurantId,
      'titleRu': title.trim(),
      'titleKk': title.trim(),
    };

    if (sortOrder != null) {
      payload['sortOrder'] = sortOrder;
    }

    final response = await _client.post(
      '/food-categories',
      payload,
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    return <String, dynamic>{};
  }

  Future<void> replaceProductImages({
    required String restaurantId,
    required String productId,
    File? mainImage,
    List<File> otherImages = const [],
  }) async {
    if (mainImage == null && otherImages.isEmpty) return;

    final files = <File>[
      if (mainImage != null) mainImage,
      ...otherImages,
    ];

    await _client.uploadFiles(
      '/restaurants/$restaurantId/menu/products/$productId/images',
      files: files,
      mainFile: mainImage,
      mainFieldName: 'main',
      filesFieldName: 'others',
    );
  }

  Future<void> addProductImages({
    required String restaurantId,
    required String productId,
    required List<File> images,
  }) async {
    if (images.isEmpty) return;

    await _client.uploadFiles(
      '/restaurants/$restaurantId/menu/products/$productId/images/add',
      files: images,
      filesFieldName: 'files',
    );
  }

  Future<void> setMainImage({
    required String restaurantId,
    required String productId,
    required String imageId,
  }) async {
    await _client.patch(
      '/restaurants/$restaurantId/menu/products/$productId/images/$imageId/main',
      {},
    );
  }

  Future<void> deleteImage({
    required String restaurantId,
    required String productId,
    required String imageId,
  }) async {
    await _client.delete(
      '/restaurants/$restaurantId/menu/products/$productId/images/$imageId',
    );
  }
}
``

## FILE: lib\features\menu\domain\restaurant_menu_models.dart

- Size: 4527 bytes

``dart
class RestaurantMenuData {
  final List<RestaurantMenuCategory> categories;
  final List<RestaurantMenuItem> items;

  RestaurantMenuData({
    required this.categories,
    required this.items,
  });

  factory RestaurantMenuData.fromJson(Map<String, dynamic> json) {
    return RestaurantMenuData(
      categories: ((json['categories'] as List?) ?? const [])
          .map(
            (e) => RestaurantMenuCategory.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      items: ((json['items'] as List?) ?? const [])
          .map(
            (e) => RestaurantMenuItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}

class RestaurantMenuCategory {
  final String id;
  final String title;

  RestaurantMenuCategory({
    required this.id,
    required this.title,
  });

  factory RestaurantMenuCategory.fromJson(Map<String, dynamic> json) {
    return RestaurantMenuCategory(
      id: json['id']?.toString() ?? '',
      title: (json['titleRu'] ?? json['title'] ?? '').toString(),
    );
  }
}

class RestaurantMenuItem {
  final String id;
  final String titleRu;
  final String titleKk;
  final int price;
  final bool isAvailable;
  final String categoryId;
  final String? imageUrl;
  final String? description;
  final String? weight;
  final String? composition;
  final bool isDrink;
  final List<RestaurantMenuImage> images;

  const RestaurantMenuItem({
    required this.id,
    required this.titleRu,
    required this.titleKk,
    required this.price,
    required this.isAvailable,
    required this.categoryId,
    this.imageUrl,
    this.description,
    this.weight,
    this.composition,
    required this.isDrink,
    required this.images,
  });

  factory RestaurantMenuItem.fromJson(Map<String, dynamic> json) {
    return RestaurantMenuItem(
      id: json['id']?.toString() ?? '',
      titleRu: (json['titleRu'] ?? '').toString(),
      titleKk: (json['titleKk'] ?? '').toString(),
      price: (json['price'] as num?)?.toInt() ?? 0,
      isAvailable: json['isAvailable'] == null
          ? true
          : json['isAvailable'] == true,
      categoryId: json['categoryId']?.toString() ??
          json['category']?['id']?.toString() ??
          '',
      imageUrl: json['imageUrl']?.toString(),
      description: _nullableString(json['description']),
      weight: _nullableString(
        json['weight'] ?? json['weightText'] ?? json['portion'],
      ),
      composition: _nullableString(
        json['composition'] ?? json['ingredients'],
      ),
      isDrink: json['isDrink'] == true,
      images: ((json['images'] as List?) ?? const [])
          .map(
            (e) => RestaurantMenuImage.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }

  RestaurantMenuItem copyWith({
    String? id,
    String? titleRu,
    String? titleKk,
    int? price,
    bool? isAvailable,
    String? categoryId,
    String? imageUrl,
    String? description,
    String? weight,
    String? composition,
    bool? isDrink,
    List<RestaurantMenuImage>? images,
  }) {
    return RestaurantMenuItem(
      id: id ?? this.id,
      titleRu: titleRu ?? this.titleRu,
      titleKk: titleKk ?? this.titleKk,
      price: price ?? this.price,
      isAvailable: isAvailable ?? this.isAvailable,
      categoryId: categoryId ?? this.categoryId,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      weight: weight ?? this.weight,
      composition: composition ?? this.composition,
      isDrink: isDrink ?? this.isDrink,
      images: images ?? this.images,
    );
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }
}

class RestaurantMenuImage {
  final String id;
  final String url;
  final bool isMain;

  const RestaurantMenuImage({
    required this.id,
    required this.url,
    required this.isMain,
  });

  factory RestaurantMenuImage.fromJson(Map<String, dynamic> json) {
    return RestaurantMenuImage(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      isMain: json['isMain'] == true,
    );
  }
}
``

## FILE: lib\features\menu\presentation\pages\createMenuCategoryPage.dart

- Size: 12812 bytes

``dart
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../data/restaurant_menu_api.dart';

class CreateMenuCategoryPage extends StatefulWidget {
  final String restaurantId;
  final int? nextSortOrder;

  const CreateMenuCategoryPage({
    super.key,
    required this.restaurantId,
    this.nextSortOrder,
  });

  @override
  State<CreateMenuCategoryPage> createState() =>
      _CreateMenuCategoryPageState();
}

class _CreateMenuCategoryPageState extends State<CreateMenuCategoryPage> {
  final RestaurantMenuApi _api = RestaurantMenuApi();
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _nameController.text.trim();

    if (title.isEmpty) {
      setState(() {
        _errorText = 'Введите название категории';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await _api.createCategory(
        restaurantId: widget.restaurantId,
        title: title,
        sortOrder: widget.nextSortOrder,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorText = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });
    }
  }

  void _close() {
    if (_isSaving) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    const cardTop = Color(0xFF172338);
    const cardBottom = Color(0xFF111A2C);
    const strokeColor = Color(0xFF2A3A57);
    const inputFill = Color(0xFF1A2740);
    const green = Color(0xFF54B52E);
    const cancel = Color(0xFF3A465B);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.45),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: 360,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [cardTop, cardBottom],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: strokeColor,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Новая категория',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: _close,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.10),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Название категории *',
                            style: TextStyle(
                              color: Color(0xFFD2D9E6),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _nameController,
                          focusNode: _focusNode,
                          enabled: !_isSaving,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) {
                            if (_errorText != null) {
                              setState(() {
                                _errorText = null;
                              });
                            }
                          },
                          onSubmitted: (_) => _save(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Например: Десерты',
                            hintStyle: const TextStyle(
                              color: Color(0xFF8D9AB0),
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: inputFill,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: strokeColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: strokeColor,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: green,
                                width: 1.3,
                              ),
                            ),
                          ),
                        ),
                        if (_errorText != null) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _errorText!,
                              style: const TextStyle(
                                color: Color(0xFFFF7A7A),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _close,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cancel,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        cancel.withOpacity(0.7),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Отмена',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _save,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: green,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        green.withOpacity(0.7),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Создать',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
``

## FILE: lib\features\menu\presentation\pages\restaurant_menu_page.dart

- Size: 18297 bytes

``dart
import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/session/restaurant_context.dart';
import '../../data/restaurant_menu_api.dart';
import '../../domain/restaurant_menu_models.dart';
import '../widgets/menu_item_card.dart';
import '../widgets/menuCreateActionSheet.dart';
import 'createMenuCategoryPage.dart';
import 'upsertMenuItemPage.dart';

class RestaurantMenuPage extends StatefulWidget {
  const RestaurantMenuPage({super.key});

  @override
  State<RestaurantMenuPage> createState() => _RestaurantMenuPageState();
}

class _RestaurantMenuPageState extends State<RestaurantMenuPage> {
  final RestaurantMenuApi _api = RestaurantMenuApi();

  bool _isLoading = true;
  String? _error;

  String? _restaurantId;
  List<RestaurantMenuCategory> _categories = [];
  List<RestaurantMenuItem> _items = [];
  String _selectedCategory = 'Все';

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final me = await _api.getRestaurantMe();

      final restaurantId = resolveRestaurantIdFromMe(me);

      if (restaurantId == null || restaurantId.isEmpty) {
        throw Exception('Не найден restaurantId');
      }

      final response = await _api.getMenu(restaurantId);
      final parsed = RestaurantMenuData.fromJson(response);

      if (!mounted) return;

      setState(() {
        _restaurantId = restaurantId;
        _categories = parsed.categories;
        _items = parsed.items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  List<RestaurantMenuItem> get _filteredItems {
    if (_selectedCategory == 'Все') return _items;

    final matches = _categories.where((e) => e.title == _selectedCategory);
    if (matches.isEmpty) return [];

    final selected = matches.first;

    return _items.where((item) => item.categoryId == selected.id).toList();
  }

  String _categoryTitleByItem(RestaurantMenuItem item) {
    try {
      return _categories.firstWhere((e) => e.id == item.categoryId).title;
    } catch (_) {
      return 'Без категории';
    }
  }

  Future<void> _toggleAvailability(RestaurantMenuItem item) async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) return;

    final newValue = !item.isAvailable;

    try {
      await _api.updateAvailability(
        restaurantId: restaurantId,
        productId: item.id,
        value: newValue,
      );

      if (!mounted) return;

      setState(() {
        _items = _items.map((e) {
          if (e.id != item.id) return e;
          return e.copyWith(isAvailable: newValue);
        }).toList();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  Future<void> _deleteItem(RestaurantMenuItem item) async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1F2937), Color(0xFF111827)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF374151)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Удалить блюдо?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Удалить "${item.titleRu}" из меню?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF4B5563)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Удалить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _api.deleteProduct(restaurantId, item.id);

      if (!mounted) return;

      setState(() {
        _items.removeWhere((e) => e.id == item.id);
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  Future<void> _openCreateItem() async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) return;

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UpsertMenuItemPage(
          restaurantId: restaurantId,
        ),
      ),
    );

    if (created == true) {
      await _loadMenu();
    }
  }

  Future<void> _openCreateCategory() async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) return;

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateMenuCategoryPage(
          restaurantId: restaurantId,
          nextSortOrder: _categories.length,
        ),
      ),
    );

    if (created == true) {
      await _loadMenu();
    }
  }

  void _openCreateActions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return MenuCreateActionSheet(
          onAddProduct: () {
            Navigator.of(sheetContext).pop();
            _openCreateItem();
          },
          onAddCategory: () {
            Navigator.of(sheetContext).pop();
            _openCreateCategory();
          },
        );
      },
    );
  }

  Future<void> _openEditItem(RestaurantMenuItem item) async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) return;

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UpsertMenuItemPage(
          restaurantId: restaurantId,
          item: item,
        ),
      ),
    );

    if (updated == true) {
      await _loadMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020817),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 99, right: 4),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: _openCreateActions,
            elevation: 0,
            backgroundColor: const Color(0xFF489F2A),
            foregroundColor: Colors.white,
            shape: const CircleBorder(
              side: BorderSide(
                color: Color(0xFF020817),
                width: 4,
              ),
            ),
            child: const Icon(Icons.add, size: 28),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _MenuHeader(
              categories: _categories,
              selectedCategory: _selectedCategory,
              itemCount: _items.length,
              onCategorySelected: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadMenu,
                color: const Color(0xFF489F2A),
                backgroundColor: const Color(0xFF111827),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 180),
        children: const [
          Center(
            child: CircularProgressIndicator(
              color: Color(0xFF489F2A),
            ),
          ),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 140, 24, 120),
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFF6B7280),
            size: 46,
          ),
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _loadMenu,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF489F2A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Повторить'),
            ),
          ),
        ],
      );
    }

    if (_filteredItems.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 120),
        children: const [
          Center(
            child: Icon(
              Icons.restaurant_menu,
              color: Color(0xFF4B5563),
              size: 54,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Нет блюд',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Добавьте первое блюдо в меню',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      itemCount: _filteredItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final item = _filteredItems[index];

        return MenuItemCard(
          item: item,
          categoryTitle: _categoryTitleByItem(item),
          onToggleAvailability: () => _toggleAvailability(item),
          onEdit: () => _openEditItem(item),
          onDelete: () => _deleteItem(item),
        );
      },
    );
  }
}

class _MenuHeader extends StatelessWidget {
  const _MenuHeader({
    required this.categories,
    required this.selectedCategory,
    required this.itemCount,
    required this.onCategorySelected,
  });

  final List<RestaurantMenuCategory> categories;
  final String selectedCategory;
  final int itemCount;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final tabs = <String>[
      'Все',
      ...categories.map((e) => e.title),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF489F2A), Color(0xFF3A7E21)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'jetkiz',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Управление меню',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$itemCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final tab = tabs[index];
                final selected = selectedCategory == tab;

                return GestureDetector(
                  onTap: () => onCategorySelected(tab),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFF489F2A)
                            : Colors.white.withValues(alpha: 0.92),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

``

## FILE: lib\features\menu\presentation\pages\upsertMenuItemPage.dart

- Size: 37342 bytes

``dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:jetkiz_restaurant/core/network/api_client.dart';
import '../../data/restaurant_menu_api.dart';
import '../../domain/restaurant_menu_models.dart';

class UpsertMenuItemPage extends StatefulWidget {
  final String restaurantId;
  final RestaurantMenuItem? item;

  const UpsertMenuItemPage({
    super.key,
    required this.restaurantId,
    this.item,
  });

  @override
  State<UpsertMenuItemPage> createState() => _UpsertMenuItemPageState();
}

class _UpsertMenuItemPageState extends State<UpsertMenuItemPage> {
  final RestaurantMenuApi _api = RestaurantMenuApi();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _titleRuController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _compositionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDrink = false;
  bool _isAvailable = true;

  String? _errorText;
  String? _selectedCategoryId;
  List<RestaurantMenuCategory> _categories = [];

  File? _mainImageFile;
  final List<File> _otherImageFiles = [];

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    _fillInitialData();
    _loadCategories();
  }

  void _fillInitialData() {
    final item = widget.item;
    if (item == null) return;

    _titleRuController.text = item.titleRu;
    _weightController.text = item.weight ?? '';
    _compositionController.text = item.composition ?? '';
    _priceController.text = item.price.toString();
    _descriptionController.text = item.description ?? '';
    _selectedCategoryId = item.categoryId;
    _isDrink = item.isDrink;
    _isAvailable = item.isAvailable;
  }

  Future<void> _loadCategories() async {
    try {
      final response = await _api.getMenu(widget.restaurantId);
      final parsed = RestaurantMenuData.fromJson(response);

      if (!mounted) return;

      setState(() {
        _categories = parsed.categories;
        _selectedCategoryId ??=
            parsed.categories.isNotEmpty ? parsed.categories.first.id : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorText = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _pickMainImage() async {
    if (_isSaving) return;

    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _mainImageFile = File(picked.path);
    });
  }

  Future<void> _pickOtherImages() async {
    if (_isSaving) return;

    final picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return;

    final currentCount =
        (_mainImageFile != null ? 1 : 0) + _otherImageFiles.length;
    final available = 11 - currentCount;

    if (available <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Максимум 11 фото')),
      );
      return;
    }

    final filesToAdd = picked.take(available).map((e) => File(e.path)).toList();

    setState(() {
      _otherImageFiles.addAll(filesToAdd);
    });

    if (picked.length > available && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Можно загрузить максимум 11 фото')),
      );
    }
  }

  Future<void> _uploadPickedImages(String productId) async {
    if (_mainImageFile == null && _otherImageFiles.isEmpty) return;

    await ApiClient.instance.uploadFiles(
      '/restaurants/${widget.restaurantId}/menu/products/$productId/images',
      mainFile: _mainImageFile,
      files: _otherImageFiles,
      mainFieldName: 'main',
      filesFieldName: 'others',
    );
  }

  RestaurantMenuItem? _findCreatedItem(
    List<RestaurantMenuItem> items, {
    required String titleRu,
    required int price,
    required String categoryId,
  }) {
    final matches = items.where((item) {
      return item.titleRu.trim() == titleRu.trim() &&
          item.price == price &&
          item.categoryId == categoryId;
    }).toList();

    if (matches.isEmpty) return null;
    return matches.last;
  }

  @override
  void dispose() {
    _titleRuController.dispose();
    _weightController.dispose();
    _compositionController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final categoryId = _selectedCategoryId?.trim() ?? '';
    final titleRu = _titleRuController.text.trim();
    final weight = _weightController.text.trim();
    final composition = _compositionController.text.trim();
    final description = _descriptionController.text.trim();

    final price = int.tryParse(_priceController.text.trim());

    if (categoryId.isEmpty) {
      setState(() {
        _errorText = 'Выберите категорию';
      });
      return;
    }

    if (titleRu.isEmpty) {
      setState(() {
        _errorText = 'Введите название блюда';
      });
      return;
    }

    if (price == null || price <= 0) {
      setState(() {
        _errorText = 'Введите корректную цену';
      });
      return;
    }

    if (!_isDrink && composition.isEmpty) {
      setState(() {
        _errorText = 'Для блюда состав обязателен';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final data = <String, dynamic>{
      'categoryId': categoryId,
      'titleRu': titleRu,
      'titleKk': titleRu,
      'price': price,
      'weight': weight.isEmpty ? null : weight,
      'composition': composition.isEmpty ? null : composition,
      'description': description.isEmpty ? null : description,
      'isDrink': _isDrink,
      'isAvailable': _isAvailable,
    };

    try {
      if (_isEdit) {
        await _api.updateProduct(
          widget.restaurantId,
          widget.item!.id,
          data,
        );

        await _uploadPickedImages(widget.item!.id);
      } else {
        await _api.createProduct(
          widget.restaurantId,
          data,
        );

        if (_mainImageFile != null || _otherImageFiles.isNotEmpty) {
          final response = await _api.getMenu(widget.restaurantId);
          final parsed = RestaurantMenuData.fromJson(response);

          final createdItem = _findCreatedItem(
            parsed.items,
            titleRu: titleRu,
            price: price,
            categoryId: categoryId,
          );

          if (createdItem != null) {
            await _uploadPickedImages(createdItem.id);
          }
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorText = e.toString().replaceFirst('Exception: ', '');
        _isSaving = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });
  }

  void _close() {
    if (_isSaving) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF020817);
    const cardTop = Color(0xFF172338);
    const cardBottom = Color(0xFF111A2C);
    const stroke = Color(0xFF2A3A57);
    const field = Color(0xFF1A2740);
    const green = Color(0xFF54B52E);
    const cancel = Color(0xFF3A465B);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEdit ? 'Редактировать блюдо' : 'Добавить блюдо',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _close,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [cardTop, cardBottom],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: stroke,
                    width: 1.2,
                  ),
                ),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: green,
                        ),
                      )
                    : _errorText != null && _categories.isEmpty
                        ? _ErrorBlock(
                            message: _errorText!,
                            onRetry: _loadCategories,
                          )
                        : ScrollConfiguration(
                            behavior: const _NoScrollbarBehavior(),
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('Категория *'),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    value: _selectedCategoryId,
                                    dropdownColor: field,
                                    iconEnabledColor: Colors.white70,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: _inputDecoration(
                                      fillColor: field,
                                      borderColor: stroke,
                                    ),
                                    items: _categories
                                        .map(
                                          (e) => DropdownMenuItem<String>(
                                            value: e.id,
                                            child: Text(
                                              e.title,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: _isSaving
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _selectedCategoryId = value;
                                            });
                                          },
                                  ),
                                  const SizedBox(height: 14),

                                  _FieldLabel('Название (RU) *'),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _titleRuController,
                                    enabled: !_isSaving,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration(
                                      hintText: 'Например: Чизбургер',
                                      fillColor: field,
                                      borderColor: stroke,
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  _FieldLabel('Граммовка / Литраж'),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _weightController,
                                    enabled: !_isSaving,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration(
                                      hintText: 'Например: 350 г / 0.5 л',
                                      fillColor: field,
                                      borderColor: stroke,
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  Container(
                                    decoration: BoxDecoration(
                                      color: field,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: stroke),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Это напиток\n(состав необязателен)',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                        Switch(
                                          value: _isDrink,
                                          onChanged: _isSaving
                                              ? null
                                              : (value) {
                                                  setState(() {
                                                    _isDrink = value;
                                                  });
                                                },
                                          activeColor: green,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  _FieldLabel(_isDrink ? 'Состав' : 'Состав *'),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _compositionController,
                                    enabled: !_isSaving,
                                    maxLines: 2,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration(
                                      hintText:
                                          'Например: говядина, сыр, соус, булочка...',
                                      fillColor: field,
                                      borderColor: stroke,
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  _FieldLabel('Цена (₸) *'),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _priceController,
                                    enabled: !_isSaving,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration(
                                      hintText: '1290',
                                      fillColor: field,
                                      borderColor: stroke,
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  _FieldLabel('Описание (опционально)'),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _descriptionController,
                                    enabled: !_isSaving,
                                    maxLines: 2,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration(
                                      hintText:
                                          'Краткое описание для клиента...',
                                      fillColor: field,
                                      borderColor: stroke,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  const _SectionLabel('Главное фото'),
                                  const SizedBox(height: 8),
                                  _UploadBox(
                                    title: _mainImageFile == null
                                        ? 'Загрузить фото'
                                        : 'Фото выбрано',
                                    height: 96,
                                    onTap: _pickMainImage,
                                  ),
                                  if (_mainImageFile != null) ...[
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.file(
                                        _mainImageFile!,
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),

                                  _SectionLabel(
                                    'Дополнительные фото (${_otherImageFiles.length}/10)',
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _SmallAddPhotoBox(
                                        onTap: _pickOtherImages,
                                      ),
                                      ..._otherImageFiles.asMap().entries.map(
                                        (entry) => Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              child: Image.file(
                                                entry.value,
                                                width: 62,
                                                height: 62,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            Positioned(
                                              top: 2,
                                              right: 2,
                                              child: InkWell(
                                                onTap: _isSaving
                                                    ? null
                                                    : () {
                                                        setState(() {
                                                          _otherImageFiles
                                                              .removeAt(
                                                            entry.key,
                                                          );
                                                        });
                                                      },
                                                child: Container(
                                                  width: 18,
                                                  height: 18,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Colors.black54,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    size: 12,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  Container(
                                    decoration: BoxDecoration(
                                      color: field,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: stroke),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Доступно для заказа',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Switch(
                                          value: _isAvailable,
                                          onChanged: _isSaving
                                              ? null
                                              : (value) {
                                                  setState(() {
                                                    _isAvailable = value;
                                                  });
                                                },
                                          activeColor: green,
                                        ),
                                      ],
                                    ),
                                  ),

                                  if (_errorText != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      _errorText!,
                                      style: const TextStyle(
                                        color: Color(0xFFFF7A7A),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 48,
                                          child: ElevatedButton(
                                            onPressed: _isSaving ? null : _close,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: cancel,
                                              foregroundColor: Colors.white,
                                              disabledBackgroundColor:
                                                  cancel.withOpacity(0.7),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              elevation: 0,
                                            ),
                                            child: const Text(
                                              'Отмена',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: SizedBox(
                                          height: 48,
                                          child: ElevatedButton(
                                            onPressed:
                                                _isSaving ? null : _submit,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: green,
                                              foregroundColor: Colors.white,
                                              disabledBackgroundColor:
                                                  green.withOpacity(0.7),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              elevation: 0,
                                            ),
                                            child: _isSaving
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2.2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : Text(
                                                    _isEdit
                                                        ? 'Сохранить'
                                                        : 'Добавить',
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hintText,
    required Color fillColor,
    required Color borderColor,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF8D9AB0),
        fontSize: 14,
      ),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF54B52E),
          width: 1.2,
        ),
      ),
    );
  }
}

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFD2D9E6),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFD2D9E6),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _UploadBox extends StatelessWidget {
  final String title;
  final double height;
  final VoidCallback onTap;

  const _UploadBox({
    required this.title,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A2740),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF2A3A57),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.file_upload_outlined,
                color: Colors.white.withOpacity(0.55),
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallAddPhotoBox extends StatelessWidget {
  final VoidCallback onTap;

  const _SmallAddPhotoBox({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A2740),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF2A3A57),
            ),
          ),
          child: const Icon(
            Icons.add,
            color: Color(0xFF8D9AB0),
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBlock({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white70,
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF54B52E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
``

## FILE: lib\features\menu\presentation\widgets\menu_item_card.dart

- Size: 8676 bytes

``dart
import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/config/app_config.dart';
import '../../domain/restaurant_menu_models.dart';

class MenuItemCard extends StatelessWidget {
  const MenuItemCard({
    super.key,
    required this.item,
    required this.categoryTitle,
    required this.onToggleAvailability,
    required this.onEdit,
    required this.onDelete,
  });

  final RestaurantMenuItem item;
  final String categoryTitle;
  final VoidCallback onToggleAvailability;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _resolveImage() {
    try {
      final main = item.images.firstWhere((e) => e.isMain);
      if (main.url.trim().isNotEmpty) return main.url.trim();
    } catch (_) {}

    return (item.imageUrl ?? '').trim();
  }

  String _toFullImageUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return '${AppConfig.baseUrl}$url';
  }

  @override
  Widget build(BuildContext context) {
    final rawImageUrl = _resolveImage();
    final imageUrl = _toFullImageUrl(rawImageUrl);
    final hasImage = imageUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2438), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF25324A),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 80,
                height: 80,
                color: const Color(0xFF111827),
                child: hasImage
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
                      )
                    : const _ImagePlaceholder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.titleRu,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (item.description ?? '').trim().isEmpty
                                    ? 'Описание отсутствует'
                                    : item.description!.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF8FA1BC),
                                  fontSize: 11,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onToggleAvailability,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: item.isAvailable
                                  ? const Color(0xFF4B9E2F).withOpacity(0.18)
                                  : const Color(0xFF374151),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              item.isAvailable
                                  ? Icons.power_settings_new
                                  : Icons.power_off,
                              size: 16,
                              color: item.isAvailable
                                  ? const Color(0xFF67D33D)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          '${item.price} ₸',
                          style: const TextStyle(
                            color: Color(0xFF58C437),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A3346),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              categoryTitle,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF9AA7BD),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        _CircleActionButton(
                          icon: Icons.edit,
                          bg: const Color(0xFF2563EB).withOpacity(0.18),
                          color: const Color(0xFF60A5FA),
                          onTap: onEdit,
                        ),
                        const SizedBox(width: 6),
                        _CircleActionButton(
                          icon: Icons.delete_outline,
                          bg: const Color(0xFFDC2626).withOpacity(0.18),
                          color: const Color(0xFFF87171),
                          onTap: onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.bg,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color bg;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.image_outlined,
        color: Color(0xFF475569),
        size: 24,
      ),
    );
  }
}
``

## FILE: lib\features\menu\presentation\widgets\menuCreateActionSheet.dart

- Size: 6517 bytes

``dart
import 'dart:ui';
import 'package:flutter/material.dart';

class MenuCreateActionSheet extends StatelessWidget {
  const MenuCreateActionSheet({
    super.key,
    required this.onAddProduct,
    required this.onAddCategory,
  });

  final VoidCallback onAddProduct;
  final VoidCallback onAddCategory;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1C2C44),
                    Color(0xFF0F1B2D),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  const Text(
                    'Выберите действие',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ActionCard(
                    iconBg: const Color(0x66FFFFFF),
                    accent: const Color(0xFF6BCB3D),
                    background: const LinearGradient(
                      colors: [Color(0xFF4CAF2A), Color(0xFF419A25)],
                    ),
                    icon: Icons.restaurant_menu,
                    title: 'Создать товар',
                    subtitle: 'Добавить новое блюдо в меню',
                    onTap: onAddProduct,
                  ),
                  const SizedBox(height: 12),
                  _ActionCard(
                    iconBg: const Color(0xFF5B3C91),
                    accent: const Color(0xFFB388FF),
                    background: const LinearGradient(
                      colors: [Color(0xFF2B3E57), Color(0xFF223248)],
                    ),
                    icon: Icons.add_box_outlined,
                    title: 'Создать категорию',
                    subtitle: 'Добавить новую категорию',
                    onTap: onAddCategory,
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Отмена',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.iconBg,
    required this.accent,
    required this.background,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color iconBg;
  final Color accent;
  final Gradient background;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
``

## FILE: lib\features\navigation\presentation\pages\restaurant_shell_page.dart

- Size: 3542 bytes

``dart
import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/core/session/restaurant_session.dart';
import 'package:jetkiz_restaurant/features/finance/presentation/pages/restaurant_finance_page.dart';
import 'package:jetkiz_restaurant/features/menu/presentation/pages/restaurant_menu_page.dart';
import 'package:jetkiz_restaurant/features/navigation/presentation/widgets/restaurant_bottom_bar.dart';
import 'package:jetkiz_restaurant/features/orders/presentation/pages/restaurant_orders_page.dart'
    as orders_page;
import 'package:jetkiz_restaurant/features/restaurant/data/restaurant_api.dart';
import 'package:jetkiz_restaurant/features/restaurant_profile/presentation/pages/restaurant_profile_page.dart'
    as profile_page;

class RestaurantShellPage extends StatefulWidget {
  final RestaurantBottomBarTab initialTab;

  const RestaurantShellPage({
    super.key,
    this.initialTab = RestaurantBottomBarTab.orders,
  });

  @override
  State<RestaurantShellPage> createState() => _RestaurantShellPageState();
}

class _RestaurantShellPageState extends State<RestaurantShellPage> {
  late RestaurantBottomBarTab _currentTab;

  final List<RestaurantBottomBarTab> _tabOrder = <RestaurantBottomBarTab>[
    RestaurantBottomBarTab.orders,
    RestaurantBottomBarTab.menu,
    RestaurantBottomBarTab.profile,
    RestaurantBottomBarTab.finance,
    RestaurantBottomBarTab.support,
  ];

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _loadRestaurant();
  }

  Future<void> _loadRestaurant() async {
    try {
      final restaurantApi = RestaurantApi(ApiClient.instance);
      final restaurant = await restaurantApi.getMyRestaurant();
      RestaurantSession.restaurant = restaurant;

      if (mounted) {
        setState(() {});
      }
    } catch (e, st) {
      debugPrint('ERROR loading restaurant: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  void _onTabSelected(RestaurantBottomBarTab tab) {
    if (_currentTab == tab) return;
    if (!_tabOrder.contains(tab)) return;

    setState(() {
      _currentTab = tab;
    });
  }

  Widget _buildPage() {
    switch (_currentTab) {
      case RestaurantBottomBarTab.orders:
        return const orders_page.RestaurantOrdersPage(hideBottomBar: true);

      case RestaurantBottomBarTab.menu:
        return const RestaurantMenuPage();

      case RestaurantBottomBarTab.profile:
        return const profile_page.RestaurantProfilePage(hideBottomBar: true);

      case RestaurantBottomBarTab.finance:
        return const RestaurantFinancePage();

      case RestaurantBottomBarTab.support:
        return const _RestaurantSupportStubPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: _buildPage(),
      ),
      bottomNavigationBar: RestaurantBottomBar(
        currentTab: _currentTab,
        onTabSelected: _onTabSelected,
      ),
    );
  }
}

class _RestaurantSupportStubPage extends StatelessWidget {
  const _RestaurantSupportStubPage();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF0F1115),
      child: Center(
        child: Text(
          'Поддержка',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}
``

## FILE: lib\features\navigation\presentation\widgets\restaurant_bottom_bar.dart

- Size: 5643 bytes

``dart
import 'package:flutter/material.dart';

/// JETKIZ RESTAURANT APP
/// Bottom navigation for the restaurant shell.
///
/// ВАЖНО:
/// - Этот файл является source of truth для tab enum.
/// - Все экраны shell должны использовать именно RestaurantBottomBarTab.
/// - Текущая архитектура restaurant app:
///   orders / menu / profile / finance / support
/// - Если меняются названия вкладок, сначала меняем enum здесь,
///   потом синхронизируем restaurant_shell_page.dart.
enum RestaurantBottomBarTab {
  orders,
  menu,
  profile,
  finance,
  support,
}

class RestaurantBottomBar extends StatelessWidget {
  final RestaurantBottomBarTab currentTab;
  final ValueChanged<RestaurantBottomBarTab> onTabSelected;
  final bool isVisible;

  const RestaurantBottomBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
    this.isVisible = true,
  });

  static const List<_RestaurantBottomBarItem> _items = [
    _RestaurantBottomBarItem(
      tab: RestaurantBottomBarTab.orders,
      label: 'Заказы',
      icon: Icons.receipt_long_rounded,
    ),
    _RestaurantBottomBarItem(
      tab: RestaurantBottomBarTab.menu,
      label: 'Меню',
      icon: Icons.restaurant_menu_rounded,
    ),
    _RestaurantBottomBarItem(
      tab: RestaurantBottomBarTab.profile,
      label: 'Профиль',
      icon: Icons.storefront_rounded,
    ),
    _RestaurantBottomBarItem(
      tab: RestaurantBottomBarTab.finance,
      label: 'Финансы',
      icon: Icons.account_balance_wallet_rounded,
    ),
    _RestaurantBottomBarItem(
      tab: RestaurantBottomBarTab.support,
      label: 'Поддержка',
      icon: Icons.support_agent_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      offset: isVisible ? Offset.zero : const Offset(0, 1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        opacity: isVisible ? 1 : 0,
        child: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF2A3342),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: _items.map((item) {
                final isSelected = item.tab == currentTab;

                return Expanded(
                  child: _BottomBarButton(
                    item: item,
                    isSelected: isSelected,
                    onTap: () => onTabSelected(item.tab),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBarButton extends StatelessWidget {
  final _RestaurantBottomBarItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomBarButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF4CAF50);
    final inactiveColor = const Color(0xFF9CA3AF);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.icon,
                  size: 22,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? activeColor : inactiveColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestaurantBottomBarItem {
  final RestaurantBottomBarTab tab;
  final String label;
  final IconData icon;

  const _RestaurantBottomBarItem({
    required this.tab,
    required this.label,
    required this.icon,
  });
}
``

## FILE: lib\features\orders\data\restaurant_orders_api.dart

- Size: 5632 bytes

``dart
import 'package:flutter/foundation.dart';
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

    debugPrint('GET $path START');

    final dynamic response = await _apiClient.get(path);

    debugPrint('GET $path response: $response');
    debugPrint('GET $path response type: ${response.runtimeType}');

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

    debugPrint('GET $path START');

    final dynamic response = await _apiClient.get(path);

    debugPrint('GET $path response: $response');
    debugPrint('GET $path response type: ${response.runtimeType}');

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception('������������ ����� ������� ��� ��������� ������');
  }

  Future<Map<String, dynamic>> updateOrderStatus({
    required String id,
    required String status,
  }) async {
    final path = '/orders/$id/status';

    debugPrint('PATCH $path START with status=$status');

    final dynamic response = await _apiClient.patch(
      path,
      <String, dynamic>{'status': status},
    );

    debugPrint('PATCH $path response: $response');
    debugPrint('PATCH $path response type: ${response.runtimeType}');

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception('������������ ����� ������� ��� ���������� �������');
  }

  Future<Map<String, dynamic>> assignCourier({
    required String id,
    required String courierUserId,
  }) async {
    final path = '/orders/$id/assign-courier';

    debugPrint('PATCH $path START with courierUserId=$courierUserId');

    final dynamic response = await _apiClient.patch(
      path,
      <String, dynamic>{'courierUserId': courierUserId},
    );

    debugPrint('PATCH $path response: $response');
    debugPrint('PATCH $path response type: ${response.runtimeType}');

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception('������������ ����� ������� ��� ���������� �������');
  }

  Future<Map<String, dynamic>> unassignCourier({
    required String id,
  }) async {
    final path = '/orders/$id/unassign-courier';

    debugPrint('PATCH $path START');

    final dynamic response = await _apiClient.patch(
      path,
      <String, dynamic>{},
    );

    debugPrint('PATCH $path response: $response');
    debugPrint('PATCH $path response type: ${response.runtimeType}');

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception('������������ ����� ������� ��� ������ �������');
  }

  Future<Map<String, dynamic>> autoAssignCourier({
    required String id,
  }) async {
    final path = '/orders/$id/auto-assign';

    debugPrint('PATCH $path START');

    final dynamic response = await _apiClient.patch(
      path,
      <String, dynamic>{},
    );

    debugPrint('PATCH $path response: $response');
    debugPrint('PATCH $path response type: ${response.runtimeType}');

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception('������������ ����� ������� ��� �������������� �������');
  }
}
``

## FILE: lib\features\orders\domain\restaurant_order.dart

- Size: 5880 bytes

``dart
// JETKIZ RESTAURANT APP
// Order list model for restaurant-side orders screen.
//
// BACKEND CONTRACT:
// GET /orders
//
// Confirmed fields from backend:
// - id
// - number
// - status
// - subtotal
// - deliveryFee
// - total
// - paymentStatus
// - comment
// - leaveAtDoor
// - phone
// - assignedAt
// - pickedUpAt
// - deliveredAt
// - promisedAt
// - user
// - courier
// - previewItems / items / itemsCount
//
// Important:
// Backend already filters orders by current restaurantId for RESTAURANT role.
// This model is intentionally built from real confirmed fields only.

class RestaurantOrder {
  final String id;
  final int? number;
  final String status;
  final int subtotal;
  final int deliveryFee;
  final int total;
  final String? paymentStatus;
  final String? comment;
  final bool leaveAtDoor;
  final String? phone;
  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? promisedAt;
  final RestaurantOrderUser? user;
  final RestaurantOrderCourier? courier;
  final List<RestaurantOrderItem> items;
  final int itemsCount;
  final DateTime? createdAt;

  const RestaurantOrder({
    required this.id,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.leaveAtDoor,
    required this.items,
    required this.itemsCount,
    this.number,
    this.paymentStatus,
    this.comment,
    this.phone,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.promisedAt,
    this.user,
    this.courier,
    this.createdAt,
  });

  factory RestaurantOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];

    return RestaurantOrder(
      id: json['id']?.toString() ?? '',
      number: _toInt(json['number']),
      status: json['status']?.toString() ?? 'UNKNOWN',
      subtotal: _toInt(json['subtotal']) ?? 0,
      deliveryFee: _toInt(json['deliveryFee']) ?? 0,
      total: _toInt(json['total']) ?? 0,
      paymentStatus: json['paymentStatus']?.toString(),
      comment: json['comment']?.toString(),
      leaveAtDoor: json['leaveAtDoor'] == true,
      phone: json['phone']?.toString(),
      assignedAt: _toDateTime(json['assignedAt']),
      pickedUpAt: _toDateTime(json['pickedUpAt']),
      deliveredAt: _toDateTime(json['deliveredAt']),
      promisedAt: _toDateTime(json['promisedAt']),
      user: json['user'] is Map<String, dynamic>
          ? RestaurantOrderUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      courier: json['courier'] is Map<String, dynamic>
          ? RestaurantOrderCourier.fromJson(
              json['courier'] as Map<String, dynamic>,
            )
          : null,
      items: rawItems
          .whereType<Map>()
          .map((e) => RestaurantOrderItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      itemsCount: _toInt(json['itemsCount']) ?? rawItems.length,
      createdAt: _toDateTime(json['createdAt']),
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _toDateTime(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

class RestaurantOrderItem {
  final String id;
  final String? productId;
  final String title;
  final int price;
  final int quantity;

  const RestaurantOrderItem({
    required this.id,
    required this.title,
    required this.price,
    required this.quantity,
    this.productId,
  });

  factory RestaurantOrderItem.fromJson(Map<String, dynamic> json) {
    return RestaurantOrderItem(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString(),
      title: json['title']?.toString() ?? 'Без названия',
      price: RestaurantOrder._toInt(json['price']) ?? 0,
      quantity: RestaurantOrder._toInt(json['quantity']) ?? 0,
    );
  }
}

class RestaurantOrderUser {
  final String id;
  final String? phone;
  final String? firstName;
  final String? lastName;

  const RestaurantOrderUser({
    required this.id,
    this.phone,
    this.firstName,
    this.lastName,
  });

  factory RestaurantOrderUser.fromJson(Map<String, dynamic> json) {
    return RestaurantOrderUser(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString(),
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
    );
  }

  String get displayName {
    final fullName = [
      firstName?.trim() ?? '',
      lastName?.trim() ?? '',
    ].where((e) => e.isNotEmpty).join(' ');
    if (fullName.isNotEmpty) return fullName;
    if ((phone ?? '').trim().isNotEmpty) return phone!.trim();
    return 'Клиент';
  }
}

class RestaurantOrderCourier {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? phone;

  const RestaurantOrderCourier({
    required this.id,
    this.firstName,
    this.lastName,
    this.phone,
  });

  factory RestaurantOrderCourier.fromJson(Map<String, dynamic> json) {
    return RestaurantOrderCourier(
      id: json['id']?.toString() ?? '',
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
      phone: json['phone']?.toString(),
    );
  }

  String get displayName {
    final fullName = [
      firstName?.trim() ?? '',
      lastName?.trim() ?? '',
    ].where((e) => e.isNotEmpty).join(' ');
    if (fullName.isNotEmpty) return fullName;
    if ((phone ?? '').trim().isNotEmpty) return phone!.trim();
    return 'Курьер';
  }
}
``

## FILE: lib\features\orders\domain\restaurant_order_details.dart

- Size: 7880 bytes

``dart
// JETKIZ RESTAURANT APP
// Restaurant order details model.
//
// BACKEND CONTRACT:
// GET /orders/:id
//
// Confirmed fields:
// - id
// - number
// - status
// - subtotal
// - deliveryFee
// - discountAmount
// - deliveryDiscountAmount
// - total
// - phone
// - comment
// - leaveAtDoor
// - paymentMethod
// - paymentStatus
// - pricingSource
// - assignedAt
// - pickedUpAt
// - deliveredAt
// - promisedAt
// - createdAt
// - updatedAt
// - user
// - restaurant
// - courier
// - items[]

class RestaurantOrderDetails {
  final String id;
  final int? number;
  final String status;

  final int subtotal;
  final int deliveryFee;
  final int discountAmount;
  final int deliveryDiscountAmount;
  final int total;

  final String? phone;
  final String? comment;
  final bool leaveAtDoor;

  final String? paymentMethod;
  final String? paymentStatus;
  final String? pricingSource;

  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? promisedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final RestaurantOrderDetailsCustomer? user;
  final RestaurantOrderDetailsRestaurant? restaurant;
  final RestaurantOrderDetailsCourier? courier;
  final List<RestaurantOrderDetailsItem> items;

  const RestaurantOrderDetails({
    required this.id,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.discountAmount,
    required this.deliveryDiscountAmount,
    required this.total,
    required this.leaveAtDoor,
    required this.items,
    this.number,
    this.phone,
    this.comment,
    this.paymentMethod,
    this.paymentStatus,
    this.pricingSource,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.promisedAt,
    this.createdAt,
    this.updatedAt,
    this.user,
    this.restaurant,
    this.courier,
  });

  int get itemsCount => items.length;

  String? get address => restaurant?.address;

  factory RestaurantOrderDetails.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];

    return RestaurantOrderDetails(
      id: json['id']?.toString() ?? '',
      number: _toInt(json['number']),
      status: json['status']?.toString() ?? 'UNKNOWN',
      subtotal: _toInt(json['subtotal']) ?? 0,
      deliveryFee: _toInt(json['deliveryFee']) ?? 0,
      discountAmount: _toInt(json['discountAmount']) ?? 0,
      deliveryDiscountAmount: _toInt(json['deliveryDiscountAmount']) ?? 0,
      total: _toInt(json['total']) ?? 0,
      phone: json['phone']?.toString(),
      comment: json['comment']?.toString(),
      leaveAtDoor: json['leaveAtDoor'] == true,
      paymentMethod: json['paymentMethod']?.toString(),
      paymentStatus: json['paymentStatus']?.toString(),
      pricingSource: json['pricingSource']?.toString(),
      assignedAt: _toDateTime(json['assignedAt']),
      pickedUpAt: _toDateTime(json['pickedUpAt']),
      deliveredAt: _toDateTime(json['deliveredAt']),
      promisedAt: _toDateTime(json['promisedAt']),
      createdAt: _toDateTime(json['createdAt']),
      updatedAt: _toDateTime(json['updatedAt']),
      user: json['user'] is Map<String, dynamic>
          ? RestaurantOrderDetailsCustomer.fromJson(
              json['user'] as Map<String, dynamic>,
            )
          : null,
      restaurant: json['restaurant'] is Map<String, dynamic>
          ? RestaurantOrderDetailsRestaurant.fromJson(
              json['restaurant'] as Map<String, dynamic>,
            )
          : null,
      courier: json['courier'] is Map<String, dynamic>
          ? RestaurantOrderDetailsCourier.fromJson(
              json['courier'] as Map<String, dynamic>,
            )
          : null,
      items: rawItems
          .whereType<Map>()
          .map(
            (e) => RestaurantOrderDetailsItem.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _toDateTime(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

class RestaurantOrderDetailsItem {
  final String id;
  final String? productId;
  final String title;
  final int price;
  final int quantity;

  const RestaurantOrderDetailsItem({
    required this.id,
    required this.title,
    required this.price,
    required this.quantity,
    this.productId,
  });

  factory RestaurantOrderDetailsItem.fromJson(Map<String, dynamic> json) {
    return RestaurantOrderDetailsItem(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString(),
      title: json['title']?.toString() ?? 'Без названия',
      price: RestaurantOrderDetails._toInt(json['price']) ?? 0,
      quantity: RestaurantOrderDetails._toInt(json['quantity']) ?? 0,
    );
  }
}

class RestaurantOrderDetailsCustomer {
  final String id;
  final String? phone;
  final String? firstName;
  final String? lastName;

  const RestaurantOrderDetailsCustomer({
    required this.id,
    this.phone,
    this.firstName,
    this.lastName,
  });

  factory RestaurantOrderDetailsCustomer.fromJson(Map<String, dynamic> json) {
    return RestaurantOrderDetailsCustomer(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString(),
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
    );
  }

  String get displayName {
    final fullName = [
      firstName?.trim() ?? '',
      lastName?.trim() ?? '',
    ].where((e) => e.isNotEmpty).join(' ');

    if (fullName.isNotEmpty) return fullName;
    if ((phone ?? '').trim().isNotEmpty) return phone!.trim();
    return 'Клиент';
  }
}

class RestaurantOrderDetailsCourier {
  final String id;
  final String? phone;
  final String? firstName;
  final String? lastName;

  const RestaurantOrderDetailsCourier({
    required this.id,
    this.phone,
    this.firstName,
    this.lastName,
  });

  factory RestaurantOrderDetailsCourier.fromJson(Map<String, dynamic> json) {
    return RestaurantOrderDetailsCourier(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString(),
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
    );
  }

  String get displayName {
    final fullName = [
      firstName?.trim() ?? '',
      lastName?.trim() ?? '',
    ].where((e) => e.isNotEmpty).join(' ');

    if (fullName.isNotEmpty) return fullName;
    if ((phone ?? '').trim().isNotEmpty) return phone!.trim();
    return 'Курьер';
  }
}

class RestaurantOrderDetailsRestaurant {
  final String id;
  final String? slug;
  final String? nameRu;
  final String? nameKk;
  final String? coverImageUrl;
  final String? status;
  final String? address;

  const RestaurantOrderDetailsRestaurant({
    required this.id,
    this.slug,
    this.nameRu,
    this.nameKk,
    this.coverImageUrl,
    this.status,
    this.address,
  });

  factory RestaurantOrderDetailsRestaurant.fromJson(
    Map<String, dynamic> json,
  ) {
    return RestaurantOrderDetailsRestaurant(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString(),
      nameRu: json['nameRu']?.toString(),
      nameKk: json['nameKk']?.toString(),
      coverImageUrl: json['coverImageUrl']?.toString(),
      status: json['status']?.toString(),
      address: json['address']?.toString(),
    );
  }
}
``

## FILE: lib\features\orders\presentation\pages\restaurant_order_details_page.dart

- Size: 18241 bytes

``dart
import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/orders/domain/restaurant_order_details.dart';

// JETKIZ RESTAURANT APP
// Restaurant order details page.
//
// BACKEND:
// - GET /orders/:id
//
// IMPORTANT:
// This screen is intentionally kept read-only now.
// User request was only:
// "нажимая на заказ открыть подробнее"
// So no extra status-change logic is added here.

class RestaurantOrderDetailsPage extends StatefulWidget {
  const RestaurantOrderDetailsPage({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  State<RestaurantOrderDetailsPage> createState() =>
      _RestaurantOrderDetailsPageState();
}

class _RestaurantOrderDetailsPageState extends State<RestaurantOrderDetailsPage> {
  final ApiClient _apiClient = ApiClient();
  Future<RestaurantOrderDetails>? _orderFuture;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  void _loadOrder() {
    setState(() {
      _orderFuture = _getOrderDetails();
    });
  }

  Future<void> _refresh() async {
    _loadOrder();
    await _orderFuture;
  }

  Future<RestaurantOrderDetails> _getOrderDetails() async {
    final dynamic response = await _apiClient.get('/orders/${widget.orderId}');

    if (response is Map<String, dynamic>) {
      return RestaurantOrderDetails.fromJson(response);
    }

    if (response is Map) {
      return RestaurantOrderDetails.fromJson(
        Map<String, dynamic>.from(response),
      );
    }

    throw Exception('Некорректный ответ по заказу');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09111C),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Детали заказа',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<RestaurantOrderDetails>(
          future: _orderFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return _DetailsErrorState(
                message: snapshot.error.toString().replaceFirst('Exception: ', ''),
                onRetry: _loadOrder,
              );
            }

            final order = snapshot.data;
            if (order == null) {
              return _DetailsErrorState(
                message: 'Заказ не найден',
                onRetry: _loadOrder,
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.number != null
                                    ? 'Заказ #${order.number}'
                                    : 'Заказ',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _StatusBadge(status: order.status),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _InfoRow(label: 'ID', value: order.id),
                        _InfoRow(
                          label: 'Статус оплаты',
                          value: order.paymentStatus ?? 'Не указан',
                        ),
                        _InfoRow(
                          label: 'Оплата',
                          value: order.paymentMethod ?? 'Не указана',
                        ),
                        _InfoRow(
                          label: 'Подытог',
                          value: '${order.subtotal} ₸',
                        ),
                        _InfoRow(
                          label: 'Доставка',
                          value: '${order.deliveryFee} ₸',
                        ),
                        _InfoRow(
                          label: 'Итого',
                          value: '${order.total} ₸',
                        ),
                        if (order.createdAt != null)
                          _InfoRow(
                            label: 'Создан',
                            value: _formatDateTime(order.createdAt!.toLocal()),
                          ),
                        if (order.promisedAt != null)
                          _InfoRow(
                            label: 'Обещано к',
                            value: _formatDateTime(order.promisedAt!.toLocal()),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('Клиент'),
                        const SizedBox(height: 12),
                        _InfoRow(
                          label: 'Имя',
                          value: order.user?.displayName ?? 'Не указан',
                        ),
                        _InfoRow(
                          label: 'Телефон',
                          value: (order.phone ?? '').trim().isNotEmpty
                              ? order.phone!.trim()
                              : ((order.user?.phone ?? '').trim().isNotEmpty
                                  ? order.user!.phone!.trim()
                                  : 'Не указан'),
                        ),
                        _InfoRow(
                          label: 'Оставить у двери',
                          value: order.leaveAtDoor ? 'Да' : 'Нет',
                        ),
                        if ((order.comment ?? '').trim().isNotEmpty)
                          _InfoRow(
                            label: 'Комментарий',
                            value: order.comment!.trim(),
                          ),
                        if ((order.address ?? '').trim().isNotEmpty)
                          _InfoRow(
                            label: 'Адрес',
                            value: order.address!.trim(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (order.courier != null) ...[
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle('Курьер'),
                          const SizedBox(height: 12),
                          _InfoRow(
                            label: 'Имя',
                            value: order.courier!.displayName,
                          ),
                          _InfoRow(
                            label: 'Телефон',
                            value: (order.courier!.phone ?? '').trim().isNotEmpty
                                ? order.courier!.phone!.trim()
                                : 'Не указан',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('Состав заказа'),
                        const SizedBox(height: 12),
                        if (order.items.isEmpty)
                          const Text(
                            'Позиции отсутствуют',
                            style: TextStyle(color: Colors.white70),
                          )
                        else
                          ...order.items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _OrderItemTile(item: item),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime dateTime) {
    return '${_two(dateTime.day)}.${_two(dateTime.month)}.${dateTime.year} '
        '${_two(dateTime.hour)}:${_two(dateTime.minute)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131E2D),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  const _OrderItemTile({
    required this.item,
  });

  final RestaurantOrderDetailsItem item;

  @override
  Widget build(BuildContext context) {
    final total = item.price * item.quantity;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2738),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${item.quantity} × ${item.price} ₸',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$total ₸',
            style: const TextStyle(
              color: Color(0xFF70D74D),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsErrorState extends StatelessWidget {
  const _DetailsErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFFF8A8A),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF489F2A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final meta = _OrderStatusMeta.fromStatus(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: meta.backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: meta.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 14, color: meta.textColor),
          const SizedBox(width: 5),
          Text(
            meta.label,
            style: TextStyle(
              color: meta.textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderStatusMeta {
  const _OrderStatusMeta({
    required this.label,
    required this.icon,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String label;
  final IconData icon;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;

  static _OrderStatusMeta fromStatus(String status) {
    switch (status) {
      case 'CREATED':
        return const _OrderStatusMeta(
          label: 'Новый',
          icon: Icons.fiber_new,
          textColor: Color(0xFF66D7FF),
          backgroundColor: Color(0x1A66D7FF),
          borderColor: Color(0x3366D7FF),
        );
      case 'ACCEPTED':
        return const _OrderStatusMeta(
          label: 'Принят',
          icon: Icons.check_circle_outline,
          textColor: Color(0xFF00E676),
          backgroundColor: Color(0x1A00E676),
          borderColor: Color(0x3300E676),
        );
      case 'COOKING':
        return const _OrderStatusMeta(
          label: 'Готовится',
          icon: Icons.local_fire_department_outlined,
          textColor: Color(0xFFFFC857),
          backgroundColor: Color(0x1AFFC857),
          borderColor: Color(0x33FFC857),
        );
      case 'READY':
        return const _OrderStatusMeta(
          label: 'Готов',
          icon: Icons.done_all,
          textColor: Color(0xFFB46CFF),
          backgroundColor: Color(0x1AB46CFF),
          borderColor: Color(0x33B46CFF),
        );
      case 'ON_THE_WAY':
        return const _OrderStatusMeta(
          label: 'В пути',
          icon: Icons.delivery_dining,
          textColor: Color(0xFFFF9E57),
          backgroundColor: Color(0x1AFF9E57),
          borderColor: Color(0x33FF9E57),
        );
      case 'DELIVERED':
        return const _OrderStatusMeta(
          label: 'Доставлен',
          icon: Icons.verified,
          textColor: Color(0xFF7CFF9E),
          backgroundColor: Color(0x1A7CFF9E),
          borderColor: Color(0x337CFF9E),
        );
      case 'CANCELED':
        return const _OrderStatusMeta(
          label: 'Отменён',
          icon: Icons.cancel_outlined,
          textColor: Color(0xFFFF7C7C),
          backgroundColor: Color(0x1AFF7C7C),
          borderColor: Color(0x33FF7C7C),
        );
      default:
        return const _OrderStatusMeta(
          label: 'Неизвестно',
          icon: Icons.help_outline,
          textColor: Color(0xFFB0BEC5),
          backgroundColor: Color(0x1AB0BEC5),
          borderColor: Color(0x33B0BEC5),
        );
    }
  }
}
``

## FILE: lib\features\orders\presentation\pages\restaurant_orders_page.dart

- Size: 39913 bytes

``dart
import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/features/orders/data/restaurant_orders_api.dart';
import 'package:jetkiz_restaurant/features/orders/presentation/pages/restaurant_order_details_page.dart';

class RestaurantOrdersPage extends StatefulWidget {
  const RestaurantOrdersPage({
    super.key,
    this.hideBottomBar = false,
  });

  final bool hideBottomBar;

  @override
  State<RestaurantOrdersPage> createState() => _RestaurantOrdersPageState();
}

class _RestaurantOrdersPageState extends State<RestaurantOrdersPage>
    with SingleTickerProviderStateMixin {
  final RestaurantOrdersApi _ordersApi = RestaurantOrdersApi();

  late final AnimationController _blinkController;

  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> _allOrders = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _visibleOrders = <Map<String, dynamic>>[];

  final Set<String> _updatingOrderIds = <String>{};

  String _selectedStatus = 'ALL';

  final List<_OrderFilterItem> _filters = const [
    _OrderFilterItem(code: 'ALL', label: 'Все'),
    _OrderFilterItem(code: 'CREATED', label: 'Создан'),
    _OrderFilterItem(code: 'ACCEPTED', label: 'Принят'),
    _OrderFilterItem(code: 'COOKING', label: 'Готовится'),
    _OrderFilterItem(code: 'READY', label: 'Готов'),
    _OrderFilterItem(code: 'ON_THE_WAY', label: 'В пути'),
    _OrderFilterItem(code: 'DELIVERED', label: 'Доставлен'),
    _OrderFilterItem(code: 'CANCELED', label: 'Отменен'),
  ];

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _loadOrders();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final result = await _ordersApi.getOrders();

      if (!mounted) return;

      setState(() {
        _allOrders = result;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _loadOrders();
  }

  void _applyFilter() {
    if (_selectedStatus == 'ALL') {
      _visibleOrders = List<Map<String, dynamic>>.from(_allOrders);
      return;
    }

    _visibleOrders = _allOrders.where((order) {
      return _status(order) == _selectedStatus;
    }).toList();
  }

  void _selectStatus(String status) {
    if (_selectedStatus == status) return;

    setState(() {
      _selectedStatus = status;
      _applyFilter();
    });
  }

  Future<void> _openOrder(Map<String, dynamic> order) async {
    final orderId = _orderId(order);

    if (orderId.isEmpty) {
      final number = _orderNumber(order);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('�� ������� ������� ����� #$number'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RestaurantOrderDetailsPage(orderId: orderId),
      ),
    );

    if (!mounted) return;
    await _loadOrders();
  }

  Future<void> _changeStatus(
    Map<String, dynamic> order,
    String newStatus,
  ) async {
    final orderId = _orderId(order);
    if (orderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('�� ������� ���������� ID ������'),
        ),
      );
      return;
    }

    if (_updatingOrderIds.contains(orderId)) return;

    setState(() {
      _updatingOrderIds.add(orderId);
    });

    try {
      final updated = await _ordersApi.updateOrderStatus(
        id: orderId,
        status: newStatus,
      );

      if (!mounted) return;

      final updatedStatus =
          (updated['status'] ?? updated['orderStatus'] ?? newStatus).toString();

      final updatedOrder = Map<String, dynamic>.from(order);
      updatedOrder['status'] = updatedStatus;
      if (updated.containsKey('updatedAt')) {
        updatedOrder['updatedAt'] = updated['updatedAt'];
      }
      if (updated.containsKey('pickedUpAt')) {
        updatedOrder['pickedUpAt'] = updated['pickedUpAt'];
      }
      if (updated.containsKey('deliveredAt')) {
        updatedOrder['deliveredAt'] = updated['deliveredAt'];
      }

      final index = _allOrders.indexWhere((item) => _orderId(item) == orderId);
      if (index != -1) {
        _allOrders[index] = updatedOrder;
      }

      setState(() {
        _applyFilter();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '������ ������ #${_orderNumber(order)} ������: ${_statusLabel(updatedStatus)}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingOrderIds.remove(orderId);
        });
      }
    }
  }

  String _status(Map<String, dynamic> order) {
    final dynamic value = order['status'] ?? order['orderStatus'];
    return value?.toString() ?? 'UNKNOWN';
  }

  String _orderId(Map<String, dynamic> order) {
    final dynamic value =
        order['id'] ?? order['_id'] ?? order['orderId'] ?? order['number'];
    return value?.toString() ?? '';
  }

  String _orderNumber(Map<String, dynamic> order) {
    final dynamic value =
        order['number'] ?? order['id'] ?? order['_id'] ?? order['orderId'];
    return value?.toString() ?? '�';
  }

  int _total(Map<String, dynamic> order) {
    final dynamic value =
        order['total'] ?? order['totalPrice'] ?? order['sum'] ?? 0;

    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  String _customerName(Map<String, dynamic> order) {
    final dynamic user = order['user'];

    if (user is Map<String, dynamic>) {
      final first = (user['firstName'] ?? '').toString().trim();
      final last = (user['lastName'] ?? '').toString().trim();
      final full = '$first $last'.trim();
      if (full.isNotEmpty) return full;

      final phone = (user['phone'] ?? '').toString().trim();
      if (phone.isNotEmpty) return phone;
    }

    final phone = (order['phone'] ?? '').toString().trim();
    if (phone.isNotEmpty) return phone;

    final customerName = (order['customerName'] ?? '').toString().trim();
    if (customerName.isNotEmpty) return customerName;

    return '������';
  }

  String _itemsPreview(Map<String, dynamic> order) {
    final dynamic rawItems = order['items'];

    if (rawItems is! List || rawItems.isEmpty) {
      return '������ ������ �� ������';
    }

    final items = rawItems.whereType<Map>().toList();
    if (items.isEmpty) return '������ ������ �� ������';

    final titles = items.take(2).map((item) {
      final title = (item['title'] ?? item['name'] ?? '��� ��������').toString();
      final qty = item['quantity']?.toString() ?? '1';
      return '$title ?$qty';
    }).join(', ');

    if (items.length <= 2) return titles;
    return '$titles � ��� ${items.length - 2}';
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    final parsed = DateTime.tryParse(value.toString());
    return parsed;
  }

  DateTime? _createdAt(Map<String, dynamic> order) {
    return _parseDate(order['createdAt']);
  }

  DateTime? _promisedAt(Map<String, dynamic> order) {
    return _parseDate(order['promisedAt']);
  }

  bool _isOverdue(Map<String, dynamic> order) {
    final promisedAt = _promisedAt(order);
    final status = _status(order);

    if (promisedAt == null) return false;
    if (status == 'DELIVERED' || status == 'CANCELED') return false;

    return DateTime.now().isAfter(promisedAt.toLocal());
  }

  String _formatHm(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _timeText(Map<String, dynamic> order) {
    final createdAt = _createdAt(order);
    final promisedAt = _promisedAt(order);

    if (createdAt == null && promisedAt == null) {
      return '����� �� �������';
    }

    final created = createdAt != null ? _formatHm(createdAt.toLocal()) : null;
    final promised = promisedAt != null ? _formatHm(promisedAt.toLocal()) : null;

    if (created != null && promised != null) {
      final remain = promisedAt!.difference(DateTime.now()).inMinutes;
      final remainText = remain >= 0
          ? '$remain ��� ��������'
          : '${remain.abs()} ��� ���������';
      return '$created � $remainText';
    }

    return created ?? promised ?? '����� �� �������';
  }

  List<_OrderAction> _actionsForStatus(String status) {
    switch (status) {
      case 'CREATED':
        return const [
          _OrderAction(
            nextStatus: 'ACCEPTED',
            label: '�������',
            icon: Icons.check_rounded,
            isPrimary: false,
          ),
          _OrderAction(
            nextStatus: 'ACCEPTED',
            label: '������ ��������',
            icon: Icons.local_fire_department_outlined,
            isPrimary: true,
          ),
          _OrderAction(
            nextStatus: 'CANCELED',
            label: '��������',
            icon: Icons.close_rounded,
            isDanger: true,
          ),
        ];
      case 'ACCEPTED':
        return const [
          _OrderAction(
            nextStatus: 'COOKING',
            label: '������ ��������',
            icon: Icons.local_fire_department_outlined,
            isPrimary: true,
          ),
          _OrderAction(
            nextStatus: 'CANCELED',
            label: '��������',
            icon: Icons.close_rounded,
            isDanger: true,
          ),
        ];
      case 'COOKING':
        return const [
          _OrderAction(
            nextStatus: 'READY',
            label: '������',
            icon: Icons.done_all_rounded,
            isPrimary: true,
          ),
          _OrderAction(
            nextStatus: 'CANCELED',
            label: '��������',
            icon: Icons.close_rounded,
            isDanger: true,
          ),
        ];
      case 'READY':
        return const [
          _OrderAction(
            nextStatus: 'ON_THE_WAY',
            label: '������� �������',
            icon: Icons.delivery_dining_rounded,
            isPrimary: false,
          ),
          _OrderAction(
            nextStatus: 'ON_THE_WAY',
            label: '�������� �������',
            icon: Icons.delivery_dining_rounded,
            isPrimary: true,
          ),
          _OrderAction(
            nextStatus: 'CANCELED',
            label: '��������',
            icon: Icons.close_rounded,
            isDanger: true,
          ),
        ];
      case 'ON_THE_WAY':
        return const [];
      default:
        return const [];
    }
  }

  String _statusLabel(String status) {
    return _OrderStatusMeta.fromStatus(status).label;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      appBar: widget.hideBottomBar
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF09111C),
              elevation: 0,
              centerTitle: true,
              title: const Text(
                '������',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            _OrdersHeader(
              filters: _filters,
              selectedStatus: _selectedStatus,
              onSelect: _selectStatus,
            ),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const _OrdersLoadingState();
    }

    if (_error != null) {
      return _OrdersErrorState(
        message: _error!,
        onRetry: _loadOrders,
      );
    }

    if (_visibleOrders.isEmpty) {
      return _OrdersEmptyState(
        statusCode: _selectedStatus,
        onRefresh: _refresh,
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        itemCount: _visibleOrders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = _visibleOrders[index];
          final orderId = _orderId(order);

          return _RestaurantOrderCard(
            orderNumber: _orderNumber(order),
            customerName: _customerName(order),
            itemsPreview: _itemsPreview(order),
            total: _total(order),
            timeText: _timeText(order),
            status: _status(order),
            isOverdue: _isOverdue(order),
            blinkAnimation: _blinkController,
            isUpdating: _updatingOrderIds.contains(orderId),
            actions: _actionsForStatus(_status(order)),
            onTap: () => _openOrder(order),
            onActionTap: (action) => _changeStatus(order, action.nextStatus),
          );
        },
      ),
    );
  }
}

class _OrdersHeader extends StatelessWidget {
  const _OrdersHeader({
    required this.filters,
    required this.selectedStatus,
    required this.onSelect,
  });

  final List<_OrderFilterItem> filters;
  final String selectedStatus;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF489F2A),
            Color(0xFF3C861F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33489F2A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  '������ ���������',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.volume_up_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = filters[index];
                final isActive = item.code == selectedStatus;

                return GestureDetector(
                  onTap: () => onSelect(item.code),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isActive
                            ? Colors.white
                            : Colors.white.withOpacity(0.18),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: isActive
                              ? const Color(0xFF489F2A)
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantOrderCard extends StatelessWidget {
  const _RestaurantOrderCard({
    required this.orderNumber,
    required this.customerName,
    required this.itemsPreview,
    required this.total,
    required this.timeText,
    required this.status,
    required this.isOverdue,
    required this.blinkAnimation,
    required this.isUpdating,
    required this.actions,
    required this.onTap,
    required this.onActionTap,
  });

  final String orderNumber;
  final String customerName;
  final String itemsPreview;
  final int total;
  final String timeText;
  final String status;
  final bool isOverdue;
  final Animation<double> blinkAnimation;
  final bool isUpdating;
  final List<_OrderAction> actions;
  final VoidCallback onTap;
  final ValueChanged<_OrderAction> onActionTap;

  @override
  Widget build(BuildContext context) {
    final statusMeta = _OrderStatusMeta.fromStatus(status);

    return AnimatedBuilder(
      animation: blinkAnimation,
      builder: (context, child) {
        final highlightOpacity =
            isOverdue ? (0.22 + (blinkAnimation.value * 0.30)) : 0.0;

        return GestureDetector(
          onTap: isUpdating ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF142234),
                  Color(0xFF0B1421),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: isOverdue
                    ? Color.lerp(
                        const Color(0x33FF5E5E),
                        const Color(0x99FF5E5E),
                        highlightOpacity,
                      )!
                    : const Color(0xFF223247),
              ),
              boxShadow: [
                const BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
                if (isOverdue)
                  BoxShadow(
                    color: Color.lerp(
                      const Color(0x00FF5E5E),
                      const Color(0x55FF5E5E),
                      highlightOpacity,
                    )!,
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _CircleIcon(
                icon: Icons.inventory_2_outlined,
                iconColor: Color(0xFF70D74D),
                backgroundColor: Color(0x1A70D74D),
                borderColor: Color(0x3370D74D),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '����� #$orderNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusChip(meta: statusMeta),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.access_time,
                color: Color(0xFF8A98AC),
                size: 14,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  timeText,
                  style: const TextStyle(
                    color: Color(0xFF8A98AC),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isOverdue)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x22FF5E5E),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x55FF5E5E)),
                  ),
                  child: const Text(
                    '���������',
                    style: TextStyle(
                      color: Color(0xFFFF8A8A),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0x33060C15),
              border: Border.all(color: const Color(0xFF1E2B3D)),
            ),
            child: Column(
              children: [
                _OrderInfoRow(
                  icon: Icons.person_outline,
                  title: customerName,
                  trailing: '��������� >',
                  trailingColor: const Color(0xFF63C73E),
                ),
                const SizedBox(height: 10),
                _OrderInfoRow(
                  icon: Icons.receipt_long_outlined,
                  title: itemsPreview,
                ),
                const SizedBox(height: 10),
                _OrderInfoRow(
                  icon: Icons.payments_outlined,
                  title: '�����',
                  trailing: '$total ?',
                  trailingColor: const Color(0xFF70D74D),
                ),
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _OrderActionsSection(
              actions: actions,
              isUpdating: isUpdating,
              onActionTap: onActionTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderActionsSection extends StatelessWidget {
  const _OrderActionsSection({
    required this.actions,
    required this.isUpdating,
    required this.onActionTap,
  });

  final List<_OrderAction> actions;
  final bool isUpdating;
  final ValueChanged<_OrderAction> onActionTap;

  @override
  Widget build(BuildContext context) {
    final primaryAction = actions.where((e) => e.isPrimary).toList();
    final secondaryActions = actions.where((e) => !e.isPrimary).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (primaryAction.isNotEmpty)
          _PrimaryActionButton(
            action: primaryAction.first,
            isLoading: isUpdating,
            onTap: isUpdating ? null : () => onActionTap(primaryAction.first),
          ),
        if (secondaryActions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: secondaryActions.map((action) {
              return _SecondaryActionButton(
                action: action,
                isLoading: isUpdating,
                onTap: isUpdating ? null : () => onActionTap(action),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.action,
    required this.isLoading,
    required this.onTap,
  });

  final _OrderAction action;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = action.isDanger
        ? const Color(0xFF6C1E24)
        : const Color(0xFF63C73E);

    final foregroundColor =
        action.isDanger ? const Color(0xFFFFB6BD) : const Color(0xFF0D1A0F);

    return SizedBox(
      height: 46,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withOpacity(0.55),
          disabledForegroundColor: foregroundColor.withOpacity(0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                ),
              )
            : Icon(action.icon, size: 18),
        label: Text(
          isLoading ? '����������...' : action.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.action,
    required this.isLoading,
    required this.onTap,
  });

  final _OrderAction action;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        action.isDanger ? const Color(0x66FF7C7C) : const Color(0x554D79FF);
    final backgroundColor =
        action.isDanger ? const Color(0x22FF7C7C) : const Color(0x334D79FF);
    final foregroundColor =
        action.isDanger ? const Color(0xFFFF9DA6) : const Color(0xFFAEBEFF);

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                  ),
                )
              else
                Icon(
                  action.icon,
                  size: 16,
                  color: foregroundColor,
                ),
              const SizedBox(width: 8),
              Text(
                action.label,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderInfoRow extends StatelessWidget {
  const _OrderInfoRow({
    required this.icon,
    required this.title,
    this.trailing,
    this.trailingColor,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF8A98AC), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Text(
            trailing!,
            style: TextStyle(
              color: trailingColor ?? const Color(0xFF9AA7B8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.meta});

  final _OrderStatusMeta meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: meta.backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: meta.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, color: meta.textColor, size: 13),
          const SizedBox(width: 4),
          Text(
            meta.label,
            style: TextStyle(
              color: meta.textColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: Border.all(color: borderColor),
      ),
      child: Icon(icon, size: 18, color: iconColor),
    );
  }
}

class _OrdersLoadingState extends StatelessWidget {
  const _OrdersLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      children: List.generate(
        4,
        (index) => Container(
          height: 220,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: const Color(0xFF132131),
            border: Border.all(color: const Color(0xFF223247)),
          ),
          child: const Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrdersErrorState extends StatelessWidget {
  const _OrdersErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFFF8A8A),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF489F2A),
                foregroundColor: Colors.white,
              ),
              child: const Text('���������'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersEmptyState extends StatelessWidget {
  const _OrdersEmptyState({
    required this.statusCode,
    required this.onRefresh,
  });

  final String statusCode;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final text = statusCode == 'ALL'
        ? '������� ���� ���'
        : '�� ���������� ������� ������� ���';

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: const Color(0xFF111C2B),
              border: Border.all(color: const Color(0xFF223247)),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: Color(0xFF489F2A),
                  size: 46,
                ),
                SizedBox(height: 12),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '������ ���� ��� ����������',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderFilterItem {
  const _OrderFilterItem({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;
}

class _OrderAction {
  const _OrderAction({
    required this.nextStatus,
    required this.label,
    required this.icon,
    this.isPrimary = false,
    this.isDanger = false,
  });

  final String nextStatus;
  final String label;
  final IconData icon;
  final bool isPrimary;
  final bool isDanger;
}

class _OrderStatusMeta {
  const _OrderStatusMeta({
    required this.label,
    required this.icon,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String label;
  final IconData icon;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;

  static _OrderStatusMeta fromStatus(String status) {
    switch (status) {
      case 'CREATED':
        return const _OrderStatusMeta(
          label: 'Создан',
          icon: Icons.fiber_new,
          textColor: Color(0xFF66D7FF),
          backgroundColor: Color(0x1A66D7FF),
          borderColor: Color(0x3366D7FF),
        );
      case 'ACCEPTED':
        return const _OrderStatusMeta(
          label: 'Принят',
          icon: Icons.check_circle_outline,
          textColor: Color(0xFF00E676),
          backgroundColor: Color(0x1A00E676),
          borderColor: Color(0x3300E676),
        );
      case 'COOKING':
        return const _OrderStatusMeta(
          label: 'Готовится',
          icon: Icons.local_fire_department_outlined,
          textColor: Color(0xFFFFC857),
          backgroundColor: Color(0x1AFFC857),
          borderColor: Color(0x33FFC857),
        );
      case 'READY':
        return const _OrderStatusMeta(
          label: 'Готов',
          icon: Icons.done_all,
          textColor: Color(0xFFB46CFF),
          backgroundColor: Color(0x1AB46CFF),
          borderColor: Color(0x33B46CFF),
        );
      case 'ON_THE_WAY':
        return const _OrderStatusMeta(
          label: 'В пути',
          icon: Icons.delivery_dining,
          textColor: Color(0xFFFF9E57),
          backgroundColor: Color(0x1AFF9E57),
          borderColor: Color(0x33FF9E57),
        );
      case 'DELIVERED':
        return const _OrderStatusMeta(
          label: 'Доставлен',
          icon: Icons.verified,
          textColor: Color(0xFF7CFF9E),
          backgroundColor: Color(0x1A7CFF9E),
          borderColor: Color(0x337CFF9E),
        );
      case 'CANCELED':
        return const _OrderStatusMeta(
          label: 'Отменен',
          icon: Icons.cancel_outlined,
          textColor: Color(0xFFFF7C7C),
          backgroundColor: Color(0x1AFF7C7C),
          borderColor: Color(0x33FF7C7C),
        );
      default:
        return const _OrderStatusMeta(
          label: 'Неизвестно',
          icon: Icons.help_outline,
          textColor: Color(0xFFB0BEC5),
          backgroundColor: Color(0x1AB0BEC5),
          borderColor: Color(0x33B0BEC5),
        );
    }
  }
}
``

## FILE: lib\features\orders\presentation\widgets\order_card.dart

- Size: 1210 bytes

``dart
import 'package:flutter/material.dart';
import '../../domain/restaurant_order.dart';

class OrderCard extends StatelessWidget {
  final RestaurantOrder order;
  final VoidCallback? onTap;

  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D23),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '����� #${order.id}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              order.status,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}



``

## FILE: lib\features\restaurant\data\restaurant_api.dart

- Size: 1209 bytes

``dart
import 'dart:io';

import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/restaurant/domain/restaurant_profile_data.dart';

class RestaurantApi {
  final ApiClient _client;

  RestaurantApi(this._client);

  Future<RestaurantProfileData> getMyRestaurant() async {
    final response = await _client.get('/restaurants/me');

    return RestaurantProfileData.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<RestaurantProfileData> updateMe({
    required String address,
    required String phone,
    required String workingHours,
  }) async {
    final response = await _client.patch(
      '/restaurants/me',
      {
        'address': address,
        'phone': phone,
        'workingHours': workingHours,
      },
    );

    return RestaurantProfileData.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<RestaurantProfileData> uploadRestaurantCover(File file) async {
    final currentProfile = await getMyRestaurant();

    await _client.uploadFile(
      '/restaurants/${currentProfile.id}/cover',
      file: file,
      fieldName: 'file',
    );

    return getMyRestaurant();
  }
}
``

## FILE: lib\features\restaurant\data\restaurant_metrics_api.dart

- Size: 1267 bytes

``dart
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

    return RestaurantMetricsData.fromJson(
      Map<String, dynamic>.from(response),
    );
  }
}
``

## FILE: lib\features\restaurant\domain\restaurant_metrics_data.dart

- Size: 14192 bytes

``dart
class RestaurantMetricsData {
  final RestaurantMetricsRestaurant? restaurant;
  final RestaurantMetricsPeriod period;
  final RestaurantMetricsOverview overview;
  final List<RestaurantDailyMetric> daily;
  final RestaurantCustomerStats customers;
  final RestaurantReviewStats reviews;
  final RestaurantTrendStats trends;
  final List<RestaurantRecentOrderMetric> recentOrders;
  final List<RestaurantTopClientMetric> topClients;
  final Map<String, int> rfmDistribution;
  final List<RestaurantSuggestion> suggestions;

  const RestaurantMetricsData({
    required this.restaurant,
    required this.period,
    required this.overview,
    required this.daily,
    required this.customers,
    required this.reviews,
    required this.trends,
    required this.recentOrders,
    required this.topClients,
    required this.rfmDistribution,
    required this.suggestions,
  });

  factory RestaurantMetricsData.fromJson(Map<String, dynamic> json) {
    final revenue = _asMap(json['revenue']) ?? const <String, dynamic>{};
    final rates = _asMap(json['rates']) ?? const <String, dynamic>{};
    final customers = _asMap(json['customers']) ?? const <String, dynamic>{};
    final reviews = _asMap(json['reviews']) ?? const <String, dynamic>{};

    return RestaurantMetricsData(
      restaurant: _asMap(json['restaurant']) == null
          ? null
          : RestaurantMetricsRestaurant.fromJson(
              _asMap(json['restaurant']) ?? const <String, dynamic>{},
            ),
      period: RestaurantMetricsPeriod.fromJson(
        _asMap(json['period']) ?? const <String, dynamic>{},
      ),
      overview: RestaurantMetricsOverview.fromJson(
        <String, dynamic>{
          ...json,
          ...revenue,
          ...rates,
        },
      ),
      daily: _asList(json['daily'])
          .map((e) => RestaurantDailyMetric.fromJson(_asMap(e) ?? const {}))
          .toList(),
      customers: RestaurantCustomerStats.fromJson(customers),
      reviews: RestaurantReviewStats.fromJson(reviews),
      trends: RestaurantTrendStats.fromJson(json),
      recentOrders: _asList(json['recentOrders'])
          .map(
            (e) => RestaurantRecentOrderMetric.fromJson(
              _asMap(e) ?? const <String, dynamic>{},
            ),
          )
          .toList(),
      topClients: _asList(json['topClients'])
          .map(
            (e) => RestaurantTopClientMetric.fromJson(
              _asMap(e) ?? const <String, dynamic>{},
            ),
          )
          .toList(),
      rfmDistribution: _parseStringIntMap(customers['rfmDistribution']),
      suggestions: _asList(json['suggestions'])
          .map(
            (e) => RestaurantSuggestion.fromJson(
              _asMap(e) ?? const <String, dynamic>{},
            ),
          )
          .toList(),
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<dynamic> _asList(dynamic value) {
    return value is List ? value : const <dynamic>[];
  }

  static Map<String, int> _parseStringIntMap(dynamic value) {
    if (value is! Map) return const <String, int>{};

    final result = <String, int>{};
    value.forEach((key, val) {
      result[key.toString()] = _toInt(val);
    });
    return result;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _toDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static String? _toNullableString(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }
}

class RestaurantMetricsRestaurant {
  final String id;
  final String? slug;
  final String? nameRu;
  final String? nameKk;
  final String? status;

  const RestaurantMetricsRestaurant({
    required this.id,
    required this.slug,
    required this.nameRu,
    required this.nameKk,
    required this.status,
  });

  factory RestaurantMetricsRestaurant.fromJson(Map<String, dynamic> json) {
    return RestaurantMetricsRestaurant(
      id: json['id']?.toString() ?? '',
      slug: RestaurantMetricsData._toNullableString(json['slug']),
      nameRu: RestaurantMetricsData._toNullableString(json['nameRu']),
      nameKk: RestaurantMetricsData._toNullableString(json['nameKk']),
      status: RestaurantMetricsData._toNullableString(json['status']),
    );
  }
}

class RestaurantMetricsPeriod {
  final String? from;
  final String? to;
  final int days;

  const RestaurantMetricsPeriod({
    required this.from,
    required this.to,
    required this.days,
  });

  factory RestaurantMetricsPeriod.fromJson(Map<String, dynamic> json) {
    return RestaurantMetricsPeriod(
      from: json['from']?.toString(),
      to: json['to']?.toString(),
      days: RestaurantMetricsData._toInt(json['days']),
    );
  }
}

class RestaurantMetricsOverview {
  final int totalOrders;
  final int deliveredCount;
  final int canceledCount;
  final int paidCount;
  final int totalRevenue;
  final int avgCheckRevenue;
  final int totalPaid;
  final int totalDelivered;
  final int cancelRatePercent;
  final int paidRatePercent;
  final int deliveredRatePercent;

  const RestaurantMetricsOverview({
    required this.totalOrders,
    required this.deliveredCount,
    required this.canceledCount,
    required this.paidCount,
    required this.totalRevenue,
    required this.avgCheckRevenue,
    required this.totalPaid,
    required this.totalDelivered,
    required this.cancelRatePercent,
    required this.paidRatePercent,
    required this.deliveredRatePercent,
  });

  factory RestaurantMetricsOverview.fromJson(Map<String, dynamic> json) {
    return RestaurantMetricsOverview(
      totalOrders: RestaurantMetricsData._toInt(json['totalOrders']),
      deliveredCount: RestaurantMetricsData._toInt(json['deliveredCount']),
      canceledCount: RestaurantMetricsData._toInt(json['canceledCount']),
      paidCount: RestaurantMetricsData._toInt(json['paidCount']),
      totalRevenue: RestaurantMetricsData._toInt(json['totalRevenue']),
      avgCheckRevenue: RestaurantMetricsData._toInt(json['avgCheckRevenue']),
      totalPaid: RestaurantMetricsData._toInt(json['totalPaid']),
      totalDelivered: RestaurantMetricsData._toInt(json['totalDelivered']),
      cancelRatePercent: RestaurantMetricsData._toInt(
        json['cancelRatePercent'],
      ),
      paidRatePercent: RestaurantMetricsData._toInt(json['paidRatePercent']),
      deliveredRatePercent: RestaurantMetricsData._toInt(
        json['deliveredRatePercent'],
      ),
    );
  }
}

class RestaurantDailyMetric {
  final String date;
  final int orders;
  final int delivered;
  final int canceled;
  final int paid;
  final int revenue;

  const RestaurantDailyMetric({
    required this.date,
    required this.orders,
    required this.delivered,
    required this.canceled,
    required this.paid,
    required this.revenue,
  });

  factory RestaurantDailyMetric.fromJson(Map<String, dynamic> json) {
    return RestaurantDailyMetric(
      date: json['date']?.toString() ?? '',
      orders: RestaurantMetricsData._toInt(json['orders']),
      delivered: RestaurantMetricsData._toInt(json['delivered']),
      canceled: RestaurantMetricsData._toInt(json['canceled']),
      paid: RestaurantMetricsData._toInt(json['paid']),
      revenue: RestaurantMetricsData._toInt(json['revenue']),
    );
  }

  DateTime? get parsedDate => RestaurantMetricsData._toDate(date);
}

class RestaurantCustomerStats {
  final int activeCustomers;
  final int activeCustomersLast7;
  final int activeCustomersLast30;
  final int newCustomers;
  final int repeatRatePercent;

  const RestaurantCustomerStats({
    required this.activeCustomers,
    required this.activeCustomersLast7,
    required this.activeCustomersLast30,
    required this.newCustomers,
    required this.repeatRatePercent,
  });

  factory RestaurantCustomerStats.fromJson(Map<String, dynamic> json) {
    return RestaurantCustomerStats(
      activeCustomers: RestaurantMetricsData._toInt(json['activeCustomers']),
      activeCustomersLast7: RestaurantMetricsData._toInt(
        json['activeCustomersLast7'] ?? json['activeCustomers7d'],
      ),
      activeCustomersLast30: RestaurantMetricsData._toInt(
        json['activeCustomersLast30'] ?? json['activeCustomers30d'],
      ),
      newCustomers: RestaurantMetricsData._toInt(json['newCustomers']),
      repeatRatePercent: RestaurantMetricsData._toInt(
        json['repeatRatePercent'] ?? json['repeatCustomers'],
      ),
    );
  }
}

class RestaurantReviewStats {
  final int reviewsCount;
  final double averageRating;
  final int reviewRatePercent;

  const RestaurantReviewStats({
    required this.reviewsCount,
    required this.averageRating,
    required this.reviewRatePercent,
  });

  factory RestaurantReviewStats.fromJson(Map<String, dynamic> json) {
    return RestaurantReviewStats(
      reviewsCount: RestaurantMetricsData._toInt(json['reviewsCount']),
      averageRating: RestaurantMetricsData._toDouble(
        json['averageRating'] ?? json['ratingAvg'],
      ),
      reviewRatePercent: RestaurantMetricsData._toInt(
        json['reviewRatePercent'],
      ),
    );
  }
}

class RestaurantTrendStats {
  final double? trendRevenuePercent;
  final double? trendOrdersPercent;

  const RestaurantTrendStats({
    required this.trendRevenuePercent,
    required this.trendOrdersPercent,
  });

  factory RestaurantTrendStats.fromJson(Map<String, dynamic> json) {
    return RestaurantTrendStats(
      trendRevenuePercent: json['trendRevenuePercent'] == null
          ? null
          : RestaurantMetricsData._toDouble(json['trendRevenuePercent']),
      trendOrdersPercent: json['trendOrdersPercent'] == null
          ? null
          : RestaurantMetricsData._toDouble(json['trendOrdersPercent']),
    );
  }
}

class RestaurantRecentOrderMetric {
  final String id;
  final String? phone;
  final String? customerName;
  final String? status;
  final String? paymentStatus;
  final String? paymentMethod;
  final String? userId;
  final int total;
  final int payout;
  final DateTime? createdAt;
  final DateTime? deliveredAt;

  const RestaurantRecentOrderMetric({
    required this.id,
    required this.phone,
    required this.customerName,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.userId,
    required this.total,
    required this.payout,
    required this.createdAt,
    required this.deliveredAt,
  });

  factory RestaurantRecentOrderMetric.fromJson(Map<String, dynamic> json) {
    return RestaurantRecentOrderMetric(
      id: json['id']?.toString() ?? '',
      phone: RestaurantMetricsData._toNullableString(
        json['phone'] ?? json['userPhone'],
      ),
      customerName: RestaurantMetricsData._toNullableString(
        json['customerName'] ?? json['userName'],
      ),
      status: RestaurantMetricsData._toNullableString(json['status']),
      paymentStatus: RestaurantMetricsData._toNullableString(
        json['paymentStatus'],
      ),
      paymentMethod: RestaurantMetricsData._toNullableString(
        json['paymentMethod'],
      ),
      userId: RestaurantMetricsData._toNullableString(json['userId']),
      total: RestaurantMetricsData._toInt(json['total']),
      payout: RestaurantMetricsData._toInt(
        json['payout'] ?? json['restaurantPayoutAmount'],
      ),
      createdAt: RestaurantMetricsData._toDate(json['createdAt']),
      deliveredAt: RestaurantMetricsData._toDate(json['deliveredAt']),
    );
  }
}

class RestaurantTopClientMetric {
  final String userId;
  final String? phone;
  final String? name;
  final int ordersCount;
  final int spent;
  final DateTime? lastOrderAt;
  final int? recencyDays;
  final String status;

  const RestaurantTopClientMetric({
    required this.userId,
    required this.phone,
    required this.name,
    required this.ordersCount,
    required this.spent,
    required this.lastOrderAt,
    required this.recencyDays,
    required this.status,
  });

  factory RestaurantTopClientMetric.fromJson(Map<String, dynamic> json) {
    return RestaurantTopClientMetric(
      userId: json['userId']?.toString() ?? '',
      phone: json['phone']?.toString(),
      name: json['name']?.toString(),
      ordersCount: RestaurantMetricsData._toInt(json['ordersCount']),
      spent: RestaurantMetricsData._toInt(json['spent']),
      lastOrderAt: RestaurantMetricsData._toDate(json['lastOrderAt']),
      recencyDays: json['recencyDays'] == null
          ? null
          : RestaurantMetricsData._toInt(json['recencyDays']),
      status: json['status']?.toString() ?? 'Неизвестно',
    );
  }
}

class RestaurantSuggestion {
  final String type;
  final String title;
  final String text;

  const RestaurantSuggestion({
    required this.type,
    required this.title,
    required this.text,
  });

  bool get isWarning => type == 'warning';
  bool get isInfo => type == 'info';
  bool get isSuccess => type == 'success';

  factory RestaurantSuggestion.fromJson(Map<String, dynamic> json) {
    return RestaurantSuggestion(
      type: json['type']?.toString() ?? 'info',
      title: json['title']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
    );
  }
}
``

## FILE: lib\features\restaurant\domain\restaurant_profile_data.dart

- Size: 6523 bytes

``dart
class RestaurantProfileData {
  final String id;
  final String nameRu;
  final String? nameKk;
  final String? phone;
  final String? address;

  // New backend fields
  final String? workingHours;
  final String? coverImageUrl;
  final String? status;
  final bool? isInApp;
  final bool? isPinned;
  final int? sortOrder;
  final num? effectiveRestaurantCommissionPct;

  // Legacy compatibility fields
  final String? imageUrl;
  final String? localImagePath;
  final List<String>? workDays;
  final String? workingHoursFrom;
  final String? workingHoursTo;
  final int? imageVersion;

  const RestaurantProfileData({
    required this.id,
    required this.nameRu,
    this.nameKk,
    this.phone,
    this.address,
    this.workingHours,
    this.coverImageUrl,
    this.status,
    this.isInApp,
    this.isPinned,
    this.sortOrder,
    this.effectiveRestaurantCommissionPct,
    this.imageUrl,
    this.localImagePath,
    this.workDays,
    this.workingHoursFrom,
    this.workingHoursTo,
    this.imageVersion,
  });

  factory RestaurantProfileData.fromJson(Map<String, dynamic> json) {
    return RestaurantProfileData(
      id: json['id']?.toString() ?? '',
      nameRu: json['nameRu']?.toString() ?? '',
      nameKk: json['nameKk']?.toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),

      // New backend contract
      workingHours: json['workingHours']?.toString(),
      coverImageUrl: json['coverImageUrl']?.toString(),
      status: json['status']?.toString(),
      isInApp: json['isInApp'] as bool?,
      isPinned: json['isPinned'] as bool?,
      sortOrder: json['sortOrder'] is int
          ? json['sortOrder'] as int
          : int.tryParse(json['sortOrder']?.toString() ?? ''),
      effectiveRestaurantCommissionPct:
          json['effectiveRestaurantCommissionPct'] as num?,

      // Legacy compatibility
      imageUrl: json['imageUrl']?.toString(),
      localImagePath: json['localImagePath']?.toString(),
      workDays: (json['workDays'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      workingHoursFrom: json['workingHoursFrom']?.toString(),
      workingHoursTo: json['workingHoursTo']?.toString(),
      imageVersion: json['imageVersion'] is int
          ? json['imageVersion'] as int
          : int.tryParse(json['imageVersion']?.toString() ?? ''),
    );
  }

  String get displayName {
    if (nameRu.trim().isNotEmpty) return nameRu.trim();
    if ((nameKk ?? '').trim().isNotEmpty) return nameKk!.trim();
    return 'Без названия';
  }

  String get displayAddress {
    final value = (address ?? '').trim();
    return value.isNotEmpty ? value : 'Адрес не указан';
  }

  String get displayPhone {
    final value = (phone ?? '').trim();
    return value.isNotEmpty ? value : 'Телефон не указан';
  }

  String get displayWorkingHours {
    final newValue = (workingHours ?? '').trim();
    if (newValue.isNotEmpty) return newValue;

    final from = (workingHoursFrom ?? '').trim();
    final to = (workingHoursTo ?? '').trim();
    if (from.isNotEmpty && to.isNotEmpty) {
      return '$from - $to';
    }

    return 'Время не указано';
  }

  String get displayStatus {
    final raw = (status ?? '').trim().toUpperCase();
    switch (raw) {
      case 'OPEN':
        return 'Открыт';
      case 'CLOSED':
        return 'Закрыт';
      default:
        return raw.isNotEmpty ? raw : 'Не указан';
    }
  }

  String? get resolvedRemoteImageUrl {
    final newUrl = (coverImageUrl ?? '').trim();
    if (newUrl.isNotEmpty) return newUrl;

    final legacyUrl = (imageUrl ?? '').trim();
    if (legacyUrl.isNotEmpty) return legacyUrl;

    return null;
  }

  String? get resolvedLocalImagePath {
    final value = (localImagePath ?? '').trim();
    return value.isNotEmpty ? value : null;
  }

  bool get hasAnyImage =>
      resolvedRemoteImageUrl != null || resolvedLocalImagePath != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nameRu': nameRu,
      'nameKk': nameKk,
      'phone': phone,
      'address': address,
      'workingHours': workingHours,
      'coverImageUrl': coverImageUrl,
      'status': status,
      'isInApp': isInApp,
      'isPinned': isPinned,
      'sortOrder': sortOrder,
      'effectiveRestaurantCommissionPct': effectiveRestaurantCommissionPct,
      'imageUrl': imageUrl,
      'localImagePath': localImagePath,
      'workDays': workDays,
      'workingHoursFrom': workingHoursFrom,
      'workingHoursTo': workingHoursTo,
      'imageVersion': imageVersion,
    };
  }

  RestaurantProfileData copyWith({
    String? id,
    String? nameRu,
    String? nameKk,
    String? phone,
    String? address,
    String? workingHours,
    String? coverImageUrl,
    String? status,
    bool? isInApp,
    bool? isPinned,
    int? sortOrder,
    num? effectiveRestaurantCommissionPct,
    String? imageUrl,
    String? localImagePath,
    List<String>? workDays,
    String? workingHoursFrom,
    String? workingHoursTo,
    int? imageVersion,
    bool clearCoverImageUrl = false,
    bool clearImageUrl = false,
    bool clearLocalImagePath = false,
  }) {
    return RestaurantProfileData(
      id: id ?? this.id,
      nameRu: nameRu ?? this.nameRu,
      nameKk: nameKk ?? this.nameKk,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      workingHours: workingHours ?? this.workingHours,
      coverImageUrl: clearCoverImageUrl
          ? null
          : (coverImageUrl ?? this.coverImageUrl),
      status: status ?? this.status,
      isInApp: isInApp ?? this.isInApp,
      isPinned: isPinned ?? this.isPinned,
      sortOrder: sortOrder ?? this.sortOrder,
      effectiveRestaurantCommissionPct:
          effectiveRestaurantCommissionPct ??
              this.effectiveRestaurantCommissionPct,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      localImagePath: clearLocalImagePath
          ? null
          : (localImagePath ?? this.localImagePath),
      workDays: workDays ?? this.workDays,
      workingHoursFrom: workingHoursFrom ?? this.workingHoursFrom,
      workingHoursTo: workingHoursTo ?? this.workingHoursTo,
      imageVersion: imageVersion ?? this.imageVersion,
    );
  }
}
``

## FILE: lib\features\restaurant_profile\domain\restaurant_profile_data.dart

- Size: 1841 bytes

``dart
class RestaurantProfileData {
  final String id;
  final String nameRu;
  final String? nameKk;
  final String? phone;
  final String? address;
  final String? workingHours;
  final String? coverImageUrl;
  final String? status;
  final bool? isInApp;
  final bool? isPinned;
  final int? sortOrder;
  final num? effectiveRestaurantCommissionPct;

  const RestaurantProfileData({
    required this.id,
    required this.nameRu,
    this.nameKk,
    this.phone,
    this.address,
    this.workingHours,
    this.coverImageUrl,
    this.status,
    this.isInApp,
    this.isPinned,
    this.sortOrder,
    this.effectiveRestaurantCommissionPct,
  });

  factory RestaurantProfileData.fromJson(Map<String, dynamic> json) {
    return RestaurantProfileData(
      id: json['id']?.toString() ?? '',
      nameRu: json['nameRu']?.toString() ?? '',
      nameKk: json['nameKk']?.toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      workingHours: json['workingHours']?.toString(),
      coverImageUrl: json['coverImageUrl']?.toString(),
      status: json['status']?.toString(),
      isInApp: json['isInApp'] as bool?,
      isPinned: json['isPinned'] as bool?,
      sortOrder: json['sortOrder'] as int?,
      effectiveRestaurantCommissionPct: json['effectiveRestaurantCommissionPct'] as num?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nameRu': nameRu,
      'nameKk': nameKk,
      'phone': phone,
      'address': address,
      'workingHours': workingHours,
      'coverImageUrl': coverImageUrl,
      'status': status,
      'isInApp': isInApp,
      'isPinned': isPinned,
      'sortOrder': sortOrder,
      'effectiveRestaurantCommissionPct': effectiveRestaurantCommissionPct,
    };
  }
}
``

## FILE: lib\features\restaurant_profile\presentation\pages\restaurant_profile_page.dart

- Size: 43519 bytes

``dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jetkiz_restaurant/core/config/app_config.dart';
import 'package:jetkiz_restaurant/core/navigation/app_page_route.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_storage.dart';
import 'package:jetkiz_restaurant/features/auth/presentation/pages/restaurant_auth_page.dart';
import 'package:jetkiz_restaurant/features/restaurant/data/restaurant_api.dart';
import 'package:jetkiz_restaurant/features/restaurant/domain/restaurant_profile_data.dart';
import 'package:jetkiz_restaurant/features/restaurant_profile/widgets/restaurant_statistics_tab.dart';

// JETKIZ RESTAURANT APP
// Restaurant profile page.
//
// BACKEND:
// - GET /restaurants/me
// - PATCH /restaurants/me
// - POST /restaurants/:id/cover
//
// IMPORTANT:
// Backend upload currently accepts only:
// jpg / jpeg / png / webp
//
// Because gallery/camera may return HEIC/HEIF on some devices,
// selected image is converted to JPG before upload.

class RestaurantProfilePage extends StatefulWidget {
  const RestaurantProfilePage({
    super.key,
    this.hideBottomBar = false,
  });

  final bool hideBottomBar;

  @override
  State<RestaurantProfilePage> createState() => _RestaurantProfilePageState();
}

class _RestaurantProfilePageState extends State<RestaurantProfilePage> {
  late final RestaurantApi _restaurantApi;
  final ImagePicker _imagePicker = ImagePicker();

  Future<RestaurantProfileData>? _profileFuture;

  _RestaurantProfileTab _activeTab = _RestaurantProfileTab.profile;

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _workingHoursController = TextEditingController();

  String? _lastProfileSyncKey;
  File? _localPhotoPreview;
  int _photoCacheBuster = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _restaurantApi = RestaurantApi(ApiClient());
    _profileFuture = _restaurantApi.getMyRestaurant();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _workingHoursController.dispose();
    super.dispose();
  }

  Future<void> _reloadProfile() async {
    setState(() {
      _profileFuture = _restaurantApi.getMyRestaurant();
    });
    await _profileFuture;
  }

  void _syncControllersFromProfile(RestaurantProfileData profile) {
    final syncKey = [
      profile.id,
      profile.phone ?? '',
      profile.address ?? '',
      profile.workingHours ?? '',
      profile.workingHoursFrom ?? '',
      profile.workingHoursTo ?? '',
    ].join('|');

    if (_lastProfileSyncKey == syncKey) {
      return;
    }

    _phoneController.text = profile.phone?.trim() ?? '';
    _addressController.text = profile.address?.trim() ?? '';

    if (profile.workingHours?.trim().isNotEmpty == true) {
      _workingHoursController.text = profile.workingHours!.trim();
    } else if (profile.workingHoursFrom?.trim().isNotEmpty == true &&
        profile.workingHoursTo?.trim().isNotEmpty == true) {
      _workingHoursController.text =
          '${profile.workingHoursFrom!.trim()} - ${profile.workingHoursTo!.trim()}';
    } else {
      _workingHoursController.text = '';
    }

    _lastProfileSyncKey = syncKey;
  }

  void _startEditing(RestaurantProfileData profile) {
    _syncControllersFromProfile(profile);
    setState(() {
      _isEditing = true;
    });
  }

  void _cancelEditing(RestaurantProfileData profile) {
    _syncControllersFromProfile(profile);
    setState(() {
      _isEditing = false;
    });
  }

  Future<void> _saveProfile(RestaurantProfileData profile) async {
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();
    final workingHours = _workingHoursController.text.trim();

    if (address.isEmpty) {
      _showSnackBar('Введите адрес');
      return;
    }

    if (phone.isEmpty) {
      _showSnackBar('Введите телефон');
      return;
    }

    if (workingHours.isEmpty) {
      _showSnackBar('Введите время работы');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedProfile = await _restaurantApi.updateMe(
        address: address,
        phone: phone,
        workingHours: workingHours,
      );

      _syncControllersFromProfile(updatedProfile);

      if (!mounted) return;

      setState(() {
        _isEditing = false;
        _profileFuture = Future.value(updatedProfile);
      });

      await _reloadProfile();

      if (!mounted) return;
      _showSnackBar('Профиль сохранён');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<File> _prepareUploadFile(File originalFile) async {
    final lowerPath = originalFile.path.toLowerCase();

    final alreadySupported =
        lowerPath.endsWith('.jpg') ||
        lowerPath.endsWith('.jpeg') ||
        lowerPath.endsWith('.png') ||
        lowerPath.endsWith('.webp');

    if (alreadySupported) {
      return originalFile;
    }

    final targetPath = '${originalFile.path}_upload.jpg';

    final compressed = await FlutterImageCompress.compressAndGetFile(
      originalFile.absolute.path,
      targetPath,
      format: CompressFormat.jpeg,
      quality: 90,
    );

    if (compressed == null) {
      throw Exception('Не удалось подготовить фото к загрузке');
    }

    return File(compressed.path);
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_isUploadingPhoto) return;

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (pickedFile == null) {
        return;
      }

      final originalFile = File(pickedFile.path);
      final uploadFile = await _prepareUploadFile(originalFile);

      if (!mounted) return;

      setState(() {
        _localPhotoPreview = uploadFile;
        _isUploadingPhoto = true;
      });

      final updatedProfile = await _restaurantApi.uploadRestaurantCover(
        uploadFile,
      );

      if (!mounted) return;

      setState(() {
        _profileFuture = Future.value(updatedProfile);
        _localPhotoPreview = null;
        _photoCacheBuster = DateTime.now().millisecondsSinceEpoch;
      });

      await _reloadProfile();

      if (!mounted) return;

      setState(() {
        _photoCacheBuster = DateTime.now().millisecondsSinceEpoch;
      });

      _showSnackBar('Фото обновлено');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _localPhotoPreview = null;
      });
      _showSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await AuthStorage().clearTokens();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      AppPageRoute<void>(
        page: const RestaurantAuthPage(),
      ),
      (route) => false,
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      appBar: widget.hideBottomBar
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF09111C),
              elevation: 0,
              centerTitle: true,
              title: const Text(
                'Мой ресторан',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      body: SafeArea(
        child: FutureBuilder<RestaurantProfileData>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ошибка загрузки профиля: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _reloadProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF489F2A),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final profile = snapshot.data;
            if (profile == null) {
              return const Center(
                child: Text(
                  'Профиль не найден',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            if (!_isEditing) {
              _syncControllersFromProfile(profile);
            }

            return Column(
              children: [
                _ProfileTopHeader(
                  activeTab: _activeTab,
                  isEditing: _isEditing,
                  isSaving: _isSaving,
                  onTabChanged: (tab) {
                    setState(() => _activeTab = tab);
                  },
                  onEditTap: () {
                    if (_isSaving || _isUploadingPhoto) return;

                    if (_isEditing) {
                      _cancelEditing(profile);
                    } else {
                      _startEditing(profile);
                    }
                  },
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _activeTab == _RestaurantProfileTab.profile
                        ? _ProfileTabView(
                            key: const ValueKey('profile_tab'),
                            profile: profile,
                            onReload: _reloadProfile,
                            isEditing: _isEditing,
                            isSaving: _isSaving,
                            isUploadingPhoto: _isUploadingPhoto,
                            localPhotoPreview: _localPhotoPreview,
                            photoCacheBuster: _photoCacheBuster,
                            phoneController: _phoneController,
                            addressController: _addressController,
                            workingHoursController: _workingHoursController,
                            onCancel: () => _cancelEditing(profile),
                            onSave: () => _saveProfile(profile),
                            onChangePhoto: _pickAndUploadPhoto,
                            onLogout: _logout,
                          )
                        : RestaurantStatisticsTab(
                            key: ValueKey('statistics_tab_${profile.id}'),
                            restaurantId: profile.id,
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _RestaurantProfileTab {
  profile,
  statistics,
}

class _ProfileTopHeader extends StatelessWidget {
  const _ProfileTopHeader({
    required this.activeTab,
    required this.onTabChanged,
    required this.onEditTap,
    required this.isEditing,
    required this.isSaving,
  });

  final _RestaurantProfileTab activeTab;
  final ValueChanged<_RestaurantProfileTab> onTabChanged;
  final VoidCallback onEditTap;
  final bool isEditing;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF489F2A),
            Color(0xFF3A7E21),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332E6A1A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Мой ресторан',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isSaving ? null : onEditTap,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            isEditing ? Icons.close_rounded : Icons.edit_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeaderTabButton(
                    text: 'Профиль',
                    isActive: activeTab == _RestaurantProfileTab.profile,
                    onTap: () => onTabChanged(_RestaurantProfileTab.profile),
                  ),
                ),
                Expanded(
                  child: _HeaderTabButton(
                    text: 'Статистика',
                    isActive: activeTab == _RestaurantProfileTab.statistics,
                    onTap: () => onTabChanged(_RestaurantProfileTab.statistics),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderTabButton extends StatelessWidget {
  const _HeaderTabButton({
    required this.text,
    required this.isActive,
    required this.onTap,
  });

  final String text;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: isActive
                ? const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: isActive ? const Color(0xFF489F2A) : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileTabView extends StatelessWidget {
  const _ProfileTabView({
    super.key,
    required this.profile,
    required this.onReload,
    required this.isEditing,
    required this.isSaving,
    required this.isUploadingPhoto,
    required this.localPhotoPreview,
    required this.photoCacheBuster,
    required this.phoneController,
    required this.addressController,
    required this.workingHoursController,
    required this.onCancel,
    required this.onSave,
    required this.onChangePhoto,
    required this.onLogout,
  });

  final RestaurantProfileData profile;
  final Future<void> Function() onReload;
  final bool isEditing;
  final bool isSaving;
  final bool isUploadingPhoto;
  final File? localPhotoPreview;
  final int photoCacheBuster;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController workingHoursController;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final VoidCallback onChangePhoto;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onReload,
      color: const Color(0xFF489F2A),
      backgroundColor: const Color(0xFF121B2C),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          _RestaurantPhotoCard(
            profile: profile,
            localPreviewFile: localPhotoPreview,
            isUploading: isUploadingPhoto,
            onChangePhoto: onChangePhoto,
            cacheBuster: photoCacheBuster,
          ),
          const SizedBox(height: 14),
          _InfoCard(
            icon: Icons.storefront_rounded,
            iconBg: const Color(0x33489F2A),
            iconColor: const Color(0xFF65C044),
            title: 'Название',
            value: _displayName(profile),
            helperText: isEditing
                ? 'Название пока читается только из backend и в этом экране не редактируется'
                : null,
          ),
          const SizedBox(height: 12),
          _EditableInfoCard(
            icon: Icons.location_on_outlined,
            iconBg: const Color(0x332A7BFF),
            iconColor: const Color(0xFF5EA3FF),
            title: 'Адрес',
            controller: addressController,
            value: _displayAddress(profile),
            hintText: 'Введите адрес',
            enabled: isEditing && !isSaving,
            multiLine: true,
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          _EditableInfoCard(
            icon: Icons.phone_outlined,
            iconBg: const Color(0x336C3DF4),
            iconColor: const Color(0xFFA27BFF),
            title: 'Телефон',
            controller: phoneController,
            value: _displayPhone(profile),
            hintText: 'Введите телефон',
            enabled: isEditing && !isSaving,
          ),
          const SizedBox(height: 12),
          _EditableInfoCard(
            icon: Icons.access_time_rounded,
            iconBg: const Color(0x33F08A24),
            iconColor: const Color(0xFFFFA247),
            title: 'Время работы',
            controller: workingHoursController,
            value: _displayWorkingHours(profile),
            hintText: 'Например: 09:00 - 22:00',
            enabled: isEditing && !isSaving,
          ),
          const SizedBox(height: 12),
          _StatusCard(status: profile.status),
          if (isEditing) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSaving ? null : onCancel,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF33445F)),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isSaving ? null : onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF489F2A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Сохранить',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onLogout,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Выйти из аккаунта',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _displayName(RestaurantProfileData profile) {
    if (profile.nameRu.trim().isNotEmpty) return profile.nameRu.trim();
    if (profile.nameKk?.trim().isNotEmpty == true) return profile.nameKk!.trim();
    return 'Без названия';
  }

  static String _displayAddress(RestaurantProfileData profile) {
    if (profile.address?.trim().isNotEmpty == true) return profile.address!.trim();
    return 'Адрес не указан';
  }

  static String _displayPhone(RestaurantProfileData profile) {
    if (profile.phone?.trim().isNotEmpty == true) return profile.phone!.trim();
    return 'Телефон не указан';
  }

  static String _displayWorkingHours(RestaurantProfileData profile) {
    if (profile.workingHours?.trim().isNotEmpty == true) {
      return profile.workingHours!.trim();
    }

    if (profile.workingHoursFrom?.trim().isNotEmpty == true &&
        profile.workingHoursTo?.trim().isNotEmpty == true) {
      return '${profile.workingHoursFrom!.trim()} - ${profile.workingHoursTo!.trim()}';
    }

    return 'Время не указано';
  }
}

class _RestaurantPhotoCard extends StatelessWidget {
  const _RestaurantPhotoCard({
    required this.profile,
    required this.localPreviewFile,
    required this.isUploading,
    required this.onChangePhoto,
    required this.cacheBuster,
  });

  final RestaurantProfileData profile;
  final File? localPreviewFile;
  final bool isUploading;
  final VoidCallback onChangePhoto;
  final int cacheBuster;

  @override
  Widget build(BuildContext context) {
    final remoteImageUrl = _resolveRemoteImage(profile);
    final hasRemoteImage = remoteImageUrl.isNotEmpty;
    final hasLocalPreview = localPreviewFile != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF172338),
            Color(0xFF0F1829),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF22324A),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            if (hasLocalPreview)
              Image.file(
                localPreviewFile!,
                height: 186,
                width: double.infinity,
                fit: BoxFit.cover,
              )
            else if (hasRemoteImage)
              Image.network(
                remoteImageUrl,
                height: 186,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) {
                  return const _PhotoPlaceholder();
                },
              )
            else
              const _PhotoPlaceholder(),
            Container(
              height: 186,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0x66000000),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: ElevatedButton.icon(
                onPressed: isUploading ? null : onChangePhoto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF489F2A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(
                  isUploading ? 'Загрузка...' : 'Изменить фото',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveRemoteImage(RestaurantProfileData profile) {
    final rawImagePath = (profile.coverImageUrl ?? '').trim();

    if (rawImagePath.isNotEmpty) {
      final imageUrl = rawImagePath.startsWith('http')
          ? rawImagePath
          : '${AppConfig.baseUrl}$rawImagePath';

      return '$imageUrl?t=$cacheBuster';
    }

    final legacy = profile.imageUrl?.trim() ?? '';
    if (legacy.isNotEmpty) {
      return '$legacy?t=$cacheBuster';
    }

    return '';
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 186,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B2A43),
            Color(0xFF0E1626),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.10),
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.image_not_supported_outlined,
              color: Color(0xFF7E8CA3),
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Фото ресторана не загружено',
            style: TextStyle(
              color: Color(0xFFA2AEC0),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF489F2A),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Добавить фото',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.value,
    this.multiLine = false,
    this.helperText,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String value;
  final bool multiLine;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF151F32),
            Color(0xFF0D1524),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF22324A),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: iconColor.withOpacity(0.28),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF7F8BA0),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: multiLine ? 14 : 15,
                    fontWeight: FontWeight.w700,
                    height: multiLine ? 1.35 : 1.2,
                  ),
                ),
                if (helperText?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    helperText!.trim(),
                    style: const TextStyle(
                      color: Color(0xFF93A0B4),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableInfoCard extends StatelessWidget {
  const _EditableInfoCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.controller,
    required this.value,
    required this.hintText,
    required this.enabled,
    this.multiLine = false,
    this.minLines,
    this.maxLines = 1,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final TextEditingController controller;
  final String value;
  final String hintText;
  final bool enabled;
  final bool multiLine;
  final int? minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final isEditMode = enabled;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF151F32),
            Color(0xFF0D1524),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF22324A),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: iconColor.withOpacity(0.28),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF7F8BA0),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                if (isEditMode)
                  TextField(
                    controller: controller,
                    enabled: enabled,
                    minLines: minLines,
                    maxLines: maxLines,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: const TextStyle(
                        color: Color(0xFF6F7C91),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0E1626),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF2A3A52),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF489F2A),
                          width: 1.4,
                        ),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF2A3A52),
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: multiLine ? 14 : 15,
                      fontWeight: FontWeight.w700,
                      height: multiLine ? 1.35 : 1.2,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.status,
  });

  final String? status;

  @override
  Widget build(BuildContext context) {
    final isOpen = (status ?? '').trim().toUpperCase() == 'OPEN';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOpen
              ? [
                  const Color(0x1A489F2A),
                  const Color(0x143A7E21),
                ]
              : [
                  const Color(0x1AF04444),
                  const Color(0x14B72F2F),
                ],
        ),
        border: Border.all(
          color: isOpen
              ? const Color(0x55489F2A)
              : const Color(0x55E45252),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isOpen
                  ? const Color(0x33489F2A)
                  : const Color(0x33E45252),
              shape: BoxShape.circle,
              border: Border.all(
                color: isOpen
                    ? const Color(0x66489F2A)
                    : const Color(0x66E45252),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.radio_button_checked_rounded,
              color: isOpen
                  ? const Color(0xFF65C044)
                  : const Color(0xFFFF6E6E),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Статус ресторана',
              style: TextStyle(
                color: Color(0xFF7F8BA0),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: isOpen
                      ? const Color(0xFF65C044)
                      : const Color(0xFFFF6E6E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isOpen ? 'Открыт' : 'Закрыт',
                style: TextStyle(
                  color: isOpen
                      ? const Color(0xFF65C044)
                      : const Color(0xFFFF6E6E),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
``

## FILE: lib\features\restaurant_profile\widgets\restaurant_statistics_tab.dart

- Size: 49798 bytes

``dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jetkiz_restaurant/core/navigation/app_page_route.dart';
import 'package:jetkiz_restaurant/features/restaurant/data/restaurant_metrics_api.dart';
import 'package:jetkiz_restaurant/features/restaurant/domain/restaurant_metrics_data.dart';
import 'package:jetkiz_restaurant/features/reviews/presentation/pages/restaurant_reviews_page.dart';

class RestaurantStatisticsTab extends StatefulWidget {
  const RestaurantStatisticsTab({
    super.key,
    required this.restaurantId,
  });

  final String restaurantId;

  @override
  State<RestaurantStatisticsTab> createState() =>
      _RestaurantStatisticsTabState();
}

enum _StatisticsPeriodMode {
  day,
  week,
  month,
  year,
  custom,
}

class _RestaurantStatisticsTabState extends State<RestaurantStatisticsTab> {
  late final RestaurantMetricsApi _metricsApi;
  late Future<RestaurantMetricsData> _metricsFuture;

  _StatisticsPeriodMode _periodMode = _StatisticsPeriodMode.week;

  DateTime? _customFrom;
  DateTime? _customTo;

  @override
  void initState() {
    super.initState();
    _metricsApi = RestaurantMetricsApi();
    _metricsFuture = _loadMetrics();
  }

  Future<RestaurantMetricsData> _loadMetrics() {
    switch (_periodMode) {
      case _StatisticsPeriodMode.day:
        return _metricsApi.getMetrics(
          restaurantId: widget.restaurantId,
          days: 1,
        );
      case _StatisticsPeriodMode.week:
        return _metricsApi.getMetrics(
          restaurantId: widget.restaurantId,
          days: 7,
        );
      case _StatisticsPeriodMode.month:
        return _metricsApi.getMetrics(
          restaurantId: widget.restaurantId,
          days: 30,
        );
      case _StatisticsPeriodMode.year:
        return _metricsApi.getMetrics(
          restaurantId: widget.restaurantId,
          days: 365,
        );
      case _StatisticsPeriodMode.custom:
        if (_customFrom != null && _customTo != null) {
          return _metricsApi.getMetrics(
            restaurantId: widget.restaurantId,
            from: _ymd(_customFrom!),
            to: _ymd(_customTo!),
          );
        }

        return _metricsApi.getMetrics(
          restaurantId: widget.restaurantId,
          days: 7,
        );
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _metricsFuture = _loadMetrics();
    });
    await _metricsFuture;
  }

  void _setPeriodMode(_StatisticsPeriodMode mode) {
    if (_periodMode == mode) return;

    setState(() {
      _periodMode = mode;

      if (mode == _StatisticsPeriodMode.custom) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        _customTo ??= today;
        _customFrom ??= today.subtract(const Duration(days: 6));

        if (_customFrom!.isAfter(_customTo!)) {
          _customFrom = _customTo;
        }
      } else {
        _metricsFuture = _loadMetrics();
      }
    });
  }

  Future<void> _pickCustomFrom() async {
    final now = DateTime.now();
    final minDate = DateTime(now.year - 3, 1, 1);
    final maxDate = _customTo ?? DateTime(now.year + 1, 12, 31);

    DateTime initialDate = _customFrom ?? now.subtract(const Duration(days: 6));

    if (initialDate.isBefore(minDate)) {
      initialDate = minDate;
    }
    if (initialDate.isAfter(maxDate)) {
      initialDate = maxDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minDate,
      lastDate: maxDate,
      locale: const Locale('ru'),
      helpText: 'Дата начала',
      cancelText: 'Отмена',
      confirmText: 'Готово',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF489F2A),
              surface: Color(0xFF121B2C),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF09111C),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _customFrom = DateTime(picked.year, picked.month, picked.day);

      if (_customTo != null && _customTo!.isBefore(_customFrom!)) {
        _customTo = _customFrom;
      }
    });
  }

  Future<void> _pickCustomTo() async {
    final now = DateTime.now();
    final minDate = _customFrom ?? DateTime(now.year - 3, 1, 1);
    final maxDate = DateTime(now.year + 1, 12, 31);

    DateTime initialDate = _customTo ?? _customFrom ?? now;

    if (initialDate.isBefore(minDate)) {
      initialDate = minDate;
    }
    if (initialDate.isAfter(maxDate)) {
      initialDate = maxDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minDate,
      lastDate: maxDate,
      locale: const Locale('ru'),
      helpText: 'Дата конца',
      cancelText: 'Отмена',
      confirmText: 'Готово',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF489F2A),
              surface: Color(0xFF121B2C),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF09111C),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _customTo = DateTime(picked.year, picked.month, picked.day);

      if (_customFrom != null && _customFrom!.isAfter(_customTo!)) {
        _customFrom = _customTo;
      }
    });
  }

  void _applyCustomPeriod() {
    if (_customFrom == null || _customTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите даты начала и конца периода'),
        ),
      );
      return;
    }

    if (_customFrom!.isAfter(_customTo!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Дата начала не может быть позже даты конца'),
        ),
      );
      return;
    }

    setState(() {
      _metricsFuture = _loadMetrics();
    });
  }

  String _ymd(DateTime date) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  String _displayDate(DateTime? date) {
    if (date == null) return 'дд.мм.гггг';
    return DateFormat('dd.MM.yyyy').format(date);
  }

  String _buildSelectedPeriodLabel(RestaurantMetricsPeriod period) {
    if (_periodMode == _StatisticsPeriodMode.custom &&
        _customFrom != null &&
        _customTo != null) {
      return '${_displayDate(_customFrom)} — ${_displayDate(_customTo)}';
    }

    final from = DateTime.tryParse(period.from ?? '');
    final to = DateTime.tryParse(period.to ?? '');

    if (from != null && to != null) {
      return '${_displayDate(from)} — ${_displayDate(to)}';
    }

    switch (_periodMode) {
      case _StatisticsPeriodMode.day:
        return 'Сегодня';
      case _StatisticsPeriodMode.week:
        return 'Последние 7 дней';
      case _StatisticsPeriodMode.month:
        return 'Последние 30 дней';
      case _StatisticsPeriodMode.year:
        return 'Последние 365 дней';
      case _StatisticsPeriodMode.custom:
        return 'Выберите даты';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RestaurantMetricsData>(
      future: _metricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ошибка загрузки статистики: ${snapshot.error}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _refresh,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF489F2A),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          );
        }

        final metrics = snapshot.data;
        if (metrics == null) {
          return const Center(
            child: Text(
              'Статистика недоступна',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF489F2A),
          backgroundColor: const Color(0xFF121B2C),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              _StatisticsPeriodCard(
                mode: _periodMode,
                customFrom: _customFrom,
                customTo: _customTo,
                selectedPeriodLabel: _buildSelectedPeriodLabel(metrics.period),
                onModeSelected: _setPeriodMode,
                onPickFrom: _pickCustomFrom,
                onPickTo: _pickCustomTo,
                onApplyCustom: _applyCustomPeriod,
                displayDate: _displayDate,
              ),
              const SizedBox(height: 14),
              _ReviewsNavigationCard(
                reviewsCount: metrics.reviews.reviewsCount,
                averageRating: metrics.reviews.averageRating,
                onTap: () {
                  Navigator.of(context).push(
                    AppPageRoute<void>(
                      page: RestaurantReviewsPage(
                        restaurantId: widget.restaurantId,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 0.92,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _MetricTile(
                    icon: Icons.trending_up_rounded,
                    iconBg: const Color(0x3329D391),
                    iconColor: const Color(0xFF00E79A),
                    title: 'Выручка (итого)',
                    value: _currency(metrics.overview.totalRevenue),
                    subtitle:
                        'Средний чек ${_currency(metrics.overview.avgCheckRevenue)}',
                  ),
                  _MetricTile(
                    icon: Icons.receipt_long_rounded,
                    iconBg: const Color(0x332A7BFF),
                    iconColor: const Color(0xFF5EA3FF),
                    title: 'Заказы',
                    value: '${metrics.overview.totalOrders}',
                    subtitle:
                        'Выполнено: ${metrics.overview.deliveredCount}, Отменено: ${metrics.overview.canceledCount}',
                  ),
                  _MetricTile(
                    icon: Icons.account_balance_wallet_outlined,
                    iconBg: const Color(0x3300D0FF),
                    iconColor: const Color(0xFF00D9FF),
                    title: 'Оплаты',
                    value: '${metrics.overview.paidRatePercent}%',
                    subtitle: 'Оплачено: ${metrics.overview.paidCount}',
                  ),
                  _MetricTile(
                    icon: Icons.cancel_outlined,
                    iconBg: const Color(0x33FF5A6E),
                    iconColor: const Color(0xFFFF6B7C),
                    title: 'Отмены',
                    value: '${metrics.overview.cancelRatePercent}%',
                    subtitle: 'Отменено: ${metrics.overview.canceledCount}',
                  ),
                  _MetricTile(
                    icon: Icons.people_outline_rounded,
                    iconBg: const Color(0x334E3BFF),
                    iconColor: const Color(0xFF9A8BFF),
                    title: 'Клиенты',
                    value: '${metrics.customers.activeCustomers}',
                    subtitle:
                        'Новые: ${metrics.customers.newCustomers}, Повторные: ${metrics.customers.repeatRatePercent}%',
                  ),
                  _MetricTile(
                    icon: Icons.calendar_today_outlined,
                    iconBg: const Color(0x334F5D75),
                    iconColor: const Color(0xFFD0D7E2),
                    title: 'Активные 7 дней',
                    value: '${metrics.customers.activeCustomersLast7}',
                    subtitle: 'активных',
                  ),
                  _MetricTile(
                    icon: Icons.event_note_outlined,
                    iconBg: const Color(0x334F5D75),
                    iconColor: const Color(0xFFD0D7E2),
                    title: 'Активные 30 дней',
                    value: '${metrics.customers.activeCustomersLast30}',
                    subtitle: 'активных',
                  ),
                  _MetricTile(
                    icon: Icons.star_border_rounded,
                    iconBg: const Color(0x33FF9800),
                    iconColor: const Color(0xFFFFB24A),
                    title: 'Рейтинг',
                    value: metrics.reviews.averageRating > 0
                        ? metrics.reviews.averageRating.toStringAsFixed(1)
                        : '0.0',
                    subtitle:
                        'Отзывы: ${metrics.reviews.reviewsCount}, rate ${metrics.reviews.reviewRatePercent}%',
                  ),
                  _MetricTile(
                    icon: Icons.verified_outlined,
                    iconBg: const Color(0x3329D391),
                    iconColor: const Color(0xFF00E79A),
                    title: 'Доставлено',
                    value: '${metrics.overview.deliveredRatePercent}%',
                    subtitle:
                        '${metrics.overview.deliveredCount} из ${metrics.overview.totalOrders}',
                  ),
                  _MetricTile(
                    icon: Icons.payments_outlined,
                    iconBg: const Color(0x333CCB7F),
                    iconColor: const Color(0xFF5CF2A0),
                    title: 'Payout',
                    value: _currency(metrics.overview.totalDelivered),
                    subtitle:
                        'Оплачено ${_currency(metrics.overview.totalPaid)}',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _LineChartCard(
                title: 'Выручка по дням',
                subtitle: 'Динамика дохода за выбранный период',
                items: metrics.daily,
                mode: _ChartMode.revenue,
              ),
              const SizedBox(height: 12),
              _LineChartCard(
                title: 'Заказы по дням',
                subtitle: 'Количество заказов за выбранный период',
                items: metrics.daily,
                mode: _ChartMode.orders,
              ),
              if (metrics.trends.trendRevenuePercent != null ||
                  metrics.trends.trendOrdersPercent != null) ...[
                const SizedBox(height: 12),
                _TrendCard(trends: metrics.trends),
              ],
              if (metrics.suggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SuggestionsCard(suggestions: metrics.suggestions),
              ],
              if (metrics.topClients.isNotEmpty) ...[
                const SizedBox(height: 12),
                _TopClientsCard(clients: metrics.topClients),
              ],
              if (metrics.recentOrders.isNotEmpty) ...[
                const SizedBox(height: 12),
                _RecentOrdersCard(orders: metrics.recentOrders),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _currency(int value) {
    return '$value ₸';
  }
}

class _ReviewsNavigationCard extends StatelessWidget {
  const _ReviewsNavigationCard({
    required this.reviewsCount,
    required this.averageRating,
    required this.onTap,
  });

  final int reviewsCount;
  final double averageRating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratingText =
        averageRating > 0 ? averageRating.toStringAsFixed(1) : '0.0';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF121B2C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF22314A)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0x33489F2A),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.rate_review_rounded,
                  color: Color(0xFF65C044),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Отзывы',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$reviewsCount отзывов • рейтинг $ratingText',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white54,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatisticsPeriodCard extends StatelessWidget {
  const _StatisticsPeriodCard({
    required this.mode,
    required this.customFrom,
    required this.customTo,
    required this.selectedPeriodLabel,
    required this.onModeSelected,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onApplyCustom,
    required this.displayDate,
  });

  final _StatisticsPeriodMode mode;
  final DateTime? customFrom;
  final DateTime? customTo;
  final String selectedPeriodLabel;
  final ValueChanged<_StatisticsPeriodMode> onModeSelected;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onApplyCustom;
  final String Function(DateTime?) displayDate;

  @override
  Widget build(BuildContext context) {
    final isCustom = mode == _StatisticsPeriodMode.custom;
    final canApply = customFrom != null && customTo != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22314A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                color: Color(0xFF65C044),
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Период',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PeriodChip(
                label: 'День',
                selected: mode == _StatisticsPeriodMode.day,
                onTap: () => onModeSelected(_StatisticsPeriodMode.day),
              ),
              _PeriodChip(
                label: 'Неделя',
                selected: mode == _StatisticsPeriodMode.week,
                onTap: () => onModeSelected(_StatisticsPeriodMode.week),
              ),
              _PeriodChip(
                label: 'Месяц',
                selected: mode == _StatisticsPeriodMode.month,
                onTap: () => onModeSelected(_StatisticsPeriodMode.month),
              ),
              _PeriodChip(
                label: 'Год',
                selected: mode == _StatisticsPeriodMode.year,
                onTap: () => onModeSelected(_StatisticsPeriodMode.year),
              ),
              _PeriodChip(
                label: 'Период',
                selected: mode == _StatisticsPeriodMode.custom,
                onTap: () => onModeSelected(_StatisticsPeriodMode.custom),
              ),
            ],
          ),
          if (isCustom) ...[
            const SizedBox(height: 14),
            const Divider(
              height: 1,
              color: Color(0xFF25344B),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'С',
                    value: displayDate(customFrom),
                    onTap: onPickFrom,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'До',
                    value: displayDate(customTo),
                    onTap: onPickTo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canApply ? onApplyCustom : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D3A52),
                  disabledBackgroundColor: const Color(0xFF2A3346),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white38,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Применить период',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Выбранный период:',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  selectedPeriodLabel,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF65C044),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = value == 'дд.мм.гггг';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1626),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2A3A52),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        color: isPlaceholder
                            ? const Color(0xFF6F7C91)
                            : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: Colors.white54,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF489F2A) : const Color(0xFF1A2437),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFF65C044)
                  : const Color(0xFF233149),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(selected ? 1 : 0.82),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22314A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: iconColor,
              size: 18,
            ),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              height: 1.0,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChartMode {
  revenue,
  orders,
}

class _LineChartCard extends StatelessWidget {
  const _LineChartCard({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.mode,
  });

  final String title;
  final String subtitle;
  final List<RestaurantDailyMetric> items;
  final _ChartMode mode;

  @override
  Widget build(BuildContext context) {
    final values = items
        .map(
          (e) => mode == _ChartMode.revenue
              ? e.revenue.toDouble()
              : e.orders.toDouble(),
        )
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22314A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                mode == _ChartMode.revenue
                    ? Icons.insert_chart_outlined_rounded
                    : Icons.show_chart_rounded,
                color: Colors.white38,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 132,
            child: _MiniLineChart(
              values: values,
              lineColor: mode == _ChartMode.revenue
                  ? const Color(0xFF00E79A)
                  : const Color(0xFF5EA3FF),
            ),
          ),
          const SizedBox(height: 10),
          if (items.isNotEmpty)
            Row(
              children: [
                Text(
                  _labelFor(items.first.date),
                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                ),
                const Spacer(),
                Text(
                  _labelFor(items[items.length ~/ 2].date),
                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                ),
                const Spacer(),
                Text(
                  _labelFor(items.last.date),
                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String _labelFor(String raw) {
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    return DateFormat('MM-dd').format(date);
  }
}

class _MiniLineChart extends StatelessWidget {
  const _MiniLineChart({
    required this.values,
    required this.lineColor,
  });

  final List<double> values;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MiniLineChartPainter(
        values: values,
        lineColor: lineColor,
        gridColor: const Color(0x223E4B62),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _MiniLineChartPainter extends CustomPainter {
  _MiniLineChartPainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.isEmpty) return;

    final safeValues = values.map((e) => e.isFinite ? e : 0.0).toList();

    final maxValue = math.max<double>(
      1.0,
      safeValues.fold<double>(
        0.0,
        (prev, e) => math.max<double>(prev, e),
      ),
    );

    final dx = safeValues.length == 1
        ? 0.0
        : size.width / (safeValues.length - 1);

    final path = Path();
    final points = <Offset>[];

    for (var i = 0; i < safeValues.length; i++) {
      final x = dx * i;
      final ratio = safeValues[i] / maxValue;
      final y = size.height - (ratio * (size.height - 8)) - 4;
      final point = Offset(x, y);
      points.add(point);

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          lineColor.withOpacity(0.28),
          lineColor.withOpacity(0.02),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    final pointPaint = Paint()..color = lineColor;
    final pointFillPaint = Paint()..color = const Color(0xFF121B2C);

    for (final point in points) {
      canvas.drawCircle(point, 4.5, pointPaint);
      canvas.drawCircle(point, 2.4, pointFillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniLineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.trends,
  });

  final RestaurantTrendStats trends;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22314A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Тренды',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _TrendRow(
            label: 'Выручка vs предыдущий период',
            value: trends.trendRevenuePercent,
          ),
          const SizedBox(height: 10),
          _TrendRow(
            label: 'Заказы vs предыдущий период',
            value: trends.trendOrdersPercent,
          ),
        ],
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({
    required this.label,
    required this.value,
  });

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final positive = (value ?? 0) >= 0;
    final display = value == null
        ? '—'
        : '${positive ? '+' : ''}${value!.toStringAsFixed(1)}%';

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: value == null
                ? const Color(0x33233149)
                : positive
                    ? const Color(0x3329D391)
                    : const Color(0x33FF5A6E),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            display,
            style: TextStyle(
              color: value == null
                  ? Colors.white54
                  : positive
                      ? const Color(0xFF00E79A)
                      : const Color(0xFFFF7C7C),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SuggestionsCard extends StatelessWidget {
  const _SuggestionsCard({
    required this.suggestions,
  });

  final List<RestaurantSuggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22314A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Рекомендации',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...suggestions.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      _iconForSuggestion(item),
                      color: _colorForSuggestion(item),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.title.trim().isNotEmpty)
                          Text(
                            item.title,
                            style: TextStyle(
                              color: _colorForSuggestion(item),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (item.title.trim().isNotEmpty)
                          const SizedBox(height: 4),
                        Text(
                          item.text,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconForSuggestion(RestaurantSuggestion item) {
    if (item.isWarning) return Icons.warning_amber_rounded;
    if (item.isSuccess) return Icons.check_circle_outline_rounded;
    return Icons.auto_awesome_outlined;
  }

  static Color _colorForSuggestion(RestaurantSuggestion item) {
    if (item.isWarning) return const Color(0xFFFFB24A);
    if (item.isSuccess) return const Color(0xFF65C044);
    return const Color(0xFF7BC6FF);
  }
}

class _TopClientsCard extends StatelessWidget {
  const _TopClientsCard({
    required this.clients,
  });

  final List<RestaurantTopClientMetric> clients;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22314A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Топ клиенты',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...clients.take(5).map(
            (client) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2437),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayClientName(client),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${client.ordersCount} заказов • ${client.spent} ₸',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x332A7BFF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      client.status,
                      style: const TextStyle(
                        color: Color(0xFFB9C8FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _displayClientName(RestaurantTopClientMetric client) {
    if (client.name?.trim().isNotEmpty == true) return client.name!.trim();
    if (client.phone?.trim().isNotEmpty == true) return client.phone!.trim();
    return 'Клиент';
  }
}

class _RecentOrdersCard extends StatelessWidget {
  const _RecentOrdersCard({
    required this.orders,
  });

  final List<RestaurantRecentOrderMetric> orders;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22314A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Последние заказы',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...orders.take(5).map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.customerName?.trim().isNotEmpty == true
                              ? order.customerName!.trim()
                              : (order.phone?.trim().isNotEmpty == true
                                  ? order.phone!.trim()
                                  : 'Клиент'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${order.total} ₸ • ${order.status ?? '—'}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatDateTime(order.createdAt),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime? value) {
    if (value == null) return '—';
    return DateFormat('dd.MM HH:mm').format(value.toLocal());
  }
}
``

## FILE: lib\features\reviews\data\restaurant_reviews_api.dart

- Size: 2355 bytes

``dart
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/reviews/domain/restaurant_review.dart';

class RestaurantReviewsApi {
  const RestaurantReviewsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<RestaurantReviewsPageData> getRestaurantReviews({
    required String restaurantId,
    int page = 1,
    int limit = 20,
  }) async {
    final path = Uri(
      path: '/restaurants/$restaurantId/reviews',
      queryParameters: <String, String>{
        'page': '$page',
        'limit': '$limit',
        'includeUser': 'true',
      },
    ).toString();

    final dynamic response = await _apiClient.get(path);

    if (response is! Map) {
      throw Exception('Некорректный ответ сервера по отзывам');
    }

    final json = Map<String, dynamic>.from(response);
    final itemsRaw = json['items'];
    final metaRaw = json['meta'];

    final items = itemsRaw is List
        ? itemsRaw
            .whereType<Map>()
            .map((e) => RestaurantReview.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false)
        : <RestaurantReview>[];

    final meta = metaRaw is Map
        ? ReviewsMeta.fromJson(Map<String, dynamic>.from(metaRaw))
        : ReviewsMeta(
            page: page,
            limit: limit,
            total: items.length,
          );

    return RestaurantReviewsPageData(
      items: items,
      meta: meta,
    );
  }
}

class RestaurantReviewsPageData {
  const RestaurantReviewsPageData({
    required this.items,
    required this.meta,
  });

  final List<RestaurantReview> items;
  final ReviewsMeta meta;
}

class ReviewsMeta {
  const ReviewsMeta({
    required this.page,
    required this.limit,
    required this.total,
  });

  final int page;
  final int limit;
  final int total;

  factory ReviewsMeta.fromJson(Map<String, dynamic> json) {
    return ReviewsMeta(
      page: _toInt(json['page'], 1),
      limit: _toInt(json['limit'], 20),
      total: _toInt(json['total'], 0),
    );
  }

  static int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
``

## FILE: lib\features\reviews\domain\restaurant_review.dart

- Size: 5764 bytes

``dart
class RestaurantReview {
  const RestaurantReview({
    required this.id,
    required this.rating,
    required this.createdAt,
    required this.text,
    required this.userName,
    this.userAvatar,
    this.media = const [],
    this.reactions = const [],
    this.reactionsSummary = const {},
    this.response,
  });

  final String id;
  final int rating;
  final DateTime createdAt;
  final String? text;
  final String userName;
  final String? userAvatar;
  final List<ReviewMedia> media;
  final List<ReviewReaction> reactions;
  final Map<String, int> reactionsSummary;
  final ReviewResponse? response;

  factory RestaurantReview.fromJson(Map<String, dynamic> json) {
    final user = _asMap(json['user']);

    return RestaurantReview(
      id: (json['id'] ?? '').toString(),
      rating: _toInt(json['rating']),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      text: _toNullableString(json['text']),
      userName: _buildUserName(user),
      userAvatar: _toNullableString(user?['avatarUrl']),
      media: _toListOfMaps(json['media'])
          .map(ReviewMedia.fromJson)
          .toList(growable: false),
      reactions: _toListOfMaps(json['reactions'])
          .map(ReviewReaction.fromJson)
          .toList(growable: false),
      reactionsSummary: _toSummaryMap(json['reactionsSummary']),
      response: json['response'] == null
          ? null
          : ReviewResponse.fromJson(
              Map<String, dynamic>.from(json['response'] as Map),
            ),
    );
  }

  static String _buildUserName(Map<String, dynamic>? user) {
    if (user == null) return 'Пользователь';

    final firstName = _toNullableString(user['firstName']) ?? '';
    final lastName = _toNullableString(user['lastName']) ?? '';
    final fullName = '$firstName $lastName'.trim();

    if (fullName.isNotEmpty) return fullName;

    final phone = _toNullableString(user['phone']);
    if (phone != null && phone.isNotEmpty) return phone;

    return 'Пользователь';
  }
}

class ReviewMedia {
  const ReviewMedia({
    required this.id,
    required this.type,
    required this.url,
    this.previewUrl,
    this.createdAt,
  });

  final String id;
  final String type;
  final String url;
  final String? previewUrl;
  final DateTime? createdAt;

  bool get isImage => type == 'IMAGE';
  bool get isVideo => type == 'VIDEO';
  bool get isAudio => type == 'AUDIO';

  factory ReviewMedia.fromJson(Map<String, dynamic> json) {
    return ReviewMedia(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      previewUrl: _toNullableString(json['previewUrl']),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

class ReviewReaction {
  const ReviewReaction({
    required this.id,
    required this.userId,
    required this.type,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String type;
  final DateTime? createdAt;

  factory ReviewReaction.fromJson(Map<String, dynamic> json) {
    return ReviewReaction(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

class ReviewResponse {
  const ReviewResponse({
    required this.id,
    required this.createdByName,
    required this.text,
    required this.media,
    required this.reactions,
    required this.reactionsSummary,
    this.createdAt,
  });

  final String id;
  final String createdByName;
  final String? text;
  final List<ReviewMedia> media;
  final List<ReviewReaction> reactions;
  final Map<String, int> reactionsSummary;
  final DateTime? createdAt;

  bool get hasContent =>
      (text != null && text!.trim().isNotEmpty) || media.isNotEmpty;

  factory ReviewResponse.fromJson(Map<String, dynamic> json) {
    final createdByUser = _asMap(json['createdByUser']);

    return ReviewResponse(
      id: (json['id'] ?? '').toString(),
      createdByName: RestaurantReview._buildUserName(createdByUser),
      text: _toNullableString(json['text']),
      media: _toListOfMaps(json['media'])
          .map(ReviewMedia.fromJson)
          .toList(growable: false),
      reactions: _toListOfMaps(json['reactions'])
          .map(ReviewReaction.fromJson)
          .toList(growable: false),
      reactionsSummary: _toSummaryMap(json['reactionsSummary']),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

List<Map<String, dynamic>> _toListOfMaps(dynamic raw) {
  if (raw is! List) return const [];

  return raw
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String? _toNullableString(dynamic value) {
  if (value == null) return null;
  final result = value.toString().trim();
  return result.isEmpty ? null : result;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, int> _toSummaryMap(dynamic raw) {
  if (raw is! Map) return const {};

  final result = <String, int>{};
  raw.forEach((key, value) {
    result[key.toString()] = _toInt(value);
  });
  return result;
}
``

## FILE: lib\features\reviews\presentation\pages\restaurant_reviews_page.dart

- Size: 30904 bytes

``dart
import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/config/app_config.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/reviews/data/restaurant_reviews_api.dart';
import 'package:jetkiz_restaurant/features/reviews/domain/restaurant_review.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';

class RestaurantReviewsPage extends StatefulWidget {
  const RestaurantReviewsPage({
    super.key,
    required this.restaurantId,
  });

  final String restaurantId;

  @override
  State<RestaurantReviewsPage> createState() => _RestaurantReviewsPageState();
}

class _RestaurantReviewsPageState extends State<RestaurantReviewsPage> {
  late final RestaurantReviewsApi _api;

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  List<RestaurantReview> _items = const [];

  @override
  void initState() {
    super.initState();
    _api = RestaurantReviewsApi(ApiClient());
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isRefreshing = true;
      });
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final result = await _api.getRestaurantReviews(
        restaurantId: widget.restaurantId,
      );

      if (!mounted) return;

      setState(() {
        _items = result.items;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09111C),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Отзывы',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ошибка загрузки отзывов: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF489F2A),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        color: const Color(0xFF489F2A),
        backgroundColor: const Color(0xFF121B2C),
        child: ListView(
          children: const [
            SizedBox(height: 140),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Пока нет отзывов',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      color: const Color(0xFF489F2A),
      backgroundColor: const Color(0xFF121B2C),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _items[index];
          return _ReviewCard(review: item);
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
  });

  final RestaurantReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF151F32),
            Color(0xFF0D1524),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF22324A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(imageUrl: review.userAvatar),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (index) => Icon(
                            index < review.rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 18,
                            color: const Color(0xFFFFC107),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(review.createdAt),
                          style: const TextStyle(
                            color: Color(0xFF93A0B4),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((review.text ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review.text!.trim(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
          if (review.media.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ReviewMediaPreview(media: review.media),
          ],
          if (review.reactionsSummary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: review.reactionsSummary.entries.map((entry) {
                return _ReactionChip(
                  label: _reactionEmoji(entry.key),
                  count: entry.value,
                );
              }).toList(growable: false),
            ),
          ],
          if (review.response != null && review.response!.hasContent) ...[
            const SizedBox(height: 14),
            _ResponseBlock(response: review.response!),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day.$month.$year';
  }

  static String _reactionEmoji(String type) {
    switch (type) {
      case 'LIKE':
        return '👍';
      case 'LOVE':
        return '❤️';
      case 'FIRE':
        return '🔥';
      case 'USEFUL':
        return '💡';
      case 'YUMMY':
        return '😍';
      default:
        return '✨';
    }
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.imageUrl,
  });

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final absolute = _toAbsoluteUrl(imageUrl);

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF22324A),
        borderRadius: BorderRadius.circular(999),
      ),
      clipBehavior: Clip.antiAlias,
      child: absolute == null
          ? const Icon(
              Icons.person_rounded,
              color: Colors.white70,
              size: 20,
            )
          : Image.network(
              absolute,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.person_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ),
    );
  }
}

class _ReviewMediaPreview extends StatelessWidget {
  const _ReviewMediaPreview({
    required this.media,
  });

  final List<ReviewMedia> media;

  @override
  Widget build(BuildContext context) {
    final images = media.where((e) => e.isImage).toList(growable: false);
    final videos = media.where((e) => e.isVideo).toList(growable: false);
    final audios = media.where((e) => e.isAudio).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          GridView.builder(
            itemCount: images.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemBuilder: (_, index) {
              final item = images[index];
              final url = _toAbsoluteUrl(item.url);

              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Material(
                  color: const Color(0xFF1E2A40),
                  child: InkWell(
                    onTap: url == null
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _ImageViewerPage(
                                  imageUrls: images
                                      .map((e) => _toAbsoluteUrl(e.url))
                                      .whereType<String>()
                                      .toList(growable: false),
                                  initialIndex: index,
                                ),
                              ),
                            );
                          },
                    child: url == null
                        ? const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white70,
                          )
                        : Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white70,
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        if (videos.isNotEmpty) ...[
          if (images.isNotEmpty) const SizedBox(height: 10),
          ...videos.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _VideoReviewPlayer(media: item),
            );
          }),
        ],
        if (audios.isNotEmpty) ...[
          if (images.isNotEmpty || videos.isNotEmpty) const SizedBox(height: 2),
          ...audios.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AudioReviewPlayer(media: item),
            );
          }),
        ],
      ],
    );
  }
}

class _VideoReviewPlayer extends StatefulWidget {
  const _VideoReviewPlayer({
    required this.media,
  });

  final ReviewMedia media;

  @override
  State<_VideoReviewPlayer> createState() => _VideoReviewPlayerState();
}

class _VideoReviewPlayerState extends State<_VideoReviewPlayer> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _error;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final url = _toAbsoluteUrl(widget.media.url);
    if (url == null) {
      setState(() {
        _isLoading = false;
        _error = 'Некорректная ссылка на видео';
      });
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      await controller.setLooping(false);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isLoading = false;
        _isReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Не удалось загрузить видео';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null || !_isReady) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final preview = _toAbsoluteUrl(widget.media.previewUrl ?? widget.media.url);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111B2B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF22324A)),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: _controller?.value.aspectRatio == null ||
                      _controller!.value.aspectRatio <= 0
                  ? (16 / 9)
                  : _controller!.value.aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isReady && _controller != null)
                    VideoPlayer(_controller!)
                  else if (preview != null)
                    Image.network(
                      preview,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF1E2A40),
                        child: const Icon(
                          Icons.videocam_outlined,
                          color: Colors.white70,
                          size: 40,
                        ),
                      ),
                    )
                  else
                    Container(
                      color: const Color(0xFF1E2A40),
                      child: const Icon(
                        Icons.videocam_outlined,
                        color: Colors.white70,
                        size: 40,
                      ),
                    ),
                  if (_isLoading)
                    Container(
                      color: Colors.black26,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  if (_error != null)
                    Container(
                      color: Colors.black38,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (_error == null)
                    Center(
                      child: GestureDetector(
                        onTap: _togglePlay,
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Icon(
                            (_controller?.value.isPlaying ?? false)
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Видео-отзыв',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_isReady && _controller != null)
                Text(
                  _formatDuration(_controller!.value.position),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          if (_isReady && _controller != null)
            VideoProgressIndicator(
              _controller!,
              allowScrubbing: true,
              padding: const EdgeInsets.only(top: 8),
              colors: VideoProgressColors(
                playedColor: const Color(0xFF65C044),
                backgroundColor: Colors.white24,
                bufferedColor: Colors.white38,
              ),
            ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration value) {
    final total = value.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _AudioReviewPlayer extends StatefulWidget {
  const _AudioReviewPlayer({
    required this.media,
  });

  final ReviewMedia media;

  @override
  State<_AudioReviewPlayer> createState() => _AudioReviewPlayerState();
}

class _AudioReviewPlayerState extends State<_AudioReviewPlayer> {
  late final AudioPlayer _player;

  bool _isLoading = true;
  String? _error;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _bind();
    _init();
  }

  void _bind() {
    _player.durationStream.listen((value) {
      if (!mounted) return;
      setState(() {
        _duration = value ?? Duration.zero;
      });
    });

    _player.positionStream.listen((value) {
      if (!mounted) return;
      setState(() {
        _position = value;
      });
    });

    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
      });
    });
  }

  Future<void> _init() async {
    final url = _toAbsoluteUrl(widget.media.url);
    if (url == null) {
      setState(() {
        _isLoading = false;
        _error = 'Некорректная ссылка на аудио';
      });
      return;
    }

    try {
      await _player.setUrl(url);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Не удалось загрузить аудио';
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_error != null) return;

    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _seek(double value) async {
    await _player.seek(Duration(milliseconds: value.round()));
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = _duration.inMilliseconds <= 0 ? 1 : _duration.inMilliseconds;
    final currentMs = _position.inMilliseconds.clamp(0, maxMs).toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF111B2B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF22324A)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2A1B),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: const Color(0xFF65C044),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Аудио-отзыв',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _formatDuration(_position),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: currentMs,
                min: 0,
                max: maxMs.toDouble(),
                activeColor: const Color(0xFF65C044),
                inactiveColor: Colors.white24,
                onChanged: _isLoading ? null : _seek,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_position),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDuration(Duration value) {
    final total = value.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _ResponseBlock extends StatelessWidget {
  const _ResponseBlock({
    required this.response,
  });

  final ReviewResponse response;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x1426A65B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0x55489F2A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ответ ресторана',
            style: TextStyle(
              color: Color(0xFF65C044),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            response.createdByName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if ((response.text ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              response.text!.trim(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF111B2B),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF22324A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageViewerPage extends StatefulWidget {
  const _ImageViewerPage({
    required this.imageUrls,
    required this.initialIndex,
  });

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.imageUrls.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_index + 1} / $total',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: total,
        onPageChanged: (value) {
          setState(() {
            _index = value;
          });
        },
        itemBuilder: (_, index) {
          final imageUrl = widget.imageUrls[index];

          return InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Center(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white70,
                  size: 40,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String? _toAbsoluteUrl(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return null;

  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }

  if (value.startsWith('/')) {
    return '${AppConfig.baseUrl}$value';
  }

  return '${AppConfig.baseUrl}/$value';
}
``

## FILE: lib\main.dart

- Size: 175 bytes

``dart
import 'package:flutter/material.dart';
import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JetkizRestaurantApp());
}



``

## FILE: pubspec.yaml

- Size: 619 bytes

``yaml
name: jetkiz_restaurant
description: "JETKIZ restaurant application"
publish_to: 'none'

version: 1.0.0+1

environment:
  sdk: ^3.10.4

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  cupertino_icons: ^1.0.8
  http: ^1.6.0
  http_parser: ^4.0.2
  shared_preferences: ^2.5.4
  flutter_secure_storage: ^9.2.2
  image_picker: ^1.2.1
  dio: ^5.4.0
  intl: ^0.20.2
  flutter_image_compress: ^2.3.0
  video_player: ^2.9.2
  just_audio: ^0.9.46

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true

``

# Manual audit checklist

## Auth
- Can restaurant login?
- Does token persist safely?
- Does refresh work?
- What happens on 401?

## Orders
- Does restaurant see new orders?
- Can restaurant accept order?
- Can restaurant reject order?
- Can restaurant mark cooking?
- Can restaurant mark ready?
- Are invalid status transitions blocked?

## Menu
- Can restaurant see products?
- Can restaurant enable/disable product?
- Are unavailable products blocked from client ordering?

## Runtime
- Does restaurant online/offline status work?
- Does workingHours affect availability?
- Are closed restaurants protected from new orders?

## Push
- Does restaurant receive push for new order?
- Does push tap open order details?
- Does unknown push payload fail safely?

## Release risks
- Missing empty states
- Missing loading states
- Missing error states
- Weak API error parsing
- Missing role checks
- Screens not connected to backend
- Hardcoded texts or broken Cyrillic

