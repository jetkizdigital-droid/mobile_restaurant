import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  static const String _roleOwner = 'OWNER';
  static const String _roleManager = 'MANAGER';
  static const String _roleStaff = 'STAFF';

  late RestaurantBottomBarTab _currentTab;
  StreamSubscription<void>? _sessionExpiredSubscription;
  Timer? _ordersRefreshTimer;

  bool _openingLogin = false;
  bool _isUpdatingAcceptingOrders = false;
  bool _isLoggingOut = false;
  RestaurantProfileData? _restaurantProfile;
  RestaurantAppBootstrap? _cmsBootstrap;
  String _restaurantAccessRole = 'UNKNOWN';

  static const List<RestaurantBottomBarTab> _managerTabs =
      <RestaurantBottomBarTab>[
    RestaurantBottomBarTab.orders,
    RestaurantBottomBarTab.menu,
    RestaurantBottomBarTab.profile,
    RestaurantBottomBarTab.finance,
    RestaurantBottomBarTab.support,
  ];

  static const List<RestaurantBottomBarTab> _staffTabs =
      <RestaurantBottomBarTab>[
    RestaurantBottomBarTab.orders,
  ];

  List<RestaurantBottomBarTab> get _visibleTabs {
    if (_restaurantAccessRole == _roleOwner ||
        _restaurantAccessRole == _roleManager) {
      return _managerTabs;
    }
    return _staffTabs;
  }

  bool get _canManageRestaurant =>
      _restaurantAccessRole == _roleOwner ||
      _restaurantAccessRole == _roleManager;

  bool get _isOwner => _restaurantAccessRole == _roleOwner;

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
      (_) => _refreshActiveOrders(),
    );
    unawaited(RestaurantPushNotificationService.instance.markNavigationReady());
    unawaited(_registerPushAfterLogin());
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
    unawaited(
      RestaurantPushNotificationService.instance.registerCurrentToken(
        requestPermissionIfNeeded: false,
      ),
    );
    unawaited(_loadRestaurant());
    _refreshActiveOrders();
  }

  Future<void> _registerPushAfterLogin() async {
    try {
      await RestaurantPushNotificationService.instance.registerCurrentToken(
        requestPermissionIfNeeded: true,
      );
    } catch (error) {
      debugPrint('Restaurant push registration after login failed: $error');
    }
  }

  void _refreshActiveOrders() {
    if (!mounted || _currentTab != RestaurantBottomBarTab.orders) return;
    RestaurantOrdersSyncBus.instance.requestRefresh();
  }

  String _userSafeError(Object error, String fallbackRu, String fallbackKk) {
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

  void _openLogin() {
    if (!mounted || _openingLogin) return;
    _openingLogin = true;
    RestaurantSession.restaurant = null;
    RestaurantAppCmsSession.instance.clear();
    RestaurantPushNotificationService.instance.markNavigationUnavailable();
    Navigator.of(context).pushAndRemoveUntil(
      AppPageRoute<void>(page: const RestaurantAccessChoicePage()),
      (route) => false,
    );
  }

  Future<void> _logout() async {
    if (_isLoggingOut || _openingLogin) return;
    setState(() => _isLoggingOut = true);

    try {
      try {
        await RestaurantPushNotificationService.instance
            .unregisterCurrentToken();
      } catch (_) {}
      try {
        await AuthApi().logout();
      } catch (_) {}

      await AuthStorage().clearTokens();
      ApiClient.instance.clearSelectedRestaurantId();
      if (mounted) _openLogin();
    } finally {
      if (mounted && !_openingLogin) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  void _openSupportDuringMaintenance() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RestaurantSupportPage()),
    );
  }

  String _resolveRestaurantAccessRole(
    Map<String, dynamic>? me,
    String restaurantId,
  ) {
    final accesses = me?['restaurantAccesses'];
    if (accesses is! List) return 'UNKNOWN';

    for (final raw in accesses) {
      if (raw is! Map) continue;
      final id = raw['restaurantId']?.toString().trim() ?? '';
      if (id != restaurantId) continue;

      final source = raw['source']?.toString().trim().toUpperCase() ?? '';
      final role = raw['role']?.toString().trim().toUpperCase() ?? '';
      if (source == _roleOwner || role == _roleOwner) return _roleOwner;
      if (role == _roleManager) return _roleManager;
      if (role == _roleStaff) return _roleStaff;
      return 'UNKNOWN';
    }
    return 'UNKNOWN';
  }

  Future<void> _loadRestaurant() async {
    try {
      Map<String, dynamic>? me;
      try {
        me = await AuthApi().getMe();
      } catch (error) {
        debugPrint('Restaurant auth/me unavailable: $error');
      }

      final restaurantApi = RestaurantApi(ApiClient.instance);
      final restaurant = await restaurantApi.getMyRestaurant();
      RestaurantSession.restaurant = restaurant;
      final accessRole = _resolveRestaurantAccessRole(me, restaurant.id);

      RestaurantAppBootstrap? bootstrap;
      try {
        bootstrap = await RestaurantAppCmsSession.instance.refresh();
      } catch (error, stackTrace) {
        debugPrint('CMS bootstrap unavailable: $error');
        debugPrintStack(stackTrace: stackTrace);
        bootstrap = RestaurantAppCmsSession.instance.state.value;
      }

      if (!mounted) return;
      setState(() {
        _restaurantProfile = restaurant;
        _cmsBootstrap = bootstrap;
        _restaurantAccessRole = accessRole;
        if (!_visibleTabs.contains(_currentTab)) {
          _currentTab = RestaurantBottomBarTab.orders;
        }
      });
    } catch (error, stackTrace) {
      debugPrint('Restaurant load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> _notificationsAllowedForOrders() async {
    try {
      await RestaurantPushNotificationService.instance.registerCurrentToken(
        requestPermissionIfNeeded: true,
      );

      if (Platform.isAndroid) {
        final androidPlugin = FlutterLocalNotificationsPlugin()
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final enabled = await androidPlugin?.areNotificationsEnabled();
        if (enabled != null) return enabled;
      }

      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (error) {
      debugPrint('Restaurant notification readiness check failed: $error');
      return false;
    }
  }

  Future<void> _showNotificationRequiredDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text(
          _t('Включите уведомления', 'Хабарландыруларды қосыңыз'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          _t(
            'JETKIZ не включит приём заказов без уведомлений: ресторан может пропустить оплаченный заказ. Разрешите уведомления для JETKIZ Restaurant и повторите.',
            'JETKIZ хабарландыруларсыз тапсырыс қабылдауды қоспайды: мейрамхана төленген тапсырысты өткізіп алуы мүмкін. JETKIZ Restaurant хабарландыруларына рұқсат беріп, қайталаңыз.',
          ),
          style: const TextStyle(color: Color(0xFFCBD5E1), height: 1.4),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_t('Понятно', 'Түсінікті')),
          ),
        ],
      ),
    );
  }

  Future<void> _setAcceptingOrders(bool value) async {
    if (_isUpdatingAcceptingOrders || !_canManageRestaurant) return;

    final cms = _cmsBootstrap;
    if (cms != null && !cms.featureEnabled('ACCEPT_ORDERS_ENABLED')) {
      final reason = cms.featureReason(
        'ACCEPT_ORDERS_ENABLED',
        kazakh: context.isKazakh,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reason ??
                _t(
                  'Приём заказов временно недоступен',
                  'Тапсырыс қабылдау уақытша қолжетімсіз',
                ),
          ),
        ),
      );
      return;
    }

    if (value && !await _notificationsAllowedForOrders()) {
      await _showNotificationRequiredDialog();
      return;
    }

    if (!mounted) return;
    setState(() => _isUpdatingAcceptingOrders = true);

    try {
      final restaurant = await RestaurantApi(
        ApiClient.instance,
      ).setAcceptingOrders(value);
      RestaurantSession.restaurant = restaurant;

      RestaurantAppBootstrap? bootstrap;
      try {
        bootstrap = await RestaurantAppCmsSession.instance.refresh();
      } catch (_) {
        bootstrap = _cmsBootstrap;
      }

      if (!mounted) return;
      setState(() {
        _restaurantProfile = restaurant;
        _cmsBootstrap = bootstrap;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? _t('Приём заказов включён', 'Тапсырыс қабылдау қосылды')
                  : _t(
                      'Приём заказов приостановлен',
                      'Тапсырыс қабылдау тоқтатылды',
                    ),
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _userSafeError(
                error,
                'Не удалось изменить приём заказов. Проверьте интернет и повторите.',
                'Тапсырыс қабылдау күйін өзгерту мүмкін болмады. Интернетті тексеріп, қайталаңыз.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _isUpdatingAcceptingOrders = false);
    }
  }

  Future<void> _resubmitForReview() async {
    if (_isUpdatingAcceptingOrders || !_canManageRestaurant) return;
    setState(() => _isUpdatingAcceptingOrders = true);

    try {
      final restaurant = await RestaurantApi(
        ApiClient.instance,
      ).resubmitForReview();
      RestaurantSession.restaurant = restaurant;

      if (!mounted) return;
      setState(() => _restaurantProfile = restaurant);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Заявка повторно отправлена на модерацию',
                'Өтінім модерацияға қайта жіберілді',
              ),
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _userSafeError(
                error,
                'Не удалось отправить заявку. Проверьте интернет и повторите.',
                'Өтінімді жіберу мүмкін болмады. Интернетті тексеріп, қайталаңыз.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _isUpdatingAcceptingOrders = false);
    }
  }

  void _onTabSelected(RestaurantBottomBarTab tab) {
    if (_currentTab == tab || !_visibleTabs.contains(tab)) return;
    setState(() => _currentTab = tab);
    if (tab == RestaurantBottomBarTab.orders) _refreshActiveOrders();
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
        return RestaurantProfileAccessPage(isOwner: _isOwner);
      case RestaurantBottomBarTab.finance:
        if (_cmsBootstrap?.featureEnabled('FINANCE_VIEW_ENABLED') == false) {
          return _FeatureUnavailable(
            title: _t(
              'Финансы временно недоступны',
              'Қаржы бөлімі уақытша қолжетімсіз',
            ),
            reason: _cmsBootstrap?.featureReason(
              'FINANCE_VIEW_ENABLED',
              kazakh: context.isKazakh,
            ),
          );
        }
        return const RestaurantFinancePage();
      case RestaurantBottomBarTab.support:
        if (_cmsBootstrap?.featureEnabled('SUPPORT_ENABLED') == false) {
          return _FeatureUnavailable(
            title: _t(
              'Поддержка временно недоступна',
              'Қолдау уақытша қолжетімсіз',
            ),
            reason: _cmsBootstrap?.featureReason(
              'SUPPORT_ENABLED',
              kazakh: context.isKazakh,
            ),
          );
        }
        return const RestaurantSupportPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _restaurantProfile;
    final maintenance = _cmsBootstrap?.maintenance;
    final title = context.isKazakh ? maintenance?.titleKk : maintenance?.titleRu;
    final body = context.isKazakh ? maintenance?.bodyKk : maintenance?.bodyRu;
    final fallbackTitle = context.isKazakh ? maintenance?.titleRu : maintenance?.titleKk;
    final fallbackBody = context.isKazakh ? maintenance?.bodyRu : maintenance?.bodyKk;

    if (maintenance?.blocksApp == true) {
      return _MaintenanceGate(
        title: _firstNonEmpty(title, fallbackTitle),
        body: _firstNonEmpty(body, fallbackBody),
        onRetry: _loadRestaurant,
        onSupport: _openSupportDuringMaintenance,
        onLogout: _logout,
        isLoggingOut: _isLoggingOut,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (maintenance?.isSoft == true)
              _SoftMaintenanceBanner(
                title: _firstNonEmpty(title, fallbackTitle),
                body: _firstNonEmpty(body, fallbackBody),
              ),
            if (profile != null && _canManageRestaurant)
              RestaurantOperationalBanner(
                profile: profile,
                isUpdating: _isUpdatingAcceptingOrders,
                onAcceptingOrdersChanged: _setAcceptingOrders,
                onResubmit: profile.canResubmitForReview
                    ? _resubmitForReview
                    : null,
              ),
            Expanded(child: _buildPage()),
          ],
        ),
      ),
      bottomNavigationBar: RestaurantBottomBar(
        currentTab: _currentTab,
        visibleTabs: _visibleTabs,
        onTabSelected: _onTabSelected,
      ),
    );
  }

  String? _firstNonEmpty(String? primary, String? fallback) {
    final first = primary?.trim();
    if (first != null && first.isNotEmpty) return first;
    final second = fallback?.trim();
    return second == null || second.isEmpty ? null : second;
  }
}

class _MaintenanceGate extends StatelessWidget {
  const _MaintenanceGate({
    required this.title,
    required this.body,
    required this.onRetry,
    required this.onSupport,
    required this.onLogout,
    required this.isLoggingOut,
  });

  final String? title;
  final String? body;
  final Future<void> Function() onRetry;
  final VoidCallback onSupport;
  final Future<void> Function() onLogout;
  final bool isLoggingOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.engineering_rounded,
                  color: Color(0xFF65C044),
                  size: 54,
                ),
                const SizedBox(height: 18),
                Text(
                  (title ?? '').trim().isNotEmpty
                      ? title!.trim()
                      : context.tr('Технические работы', 'Техникалық жұмыстар'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  (body ?? '').trim().isNotEmpty
                      ? body!.trim()
                      : context.tr(
                          'Приложение временно недоступно. Попробуйте ещё раз позже.',
                          'Қосымша уақытша қолжетімсіз. Кейінірек қайталап көріңіз.',
                        ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFB4BECC),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onRetry,
                    child: Text(context.tr('Проверить снова', 'Қайта тексеру')),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onSupport,
                    icon: const Icon(Icons.support_agent_rounded),
                    label: Text(
                      context.tr('Открыть поддержку', 'Қолдауды ашу'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: isLoggingOut ? null : onLogout,
                  icon: isLoggingOut
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout_rounded),
                  label: Text(
                    context.tr('Выйти из аккаунта', 'Аккаунттан шығу'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SoftMaintenanceBanner extends StatelessWidget {
  const _SoftMaintenanceBanner({this.title, this.body});

  final String? title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final message = <String?>[title, body]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' · ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF30270F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6B5315)),
      ),
      child: Text(
        message.isEmpty
            ? context.tr(
                'Возможны временные ограничения в работе приложения.',
                'Қосымша жұмысында уақытша шектеулер болуы мүмкін.',
              )
            : message,
        style: const TextStyle(color: Color(0xFFF7E5A5), fontSize: 12),
      ),
    );
  }
}

class _FeatureUnavailable extends StatelessWidget {
  const _FeatureUnavailable({required this.title, this.reason});

  final String title;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF09111C),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_clock_rounded,
                color: Color(0xFF7D8AA0),
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if ((reason ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  reason!.trim(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
