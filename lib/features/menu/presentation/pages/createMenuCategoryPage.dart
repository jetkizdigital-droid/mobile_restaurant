import 'package:flutter/material.dart';

import '../../data/restaurant_menu_api.dart';
import '../../domain/restaurant_menu_models.dart';

class CreateMenuCategoryPage extends StatefulWidget {
  const CreateMenuCategoryPage({
    super.key,
    required this.restaurantId,
    this.nextSortOrder,
  });

  final String restaurantId;
  final int? nextSortOrder;

  @override
  State<CreateMenuCategoryPage> createState() => _CreateMenuCategoryPageState();
}

class _CreateMenuCategoryPageState extends State<CreateMenuCategoryPage> {
  final RestaurantMenuApi _api = RestaurantMenuApi();
  final TextEditingController _titleRuController = TextEditingController();
  final TextEditingController _titleKkController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorText;
  List<RestaurantMenuCategory> _categories = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleRuController.dispose();
    _titleKkController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await _api.getMenu(widget.restaurantId);
      final parsed = RestaurantMenuData.fromJson(response);
      if (!mounted) return;
      setState(() {
        _categories = parsed.categories;
        _isLoading = false;
        _errorText = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = _clean(error);
      });
    }
  }

  Future<void> _create() async {
    final titleRu = _titleRuController.text.trim();
    final titleKk = _titleKkController.text.trim();

    if (titleRu.isEmpty || titleKk.isEmpty) {
      setState(() {
        _errorText = 'Укажите название категории на русском и казахском';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await _api.createCategory(
        restaurantId: widget.restaurantId,
        titleRu: titleRu,
        titleKk: titleKk,
        sortOrder: widget.nextSortOrder ?? _categories.length,
      );

      _titleRuController.clear();
      _titleKkController.clear();
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = _clean(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _edit(RestaurantMenuCategory category) async {
    final ruController = TextEditingController(text: category.titleRu);
    final kkController = TextEditingController(text: category.titleKk);

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Изменить категорию'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogField(
              controller: ruController,
              label: 'Название на русском',
            ),
            const SizedBox(height: 12),
            _DialogField(
              controller: kkController,
              label: 'Название на казахском',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (save != true) {
      ruController.dispose();
      kkController.dispose();
      return;
    }

    final titleRu = ruController.text.trim();
    final titleKk = kkController.text.trim();
    ruController.dispose();
    kkController.dispose();

    if (titleRu.isEmpty || titleKk.isEmpty) {
      _message('Оба названия обязательны');
      return;
    }

    try {
      await _api.updateCategory(
        restaurantId: widget.restaurantId,
        categoryId: category.id,
        titleRu: titleRu,
        titleKk: titleKk,
        sortOrder: category.sortOrder,
      );
      await _load();
    } catch (error) {
      if (mounted) _message(_clean(error));
    }
  }

  Future<void> _delete(RestaurantMenuCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Удалить категорию?'),
        content: Text(
          'Категория «${category.title}» будет удалена, если в ней нет блюд.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.deleteCategory(
        restaurantId: widget.restaurantId,
        categoryId: category.id,
      );
      await _load();
    } catch (error) {
      if (mounted) _message(_clean(error));
    }
  }

  String _clean(Object error) =>
      error.toString().replaceFirst('Exception: ', '').trim();

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09111C),
        title: const Text('Категории меню'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: const Color(0xFF54B52E),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              const Text(
                'Новая категория',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _field(
                controller: _titleRuController,
                label: 'Название на русском *',
                hint: 'Например: Десерты',
              ),
              const SizedBox(height: 12),
              _field(
                controller: _titleKkController,
                label: 'Название на казахском *',
                hint: 'Мысалы: Десерттер',
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorText!,
                  style: const TextStyle(color: Color(0xFFFF7A7A)),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _create,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF54B52E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Добавить категорию',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Текущие категории',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${_categories.length}',
                    style: const TextStyle(color: Color(0xFF91A0B4)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF54B52E)),
                  ),
                )
              else if (_categories.isEmpty)
                const _EmptyCategories()
              else
                ..._categories.map(
                  (category) => _CategoryCard(
                    category: category,
                    onEdit: () => _edit(category),
                    onDelete: () => _delete(category),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          enabled: !_isSaving,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF6F7D91)),
            filled: true,
            fillColor: const Color(0xFF162035),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final RestaurantMenuCategory category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263348)),
      ),
      child: Row(
        children: [
          const Icon(Icons.category_outlined, color: Color(0xFF65C044)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.titleRu,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category.titleKk.isEmpty
                      ? 'Казахское название не указано'
                      : category.titleKk,
                  style: const TextStyle(
                    color: Color(0xFF93A0B4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: Color(0xFFFF7777)),
          ),
        ],
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Категорий пока нет',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white60),
      ),
    );
  }
}
