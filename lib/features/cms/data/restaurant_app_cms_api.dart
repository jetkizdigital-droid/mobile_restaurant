import 'package:flutter/foundation.dart';
import 'package:jetkiz_restaurant/core/config/app_build_info.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/cms/domain/restaurant_app_bootstrap.dart';

class RestaurantAppCmsApi {
  RestaurantAppCmsApi({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<RestaurantAppBootstrap> getBootstrap() async {
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'IOS',
      TargetPlatform.android => 'ANDROID',
      _ => 'UNKNOWN',
    };

    final path = Uri(
      path: '/restaurant-app-cms/bootstrap',
      queryParameters: <String, String>{
        'platform': platform,
        'appVersion': AppBuildInfo.versionName,
      },
    ).toString();

    final response = await _apiClient.get(path);
    if (response is! Map) {
      throw Exception('Некорректный ответ конфигурации приложения');
    }

    return RestaurantAppBootstrap.fromJson(Map<String, dynamic>.from(response));
  }

  Future<void> dismissBanner(String bannerId) async {
    final id = bannerId.trim();
    if (id.isEmpty) return;

    await _apiClient.post('/restaurant-app-cms/dismiss', {'bannerId': id});
  }

  Future<void> trackBannerEvent({
    required String bannerId,
    required String eventType,
  }) async {
    final id = bannerId.trim();
    if (id.isEmpty) return;

    await _apiClient.post('/restaurant-app-cms/events', {
      'bannerId': id,
      'eventType': eventType,
    });
  }
}
