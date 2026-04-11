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