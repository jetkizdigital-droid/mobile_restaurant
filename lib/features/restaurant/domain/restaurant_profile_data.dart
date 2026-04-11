class RestaurantProfileData {
  final String id;
  final String nameRu;
  final String? nameKk;
  final String? phone;
  final String? address;

  // New backend fields
  final String? workingHours;
  final String? coverImageUrl;
  final String? status;
  final bool? isInApp;
  final bool? isPinned;
  final int? sortOrder;
  final num? effectiveRestaurantCommissionPct;

  // Legacy compatibility fields
  final String? imageUrl;
  final String? localImagePath;
  final List<String>? workDays;
  final String? workingHoursFrom;
  final String? workingHoursTo;
  final int? imageVersion;

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
    this.imageUrl,
    this.localImagePath,
    this.workDays,
    this.workingHoursFrom,
    this.workingHoursTo,
    this.imageVersion,
  });

  factory RestaurantProfileData.fromJson(Map<String, dynamic> json) {
    return RestaurantProfileData(
      id: json['id']?.toString() ?? '',
      nameRu: json['nameRu']?.toString() ?? '',
      nameKk: json['nameKk']?.toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),

      // New backend contract
      workingHours: json['workingHours']?.toString(),
      coverImageUrl: json['coverImageUrl']?.toString(),
      status: json['status']?.toString(),
      isInApp: json['isInApp'] as bool?,
      isPinned: json['isPinned'] as bool?,
      sortOrder: json['sortOrder'] is int
          ? json['sortOrder'] as int
          : int.tryParse(json['sortOrder']?.toString() ?? ''),
      effectiveRestaurantCommissionPct:
          json['effectiveRestaurantCommissionPct'] as num?,

      // Legacy compatibility
      imageUrl: json['imageUrl']?.toString(),
      localImagePath: json['localImagePath']?.toString(),
      workDays: (json['workDays'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      workingHoursFrom: json['workingHoursFrom']?.toString(),
      workingHoursTo: json['workingHoursTo']?.toString(),
      imageVersion: json['imageVersion'] is int
          ? json['imageVersion'] as int
          : int.tryParse(json['imageVersion']?.toString() ?? ''),
    );
  }

  String get displayName {
    if (nameRu.trim().isNotEmpty) return nameRu.trim();
    if ((nameKk ?? '').trim().isNotEmpty) return nameKk!.trim();
    return 'Без названия';
  }

  String get displayAddress {
    final value = (address ?? '').trim();
    return value.isNotEmpty ? value : 'Адрес не указан';
  }

  String get displayPhone {
    final value = (phone ?? '').trim();
    return value.isNotEmpty ? value : 'Телефон не указан';
  }

  String get displayWorkingHours {
    final newValue = (workingHours ?? '').trim();
    if (newValue.isNotEmpty) return newValue;

    final from = (workingHoursFrom ?? '').trim();
    final to = (workingHoursTo ?? '').trim();
    if (from.isNotEmpty && to.isNotEmpty) {
      return '$from - $to';
    }

    return 'Время не указано';
  }

  String get displayStatus {
    final raw = (status ?? '').trim().toUpperCase();
    switch (raw) {
      case 'OPEN':
        return 'Открыт';
      case 'CLOSED':
        return 'Закрыт';
      default:
        return raw.isNotEmpty ? raw : 'Не указан';
    }
  }

  String? get resolvedRemoteImageUrl {
    final newUrl = (coverImageUrl ?? '').trim();
    if (newUrl.isNotEmpty) return newUrl;

    final legacyUrl = (imageUrl ?? '').trim();
    if (legacyUrl.isNotEmpty) return legacyUrl;

    return null;
  }

  String? get resolvedLocalImagePath {
    final value = (localImagePath ?? '').trim();
    return value.isNotEmpty ? value : null;
  }

  bool get hasAnyImage =>
      resolvedRemoteImageUrl != null || resolvedLocalImagePath != null;

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
      'imageUrl': imageUrl,
      'localImagePath': localImagePath,
      'workDays': workDays,
      'workingHoursFrom': workingHoursFrom,
      'workingHoursTo': workingHoursTo,
      'imageVersion': imageVersion,
    };
  }

  RestaurantProfileData copyWith({
    String? id,
    String? nameRu,
    String? nameKk,
    String? phone,
    String? address,
    String? workingHours,
    String? coverImageUrl,
    String? status,
    bool? isInApp,
    bool? isPinned,
    int? sortOrder,
    num? effectiveRestaurantCommissionPct,
    String? imageUrl,
    String? localImagePath,
    List<String>? workDays,
    String? workingHoursFrom,
    String? workingHoursTo,
    int? imageVersion,
    bool clearCoverImageUrl = false,
    bool clearImageUrl = false,
    bool clearLocalImagePath = false,
  }) {
    return RestaurantProfileData(
      id: id ?? this.id,
      nameRu: nameRu ?? this.nameRu,
      nameKk: nameKk ?? this.nameKk,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      workingHours: workingHours ?? this.workingHours,
      coverImageUrl: clearCoverImageUrl
          ? null
          : (coverImageUrl ?? this.coverImageUrl),
      status: status ?? this.status,
      isInApp: isInApp ?? this.isInApp,
      isPinned: isPinned ?? this.isPinned,
      sortOrder: sortOrder ?? this.sortOrder,
      effectiveRestaurantCommissionPct:
          effectiveRestaurantCommissionPct ??
              this.effectiveRestaurantCommissionPct,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      localImagePath: clearLocalImagePath
          ? null
          : (localImagePath ?? this.localImagePath),
      workDays: workDays ?? this.workDays,
      workingHoursFrom: workingHoursFrom ?? this.workingHoursFrom,
      workingHoursTo: workingHoursTo ?? this.workingHoursTo,
      imageVersion: imageVersion ?? this.imageVersion,
    );
  }
}