import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/cms/data/restaurant_app_cms_session.dart';

class RestaurantMenuApi {
  static const int maxProductImages = 5;

  final ApiClient _client;

  // One RestaurantMenuApi instance belongs to one editor screen. Once a new
  // product is successfully created, retries in the same editor update that
  // product instead of creating another row if a later step (images/stop-list)
  // failed.
  String? _createdProductId;

  // Existing image mutations are staged locally by the editor and committed
  // only from updateProduct(), i.e. from the final Save action.
  final Set<String> _pendingDeletedImageIds = <String>{};
  String? _pendingMainImageId;

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

  Future<void> deleteProduct(String restaurantId, String productId) async {
    _requireFeature('MENU_EDIT_ENABLED', 'Редактирование меню недоступно');
    await _client.delete('/restaurants/$restaurantId/menu/products/$productId');
  }

  Future<void> updateAvailability({
    required String restaurantId,
    required String productId,
    required bool value,
  }) async {
    _requireFeature('STOP_LIST_ENABLED', 'Стоп-лист временно недоступен');
    await _client.patch(
      '/restaurants/$restaurantId/menu/products/$productId',
      {'isAvailable': value},
    );
  }

  Future<Map<String, dynamic>> createProduct(
    String restaurantId,
    Map<String, dynamic> data,
  ) async {
    _requireFeature('MENU_EDIT_ENABLED', 'Редактирование меню недоступно');

    final existingId = _createdProductId;
    if (existingId != null && existingId.isNotEmpty) {
      final response = await _client.patch(
        '/restaurants/$restaurantId/menu/products/$existingId',
        data,
      );
      if (response is Map) {
        return <String, dynamic>{
          ...Map<String, dynamic>.from(response),
          'id': existingId,
        };
      }
      return <String, dynamic>{'id': existingId};
    }

    final response = await _client.post(
      '/restaurants/$restaurantId/menu/products',
      data,
    );

    final result = Map<String, dynamic>.from(response as Map);
    final id = result['id']?.toString().trim() ?? '';
    if (id.isNotEmpty) {
      _createdProductId = id;
    }
    return result;
  }

  Future<Map<String, dynamic>> updateProduct(
    String restaurantId,
    String productId,
    Map<String, dynamic> data,
  ) async {
    _requireFeature('MENU_EDIT_ENABLED', 'Редактирование меню недоступно');
    final response = await _client.patch(
      '/restaurants/$restaurantId/menu/products/$productId',
      data,
    );

    await _flushPendingImageMutations(
      restaurantId: restaurantId,
      productId: productId,
    );

    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> createCategory({
    required String restaurantId,
    required String titleRu,
    required String titleKk,
    int? sortOrder,
  }) async {
    _requireFeature('MENU_EDIT_ENABLED', 'Редактирование меню недоступно');
    final payload = <String, dynamic>{
      'restaurantId': restaurantId,
      'titleRu': titleRu.trim(),
      'titleKk': titleKk.trim(),
    };

    if (sortOrder != null) payload['sortOrder'] = sortOrder;

    final response = await _client.post('/food-categories', payload);
    return response is Map
        ? Map<String, dynamic>.from(response)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateCategory({
    required String restaurantId,
    required String categoryId,
    required String titleRu,
    required String titleKk,
    int? sortOrder,
  }) async {
    _requireFeature('MENU_EDIT_ENABLED', 'Редактирование меню недоступно');
    final payload = <String, dynamic>{
      'titleRu': titleRu.trim(),
      'titleKk': titleKk.trim(),
      if (sortOrder != null) 'sortOrder': sortOrder,
    };

    final response = await _client.patch(
      '/restaurants/$restaurantId/categories/$categoryId',
      payload,
    );

    return response is Map
        ? Map<String, dynamic>.from(response)
        : <String, dynamic>{};
  }

  Future<void> deleteCategory({
    required String restaurantId,
    required String categoryId,
    bool force = false,
  }) async {
    _requireFeature('MENU_EDIT_ENABLED', 'Редактирование меню недоступно');
    final suffix = force ? '?force=1' : '';
    await _client.delete(
      '/restaurants/$restaurantId/categories/$categoryId$suffix',
    );
  }

  Future<void> replaceProductImages({
    required String restaurantId,
    required String productId,
    File? mainImage,
    List<File> otherImages = const [],
  }) async {
    _requireFeature('MENU_EDIT_ENABLED', 'Редактирование меню недоступно');
    if (mainImage == null && otherImages.isEmpty) return;

    final totalImages = (mainImage == null ? 0 : 1) + otherImages.length;
    if (totalImages > maxProductImages) {
      throw Exception(
        'Можно загрузить максимум $maxProductImages фото блюда',
      );
    }

    final preparedMain =
        mainImage == null ? null : await _prepareUploadImage(mainImage);
    final preparedOthers = <File>[];
    for (final image in otherImages) {
      preparedOthers.add(await _prepareUploadImage(image));
    }

    await _client.uploadFiles(
      '/restaurants/$restaurantId/menu/products/$productId/images',
      files: preparedOthers,
      mainFile: preparedMain,
      mainFieldName: 'main',
      filesFieldName: 'others',
    );
  }

  Future<void> addProductImages({
    required String restaurantId,
    required String productId,
    required List<File> images,
  }) async {
    _requireFeature('MENU_EDIT_ENABLED', 'Редактирование меню недоступно');
    if (images.isEmpty) return;
    if (images.length > maxProductImages) {
      throw Exception(
        'Можно загрузить максимум $maxProductImages фото блюда',
      );
    }

    final prepared = <File>[];
    for (final image in images) {
      prepared.add(await _prepareUploadImage(image));
    }

    await _client.uploadFiles(
      '/restaurants/$restaurantId/menu/products/$productId/images/add',
      files: prepared,
      filesFieldName: 'files',
    );
  }

  Future<void> setMainImage({
    required String restaurantId,
    required String productId,
    required String imageId,
  }) async {
    _requireFeature('MENU_EDIT_ENABLED', 'Редактирование меню недоступно');
    final id = imageId.trim();
    if (id.isEmpty || _pendingDeletedImageIds.contains(id)) return;
    _pendingMainImageId = id;
  }

  Future<void> deleteImage({
    required String restaurantId,
    required String productId,
    required String imageId,
  }) async {
    _requireFeature('MENU_EDIT_ENABLED', 'Редактирование меню недоступно');
    final id = imageId.trim();
    if (id.isEmpty) return;
    _pendingDeletedImageIds.add(id);
    if (_pendingMainImageId == id) {
      _pendingMainImageId = null;
    }
  }

  Future<void> _flushPendingImageMutations({
    required String restaurantId,
    required String productId,
  }) async {
    final deletedIds = List<String>.from(_pendingDeletedImageIds);
    for (final imageId in deletedIds) {
      try {
        await _client.delete(
          '/restaurants/$restaurantId/menu/products/$productId/images/$imageId',
        );
      } on ApiException catch (error) {
        // A lost response after a successful delete may make a retry return
        // 404. In that case the requested final state is already reached.
        if (error.statusCode != 404) rethrow;
      }
      _pendingDeletedImageIds.remove(imageId);
    }

    final mainImageId = _pendingMainImageId;
    if (mainImageId == null || mainImageId.isEmpty) return;
    if (_pendingDeletedImageIds.contains(mainImageId)) return;

    await _client.patch(
      '/restaurants/$restaurantId/menu/products/$productId/images/$mainImageId/main',
      <String, dynamic>{},
    );
    _pendingMainImageId = null;
  }

  Future<File> _prepareUploadImage(File original) async {
    final lowerPath = original.path.toLowerCase();
    if (lowerPath.endsWith('.jpg') ||
        lowerPath.endsWith('.jpeg') ||
        lowerPath.endsWith('.png') ||
        lowerPath.endsWith('.webp')) {
      return original;
    }

    final targetPath = '${original.path}_jetkiz_upload.jpg';
    final compressed = await FlutterImageCompress.compressAndGetFile(
      original.absolute.path,
      targetPath,
      format: CompressFormat.jpeg,
      quality: 90,
    );

    if (compressed == null) {
      throw Exception('Не удалось подготовить изображение к загрузке');
    }

    return File(compressed.path);
  }

  void _requireFeature(String key, String fallback) {
    final cms = RestaurantAppCmsSession.instance;
    if (cms.featureEnabled(key)) return;
    throw Exception(cms.featureReason(key) ?? fallback);
  }
}
