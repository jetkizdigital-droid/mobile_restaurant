import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/session/restaurant_context.dart';
import 'package:jetkiz_restaurant/core/session/session_manager.dart';

import '../../data/restaurant_menu_api.dart';
import '../../domain/restaurant_menu_models.dart';
import '../widgets/menu_item_card.dart';
import '../widgets/menuCreateActionSheet.dart';
import 'createMenuCategoryPage.dart';
import 'upsertMenuItemPage.dart';

class RestaurantMenuPage extends StatefulWidget {
  const RestaurantMenuPage({super.key});

  @override
  State<RestaurantMenuPage> createState() => _RestaurantMenuPageState();
}

class _RestaurantMenuPageState extends State<RestaurantMenuPage> {
  final RestaurantMenuApi _api = RestaurantMenuApi();

  bool _isLoading = true;
  String? _error;

  String? _restaurantId;
  List<RestaurantMenuCategory> _categories = [];
  List<RestaurantMenuItem> _items = [];
  String _selectedCategory = 'Все';

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  String? _readId(dynamic value) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }

    return text;
  }

  bool _looksLikeRestaurantPayload(Map<String, dynamic> data) {
    return data.containsKey('nameRu') ||
        data.containsKey('nameKk') ||
        data.containsKey('slug') ||
        data.containsKey('workingHours') ||
        data.containsKey('status') ||
        data.containsKey('isInApp');
  }

  String? _resolveRestaurantId(Map<String, dynamic> data) {
    final fromContext = resolveRestaurantIdFromMe(data)?.trim();

    if (fromContext != null && fromContext.isNotEmpty) {
      return fromContext;
    }

    final directRestaurantId = _readId(data['restaurantId']);

    if (directRestaurantId != null) {
      return directRestaurantId;
    }

    if (_looksLikeRestaurantPayload(data)) {
      final directId = _readId(data['id']);

      if (directId != null) {
        return directId;
      }
    }

    final restaurant = data['restaurant'];

    if (restaurant is Map) {
      final id = _readId(restaurant['id']) ?? _readId(restaurant['restaurantId']);

      if (id != null) {
        return id;
      }
    }

    final ownedRestaurant = data['ownedRestaurant'];

    if (ownedRestaurant is Map) {
      final id =
          _readId(ownedRestaurant['id']) ?? _readId(ownedRestaurant['restaurantId']);

      if (id != null) {
        return id;
      }
    }

    final restaurantProfile = data['restaurantProfile'];

    if (restaurantProfile is Map) {
      final id = _readId(restaurantProfile['id']) ??
          _readId(restaurantProfile['restaurantId']);

      if (id != null) {
        return id;
      }
    }

    final restaurants = data['restaurants'];

    if (restaurants is List && restaurants.isNotEmpty) {
      for (final item in restaurants) {
        if (item is Map) {
          final id = _readId(item['id']) ?? _readId(item['restaurantId']);

          if (id != null) {
            return id;
          }
        }
      }
    }

    final accesses = data['restaurantAccesses'];

    if (accesses is List && accesses.isNotEmpty) {
      for (final access in accesses) {
        if (access is! Map) {
          continue;
        }

        final restaurantId = _readId(access['restaurantId']);

        if (restaurantId != null) {
          return restaurantId;
        }

        final restaurantFromAccess = access['restaurant'];

        if (restaurantFromAccess is Map) {
          final id = _readId(restaurantFromAccess['id']) ??
              _readId(restaurantFromAccess['restaurantId']);

          if (id != null) {
            return id;
          }
        }
      }
    }

    return null;
  }

  Future<String> _getRestaurantId() async {
    final sessionRestaurantId = _readId(SessionManager.restaurantId);

    if (sessionRestaurantId != null) {
      return sessionRestaurantId;
    }

    final me = await _api.getRestaurantMe();
    final restaurantId = _resolveRestaurantId(me);

    if (restaurantId == null || restaurantId.trim().isEmpty) {
      throw Exception('У аккаунта не найден ресторан');
    }

    final normalizedRestaurantId = restaurantId.trim();
    SessionManager.restaurantId = normalizedRestaurantId;

    return normalizedRestaurantId;
  }

  Future<void> _loadMenu() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final restaurantId = await _getRestaurantId();
      final response = await _api.getMenu(restaurantId);
      final parsed = RestaurantMenuData.fromJson(response);

      if (!mounted) return;

      setState(() {
        _restaurantId = restaurantId;
        _categories = parsed.categories;
        _items = parsed.items;
        _selectedCategory = _normalizeSelectedCategory(
          selected: _selectedCategory,
          categories: parsed.categories,
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '').trim();
        _isLoading = false;
      });
    }
  }

  String _normalizeSelectedCategory({
    required String selected,
    required List<RestaurantMenuCategory> categories,
  }) {
    if (selected == 'Все') {
      return selected;
    }

    final exists = categories.any((category) => category.title == selected);

    return exists ? selected : 'Все';
  }

  List<RestaurantMenuItem> get _filteredItems {
    if (_selectedCategory == 'Все') return _items;

    final matches = _categories.where((e) => e.title == _selectedCategory);
    if (matches.isEmpty) return [];

    final selected = matches.first;

    return _items.where((item) => item.categoryId == selected.id).toList();
  }

  String _categoryTitleByItem(RestaurantMenuItem item) {
    try {
      return _categories.firstWhere((e) => e.id == item.categoryId).title;
    } catch (_) {
      return 'Без категории';
    }
  }

  Future<void> _toggleAvailability(RestaurantMenuItem item) async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) {
      _showMessage('Не найден ресторан');
      return;
    }

    final newValue = !item.isAvailable;

    try {
      await _api.updateAvailability(
        restaurantId: restaurantId,
        productId: item.id,
        value: newValue,
      );

      if (!mounted) return;

      setState(() {
        _items = _items.map((e) {
          if (e.id != item.id) return e;
          return e.copyWith(isAvailable: newValue);
        }).toList();
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', '').trim());
    }
  }

  Future<void> _deleteItem(RestaurantMenuItem item) async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) {
      _showMessage('Не найден ресторан');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1F2937), Color(0xFF111827)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF374151)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Удалить блюдо?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Удалить "${item.titleRu}" из меню?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF4B5563)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Удалить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _api.deleteProduct(restaurantId, item.id);

      if (!mounted) return;

      setState(() {
        _items.removeWhere((e) => e.id == item.id);
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', '').trim());
    }
  }

  Future<void> _openCreateItem() async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) {
      _showMessage('Не найден ресторан');
      return;
    }

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UpsertMenuItemPage(
          restaurantId: restaurantId,
        ),
      ),
    );

    if (created == true) {
      await _loadMenu();
    }
  }

  Future<void> _openCreateCategory() async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) {
      _showMessage('Не найден ресторан');
      return;
    }

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateMenuCategoryPage(
          restaurantId: restaurantId,
          nextSortOrder: _categories.length,
        ),
      ),
    );

    if (created == true) {
      await _loadMenu();
    }
  }

  void _openCreateActions() {
    if (_restaurantId == null || _restaurantId!.trim().isEmpty) {
      _showMessage('Не найден ресторан');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return MenuCreateActionSheet(
          onAddProduct: () {
            Navigator.of(sheetContext).pop();
            _openCreateItem();
          },
          onAddCategory: () {
            Navigator.of(sheetContext).pop();
            _openCreateCategory();
          },
        );
      },
    );
  }

  Future<void> _openEditItem(RestaurantMenuItem item) async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) {
      _showMessage('Не найден ресторан');
      return;
    }

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UpsertMenuItemPage(
          restaurantId: restaurantId,
          item: item,
        ),
      ),
    );

    if (updated == true) {
      await _loadMenu();
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);

    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message.trim().isEmpty ? 'Ошибка' : message.trim(),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020817),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 99, right: 4),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: _openCreateActions,
            elevation: 0,
            backgroundColor: const Color(0xFF489F2A),
            foregroundColor: Colors.white,
            shape: const CircleBorder(
              side: BorderSide(
                color: Color(0xFF020817),
                width: 4,
              ),
            ),
            child: const Icon(Icons.add, size: 28),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _MenuHeader(
              categories: _categories,
              selectedCategory: _selectedCategory,
              itemCount: _items.length,
              onCategorySelected: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadMenu,
                color: const Color(0xFF489F2A),
                backgroundColor: const Color(0xFF111827),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 180),
        children: const [
          Center(
            child: CircularProgressIndicator(
              color: Color(0xFF489F2A),
            ),
          ),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 140, 24, 120),
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFF6B7280),
            size: 46,
          ),
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _loadMenu,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF489F2A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Повторить'),
            ),
          ),
        ],
      );
    }

    if (_filteredItems.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 120),
        children: const [
          Center(
            child: Icon(
              Icons.restaurant_menu,
              color: Color(0xFF4B5563),
              size: 54,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Нет блюд',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Добавьте первое блюдо в меню',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      itemCount: _filteredItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final item = _filteredItems[index];

        return MenuItemCard(
          item: item,
          categoryTitle: _categoryTitleByItem(item),
          onToggleAvailability: () => _toggleAvailability(item),
          onEdit: () => _openEditItem(item),
          onDelete: () => _deleteItem(item),
        );
      },
    );
  }
}

class _MenuHeader extends StatelessWidget {
  const _MenuHeader({
    required this.categories,
    required this.selectedCategory,
    required this.itemCount,
    required this.onCategorySelected,
  });

  final List<RestaurantMenuCategory> categories;
  final String selectedCategory;
  final int itemCount;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final tabs = <String>[
      'Все',
      ...categories.map((e) => e.title),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF489F2A), Color(0xFF3A7E21)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'jetkiz',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Управление меню',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$itemCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final tab = tabs[index];
                final selected = selectedCategory == tab;

                return GestureDetector(
                  onTap: () => onCategorySelected(tab),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFF489F2A)
                            : Colors.white.withValues(alpha: 0.92),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
