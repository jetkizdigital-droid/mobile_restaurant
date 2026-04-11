class RestaurantMenuData {
  final List<RestaurantMenuCategory> categories;
  final List<RestaurantMenuItem> items;

  RestaurantMenuData({
    required this.categories,
    required this.items,
  });

  factory RestaurantMenuData.fromJson(Map<String, dynamic> json) {
    return RestaurantMenuData(
      categories: ((json['categories'] as List?) ?? const [])
          .map(
            (e) => RestaurantMenuCategory.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      items: ((json['items'] as List?) ?? const [])
          .map(
            (e) => RestaurantMenuItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}

class RestaurantMenuCategory {
  final String id;
  final String title;

  RestaurantMenuCategory({
    required this.id,
    required this.title,
  });

  factory RestaurantMenuCategory.fromJson(Map<String, dynamic> json) {
    return RestaurantMenuCategory(
      id: json['id']?.toString() ?? '',
      title: (json['titleRu'] ?? json['title'] ?? '').toString(),
    );
  }
}

class RestaurantMenuItem {
  final String id;
  final String titleRu;
  final String titleKk;
  final int price;
  final bool isAvailable;
  final String categoryId;
  final String? imageUrl;
  final String? description;
  final String? weight;
  final String? composition;
  final bool isDrink;
  final List<RestaurantMenuImage> images;

  const RestaurantMenuItem({
    required this.id,
    required this.titleRu,
    required this.titleKk,
    required this.price,
    required this.isAvailable,
    required this.categoryId,
    this.imageUrl,
    this.description,
    this.weight,
    this.composition,
    required this.isDrink,
    required this.images,
  });

  factory RestaurantMenuItem.fromJson(Map<String, dynamic> json) {
    return RestaurantMenuItem(
      id: json['id']?.toString() ?? '',
      titleRu: (json['titleRu'] ?? '').toString(),
      titleKk: (json['titleKk'] ?? '').toString(),
      price: (json['price'] as num?)?.toInt() ?? 0,
      isAvailable: json['isAvailable'] == null
          ? true
          : json['isAvailable'] == true,
      categoryId: json['categoryId']?.toString() ??
          json['category']?['id']?.toString() ??
          '',
      imageUrl: json['imageUrl']?.toString(),
      description: _nullableString(json['description']),
      weight: _nullableString(
        json['weight'] ?? json['weightText'] ?? json['portion'],
      ),
      composition: _nullableString(
        json['composition'] ?? json['ingredients'],
      ),
      isDrink: json['isDrink'] == true,
      images: ((json['images'] as List?) ?? const [])
          .map(
            (e) => RestaurantMenuImage.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }

  RestaurantMenuItem copyWith({
    String? id,
    String? titleRu,
    String? titleKk,
    int? price,
    bool? isAvailable,
    String? categoryId,
    String? imageUrl,
    String? description,
    String? weight,
    String? composition,
    bool? isDrink,
    List<RestaurantMenuImage>? images,
  }) {
    return RestaurantMenuItem(
      id: id ?? this.id,
      titleRu: titleRu ?? this.titleRu,
      titleKk: titleKk ?? this.titleKk,
      price: price ?? this.price,
      isAvailable: isAvailable ?? this.isAvailable,
      categoryId: categoryId ?? this.categoryId,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      weight: weight ?? this.weight,
      composition: composition ?? this.composition,
      isDrink: isDrink ?? this.isDrink,
      images: images ?? this.images,
    );
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }
}

class RestaurantMenuImage {
  final String id;
  final String url;
  final bool isMain;

  const RestaurantMenuImage({
    required this.id,
    required this.url,
    required this.isMain,
  });

  factory RestaurantMenuImage.fromJson(Map<String, dynamic> json) {
    return RestaurantMenuImage(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      isMain: json['isMain'] == true,
    );
  }
}