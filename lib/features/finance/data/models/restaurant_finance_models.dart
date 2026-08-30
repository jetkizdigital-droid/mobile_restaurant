class RestaurantFinanceResponse {
  const RestaurantFinanceResponse({
    required this.restaurant,
    required this.period,
    required this.summary,
    required this.allTime,
    required this.payouts,
    required this.recentDeliveredOrders,
  });

  final RestaurantFinanceRestaurant restaurant;
  final RestaurantFinancePeriod period;
  final RestaurantFinanceSummary summary;
  final RestaurantFinanceAllTime allTime;
  final RestaurantFinancePayouts payouts;
  final List<RestaurantFinanceOrder> recentDeliveredOrders;

  factory RestaurantFinanceResponse.fromJson(Map<String, dynamic> json) {
    return RestaurantFinanceResponse(
      restaurant: RestaurantFinanceRestaurant.fromJson(
        _asMap(json['restaurant']) ?? const <String, dynamic>{},
      ),
      period: RestaurantFinancePeriod.fromJson(
        _asMap(json['period']) ?? const <String, dynamic>{},
      ),
      summary: RestaurantFinanceSummary.fromJson(
        _asMap(json['summary']) ?? const <String, dynamic>{},
      ),
      allTime: RestaurantFinanceAllTime.fromJson(
        _asMap(json['allTime']) ?? const <String, dynamic>{},
      ),
      payouts: RestaurantFinancePayouts.fromJson(
        _asMap(json['payouts']) ?? const <String, dynamic>{},
      ),
      recentDeliveredOrders: _asList(json['recentDeliveredOrders'])
          .map(
            (e) => RestaurantFinanceOrder.fromJson(
              _asMap(e) ?? const <String, dynamic>{},
            ),
          )
          .toList(),
    );
  }

  double get availableToWithdraw => payouts.pendingPayoutAmount;
  double get paidAmount => payouts.paidPayoutAmount;
  double get assignedButUnpaidAmount => payouts.unpaidButAssignedAmount;
  double get grossRevenue => summary.grossTotal;
  double get commissionAmount => summary.commissionAmount;
  double get payoutAmount => summary.payoutAmount;
  int get deliveredOrdersCount => summary.deliveredOrdersCount;
}

class RestaurantFinanceRestaurant {
  const RestaurantFinanceRestaurant({
    required this.id,
    required this.slug,
    required this.nameRu,
    required this.nameKk,
    required this.number,
    required this.status,
    this.individualRestaurantCommissionPctOverride,
    this.effectiveRestaurantCommissionPct,
  });

  final String id;
  final String slug;
  final String nameRu;
  final String nameKk;
  final int number;
  final String status;
  final int? individualRestaurantCommissionPctOverride;
  final int? effectiveRestaurantCommissionPct;

  factory RestaurantFinanceRestaurant.fromJson(Map<String, dynamic> json) {
    return RestaurantFinanceRestaurant(
      id: _toStringValue(json['id']),
      slug: _toStringValue(json['slug']),
      nameRu: _toStringValue(json['nameRu']),
      nameKk: _toStringValue(json['nameKk']),
      number: _toInt(json['number']),
      status: _toStringValue(json['status']),
      individualRestaurantCommissionPctOverride: _toNullableInt(
        json['restaurantCommissionPctOverride'],
      ),
      effectiveRestaurantCommissionPct: _toNullableInt(
        json['effectiveRestaurantCommissionPct'],
      ),
    );
  }

  String get displayName {
    final ru = nameRu.trim();
    if (ru.isNotEmpty) return ru;
    return nameKk.trim();
  }

  bool get hasIndividualCommission =>
      individualRestaurantCommissionPctOverride != null;

  // Backward-compatible UI accessor. Existing finance widgets use this field
  // as the rate to display, so return the effective rate while preserving the
  // raw override separately for the "individual/general" label.
  int? get restaurantCommissionPctOverride =>
      effectiveRestaurantCommissionPct ??
      individualRestaurantCommissionPctOverride;
}

class RestaurantFinancePeriod {
  const RestaurantFinancePeriod({
    required this.key,
    required this.start,
    required this.end,
    required this.cutoffHour,
  });

  final String key;
  final DateTime? start;
  final DateTime? end;
  final int cutoffHour;

  factory RestaurantFinancePeriod.fromJson(Map<String, dynamic> json) {
    return RestaurantFinancePeriod(
      key: _toStringValue(json['key']),
      start: _toDateTime(json['start']),
      end: _toDateTime(json['end']),
      cutoffHour: _toInt(json['cutoffHour']),
    );
  }
}

class RestaurantFinanceSummary {
  const RestaurantFinanceSummary({
    required this.deliveredOrdersCount,
    required this.subtotal,
    required this.deliveryFee,
    required this.discountAmount,
    required this.deliveryDiscountAmount,
    required this.grossTotal,
    required this.commissionAmount,
    required this.payoutAmount,
    required this.averagePayoutPerOrder,
    required this.averageGrossOrderValue,
  });

  final int deliveredOrdersCount;
  final double subtotal;
  final double deliveryFee;
  final double discountAmount;
  final double deliveryDiscountAmount;
  final double grossTotal;
  final double commissionAmount;
  final double payoutAmount;
  final double averagePayoutPerOrder;
  final double averageGrossOrderValue;

  factory RestaurantFinanceSummary.fromJson(Map<String, dynamic> json) {
    return RestaurantFinanceSummary(
      deliveredOrdersCount: _toInt(json['deliveredOrdersCount']),
      subtotal: _toDouble(json['subtotal']),
      deliveryFee: _toDouble(json['deliveryFee']),
      discountAmount: _toDouble(json['discountAmount']),
      deliveryDiscountAmount: _toDouble(json['deliveryDiscountAmount']),
      grossTotal: _toDouble(json['grossTotal'] ?? json['subtotal']),
      commissionAmount: _toDouble(json['commissionAmount']),
      payoutAmount: _toDouble(json['payoutAmount']),
      averagePayoutPerOrder: _toDouble(json['averagePayoutPerOrder']),
      averageGrossOrderValue: _toDouble(
        json['averageGrossOrderValue'] ?? json['averageFoodSubtotalPerOrder'],
      ),
    );
  }
}

class RestaurantFinanceAllTime {
  const RestaurantFinanceAllTime({
    required this.deliveredOrdersCount,
    required this.subtotal,
    required this.grossTotal,
    required this.commissionAmount,
    required this.payoutAmount,
  });

  final int deliveredOrdersCount;
  final double subtotal;
  final double grossTotal;
  final double commissionAmount;
  final double payoutAmount;

  factory RestaurantFinanceAllTime.fromJson(Map<String, dynamic> json) {
    return RestaurantFinanceAllTime(
      deliveredOrdersCount: _toInt(json['deliveredOrdersCount']),
      subtotal: _toDouble(json['subtotal']),
      grossTotal: _toDouble(json['grossTotal'] ?? json['subtotal']),
      commissionAmount: _toDouble(json['commissionAmount']),
      payoutAmount: _toDouble(json['payoutAmount']),
    );
  }
}

class RestaurantFinancePayouts {
  const RestaurantFinancePayouts({
    required this.assignedPayoutAmount,
    required this.paidPayoutAmount,
    required this.unpaidButAssignedAmount,
    required this.pendingPayoutAmount,
    required this.rows,
  });

  final double assignedPayoutAmount;
  final double paidPayoutAmount;
  final double unpaidButAssignedAmount;
  final double pendingPayoutAmount;
  final List<RestaurantFinancePayoutRow> rows;

  factory RestaurantFinancePayouts.fromJson(Map<String, dynamic> json) {
    return RestaurantFinancePayouts(
      assignedPayoutAmount: _toDouble(json['assignedPayoutAmount']),
      paidPayoutAmount: _toDouble(json['paidPayoutAmount']),
      unpaidButAssignedAmount: _toDouble(json['unpaidButAssignedAmount']),
      pendingPayoutAmount: _toDouble(json['pendingPayoutAmount']),
      rows: _asList(json['rows'])
          .map(
            (e) => RestaurantFinancePayoutRow.fromJson(
              _asMap(e) ?? const <String, dynamic>{},
            ),
          )
          .toList(),
    );
  }

  bool get hasRows => rows.isNotEmpty;
}

class RestaurantFinancePayoutRow {
  const RestaurantFinancePayoutRow({
    required this.id,
    required this.periodFrom,
    required this.periodTo,
    required this.ordersCount,
    required this.grossSubtotal,
    required this.commissionAmount,
    required this.payoutAmount,
    required this.status,
    required this.paidAt,
    required this.note,
    required this.paymentReference,
    required this.paymentComment,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final DateTime? periodFrom;
  final DateTime? periodTo;
  final int ordersCount;
  final double grossSubtotal;
  final double commissionAmount;
  final double payoutAmount;
  final String status;
  final DateTime? paidAt;
  final String? note;
  final String? paymentReference;
  final String? paymentComment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RestaurantFinancePayoutRow.fromJson(Map<String, dynamic> json) {
    return RestaurantFinancePayoutRow(
      id: _toStringValue(json['id']),
      periodFrom: _toDateTime(json['periodFrom']),
      periodTo: _toDateTime(json['periodTo']),
      ordersCount: _toInt(json['ordersCount']),
      grossSubtotal: _toDouble(json['grossSubtotal']),
      commissionAmount: _toDouble(json['commissionAmount']),
      payoutAmount: _toDouble(json['payoutAmount']),
      status: _toStringValue(json['status']),
      paidAt: _toDateTime(json['paidAt']),
      note: _toNullableString(json['note']),
      paymentReference: _toNullableString(json['paymentReference']),
      paymentComment: _toNullableString(json['paymentComment']),
      createdAt: _toDateTime(json['createdAt']),
      updatedAt: _toDateTime(json['updatedAt']),
    );
  }

  bool get isPaid => status.toUpperCase() == 'PAID';
}

class RestaurantFinanceOrder {
  const RestaurantFinanceOrder({
    required this.id,
    required this.number,
    required this.subtotal,
    required this.deliveryFee,
    required this.discountAmount,
    required this.deliveryDiscountAmount,
    required this.total,
    required this.paymentStatus,
    required this.restaurantCommissionPctApplied,
    required this.restaurantCommissionAmount,
    required this.restaurantPayoutAmount,
    required this.deliveredAt,
    required this.createdAt,
    required this.restaurantPayoutId,
    required this.user,
    required this.itemsCount,
    required this.previewItems,
    required this.items,
  });

  final String id;
  final int number;
  final double subtotal;
  final double deliveryFee;
  final double discountAmount;
  final double deliveryDiscountAmount;
  final double total;
  final String paymentStatus;
  final double restaurantCommissionPctApplied;
  final double restaurantCommissionAmount;
  final double restaurantPayoutAmount;
  final DateTime? deliveredAt;
  final DateTime? createdAt;
  final String? restaurantPayoutId;
  final RestaurantFinanceOrderUser? user;
  final int itemsCount;
  final List<RestaurantFinanceOrderItem> previewItems;
  final List<RestaurantFinanceOrderItem> items;

  factory RestaurantFinanceOrder.fromJson(Map<String, dynamic> json) {
    return RestaurantFinanceOrder(
      id: _toStringValue(json['id']),
      number: _toInt(json['number']),
      subtotal: _toDouble(json['subtotal']),
      deliveryFee: _toDouble(json['deliveryFee']),
      discountAmount: _toDouble(json['discountAmount']),
      deliveryDiscountAmount: _toDouble(json['deliveryDiscountAmount']),
      total: _toDouble(json['total']),
      paymentStatus: _toStringValue(json['paymentStatus']),
      restaurantCommissionPctApplied: _toDouble(
        json['restaurantCommissionPctApplied'],
      ),
      restaurantCommissionAmount: _toDouble(
        json['restaurantCommissionAmount'],
      ),
      restaurantPayoutAmount: _toDouble(json['restaurantPayoutAmount']),
      deliveredAt: _toDateTime(json['deliveredAt']),
      createdAt: _toDateTime(json['createdAt']),
      restaurantPayoutId: _toNullableString(json['restaurantPayoutId']),
      user: _asMap(json['user']) == null
          ? null
          : RestaurantFinanceOrderUser.fromJson(
              _asMap(json['user']) ?? const <String, dynamic>{},
            ),
      itemsCount: _toInt(json['itemsCount']),
      previewItems: _asList(json['previewItems'])
          .map(
            (e) => RestaurantFinanceOrderItem.fromJson(
              _asMap(e) ?? const <String, dynamic>{},
            ),
          )
          .toList(),
      items: _asList(json['items'])
          .map(
            (e) => RestaurantFinanceOrderItem.fromJson(
              _asMap(e) ?? const <String, dynamic>{},
            ),
          )
          .toList(),
    );
  }

  bool get isAssignedToPayout => restaurantPayoutId != null;
}

class RestaurantFinanceOrderUser {
  const RestaurantFinanceOrderUser({
    required this.id,
    required this.phone,
    required this.firstName,
    required this.lastName,
  });

  final String id;
  final String phone;
  final String? firstName;
  final String? lastName;

  factory RestaurantFinanceOrderUser.fromJson(Map<String, dynamic> json) {
    return RestaurantFinanceOrderUser(
      id: _toStringValue(json['id']),
      phone: _toStringValue(json['phone']),
      firstName: _toNullableString(json['firstName']),
      lastName: _toNullableString(json['lastName']),
    );
  }

  String get displayName {
    final first = (firstName ?? '').trim();
    final last = (lastName ?? '').trim();
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    return phone;
  }
}

class RestaurantFinanceOrderItem {
  const RestaurantFinanceOrderItem({
    required this.id,
    required this.productId,
    required this.title,
    required this.price,
    required this.quantity,
  });

  final String id;
  final String productId;
  final String title;
  final double price;
  final int quantity;

  factory RestaurantFinanceOrderItem.fromJson(Map<String, dynamic> json) {
    return RestaurantFinanceOrderItem(
      id: _toStringValue(json['id']),
      productId: _toStringValue(json['productId']),
      title: _toStringValue(json['title']),
      price: _toDouble(json['price']),
      quantity: _toInt(json['quantity']),
    );
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<dynamic> _asList(dynamic value) {
  return value is List ? value : const <dynamic>[];
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _toNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString());
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _toStringValue(dynamic value, {String fallback = ''}) {
  final raw = value?.toString();
  if (raw == null) return fallback;
  return raw;
}

String? _toNullableString(dynamic value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  return raw;
}

DateTime? _toDateTime(dynamic value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
