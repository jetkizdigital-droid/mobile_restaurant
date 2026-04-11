import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/features/orders/data/restaurant_orders_api.dart';
import 'package:jetkiz_restaurant/features/orders/presentation/pages/restaurant_order_details_page.dart';

class RestaurantOrdersPage extends StatefulWidget {
  const RestaurantOrdersPage({
    super.key,
    this.hideBottomBar = false,
  });

  final bool hideBottomBar;

  @override
  State<RestaurantOrdersPage> createState() => _RestaurantOrdersPageState();
}

class _RestaurantOrdersPageState extends State<RestaurantOrdersPage>
    with SingleTickerProviderStateMixin {
  final RestaurantOrdersApi _ordersApi = RestaurantOrdersApi();

  late final AnimationController _blinkController;

  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> _allOrders = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _visibleOrders = <Map<String, dynamic>>[];

  final Set<String> _updatingOrderIds = <String>{};

  String _selectedStatus = 'ALL';

  final List<_OrderFilterItem> _filters = const [
    _OrderFilterItem(code: 'ALL', label: 'Все'),
    _OrderFilterItem(code: 'CREATED', label: 'Новые'),
    _OrderFilterItem(code: 'ACCEPTED', label: 'Приняты'),
    _OrderFilterItem(code: 'COOKING', label: 'Готовятся'),
    _OrderFilterItem(code: 'READY', label: 'Готово'),
    _OrderFilterItem(code: 'ON_THE_WAY', label: 'В пути'),
    _OrderFilterItem(code: 'DELIVERED', label: 'Доставлены'),
    _OrderFilterItem(code: 'CANCELED', label: 'Отменены'),
  ];

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _loadOrders();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final result = await _ordersApi.getOrders();

      if (!mounted) return;

      setState(() {
        _allOrders = result;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _loadOrders();
  }

  void _applyFilter() {
    if (_selectedStatus == 'ALL') {
      _visibleOrders = List<Map<String, dynamic>>.from(_allOrders);
      return;
    }

    _visibleOrders = _allOrders.where((order) {
      return _status(order) == _selectedStatus;
    }).toList();
  }

  void _selectStatus(String status) {
    if (_selectedStatus == status) return;

    setState(() {
      _selectedStatus = status;
      _applyFilter();
    });
  }

  Future<void> _openOrder(Map<String, dynamic> order) async {
    final orderId = _orderId(order);

    if (orderId.isEmpty) {
      final number = _orderNumber(order);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось открыть заказ #$number'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RestaurantOrderDetailsPage(orderId: orderId),
      ),
    );

    if (!mounted) return;
    await _loadOrders();
  }

  Future<void> _changeStatus(
    Map<String, dynamic> order,
    String newStatus,
  ) async {
    final orderId = _orderId(order);
    if (orderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось определить ID заказа'),
        ),
      );
      return;
    }

    if (_updatingOrderIds.contains(orderId)) return;

    setState(() {
      _updatingOrderIds.add(orderId);
    });

    try {
      final updated = await _ordersApi.updateOrderStatus(
        id: orderId,
        status: newStatus,
      );

      if (!mounted) return;

      final updatedStatus =
          (updated['status'] ?? updated['orderStatus'] ?? newStatus).toString();

      final updatedOrder = Map<String, dynamic>.from(order);
      updatedOrder['status'] = updatedStatus;
      if (updated.containsKey('updatedAt')) {
        updatedOrder['updatedAt'] = updated['updatedAt'];
      }
      if (updated.containsKey('pickedUpAt')) {
        updatedOrder['pickedUpAt'] = updated['pickedUpAt'];
      }
      if (updated.containsKey('deliveredAt')) {
        updatedOrder['deliveredAt'] = updated['deliveredAt'];
      }

      final index = _allOrders.indexWhere((item) => _orderId(item) == orderId);
      if (index != -1) {
        _allOrders[index] = updatedOrder;
      }

      setState(() {
        _applyFilter();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Статус заказа #${_orderNumber(order)} изменён: ${_statusLabel(updatedStatus)}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingOrderIds.remove(orderId);
        });
      }
    }
  }

  String _status(Map<String, dynamic> order) {
    final dynamic value = order['status'] ?? order['orderStatus'];
    return value?.toString() ?? 'UNKNOWN';
  }

  String _orderId(Map<String, dynamic> order) {
    final dynamic value =
        order['id'] ?? order['_id'] ?? order['orderId'] ?? order['number'];
    return value?.toString() ?? '';
  }

  String _orderNumber(Map<String, dynamic> order) {
    final dynamic value =
        order['number'] ?? order['id'] ?? order['_id'] ?? order['orderId'];
    return value?.toString() ?? '—';
  }

  int _total(Map<String, dynamic> order) {
    final dynamic value =
        order['total'] ?? order['totalPrice'] ?? order['sum'] ?? 0;

    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  String _customerName(Map<String, dynamic> order) {
    final dynamic user = order['user'];

    if (user is Map<String, dynamic>) {
      final first = (user['firstName'] ?? '').toString().trim();
      final last = (user['lastName'] ?? '').toString().trim();
      final full = '$first $last'.trim();
      if (full.isNotEmpty) return full;

      final phone = (user['phone'] ?? '').toString().trim();
      if (phone.isNotEmpty) return phone;
    }

    final phone = (order['phone'] ?? '').toString().trim();
    if (phone.isNotEmpty) return phone;

    final customerName = (order['customerName'] ?? '').toString().trim();
    if (customerName.isNotEmpty) return customerName;

    return 'Клиент';
  }

  String _itemsPreview(Map<String, dynamic> order) {
    final dynamic rawItems = order['items'];

    if (rawItems is! List || rawItems.isEmpty) {
      return 'Состав заказа не указан';
    }

    final items = rawItems.whereType<Map>().toList();
    if (items.isEmpty) return 'Состав заказа не указан';

    final titles = items.take(2).map((item) {
      final title = (item['title'] ?? item['name'] ?? 'Без названия').toString();
      final qty = item['quantity']?.toString() ?? '1';
      return '$title ×$qty';
    }).join(', ');

    if (items.length <= 2) return titles;
    return '$titles и ещё ${items.length - 2}';
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    final parsed = DateTime.tryParse(value.toString());
    return parsed;
  }

  DateTime? _createdAt(Map<String, dynamic> order) {
    return _parseDate(order['createdAt']);
  }

  DateTime? _promisedAt(Map<String, dynamic> order) {
    return _parseDate(order['promisedAt']);
  }

  bool _isOverdue(Map<String, dynamic> order) {
    final promisedAt = _promisedAt(order);
    final status = _status(order);

    if (promisedAt == null) return false;
    if (status == 'DELIVERED' || status == 'CANCELED') return false;

    return DateTime.now().isAfter(promisedAt.toLocal());
  }

  String _formatHm(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _timeText(Map<String, dynamic> order) {
    final createdAt = _createdAt(order);
    final promisedAt = _promisedAt(order);

    if (createdAt == null && promisedAt == null) {
      return 'Время не указано';
    }

    final created = createdAt != null ? _formatHm(createdAt.toLocal()) : null;
    final promised = promisedAt != null ? _formatHm(promisedAt.toLocal()) : null;

    if (created != null && promised != null) {
      final remain = promisedAt!.difference(DateTime.now()).inMinutes;
      final remainText = remain >= 0
          ? '$remain мин осталось'
          : '${remain.abs()} мин просрочка';
      return '$created · $remainText';
    }

    return created ?? promised ?? 'Время не указано';
  }

  List<_OrderAction> _actionsForStatus(String status) {
    switch (status) {
      case 'CREATED':
        return const [
          _OrderAction(
            nextStatus: 'ACCEPTED',
            label: 'Принять',
            icon: Icons.check_rounded,
            isPrimary: false,
          ),
          _OrderAction(
            nextStatus: 'ACCEPTED',
            label: 'Начать готовить',
            icon: Icons.local_fire_department_outlined,
            isPrimary: true,
          ),
          _OrderAction(
            nextStatus: 'CANCELED',
            label: 'Отменить',
            icon: Icons.close_rounded,
            isDanger: true,
          ),
        ];
      case 'ACCEPTED':
        return const [
          _OrderAction(
            nextStatus: 'COOKING',
            label: 'Начать готовить',
            icon: Icons.local_fire_department_outlined,
            isPrimary: true,
          ),
          _OrderAction(
            nextStatus: 'CANCELED',
            label: 'Отменить',
            icon: Icons.close_rounded,
            isDanger: true,
          ),
        ];
      case 'COOKING':
        return const [
          _OrderAction(
            nextStatus: 'READY',
            label: 'Готово',
            icon: Icons.done_all_rounded,
            isPrimary: true,
          ),
          _OrderAction(
            nextStatus: 'CANCELED',
            label: 'Отменить',
            icon: Icons.close_rounded,
            isDanger: true,
          ),
        ];
      case 'READY':
        return const [
          _OrderAction(
            nextStatus: 'ON_THE_WAY',
            label: 'Вызвать курьера',
            icon: Icons.delivery_dining_rounded,
            isPrimary: false,
          ),
          _OrderAction(
            nextStatus: 'ON_THE_WAY',
            label: 'Передать курьеру',
            icon: Icons.delivery_dining_rounded,
            isPrimary: true,
          ),
          _OrderAction(
            nextStatus: 'CANCELED',
            label: 'Отменить',
            icon: Icons.close_rounded,
            isDanger: true,
          ),
        ];
      case 'ON_THE_WAY':
        return const [];
      default:
        return const [];
    }
  }

  String _statusLabel(String status) {
    return _OrderStatusMeta.fromStatus(status).label;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      appBar: widget.hideBottomBar
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF09111C),
              elevation: 0,
              centerTitle: true,
              title: const Text(
                'Заказы',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            _OrdersHeader(
              filters: _filters,
              selectedStatus: _selectedStatus,
              onSelect: _selectStatus,
            ),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const _OrdersLoadingState();
    }

    if (_error != null) {
      return _OrdersErrorState(
        message: _error!,
        onRetry: _loadOrders,
      );
    }

    if (_visibleOrders.isEmpty) {
      return _OrdersEmptyState(
        statusCode: _selectedStatus,
        onRefresh: _refresh,
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        itemCount: _visibleOrders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = _visibleOrders[index];
          final orderId = _orderId(order);

          return _RestaurantOrderCard(
            orderNumber: _orderNumber(order),
            customerName: _customerName(order),
            itemsPreview: _itemsPreview(order),
            total: _total(order),
            timeText: _timeText(order),
            status: _status(order),
            isOverdue: _isOverdue(order),
            blinkAnimation: _blinkController,
            isUpdating: _updatingOrderIds.contains(orderId),
            actions: _actionsForStatus(_status(order)),
            onTap: () => _openOrder(order),
            onActionTap: (action) => _changeStatus(order, action.nextStatus),
          );
        },
      ),
    );
  }
}

class _OrdersHeader extends StatelessWidget {
  const _OrdersHeader({
    required this.filters,
    required this.selectedStatus,
    required this.onSelect,
  });

  final List<_OrderFilterItem> filters;
  final String selectedStatus;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF489F2A),
            Color(0xFF3C861F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33489F2A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Заказы ресторана',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.volume_up_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = filters[index];
                final isActive = item.code == selectedStatus;

                return GestureDetector(
                  onTap: () => onSelect(item.code),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isActive
                            ? Colors.white
                            : Colors.white.withOpacity(0.18),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: isActive
                              ? const Color(0xFF489F2A)
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantOrderCard extends StatelessWidget {
  const _RestaurantOrderCard({
    required this.orderNumber,
    required this.customerName,
    required this.itemsPreview,
    required this.total,
    required this.timeText,
    required this.status,
    required this.isOverdue,
    required this.blinkAnimation,
    required this.isUpdating,
    required this.actions,
    required this.onTap,
    required this.onActionTap,
  });

  final String orderNumber;
  final String customerName;
  final String itemsPreview;
  final int total;
  final String timeText;
  final String status;
  final bool isOverdue;
  final Animation<double> blinkAnimation;
  final bool isUpdating;
  final List<_OrderAction> actions;
  final VoidCallback onTap;
  final ValueChanged<_OrderAction> onActionTap;

  @override
  Widget build(BuildContext context) {
    final statusMeta = _OrderStatusMeta.fromStatus(status);

    return AnimatedBuilder(
      animation: blinkAnimation,
      builder: (context, child) {
        final highlightOpacity =
            isOverdue ? (0.22 + (blinkAnimation.value * 0.30)) : 0.0;

        return GestureDetector(
          onTap: isUpdating ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF142234),
                  Color(0xFF0B1421),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: isOverdue
                    ? Color.lerp(
                        const Color(0x33FF5E5E),
                        const Color(0x99FF5E5E),
                        highlightOpacity,
                      )!
                    : const Color(0xFF223247),
              ),
              boxShadow: [
                const BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
                if (isOverdue)
                  BoxShadow(
                    color: Color.lerp(
                      const Color(0x00FF5E5E),
                      const Color(0x55FF5E5E),
                      highlightOpacity,
                    )!,
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _CircleIcon(
                icon: Icons.inventory_2_outlined,
                iconColor: Color(0xFF70D74D),
                backgroundColor: Color(0x1A70D74D),
                borderColor: Color(0x3370D74D),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Заказ #$orderNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusChip(meta: statusMeta),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.access_time,
                color: Color(0xFF8A98AC),
                size: 14,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  timeText,
                  style: const TextStyle(
                    color: Color(0xFF8A98AC),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isOverdue)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x22FF5E5E),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x55FF5E5E)),
                  ),
                  child: const Text(
                    'Просрочен',
                    style: TextStyle(
                      color: Color(0xFFFF8A8A),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0x33060C15),
              border: Border.all(color: const Color(0xFF1E2B3D)),
            ),
            child: Column(
              children: [
                _OrderInfoRow(
                  icon: Icons.person_outline,
                  title: customerName,
                  trailing: 'Подробнее →',
                  trailingColor: const Color(0xFF63C73E),
                ),
                const SizedBox(height: 10),
                _OrderInfoRow(
                  icon: Icons.receipt_long_outlined,
                  title: itemsPreview,
                ),
                const SizedBox(height: 10),
                _OrderInfoRow(
                  icon: Icons.payments_outlined,
                  title: 'Итого',
                  trailing: '$total ₸',
                  trailingColor: const Color(0xFF70D74D),
                ),
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _OrderActionsSection(
              actions: actions,
              isUpdating: isUpdating,
              onActionTap: onActionTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderActionsSection extends StatelessWidget {
  const _OrderActionsSection({
    required this.actions,
    required this.isUpdating,
    required this.onActionTap,
  });

  final List<_OrderAction> actions;
  final bool isUpdating;
  final ValueChanged<_OrderAction> onActionTap;

  @override
  Widget build(BuildContext context) {
    final primaryAction = actions.where((e) => e.isPrimary).toList();
    final secondaryActions = actions.where((e) => !e.isPrimary).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (primaryAction.isNotEmpty)
          _PrimaryActionButton(
            action: primaryAction.first,
            isLoading: isUpdating,
            onTap: isUpdating ? null : () => onActionTap(primaryAction.first),
          ),
        if (secondaryActions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: secondaryActions.map((action) {
              return _SecondaryActionButton(
                action: action,
                isLoading: isUpdating,
                onTap: isUpdating ? null : () => onActionTap(action),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.action,
    required this.isLoading,
    required this.onTap,
  });

  final _OrderAction action;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = action.isDanger
        ? const Color(0xFF6C1E24)
        : const Color(0xFF63C73E);

    final foregroundColor =
        action.isDanger ? const Color(0xFFFFB6BD) : const Color(0xFF0D1A0F);

    return SizedBox(
      height: 46,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withOpacity(0.55),
          disabledForegroundColor: foregroundColor.withOpacity(0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                ),
              )
            : Icon(action.icon, size: 18),
        label: Text(
          isLoading ? 'Обновление...' : action.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.action,
    required this.isLoading,
    required this.onTap,
  });

  final _OrderAction action;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        action.isDanger ? const Color(0x66FF7C7C) : const Color(0x554D79FF);
    final backgroundColor =
        action.isDanger ? const Color(0x22FF7C7C) : const Color(0x334D79FF);
    final foregroundColor =
        action.isDanger ? const Color(0xFFFF9DA6) : const Color(0xFFAEBEFF);

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                  ),
                )
              else
                Icon(
                  action.icon,
                  size: 16,
                  color: foregroundColor,
                ),
              const SizedBox(width: 8),
              Text(
                action.label,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderInfoRow extends StatelessWidget {
  const _OrderInfoRow({
    required this.icon,
    required this.title,
    this.trailing,
    this.trailingColor,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF8A98AC), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Text(
            trailing!,
            style: TextStyle(
              color: trailingColor ?? const Color(0xFF9AA7B8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.meta});

  final _OrderStatusMeta meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: meta.backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: meta.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, color: meta.textColor, size: 13),
          const SizedBox(width: 4),
          Text(
            meta.label,
            style: TextStyle(
              color: meta.textColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: Border.all(color: borderColor),
      ),
      child: Icon(icon, size: 18, color: iconColor),
    );
  }
}

class _OrdersLoadingState extends StatelessWidget {
  const _OrdersLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      children: List.generate(
        4,
        (index) => Container(
          height: 220,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: const Color(0xFF132131),
            border: Border.all(color: const Color(0xFF223247)),
          ),
          child: const Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrdersErrorState extends StatelessWidget {
  const _OrdersErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFFF8A8A),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF489F2A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersEmptyState extends StatelessWidget {
  const _OrdersEmptyState({
    required this.statusCode,
    required this.onRefresh,
  });

  final String statusCode;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final text = statusCode == 'ALL'
        ? 'Заказов пока нет'
        : 'По выбранному статусу заказов нет';

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: const Color(0xFF111C2B),
              border: Border.all(color: const Color(0xFF223247)),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: Color(0xFF489F2A),
                  size: 46,
                ),
                SizedBox(height: 12),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Потяни вниз для обновления',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderFilterItem {
  const _OrderFilterItem({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;
}

class _OrderAction {
  const _OrderAction({
    required this.nextStatus,
    required this.label,
    required this.icon,
    this.isPrimary = false,
    this.isDanger = false,
  });

  final String nextStatus;
  final String label;
  final IconData icon;
  final bool isPrimary;
  final bool isDanger;
}

class _OrderStatusMeta {
  const _OrderStatusMeta({
    required this.label,
    required this.icon,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String label;
  final IconData icon;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;

  static _OrderStatusMeta fromStatus(String status) {
    switch (status) {
      case 'CREATED':
        return const _OrderStatusMeta(
          label: 'Новый',
          icon: Icons.fiber_new,
          textColor: Color(0xFF66D7FF),
          backgroundColor: Color(0x1A66D7FF),
          borderColor: Color(0x3366D7FF),
        );
      case 'ACCEPTED':
        return const _OrderStatusMeta(
          label: 'Принят',
          icon: Icons.check_circle_outline,
          textColor: Color(0xFF00E676),
          backgroundColor: Color(0x1A00E676),
          borderColor: Color(0x3300E676),
        );
      case 'COOKING':
        return const _OrderStatusMeta(
          label: 'Готовится',
          icon: Icons.local_fire_department_outlined,
          textColor: Color(0xFFFFC857),
          backgroundColor: Color(0x1AFFC857),
          borderColor: Color(0x33FFC857),
        );
      case 'READY':
        return const _OrderStatusMeta(
          label: 'Готов',
          icon: Icons.done_all,
          textColor: Color(0xFFB46CFF),
          backgroundColor: Color(0x1AB46CFF),
          borderColor: Color(0x33B46CFF),
        );
      case 'ON_THE_WAY':
        return const _OrderStatusMeta(
          label: 'В пути',
          icon: Icons.delivery_dining,
          textColor: Color(0xFFFF9E57),
          backgroundColor: Color(0x1AFF9E57),
          borderColor: Color(0x33FF9E57),
        );
      case 'DELIVERED':
        return const _OrderStatusMeta(
          label: 'Доставлен',
          icon: Icons.verified,
          textColor: Color(0xFF7CFF9E),
          backgroundColor: Color(0x1A7CFF9E),
          borderColor: Color(0x337CFF9E),
        );
      case 'CANCELED':
        return const _OrderStatusMeta(
          label: 'Отменён',
          icon: Icons.cancel_outlined,
          textColor: Color(0xFFFF7C7C),
          backgroundColor: Color(0x1AFF7C7C),
          borderColor: Color(0x33FF7C7C),
        );
      case 'PAID':
        return const _OrderStatusMeta(
          label: 'Оплачен',
          icon: Icons.payments_outlined,
          textColor: Color(0xFF67E8F9),
          backgroundColor: Color(0x1A67E8F9),
          borderColor: Color(0x3367E8F9),
        );
      default:
        return const _OrderStatusMeta(
          label: 'Неизвестно',
          icon: Icons.help_outline,
          textColor: Color(0xFFB0BEC5),
          backgroundColor: Color(0x1AB0BEC5),
          borderColor: Color(0x33B0BEC5),
        );
    }
  }
}