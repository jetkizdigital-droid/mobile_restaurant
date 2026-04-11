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