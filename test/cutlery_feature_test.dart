import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jetkiz_restaurant/features/orders/domain/restaurant_order.dart';
import 'package:jetkiz_restaurant/features/orders/domain/restaurant_order_details.dart';
import 'package:jetkiz_restaurant/features/restaurant/domain/restaurant_profile_data.dart';

void main() {
  test('profile saves cutlery settings in the same restaurant PATCH', () {
    final source = File(
      'lib/features/restaurant_profile/presentation/pages/restaurant_profile_page.dart',
    ).readAsStringSync();

    final saveStart = source.indexOf('Future<void> _saveProfile');
    final saveEnd = source.indexOf('Future<File> _prepareUploadFile', saveStart);
    final saveBlock = source.substring(saveStart, saveEnd);

    expect(saveBlock, contains('_restaurantApi.updateMe('));
    expect(saveBlock, contains('cutleryEnabled: _cutleryEnabled'));
    expect(saveBlock, isNot(contains('updateCutlerySettings')));
  });


  test('cutlery switch works outside profile edit mode', () {
    final source = File(
      'lib/features/restaurant_profile/presentation/pages/restaurant_profile_page.dart',
    ).readAsStringSync();

    expect(source, contains('onChanged: savingToggle ? null : onEnabledChanged'));
    expect(source, isNot(contains('onChanged: editing ? onEnabledChanged : null')));
    expect(source, contains('onEnabledChanged: _toggleCutleryEnabled'));
  });

  test('successful profile save is not turned into an error by a follow-up reload', () {
    final source = File(
      'lib/features/restaurant_profile/presentation/pages/restaurant_profile_page.dart',
    ).readAsStringSync();

    final saveStart = source.indexOf('Future<void> _saveProfile');
    final saveEnd = source.indexOf(
      'Future<void> _toggleCutleryEnabled',
      saveStart,
    );
    final saveBlock = source.substring(saveStart, saveEnd);

    expect(saveBlock, contains('_restaurantApi.updateMe('));
    expect(saveBlock, isNot(contains('await _reloadProfile()')));
  });

  test('restaurant API uses the PATCH response as the save result', () {
    final source = File(
      'lib/features/restaurant/data/restaurant_api.dart',
    ).readAsStringSync();

    expect(source, contains('final response = await _client.patch('));
    expect(source, contains('Future<RestaurantProfileData> setCutleryEnabled'));
    expect(
      source,
      contains("'/restaurants/me',\n      <String, dynamic>{'cutleryEnabled': value}"),
    );
  });

  test('restaurant order list parses requested cutlery count', () {
    final order = RestaurantOrder.fromJson({
      'id': 'order-1',
      'status': 'CREATED',
      'subtotal': 10000,
      'deliveryFee': 800,
      'cutleryCount': 5,
      'cutleryAmount': 200,
      'total': 11000,
      'leaveAtDoor': false,
      'items': const [],
    });

    expect(order.cutleryCount, 5);
    expect(order.cutleryAmount, 200);
  });

  test('restaurant order details preserve cutlery snapshot', () {
    final order = RestaurantOrderDetails.fromJson({
      'id': 'order-1',
      'status': 'CREATED',
      'subtotal': 10000,
      'deliveryFee': 800,
      'discountAmount': 0,
      'deliveryDiscountAmount': 0,
      'cutleryCount': 5,
      'cutleryFreeLimitApplied': 3,
      'cutleryUnitPriceApplied': 100,
      'cutleryPaidCount': 2,
      'cutleryAmount': 200,
      'total': 11000,
      'leaveAtDoor': false,
      'items': const [],
    });

    expect(order.cutleryCount, 5);
    expect(order.cutleryFreeLimitApplied, 3);
    expect(order.cutleryPaidCount, 2);
    expect(order.cutleryAmount, 200);
  });

  test('restaurant profile parses cutlery settings', () {
    final profile = RestaurantProfileData.fromJson({
      'id': 'restaurant-1',
      'nameRu': 'KINZA',
      'cutleryEnabled': true,
      'cutleryFreeLimit': 3,
      'cutleryUnitPrice': 100,
      'cutleryMaxCount': 10,
    });

    expect(profile.cutleryEnabled, isTrue);
    expect(profile.cutleryFreeLimit, 3);
    expect(profile.cutleryUnitPrice, 100);
    expect(profile.cutleryMaxCount, 10);
  });
}
