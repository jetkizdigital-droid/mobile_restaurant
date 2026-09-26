import 'package:flutter/foundation.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_api.dart';

class RestaurantAuthSmokeResult {
  const RestaurantAuthSmokeResult({required this.success, required this.message});

  final bool success;
  final String message;
}

Future<RestaurantAuthSmokeResult?> runRestaurantAuthSmokeIfRequested() async {
  const enabled = bool.fromEnvironment('E2E_AUTH_SMOKE');
  if (!enabled) return null;

  const phone = String.fromEnvironment('E2E_RESTAURANT_PHONE');
  const password = String.fromEnvironment('E2E_RESTAURANT_PASSWORD');

  if (phone.trim().isEmpty || password.isEmpty) {
    const message = 'Missing E2E restaurant credentials';
    debugPrint('JETKIZ_RESTAURANT_E2E_AUTH_FAILED: $message');
    return const RestaurantAuthSmokeResult(success: false, message: message);
  }

  final auth = AuthApi();

  try {
    final login = await auth.loginRestaurantWithPassword(
      phone: phone.trim(),
      password: password,
    );

    if (login['passwordChangeRequired'] == true) {
      const message = 'Restaurant account requires password change';
      debugPrint('JETKIZ_RESTAURANT_E2E_AUTH_FAILED: $message');
      return const RestaurantAuthSmokeResult(success: false, message: message);
    }

    final me = await auth.getMe();
    if (me.isEmpty) {
      const message = 'Restaurant session verification returned empty payload';
      debugPrint('JETKIZ_RESTAURANT_E2E_AUTH_FAILED: $message');
      return const RestaurantAuthSmokeResult(success: false, message: message);
    }

    const message = 'Production restaurant login and session verification passed';
    debugPrint('JETKIZ_RESTAURANT_E2E_AUTH_OK');
    return const RestaurantAuthSmokeResult(success: true, message: message);
  } catch (error, stackTrace) {
    final message = '${error.runtimeType}: $error';
    debugPrint('JETKIZ_RESTAURANT_E2E_AUTH_FAILED: $message');
    if (kDebugMode) {
      debugPrintStack(stackTrace: stackTrace);
    }
    return RestaurantAuthSmokeResult(success: false, message: message);
  }
}
