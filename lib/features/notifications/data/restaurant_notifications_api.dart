import 'package:jetkiz_restaurant/core/network/api_client.dart';

class RestaurantNotificationsApi {
  RestaurantNotificationsApi({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<RestaurantNotificationsPageData> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    final path = Uri(
      path: '/notifications',
      queryParameters: {'page': '$page', 'limit': '$limit'},
    ).toString();
    final response = await _apiClient.get(path);
    if (response is! Map) {
      throw Exception('Некорректный ответ сервера по уведомлениям');
    }

    final json = Map<String, dynamic>.from(response);
    final items = json['items'] is List
        ? (json['items'] as List)
            .whereType<Map>()
            .map((item) => RestaurantNotification.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList(growable: false)
        : const <RestaurantNotification>[];

    return RestaurantNotificationsPageData(
      total: _toInt(json['total']),
      items: items,
    );
  }

  Future<int> getUnreadCount() async {
    final response = await _apiClient.get('/notifications/unread-count');
    if (response is Map) return _toInt(response['count']);
    return 0;
  }

  Future<void> markRead(String id) async {
    await _apiClient.post('/notifications/$id/read', const <String, dynamic>{});
  }

  Future<void> markAllRead() async {
    await _apiClient.post('/notifications/read-all', const <String, dynamic>{});
  }
}

class RestaurantNotificationsPageData {
  const RestaurantNotificationsPageData({
    required this.total,
    required this.items,
  });

  final int total;
  final List<RestaurantNotification> items;
}

class RestaurantNotification {
  const RestaurantNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    required this.data,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime? createdAt;
  final Map<String, dynamic> data;

  factory RestaurantNotification.fromJson(Map<String, dynamic> json) {
    return RestaurantNotification(
      id: _string(json['id']),
      type: _string(json['type']),
      title: _string(json['title']),
      body: _string(json['body']),
      isRead: json['isRead'] == true,
      createdAt: DateTime.tryParse(_string(json['createdAt'])),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const <String, dynamic>{},
    );
  }

  RestaurantNotification copyWith({bool? isRead}) {
    return RestaurantNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      data: data,
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _string(dynamic value) => value?.toString().trim() ?? '';
