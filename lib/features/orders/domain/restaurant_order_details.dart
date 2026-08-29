// JETKIZ RESTAURANT APP
// Restaurant order details model.
//
// BACKEND CONTRACT:
// GET /orders/:id
//
// Confirmed legacy fields:
// - id
// - number
// - status
// - subtotal
// - deliveryFee
// - discountAmount
// - deliveryDiscountAmount
// - total
// - phone
// - comment
// - leaveAtDoor
// - paymentMethod
// - paymentStatus
// - pricingSource
// - assignedAt
// - pickedUpAt
// - deliveredAt
// - promisedAt
// - createdAt
// - updatedAt
// - user
// - restaurant
// - courier
// - items[]
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
// Missing pickup fields must not crash old DELIVERY orders.

class RestaurantOrderDetails {
  final String id;
  final int? number;
  final String status;

  final String? fulfillmentType;
  final DateTime? pickupCodeVerifiedAt;
  final DateTime? readyAt;

  final int subtotal;
  final int deliveryFee;
  final int discountAmount;
  final int deliveryDiscountAmount;
  final int total;

  final String? phone;
  final String? comment;
  final bool leaveAtDoor;

  final String? paymentMethod;
  final String? paymentStatus;
  final String? pricingSource;

  final String? addressId;
  final RestaurantOrderDetailsAddress? deliveryAddress;
  final String? rawAddressText;

  final String? courierId;
  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? promisedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final RestaurantOrderDetailsCustomer? user;
  final RestaurantOrderDetailsRestaurant? restaurant;
  final RestaurantOrderDetailsCourier? courier;
  final List<RestaurantOrderDetailsItem> items;

  const RestaurantOrderDetails({
    required this.id,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.discountAmount,
    required this.deliveryDiscountAmount,
    required this.total,
    required this.leaveAtDoor,
    required this.items,
    this.number,
    this.fulfillmentType,
    this.pickupCodeVerifiedAt,
    this.readyAt,
    this.phone,
    this.comment,
    this.paymentMethod,
    this.paymentStatus,
    this.pricingSource,
    this.addressId,
    this.deliveryAddress,
    this.rawAddressText,
    this.courierId,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.promisedAt,
    this.createdAt,
    this.updatedAt,
    this.user,
    this.restaurant,
    this.courier,
  });

  int get itemsCount => items.length;

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

  bool get hasDeliveryAddress {
    return (address ?? '').trim().isNotEmpty;
  }

  String? get address {
    final objectAddress = deliveryAddress?.displayAddress.trim();
    if (objectAddress != null &&
        objectAddress.isNotEmpty &&
        objectAddress != 'Адрес не указан') {
      return objectAddress;
    }

    final raw = rawAddressText?.trim();
    if (raw != null && raw.isNotEmpty) {
      return raw;
    }

    return null;
  }

  factory RestaurantOrderDetails.fromJson(Map<String, dynamic> json) {
    final rawItems = _readItems(json);
    final addressValue = json['address'];

    return RestaurantOrderDetails(
      id: _toStringOrEmpty(json['id']),
      number: _toInt(json['number']),
      status: _toStringOrDefault(json['status'], 'UNKNOWN'),

      fulfillmentType: _toNullableString(json['fulfillmentType']),
      pickupCodeVerifiedAt: _toDateTime(json['pickupCodeVerifiedAt']),
      readyAt: _toDateTime(json['readyAt']),

      subtotal: _toInt(json['subtotal']) ?? 0,
      deliveryFee: _toInt(json['deliveryFee']) ?? 0,
      discountAmount: _toInt(json['discountAmount']) ?? 0,
      deliveryDiscountAmount: _toInt(json['deliveryDiscountAmount']) ?? 0,
      total: _toInt(json['total']) ?? 0,

      phone: _toNullableString(json['phone']),
      comment: _toNullableString(json['comment']),
      leaveAtDoor: json['leaveAtDoor'] == true,

      paymentMethod: _toNullableString(json['paymentMethod']),
      paymentStatus: _toNullableString(json['paymentStatus']),
      pricingSource: _toNullableString(json['pricingSource']),

      addressId: _toNullableString(json['addressId']),
      deliveryAddress: addressValue is Map
          ? RestaurantOrderDetailsAddress.fromJson(
              Map<String, dynamic>.from(addressValue),
            )
          : null,
      rawAddressText: addressValue is String ? _toNullableString(addressValue) : null,

      courierId: _toNullableString(json['courierId']),
      assignedAt: _toDateTime(json['assignedAt']),
      pickedUpAt: _toDateTime(json['pickedUpAt']),
      deliveredAt: _toDateTime(json['deliveredAt']),
      promisedAt: _toDateTime(json['promisedAt']),
      createdAt: _toDateTime(json['createdAt']),
      updatedAt: _toDateTime(json['updatedAt']),

      user: json['user'] is Map
          ? RestaurantOrderDetailsCustomer.fromJson(
              Map<String, dynamic>.from(json['user'] as Map),
            )
          : null,
      restaurant: json['restaurant'] is Map
          ? RestaurantOrderDetailsRestaurant.fromJson(
              Map<String, dynamic>.from(json['restaurant'] as Map),
            )
          : null,
      courier: json['courier'] is Map
          ? RestaurantOrderDetailsCourier.fromJson(
              Map<String, dynamic>.from(json['courier'] as Map),
            )
          : null,
      items: rawItems
          .whereType<Map>()
          .map(
            (e) => RestaurantOrderDetailsItem.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
    );
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
    if (raw == null || raw.isEmpty || raw == 'null') return null;

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

class RestaurantOrderDetailsAddress {
  final String? id;
  final String? title;
  final String? address;
  final String? floor;
  final String? door;
  final String? entrance;
  final String? intercom;
  final String? contactPhone;
  final String? comment;

  const RestaurantOrderDetailsAddress({
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

  factory RestaurantOrderDetailsAddress.fromJson(Map<String, dynamic> json) {
    return RestaurantOrderDetailsAddress(
      id: RestaurantOrderDetails._toNullableString(json['id']),
      title: RestaurantOrderDetails._toNullableString(json['title']),
      address: RestaurantOrderDetails._toNullableString(json['address']) ??
          RestaurantOrderDetails._toNullableString(json['addressText']) ??
          RestaurantOrderDetails._toNullableString(json['fullAddress']),
      floor: RestaurantOrderDetails._toNullableString(json['floor']),
      door: RestaurantOrderDetails._toNullableString(json['door']) ??
          RestaurantOrderDetails._toNullableString(json['apartment']),
      entrance: RestaurantOrderDetails._toNullableString(json['entrance']),
      intercom: RestaurantOrderDetails._toNullableString(json['intercom']),
      contactPhone: RestaurantOrderDetails._toNullableString(json['contactPhone']),
      comment: RestaurantOrderDetails._toNullableString(json['comment']),
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

class RestaurantOrderDetailsItem {
  final String id;
  final String? productId;
  final String title;
  final int price;
  final int quantity;

  const RestaurantOrderDetailsItem({
    required this.id,
    required this.title,
    required this.price,
    required this.quantity,
    this.productId,
  });

  factory RestaurantOrderDetailsItem.fromJson(Map<String, dynamic> json) {
    return RestaurantOrderDetailsItem(
      id: RestaurantOrderDetails._toStringOrEmpty(json['id']),
      productId: RestaurantOrderDetails._toNullableString(json['productId']),
      title: RestaurantOrderDetails._toStringOrDefault(
        json['title'],
        'Без названия',
      ),
      price: RestaurantOrderDetails._toInt(json['price']) ?? 0,
      quantity: RestaurantOrderDetails._toInt(json['quantity']) ?? 0,
    );
  }
}

class RestaurantOrderDetailsCustomer {
  final String id;
  final String? phone;
  final String? firstName;
  final String? lastName;

  const RestaurantOrderDetailsCustomer({
    required this.id,
    this.phone,
    this.firstName,
    this.lastName,
  });

  factory RestaurantOrderDetailsCustomer.fromJson(Map<String, dynamic> json) {
    return RestaurantOrderDetailsCustomer(
      id: RestaurantOrderDetails._toStringOrEmpty(json['id']),
      phone: RestaurantOrderDetails._toNullableString(json['phone']),
      firstName: RestaurantOrderDetails._toNullableString(json['firstName']),
      lastName: RestaurantOrderDetails._toNullableString(json['lastName']),
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

class RestaurantOrderDetailsCourier {
  final String id;
  final String? phone;
  final String? firstName;
  final String? lastName;

  const RestaurantOrderDetailsCourier({
    required this.id,
    this.phone,
    this.firstName,
    this.lastName,
  });

  factory RestaurantOrderDetailsCourier.fromJson(Map<String, dynamic> json) {
    return RestaurantOrderDetailsCourier(
      id: RestaurantOrderDetails._toStringOrEmpty(json['id']),
      phone: RestaurantOrderDetails._toNullableString(json['phone']),
      firstName: RestaurantOrderDetails._toNullableString(json['firstName']),
      lastName: RestaurantOrderDetails._toNullableString(json['lastName']),
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

class RestaurantOrderDetailsRestaurant {
  final String id;
  final String? slug;
  final String? nameRu;
  final String? nameKk;
  final String? coverImageUrl;
  final String? status;
  final String? address;

  const RestaurantOrderDetailsRestaurant({
    required this.id,
    this.slug,
    this.nameRu,
    this.nameKk,
    this.coverImageUrl,
    this.status,
    this.address,
  });

  factory RestaurantOrderDetailsRestaurant.fromJson(
    Map<String, dynamic> json,
  ) {
    return RestaurantOrderDetailsRestaurant(
      id: RestaurantOrderDetails._toStringOrEmpty(json['id']),
      slug: RestaurantOrderDetails._toNullableString(json['slug']),
      nameRu: RestaurantOrderDetails._toNullableString(json['nameRu']),
      nameKk: RestaurantOrderDetails._toNullableString(json['nameKk']),
      coverImageUrl: RestaurantOrderDetails._toNullableString(
        json['coverImageUrl'],
      ),
      status: RestaurantOrderDetails._toNullableString(json['status']),
      address: RestaurantOrderDetails._toNullableString(json['address']),
    );
  }

  String get displayName {
    final ru = (nameRu ?? '').trim();
    if (ru.isNotEmpty) return ru;

    final kk = (nameKk ?? '').trim();
    if (kk.isNotEmpty) return kk;

    return 'Ресторан';
  }
}