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
      '/restaurants/$restaurantId/menu/manage?includeUnavailable=1',
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

    await _client.uploadFiles(
      '/restaurants/$restaurantId/menu/products/$productId/images',
      files: otherImages,
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