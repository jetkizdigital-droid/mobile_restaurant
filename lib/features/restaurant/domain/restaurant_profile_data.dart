class RestaurantProfileData {
  final String id;
  final String nameRu;
  final String? nameKk;
  final String? phone;
  final String? address;

  final String? workingHours;
  final String? coverImageUrl;
  final String? status;
  final String? onboardingStatus;
  final String? onboardingNote;
  final DateTime? blockedAt;
  final String? blockReason;
  final bool? isInApp;
  final bool? isAcceptingOrders;
  final bool? isWithinWorkingHours;
  final bool? canAcceptOrders;
  final bool? effectiveAcceptingOrders;
  final bool? isPinned;
  final int? sortOrder;
  final num? restaurantCommissionPctOverride;
  final num? effectiveRestaurantCommissionPct;

  // Legacy compatibility fields.
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
    this.onboardingStatus,
    this.onboardingNote,
    this.blockedAt,
    this.blockReason,
    this.isInApp,
    this.isAcceptingOrders,
    this.isWithinWorkingHours,
    this.canAcceptOrders,
    this.effectiveAcceptingOrders,
    this.isPinned,
    this.sortOrder,
    this.restaurantCommissionPctOverride,
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
      workingHours: json['workingHours']?.toString(),
      coverImageUrl: json['coverImageUrl']?.toString(),
      status: json['status']?.toString(),
      onboardingStatus: json['onboardingStatus']?.toString(),
      onboardingNote: _nullableString(json['onboardingNote']),
      blockedAt: _toDateTime(json['blockedAt']),
      blockReason: _nullableString(json['blockReason']),
      isInApp: json['isInApp'] as bool?,
      isAcceptingOrders: json['isAcceptingOrders'] as bool?,
      isWithinWorkingHours: json['isWithinWorkingHours'] as bool?,
      canAcceptOrders: json['canAcceptOrders'] as bool?,
      effectiveAcceptingOrders: json['effectiveAcceptingOrders'] as bool?,
      isPinned: json['isPinned'] as bool?,
      sortOrder: json['sortOrder'] is int
          ? json['sortOrder'] as int
          : int.tryParse(json['sortOrder']?.toString() ?? ''),
      restaurantCommissionPctOverride: _toNum(
        json['restaurantCommissionPctOverride'],
      ),
      effectiveRestaurantCommissionPct: _toNum(
        json['effectiveRestaurantCommissionPct'],
      ),
      imageUrl: json['imageUrl']?.toString(),
      localImagePath: json['localImagePath']?.toString(),
      workDays: (json['workDays'] as List?)?.map((e) => e.toString()).toList(),
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
    if (from.isNotEmpty && to.isNotEmpty) return '$from - $to';

    return 'Время не указано';
  }

  String get normalizedOnboardingStatus =>
      (onboardingStatus ?? '').trim().toUpperCase();

  bool get isApproved => normalizedOnboardingStatus == 'APPROVED';
  bool get isBlocked =>
      blockedAt != null || normalizedOnboardingStatus == 'BLOCKED';
  bool get isPublished => isInApp == true;
  bool get isTakingOrders => isAcceptingOrders == true;
  bool get isOpenBySchedule => isWithinWorkingHours ?? status == 'OPEN';
  bool get isEffectivelyTakingOrders =>
      effectiveAcceptingOrders ??
      (isTakingOrders &&
          isOpenBySchedule &&
          isApproved &&
          isPublished &&
          !isBlocked);

  bool get canEnableAcceptingOrders =>
      (canAcceptOrders ??
      (isApproved && isPublished && !isBlocked && isOpenBySchedule));

  bool get canResubmitForReview =>
      normalizedOnboardingStatus == 'REJECTED' ||
      normalizedOnboardingStatus == 'NEEDS_CHANGES';

  bool get needsOnboardingAttention {
    return normalizedOnboardingStatus == 'NEEDS_CHANGES' ||
        normalizedOnboardingStatus == 'REJECTED' ||
        isBlocked;
  }

  bool get isResubmittedForReview =>
      normalizedOnboardingStatus == 'PENDING_REVIEW' &&
      (onboardingNote ?? '').trim().isNotEmpty;

  bool get hasIndividualCommission => restaurantCommissionPctOverride != null;

  String get commissionTypeLabel =>
      hasIndividualCommission ? 'Индивидуальная' : 'Общая';

  String get displayCommission {
    final value = effectiveRestaurantCommissionPct;
    if (value == null || !value.isFinite) return 'Не указана';
    final rounded = value.round();
    return '$rounded%';
  }

  String get onboardingTitle {
    switch (normalizedOnboardingStatus) {
      case 'APPROVED':
        return 'Ресторан одобрен';
      case 'NEEDS_CHANGES':
        return 'Нужны изменения';
      case 'BLOCKED':
        return 'Ресторан заблокирован';
      case 'REJECTED':
        return 'Заявка отклонена';
      case 'DRAFT':
        return 'Заявка не завершена';
      case 'PENDING_REVIEW':
        return isResubmittedForReview
            ? 'Повторная проверка'
            : 'Заявка на проверке';
      case '':
        return 'Заявка на проверке';
      default:
        return normalizedOnboardingStatus;
    }
  }

  String get onboardingDescription {
    final note = (onboardingNote ?? '').trim();
    if (note.isNotEmpty && normalizedOnboardingStatus != 'PENDING_REVIEW') {
      return note;
    }

    switch (normalizedOnboardingStatus) {
      case 'APPROVED':
        if (!isPublished) {
          return 'Ресторан одобрен, но пока не опубликован в JETKIZ.';
        }
        if (!isOpenBySchedule) {
          return 'Сейчас ресторан закрыт по графику. Чтобы принимать заказы, измените график работы.';
        }
        return isTakingOrders
            ? 'Ресторан опубликован и принимает заказы.'
            : 'Ресторан опубликован. Приём заказов приостановлен.';
      case 'NEEDS_CHANGES':
        return 'Исправьте данные ресторана и отправьте заявку на повторную проверку.';
      case 'BLOCKED':
        return (blockReason ?? '').trim().isNotEmpty
            ? blockReason!.trim()
            : 'Ресторан скрыт из клиентского приложения. Для уточнения обратитесь в поддержку.';
      case 'REJECTED':
        return 'Исправьте данные ресторана и отправьте заявку на повторную проверку.';
      case 'PENDING_REVIEW':
        return isResubmittedForReview
            ? 'Исправления отправлены. Ожидайте решения администратора.'
            : 'Заявка отправлена. Ожидайте решения администратора.';
      default:
        return 'После одобрения ресторан сможет появиться в JETKIZ и принимать заказы.';
    }
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
      'onboardingStatus': onboardingStatus,
      'onboardingNote': onboardingNote,
      'blockedAt': blockedAt?.toIso8601String(),
      'blockReason': blockReason,
      'isInApp': isInApp,
      'isAcceptingOrders': isAcceptingOrders,
      'isWithinWorkingHours': isWithinWorkingHours,
      'canAcceptOrders': canAcceptOrders,
      'effectiveAcceptingOrders': effectiveAcceptingOrders,
      'isPinned': isPinned,
      'sortOrder': sortOrder,
      'restaurantCommissionPctOverride': restaurantCommissionPctOverride,
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
    String? onboardingStatus,
    String? onboardingNote,
    DateTime? blockedAt,
    String? blockReason,
    bool? isInApp,
    bool? isAcceptingOrders,
    bool? isWithinWorkingHours,
    bool? canAcceptOrders,
    bool? effectiveAcceptingOrders,
    bool? isPinned,
    int? sortOrder,
    num? restaurantCommissionPctOverride,
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
    bool clearOnboardingNote = false,
    bool clearBlockedAt = false,
    bool clearBlockReason = false,
    bool clearRestaurantCommissionPctOverride = false,
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
      onboardingStatus: onboardingStatus ?? this.onboardingStatus,
      onboardingNote: clearOnboardingNote
          ? null
          : (onboardingNote ?? this.onboardingNote),
      blockedAt: clearBlockedAt ? null : (blockedAt ?? this.blockedAt),
      blockReason: clearBlockReason ? null : (blockReason ?? this.blockReason),
      isInApp: isInApp ?? this.isInApp,
      isAcceptingOrders: isAcceptingOrders ?? this.isAcceptingOrders,
      isWithinWorkingHours: isWithinWorkingHours ?? this.isWithinWorkingHours,
      canAcceptOrders: canAcceptOrders ?? this.canAcceptOrders,
      effectiveAcceptingOrders:
          effectiveAcceptingOrders ?? this.effectiveAcceptingOrders,
      isPinned: isPinned ?? this.isPinned,
      sortOrder: sortOrder ?? this.sortOrder,
      restaurantCommissionPctOverride: clearRestaurantCommissionPctOverride
          ? null
          : (restaurantCommissionPctOverride ??
                this.restaurantCommissionPctOverride),
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

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty || text.toLowerCase() == 'null'
        ? null
        : text;
  }

  static num? _toNum(dynamic value) {
    if (value is num) return value;
    final text = _nullableString(value);
    return text == null ? null : num.tryParse(text);
  }

  static DateTime? _toDateTime(dynamic value) {
    final text = _nullableString(value);
    return text == null ? null : DateTime.tryParse(text);
  }
}
