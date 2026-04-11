// JETKIZ RESTAURANT APP
// Order list model for restaurant-side orders screen.
//
// BACKEND CONTRACT:
// GET /orders
//
// Confirmed fields from backend:
// - id
// - number
// - status
// - subtotal
// - deliveryFee
// - total
// - paymentStatus
// - comment
// - leaveAtDoor
// - phone
// - assignedAt
// - pickedUpAt
// - deliveredAt
// - promisedAt
// - user
// - courier
// - previewItems / items / itemsCount
//
// Important:
// Backend already filters orders by current restaurantId for RESTAURANT role.
// This model is intentionally built from real confirmed fields only.

class RestaurantOrder {
  final String id;
  final int? number;
  final String status;
  final int subtotal;
  final int deliveryFee;
  final int total;
  final String? paymentStatus;
  final String? comment;
  final bool leaveAtDoor;
  final String? phone;
  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? promisedAt;
  final RestaurantOrderUser? user;
  final RestaurantOrderCourier? courier;
  final List<RestaurantOrderItem> items;
  final int itemsCount;
  final DateTime? createdAt;

  const RestaurantOrder({
    required this.id,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.leaveAtDoor,
    required this.items,
    required this.itemsCount,
    this.number,
    this.paymentStatus,
    this.comment,
    this.phone,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.promisedAt,
    this.user,
    this.courier,
    this.createdAt,
  });

  factory RestaurantOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];

    return RestaurantOrder(
      id: json['id']?.toString() ?? '',
      number: _toInt(json['number']),
      status: json['status']?.toString() ?? 'UNKNOWN',
      subtotal: _toInt(json['subtotal']) ?? 0,
      deliveryFee: _toInt(json['deliveryFee']) ?? 0,
      total: _toInt(json['total']) ?? 0,
      paymentStatus: json['paymentStatus']?.toString(),
      comment: json['comment']?.toString(),
      leaveAtDoor: json['leaveAtDoor'] == true,
      phone: json['phone']?.toString(),
      assignedAt: _toDateTime(json['assignedAt']),
      pickedUpAt: _toDateTime(json['pickedUpAt']),
      deliveredAt: _toDateTime(json['deliveredAt']),
      promisedAt: _toDateTime(json['promisedAt']),
      user: json['user'] is Map<String, dynamic>
          ? RestaurantOrderUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      courier: json['courier'] is Map<String, dynamic>
          ? RestaurantOrderCourier.fromJson(
              json['courier'] as Map<String, dynamic>,
            )
          : null,
      items: rawItems
          .whereType<Map>()
          .map((e) => RestaurantOrderItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      itemsCount: _toInt(json['itemsCount']) ?? rawItems.length,
      createdAt: _toDateTime(json['createdAt']),
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _toDateTime(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

class RestaurantOrderItem {
  final String id;
  final String? productId;
  final String title;
  final int price;
  final int quantity;

  const RestaurantOrderItem({
    required this.id,
    required this.title,
    required this.price,
    required this.quantity,
    this.productId,
  });

  factory RestaurantOrderItem.fromJson(Map<String, dynamic> json) {
    return RestaurantOrderItem(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString(),
      title: json['title']?.toString() ?? 'Без названия',
      price: RestaurantOrder._toInt(json['price']) ?? 0,
      quantity: RestaurantOrder._toInt(json['quantity']) ?? 0,
    );
  }
}

class RestaurantOrderUser {
  final String id;
  final String? phone;
  final String? firstName;
  final String? lastName;

  const RestaurantOrderUser({
    required this.id,
    this.phone,
    this.firstName,
    this.lastName,
  });

  factory RestaurantOrderUser.fromJson(Map<String, dynamic> json) {
    return RestaurantOrderUser(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString(),
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
    );
  }

  String get displayName {
    final fullName = [
      firstName?.trim() ?? '',
      lastName?.trim() ?? '',
    ].where((e) => e.isNotEmpty).join(' ');
    if (fullName.isNotEmpty) return fullName;
    if ((phone ?? '').trim().isNotEmpty) return phone!.trim();
    return 'Клиент';
  }
}

class RestaurantOrderCourier {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? phone;

  const RestaurantOrderCourier({
    required this.id,
    this.firstName,
    this.lastName,
    this.phone,
  });

  factory RestaurantOrderCourier.fromJson(Map<String, dynamic> json) {
    return RestaurantOrderCourier(
      id: json['id']?.toString() ?? '',
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
      phone: json['phone']?.toString(),
    );
  }

  String get displayName {
    final fullName = [
      firstName?.trim() ?? '',
      lastName?.trim() ?? '',
    ].where((e) => e.isNotEmpty).join(' ');
    if (fullName.isNotEmpty) return fullName;
    if ((phone ?? '').trim().isNotEmpty) return phone!.trim();
    return 'Курьер';
  }
}