import 'dart:ui';

import 'package:flutter/material.dart';
import '../../data/restaurant_menu_api.dart';

class CreateMenuCategoryPage extends StatefulWidget {
  final String restaurantId;
  final int? nextSortOrder;

  const CreateMenuCategoryPage({
    super.key,
    required this.restaurantId,
    this.nextSortOrder,
  });

  @override
  State<CreateMenuCategoryPage> createState() =>
      _CreateMenuCategoryPageState();
}

class _CreateMenuCategoryPageState extends State<CreateMenuCategoryPage> {
  final RestaurantMenuApi _api = RestaurantMenuApi();
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _nameController.text.trim();

    if (title.isEmpty) {
      setState(() {
        _errorText = 'Введите название категории';
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
        title: title,
        sortOrder: widget.nextSortOrder,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorText = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });
    }
  }

  void _close() {
    if (_isSaving) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    const cardTop = Color(0xFF172338);
    const cardBottom = Color(0xFF111A2C);
    const strokeColor = Color(0xFF2A3A57);
    const inputFill = Color(0xFF1A2740);
    const green = Color(0xFF54B52E);
    const cancel = Color(0xFF3A465B);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.45),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: 360,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [cardTop, cardBottom],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: strokeColor,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Новая категория',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: _close,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.10),
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
                        const SizedBox(height: 18),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Название категории *',
                            style: TextStyle(
                              color: Color(0xFFD2D9E6),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _nameController,
                          focusNode: _focusNode,
                          enabled: !_isSaving,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) {
                            if (_errorText != null) {
                              setState(() {
                                _errorText = null;
                              });
                            }
                          },
                          onSubmitted: (_) => _save(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Например: Десерты',
                            hintStyle: const TextStyle(
                              color: Color(0xFF8D9AB0),
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: inputFill,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: strokeColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: strokeColor,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: green,
                                width: 1.3,
                              ),
                            ),
                          ),
                        ),
                        if (_errorText != null) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _errorText!,
                              style: const TextStyle(
                                color: Color(0xFFFF7A7A),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
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
                                      borderRadius: BorderRadius.circular(14),
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
                                  onPressed: _isSaving ? null : _save,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: green,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        green.withOpacity(0.7),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Создать',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
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
          ),
        ],
      ),
    );
  }
}