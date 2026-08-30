import 'package:flutter/material.dart';
import '../../data/restaurant_menu_api.dart';

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

  bool _isSaving = false;
  String? _errorText;

  @override
  void dispose() {
    _titleRuController.dispose();
    _titleKkController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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
        sortOrder: widget.nextSortOrder,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString().replaceFirst('Exception: ', '').trim();
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09111C),
        title: const Text('Новая категория'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _field(
              controller: _titleRuController,
              label: 'Название на русском *',
              hint: 'Например: Десерты',
            ),
            const SizedBox(height: 14),
            _field(
              controller: _titleKkController,
              label: 'Название на казахском *',
              hint: 'Мысалы: Десерттер',
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                style: const TextStyle(color: Color(0xFFFF7A7A)),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
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
                        'Создать категорию',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
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
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: !_isSaving,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF6F7D91)),
            filled: true,
            fillColor: const Color(0xFF162035),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF2A3950)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF2A3950)),
            ),
          ),
        ),
      ],
    );
  }
}
