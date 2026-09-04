import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class RestaurantDeviceIdentity {
  RestaurantDeviceIdentity._();

  static const _deviceIdKey = 'restaurant_device_id';

  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey)?.trim();

    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final random = Random.secure();
    final value = [
      DateTime.now().millisecondsSinceEpoch.toRadixString(16),
      random.nextInt(1 << 32).toRadixString(16),
      random.nextInt(1 << 32).toRadixString(16),
    ].join('-');

    await prefs.setString(_deviceIdKey, value);
    return value;
  }
}
