import 'package:flutter_test/flutter_test.dart';
import 'package:jetkiz_restaurant/features/menu/domain/restaurant_menu_models.dart';

void main() {
  test('removing one parsed menu item never removes or mutates other items', () {
    final data = RestaurantMenuData.fromJson(<String, dynamic>{
      'categories': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'category-1',
          'titleRu': 'Пицца',
          'titleKk': 'Пицца',
          'sortOrder': 0,
        },
      ],
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'product-delete',
          'titleRu': 'Пепперони',
          'titleKk': 'Пепперони',
          'price': 2222,
          'isAvailable': true,
          'categoryId': 'category-1',
          'isDrink': false,
          'images': <dynamic>[],
        },
        <String, dynamic>{
          'id': 'product-keep',
          'titleRu': 'Маргарита',
          'titleKk': 'Маргарита',
          'price': 2500,
          'isAvailable': true,
          'categoryId': 'category-1',
          'isDrink': false,
          'images': <dynamic>[],
        },
      ],
    });

    data.items.removeWhere((item) => item.id == 'product-delete');

    expect(data.items.map((item) => item.id).toList(), <String>['product-keep']);
    expect(data.items.single.titleRu, 'Маргарита');
    expect(data.items.single.price, 2500);
    expect(data.items.single.isAvailable, isTrue);
  });
}
