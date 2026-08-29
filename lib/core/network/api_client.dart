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
  final StreamController<void> _sessionExpiredController =
      StreamController<void>.broadcast();

  Future<_RefreshResult>? _refreshInFlight;

  String? _selectedRestaurantId;

  String? get selectedRestaurantId => _selectedRestaurantId;
  Stream<void> get sessionExpiredEvents => _sessionExpiredController.stream;

  Future<void> setSelectedRestaurantId(String? restaurantId) async {
    final normalized = restaurantId?.trim();

    if (normalized == null || normalized.isEmpty) {
      _selectedRestaurantId = null;
      await _storage.clearSelectedRestaurantId();
      developer.log('Selected restaurant cleared', name: 'ApiClient');
      return;
    }

    _selectedRestaurantId = normalized;
    await _storage.saveSelectedRestaurantId(normalized);

    developer.log('Selected restaurant set', name: 'ApiClient');
  }

  void clearSelectedRestaurantId() {
    _selectedRestaurantId = null;

    developer.log('Selected restaurant cleared', name: 'ApiClient');
  }

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
      'API Multipart MULTI Request: POST ${uri.path}',
      name: 'ApiClient',
    );

    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(
        await _buildHeaders(authRequired: authRequired, isJson: false),
      );

      if (mainFile != null) {
        request.files.add(await _createMultipart(mainFieldName, mainFile));
      }

      for (final file in files) {
        request.files.add(await _createMultipart(filesFieldName, file));
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw const ApiException(
          'Превышено время ожидания',
          isTransportFailure: true,
        ),
      );

      final response = await http.Response.fromStream(streamedResponse);

      _logResponse('POST', uri, response);

      if (response.statusCode == 401 && authRequired && !isRetryAfterRefresh) {
        final refreshResult = await _tryRefresh();
        if (refreshResult == _RefreshResult.refreshed) {
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
        if (refreshResult == _RefreshResult.transientFailure) {
          throw const ApiException(
            'Не удалось проверить сессию. Проверьте подключение и повторите.',
            isTransportFailure: true,
          );
        }
      }

      if (response.statusCode == 401 && authRequired && isRetryAfterRefresh) {
        await _expireSession();
      }

      return _handleResponse(response);
    } on SocketException {
      throw const ApiException(
        'Нет подключения к серверу',
        isTransportFailure: true,
      );
    } on TimeoutException {
      throw const ApiException(
        'Превышено время ожидания',
        isTransportFailure: true,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        'Ошибка загрузки файлов: ${e.toString()}',
        isTransportFailure: true,
      );
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

    developer.log('API Request: $method ${uri.path}', name: 'ApiClient');

    final headers = await _buildHeaders(
      authRequired: authRequired,
      isJson: true,
    );

    late http.Response response;

    try {
      switch (method) {
        case 'GET':
          response = await _http
              .get(uri, headers: headers)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw const ApiException(
                  'Превышено время ожидания',
                  isTransportFailure: true,
                ),
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
                onTimeout: () => throw const ApiException(
                  'Превышено время ожидания',
                  isTransportFailure: true,
                ),
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
                onTimeout: () => throw const ApiException(
                  'Превышено время ожидания',
                  isTransportFailure: true,
                ),
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
                onTimeout: () => throw const ApiException(
                  'Превышено время ожидания',
                  isTransportFailure: true,
                ),
              );
          break;
        case 'DELETE':
          response = await _http
              .delete(uri, headers: headers)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw const ApiException(
                  'Превышено время ожидания',
                  isTransportFailure: true,
                ),
              );
          break;
        default:
          throw ApiException('Неподдерживаемый HTTP-метод: $method');
      }

      _logResponse(method, uri, response);
    } on SocketException {
      throw const ApiException(
        'Нет подключения к серверу',
        isTransportFailure: true,
      );
    } on TimeoutException {
      throw const ApiException(
        'Превышено время ожидания',
        isTransportFailure: true,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        'Ошибка сети: ${e.toString()}',
        isTransportFailure: true,
      );
    }

    if (response.statusCode == 401 && authRequired && !isRetryAfterRefresh) {
      final refreshResult = await _tryRefresh();
      if (refreshResult == _RefreshResult.refreshed) {
        return _send(
          method: method,
          path: path,
          body: body,
          authRequired: authRequired,
          isRetryAfterRefresh: true,
        );
      }
      if (refreshResult == _RefreshResult.transientFailure) {
        throw const ApiException(
          'Не удалось проверить сессию. Проверьте подключение и повторите.',
          isTransportFailure: true,
        );
      }
    }

    if (response.statusCode == 401 && authRequired && isRetryAfterRefresh) {
      await _expireSession();
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

    developer.log('API Multipart Request: POST ${uri.path}', name: 'ApiClient');
    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(
        await _buildHeaders(authRequired: authRequired, isJson: false),
      );

      request.files.add(await _createMultipart(fieldName, file));

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw const ApiException(
          'Превышено время ожидания',
          isTransportFailure: true,
        ),
      );

      final response = await http.Response.fromStream(streamedResponse);

      _logResponse('POST', uri, response);

      if (response.statusCode == 401 && authRequired && !isRetryAfterRefresh) {
        final refreshResult = await _tryRefresh();
        if (refreshResult == _RefreshResult.refreshed) {
          return _sendMultipart(
            path: path,
            file: file,
            fieldName: fieldName,
            authRequired: authRequired,
            isRetryAfterRefresh: true,
          );
        }
        if (refreshResult == _RefreshResult.transientFailure) {
          throw const ApiException(
            'Не удалось проверить сессию. Проверьте подключение и повторите.',
            isTransportFailure: true,
          );
        }
      }

      if (response.statusCode == 401 && authRequired && isRetryAfterRefresh) {
        await _expireSession();
      }

      return _handleResponse(response);
    } on SocketException {
      throw const ApiException(
        'Нет подключения к серверу',
        isTransportFailure: true,
      );
    } on TimeoutException {
      throw const ApiException(
        'Превышено время ожидания',
        isTransportFailure: true,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        'Ошибка загрузки файла: ${e.toString()}',
        isTransportFailure: true,
      );
    }
  }

  Future<Map<String, String>> _buildHeaders({
    required bool authRequired,
    required bool isJson,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};

    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }

    if (authRequired) {
      final accessToken = await _storage.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    }

    if (_selectedRestaurantId == null ||
        _selectedRestaurantId!.trim().isEmpty) {
      _selectedRestaurantId = await _storage.getSelectedRestaurantId();
    }

    final restaurantId = _selectedRestaurantId?.trim();
    if (restaurantId != null && restaurantId.isNotEmpty) {
      headers['x-restaurant-id'] = restaurantId;
    }

    return headers;
  }

  Future<http.MultipartFile> _createMultipart(String field, File file) async {
    final fileName = file.path.split('/').last.toLowerCase();

    late final String mimeType;

    if (fileName.endsWith('.png')) {
      mimeType = 'image/png';
    } else if (fileName.endsWith('.webp')) {
      mimeType = 'image/webp';
    } else if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) {
      mimeType = 'image/jpeg';
    } else {
      throw const ApiException(
        'Поддерживаются изображения JPG, JPEG, PNG или WEBP',
      );
    }

    return http.MultipartFile.fromPath(
      field,
      file.path,
      filename: fileName,
      contentType: MediaType.parse(mimeType),
    );
  }

  Future<_RefreshResult> _tryRefresh() {
    final activeRefresh = _refreshInFlight;
    if (activeRefresh != null) return activeRefresh;

    final refresh = _performRefresh();
    _refreshInFlight = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    });
  }

  Future<_RefreshResult> _performRefresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _expireSession();
      return _RefreshResult.invalidSession;
    }

    final uri = Uri.parse('${AppConfig.baseUrl}/auth/refresh');

    try {
      final response = await _http
          .post(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 10));
      _logResponse('POST', uri, response);

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
          return _RefreshResult.refreshed;
        }
        return _RefreshResult.transientFailure;
      }

      if (response.statusCode == 400 ||
          response.statusCode == 401 ||
          response.statusCode == 403) {
        await _expireSession();
        return _RefreshResult.invalidSession;
      }
      return _RefreshResult.transientFailure;
    } on SocketException {
      return _RefreshResult.transientFailure;
    } on TimeoutException {
      return _RefreshResult.transientFailure;
    } catch (_) {
      return _RefreshResult.transientFailure;
    }
  }

  Future<void> _expireSession() async {
    await _storage.clearTokens();
    clearSelectedRestaurantId();
    _sessionExpiredController.add(null);
  }

  void _logResponse(String method, Uri uri, http.Response response) {
    final requestId = response.headers['x-request-id'];
    developer.log(
      'API Response: $method ${uri.path} status=${response.statusCode}'
      '${requestId == null || requestId.isEmpty ? '' : ' requestId=$requestId'}',
      name: 'ApiClient',
    );
  }

  dynamic _handleResponse(http.Response response) {
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

    throw ApiException(
      errorMessage,
      statusCode: response.statusCode,
      isTransportFailure: response.statusCode >= 500,
    );
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

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.isTransportFailure = false,
  });

  final String message;
  final int? statusCode;
  final bool isTransportFailure;

  bool get isInvalidSession => statusCode == 401;

  @override
  String toString() => 'Exception: $message';
}

enum _RefreshResult { refreshed, invalidSession, transientFailure }
