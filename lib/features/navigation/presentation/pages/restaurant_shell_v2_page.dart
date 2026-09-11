import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/localization/app_locale_controller.dart';
import 'package:jetkiz_restaurant/core/navigation/app_page_route.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/core/push/restaurant_push_notification_service.dart';
import 'package:jetkiz_restaurant/core/session/restaurant_session.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_api.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_storage.dart';
import 'package:jetkiz_restaurant/features/auth/presentation/pages/restaurant_access_choice_page.dart';
import 'package:jetkiz_restaurant/features/cms/data/restaurant_app_cms_session.dart';
import 'package:jetkiz_restaurant/features/cms/domain/restaurant_app_bootstrap.dart';
import 'package:jetkiz_restaurant/features/finance/presentation/pages/restaurant_finance_page.dart';
import 'package:jetkiz_restaurant/features/menu/presentation/pages/restaurant_menu_page.dart';
import 'package:jetkiz_restaurant/features/navigation/presentation/widgets/restaurant_bottom_bar.dart';
import 'package:jetkiz_restaurant/features/orders/data/restaurant_orders_sync_bus.dart';
import 'package:jetkiz_restaurant/features/orders/presentation/pages/restaurant_orders_localized_page.dart'
    as orders_page;
import 'package:jetkiz_restaurant/features/restaurant/data/restaurant_api.dart';
import 'package:jetkiz_restaurant/features/restaurant/domain/restaurant_profile_data.dart';
import 'package:jetkiz_restaurant/features/restaurant/presentation/widgets/restaurant_operational_banner.dart';
import 'package:jetkiz_restaurant/features/restaurant_profile/presentation/pages/restaurant_profile_access_page.dart';
import 'package:jetkiz_restaurant/features/support/presentation/pages/restaurant_support_page.dart';

class RestaurantShellPage extends StatefulWidget {
  const RestaurantShellPage({
    super.key,
    this.initialTab = RestaurantBottomBarTab.orders,
  });

  final RestaurantBottomBarTab initialTab;

  @override
  State<RestaurantShellPage> createState() => _RestaurantShellPageState();
}

class _RestaurantShellPageState extends State<RestaurantShellPage>
    with WidgetsBindingObserver {
  static const _owner = 'OWNER';
  static const _manager = 'MANAGER';
  static const _staff = 'STAFF';
  static const _managerTabs = <RestaurantBottomBarTab>[
    RestaurantBottomBarTab.orders,
    RestaurantBottomBarTab.menu,
    RestaurantBottomBarTab.profile,
    RestaurantBottomBarTab.finance,
    RestaurantBottomBarTab.support,
  ];
  static const _staffTabs = <RestaurantBottomBarTab>[
    RestaurantBottomBarTab.orders,
  ];

  late RestaurantBottomBarTab _currentTab;
  StreamSubscription<void>? _sessionExpiredSubscription;
  Timer? _ordersRefreshTimer;
  bool _openingLogin = false;
  bool _loggingOut = false;
  bool _updating = false;
  String _role = 'UNKNOWN';
  RestaurantProfileData? _profile;
  RestaurantAppBootstrap? _cms;
  List<_StaffBranch> _branches = const [];
  String? _selectedRestaurantId;

  bool get _isOwner => _role == _owner;
  bool get _isManager => _role == _owner || _role == _manager;
  bool get _isStaff => _role == _staff;
  List<RestaurantBottomBarTab> get _visibleTabs =>
      _isManager ? _managerTabs : _staffTabs;
  String _t(String ru, String kk) => context.tr(ru, kk);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentTab = widget.initialTab;
    _sessionExpiredSubscription = ApiClient.instance.sessionExpiredEvents
        .listen((_) => _openLogin());
    _ordersRefreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshOrders(),
    );
    unawaited(RestaurantPushNotificationService.instance.markNavigationReady());
    unawaited(RestaurantPushNotificationService.instance.registerCurrentToken(
      requestPermissionIfNeeded: true,
    ));
    unawaited(_loadRestaurant());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ordersRefreshTimer?.cancel();
    _sessionExpiredSubscription?.cancel();
    RestaurantPushNotificationService.instance.markNavigationUnavailable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(RestaurantPushNotificationService.instance.markAppOpened());
    unawaited(RestaurantPushNotificationService.instance.markNavigationReady());
    unawaited(RestaurantPushNotificationService.instance.registerCurrentToken(
      requestPermissionIfNeeded: false,
    ));
    unawaited(_loadRestaurant());
    _refreshOrders();
  }

  void _refreshOrders() {
    if (mounted && _currentTab == RestaurantBottomBarTab.orders) {
      RestaurantOrdersSyncBus.instance.requestRefresh();
    }
  }

  Future<void> _loadRestaurant() async {
    Map<String, dynamic>? me;
    try {
      me = await AuthApi().getMe();
    } catch (error) {
      debugPrint('Restaurant auth/me refresh failed: $error');
    }

    try {
      final restaurant = await RestaurantApi(ApiClient.instance).getMyRestaurant();
      RestaurantSession.restaurant = restaurant;

      var nextRole = _role;
      var nextBranches = _branches;
      var nextSelected = _selectedRestaurantId;
      if (me != null) {
        final parsedBranches = _parseBranches(me);
        final resolvedRole = _resolveRole(me, restaurant.id);
        if (resolvedRole != 'UNKNOWN') nextRole = resolvedRole;
        nextBranches = parsedBranches;
        nextSelected = restaurant.id;
      }

      RestaurantAppBootstrap? bootstrap;
      try {
        bootstrap = await RestaurantAppCmsSession.instance.refresh();
      } catch (_) {
        bootstrap = RestaurantAppCmsSession.instance.state.value;
      }

      if (!mounted) return;
      setState(() {
        _profile = restaurant;
        _cms = bootstrap;
        _role = nextRole;
        _branches = nextBranches;
        _selectedRestaurantId = nextSelected ?? restaurant.id;
        if (!_visibleTabs.contains(_currentTab)) {
          _currentTab = RestaurantBottomBarTab.orders;
        }
      });
    } catch (error) {
      debugPrint('Restaurant runtime refresh failed: $error');
    }
  }

  String _resolveRole(Map<String, dynamic> me, String restaurantId) {
    final accesses = me['restaurantAccesses'];
    if (accesses is! List) return 'UNKNOWN';
    for (final raw in accesses) {
      if (raw is! Map) continue;
      if ((raw['restaurantId']?.toString().trim() ?? '') != restaurantId) continue;
      final source = raw['source']?.toString().trim().toUpperCase() ?? '';
      final role = raw['role']?.toString().trim().toUpperCase() ?? '';
      if (source == _owner || role == _owner) return _owner;
      if (role == _manager) return _manager;
      if (role == _staff) return _staff;
    }
    return 'UNKNOWN';
  }

  List<_StaffBranch> _parseBranches(Map<String, dynamic> me) {
    final result = <_StaffBranch>[];
    final seen = <String>{};
    void add(String id, String? ru, String? kk) {
      final cleanId = id.trim();
      if (cleanId.isEmpty || !seen.add(cleanId)) return;
      result.add(_StaffBranch(
        id: cleanId,
        nameRu: ru?.trim() ?? '',
        nameKk: kk?.trim() ?? '',
        ordinal: result.length + 1,
      ));
    }

    final restaurants = me['restaurants'];
    if (restaurants is List) {
      for (final raw in restaurants) {
        if (raw is Map) {
          add(
            raw['id']?.toString() ?? '',
            raw['nameRu']?.toString(),
            raw['nameKk']?.toString(),
          );
        }
      }
    }
    final accesses = me['restaurantAccesses'];
    if (accesses is List) {
      for (final raw in accesses) {
        if (raw is! Map) continue;
        final nested = raw['restaurant'];
        if (nested is Map) {
          add(
            nested['id']?.toString() ?? raw['restaurantId']?.toString() ?? '',
            nested['nameRu']?.toString(),
            nested['nameKk']?.toString(),
          );
        } else {
          add(raw['restaurantId']?.toString() ?? '', null, null);
        }
      }
    }
    return result;
  }

  Future<void> _switchStaffBranch(_StaffBranch branch) async {
    if (_selectedRestaurantId == branch.id) return;
    try {
      await ApiClient.instance.setSelectedRestaurantId(branch.id);
      if (!mounted) return;
      setState(() => _selectedRestaurantId = branch.id);
      await _loadRestaurant();
      _refreshOrders();
    } catch (_) {
      if (mounted) {
        _message(_t(
          'Не удалось сменить филиал. Попробуйте ещё раз.',
          'Филиалды ауыстыру мүмкін болмады. Қайта көріңіз.',
        ));
      }
    }
  }

  Future<void> _showStaffBranchSelector() async {
    if (_branches.length <= 1) return;
    final selected = await showModalBottomSheet<_StaffBranch>(
      context: context,
      backgroundColor: const Color(0xFF111827),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
              child: Text(
                _t('Выберите филиал', 'Филиалды таңдаңыз'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ..._branches.map((branch) => ListTile(
                  leading: Icon(
                    branch.id == _selectedRestaurantId
                        ? Icons.check_circle_rounded
                        : Icons.storefront_outlined,
                    color: const Color(0xFF65C044),
                  ),
                  title: Text(
                    branch.label(context),
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(branch),
                )),
          ],
        ),
      ),
    );
    if (selected != null && mounted) await _switchStaffBranch(selected);
  }

  void _openLogin() {
    if (!mounted || _openingLogin) return;
    _openingLogin = true;
    RestaurantSession.restaurant = null;
    RestaurantAppCmsSession.instance.clear();
    RestaurantPushNotificationService.instance.markNavigationUnavailable();
    Navigator.of(context).pushAndRemoveUntil(
      AppPageRoute<void>(page: const RestaurantAccessChoicePage()),
      (_) => false,
    );
  }

  Future<void> _logout() async {
    if (_loggingOut || _openingLogin) return;
    setState(() => _loggingOut = true);
    try {
      try {
        await RestaurantPushNotificationService.instance.unregisterCurrentToken();
      } catch (_) {}
      try {
        await AuthApi().logout();
      } catch (_) {}
      await AuthStorage().clearTokens();
      ApiClient.instance.clearSelectedRestaurantId();
      if (mounted) _openLogin();
    } finally {
      if (mounted && !_openingLogin) setState(() => _loggingOut = false);
    }
  }

  Future<void> _setAcceptingOrders(bool value) async {
    if (_updating || !_isManager) return;
    final cms = _cms;
    if (cms != null && !cms.featureEnabled('ACCEPT_ORDERS_ENABLED')) {
      _message(cms?.featureReason(
            'ACCEPT_ORDERS_ENABLED',
            kazakh: context.isKazakh,
          ) ??
          _t(
            'Приём заказов временно недоступен',
            'Тапсырыс қабылдау уақытша қолжетімсіз',
          ));
      return;
    }
    if (value) {
      final ready = await RestaurantPushNotificationService.instance
          .ensureOrderNotificationsReady(requestPermissionIfNeeded: true);
      if (!ready) {
        if (mounted) await _showNotificationRequiredDialog();
        return;
      }
    }
    if (!mounted) return;
    setState(() => _updating = true);
    try {
      final latest = await RestaurantApi(ApiClient.instance).setAcceptingOrders(value);
      RestaurantSession.restaurant = latest;
      if (!mounted) return;
      setState(() => _profile = latest);
      _message(value
          ? _t('Приём заказов включён', 'Тапсырыс қабылдау қосылды')
          : _t('Приём заказов приостановлен', 'Тапсырыс қабылдау тоқтатылды'));
    } catch (_) {
      if (mounted) {
        _message(_t(
          'Не удалось изменить приём заказов. Проверьте интернет и повторите.',
          'Тапсырыс қабылдау күйін өзгерту мүмкін болмады. Интернетті тексеріп, қайталаңыз.',
        ));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _showNotificationRequiredDialog() => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF111827),
          title: Text(
            _t('Включите уведомления', 'Хабарландыруларды қосыңыз'),
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            _t(
              'JETKIZ не включит приём заказов, пока устройство не сможет получать уведомления о новых заказах. Проверьте разрешение и канал «Новые заказы».',
              'Құрылғы жаңа тапсырыстар туралы хабарландыруларды ала алмайынша JETKIZ тапсырыс қабылдауды қоспайды. Рұқсат пен «Жаңа тапсырыстар» арнасын тексеріңіз.',
            ),
            style: const TextStyle(color: Color(0xFFCBD5E1)),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_t('Понятно', 'Түсінікті')),
            ),
          ],
        ),
      );

  Future<void> _resubmit() async {
    if (_updating || !_isOwner) return;
    setState(() => _updating = true);
    try {
      final latest = await RestaurantApi(ApiClient.instance).resubmitForReview();
      RestaurantSession.restaurant = latest;
      if (mounted) {
        setState(() => _profile = latest);
        _message(_t(
          'Заявка повторно отправлена на модерацию',
          'Өтінім модерацияға қайта жіберілді',
        ));
      }
    } catch (_) {
      if (mounted) {
        _message(_t(
          'Не удалось отправить заявку. Проверьте интернет и повторите.',
          'Өтінімді жіберу мүмкін болмады. Интернетті тексеріп, қайталаңыз.',
        ));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _selectTab(RestaurantBottomBarTab tab) {
    if (!_visibleTabs.contains(tab) || tab == _currentTab) return;
    setState(() => _currentTab = tab);
    if (tab == RestaurantBottomBarTab.orders) _refreshOrders();
    unawaited(_loadRestaurant());
  }

  Widget _buildPage() {
    if (!_visibleTabs.contains(_currentTab)) {
      return const orders_page.RestaurantOrdersPage(hideBottomBar: true);
    }
    switch (_currentTab) {
      case RestaurantBottomBarTab.orders:
        return const orders_page.RestaurantOrdersPage(hideBottomBar: true);
      case RestaurantBottomBarTab.menu:
        return const RestaurantMenuPage();
      case RestaurantBottomBarTab.profile:
        return RestaurantProfileAccessPage(
          isOwner: _isOwner,
          loggingOut: _loggingOut,
          onLogout: _logout,
        );
      case RestaurantBottomBarTab.finance:
        if (_cms?.featureEnabled('FINANCE_VIEW_ENABLED') == false) {
          return _Unavailable(
            title: _t('Финансы временно недоступны', 'Қаржы уақытша қолжетімсіз'),
          );
        }
        return const RestaurantFinancePage();
      case RestaurantBottomBarTab.support:
        return const RestaurantSupportPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final maintenance = _cms?.maintenance;
    if (maintenance?.blocksApp == true) {
      return _MaintenanceGate(
        title: _localized(maintenance?.titleRu, maintenance?.titleKk) ??
            _t('Технические работы', 'Техникалық жұмыстар'),
        body: _localized(maintenance?.bodyRu, maintenance?.bodyKk) ??
            _t(
              'Приложение временно недоступно. Попробуйте позже.',
              'Қосымша уақытша қолжетімсіз. Кейінірек қайталап көріңіз.',
            ),
        onRetry: _loadRestaurant,
        onLogout: _logout,
        loggingOut: _loggingOut,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: SafeArea(
        child: Column(
          children: [
            if (maintenance?.isSoft == true)
              _SoftMaintenance(
                text: _localized(maintenance?.titleRu, maintenance?.titleKk) ??
                    _t(
                      'Возможны временные ограничения',
                      'Уақытша шектеулер болуы мүмкін',
                    ),
              ),
            if (!_isManager) _buildStaffBar(),
            if (_profile != null && _isManager)
              RestaurantOperationalBanner(
                profile: _profile!,
                isUpdating: _updating,
                onAcceptingOrdersChanged: _setAcceptingOrders,
                onResubmit: _isOwner ? () => unawaited(_resubmit()) : null,
              ),
            Expanded(child: _buildPage()),
          ],
        ),
      ),
      bottomNavigationBar: RestaurantBottomBar(
        currentTab: _currentTab,
        visibleTabs: _visibleTabs,
        onTabSelected: _selectTab,
      ),
    );
  }

  Widget _buildStaffBar() {
    _StaffBranch? current;
    for (final branch in _branches) {
      if (branch.id == _selectedRestaurantId) {
        current = branch;
        break;
      }
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront_rounded, color: Color(0xFF65C044), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: _branches.length > 1 ? _showStaffBranchSelector : null,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      current?.label(context) ?? _t('Рабочий филиал', 'Жұмыс филиалы'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_branches.length > 1)
                    const Icon(Icons.expand_more_rounded, color: Colors.white70),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: _t('Выйти', 'Шығу'),
            onPressed: _loggingOut ? null : _logout,
            icon: _loggingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  String? _localized(String? ru, String? kk) {
    final primary = (context.isKazakh ? kk : ru)?.trim();
    final fallback = (context.isKazakh ? ru : kk)?.trim();
    if (primary != null && primary.isNotEmpty) return primary;
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return null;
  }
}

class _StaffBranch {
  const _StaffBranch({
    required this.id,
    required this.nameRu,
    required this.nameKk,
    required this.ordinal,
  });
  final String id;
  final String nameRu;
  final String nameKk;
  final int ordinal;

  String label(BuildContext context) {
    final primary = context.isKazakh ? nameKk : nameRu;
    final fallback = context.isKazakh ? nameRu : nameKk;
    if (primary.isNotEmpty) return primary;
    if (fallback.isNotEmpty) return fallback;
    return context.tr('Филиал $ordinal', '$ordinal-филиал');
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
}

class _SoftMaintenance extends StatelessWidget {
  const _SoftMaintenance({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 2),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF2B2412),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6B5315)),
        ),
        child: Text(text, style: const TextStyle(color: Color(0xFFF7E5A5))),
      );
}

class _MaintenanceGate extends StatelessWidget {
  const _MaintenanceGate({
    required this.title,
    required this.body,
    required this.onRetry,
    required this.onLogout,
    required this.loggingOut,
  });
  final String title;
  final String body;
  final Future<void> Function() onRetry;
  final Future<void> Function() onLogout;
  final bool loggingOut;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF09111C),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.build_circle_outlined,
                      color: Color(0xFFFFC857), size: 54),
                  const SizedBox(height: 18),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFB4BECC), height: 1.4)),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: onRetry,
                    child: Text(context.tr('Проверить снова', 'Қайта тексеру')),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: loggingOut ? null : onLogout,
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(context.tr('Выйти из аккаунта', 'Аккаунттан шығу')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
