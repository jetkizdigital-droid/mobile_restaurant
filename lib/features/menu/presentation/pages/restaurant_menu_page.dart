import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/widgets/jetkiz_wordmark.dart';
import 'package:jetkiz_restaurant/core/localization/app_locale_controller.dart';
import 'package:jetkiz_restaurant/core/session/restaurant_context.dart';
import 'package:jetkiz_restaurant/core/session/session_manager.dart';

import '../../data/restaurant_menu_api.dart';
import '../../domain/restaurant_menu_models.dart';
import '../widgets/menuCreateActionSheet.dart';
import '../widgets/menu_item_card.dart';
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
  List<RestaurantMenuCategory> _categories = <RestaurantMenuCategory>[];
  List<RestaurantMenuItem> _items = <RestaurantMenuItem>[];
  String? _selectedCategoryId;

  String _t(String ru, String kk) => context.tr(ru, kk);

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  String? _readId(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
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
    if (fromContext != null && fromContext.isNotEmpty) return fromContext;

    final direct = _readId(data['restaurantId']);
    if (direct != null) return direct;
    if (_looksLikeRestaurantPayload(data)) {
      final id = _readId(data['id']);
      if (id != null) return id;
    }

    for (final key in <String>['restaurant', 'ownedRestaurant', 'restaurantProfile']) {
      final value = data[key];
      if (value is Map) {
        final id = _readId(value['id']) ?? _readId(value['restaurantId']);
        if (id != null) return id;
      }
    }

    final restaurants = data['restaurants'];
    if (restaurants is List) {
      for (final value in restaurants.whereType<Map>()) {
        final id = _readId(value['id']) ?? _readId(value['restaurantId']);
        if (id != null) return id;
      }
    }

    final accesses = data['restaurantAccesses'];
    if (accesses is List) {
      for (final access in accesses.whereType<Map>()) {
        final id = _readId(access['restaurantId']);
        if (id != null) return id;
        final nested = access['restaurant'];
        if (nested is Map) {
          final nestedId =
              _readId(nested['id']) ?? _readId(nested['restaurantId']);
          if (nestedId != null) return nestedId;
        }
      }
    }
    return null;
  }

  Future<String> _getRestaurantId() async {
    final sessionId = _readId(SessionManager.restaurantId);
    if (sessionId != null) return sessionId;

    final me = await _api.getRestaurantMe();
    final id = _resolveRestaurantId(me);
    if (id == null) throw const _RestaurantNotFoundException();
    SessionManager.restaurantId = id;
    return id;
  }

  String _safeError(Object error) {
    if (error is _RestaurantNotFoundException) {
      return _t(
        'У аккаунта не найден ресторан.',
        'Аккаунтқа тіркелген мейрамхана табылмады.',
      );
    }
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    if (raw.isEmpty ||
        raw.length > 180 ||
        lower.contains('dioexception') ||
        lower.contains('socketexception') ||
        lower.contains('exception') ||
        lower.contains('backend') ||
        lower.contains('endpoint') ||
        lower.contains('status code') ||
        lower.contains('http 4') ||
        lower.contains('http 5')) {
      return _t(
        'Не удалось выполнить действие. Проверьте интернет и повторите.',
        'Әрекетті орындау мүмкін болмады. Интернетті тексеріп, қайталаңыз.',
      );
    }
    return raw;
  }

  Future<void> _loadMenu() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final restaurantId = await _getRestaurantId();
      final response = await _api.getMenu(restaurantId);
      final parsed = RestaurantMenuData.fromJson(response);
      if (!mounted) return;

      setState(() {
        _restaurantId = restaurantId;
        _categories = parsed.categories;
        _items = parsed.items;
        if (_selectedCategoryId != null &&
            !_categories.any((item) => item.id == _selectedCategoryId)) {
          _selectedCategoryId = null;
        }
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _safeError(error);
        _isLoading = false;
      });
    }
  }

  List<RestaurantMenuItem> get _filteredItems {
    final categoryId = _selectedCategoryId;
    if (categoryId == null) return _items;
    return _items.where((item) => item.categoryId == categoryId).toList();
  }

  String _categoryTitle(RestaurantMenuCategory category) {
    final primary = context.isKazakh ? category.titleKk : category.titleRu;
    final fallback = context.isKazakh ? category.titleRu : category.titleKk;
    final first = primary.trim();
    if (first.isNotEmpty) return first;
    final second = fallback.trim();
    return second.isEmpty ? _t('Без названия', 'Атаусыз') : second;
  }

  String _categoryTitleByItem(RestaurantMenuItem item) {
    for (final category in _categories) {
      if (category.id == item.categoryId) return _categoryTitle(category);
    }
    return _t('Без категории', 'Санатсыз');
  }

  String _itemTitle(RestaurantMenuItem item) {
    final primary = context.isKazakh ? item.titleKk : item.titleRu;
    final fallback = context.isKazakh ? item.titleRu : item.titleKk;
    final first = primary.trim();
    if (first.isNotEmpty) return first;
    final second = fallback.trim();
    return second.isEmpty ? _t('Блюдо', 'Тағам') : second;
  }

  Future<void> _toggleAvailability(RestaurantMenuItem item) async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) {
      _showMessage(_t('Ресторан не найден', 'Мейрамхана табылмады'));
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
        _items = _items.map((current) {
          return current.id == item.id
              ? current.copyWith(isAvailable: newValue)
              : current;
        }).toList();
      });
      _showMessage(
        newValue
            ? _t('Блюдо доступно для заказа', 'Тағам тапсырысқа қолжетімді')
            : _t('Блюдо добавлено в стоп-лист', 'Тағам стоп-параққа қосылды'),
      );
    } catch (error) {
      if (mounted) _showMessage(_safeError(error));
    }
  }

  Future<void> _deleteItem(RestaurantMenuItem item) async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) {
      _showMessage(_t('Ресторан не найден', 'Мейрамхана табылмады'));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text(_t('Удалить блюдо?', 'Тағамды жою керек пе?')),
        content: Text(
          '${_t('Удалить', 'Жою')} «${_itemTitle(item)}» ${_t('из меню?', 'мәзірден?')}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_t('Отмена', 'Бас тарту')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(_t('Удалить', 'Жою')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.deleteProduct(restaurantId, item.id);
      if (!mounted) return;
      setState(() => _items.removeWhere((current) => current.id == item.id));
      _showMessage(_t('Блюдо удалено', 'Тағам жойылды'));
    } catch (error) {
      if (mounted) _showMessage(_safeError(error));
    }
  }

  Future<void> _openCreateItem() async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) {
      _showMessage(_t('Ресторан не найден', 'Мейрамхана табылмады'));
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => UpsertMenuItemPage(restaurantId: restaurantId),
      ),
    );
    if (changed == true) await _loadMenu();
  }

  Future<void> _openCreateCategory() async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) {
      _showMessage(_t('Ресторан не найден', 'Мейрамхана табылмады'));
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreateMenuCategoryPage(
          restaurantId: restaurantId,
          nextSortOrder: _categories.length,
        ),
      ),
    );
    if (changed == true) await _loadMenu();
  }

  void _openCreateActions() {
    if ((_restaurantId ?? '').trim().isEmpty) {
      _showMessage(_t('Ресторан не найден', 'Мейрамхана табылмады'));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => MenuCreateActionSheet(
        onAddProduct: () {
          Navigator.of(sheetContext).pop();
          _openCreateItem();
        },
        onAddCategory: () {
          Navigator.of(sheetContext).pop();
          _openCreateCategory();
        },
      ),
    );
  }

  Future<void> _openEditItem(RestaurantMenuItem item) async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) {
      _showMessage(_t('Ресторан не найден', 'Мейрамхана табылмады'));
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => UpsertMenuItemPage(
          restaurantId: restaurantId,
          item: item,
        ),
      ),
    );
    if (changed == true) await _loadMenu();
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message.trim().isEmpty ? _t('Ошибка', 'Қате') : message.trim(),
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
        padding: const EdgeInsets.only(bottom: 16, right: 4),
        child: FloatingActionButton(
          onPressed: _openCreateActions,
          elevation: 0,
          backgroundColor: const Color(0xFF489F2A),
          foregroundColor: Colors.white,
          child: const Icon(Icons.add, size: 28),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _MenuHeader(
              categories: _categories,
              selectedCategoryId: _selectedCategoryId,
              itemCount: _items.length,
              onCategorySelected: (value) {
                setState(() => _selectedCategoryId = value);
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
          Center(child: CircularProgressIndicator(color: Color(0xFF489F2A))),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 140, 24, 120),
        children: [
          const Icon(Icons.error_outline, color: Color(0xFF6B7280), size: 46),
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: _loadMenu,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF489F2A),
              ),
              child: Text(_t('Повторить', 'Қайталау')),
            ),
          ),
        ],
      );
    }

    if (_filteredItems.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 120),
        children: [
          const Center(
            child: Icon(
              Icons.restaurant_menu,
              color: Color(0xFF4B5563),
              size: 54,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _t('Нет блюд', 'Тағамдар жоқ'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedCategoryId == null
                ? _t(
                    'Добавьте первое блюдо в меню',
                    'Мәзірге алғашқы тағамды қосыңыз',
                  )
                : _t(
                    'В этой категории пока нет блюд',
                    'Бұл санатта әзірге тағам жоқ',
                  ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF9CA3AF)),
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

class _RestaurantNotFoundException implements Exception {
  const _RestaurantNotFoundException();
}

class _MenuHeader extends StatelessWidget {
  const _MenuHeader({
    required this.categories,
    required this.selectedCategoryId,
    required this.itemCount,
    required this.onCategorySelected,
  });

  final List<RestaurantMenuCategory> categories;
  final String? selectedCategoryId;
  final int itemCount;
  final ValueChanged<String?> onCategorySelected;

  String _title(BuildContext context, RestaurantMenuCategory category) {
    final primary = context.isKazakh ? category.titleKk : category.titleRu;
    final fallback = context.isKazakh ? category.titleRu : category.titleKk;
    return primary.trim().isNotEmpty
        ? primary.trim()
        : fallback.trim().isNotEmpty
            ? fallback.trim()
            : context.tr('Без названия', 'Атаусыз');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF489F2A), Color(0xFF3A7E21)],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const JetkizWordmark(height: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr('Управление меню', 'Мәзірді басқару'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$itemCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final category = index == 0 ? null : categories[index - 1];
                final id = category?.id;
                final selected = selectedCategoryId == id;
                final label = category == null
                    ? context.tr('Все', 'Барлығы')
                    : _title(context, category);
                return InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onCategorySelected(id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      label,
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
