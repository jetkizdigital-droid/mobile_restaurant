import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jetkiz_restaurant/core/localization/app_locale_controller.dart';
import 'package:jetkiz_restaurant/features/restaurant_profile/data/restaurant_staff_api.dart';

class RestaurantStaffManagementPage extends StatefulWidget {
  const RestaurantStaffManagementPage({super.key});

  @override
  State<RestaurantStaffManagementPage> createState() =>
      _RestaurantStaffManagementPageState();
}

class _RestaurantStaffManagementPageState
    extends State<RestaurantStaffManagementPage> {
  final RestaurantStaffApi _api = RestaurantStaffApi();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _employees = const [];
  List<Map<String, dynamic>> _branches = const [];

  String _t(String ru, String kk) => context.tr(ru, kk);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final result = await _api.list();
      final employees = result['items'];
      final branches = result['branches'];
      if (!mounted) return;
      setState(() {
        _employees = employees is List
            ? employees
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : const [];
        _branches = branches is List
            ? branches
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : const [];
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = _t(
              'Не удалось загрузить сотрудников. Проверьте интернет и повторите.',
              'Қызметкерлерді жүктеу мүмкін болмады. Интернетті тексеріп, қайталаңыз.',
            ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _temporaryPassword() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _create() async {
    if (_branches.isEmpty) {
      _message(_t('Нет доступных филиалов.', 'Қолжетімді филиал жоқ.'));
      return;
    }
    final temp = _temporaryPassword();
    final value = await showModalBottomSheet<_StaffFormValue>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      builder: (_) => _StaffForm(
        branches: _branches,
        temporaryPassword: temp,
      ),
    );
    if (value == null) return;

    try {
      final result = await _api.create(
        phone: value.phone,
        firstName: value.firstName,
        lastName: value.lastName,
        role: value.role,
        restaurantIds: value.restaurantIds,
        temporaryPassword: temp,
      );
      if (!mounted) return;
      final userId = result['id']?.toString().trim() ?? '';
      final issued = result['temporaryPasswordIssued'] == true;
      final mode = result['credentialsMode']?.toString() ?? '';
      if (issued) {
        await _showPassword(temp);
      } else if (mode == 'EXISTING_TEMPORARY_PASSWORD' && userId.isNotEmpty) {
        final reset = await _confirm(
          _t('У сотрудника уже есть временный пароль. Выдать новый?',
              'Қызметкерде уақытша құпиясөз бар. Жаңасын беру керек пе?'),
        );
        if (reset) await _resetPassword(userId);
      } else {
        _message(_t(
          'Сотрудник добавлен. Он войдёт со своим действующим паролем JETKIZ.',
          'Қызметкер қосылды. Ол қолданыстағы JETKIZ құпиясөзімен кіреді.',
        ));
      }
      await _load();
    } catch (_) {
      _message(_t('Не удалось добавить сотрудника.',
          'Қызметкерді қосу мүмкін болмады.'));
    }
  }

  Future<void> _edit(Map<String, dynamic> employee) async {
    final id = employee['id']?.toString().trim() ?? '';
    if (id.isEmpty) return;
    final value = await showModalBottomSheet<_StaffFormValue>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      builder: (_) => _StaffForm(
        branches: _branches,
        existing: employee,
      ),
    );
    if (value == null) return;
    try {
      await _api.update(
        userId: id,
        firstName: value.firstName,
        // Empty string is intentional: it clears an existing surname.
        lastName: value.lastName ?? '',
        role: value.role,
        restaurantIds: value.restaurantIds,
        isActive: value.isActive,
      );
      await _load();
      _message(_t('Изменения сохранены.', 'Өзгерістер сақталды.'));
    } catch (_) {
      _message(_t('Не удалось сохранить изменения.',
          'Өзгерістерді сақтау мүмкін болмады.'));
    }
  }

  Future<void> _deactivate(Map<String, dynamic> employee) async {
    final id = employee['id']?.toString().trim() ?? '';
    if (id.isEmpty) return;
    final yes = await _confirm(_t(
      'Отключить сотрудника? Его активные сессии будут завершены.',
      'Қызметкерді өшіру керек пе? Оның белсенді сессиялары аяқталады.',
    ));
    if (!yes) return;
    try {
      await _api.deactivate(id);
      await _load();
      _message(_t('Сотрудник отключён.', 'Қызметкер өшірілді.'));
    } catch (_) {
      _message(_t('Не удалось отключить сотрудника.',
          'Қызметкерді өшіру мүмкін болмады.'));
    }
  }

  Future<void> _resetPassword(String userId) async {
    final password = _temporaryPassword();
    try {
      await _api.resetTemporaryPassword(
        userId: userId,
        temporaryPassword: password,
      );
      if (mounted) await _showPassword(password);
      await _load();
    } catch (_) {
      _message(_t('Не удалось выдать новый временный пароль.',
          'Жаңа уақытша құпиясөзді беру мүмкін болмады.'));
    }
  }

  Future<bool> _confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF111827),
          content: Text(text, style: const TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_t('Отмена', 'Бас тарту')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(_t('Подтвердить', 'Растау')),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _showPassword(String password) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text(_t('Временный пароль', 'Уақытша құпиясөз'),
            style: const TextStyle(color: Colors.white)),
        content: Row(
          children: [
            Expanded(
              child: SelectableText(
                password,
                style: const TextStyle(
                  color: Color(0xFF65C044),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: password)),
              icon: const Icon(Icons.copy_rounded, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_t('Готово', 'Дайын')),
          ),
        ],
      ),
    );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String _name(Map<String, dynamic> employee) {
    final first = employee['firstName']?.toString().trim() ?? '';
    final last = employee['lastName']?.toString().trim() ?? '';
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    return employee['phone']?.toString() ?? _t('Сотрудник', 'Қызметкер');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0F1115),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F1115),
          foregroundColor: Colors.white,
          title: Text(_t('Сотрудники', 'Қызметкерлер')),
          actions: [
            TextButton(
              onPressed: AppLocaleController.instance.toggle,
              child: Text(
                context.isKazakh ? 'RU' : 'ҚАЗ',
                style: const TextStyle(
                    color: Color(0xFF65C044), fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _loading ? null : _create,
          backgroundColor: const Color(0xFF65C044),
          foregroundColor: const Color(0xFF071006),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: Text(_t('Добавить', 'Қосу')),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _body(),
        ),
      );

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 120, 24, 120),
        children: [
          Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          FilledButton(onPressed: _load, child: Text(_t('Повторить', 'Қайталау'))),
        ],
      );
    }
    if (_employees.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 120, 24, 120),
        children: [
          const Icon(Icons.groups_2_outlined,
              size: 54, color: Color(0xFF65C044)),
          const SizedBox(height: 12),
          Text(_t('Сотрудников пока нет', 'Әзірге қызметкерлер жоқ'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 19,
                  fontWeight: FontWeight.w800)),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      itemCount: _employees.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final employee = _employees[index];
        final id = employee['id']?.toString().trim() ?? '';
        final active = employee['isActive'] == true;
        final role = employee['role']?.toString().toUpperCase() == 'MANAGER'
            ? _t('Менеджер', 'Менеджер')
            : _t('Сотрудник', 'Қызметкер');
        final ids = employee['restaurantIds'];
        final branchCount = ids is List ? ids.length : 0;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF151922),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF2A303B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(_name(employee),
                    style: const TextStyle(color: Colors.white,
                        fontSize: 17, fontWeight: FontWeight.w800))),
                Text(active ? _t('Активен', 'Белсенді') : _t('Отключён', 'Өшірілген'),
                    style: TextStyle(
                        color: active ? const Color(0xFF78D65A) : const Color(0xFFFF8C96),
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              Text(employee['phone']?.toString() ?? '',
                  style: const TextStyle(color: Color(0xFFB4BECC))),
              const SizedBox(height: 6),
              Text('$role · ${_t('филиалов', 'филиал')}: $branchCount',
                  style: const TextStyle(color: Color(0xFF95A0B3))),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: () => _edit(employee),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(_t('Изменить', 'Өзгерту')),
                ),
                if (active &&
                    id.isNotEmpty &&
                    employee['mustChangePassword'] == true)
                  OutlinedButton.icon(
                    onPressed: () => _resetPassword(id),
                    icon: const Icon(Icons.password_rounded),
                    label: Text(
                      _t(
                        'Новый временный пароль',
                        'Жаңа уақытша құпиясөз',
                      ),
                    ),
                  ),
                if (active)
                  OutlinedButton.icon(
                    onPressed: () => _deactivate(employee),
                    icon: const Icon(Icons.person_off_outlined),
                    label: Text(_t('Отключить', 'Өшіру')),
                  ),
              ]),
            ],
          ),
        );
      },
    );
  }
}

class _StaffFormValue {
  const _StaffFormValue({
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.restaurantIds,
    required this.isActive,
  });
  final String phone;
  final String firstName;
  final String? lastName;
  final String role;
  final List<String> restaurantIds;
  final bool isActive;
}

class _StaffForm extends StatefulWidget {
  const _StaffForm({
    required this.branches,
    this.existing,
    this.temporaryPassword,
  });
  final List<Map<String, dynamic>> branches;
  final Map<String, dynamic>? existing;
  final String? temporaryPassword;

  @override
  State<_StaffForm> createState() => _StaffFormState();
}

class _StaffFormState extends State<_StaffForm> {
  late final TextEditingController _phone;
  late final TextEditingController _first;
  late final TextEditingController _last;
  late String _role;
  late bool _active;
  late Set<String> _restaurantIds;
  String? _error;
  bool get _editing => widget.existing != null;
  String _t(String ru, String kk) => context.tr(ru, kk);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _phone = TextEditingController(text: e?['phone']?.toString() ?? '');
    _first = TextEditingController(text: e?['firstName']?.toString() ?? '');
    _last = TextEditingController(text: e?['lastName']?.toString() ?? '');
    _role = e?['role']?.toString().toUpperCase() == 'MANAGER' ? 'MANAGER' : 'STAFF';
    _active = e?['isActive'] != false;
    _restaurantIds = <String>{
      if (e?['restaurantIds'] is List)
        ...(e!['restaurantIds'] as List)
            .map((v) => v.toString().trim())
            .where((v) => v.isNotEmpty),
    };
    if (!_editing && _restaurantIds.isEmpty && widget.branches.isNotEmpty) {
      final id = widget.branches.first['id']?.toString().trim() ?? '';
      if (id.isNotEmpty) _restaurantIds.add(id);
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  String _normalizePhone(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('8')) digits = '7${digits.substring(1)}';
    if (!digits.startsWith('7')) digits = '7$digits';
    return '+$digits';
  }

  void _submit() {
    final first = _first.text.trim();
    final last = _last.text.trim();
    final phone = _normalizePhone(_phone.text);
    if (first.isEmpty) {
      setState(() => _error = _t('Введите имя.', 'Атын енгізіңіз.'));
      return;
    }
    if (!_editing && !RegExp(r'^\+7\d{10}$').hasMatch(phone)) {
      setState(() => _error = _t('Введите корректный телефон.',
          'Телефон нөмірін дұрыс енгізіңіз.'));
      return;
    }
    if (_restaurantIds.isEmpty) {
      setState(() => _error = _t('Выберите хотя бы один филиал.',
          'Кемінде бір филиалды таңдаңыз.'));
      return;
    }
    Navigator.of(context).pop(_StaffFormValue(
      phone: phone,
      firstName: first,
      lastName: _editing ? last : (last.isEmpty ? null : last),
      role: _role,
      restaurantIds: _restaurantIds.toList(),
      isActive: _active,
    ));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 18, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_editing
                  ? _t('Изменить сотрудника', 'Қызметкерді өзгерту')
                  : _t('Новый сотрудник', 'Жаңа қызметкер'),
                  style: const TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              if (!_editing) ...[
                _field(_phone, _t('Телефон', 'Телефон'), TextInputType.phone),
                const SizedBox(height: 10),
              ],
              _field(_first, _t('Имя', 'Аты'), TextInputType.name),
              const SizedBox(height: 10),
              _field(_last, _t('Фамилия', 'Тегі'), TextInputType.name),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'STAFF', label: Text(_t('Сотрудник', 'Қызметкер'))),
                  ButtonSegment(value: 'MANAGER', label: Text(_t('Менеджер', 'Менеджер'))),
                ],
                selected: {_role},
                onSelectionChanged: (value) => setState(() => _role = value.first),
              ),
              const SizedBox(height: 14),
              Text(_t('Филиалы', 'Филиалдар'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ...widget.branches.map((branch) {
                final id = branch['id']?.toString().trim() ?? '';
                final ru = branch['nameRu']?.toString().trim() ?? '';
                final kk = branch['nameKk']?.toString().trim() ?? '';
                final title = context.isKazakh && kk.isNotEmpty ? kk : (ru.isNotEmpty ? ru : kk);
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _restaurantIds.contains(id),
                  activeColor: const Color(0xFF65C044),
                  title: Text(title.isEmpty ? _t('Филиал', 'Филиал') : title,
                      style: const TextStyle(color: Colors.white)),
                  onChanged: id.isEmpty ? null : (checked) => setState(() {
                    checked == true ? _restaurantIds.add(id) : _restaurantIds.remove(id);
                  }),
                );
              }),
              if (!_editing && widget.temporaryPassword != null) ...[
                const SizedBox(height: 10),
                Text('${_t('Временный пароль', 'Уақытша құпиясөз')}: ${widget.temporaryPassword}',
                    style: const TextStyle(color: Color(0xFF65C044), fontWeight: FontWeight.w800)),
              ],
              if (_editing)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                  title: Text(_t('Доступ сотрудника', 'Қызметкердің қолжетімділігі'),
                      style: const TextStyle(color: Colors.white)),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Color(0xFFFF8C96))),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(_editing ? _t('Сохранить', 'Сақтау') : _t('Добавить', 'Қосу')),
                ),
              ),
            ]),
          ),
        ),
      );

  Widget _field(TextEditingController controller, String label, TextInputType type) =>
      TextField(
        controller: controller,
        keyboardType: type,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF95A0B3)),
          filled: true,
          fillColor: const Color(0xFF0B1220),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
}
