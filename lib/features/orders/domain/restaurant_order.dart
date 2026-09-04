// JETKIZ RESTAURANT APP
// Order list/details model for restaurant-side orders screen.
//
// BACKEND CONTRACT:
// GET /orders
// GET /orders/:id
//
// Confirmed legacy fields from backend:
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
// PICKUP extension fields:
// - fulfillmentType
// - pickupCodeVerifiedAt
// - readyAt
// - courierId
// - addressId
// - address nullable
// - courier nullable
//
// Important:
// Backend already filters orders by current restaurantId for RESTAURANT role.
// This model is defensive: missing new fields must not crash old DELIVERY orders.

class RestaurantOrder {
  final String id;
  final int? number;
  final String status;

  final String? fulfillmentType;
  final DateTime? pickupCodeVerifiedAt;
  final DateTime? readyAt;

  final int subtotal;
  final int deliveryFee;
  final int total;

  final String? paymentStatus;
  final String? comment;
  final bool leaveAtDoor;
  final String? phone;

  final String? addressId;
  final RestaurantOrderAddress? address;

  final String? courierId;
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
    this.fulfillmentType,
    this.pickupCodeVerifiedAt,
    this.readyAt,
    this.paymentStatus,
    this.comment,
    this.phone,
    this.addressId,
    this.address,
    this.courierId,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.promisedAt,
    this.user,
    this.courier,
    this.createdAt,
  });

  factory RestaurantOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = _readItems(json);

    return RestaurantOrder(
      id: _toStringOrEmpty(json['id']),
      number: _toInt(json['number']),
      status: _toStringOrDefault(json['status'], 'UNKNOWN'),

      fulfillmentType: _toNullableString(json['fulfillmentType']),
      pickupCodeVerifiedAt: _toDateTime(json['pickupCodeVerifiedAt']),
      readyAt: _toDateTime(json['readyAt']),

      subtotal: _toInt(json['subtotal']) ?? 0,
      deliveryFee: _toInt(json['deliveryFee']) ?? 0,
      total: _toInt(json['total']) ?? 0,

      paymentStatus: _toNullableString(json['paymentStatus']),
      comment: _toNullableString(json['comment']),
      leaveAtDoor: json['leaveAtDoor'] == true,
      phone: _toNullableString(json['phone']),

      addressId: _toNullableString(json['addressId']),
      address: json['address'] is Map
          ? RestaurantOrderAddress.fromJson(
              Map<String, dynamic>.from(json['address'] as Map),
            )
          : null,

      courierId: _toNullableString(json['courierId']),
      assignedAt: _toDateTime(json['assignedAt']),
      pickedUpAt: _toDateTime(json['pickedUpAt']),
      deliveredAt: _toDateTime(json['deliveredAt']),
      promisedAt: _toDateTime(json['promisedAt']),

      user: json['user'] is Map
          ? RestaurantOrderUser.fromJson(
              Map<String, dynamic>.from(json['user'] as Map),
            )
          : null,
      courier: json['courier'] is Map
          ? RestaurantOrderCourier.fromJson(
              Map<String, dynamic>.from(json['courier'] as Map),
            )
          : null,

      items: rawItems
          .whereType<Map>()
          .map(
            (e) => RestaurantOrderItem.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
      itemsCount: _toInt(json['itemsCount']) ?? rawItems.length,
      createdAt: _toDateTime(json['createdAt']),
    );
  }

  String get normalizedFulfillmentType {
    return (fulfillmentType ?? '').trim().toUpperCase();
  }

  String get normalizedStatus {
    return status.trim().toUpperCase();
  }

  bool get isPickup {
    return normalizedFulfillmentType == 'PICKUP';
  }

  bool get isDelivery {
    // Legacy orders may not have fulfillmentType yet.
    // In that case we keep old behavior and treat them as delivery orders.
    return !isPickup;
  }

  bool get isPickupVerified {
    return pickupCodeVerifiedAt != null;
  }

  bool get isReadyForPickupIssue {
    return isPickup && normalizedStatus == 'READY' && !isPickupVerified;
  }

  bool get isIssuedPickup {
    return isPickup && (isPickupVerified || normalizedStatus == 'DELIVERED');
  }

  bool get hasCourier {
    return courier != null || (courierId ?? '').trim().isNotEmpty;
  }

  bool get hasAddress {
    return address != null || (addressId ?? '').trim().isNotEmpty;
  }

  static List<dynamic> _readItems(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is List) return items;

    final previewItems = json['previewItems'];
    if (previewItems is List) return previewItems;

    return const [];
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;

    return int.tryParse(raw);
  }

  static DateTime? _toDateTime(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty || raw == 'null') return null;
    return DateTime.tryParse(raw);
  }

  static String _toStringOrEmpty(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty || raw == 'null') return '';
    return raw;
  }

  static String _toStringOrDefault(dynamic value, String fallback) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty || raw == 'null') return fallback;
    return raw;
  }

  static String? _toNullableString(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty || raw == 'null') return null;
    return raw;
  }
}

class RestaurantOrderAddress {
  final String? id;
  final String? title;
  final String? address;
  final String? floor;
  final String? door;
  final String? entrance;
  final String? intercom;
  final String? contactPhone;
  final String? comment;

  const RestaurantOrderAddress({
    this.id,
    this.title,
    this.address,
    this.floor,
    this.door,
    this.entrance,
    this.intercom,
    this.contactPhone,
    this.comment,
  });

  factory RestaurantOrderAddress.fromJson(Map<String, dynamic> json) {
    return RestaurantOrderAddress(
      id: RestaurantOrder._toNullableString(json['id']),
      title: RestaurantOrder._toNullableString(json['title']),
      address:
          RestaurantOrder._toNullableString(json['address']) ??
          RestaurantOrder._toNullableString(json['addressText']) ??
          RestaurantOrder._toNullableString(json['fullAddress']),
      floor: RestaurantOrder._toNullableString(json['floor']),
      door:
          RestaurantOrder._toNullableString(json['door']) ??
          RestaurantOrder._toNullableString(json['apartment']),
      entrance: RestaurantOrder._toNullableString(json['entrance']),
      intercom: RestaurantOrder._toNullableString(json['intercom']),
      contactPhone: RestaurantOrder._toNullableString(json['contactPhone']),
      comment: RestaurantOrder._toNullableString(json['comment']),
    );
  }

  String get displayAddress {
    final value = (address ?? '').trim();
    if (value.isNotEmpty) return value;
    return 'Адрес не указан';
  }

  String get detailsLine {
    final parts = <String>[
      if ((entrance ?? '').trim().isNotEmpty) 'подъезд ${entrance!.trim()}',
      if ((floor ?? '').trim().isNotEmpty) 'этаж ${floor!.trim()}',
      if ((door ?? '').trim().isNotEmpty) 'кв. ${door!.trim()}',
      if ((intercom ?? '').trim().isNotEmpty) 'домофон ${intercom!.trim()}',
    ];

    return parts.join(' · ');
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
      id: RestaurantOrder._toStringOrEmpty(json['id']),
      productId: RestaurantOrder._toNullableString(json['productId']),
      title: RestaurantOrder._toStringOrDefault(json['title'], 'Без названия'),
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
      id: RestaurantOrder._toStringOrEmpty(json['id']),
      phone: RestaurantOrder._toNullableString(json['phone']),
      firstName: RestaurantOrder._toNullableString(json['firstName']),
      lastName: RestaurantOrder._toNullableString(json['lastName']),
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
      id: RestaurantOrder._toStringOrEmpty(json['id']),
      firstName: RestaurantOrder._toNullableString(json['firstName']),
      lastName: RestaurantOrder._toNullableString(json['lastName']),
      phone: RestaurantOrder._toNullableString(json['phone']),
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
