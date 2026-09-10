import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jetkiz_restaurant/features/restaurant_profile/data/restaurant_staff_api.dart';

class RestaurantStaffPage extends StatefulWidget {
  const RestaurantStaffPage({super.key});

  @override
  State<RestaurantStaffPage> createState() => _RestaurantStaffPageState();
}

class _RestaurantStaffPageState extends State<RestaurantStaffPage> {
  final RestaurantStaffApi _api = RestaurantStaffApi();
  bool _loading = true;
  bool _kazakh = false;
  String? _error;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _branches = <Map<String, dynamic>>[];

  String _t(String ru, String kk) => _kazakh ? kk : ru;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _friendlyError(Object error, String fallbackRu, String fallbackKk) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    if (lower.contains('dioexception') ||
        lower.contains('socketexception') ||
        lower.contains('status code') ||
        lower.contains('http ')) {
      return _t(
        'Не удалось подключиться. Проверьте интернет и повторите.',
        'Қосылу мүмкін болмады. Интернетті тексеріп, қайталаңыз.',
      );
    }
    return raw.isEmpty || raw.length > 220 ? _t(fallbackRu, fallbackKk) : raw;
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await _api.list();
      final rawItems = data['items'];
      final rawBranches = data['branches'];
      if (!mounted) return;
      setState(() {
        _items = rawItems is List
            ? rawItems
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];
        _branches = rawBranches is List
            ? rawBranches
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (silent) {
        _showError(
          _friendlyError(
            error,
            'Не удалось обновить список сотрудников.',
            'Қызметкерлер тізімін жаңарту мүмкін болмады.',
          ),
        );
        return;
      }
      setState(() {
        _loading = false;
        _error = _friendlyError(
          error,
          'Не удалось загрузить сотрудников.',
          'Қызметкерлерді жүктеу мүмкін болмады.',
        );
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB3261E),
          content: Text(message),
        ),
      );
  }

  Future<void> _openCreate() async {
    if (_branches.isEmpty) {
      _showError(
        _t(
          'Нет доступных филиалов для назначения сотрудника.',
          'Қызметкерді тағайындауға қолжетімді филиал жоқ.',
        ),
      );
      return;
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      builder: (context) => _StaffEditorSheet(
        branches: _branches,
        kazakh: _kazakh,
        onCreate: (payload) async {
          await _api.create(
            phone: payload.phone,
            firstName: payload.firstName,
            lastName: payload.lastName,
            role: payload.role,
            restaurantIds: payload.restaurantIds,
            temporaryPassword: payload.temporaryPassword!,
          );
        },
      ),
    );

    if (created == true) {
      await _load(silent: true);
    }
  }

  Future<void> _openEdit(Map<String, dynamic> item) async {
    final userId = item['id']?.toString().trim() ?? '';
    if (userId.isEmpty) return;

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      builder: (context) => _StaffEditorSheet(
        branches: _branches,
        kazakh: _kazakh,
        existing: item,
        onUpdate: (payload) async {
          await _api.update(
            userId: userId,
            firstName: payload.firstName,
            lastName: payload.lastName,
            role: payload.role,
            restaurantIds: payload.restaurantIds,
            isActive: payload.isActive,
          );
        },
      ),
    );

    if (changed == true) {
      await _load(silent: true);
    }
  }

  Future<void> _deactivate(Map<String, dynamic> item) async {
    final userId = item['id']?.toString().trim() ?? '';
    if (userId.isEmpty) return;
    final name = _displayName(item);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text(
          _t('Отключить сотрудника?', 'Қызметкерді өшіру керек пе?'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          _t(
            '$name потеряет доступ ко всем назначенным филиалам. Активные сессии будут завершены.',
            '$name тағайындалған барлық филиалдарға қолжетімділігін жоғалтады. Белсенді сессиялар аяқталады.',
          ),
          style: const TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t('Отмена', 'Бас тарту')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB3261E)),
            child: Text(_t('Отключить', 'Өшіру')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.deactivate(userId);
      await _load(silent: true);
    } catch (error) {
      _showError(
        _friendlyError(
          error,
          'Не удалось отключить сотрудника.',
          'Қызметкерді өшіру мүмкін болмады.',
        ),
      );
    }
  }

  String _displayName(Map<String, dynamic> item) {
    final first = item['firstName']?.toString().trim() ?? '';
    final last = item['lastName']?.toString().trim() ?? '';
    final full = '$first $last'.trim();
    return full.isNotEmpty ? full : (item['phone']?.toString() ?? 'Сотрудник');
  }

  String _roleName(dynamic value) {
    return value?.toString() == 'MANAGER'
        ? _t('Менеджер', 'Менеджер')
        : _t('Сотрудник', 'Қызметкер');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1115),
        foregroundColor: Colors.white,
        title: Text(_t('Сотрудники', 'Қызметкерлер')),
        actions: [
          TextButton(
            onPressed: () => setState(() => _kazakh = !_kazakh),
            child: Text(
              _kazakh ? 'RU' : 'ҚАЗ',
              style: const TextStyle(
                color: Color(0xFF65C044),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _openCreate,
        backgroundColor: const Color(0xFF65C044),
        foregroundColor: const Color(0xFF071006),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(
          _t('Добавить', 'Қосу'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF65C044)),
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 48),
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _load,
            child: Text(_t('Повторить', 'Қайталау')),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.groups_2_outlined, color: Color(0xFF65C044), size: 56),
          const SizedBox(height: 14),
          Text(
            _t('Сотрудников пока нет', 'Әзірге қызметкерлер жоқ'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t(
              'Добавьте менеджера или сотрудника и выберите филиалы, к которым он получит доступ.',
              'Менеджерді немесе қызметкерді қосып, оған қолжетімді филиалдарды таңдаңыз.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF95A0B3), height: 1.4),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _items[index];
        final active = item['isActive'] == true;
        final branchCount = item['restaurantIds'] is List
            ? (item['restaurantIds'] as List).length
            : 0;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF151922),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? const Color(0xFF2A303B) : const Color(0xFF513036),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _displayName(item),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF14331D)
                          : const Color(0xFF3B1E22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      active ? _t('Активен', 'Белсенді') : _t('Отключён', 'Өшірілген'),
                      style: TextStyle(
                        color: active
                            ? const Color(0xFF78D65A)
                            : const Color(0xFFFF8C96),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                item['phone']?.toString() ?? '',
                style: const TextStyle(color: Color(0xFFB4BECC)),
              ),
              const SizedBox(height: 10),
              Text(
                '${_roleName(item['role'])} · ${_t('филиалов', 'филиал')}: $branchCount',
                style: const TextStyle(color: Color(0xFF95A0B3)),
              ),
              if (item['mustChangePassword'] == true) ...[
                const SizedBox(height: 8),
                Text(
                  _t(
                    'Ожидается смена временного пароля',
                    'Уақытша құпиясөзді ауыстыру күтілуде',
                  ),
                  style: const TextStyle(color: Color(0xFFFFC857), fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openEdit(item),
                      child: Text(_t('Изменить', 'Өзгерту')),
                    ),
                  ),
                  if (active) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _deactivate(item),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF8C96),
                        ),
                        child: Text(_t('Отключить', 'Өшіру')),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StaffEditorPayload {
  const _StaffEditorPayload({
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.restaurantIds,
    required this.isActive,
    this.temporaryPassword,
  });

  final String phone;
  final String firstName;
  final String? lastName;
  final String role;
  final List<String> restaurantIds;
  final bool isActive;
  final String? temporaryPassword;
}

class _StaffEditorSheet extends StatefulWidget {
  const _StaffEditorSheet({
    required this.branches,
    required this.kazakh,
    this.existing,
    this.onCreate,
    this.onUpdate,
  });

  final List<Map<String, dynamic>> branches;
  final bool kazakh;
  final Map<String, dynamic>? existing;
  final Future<void> Function(_StaffEditorPayload payload)? onCreate;
  final Future<void> Function(_StaffEditorPayload payload)? onUpdate;

  @override
  State<_StaffEditorSheet> createState() => _StaffEditorSheetState();
}

class _StaffEditorSheetState extends State<_StaffEditorSheet> {
  late final TextEditingController _phone;
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _temporaryPassword;
  late String _role;
  late Set<String> _selectedBranches;
  late bool _active;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.existing != null;
  String _t(String ru, String kk) => widget.kazakh ? kk : ru;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _phone = TextEditingController(text: existing?['phone']?.toString() ?? '');
    _firstName = TextEditingController(text: existing?['firstName']?.toString() ?? '');
    _lastName = TextEditingController(text: existing?['lastName']?.toString() ?? '');
    _temporaryPassword = TextEditingController(text: _generatePassword());
    _role = existing?['role']?.toString() == 'MANAGER' ? 'MANAGER' : 'STAFF';
    _active = existing?['isActive'] != false;
    _selectedBranches = <String>{
      if (existing?['restaurantIds'] is List)
        ...(existing!['restaurantIds'] as List)
            .map((id) => id.toString())
            .where((id) => id.isNotEmpty),
    };
    if (!_editing && widget.branches.isNotEmpty) {
      _selectedBranches.add(widget.branches.first['id'].toString());
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _temporaryPassword.dispose();
    super.dispose();
  }

  String _generatePassword() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final random = Random.secure();
    return List.generate(6, (_) => alphabet[random.nextInt(alphabet.length)]).join();
  }

  String _normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    var normalized = digits;
    if (normalized.startsWith('8')) normalized = '7${normalized.substring(1)}';
    if (!normalized.startsWith('7')) normalized = '7$normalized';
    if (normalized.length > 11) normalized = normalized.substring(0, 11);
    return '+$normalized';
  }

  Future<void> _save() async {
    final firstName = _firstName.text.trim();
    final phone = _normalizePhone(_phone.text);
    final password = _temporaryPassword.text;

    if (firstName.isEmpty || (!_editing && !RegExp(r'^\+7\d{10}$').hasMatch(phone))) {
      setState(() => _error = _t('Проверьте имя и телефон.', 'Аты-жөні мен телефонды тексеріңіз.'));
      return;
    }
    if (_selectedBranches.isEmpty) {
      setState(() => _error = _t('Выберите хотя бы один филиал.', 'Кемінде бір филиалды таңдаңыз.'));
      return;
    }
    if (!_editing && (password.length != 6 || password.contains(RegExp(r'\s')))) {
      setState(() => _error = _t('Временный пароль — ровно 6 символов без пробелов.', 'Уақытша құпиясөз — бос орынсыз дәл 6 таңба.'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = _StaffEditorPayload(
      phone: phone,
      firstName: firstName,
      lastName: _lastName.text.trim().isEmpty ? null : _lastName.text.trim(),
      role: _role,
      restaurantIds: _selectedBranches.toList(),
      isActive: _active,
      temporaryPassword: _editing ? null : password,
    );

    try {
      if (_editing) {
        await widget.onUpdate!(payload);
      } else {
        await widget.onCreate!(payload);
      }
      if (!mounted) return;

      if (!_editing) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF111827),
            title: Text(
              _t('Сотрудник добавлен', 'Қызметкер қосылды'),
              style: const TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Передайте сотруднику временный пароль:', 'Қызметкерге уақытша құпиясөзді беріңіз:'),
                  style: const TextStyle(color: Color(0xFFCBD5E1)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        password,
                        style: const TextStyle(
                          color: Color(0xFF65C044),
                          fontSize: 24,
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
                const SizedBox(height: 8),
                Text(
                  _t(
                    'При первом входе приложение потребует создать личный пароль.',
                    'Алғашқы кіргенде қолданба жеке құпиясөз жасауды талап етеді.',
                  ),
                  style: const TextStyle(color: Color(0xFF95A0B3), fontSize: 12),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(_t('Готово', 'Дайын')),
              ),
            ],
          ),
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final raw = error.toString().replaceFirst('Exception: ', '').trim();
      setState(() => _error = raw.isEmpty ? _t('Не удалось сохранить.', 'Сақтау мүмкін болмады.') : raw);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _editing ? _t('Изменить сотрудника', 'Қызметкерді өзгерту') : _t('Новый сотрудник', 'Жаңа қызметкер'),
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 18),
              if (!_editing) ...[
                _textField(_phone, _t('Телефон', 'Телефон'), TextInputType.phone),
                const SizedBox(height: 12),
              ],
              _textField(_firstName, _t('Имя', 'Аты'), TextInputType.name),
              const SizedBox(height: 12),
              _textField(_lastName, _t('Фамилия', 'Тегі'), TextInputType.name),
              const SizedBox(height: 16),
              Text(_t('Роль', 'Рөлі'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'STAFF', label: Text(_t('Сотрудник', 'Қызметкер'))),
                  ButtonSegment(value: 'MANAGER', label: Text(_t('Менеджер', 'Менеджер'))),
                ],
                selected: {_role},
                onSelectionChanged: _saving ? null : (selection) => setState(() => _role = selection.first),
              ),
              const SizedBox(height: 18),
              Text(_t('Филиалы', 'Филиалдар'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              ...widget.branches.map((branch) {
                final id = branch['id']?.toString() ?? '';
                final ru = branch['nameRu']?.toString().trim() ?? '';
                final kk = branch['nameKk']?.toString().trim() ?? '';
                final address = branch['address']?.toString().trim() ?? '';
                final title = widget.kazakh && kk.isNotEmpty ? kk : ru;
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _selectedBranches.contains(id),
                  activeColor: const Color(0xFF65C044),
                  title: Text(title.isEmpty ? id : title, style: const TextStyle(color: Colors.white)),
                  subtitle: address.isEmpty ? null : Text(address, style: const TextStyle(color: Color(0xFF95A0B3))),
                  onChanged: _saving ? null : (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedBranches.add(id);
                      } else {
                        _selectedBranches.remove(id);
                      }
                    });
                  },
                );
              }),
              if (!_editing) ...[
                const SizedBox(height: 14),
                Text(_t('Временный пароль', 'Уақытша құпиясөз'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _textField(_temporaryPassword, '', TextInputType.visiblePassword, hideLabel: true)),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _saving ? null : () => setState(() => _temporaryPassword.text = _generatePassword()),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _t('Ровно 6 символов. После первого входа сотрудник создаст личный пароль.', 'Дәл 6 таңба. Алғашқы кіргеннен кейін қызметкер жеке құпиясөз жасайды.'),
                  style: const TextStyle(color: Color(0xFF95A0B3), fontSize: 12),
                ),
              ],
              if (_editing) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  activeThumbColor: const Color(0xFF65C044),
                  title: Text(_t('Доступ активен', 'Қолжетімділік белсенді'), style: const TextStyle(color: Colors.white)),
                  onChanged: _saving ? null : (value) => setState(() => _active = value),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFFFF8C96))),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF65C044),
                    foregroundColor: const Color(0xFF071006),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: Text(
                    _saving ? _t('Сохранение...', 'Сақталуда...') : _t('Сохранить', 'Сақтау'),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    TextInputType keyboardType, {
    bool hideLabel = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hideLabel) ...[
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: !_saving,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0B1220),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
          ),
        ),
      ],
    );
  }
}
