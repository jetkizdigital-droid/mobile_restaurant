import 'package:flutter_test/flutter_test.dart';
import 'package:jetkiz_restaurant/core/config/app_config.dart';
import 'package:jetkiz_restaurant/core/input/kazakhstan_phone_input.dart';
import 'package:jetkiz_restaurant/core/push/restaurant_push_notification_service.dart';

void main() {
  test('release API origin is the JETKIZ production API', () {
    expect(AppConfig.productionBaseUrl, 'https://api.jetkiz.asia');
  });

  test('Kazakhstan phone normalization accepts +7 and 8 prefixes', () {
    expect(normalizeKazakhstanPhone('+7 777 123 45 67'), '+77771234567');
    expect(normalizeKazakhstanPhone('8 777 123 45 67'), '+77771234567');
  });

  test('invalid Kazakhstan phone is rejected', () {
    expect(normalizeKazakhstanPhone('+7 701 123 45'), isEmpty);
    expect(normalizeKazakhstanPhone('+1 777 123 45 67'), isEmpty);
  });

  test('new-order notification channel contract stays stable', () {
    expect(
      RestaurantPushNotificationService.androidNewOrderChannelId,
      'restaurant_new_orders_v2',
    );
    expect(
      RestaurantPushNotificationService.restaurantOrderSoundName,
      'restaurant_order',
    );
  });
}
