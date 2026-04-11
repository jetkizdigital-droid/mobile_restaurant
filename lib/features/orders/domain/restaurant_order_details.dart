// JETKIZ RESTAURANT APP
// Restaurant order details model.
//
// BACKEND CONTRACT:
// GET /orders/:id
//
// Confirmed fields:
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

class RestaurantOrderDetails {
  final String id;
  final int? number;
  final String status;

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
    this.phone,
    this.comment,
    this.paymentMethod,
    this.paymentStatus,
    this.pricingSource,
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

  String? get address => restaurant?.address;

  factory RestaurantOrderDetails.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];

    return RestaurantOrderDetails(
      id: json['id']?.toString() ?? '',
      number: _toInt(json['number']),
      status: json['status']?.toString() ?? 'UNKNOWN',
      subtotal: _toInt(json['subtotal']) ?? 0,
      deliveryFee: _toInt(json['deliveryFee']) ?? 0,
      discountAmount: _toInt(json['discountAmount']) ?? 0,
      deliveryDiscountAmount: _toInt(json['deliveryDiscountAmount']) ?? 0,
      total: _toInt(json['total']) ?? 0,
      phone: json['phone']?.toString(),
      comment: json['comment']?.toString(),
      leaveAtDoor: json['leaveAtDoor'] == true,
      paymentMethod: json['paymentMethod']?.toString(),
      paymentStatus: json['paymentStatus']?.toString(),
      pricingSource: json['pricingSource']?.toString(),
      assignedAt: _toDateTime(json['assignedAt']),
      pickedUpAt: _toDateTime(json['pickedUpAt']),
      deliveredAt: _toDateTime(json['deliveredAt']),
      promisedAt: _toDateTime(json['promisedAt']),
      createdAt: _toDateTime(json['createdAt']),
      updatedAt: _toDateTime(json['updatedAt']),
      user: json['user'] is Map<String, dynamic>
          ? RestaurantOrderDetailsCustomer.fromJson(
              json['user'] as Map<String, dynamic>,
            )
          : null,
      restaurant: json['restaurant'] is Map<String, dynamic>
          ? RestaurantOrderDetailsRestaurant.fromJson(
              json['restaurant'] as Map<String, dynamic>,
            )
          : null,
      courier: json['courier'] is Map<String, dynamic>
          ? RestaurantOrderDetailsCourier.fromJson(
              json['courier'] as Map<String, dynamic>,
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

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _toDateTime(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
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
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString(),
      title: json['title']?.toString() ?? 'Без названия',
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
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString(),
      nameRu: json['nameRu']?.toString(),
      nameKk: json['nameKk']?.toString(),
      coverImageUrl: json['coverImageUrl']?.toString(),
      status: json['status']?.toString(),
      address: json['address']?.toString(),
    );
  }
}