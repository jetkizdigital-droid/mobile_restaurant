class RestaurantReview {
  const RestaurantReview({
    required this.id,
    required this.rating,
    required this.createdAt,
    required this.text,
    required this.userName,
    this.userAvatar,
    this.media = const [],
    this.reactions = const [],
    this.reactionsSummary = const {},
    this.response,
  });

  final String id;
  final int rating;
  final DateTime createdAt;
  final String? text;
  final String userName;
  final String? userAvatar;
  final List<ReviewMedia> media;
  final List<ReviewReaction> reactions;
  final Map<String, int> reactionsSummary;
  final ReviewResponse? response;

  factory RestaurantReview.fromJson(Map<String, dynamic> json) {
    final user = _asMap(json['user']);

    return RestaurantReview(
      id: (json['id'] ?? '').toString(),
      rating: _toInt(json['rating']),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      text: _toNullableString(json['text']),
      userName: _buildUserName(user),
      userAvatar: _toNullableString(user?['avatarUrl']),
      media: _toListOfMaps(
        json['media'],
      ).map(ReviewMedia.fromJson).toList(growable: false),
      reactions: _toListOfMaps(
        json['reactions'],
      ).map(ReviewReaction.fromJson).toList(growable: false),
      reactionsSummary: _toSummaryMap(json['reactionsSummary']),
      response: json['response'] == null
          ? null
          : ReviewResponse.fromJson(
              Map<String, dynamic>.from(json['response'] as Map),
            ),
    );
  }

  static String _buildUserName(Map<String, dynamic>? user) {
    if (user == null) return 'Пользователь';

    final firstName = _toNullableString(user['firstName']) ?? '';
    final lastName = _toNullableString(user['lastName']) ?? '';
    final fullName = '$firstName $lastName'.trim();

    if (fullName.isNotEmpty) return fullName;

    final phone = _toNullableString(user['phone']);
    if (phone != null && phone.isNotEmpty) return phone;

    return 'Пользователь';
  }
}

class ReviewMedia {
  const ReviewMedia({
    required this.id,
    required this.type,
    required this.url,
    this.previewUrl,
    this.createdAt,
  });

  final String id;
  final String type;
  final String url;
  final String? previewUrl;
  final DateTime? createdAt;

  bool get isImage => type == 'IMAGE';
  bool get isVideo => type == 'VIDEO';
  bool get isAudio => type == 'AUDIO';

  factory ReviewMedia.fromJson(Map<String, dynamic> json) {
    return ReviewMedia(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      previewUrl: _toNullableString(json['previewUrl']),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

class ReviewReaction {
  const ReviewReaction({
    required this.id,
    required this.userId,
    required this.type,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String type;
  final DateTime? createdAt;

  factory ReviewReaction.fromJson(Map<String, dynamic> json) {
    return ReviewReaction(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

class ReviewResponse {
  const ReviewResponse({
    required this.id,
    required this.createdByName,
    required this.text,
    required this.media,
    required this.reactions,
    required this.reactionsSummary,
    this.createdAt,
  });

  final String id;
  final String createdByName;
  final String? text;
  final List<ReviewMedia> media;
  final List<ReviewReaction> reactions;
  final Map<String, int> reactionsSummary;
  final DateTime? createdAt;

  bool get hasContent =>
      (text != null && text!.trim().isNotEmpty) || media.isNotEmpty;

  factory ReviewResponse.fromJson(Map<String, dynamic> json) {
    final createdByUser = _asMap(json['createdByUser']);

    return ReviewResponse(
      id: (json['id'] ?? '').toString(),
      createdByName: RestaurantReview._buildUserName(createdByUser),
      text: _toNullableString(json['text']),
      media: _toListOfMaps(
        json['media'],
      ).map(ReviewMedia.fromJson).toList(growable: false),
      reactions: _toListOfMaps(
        json['reactions'],
      ).map(ReviewReaction.fromJson).toList(growable: false),
      reactionsSummary: _toSummaryMap(json['reactionsSummary']),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

List<Map<String, dynamic>> _toListOfMaps(dynamic raw) {
  if (raw is! List) return const [];

  return raw
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String? _toNullableString(dynamic value) {
  if (value == null) return null;
  final result = value.toString().trim();
  return result.isEmpty ? null : result;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, int> _toSummaryMap(dynamic raw) {
  if (raw is! Map) return const {};

  final result = <String, int>{};
  raw.forEach((key, value) {
    result[key.toString()] = _toInt(value);
  });
  return result;
}
