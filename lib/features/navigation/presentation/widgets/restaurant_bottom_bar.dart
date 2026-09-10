import 'package:flutter/material.dart';

/// JETKIZ RESTAURANT APP
/// Bottom navigation for the restaurant shell.
///
/// This file is the source of truth for the shell tab enum. The shell may pass
/// a role-scoped [visibleTabs] list; hidden tabs are not rendered or tappable.
enum RestaurantBottomBarTab {
  orders,
  menu,
  profile,
  finance,
  support,
}

class RestaurantBottomBar extends StatelessWidget {
  final RestaurantBottomBarTab currentTab;
  final ValueChanged<RestaurantBottomBarTab> onTabSelected;
  final bool isVisible;
  final List<RestaurantBottomBarTab>? visibleTabs;

  const RestaurantBottomBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
    this.isVisible = true,
    this.visibleTabs,
  });

  static const List<_RestaurantBottomBarItem> _items = [
    _RestaurantBottomBarItem(
      tab: RestaurantBottomBarTab.orders,
      label: 'Заказы',
      icon: Icons.receipt_long_rounded,
    ),
    _RestaurantBottomBarItem(
      tab: RestaurantBottomBarTab.menu,
      label: 'Меню',
      icon: Icons.restaurant_menu_rounded,
    ),
    _RestaurantBottomBarItem(
      tab: RestaurantBottomBarTab.profile,
      label: 'Профиль',
      icon: Icons.storefront_rounded,
    ),
    _RestaurantBottomBarItem(
      tab: RestaurantBottomBarTab.finance,
      label: 'Финансы',
      icon: Icons.account_balance_wallet_rounded,
    ),
    _RestaurantBottomBarItem(
      tab: RestaurantBottomBarTab.support,
      label: 'Поддержка',
      icon: Icons.support_agent_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final allowedTabs = visibleTabs?.toSet();
    final items = allowedTabs == null
        ? _items
        : _items.where((item) => allowedTabs.contains(item.tab)).toList();

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      offset: isVisible ? Offset.zero : const Offset(0, 1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        opacity: isVisible ? 1 : 0,
        child: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF2A3342),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: items.map((item) {
                final isSelected = item.tab == currentTab;

                return Expanded(
                  child: _BottomBarButton(
                    item: item,
                    isSelected: isSelected,
                    onTap: () => onTabSelected(item.tab),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBarButton extends StatelessWidget {
  final _RestaurantBottomBarItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomBarButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF4CAF50);
    final inactiveColor = const Color(0xFF9CA3AF);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.icon,
                  size: 22,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? activeColor : inactiveColor,
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

class _RestaurantBottomBarItem {
  final RestaurantBottomBarTab tab;
  final String label;
  final IconData icon;

  const _RestaurantBottomBarItem({
    required this.tab,
    required this.label,
    required this.icon,
  });
}