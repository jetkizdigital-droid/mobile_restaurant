import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _kazakh = false;
  String? _error;
  List<Map<String, dynamic>> _employees = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _branches = <Map<String, dynamic>>[];

  String _t(String ru, String kk) => _kazakh ? kk : ru;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _safeError(Object error, String fallbackRu, String fallbackKk) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    if (raw.isEmpty ||
        raw.length > 220 ||
        lower.contains('dioexception') ||
        lower.contains('socketexception') ||
        lower.contains('exception') ||
        lower.contains('backend') ||
        lower.contains('endpoint') ||
        lower.contains('status code') ||
        lower.contains('http 4') ||
        lower.contains('http 5')) {
      return _t(fallbackRu, fallbackKk);
    }
    return raw;
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
      final rawEmployees = data['items'];
      final rawBranches = data['branches'];
      if (!mounted) return;
      setState(() {
        _employees = rawEmployees is List
            ? rawEmployees
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
      final message = _safeError(
        error,
        'Не удалось загрузить сотрудников. Проверьте интернет и повторите.',
        'Қызметкерлерді жүктеу мүмкін болмады. Интернетті тексеріп, қайталаңыз.',
      );
      if (silent) {
        _showMessage(message, error: true);
      } else {
        setState(() {
          _loading = false;
          _error = message;
        });
      }
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: error ? const Color(0xFFB3261E) : null,
          content: Text(message),
        ),
      );
  }

  String _generateTemporaryPassword() {
    const alphabet =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final random = Random.secure();
    return List<String>.generate(
      6,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  Future<void> _addEmployee() async {
    if (_branches.isEmpty) {
      _showMessage(
        _t(
          'Нет доступных филиалов для назначения сотрудника.',
          'Қызметкерді тағайындауға қолжетімді филиал жоқ.',
        ),
        error: true,
      );
      return;
    }

    final form = await showModalBottomSheet<_StaffFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      builder: (_) => _StaffFormSheet(
        branches: _branches,
        kazakh: _kazakh,
        temporaryPassword: _generateTemporaryPassword(),
      ),
    );
    if (form == null) return;

    try {
      final result = await _api.create(
        phone: form.phone,
        firstName: form.firstName,
        lastName: form.lastName,
        role: form.role,
        restaurantIds: form.restaurantIds,
        temporaryPassword: form.temporaryPassword!,
      );
      if (!mounted) return;

      final issued = result['temporaryPasswordIssued'] == true;
      final mode = result['credentialsMode']?.toString().trim() ?? '';
      final userId = result['id']?.toString().trim() ?? '';

      if (issued) {
        await _showTemporaryPassword(form.temporaryPassword!);
      } else if (mode == 'EXISTING_TEMPORARY_PASSWORD') {
        await _showExistingTemporaryPassword(userId);
      } else {
        await _showExistingPersonalPassword();
      }

      await _load(silent: true);
    } catch (error) {
      _showMessage(
        _safeError(
          error,
          'Не удалось добавить сотрудника.',
          'Қызметкерді қосу мүмкін болмады.',
        ),
        error: true,
      );
    }
  }

  Future<void> _editEmployee(Map<String, dynamic> employee) async {
    final userId = employee['id']?.toString().trim() ?? '';
    if (userId.isEmpty) return;

    final form = await showModalBottomSheet<_StaffFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      builder: (_) => _StaffFormSheet(
        branches: _branches,
        kazakh: _kazakh,
        existing: employee,
      ),
    );
    if (form == null) return;

    try {
      await _api.update(
        userId: userId,
        firstName: form.firstName,
        lastName: form.lastName,
        role: form.role,
        restaurantIds: form.restaurantIds,
        isActive: form.isActive,
      );
      await _load(silent: true);
      _showMessage(
        _t('Изменения сохранены.', 'Өзгерістер сақталды.'),
      );
    } catch (error) {
      _showMessage(
        _safeError(
          error,
          'Не удалось сохранить изменения.',
          'Өзгерістерді сақтау мүмкін болмады.',
        ),
        error: true,
      );
    }
  }

  Future<void> _deactivate(Map<String, dynamic> employee) async {
    final userId = employee['id']?.toString().trim() ?? '';
    if (userId.isEmpty) return;

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
            'Доступ ко всем назначенным филиалам будет закрыт, активные сессии завершатся.',
            'Барлық тағайындалған филиалдарға қолжетімділік жабылып, белсенді сессиялар аяқталады.',
          ),
          style: const TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t('Отмена', 'Бас тарту')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_t('Отключить', 'Өшіру')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.deactivate(userId);
      await _load(silent: true);
      _showMessage(
        _t(
          'Сотрудник отключён. Его сессии завершены.',
          'Қызметкер өшірілді. Оның сессиялары аяқталды.',
        ),
      );
    } catch (error) {
      _showMessage(
        _safeError(
          error,
          'Не удалось отключить сотрудника.',
          'Қызметкерді өшіру мүмкін болмады.',
        ),
        error: true,
      );
    }
  }

  Future<void> _resetTemporaryPassword(String userId) async {
    if (userId.isEmpty) return;
    final password = _generateTemporaryPassword();

    try {
      await _api.resetTemporaryPassword(
        userId: userId,
        temporaryPassword: password,
      );
      if (!mounted) return;
      await _showTemporaryPassword(password);
      await _load(silent: true);
    } catch (error) {
      _showMessage(
        _safeError(
          error,
          'Не удалось выдать новый временный пароль.',
          'Жаңа уақытша құпиясөзді беру мүмкін болмады.',
        ),
        error: true,
      );
    }
  }

  Future<void> _showExistingTemporaryPassword(String userId) async {
    final reset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text(
          _t('Сотрудник добавлен', 'Қызметкер қосылды'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          _t(
            'У этого пользователя уже есть действующий временный пароль. Новый пароль при добавлении не заменял его. При необходимости выдайте новый временный пароль.',
            'Бұл пайдаланушыда қолданыстағы уақытша құпиясөз бар. Қосу кезінде жаңа құпиясөз оны алмастырмады. Қажет болса, жаңа уақытша құпиясөз беріңіз.',
          ),
          style: const TextStyle(color: Color(0xFFCBD5E1), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t('Готово', 'Дайын')),
          ),
          FilledButton(
            onPressed: userId.isEmpty
                ? null
                : () => Navigator.of(context).pop(true),
            child: Text(
              _t('Выдать новый пароль', 'Жаңа құпиясөз беру'),
            ),
          ),
        ],
      ),
    );

    if (reset == true && mounted) {
      await _resetTemporaryPassword(userId);
    }
  }

  Future<void> _showExistingPersonalPassword() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text(
          _t('Сотрудник добавлен', 'Қызметкер қосылды'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          _t(
            'У пользователя уже есть личный пароль JETKIZ. Вход выполняется с ним — новый временный пароль не создавался.',
            'Пайдаланушыда JETKIZ жеке құпиясөзі бар. Кіру сол құпиясөзбен орындалады — жаңа уақытша құпиясөз жасалмады.',
          ),
          style: const TextStyle(color: Color(0xFFCBD5E1), height: 1.4),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_t('Понятно', 'Түсінікті')),
          ),
        ],
      ),
    );
  }

  Future<void> _showTemporaryPassword(String password) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text(
          _t('Временный пароль', 'Уақытша құпиясөз'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t(
                'Передайте сотруднику этот пароль. При первом входе приложение потребует создать личный пароль.',
                'Бұл құпиясөзді қызметкерге беріңіз. Алғашқы кіргенде қолданба жеке құпиясөз жасауды талап етеді.',
              ),
              style: const TextStyle(color: Color(0xFFCBD5E1), height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(
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
                  tooltip: _t('Копировать', 'Көшіру'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: password));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _t('Пароль скопирован.', 'Құпиясөз көшірілді.'),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                ),
              ],
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

  String _name(Map<String, dynamic> employee) {
    final first = employee['firstName']?.toString().trim() ?? '';
    final last = employee['lastName']?.toString().trim() ?? '';
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    return employee['phone']?.toString().trim().isNotEmpty == true
        ? employee['phone'].toString().trim()
        : _t('Сотрудник', 'Қызметкер');
  }

  String _role(Map<String, dynamic> employee) {
    return employee['role']?.toString().toUpperCase() == 'MANAGER'
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
        onPressed: _loading ? null : _addEmployee,
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
        padding: const EdgeInsets.fromLTRB(24, 110, 24, 120),
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Color(0xFFEF4444),
          ),
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

    if (_employees.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 110, 24, 120),
        children: [
          const Icon(
            Icons.groups_2_outlined,
            size: 56,
            color: Color(0xFF65C044),
          ),
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
              'Добавьте менеджера или сотрудника и назначьте нужные филиалы.',
              'Менеджерді немесе қызметкерді қосып, қажетті филиалдарды тағайындаңыз.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF95A0B3), height: 1.4),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      itemCount: _employees.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final employee = _employees[index];
        final active = employee['isActive'] == true;
        final mustChangePassword = employee['mustChangePassword'] == true;
        final restaurantIds = employee['restaurantIds'];
        final branchCount = restaurantIds is List ? restaurantIds.length : 0;
        final userId = employee['id']?.toString().trim() ?? '';

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
                      _name(employee),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _StatusChip(
                    label: active
                        ? _t('Активен', 'Белсенді')
                        : _t('Отключён', 'Өшірілген'),
                    active: active,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                employee['phone']?.toString() ?? '',
                style: const TextStyle(color: Color(0xFFB4BECC)),
              ),
              const SizedBox(height: 8),
              Text(
                '${_role(employee)} · ${_t('филиалов', 'филиал')}: $branchCount',
                style: const TextStyle(color: Color(0xFF95A0B3)),
              ),
              if (mustChangePassword) ...[
                const SizedBox(height: 8),
                Text(
                  _t(
                    'Ожидается смена временного пароля',
                    'Уақытша құпиясөзді ауыстыру күтілуде',
                  ),
                  style: const TextStyle(
                    color: Color(0xFFFFC857),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _editEmployee(employee),
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: Text(_t('Изменить', 'Өзгерту')),
                  ),
                  if (mustChangePassword && userId.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _resetTemporaryPassword(userId),
                      icon: const Icon(Icons.password_rounded, size: 17),
                      label: Text(
                        _t('Новый временный пароль', 'Жаңа уақытша құпиясөз'),
                      ),
                    ),
                  if (active)
                    OutlinedButton.icon(
                      onPressed: () => _deactivate(employee),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF8C96),
                      ),
                      icon: const Icon(Icons.person_off_outlined, size: 17),
                      label: Text(_t('Отключить', 'Өшіру')),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF14331D) : const Color(0xFF3B1E22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? const Color(0xFF78D65A) : const Color(0xFFFF8C96),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StaffFormResult {
  const _StaffFormResult({
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

class _StaffFormSheet extends StatefulWidget {
  const _StaffFormSheet({
    required this.branches,
    required this.kazakh,
    this.existing,
    this.temporaryPassword,
  });

  final List<Map<String, dynamic>> branches;
  final bool kazakh;
  final Map<String, dynamic>? existing;
  final String? temporaryPassword;

  @override
  State<_StaffFormSheet> createState() => _StaffFormSheetState();
}

class _StaffFormSheetState extends State<_StaffFormSheet> {
  late final TextEditingController _phone;
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _temporaryPassword;
  late String _role;
  late bool _active;
  late Set<String> _restaurantIds;
  String? _error;

  bool get _editing => widget.existing != null;
  String _t(String ru, String kk) => widget.kazakh ? kk : ru;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _phone = TextEditingController(text: existing?['phone']?.toString() ?? '');
    _firstName = TextEditingController(
      text: existing?['firstName']?.toString() ?? '',
    );
    _lastName = TextEditingController(
      text: existing?['lastName']?.toString() ?? '',
    );
    _temporaryPassword = TextEditingController(
      text: widget.temporaryPassword ?? '',
    );
    _role = existing?['role']?.toString().toUpperCase() == 'MANAGER'
        ? 'MANAGER'
        : 'STAFF';
    _active = existing?['isActive'] != false;
    _restaurantIds = <String>{
      if (existing?['restaurantIds'] is List)
        ...(existing!['restaurantIds'] as List)
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty),
    };
    if (!_editing && _restaurantIds.isEmpty) {
      final firstId = widget.branches.firstOrNull?['id']?.toString().trim() ?? '';
      if (firstId.isNotEmpty) _restaurantIds.add(firstId);
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

  String _normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    var normalized = digits;
    if (normalized.startsWith('8')) {
      normalized = '7${normalized.substring(1)}';
    }
    if (!normalized.startsWith('7')) normalized = '7$normalized';
    if (normalized.length > 11) normalized = normalized.substring(0, 11);
    return '+$normalized';
  }

  void _submit() {
    final firstName = _firstName.text.trim();
    final phone = _normalizePhone(_phone.text);
    final password = _temporaryPassword.text;

    if (firstName.isEmpty) {
      setState(() => _error = _t('Введите имя.', 'Атын енгізіңіз.'));
      return;
    }
    if (!_editing && !RegExp(r'^\+7\d{10}$').hasMatch(phone)) {
      setState(
        () => _error = _t(
          'Введите корректный номер телефона.',
          'Телефон нөмірін дұрыс енгізіңіз.',
        ),
      );
      return;
    }
    if (_restaurantIds.isEmpty) {
      setState(
        () => _error = _t(
          'Выберите хотя бы один филиал.',
          'Кемінде бір филиалды таңдаңыз.',
        ),
      );
      return;
    }
    if (!_editing &&
        (password.length != 6 || RegExp(r'\s').hasMatch(password))) {
      setState(
        () => _error = _t(
          'Временный пароль должен содержать ровно 6 символов без пробелов.',
          'Уақытша құпиясөз бос орынсыз дәл 6 таңбадан тұруы керек.',
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _StaffFormResult(
        phone: phone,
        firstName: firstName,
        lastName: _lastName.text.trim().isEmpty ? null : _lastName.text.trim(),
        role: _role,
        restaurantIds: _restaurantIds.toList(),
        isActive: _active,
        temporaryPassword: _editing ? null : password,
      ),
    );
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
                _editing
                    ? _t('Изменить сотрудника', 'Қызметкерді өзгерту')
                    : _t('Новый сотрудник', 'Жаңа қызметкер'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              if (!_editing) ...[
                _field(
                  controller: _phone,
                  label: _t('Телефон', 'Телефон'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
              ],
              _field(
                controller: _firstName,
                label: _t('Имя', 'Аты'),
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _lastName,
                label: _t('Фамилия', 'Тегі'),
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 18),
              Text(
                _t('Роль', 'Рөлі'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment<String>(
                    value: 'STAFF',
                    label: Text(_t('Сотрудник', 'Қызметкер')),
                  ),
                  ButtonSegment<String>(
                    value: 'MANAGER',
                    label: Text(_t('Менеджер', 'Менеджер')),
                  ),
                ],
                selected: <String>{_role},
                onSelectionChanged: (selection) {
                  setState(() => _role = selection.first);
                },
              ),
              const SizedBox(height: 18),
              Text(
                _t('Филиалы', 'Филиалдар'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              ...widget.branches.map((branch) {
                final id = branch['id']?.toString().trim() ?? '';
                if (id.isEmpty) return const SizedBox.shrink();
                final ru = branch['nameRu']?.toString().trim() ?? '';
                final kk = branch['nameKk']?.toString().trim() ?? '';
                final address = branch['address']?.toString().trim() ?? '';
                final title = widget.kazakh && kk.isNotEmpty ? kk : ru;
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _restaurantIds.contains(id),
                  activeColor: const Color(0xFF65C044),
                  title: Text(
                    title.isEmpty ? _t('Филиал', 'Филиал') : title,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: address.isEmpty
                      ? null
                      : Text(
                          address,
                          style: const TextStyle(color: Color(0xFF95A0B3)),
                        ),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _restaurantIds.add(id);
                      } else {
                        _restaurantIds.remove(id);
                      }
                    });
                  },
                );
              }),
              if (!_editing) ...[
                const SizedBox(height: 16),
                _field(
                  controller: _temporaryPassword,
                  label: _t('Временный пароль', 'Уақытша құпиясөз'),
                  keyboardType: TextInputType.visiblePassword,
                  maxLength: 6,
                ),
                const SizedBox(height: 4),
                Text(
                  _t(
                    'Ровно 6 символов. После первого входа сотрудник создаст личный пароль.',
                    'Дәл 6 таңба. Алғашқы кіргеннен кейін қызметкер жеке құпиясөз жасайды.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF95A0B3),
                    fontSize: 12,
                  ),
                ),
              ],
              if (_editing) ...[
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                  activeTrackColor: const Color(0xFF65C044),
                  title: Text(
                    _t('Доступ сотрудника', 'Қызметкердің қолжетімділігі'),
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    _active
                        ? _t('Доступ включён', 'Қолжетімділік қосулы')
                        : _t('Доступ отключён', 'Қолжетімділік өшірулі'),
                    style: const TextStyle(color: Color(0xFF95A0B3)),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFFF8C96),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF65C044),
                    foregroundColor: const Color(0xFF071006),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: Text(
                    _editing
                        ? _t('Сохранить', 'Сақтау')
                        : _t('Добавить сотрудника', 'Қызметкерді қосу'),
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required TextInputType keyboardType,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        labelStyle: const TextStyle(color: Color(0xFF95A0B3)),
        filled: true,
        fillColor: const Color(0xFF0B1220),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF65C044)),
        ),
      ),
    );
  }
}
