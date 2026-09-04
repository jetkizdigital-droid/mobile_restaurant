class RestaurantMetricsData {
  final RestaurantMetricsRestaurant? restaurant;
  final RestaurantMetricsPeriod period;
  final RestaurantMetricsOverview overview;
  final List<RestaurantDailyMetric> daily;
  final RestaurantCustomerStats customers;
  final RestaurantReviewStats reviews;
  final RestaurantTrendStats trends;
  final List<RestaurantRecentOrderMetric> recentOrders;
  final List<RestaurantTopClientMetric> topClients;
  final Map<String, int> rfmDistribution;
  final List<RestaurantSuggestion> suggestions;

  const RestaurantMetricsData({
    required this.restaurant,
    required this.period,
    required this.overview,
    required this.daily,
    required this.customers,
    required this.reviews,
    required this.trends,
    required this.recentOrders,
    required this.topClients,
    required this.rfmDistribution,
    required this.suggestions,
  });

  factory RestaurantMetricsData.fromJson(Map<String, dynamic> json) {
    final revenue = _asMap(json['revenue']) ?? const <String, dynamic>{};
    final rates = _asMap(json['rates']) ?? const <String, dynamic>{};
    final customers = _asMap(json['customers']) ?? const <String, dynamic>{};
    final reviews = _asMap(json['reviews']) ?? const <String, dynamic>{};

    return RestaurantMetricsData(
      restaurant: _asMap(json['restaurant']) == null
          ? null
          : RestaurantMetricsRestaurant.fromJson(
              _asMap(json['restaurant']) ?? const <String, dynamic>{},
            ),
      period: RestaurantMetricsPeriod.fromJson(
        _asMap(json['period']) ?? const <String, dynamic>{},
      ),
      overview: RestaurantMetricsOverview.fromJson(<String, dynamic>{
        ...json,
        ...revenue,
        ...rates,
      }),
      daily: _asList(json['daily'])
          .map((e) => RestaurantDailyMetric.fromJson(_asMap(e) ?? const {}))
          .toList(),
      customers: RestaurantCustomerStats.fromJson(customers),
      reviews: RestaurantReviewStats.fromJson(reviews),
      trends: RestaurantTrendStats.fromJson(json),
      recentOrders: _asList(json['recentOrders'])
          .map(
            (e) => RestaurantRecentOrderMetric.fromJson(
              _asMap(e) ?? const <String, dynamic>{},
            ),
          )
          .toList(),
      topClients: _asList(json['topClients'])
          .map(
            (e) => RestaurantTopClientMetric.fromJson(
              _asMap(e) ?? const <String, dynamic>{},
            ),
          )
          .toList(),
      rfmDistribution: _parseStringIntMap(customers['rfmDistribution']),
      suggestions: _asList(json['suggestions'])
          .map(
            (e) => RestaurantSuggestion.fromJson(
              _asMap(e) ?? const <String, dynamic>{},
            ),
          )
          .toList(),
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<dynamic> _asList(dynamic value) {
    return value is List ? value : const <dynamic>[];
  }

  static Map<String, int> _parseStringIntMap(dynamic value) {
    if (value is! Map) return const <String, int>{};

    final result = <String, int>{};
    value.forEach((key, val) {
      result[key.toString()] = _toInt(val);
    });
    return result;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _toDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static String? _toNullableString(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }
}

class RestaurantMetricsRestaurant {
  final String id;
  final String? slug;
  final String? nameRu;
  final String? nameKk;
  final String? status;

  const RestaurantMetricsRestaurant({
    required this.id,
    required this.slug,
    required this.nameRu,
    required this.nameKk,
    required this.status,
  });

  factory RestaurantMetricsRestaurant.fromJson(Map<String, dynamic> json) {
    return RestaurantMetricsRestaurant(
      id: json['id']?.toString() ?? '',
      slug: RestaurantMetricsData._toNullableString(json['slug']),
      nameRu: RestaurantMetricsData._toNullableString(json['nameRu']),
      nameKk: RestaurantMetricsData._toNullableString(json['nameKk']),
      status: RestaurantMetricsData._toNullableString(json['status']),
    );
  }
}

class RestaurantMetricsPeriod {
  final String? from;
  final String? to;
  final int days;

  const RestaurantMetricsPeriod({
    required this.from,
    required this.to,
    required this.days,
  });

  factory RestaurantMetricsPeriod.fromJson(Map<String, dynamic> json) {
    return RestaurantMetricsPeriod(
      from: json['from']?.toString(),
      to: json['to']?.toString(),
      days: RestaurantMetricsData._toInt(json['days']),
    );
  }
}

class RestaurantMetricsOverview {
  final int totalOrders;
  final int deliveredCount;
  final int canceledCount;
  final int paidCount;
  final int totalRevenue;
  final int avgCheckRevenue;
  final int totalPaid;
  final int totalDelivered;
  final int cancelRatePercent;
  final int paidRatePercent;
  final int deliveredRatePercent;

  const RestaurantMetricsOverview({
    required this.totalOrders,
    required this.deliveredCount,
    required this.canceledCount,
    required this.paidCount,
    required this.totalRevenue,
    required this.avgCheckRevenue,
    required this.totalPaid,
    required this.totalDelivered,
    required this.cancelRatePercent,
    required this.paidRatePercent,
    required this.deliveredRatePercent,
  });

  factory RestaurantMetricsOverview.fromJson(Map<String, dynamic> json) {
    return RestaurantMetricsOverview(
      totalOrders: RestaurantMetricsData._toInt(json['totalOrders']),
      deliveredCount: RestaurantMetricsData._toInt(json['deliveredCount']),
      canceledCount: RestaurantMetricsData._toInt(json['canceledCount']),
      paidCount: RestaurantMetricsData._toInt(json['paidCount']),
      totalRevenue: RestaurantMetricsData._toInt(json['totalRevenue']),
      avgCheckRevenue: RestaurantMetricsData._toInt(json['avgCheckRevenue']),
      totalPaid: RestaurantMetricsData._toInt(json['totalPaid']),
      totalDelivered: RestaurantMetricsData._toInt(json['totalDelivered']),
      cancelRatePercent: RestaurantMetricsData._toInt(
        json['cancelRatePercent'],
      ),
      paidRatePercent: RestaurantMetricsData._toInt(json['paidRatePercent']),
      deliveredRatePercent: RestaurantMetricsData._toInt(
        json['deliveredRatePercent'],
      ),
    );
  }
}

class RestaurantDailyMetric {
  final String date;
  final int orders;
  final int delivered;
  final int canceled;
  final int paid;
  final int revenue;

  const RestaurantDailyMetric({
    required this.date,
    required this.orders,
    required this.delivered,
    required this.canceled,
    required this.paid,
    required this.revenue,
  });

  factory RestaurantDailyMetric.fromJson(Map<String, dynamic> json) {
    return RestaurantDailyMetric(
      date: json['date']?.toString() ?? '',
      orders: RestaurantMetricsData._toInt(json['orders']),
      delivered: RestaurantMetricsData._toInt(json['delivered']),
      canceled: RestaurantMetricsData._toInt(json['canceled']),
      paid: RestaurantMetricsData._toInt(json['paid']),
      revenue: RestaurantMetricsData._toInt(json['revenue']),
    );
  }

  DateTime? get parsedDate => RestaurantMetricsData._toDate(date);
}

class RestaurantCustomerStats {
  final int activeCustomers;
  final int activeCustomersLast7;
  final int activeCustomersLast30;
  final int newCustomers;
  final int repeatRatePercent;

  const RestaurantCustomerStats({
    required this.activeCustomers,
    required this.activeCustomersLast7,
    required this.activeCustomersLast30,
    required this.newCustomers,
    required this.repeatRatePercent,
  });

  factory RestaurantCustomerStats.fromJson(Map<String, dynamic> json) {
    return RestaurantCustomerStats(
      activeCustomers: RestaurantMetricsData._toInt(json['activeCustomers']),
      activeCustomersLast7: RestaurantMetricsData._toInt(
        json['activeCustomersLast7'] ?? json['activeCustomers7d'],
      ),
      activeCustomersLast30: RestaurantMetricsData._toInt(
        json['activeCustomersLast30'] ?? json['activeCustomers30d'],
      ),
      newCustomers: RestaurantMetricsData._toInt(json['newCustomers']),
      repeatRatePercent: RestaurantMetricsData._toInt(
        json['repeatRatePercent'] ?? json['repeatCustomers'],
      ),
    );
  }
}

class RestaurantReviewStats {
  final int reviewsCount;
  final double averageRating;
  final int reviewRatePercent;

  const RestaurantReviewStats({
    required this.reviewsCount,
    required this.averageRating,
    required this.reviewRatePercent,
  });

  factory RestaurantReviewStats.fromJson(Map<String, dynamic> json) {
    return RestaurantReviewStats(
      reviewsCount: RestaurantMetricsData._toInt(json['reviewsCount']),
      averageRating: RestaurantMetricsData._toDouble(
        json['averageRating'] ?? json['ratingAvg'],
      ),
      reviewRatePercent: RestaurantMetricsData._toInt(
        json['reviewRatePercent'],
      ),
    );
  }
}

class RestaurantTrendStats {
  final double? trendRevenuePercent;
  final double? trendOrdersPercent;

  const RestaurantTrendStats({
    required this.trendRevenuePercent,
    required this.trendOrdersPercent,
  });

  factory RestaurantTrendStats.fromJson(Map<String, dynamic> json) {
    return RestaurantTrendStats(
      trendRevenuePercent: json['trendRevenuePercent'] == null
          ? null
          : RestaurantMetricsData._toDouble(json['trendRevenuePercent']),
      trendOrdersPercent: json['trendOrdersPercent'] == null
          ? null
          : RestaurantMetricsData._toDouble(json['trendOrdersPercent']),
    );
  }
}

class RestaurantRecentOrderMetric {
  final String id;
  final String? phone;
  final String? customerName;
  final String? status;
  final String? paymentStatus;
  final String? paymentMethod;
  final String? userId;
  final int total;
  final int payout;
  final DateTime? createdAt;
  final DateTime? deliveredAt;

  const RestaurantRecentOrderMetric({
    required this.id,
    required this.phone,
    required this.customerName,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.userId,
    required this.total,
    required this.payout,
    required this.createdAt,
    required this.deliveredAt,
  });

  factory RestaurantRecentOrderMetric.fromJson(Map<String, dynamic> json) {
    return RestaurantRecentOrderMetric(
      id: json['id']?.toString() ?? '',
      phone: RestaurantMetricsData._toNullableString(
        json['phone'] ?? json['userPhone'],
      ),
      customerName: RestaurantMetricsData._toNullableString(
        json['customerName'] ?? json['userName'],
      ),
      status: RestaurantMetricsData._toNullableString(json['status']),
      paymentStatus: RestaurantMetricsData._toNullableString(
        json['paymentStatus'],
      ),
      paymentMethod: RestaurantMetricsData._toNullableString(
        json['paymentMethod'],
      ),
      userId: RestaurantMetricsData._toNullableString(json['userId']),
      total: RestaurantMetricsData._toInt(json['total']),
      payout: RestaurantMetricsData._toInt(
        json['payout'] ?? json['restaurantPayoutAmount'],
      ),
      createdAt: RestaurantMetricsData._toDate(json['createdAt']),
      deliveredAt: RestaurantMetricsData._toDate(json['deliveredAt']),
    );
  }
}

class RestaurantTopClientMetric {
  final String userId;
  final String? phone;
  final String? name;
  final int ordersCount;
  final int spent;
  final DateTime? lastOrderAt;
  final int? recencyDays;
  final String status;

  const RestaurantTopClientMetric({
    required this.userId,
    required this.phone,
    required this.name,
    required this.ordersCount,
    required this.spent,
    required this.lastOrderAt,
    required this.recencyDays,
    required this.status,
  });

  factory RestaurantTopClientMetric.fromJson(Map<String, dynamic> json) {
    return RestaurantTopClientMetric(
      userId: json['userId']?.toString() ?? '',
      phone: json['phone']?.toString(),
      name: json['name']?.toString(),
      ordersCount: RestaurantMetricsData._toInt(json['ordersCount']),
      spent: RestaurantMetricsData._toInt(json['spent']),
      lastOrderAt: RestaurantMetricsData._toDate(json['lastOrderAt']),
      recencyDays: json['recencyDays'] == null
          ? null
          : RestaurantMetricsData._toInt(json['recencyDays']),
      status: json['status']?.toString() ?? 'Неизвестно',
    );
  }
}

class RestaurantSuggestion {
  final String type;
  final String title;
  final String text;

  const RestaurantSuggestion({
    required this.type,
    required this.title,
    required this.text,
  });

  bool get isWarning => type == 'warning';
  bool get isInfo => type == 'info';
  bool get isSuccess => type == 'success';

  factory RestaurantSuggestion.fromJson(Map<String, dynamic> json) {
    return RestaurantSuggestion(
      type: json['type']?.toString() ?? 'info',
      title: json['title']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
    );
  }
}
