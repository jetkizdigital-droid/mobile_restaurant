import 'package:flutter_test/flutter_test.dart';
import 'package:jetkiz_restaurant/features/orders/domain/restaurant_order.dart';
import 'package:jetkiz_restaurant/features/orders/domain/restaurant_order_details.dart';
import 'package:jetkiz_restaurant/features/restaurant/domain/restaurant_profile_data.dart';

void main() {
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
