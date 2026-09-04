class RestaurantAppBootstrap {
  const RestaurantAppBootstrap({
    required this.configVersion,
    required this.restaurant,
    required this.support,
    required this.maintenance,
    required this.featureFlags,
    required this.banners,
  });

  final int configVersion;
  final RestaurantCmsRestaurant restaurant;
  final RestaurantCmsSupport support;
  final RestaurantCmsMaintenance maintenance;
  final Map<String, RestaurantCmsFeatureFlag> featureFlags;
  final Map<String, List<Map<String, dynamic>>> banners;

  factory RestaurantAppBootstrap.fromJson(Map<String, dynamic> json) {
    final featureRaw = json['featureFlags'];
    final bannerRaw = json['banners'];

    return RestaurantAppBootstrap(
      configVersion: _toInt(json['configVersion']),
      restaurant: RestaurantCmsRestaurant.fromJson(_map(json['restaurant'])),
      support: RestaurantCmsSupport.fromJson(_map(json['support'])),
      maintenance: RestaurantCmsMaintenance.fromJson(_map(json['maintenance'])),
      featureFlags: featureRaw is Map
          ? featureRaw.map(
              (key, value) => MapEntry(
                key.toString(),
                RestaurantCmsFeatureFlag.fromJson(_map(value)),
              ),
            )
          : const <String, RestaurantCmsFeatureFlag>{},
      banners: bannerRaw is Map
          ? bannerRaw.map(
              (key, value) => MapEntry(
                key.toString(),
                value is List
                    ? value
                          .whereType<Map>()
                          .map((item) => Map<String, dynamic>.from(item))
                          .toList(growable: false)
                    : const <Map<String, dynamic>>[],
              ),
            )
          : const <String, List<Map<String, dynamic>>>{},
    );
  }

  bool featureEnabled(String key) => featureFlags[key]?.enabled ?? true;

  String? featureReason(String key, {bool kazakh = false}) {
    final flag = featureFlags[key];
    if (flag == null) return null;
    final preferred = kazakh ? flag.reasonKk : flag.reasonRu;
    final fallback = kazakh ? flag.reasonRu : flag.reasonKk;
    return _nonEmpty(preferred) ?? _nonEmpty(fallback);
  }
}

class RestaurantCmsRestaurant {
  const RestaurantCmsRestaurant({
    required this.id,
    required this.nameRu,
    required this.nameKk,
    required this.status,
    required this.isInApp,
    required this.isAcceptingOrders,
    required this.onboardingStatus,
    this.onboardingNote,
    this.blockedAt,
    this.blockReason,
  });

  final String id;
  final String nameRu;
  final String nameKk;
  final String status;
  final bool isInApp;
  final bool isAcceptingOrders;
  final String onboardingStatus;
  final String? onboardingNote;
  final DateTime? blockedAt;
  final String? blockReason;

  factory RestaurantCmsRestaurant.fromJson(Map<String, dynamic> json) {
    return RestaurantCmsRestaurant(
      id: _string(json['id']),
      nameRu: _string(json['nameRu']),
      nameKk: _string(json['nameKk']),
      status: _string(json['status']),
      isInApp: json['isInApp'] == true,
      isAcceptingOrders: json['isAcceptingOrders'] == true,
      onboardingStatus: _string(json['onboardingStatus']),
      onboardingNote: _nullable(json['onboardingNote']),
      blockedAt: DateTime.tryParse(_string(json['blockedAt'])),
      blockReason: _nullable(json['blockReason']),
    );
  }
}

class RestaurantCmsSupport {
  const RestaurantCmsSupport({
    this.phone,
    this.whatsappUrl,
    this.telegramUrl,
    this.workingHoursRu,
    this.workingHoursKk,
    this.emergencyTextRu,
    this.emergencyTextKk,
  });

  final String? phone;
  final String? whatsappUrl;
  final String? telegramUrl;
  final String? workingHoursRu;
  final String? workingHoursKk;
  final String? emergencyTextRu;
  final String? emergencyTextKk;

  factory RestaurantCmsSupport.fromJson(Map<String, dynamic> json) {
    return RestaurantCmsSupport(
      phone: _nullable(json['phone']),
      whatsappUrl: _nullable(json['whatsappUrl']),
      telegramUrl: _nullable(json['telegramUrl']),
      workingHoursRu: _nullable(json['workingHoursRu']),
      workingHoursKk: _nullable(json['workingHoursKk']),
      emergencyTextRu: _nullable(json['emergencyTextRu']),
      emergencyTextKk: _nullable(json['emergencyTextKk']),
    );
  }
}

class RestaurantCmsMaintenance {
  const RestaurantCmsMaintenance({
    required this.mode,
    required this.isEnabled,
    this.titleRu,
    this.titleKk,
    this.bodyRu,
    this.bodyKk,
    this.affectedFeatures = const <String>[],
  });

  final String mode;
  final bool isEnabled;
  final String? titleRu;
  final String? titleKk;
  final String? bodyRu;
  final String? bodyKk;
  final List<String> affectedFeatures;

  bool get blocksApp => isEnabled && mode.toUpperCase() == 'BLOCK';
  bool get isSoft => isEnabled && mode.toUpperCase() == 'SOFT';

  factory RestaurantCmsMaintenance.fromJson(Map<String, dynamic> json) {
    return RestaurantCmsMaintenance(
      mode: _string(json['mode']),
      isEnabled: json['isEnabled'] == true,
      titleRu: _nullable(json['titleRu']),
      titleKk: _nullable(json['titleKk']),
      bodyRu: _nullable(json['bodyRu']),
      bodyKk: _nullable(json['bodyKk']),
      affectedFeatures: json['affectedFeatures'] is List
          ? (json['affectedFeatures'] as List)
                .map((item) => item.toString())
                .toList(growable: false)
          : const <String>[],
    );
  }
}

class RestaurantCmsFeatureFlag {
  const RestaurantCmsFeatureFlag({
    required this.enabled,
    this.reasonRu,
    this.reasonKk,
  });

  final bool enabled;
  final String? reasonRu;
  final String? reasonKk;

  factory RestaurantCmsFeatureFlag.fromJson(Map<String, dynamic> json) {
    return RestaurantCmsFeatureFlag(
      enabled: json['enabled'] != false,
      reasonRu: _nullable(json['reasonRu']),
      reasonKk: _nullable(json['reasonKk']),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _string(dynamic value) => value?.toString().trim() ?? '';

String? _nullable(dynamic value) {
  final text = _string(value);
  return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
}

String? _nonEmpty(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}
