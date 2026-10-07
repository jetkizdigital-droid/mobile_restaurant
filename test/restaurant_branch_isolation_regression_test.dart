import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restaurant requests keep their original branch across retries', () {
    final source = File('lib/core/network/api_client.dart').readAsStringSync();

    expect(
      source,
      contains('final scope = requestScope ?? await _captureRequestScope();'),
    );
    expect(source, contains('restaurantId: scope.restaurantId'));
    expect(source, contains('requestScope: scope'));
  });

  test('late restaurant runtime responses cannot overwrite a newer branch', () {
    final source = File(
      'lib/features/navigation/presentation/pages/restaurant_shell_v2_page.dart',
    ).readAsStringSync();

    expect(source, contains('int _restaurantLoadGeneration = 0;'));
    expect(source, contains('generation != _restaurantLoadGeneration'));
  });

  test('delayed READY action keeps the restaurant where it was confirmed', () {
    final source = File(
      'lib/features/orders/presentation/pages/restaurant_orders_localized_page.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        'final restaurantId = ApiClient.instance.selectedRestaurantId?.trim();',
      ),
    );
    expect(source, contains('_commitReady(order, orderId, restaurantId)'));
    expect(source, contains('restaurantId: restaurantId'));
    expect(source, contains('_loadGeneration++;'));
  });
}
