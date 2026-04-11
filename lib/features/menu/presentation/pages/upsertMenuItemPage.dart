import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:jetkiz_restaurant/core/network/api_client.dart';
import '../../data/restaurant_menu_api.dart';
import '../../domain/restaurant_menu_models.dart';

class UpsertMenuItemPage extends StatefulWidget {
  final String restaurantId;
  final RestaurantMenuItem? item;

  const UpsertMenuItemPage({
    super.key,
    required this.restaurantId,
    this.item,
  });

  @override
  State<UpsertMenuItemPage> createState() => _UpsertMenuItemPageState();
}

class _UpsertMenuItemPageState extends State<UpsertMenuItemPage> {
  final RestaurantMenuApi _api = RestaurantMenuApi();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _titleRuController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _compositionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDrink = false;
  bool _isAvailable = true;

  String? _errorText;
  String? _selectedCategoryId;
  List<RestaurantMenuCategory> _categories = [];

  File? _mainImageFile;
  final List<File> _otherImageFiles = [];

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    _fillInitialData();
    _loadCategories();
  }

  void _fillInitialData() {
    final item = widget.item;
    if (item == null) return;

    _titleRuController.text = item.titleRu;
    _weightController.text = item.weight ?? '';
    _compositionController.text = item.composition ?? '';
    _priceController.text = item.price.toString();
    _descriptionController.text = item.description ?? '';
    _selectedCategoryId = item.categoryId;
    _isDrink = item.isDrink;
    _isAvailable = item.isAvailable;
  }

  Future<void> _loadCategories() async {
    try {
      final response = await _api.getMenu(widget.restaurantId);
      final parsed = RestaurantMenuData.fromJson(response);

      if (!mounted) return;

      setState(() {
        _categories = parsed.categories;
        _selectedCategoryId ??=
            parsed.categories.isNotEmpty ? parsed.categories.first.id : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorText = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _pickMainImage() async {
    if (_isSaving) return;

    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _mainImageFile = File(picked.path);
    });
  }

  Future<void> _pickOtherImages() async {
    if (_isSaving) return;

    final picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return;

    final currentCount =
        (_mainImageFile != null ? 1 : 0) + _otherImageFiles.length;
    final available = 11 - currentCount;

    if (available <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Максимум 11 фото')),
      );
      return;
    }

    final filesToAdd = picked.take(available).map((e) => File(e.path)).toList();

    setState(() {
      _otherImageFiles.addAll(filesToAdd);
    });

    if (picked.length > available && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Можно загрузить максимум 11 фото')),
      );
    }
  }

  Future<void> _uploadPickedImages(String productId) async {
    if (_mainImageFile == null && _otherImageFiles.isEmpty) return;

    await ApiClient.instance.uploadFiles(
      '/restaurants/${widget.restaurantId}/menu/products/$productId/images',
      mainFile: _mainImageFile,
      files: _otherImageFiles,
      mainFieldName: 'main',
      filesFieldName: 'others',
    );
  }

  RestaurantMenuItem? _findCreatedItem(
    List<RestaurantMenuItem> items, {
    required String titleRu,
    required int price,
    required String categoryId,
  }) {
    final matches = items.where((item) {
      return item.titleRu.trim() == titleRu.trim() &&
          item.price == price &&
          item.categoryId == categoryId;
    }).toList();

    if (matches.isEmpty) return null;
    return matches.last;
  }

  @override
  void dispose() {
    _titleRuController.dispose();
    _weightController.dispose();
    _compositionController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final categoryId = _selectedCategoryId?.trim() ?? '';
    final titleRu = _titleRuController.text.trim();
    final weight = _weightController.text.trim();
    final composition = _compositionController.text.trim();
    final description = _descriptionController.text.trim();

    final price = int.tryParse(_priceController.text.trim());

    if (categoryId.isEmpty) {
      setState(() {
        _errorText = 'Выберите категорию';
      });
      return;
    }

    if (titleRu.isEmpty) {
      setState(() {
        _errorText = 'Введите название блюда';
      });
      return;
    }

    if (price == null || price <= 0) {
      setState(() {
        _errorText = 'Введите корректную цену';
      });
      return;
    }

    if (!_isDrink && composition.isEmpty) {
      setState(() {
        _errorText = 'Для блюда состав обязателен';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final data = <String, dynamic>{
      'categoryId': categoryId,
      'titleRu': titleRu,
      'titleKk': titleRu,
      'price': price,
      'weight': weight.isEmpty ? null : weight,
      'composition': composition.isEmpty ? null : composition,
      'description': description.isEmpty ? null : description,
      'isDrink': _isDrink,
      'isAvailable': _isAvailable,
    };

    try {
      if (_isEdit) {
        await _api.updateProduct(
          widget.restaurantId,
          widget.item!.id,
          data,
        );

        await _uploadPickedImages(widget.item!.id);
      } else {
        await _api.createProduct(
          widget.restaurantId,
          data,
        );

        if (_mainImageFile != null || _otherImageFiles.isNotEmpty) {
          final response = await _api.getMenu(widget.restaurantId);
          final parsed = RestaurantMenuData.fromJson(response);

          final createdItem = _findCreatedItem(
            parsed.items,
            titleRu: titleRu,
            price: price,
            categoryId: categoryId,
          );

          if (createdItem != null) {
            await _uploadPickedImages(createdItem.id);
          }
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorText = e.toString().replaceFirst('Exception: ', '');
        _isSaving = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });
  }

  void _close() {
    if (_isSaving) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF020817);
    const cardTop = Color(0xFF172338);
    const cardBottom = Color(0xFF111A2C);
    const stroke = Color(0xFF2A3A57);
    const field = Color(0xFF1A2740);
    const green = Color(0xFF54B52E);
    const cancel = Color(0xFF3A465B);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEdit ? 'Редактировать блюдо' : 'Добавить блюдо',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _close,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [cardTop, cardBottom],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: stroke,
                    width: 1.2,
                  ),
                ),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: green,
                        ),
                      )
                    : _errorText != null && _categories.isEmpty
                        ? _ErrorBlock(
                            message: _errorText!,
                            onRetry: _loadCategories,
                          )
                        : ScrollConfiguration(
                            behavior: const _NoScrollbarBehavior(),
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('Категория *'),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    value: _selectedCategoryId,
                                    dropdownColor: field,
                                    iconEnabledColor: Colors.white70,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: _inputDecoration(
                                      fillColor: field,
                                      borderColor: stroke,
                                    ),
                                    items: _categories
                                        .map(
                                          (e) => DropdownMenuItem<String>(
                                            value: e.id,
                                            child: Text(
                                              e.title,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: _isSaving
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _selectedCategoryId = value;
                                            });
                                          },
                                  ),
                                  const SizedBox(height: 14),

                                  _FieldLabel('Название (RU) *'),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _titleRuController,
                                    enabled: !_isSaving,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration(
                                      hintText: 'Например: Чизбургер',
                                      fillColor: field,
                                      borderColor: stroke,
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  _FieldLabel('Граммовка / Литраж'),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _weightController,
                                    enabled: !_isSaving,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration(
                                      hintText: 'Например: 350 г / 0.5 л',
                                      fillColor: field,
                                      borderColor: stroke,
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  Container(
                                    decoration: BoxDecoration(
                                      color: field,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: stroke),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Это напиток\n(состав необязателен)',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                        Switch(
                                          value: _isDrink,
                                          onChanged: _isSaving
                                              ? null
                                              : (value) {
                                                  setState(() {
                                                    _isDrink = value;
                                                  });
                                                },
                                          activeColor: green,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  _FieldLabel(_isDrink ? 'Состав' : 'Состав *'),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _compositionController,
                                    enabled: !_isSaving,
                                    maxLines: 2,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration(
                                      hintText:
                                          'Например: говядина, сыр, соус, булочка...',
                                      fillColor: field,
                                      borderColor: stroke,
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  _FieldLabel('Цена (₸) *'),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _priceController,
                                    enabled: !_isSaving,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration(
                                      hintText: '1290',
                                      fillColor: field,
                                      borderColor: stroke,
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  _FieldLabel('Описание (опционально)'),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _descriptionController,
                                    enabled: !_isSaving,
                                    maxLines: 2,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration(
                                      hintText:
                                          'Краткое описание для клиента...',
                                      fillColor: field,
                                      borderColor: stroke,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  const _SectionLabel('Главное фото'),
                                  const SizedBox(height: 8),
                                  _UploadBox(
                                    title: _mainImageFile == null
                                        ? 'Загрузить фото'
                                        : 'Фото выбрано',
                                    height: 96,
                                    onTap: _pickMainImage,
                                  ),
                                  if (_mainImageFile != null) ...[
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.file(
                                        _mainImageFile!,
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),

                                  _SectionLabel(
                                    'Дополнительные фото (${_otherImageFiles.length}/10)',
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _SmallAddPhotoBox(
                                        onTap: _pickOtherImages,
                                      ),
                                      ..._otherImageFiles.asMap().entries.map(
                                        (entry) => Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              child: Image.file(
                                                entry.value,
                                                width: 62,
                                                height: 62,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            Positioned(
                                              top: 2,
                                              right: 2,
                                              child: InkWell(
                                                onTap: _isSaving
                                                    ? null
                                                    : () {
                                                        setState(() {
                                                          _otherImageFiles
                                                              .removeAt(
                                                            entry.key,
                                                          );
                                                        });
                                                      },
                                                child: Container(
                                                  width: 18,
                                                  height: 18,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Colors.black54,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    size: 12,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  Container(
                                    decoration: BoxDecoration(
                                      color: field,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: stroke),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Доступно для заказа',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Switch(
                                          value: _isAvailable,
                                          onChanged: _isSaving
                                              ? null
                                              : (value) {
                                                  setState(() {
                                                    _isAvailable = value;
                                                  });
                                                },
                                          activeColor: green,
                                        ),
                                      ],
                                    ),
                                  ),

                                  if (_errorText != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      _errorText!,
                                      style: const TextStyle(
                                        color: Color(0xFFFF7A7A),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 48,
                                          child: ElevatedButton(
                                            onPressed: _isSaving ? null : _close,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: cancel,
                                              foregroundColor: Colors.white,
                                              disabledBackgroundColor:
                                                  cancel.withOpacity(0.7),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              elevation: 0,
                                            ),
                                            child: const Text(
                                              'Отмена',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: SizedBox(
                                          height: 48,
                                          child: ElevatedButton(
                                            onPressed:
                                                _isSaving ? null : _submit,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: green,
                                              foregroundColor: Colors.white,
                                              disabledBackgroundColor:
                                                  green.withOpacity(0.7),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              elevation: 0,
                                            ),
                                            child: _isSaving
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2.2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : Text(
                                                    _isEdit
                                                        ? 'Сохранить'
                                                        : 'Добавить',
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hintText,
    required Color fillColor,
    required Color borderColor,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF8D9AB0),
        fontSize: 14,
      ),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF54B52E),
          width: 1.2,
        ),
      ),
    );
  }
}

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFD2D9E6),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFD2D9E6),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _UploadBox extends StatelessWidget {
  final String title;
  final double height;
  final VoidCallback onTap;

  const _UploadBox({
    required this.title,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A2740),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF2A3A57),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.file_upload_outlined,
                color: Colors.white.withOpacity(0.55),
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallAddPhotoBox extends StatelessWidget {
  final VoidCallback onTap;

  const _SmallAddPhotoBox({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A2740),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF2A3A57),
            ),
          ),
          child: const Icon(
            Icons.add,
            color: Color(0xFF8D9AB0),
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBlock({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white70,
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF54B52E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}