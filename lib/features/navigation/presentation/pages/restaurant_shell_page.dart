import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/core/session/restaurant_session.dart';
import 'package:jetkiz_restaurant/features/finance/presentation/pages/restaurant_finance_page.dart';
import 'package:jetkiz_restaurant/features/menu/presentation/pages/restaurant_menu_page.dart';
import 'package:jetkiz_restaurant/features/navigation/presentation/widgets/restaurant_bottom_bar.dart';
import 'package:jetkiz_restaurant/features/orders/presentation/pages/restaurant_orders_page.dart'
    as orders_page;
import 'package:jetkiz_restaurant/features/restaurant/data/restaurant_api.dart';
import 'package:jetkiz_restaurant/features/restaurant_profile/presentation/pages/restaurant_profile_page.dart'
    as profile_page;

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
    _loadRestaurant();
  }

  Future<void> _loadRestaurant() async {
    try {
      final restaurantApi = RestaurantApi(ApiClient.instance);
      final restaurant = await restaurantApi.getMyRestaurant();
      RestaurantSession.restaurant = restaurant;

      if (mounted) {
        setState(() {});
      }
    } catch (e, st) {
      debugPrint('ERROR loading restaurant: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  void _onTabSelected(RestaurantBottomBarTab tab) {
    if (_currentTab == tab) return;
    if (!_tabOrder.contains(tab)) return;

    setState(() {
      _currentTab = tab;
    });
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
        return const _RestaurantSupportStubPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: _buildPage(),
      ),
      bottomNavigationBar: RestaurantBottomBar(
        currentTab: _currentTab,
        onTabSelected: _onTabSelected,
      ),
    );
  }
}

class _RestaurantSupportStubPage extends StatelessWidget {
  const _RestaurantSupportStubPage();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF0F1115),
      child: Center(
        child: Text(
          'Поддержка',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}