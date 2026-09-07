import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/navigation/app_page_route.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/core/push/restaurant_push_notification_service.dart';
import 'package:jetkiz_restaurant/core/session/restaurant_session.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_api.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_storage.dart';
import 'package:jetkiz_restaurant/features/auth/presentation/pages/restaurant_auth_page.dart';
import 'package:jetkiz_restaurant/features/cms/data/restaurant_app_cms_session.dart';
import 'package:jetkiz_restaurant/features/cms/domain/restaurant_app_bootstrap.dart';
import 'package:jetkiz_restaurant/features/finance/presentation/pages/restaurant_finance_page.dart';
import 'package:jetkiz_restaurant/features/menu/presentation/pages/restaurant_menu_page.dart';
import 'package:jetkiz_restaurant/features/navigation/presentation/widgets/restaurant_bottom_bar.dart';
import 'package:jetkiz_restaurant/features/orders/presentation/pages/restaurant_orders_page.dart'
    as orders_page;
import 'package:jetkiz_restaurant/features/restaurant/data/restaurant_api.dart';
import 'package:jetkiz_restaurant/features/restaurant/domain/restaurant_profile_data.dart';
import 'package:jetkiz_restaurant/features/restaurant/presentation/widgets/restaurant_operational_banner.dart';
import 'package:jetkiz_restaurant/features/restaurant_profile/presentation/pages/restaurant_profile_page.dart'
    as profile_page;
import 'package:jetkiz_restaurant/features/support/presentation/pages/restaurant_support_page.dart';

class RestaurantShellPage extends StatefulWidget {
  final RestaurantBottomBarTab initialTab;

  const RestaurantShellPage({
    super.key,
    this.initialTab = RestaurantBottomBarTab.orders,
  });

  @override
  State<RestaurantShellPage> createState() => _RestaurantShellPageState();
}

class _RestaurantShellPageState extends State<RestaurantShellPage>
    with WidgetsBindingObserver {
  late RestaurantBottomBarTab _currentTab;
  StreamSubscription<void>? _sessionExpiredSubscription;
  bool _openingLogin = false;
  bool _isUpdatingAcceptingOrders = false;
  bool _isLoggingOut = false;
  RestaurantProfileData? _restaurantProfile;
  RestaurantAppBootstrap? _cmsBootstrap;

  final List<RestaurantBottomBarTab> _tabOrder = <RestaurantBottomBarTab>[
    RestaurantBottomBarTab.orders,
    RestaurantBottomBarTab.menu,
    RestaurantBottomBarTab.profile,
    RestaurantBottomBarTab.finance,
    RestaurantBottomBarTab.support,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentTab = widget.initialTab;
    _sessionExpiredSubscription = ApiClient.instance.sessionExpiredEvents
        .listen((_) => _openLogin());
    unawaited(RestaurantPushNotificationService.instance.markNavigationReady());
    unawaited(_loadRestaurant());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
  }

  void _openLogin() {
    if (!mounted || _openingLogin) return;
    _openingLogin = true;
    RestaurantSession.restaurant = null;
    RestaurantAppCmsSession.instance.clear();
    RestaurantPushNotificationService.instance.markNavigationUnavailable();
    Navigator.of(context).pushAndRemoveUntil(
      AppPageRoute<void>(page: const RestaurantAuthPage()),
      (route) => false,
    );
  }

  Future<void> _logout() async {
    if (_isLoggingOut || _openingLogin) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      try {
        await RestaurantPushNotificationService.instance
            .unregisterCurrentToken();
      } catch (_) {
        // Logout must remain available even when push/backend is degraded.
      }

      try {
        await AuthApi().logout();
      } catch (_) {
        // Local session cleanup is authoritative for the device during
        // maintenance or network failure.
      }

      await AuthStorage().clearTokens();
      ApiClient.instance.clearSelectedRestaurantId();
      if (!mounted) return;
      _openLogin();
    } finally {
      if (mounted && !_openingLogin) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  void _openSupportDuringMaintenance() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RestaurantSupportPage()));
  }

  Future<void> _loadRestaurant() async {
    try {
      final restaurantApi = RestaurantApi(ApiClient.instance);
      final restaurant = await restaurantApi.getMyRestaurant();
      RestaurantSession.restaurant = restaurant;

      RestaurantAppBootstrap? bootstrap;
      try {
        bootstrap = await RestaurantAppCmsSession.instance.refresh();
      } catch (e, st) {
        debugPrint('CMS bootstrap unavailable: $e');
        debugPrintStack(stackTrace: st);
        bootstrap = RestaurantAppCmsSession.instance.state.value;
      }

      if (!mounted) return;
      setState(() {
        _restaurantProfile = restaurant;
        _cmsBootstrap = bootstrap;
      });
    } catch (e, st) {
      debugPrint('ERROR loading restaurant: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> _setAcceptingOrders(bool value) async {
    if (_isUpdatingAcceptingOrders) return;

    final cms = _cmsBootstrap;
    if (cms != null && !cms.featureEnabled('ACCEPT_ORDERS_ENABLED')) {
      final reason = cms.featureReason('ACCEPT_ORDERS_ENABLED');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason ?? 'Приём заказов временно недоступен')),
      );
      return;
    }

    setState(() {
      _isUpdatingAcceptingOrders = true;
    });

    try {
      final restaurantApi = RestaurantApi(ApiClient.instance);
      final restaurant = await restaurantApi.setAcceptingOrders(value);
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
              value ? 'Приём заказов включён' : 'Приём заказов приостановлен',
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
              error.toString().replaceFirst('Exception: ', '').trim(),
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingAcceptingOrders = false;
        });
      }
    }
  }

  Future<void> _resubmitForReview() async {
    if (_isUpdatingAcceptingOrders) return;

    setState(() {
      _isUpdatingAcceptingOrders = true;
    });

    try {
      final restaurant = await RestaurantApi(
        ApiClient.instance,
      ).resubmitForReview();
      RestaurantSession.restaurant = restaurant;

      if (!mounted) return;
      setState(() {
        _restaurantProfile = restaurant;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Заявка повторно отправлена на модерацию'),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst('Exception: ', '').trim(),
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingAcceptingOrders = false;
        });
      }
    }
  }

  void _onTabSelected(RestaurantBottomBarTab tab) {
    if (_currentTab == tab) return;
    if (!_tabOrder.contains(tab)) return;

    setState(() {
      _currentTab = tab;
    });

    // The profile screen can change the active branch. Reload both restaurant
    // runtime state and server-controlled app configuration on tab changes.
    unawaited(_loadRestaurant());
  }

  Widget _buildPage() {
    switch (_currentTab) {
      case RestaurantBottomBarTab.orders:
        return const orders_page.RestaurantOrdersPage(hideBottomBar: true);
      case RestaurantBottomBarTab.menu:
        return const RestaurantMenuPage();
      case RestaurantBottomBarTab.profile:
        return const profile_page.RestaurantProfilePage(hideBottomBar: true);
      case RestaurantBottomBarTab.finance:
        if (_cmsBootstrap?.featureEnabled('FINANCE_VIEW_ENABLED') == false) {
          return _FeatureUnavailable(
            title: 'Финансы временно недоступны',
            reason: _cmsBootstrap?.featureReason('FINANCE_VIEW_ENABLED'),
          );
        }
        return const RestaurantFinancePage();
      case RestaurantBottomBarTab.support:
        if (_cmsBootstrap?.featureEnabled('SUPPORT_ENABLED') == false) {
          return _FeatureUnavailable(
            title: 'Поддержка временно недоступна',
            reason: _cmsBootstrap?.featureReason('SUPPORT_ENABLED'),
          );
        }
        return const RestaurantSupportPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _restaurantProfile;
    final maintenance = _cmsBootstrap?.maintenance;

    if (maintenance?.blocksApp == true) {
      return _MaintenanceGate(
        title: maintenance?.titleRu,
        body: maintenance?.bodyRu,
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
                title: maintenance?.titleRu,
                body: maintenance?.bodyRu,
              ),
            if (profile != null)
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
        onTabSelected: _onTabSelected,
      ),
    );
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
                      : 'Технические работы',
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
                      : 'Приложение временно недоступно. Попробуйте ещё раз позже.',
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
                    child: const Text('Проверить снова'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onSupport,
                    icon: const Icon(Icons.support_agent_rounded),
                    label: const Text('Открыть поддержку'),
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
                  label: const Text('Выйти из аккаунта'),
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
        [title, body]
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .join(' · '),
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
