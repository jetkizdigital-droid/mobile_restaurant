import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Stable installation identifier used to bind Restaurant auth sessions and
/// push registrations to the same device identity.
///
/// This is intentionally an app-scoped random identifier rather than a
/// hardware/advertising identifier. It persists in SharedPreferences until the
/// application data is cleared.
abstract final class RestaurantDeviceIdentity {
  static const String _deviceIdKey = 'restaurant_device_id';

  static Future<String> getOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey)?.trim();

    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final random = Random.secure();
    final value = [
      DateTime.now().millisecondsSinceEpoch.toRadixString(16),
      random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
      random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
    ].join('-');

    await prefs.setString(_deviceIdKey, value);
    return value;
  }
}
