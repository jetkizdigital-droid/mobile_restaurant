import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jetkiz_restaurant/features/cms/data/restaurant_app_cms_session.dart';

import '../../data/restaurant_menu_api.dart';
import '../../domain/restaurant_menu_models.dart';

class UpsertMenuItemPage extends StatefulWidget {
  const UpsertMenuItemPage({
    super.key,
    required this.restaurantId,
    this.item,
  });

  final String restaurantId;
  final RestaurantMenuItem? item;

  @override
  State<UpsertMenuItemPage> createState() => _UpsertMenuItemPageState();
}

class _UpsertMenuItemPageState extends State<UpsertMenuItemPage> {
  final RestaurantMenuApi _api = RestaurantMenuApi();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _titleRuController = TextEditingController();
  final TextEditingController _titleKkController = TextEditingController();
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
  List<RestaurantMenuCategory> _categories = const [];
  List<RestaurantMenuImage> _existingImages = const [];

  File? _mainImageFile;
  final List<File> _otherImageFiles = <File>[];

  bool get _isEdit => widget.item != null;
  int get _newImagesCount =>
      (_mainImageFile == null ? 0 : 1) + _otherImageFiles.length;

  @override
  void initState() {
    super.initState();
    _fillInitialData();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleRuController.dispose();
    _titleKkController.dispose();
    _weightController.dispose();
    _compositionController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _fillInitialData() {
    final item = widget.item;
    if (item == null) return;

    _titleRuController.text = item.titleRu;
    _titleKkController.text = item.titleKk;
    _weightController.text = item.weight ?? '';
    _compositionController.text = item.composition ?? '';
    _priceController.text = item.price.toString();
    _descriptionController.text = item.description ?? '';
    _selectedCategoryId = item.categoryId;
    _isDrink = item.isDrink;
    _isAvailable = item.isAvailable;
    _existingImages = List<RestaurantMenuImage>.from(item.images);
  }

  Future<void> _loadCategories() async {
    try {
      final response = await _api.getMenu(widget.restaurantId);
      final parsed = RestaurantMenuData.fromJson(response);
      if (!mounted) return;

      setState(() {
        _categories = parsed.categories;
        if (_selectedCategoryId == null ||
            !_categories.any((item) => item.id == _selectedCategoryId)) {
          _selectedCategoryId =
              _categories.isNotEmpty ? _categories.first.id : null;
        }
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = _clean(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _pickMainImage() async {
    if (_isSaving) return;

    if (_mainImageFile == null &&
        _otherImageFiles.length >= RestaurantMenuApi.maxProductImages) {
      _message(
        'У блюда может быть максимум ${RestaurantMenuApi.maxProductImages} фото',
      );
      return;
    }

    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() => _mainImageFile = File(picked.path));
  }

  Future<void> _pickOtherImages() async {
    if (_isSaving) return;
    final picked = await _picker.pickMultiImage();
    if (picked.isEmpty || !mounted) return;

    final available = RestaurantMenuApi.maxProductImages - _newImagesCount;
    if (available <= 0) {
      _message(
        'У блюда может быть максимум ${RestaurantMenuApi.maxProductImages} фото',
      );
      return;
    }

    setState(() {
      _otherImageFiles.addAll(
        picked.take(available).map((item) => File(item.path)),
      );
    });

    if (picked.length > available) {
      _message(
        'Лишние фото не добавлены. Максимум — ${RestaurantMenuApi.maxProductImages}',
      );
    }
  }

  Future<void> _deleteExistingImage(RestaurantMenuImage image) async {
    if (!_isEdit || _isSaving) return;

    try {
      await _api.deleteImage(
        restaurantId: widget.restaurantId,
        productId: widget.item!.id,
        imageId: image.id,
      );
      if (!mounted) return;
      setState(() {
        _existingImages = _existingImages
            .where((item) => item.id != image.id)
            .toList(growable: false);
      });
    } catch (error) {
      if (mounted) _message(_clean(error));
    }
  }

  Future<void> _setExistingMain(RestaurantMenuImage image) async {
    if (!_isEdit || _isSaving || image.isMain) return;

    try {
      await _api.setMainImage(
        restaurantId: widget.restaurantId,
        productId: widget.item!.id,
        imageId: image.id,
      );
      if (!mounted) return;
      setState(() {
        _existingImages = _existingImages
            .map(
              (item) => RestaurantMenuImage(
                id: item.id,
                url: item.url,
                isMain: item.id == image.id,
              ),
            )
            .toList(growable: false);
      });
    } catch (error) {
      if (mounted) _message(_clean(error));
    }
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    final cms = RestaurantAppCmsSession.instance;
    if (!cms.featureEnabled('MENU_EDIT_ENABLED')) {
      _message(
        cms.featureReason('MENU_EDIT_ENABLED') ??
            'Редактирование меню временно недоступно',
      );
      return;
    }

    final categoryId = _selectedCategoryId?.trim() ?? '';
    final titleRu = _titleRuController.text.trim();
    final titleKk = _titleKkController.text.trim();
    final weight = _weightController.text.trim();
    final composition = _compositionController.text.trim();
    final description = _descriptionController.text.trim();
    final price = int.tryParse(_priceController.text.trim());

    String? validation;
    if (categoryId.isEmpty) {
      validation = 'Выберите категорию';
    } else if (titleRu.isEmpty) {
      validation = 'Введите название блюда на русском';
    } else if (titleKk.isEmpty) {
      validation = 'Введите название блюда на казахском';
    } else if (price == null || price <= 0) {
      validation = 'Введите корректную цену';
    } else if (!_isDrink && composition.isEmpty) {
      validation = 'Для блюда состав обязателен';
    } else if (_newImagesCount > RestaurantMenuApi.maxProductImages) {
      validation =
          'У блюда может быть максимум ${RestaurantMenuApi.maxProductImages} фото';
    }

    if (validation != null) {
      setState(() => _errorText = validation);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final data = <String, dynamic>{
      'categoryId': categoryId,
      'titleRu': titleRu,
      'titleKk': titleKk,
      'price': price,
      'weight': weight.isEmpty ? null : weight,
      'composition': composition.isEmpty ? null : composition,
      'description': description.isEmpty ? null : description,
      'isDrink': _isDrink,
    };

    try {
      String productId;
      if (_isEdit) {
        productId = widget.item!.id;
        await _api.updateProduct(widget.restaurantId, productId, data);

        if (widget.item!.isAvailable != _isAvailable) {
          if (!cms.featureEnabled('STOP_LIST_ENABLED')) {
            throw Exception(
              cms.featureReason('STOP_LIST_ENABLED') ??
                  'Стоп-лист временно недоступен',
            );
          }
          await _api.updateAvailability(
            restaurantId: widget.restaurantId,
            productId: productId,
            value: _isAvailable,
          );
        }
      } else {
        final created = await _api.createProduct(widget.restaurantId, data);
        productId = created['id']?.toString().trim() ?? '';
        if (productId.isEmpty) {
          throw Exception(
            'Блюдо создано, но сервер не вернул идентификатор. Обновите меню.',
          );
        }

        if (!_isAvailable) {
          if (!cms.featureEnabled('STOP_LIST_ENABLED')) {
            throw Exception(
              cms.featureReason('STOP_LIST_ENABLED') ??
                  'Стоп-лист временно недоступен',
            );
          }
          await _api.updateAvailability(
            restaurantId: widget.restaurantId,
            productId: productId,
            value: false,
          );
        }
      }

      if (_mainImageFile != null || _otherImageFiles.isNotEmpty) {
        // Backend requires one main image whenever the gallery is replaced.
        // If the user picked only additional photos, promote the first one.
        final mainImage =
            _mainImageFile ??
            (_otherImageFiles.isNotEmpty ? _otherImageFiles.first : null);
        final otherImages = _mainImageFile != null
            ? List<File>.from(_otherImageFiles)
            : _otherImageFiles.skip(1).toList(growable: false);

        await _api.replaceProductImages(
          restaurantId: widget.restaurantId,
          productId: productId,
          mainImage: mainImage,
          otherImages: otherImages,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = _clean(error);
        _isSaving = false;
      });
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
      backgroundColor: const Color(0xFF020817),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020817),
        elevation: 0,
        title: Text(_isEdit ? 'Редактировать блюдо' : 'Добавить блюдо'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF54B52E)),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  if (_categories.isEmpty)
                    _ErrorCard(
                      text: _errorText ??
                          'Сначала создайте хотя бы одну категорию меню',
                      onRetry: _loadCategories,
                    )
                  else ...[
                    _label('Категория *'),
                    _dropdown(),
                    _label('Название на русском *'),
                    _field(_titleRuController, 'Например: Чизбургер'),
                    _label('Название на казахском *'),
                    _field(_titleKkController, 'Мысалы: Чизбургер'),
                    _label('Граммовка / литраж'),
                    _field(_weightController, '350 г / 0.5 л'),
                    _switchCard(
                      title: 'Это напиток',
                      subtitle: 'Для напитка состав необязателен',
                      value: _isDrink,
                      onChanged: (value) => setState(() => _isDrink = value),
                    ),
                    _label(_isDrink ? 'Состав' : 'Состав *'),
                    _field(
                      _compositionController,
                      'Говядина, сыр, соус, булочка...',
                      maxLines: 3,
                    ),
                    _label('Цена (₸) *'),
                    _field(
                      _priceController,
                      '1290',
                      keyboardType: TextInputType.number,
                    ),
                    _label('Описание'),
                    _field(
                      _descriptionController,
                      'Краткое описание для клиента',
                      maxLines: 3,
                    ),
                    _switchCard(
                      title: 'Доступно для заказа',
                      subtitle: _isAvailable
                          ? 'Блюдо видно клиентам'
                          : 'Блюдо находится в стоп-листе',
                      value: _isAvailable,
                      onChanged: RestaurantAppCmsSession.instance
                              .featureEnabled('STOP_LIST_ENABLED')
                          ? (value) => setState(() => _isAvailable = value)
                          : null,
                    ),
                    if (_isEdit && _existingImages.isNotEmpty) ...[
                      _label('Текущие фото'),
                      _existingImagesGrid(),
                    ],
                    _label(_isEdit ? 'Новая галерея' : 'Фото блюда'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _isEdit
                            ? 'Если выбрать новые фото, текущая галерея будет заменена. Максимум — ${RestaurantMenuApi.maxProductImages} фото.'
                            : 'Можно добавить до ${RestaurantMenuApi.maxProductImages} фото блюда.',
                        style: const TextStyle(
                          color: Color(0xFF9AA7B9),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    _imagePickerCard(),
                    if (_errorText != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _errorText!,
                        style: const TextStyle(
                          color: Color(0xFFFF7A7A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF54B52E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isEdit
                                    ? 'Сохранить изменения'
                                    : 'Добавить блюдо',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _dropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _selectedCategoryId,
        dropdownColor: const Color(0xFF1A2740),
        decoration: _decoration(),
        items: _categories
            .map(
              (item) => DropdownMenuItem<String>(
                value: item.id,
                child: Text(item.title, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(growable: false),
        onChanged: _isSaving
            ? null
            : (value) => setState(() => _selectedCategoryId = value),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        enabled: !_isSaving,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: _decoration(hint: hint),
      ),
    );
  }

  Widget _switchCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141F34),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3A57)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF93A0B4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: const Color(0xFF54B52E),
            onChanged: _isSaving ? null : onChanged,
          ),
        ],
      ),
    );
  }

  Widget _existingImagesGrid() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _existingImages.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          final image = _existingImages[index];
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  image.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFF1A2740),
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
              Positioned(
                left: 4,
                bottom: 4,
                child: InkWell(
                  onTap: () => _setExistingMain(image),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: image.isMain
                          ? const Color(0xFF54B52E)
                          : Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      image.isMain ? Icons.star : Icons.star_border,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: InkWell(
                  onTap: () => _deleteExistingImage(image),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _imagePickerCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141F34),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A3A57)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickMainImage,
                  icon: const Icon(Icons.photo_outlined),
                  label: const Text('Главное фото'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickOtherImages,
                  icon: const Icon(Icons.collections_outlined),
                  label: const Text('Другие фото'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Выбрано: $_newImagesCount/${RestaurantMenuApi.maxProductImages}',
              style: const TextStyle(
                color: Color(0xFF93A0B4),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_mainImageFile != null) ...[
            const SizedBox(height: 10),
            _localImageTile(
              _mainImageFile!,
              label: 'Главное',
              onRemove: () => setState(() => _mainImageFile = null),
            ),
          ],
          if (_otherImageFiles.isNotEmpty) ...[
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _otherImageFiles.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final file = _otherImageFiles[index];
                return _localImageTile(
                  file,
                  onRemove: () => setState(() {
                    _otherImageFiles.removeAt(index);
                  }),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _localImageTile(
    File file, {
    String? label,
    required VoidCallback onRemove,
  }) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            width: double.infinity,
            height: label == null ? 100 : 150,
            fit: BoxFit.cover,
          ),
        ),
        if (label != null)
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF54B52E),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        Positioned(
          right: 6,
          top: 6,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  InputDecoration _decoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF6F7D91)),
      filled: true,
      fillColor: const Color(0xFF1A2740),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2A3A57)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2A3A57)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF54B52E)),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.text, required this.onRetry});

  final String text;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A3A57)),
      ),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}
