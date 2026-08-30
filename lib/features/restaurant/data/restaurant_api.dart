import 'dart:io';

import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/restaurant/domain/restaurant_profile_data.dart';

class RestaurantApi {
  final ApiClient _client;

  RestaurantApi(this._client);

  Future<RestaurantProfileData> getMyRestaurant() async {
    final response = await _client.get('/restaurants/me');
    final profile = Map<String, dynamic>.from(response as Map);

    try {
      final runtimeResponse = await _client.get('/restaurants/me/runtime');
      if (runtimeResponse is Map) {
        profile.addAll(Map<String, dynamic>.from(runtimeResponse));
      }
    } on ApiException catch (error) {
      // Backward-compatible while backend rollout is in progress. Any error
      // except a missing endpoint must remain visible to the caller.
      if (error.statusCode != 404) rethrow;
    }

    return RestaurantProfileData.fromJson(profile);
  }

  Future<RestaurantProfileData> updateMe({
    required String address,
    required String phone,
    required String workingHours,
  }) async {
    await _client.patch(
      '/restaurants/me',
      {
        'address': address,
        'phone': phone,
        'workingHours': workingHours,
      },
    );

    return getMyRestaurant();
  }

  Future<RestaurantProfileData> setAcceptingOrders(bool value) async {
    await _client.patch(
      '/restaurants/me/accepting-orders',
      {'isAcceptingOrders': value},
    );

    return getMyRestaurant();
  }

  Future<RestaurantProfileData> uploadRestaurantCover(File file) async {
    await _client.uploadFile(
      '/restaurants/me/cover',
      file: file,
      fieldName: 'file',
    );

    return getMyRestaurant();
  }
}
