class RestaurantMenuData {
  final List<RestaurantMenuCategory> categories;
  final List<RestaurantMenuItem> items;

  RestaurantMenuData({
    required this.categories,
    required this.items,
  });

  factory RestaurantMenuData.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];
    final rawItems = json['items'];

    if (rawCategories is! List || rawItems is! List) {
      throw const FormatException('Invalid restaurant menu payload');
    }

    return RestaurantMenuData(
      categories: rawCategories
          .map(
            (e) => RestaurantMenuCategory.fromJson(
              _requiredMap(e, 'category'),
            ),
          )
          .toList(growable: false),
      items: rawItems
          .map(
            (e) => RestaurantMenuItem.fromJson(
              _requiredMap(e, 'product'),
            ),
          )
          .toList(growable: false),
    );
  }
}

class RestaurantMenuCategory {
  final String id;
  final String titleRu;
  final String titleKk;
  final int sortOrder;

  const RestaurantMenuCategory({
    required this.id,
    required this.titleRu,
    required this.titleKk,
    this.sortOrder = 0,
  });

  String get title => titleRu.trim().isNotEmpty ? titleRu.trim() : titleKk.trim();

  factory RestaurantMenuCategory.fromJson(Map<String, dynamic> json) {
    final id = _requiredString(json['id'], 'category.id');
    final ru = _optionalString(json['titleRu'] ?? json['title']) ?? '';
    final kk = _optionalString(json['titleKk']) ?? '';
    if (ru.isEmpty && kk.isEmpty) {
      throw const FormatException('Invalid category title');
    }

    return RestaurantMenuCategory(
      id: id,
      titleRu: ru,
      titleKk: kk,
      sortOrder: _optionalInt(json['sortOrder']) ?? 0,
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
    final id = _requiredString(json['id'], 'product.id');
    final titleRu = _optionalString(json['titleRu']) ?? '';
    final titleKk = _optionalString(json['titleKk']) ?? '';
    if (titleRu.isEmpty && titleKk.isEmpty) {
      throw const FormatException('Invalid product title');
    }

    final price = _requiredPositiveInt(json['price'], 'product.price');
    final isAvailable = _requiredBool(json['isAvailable'], 'product.isAvailable');
    final isDrink = _requiredBool(json['isDrink'], 'product.isDrink');

    String categoryId = '';
    if (json.containsKey('categoryId')) {
      categoryId = _optionalString(json['categoryId']) ?? '';
    } else {
      final category = json['category'];
      if (category is Map) {
        categoryId = _optionalString(category['id']) ?? '';
      } else {
        throw const FormatException('Missing product.categoryId');
      }
    }

    final rawImages = json['images'];
    if (rawImages != null && rawImages is! List) {
      throw const FormatException('Invalid product.images');
    }

    return RestaurantMenuItem(
      id: id,
      titleRu: titleRu,
      titleKk: titleKk,
      price: price,
      isAvailable: isAvailable,
      categoryId: categoryId,
      imageUrl: _optionalString(json['imageUrl']),
      description: _optionalString(json['description']),
      weight: _optionalString(
        json['weight'] ?? json['weightText'] ?? json['portion'],
      ),
      composition: _optionalString(
        json['composition'] ?? json['ingredients'],
      ),
      isDrink: isDrink,
      images: (rawImages as List? ?? const <dynamic>[])
          .map(
            (e) => RestaurantMenuImage.fromJson(
              _requiredMap(e, 'product.image'),
            ),
          )
          .toList(growable: false),
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
      id: _requiredString(json['id'], 'product.image.id'),
      url: _requiredString(json['url'], 'product.image.url'),
      isMain: _requiredBool(json['isMain'], 'product.image.isMain'),
    );
  }
}

Map<String, dynamic> _requiredMap(dynamic value, String field) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Invalid $field');
}

String _requiredString(dynamic value, String field) {
  final text = _optionalString(value);
  if (text == null) throw FormatException('Missing $field');
  return text;
}

String? _optionalString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  return text;
}

int _requiredPositiveInt(dynamic value, String field) {
  final parsed = _optionalInt(value);
  if (parsed == null || parsed <= 0) {
    throw FormatException('Invalid $field');
  }
  return parsed;
}

int? _optionalInt(dynamic value) {
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  final text = _optionalString(value);
  return text == null ? null : int.tryParse(text);
}

bool _requiredBool(dynamic value, String field) {
  if (value is bool) return value;
  throw FormatException('Invalid $field');
}
