import 'dart:async';

import 'package:jetkiz_restaurant/core/network/api_client.dart';

/// Compatibility facade for older screens.
///
/// ApiClient is the single runtime source of truth for the selected restaurant.
/// Persisted state is managed by ApiClient through AuthStorage.
class SessionManager {
  static String? get restaurantId => ApiClient.instance.selectedRestaurantId;

  static set restaurantId(String? value) {
    unawaited(ApiClient.instance.setSelectedRestaurantId(value));
  }
}
