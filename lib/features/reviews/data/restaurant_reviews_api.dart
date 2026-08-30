import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/reviews/domain/restaurant_review.dart';

class RestaurantReviewsApi {
  const RestaurantReviewsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<RestaurantReviewsPageData> getRestaurantReviews({
    required String restaurantId,
    int page = 1,
    int limit = 20,
  }) async {
    final path = Uri(
      path: '/restaurants/$restaurantId/reviews',
      queryParameters: <String, String>{
        'page': '$page',
        'limit': '$limit',
        'includeUser': 'true',
      },
    ).toString();

    final dynamic response = await _apiClient.get(path);

    if (response is! Map) {
      throw Exception('Некорректный ответ сервера по отзывам');
    }

    final json = Map<String, dynamic>.from(response);
    final itemsRaw = json['items'];
    final metaRaw = json['meta'];

    final items = itemsRaw is List
        ? itemsRaw
            .whereType<Map>()
            .map((e) => RestaurantReview.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false)
        : <RestaurantReview>[];

    final meta = metaRaw is Map
        ? ReviewsMeta.fromJson(Map<String, dynamic>.from(metaRaw))
        : ReviewsMeta(
            page: page,
            limit: limit,
            total: items.length,
          );

    return RestaurantReviewsPageData(
      items: items,
      meta: meta,
    );
  }

  Future<ReviewResponse> saveResponse({
    required String reviewId,
    required String text,
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      throw Exception('Введите текст ответа');
    }

    final dynamic response = await _apiClient.post(
      '/restaurants/reviews/$reviewId/response',
      <String, dynamic>{'text': normalized},
    );

    if (response is! Map) {
      throw Exception('Некорректный ответ сервера');
    }

    final json = Map<String, dynamic>.from(response);
    final item = json['item'];
    if (item is! Map) {
      throw Exception('Сервер не вернул сохранённый ответ');
    }

    return ReviewResponse.fromJson(Map<String, dynamic>.from(item));
  }

  Future<void> deleteResponse({required String reviewId}) async {
    await _apiClient.delete('/restaurants/reviews/$reviewId/response');
  }
}

class RestaurantReviewsPageData {
  const RestaurantReviewsPageData({
    required this.items,
    required this.meta,
  });

  final List<RestaurantReview> items;
  final ReviewsMeta meta;
}

class ReviewsMeta {
  const ReviewsMeta({
    required this.page,
    required this.limit,
    required this.total,
  });

  final int page;
  final int limit;
  final int total;

  bool get hasMore => page * limit < total;

  factory ReviewsMeta.fromJson(Map<String, dynamic> json) {
    return ReviewsMeta(
      page: _toInt(json['page'], 1),
      limit: _toInt(json['limit'], 20),
      total: _toInt(json['total'], 0),
    );
  }

  static int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
