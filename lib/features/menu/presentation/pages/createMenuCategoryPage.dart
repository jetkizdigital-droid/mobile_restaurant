import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/localization/app_locale_controller.dart';

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
  State<CreateMenuCategoryPage> createState() =>
      _CreateMenuCategoryPageState();
}

class _CreateMenuCategoryPageState extends State<CreateMenuCategoryPage> {
  final RestaurantMenuApi _api = RestaurantMenuApi();
  final TextEditingController _titleRuController = TextEditingController();
  final TextEditingController _titleKkController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorText;
  List<RestaurantMenuCategory> _categories = const <RestaurantMenuCategory>[];

  String _t(String ru, String kk) => context.tr(ru, kk);

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

  String _safeError(Object error) {
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

  String _categoryName(RestaurantMenuCategory category) {
    final primary = context.isKazakh ? category.titleKk : category.titleRu;
    final fallback = context.isKazakh ? category.titleRu : category.titleKk;
    if (primary.trim().isNotEmpty) return primary.trim();
    if (fallback.trim().isNotEmpty) return fallback.trim();
    return _t('Без названия', 'Атаусыз');
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
        _errorText = _safeError(error);
      });
    }
  }

  Future<void> _create() async {
    final titleRu = _titleRuController.text.trim();
    final titleKk = _titleKkController.text.trim();
    if (titleRu.isEmpty || titleKk.isEmpty) {
      setState(() {
        _errorText = _t(
          'Укажите название категории на русском и казахском.',
          'Санат атауын орыс және қазақ тілдерінде көрсетіңіз.',
        );
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
      if (mounted) {
        _message(_t('Категория добавлена', 'Санат қосылды'));
      }
    } catch (error) {
      if (mounted) setState(() => _errorText = _safeError(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _edit(RestaurantMenuCategory category) async {
    final ruController = TextEditingController(text: category.titleRu);
    final kkController = TextEditingController(text: category.titleKk);

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text(_t('Изменить категорию', 'Санатты өзгерту')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogField(
              controller: ruController,
              label: _t('Название на русском', 'Орысша атауы'),
            ),
            const SizedBox(height: 12),
            _DialogField(
              controller: kkController,
              label: _t('Название на казахском', 'Қазақша атауы'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_t('Отмена', 'Бас тарту')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(_t('Сохранить', 'Сақтау')),
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
      _message(
        _t(
          'Оба названия обязательны.',
          'Екі тілдегі атау да міндетті.',
        ),
      );
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
      if (mounted) _message(_t('Категория сохранена', 'Санат сақталды'));
    } catch (error) {
      if (mounted) _message(_safeError(error));
    }
  }

  Future<void> _delete(RestaurantMenuCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text(_t('Удалить категорию?', 'Санатты жою керек пе?')),
        content: Text(
          '${_t('Категория', 'Санат')} «${_categoryName(category)}» ${_t('будет удалена, если в ней нет блюд.', 'ішінде тағам болмаса жойылады.')}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_t('Отмена', 'Бас тарту')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(_t('Удалить', 'Жою')),
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
      if (mounted) _message(_t('Категория удалена', 'Санат жойылды'));
    } catch (error) {
      if (mounted) _message(_safeError(error));
    }
  }

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
        title: Text(_t('Категории меню', 'Мәзір санаттары')),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: const Color(0xFF54B52E),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Text(
                _t('Новая категория', 'Жаңа санат'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _field(
                controller: _titleRuController,
                label: _t('Название на русском *', 'Орысша атауы *'),
                hint: _t('Например: Десерты', 'Мысалы: Десерты'),
              ),
              const SizedBox(height: 12),
              _field(
                controller: _titleKkController,
                label: _t('Название на казахском *', 'Қазақша атауы *'),
                hint: _t('Например: Десерттер', 'Мысалы: Десерттер'),
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
                child: FilledButton(
                  onPressed: _isSaving ? null : _create,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF54B52E),
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
                      : Text(
                          _t('Добавить категорию', 'Санат қосу'),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _t('Текущие категории', 'Қазіргі санаттар'),
                      style: const TextStyle(
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
                _EmptyCategories(
                  text: _t('Категорий пока нет', 'Әзірге санаттар жоқ'),
                )
              else
                ..._categories.map(
                  (category) => _CategoryCard(
                    category: category,
                    displayName: _categoryName(category),
                    languageHint: context.isKazakh
                        ? (category.titleRu.trim().isEmpty
                            ? _t('Русское название не указано', 'Орысша атауы көрсетілмеген')
                            : category.titleRu.trim())
                        : (category.titleKk.trim().isEmpty
                            ? _t('Казахское название не указано', 'Қазақша атауы көрсетілмеген')
                            : category.titleKk.trim()),
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
    required this.displayName,
    required this.languageHint,
    required this.onEdit,
    required this.onDelete,
  });

  final RestaurantMenuCategory category;
  final String displayName;
  final String languageHint;
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
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  languageHint,
                  style: const TextStyle(
                    color: Color(0xFF93A0B4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('Изменить', 'Өзгерту'),
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: context.tr('Удалить', 'Жою'),
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
  const _EmptyCategories({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white60),
      ),
    );
  }
}
