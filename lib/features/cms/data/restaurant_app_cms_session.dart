import 'package:flutter/foundation.dart';
import 'package:jetkiz_restaurant/features/cms/data/restaurant_app_cms_api.dart';
import 'package:jetkiz_restaurant/features/cms/domain/restaurant_app_bootstrap.dart';

class RestaurantAppCmsSession {
  RestaurantAppCmsSession._();

  static final RestaurantAppCmsSession instance = RestaurantAppCmsSession._();

  static const Set<String> _failClosedFeatureKeys = <String>{
    'ACCEPT_ORDERS_ENABLED',
    'REJECT_ORDERS_ENABLED',
    'MENU_EDIT_ENABLED',
    'STOP_LIST_ENABLED',
    'SCHEDULE_EDIT_ENABLED',
    'RESTAURANT_STATUS_EDIT_ENABLED',
  };

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

    // Never permit a state-changing restaurant operation merely because the
    // CMS bootstrap could not be loaded. Read-only screens stay available so
    // a transient CMS outage does not unnecessarily lock the restaurant out
    // of its existing information.
    return !_failClosedFeatureKeys.contains(key.trim().toUpperCase());
  }

  String? featureReason(String key, {bool kazakh = false}) =>
      state.value?.featureReason(key, kazakh: kazakh);
}
