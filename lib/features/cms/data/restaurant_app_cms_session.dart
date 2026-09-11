import 'package:flutter/foundation.dart';
import 'package:jetkiz_restaurant/features/cms/data/restaurant_app_cms_api.dart';
import 'package:jetkiz_restaurant/features/cms/domain/restaurant_app_bootstrap.dart';

class RestaurantAppCmsSession {
  RestaurantAppCmsSession._();

  static final RestaurantAppCmsSession instance = RestaurantAppCmsSession._();

  final ValueNotifier<RestaurantAppBootstrap?> state =
      ValueNotifier<RestaurantAppBootstrap?>(null);

  Future<RestaurantAppBootstrap> refresh() async {
    final bootstrap = await RestaurantAppCmsApi().getBootstrap();
    state.value = bootstrap;
    return bootstrap;
  }

  void clear() {
    state.value = null;
  }

  bool featureEnabled(String key) {
    final bootstrap = state.value;
    if (bootstrap != null) return bootstrap.featureEnabled(key);

    // CMS feature flags are operational controls, not authorization. When the
    // optional bootstrap is temporarily unavailable, keep the app usable and
    // let authenticated backend endpoints remain the authoritative guard.
    return true;
  }

  String? featureReason(String key, {bool kazakh = false}) =>
      state.value?.featureReason(key, kazakh: kazakh);
}
