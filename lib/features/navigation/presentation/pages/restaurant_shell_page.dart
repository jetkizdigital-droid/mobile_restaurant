import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/navigation/app_page_route.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/core/push/restaurant_push_notification_service.dart';
import 'package:jetkiz_restaurant/core/session/restaurant_session.dart';
import 'package:jetkiz_restaurant/features/auth/presentation/pages/restaurant_auth_page.dart';
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

class _RestaurantShellPageState extends State<RestaurantShellPage> {
  late RestaurantBottomBarTab _currentTab;
  StreamSubscription<void>? _sessionExpiredSubscription;
  bool _openingLogin = false;
  bool _isUpdatingAcceptingOrders = false;
  RestaurantProfileData? _restaurantProfile;

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
    _currentTab = widget.initialTab;
    _sessionExpiredSubscription = ApiClient.instance.sessionExpiredEvents
        .listen((_) => _openLogin());
    unawaited(RestaurantPushNotificationService.instance.markNavigationReady());
    unawaited(_loadRestaurant());
  }

  @override
  void dispose() {
    _sessionExpiredSubscription?.cancel();
    RestaurantPushNotificationService.instance.markNavigationUnavailable();
    super.dispose();
  }

  void _openLogin() {
    if (!mounted || _openingLogin) return;
    _openingLogin = true;
    RestaurantPushNotificationService.instance.markNavigationUnavailable();
    Navigator.of(context).pushAndRemoveUntil(
      AppPageRoute<void>(page: const RestaurantAuthPage()),
      (route) => false,
    );
  }

  Future<void> _loadRestaurant() async {
    try {
      final restaurantApi = RestaurantApi(ApiClient.instance);
      final restaurant = await restaurantApi.getMyRestaurant();
      RestaurantSession.restaurant = restaurant;

      if (!mounted) return;
      setState(() {
        _restaurantProfile = restaurant;
      });
    } catch (e, st) {
      debugPrint('ERROR loading restaurant: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> _setAcceptingOrders(bool value) async {
    if (_isUpdatingAcceptingOrders) return;

    setState(() {
      _isUpdatingAcceptingOrders = true;
    });

    try {
      final restaurantApi = RestaurantApi(ApiClient.instance);
      final restaurant = await restaurantApi.setAcceptingOrders(value);
      RestaurantSession.restaurant = restaurant;

      if (!mounted) return;
      setState(() {
        _restaurantProfile = restaurant;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Приём заказов включён'
                  : 'Приём заказов приостановлен',
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

  void _onTabSelected(RestaurantBottomBarTab tab) {
    if (_currentTab == tab) return;
    if (!_tabOrder.contains(tab)) return;

    setState(() {
      _currentTab = tab;
    });

    // Profile can change the active branch. Reload runtime state whenever the
    // user moves between shell tabs so the global banner follows that branch.
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
        return const RestaurantFinancePage();
      case RestaurantBottomBarTab.support:
        return const RestaurantSupportPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _restaurantProfile;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (profile != null)
              RestaurantOperationalBanner(
                profile: profile,
                isUpdating: _isUpdatingAcceptingOrders,
                onAcceptingOrdersChanged: _setAcceptingOrders,
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
