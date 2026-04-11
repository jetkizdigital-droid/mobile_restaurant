class RestaurantProfileData {
  final String id;
  final String nameRu;
  final String? nameKk;
  final String? phone;
  final String? address;
  final String? workingHours;
  final String? coverImageUrl;
  final String? status;
  final bool? isInApp;
  final bool? isPinned;
  final int? sortOrder;
  final num? effectiveRestaurantCommissionPct;

  const RestaurantProfileData({
    required this.id,
    required this.nameRu,
    this.nameKk,
    this.phone,
    this.address,
    this.workingHours,
    this.coverImageUrl,
    this.status,
    this.isInApp,
    this.isPinned,
    this.sortOrder,
    this.effectiveRestaurantCommissionPct,
  });

  factory RestaurantProfileData.fromJson(Map<String, dynamic> json) {
    return RestaurantProfileData(
      id: json['id']?.toString() ?? '',
      nameRu: json['nameRu']?.toString() ?? '',
      nameKk: json['nameKk']?.toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      workingHours: json['workingHours']?.toString(),
      coverImageUrl: json['coverImageUrl']?.toString(),
      status: json['status']?.toString(),
      isInApp: json['isInApp'] as bool?,
      isPinned: json['isPinned'] as bool?,
      sortOrder: json['sortOrder'] as int?,
      effectiveRestaurantCommissionPct: json['effectiveRestaurantCommissionPct'] as num?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nameRu': nameRu,
      'nameKk': nameKk,
      'phone': phone,
      'address': address,
      'workingHours': workingHours,
      'coverImageUrl': coverImageUrl,
      'status': status,
      'isInApp': isInApp,
      'isPinned': isPinned,
      'sortOrder': sortOrder,
      'effectiveRestaurantCommissionPct': effectiveRestaurantCommissionPct,
    };
  }
}