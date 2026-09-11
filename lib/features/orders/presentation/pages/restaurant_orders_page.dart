import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/localization/app_locale_controller.dart';
import 'package:jetkiz_restaurant/core/push/restaurant_push_notification_service.dart';
import 'package:jetkiz_restaurant/features/orders/data/restaurant_orders_api.dart';
import 'package:jetkiz_restaurant/features/orders/data/restaurant_orders_sync_bus.dart';
import 'package:jetkiz_restaurant/features/orders/presentation/pages/restaurant_order_details_page.dart';

class RestaurantOrdersPage extends StatefulWidget {
  const RestaurantOrdersPage({super.key, this.hideBottomBar = false});

  final bool hideBottomBar;

  @override
  State<RestaurantOrdersPage> createState() => _RestaurantOrdersPageState();
}

class _RestaurantOrdersPageState extends State<RestaurantOrdersPage>
    with SingleTickerProviderStateMixin {
  final RestaurantOrdersApi _ordersApi = RestaurantOrdersApi();

  late final AnimationController _blinkController;
  StreamSubscription<void>? _pushRefreshSubscription;
  StreamSubscription<void>? _fallbackRefreshSubscription;

  bool _isLoading = true;
  bool _silentRefreshInFlight = false;
  int _foregroundLoadsInFlight = 0;
  int _loadGeneration = 0;
  String? _error;

  List<Map<String, dynamic>> _allOrders = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _visibleOrders = <Map<String, dynamic>>[];

  final Set<String> _updatingOrderIds = <String>{};
  final Set<String> _pendingReadyOrderIds = <String>{};
  final Map<String, Timer> _pendingReadyTimers = <String, Timer>{};

  String _selectedStatus = 'CREATED';

  final List<_OrderFilterItem> _filters = const [
    _OrderFilterItem(code: 'ALL', label: 'Все'),
    _OrderFilterItem(code: 'CREATED', label: 'Новые'),
    _OrderFilterItem(code: 'ACCEPTED', label: 'Приняты'),
    _OrderFilterItem(code: 'COOKING', label: 'Готовятся'),
    _OrderFilterItem(code: 'READY', label: 'Готовы'),
    _OrderFilterItem(code: 'ON_THE_WAY', label: 'В пути'),
    _OrderFilterItem(code: 'DELIVERED', label: 'Доставлены'),
    _OrderFilterItem(code: 'REJECTED', label: 'Отклонены'),
    _OrderFilterItem(code: 'CANCELED', label: 'Отменены'),
  ];

  String _t(String ru, String kk) => context.tr(ru, kk);

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

  @override
  void initState() {
    super.initState();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pushRefreshSubscription = RestaurantPushNotificationService
        .instance
        .ordersRefreshEvents
        .listen((_) => unawaited(_loadOrders(silent: true)));
    _fallbackRefreshSubscription = RestaurantOrdersSyncBus.instance.events
        .listen((_) => unawaited(_loadOrders(silent: true)));

    _loadOrders();
  }

  @override
  void dispose() {
    _pushRefreshSubscription?.cancel();
    _fallbackRefreshSubscription?.cancel();
    // READY confirmation timers intentionally survive this page's lifecycle.
    // A restaurant may leave the Orders tab during the 5-second undo window;
    // the confirmed transition still has to reach the server unless undone.
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders({bool silent = false}) async {
    // Background refreshes must never supersede an explicit filter/retry load.
    if (silent &&
        (_silentRefreshInFlight || _foregroundLoadsInFlight > 0)) {
      return;
    }

    final generation = ++_loadGeneration;
    final requestedStatus = _selectedStatus;

    if (silent) {
      _silentRefreshInFlight = true;
    } else {
      _foregroundLoadsInFlight += 1;
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }
    }

    try {
      final result = await _ordersApi.getOrders(
        status: requestedStatus == 'ALL' ? null : requestedStatus,
      );

      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _allOrders = result;
        _applyFilter();
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;

      if (silent) {
        debugPrint('Restaurant orders silent refresh failed: $e');
        return;
      }

      setState(() {
        _error = _cleanError(e);
        _isLoading = false;
      });
    } finally {
      if (silent) {
        _silentRefreshInFlight = false;
      } else if (_foregroundLoadsInFlight > 0) {
        _foregroundLoadsInFlight -= 1;
      }
    }
  }

  Future<void> _refresh() async {
    await _loadOrders(silent: true);
  }

  String _cleanError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    if (raw.isEmpty ||
        raw.length > 220 ||
        lower.contains('dioexception') ||
        lower.contains('socketexception') ||
        lower.contains('exception') ||
        lower.contains('backend') ||
        lower.contains('api') ||
        lower.contains('endpoint') ||
        lower.contains('status code') ||
        lower.contains('http 4') ||
        lower.contains('http 5')) {
      return 'Не удалось загрузить заказы. Проверьте интернет и повторите.';
    }
    return raw;
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

  void _selectFilter(String status) {
    if (_selectedStatus == status) return;

    setState(() {
      _selectedStatus = status;
    });
    unawaited(_loadOrders());
  }

  Future<void> _openOrder(Map<String, dynamic> order) async {
    final orderId = _string(order['id']);

    if (orderId.isEmpty) {
      _showSnackBar('Не удалось определить заказ. Обновите список и повторите.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RestaurantOrderDetailsPage(orderId: orderId),
      ),
    );

    if (!mounted) return;
    await _loadOrders(silent: true);
  }

  Future<void> _changeStatus(
    Map<String, dynamic> order,
    String nextStatus, {
    String? rejectionReason,
    String? cancellationReason,
  }) async {
    final orderId = _string(order['id']);

    if (orderId.isEmpty) {
      _showSnackBar('Не удалось определить заказ. Обновите список и повторите.');
      return;
    }

    if (_updatingOrderIds.contains(orderId)) return;

    setState(() {
      _updatingOrderIds.add(orderId);
    });

    try {
      final Map<String, dynamic> updated;
      if (nextStatus == 'REJECTED') {
        updated = await _ordersApi.rejectOrder(
          id: orderId,
          reason: rejectionReason ?? '',
        );
      } else if (nextStatus == 'CANCELED') {
        updated = await _ordersApi.cancelOrder(
          id: orderId,
          reason: cancellationReason ?? '',
        );
      } else {
        updated = await _ordersApi.updateOrderStatus(
          id: orderId,
          status: nextStatus,
        );
      }

      if (!mounted) return;

      setState(() {
        _allOrders = _allOrders.map((item) {
          if (_string(item['id']) != orderId) return item;
          return updated;
        }).toList();

        _applyFilter();
      });

      _showSnackBar(
        _statusChangedMessage(nextStatus, isPickup: _isPickup(order)),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(_cleanError(e));
    } finally {
      if (!mounted) return;

      setState(() {
        _updatingOrderIds.remove(orderId);
      });
    }
  }

  Future<void> _confirmReject(Map<String, dynamic> order) async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canSubmit = controller.text.trim().isNotEmpty;

            return AlertDialog(
              backgroundColor: const Color(0xFF111827),
              title: const Text(
                'Отклонить заказ?',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Укажите причину отклонения. Она будет сохранена в истории заказа.',
                    style: TextStyle(color: Color(0xFFCBD5E1)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 250,
                    maxLines: 3,
                    onChanged: (_) => setDialogState(() {}),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Например: блюдо закончилось',
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF0B1220),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFDC2626)),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Назад'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                  onPressed: canSubmit
                      ? () => Navigator.of(context).pop(controller.text.trim())
                      : null,
                  child: const Text('Отклонить'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (reason != null && reason.trim().isNotEmpty) {
      await _changeStatus(order, 'REJECTED', rejectionReason: reason);
    }
  }

  Future<void> _confirmCancel(Map<String, dynamic> order) async {
    final controller = TextEditingController();
    final paid = _string(order['paymentStatus']).toUpperCase() == 'PAID';

    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canSubmit = controller.text.trim().isNotEmpty;

            return AlertDialog(
              backgroundColor: const Color(0xFF111827),
              title: const Text(
                'Отменить заказ?',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paid
                        ? 'Заказ уже оплачен. После отмены JETKIZ запустит возврат оплаты клиенту. Укажите причину.'
                        : 'Отмена завершит заказ. Укажите причину — она сохранится в истории.',
                    style: const TextStyle(color: Color(0xFFCBD5E1)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 250,
                    maxLines: 3,
                    onChanged: (_) => setDialogState(() {}),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Например: закончился ингредиент',
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF0B1220),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFDC2626)),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Не отменять'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                  onPressed: canSubmit
                      ? () => Navigator.of(context).pop(controller.text.trim())
                      : null,
                  child: const Text('Отменить заказ'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (reason != null && reason.trim().isNotEmpty) {
      await _changeStatus(order, 'CANCELED', cancellationReason: reason);
    }
  }

  Future<void> _confirmReady(Map<String, dynamic> order) async {
    // Only one order may be inside the short undo window at a time. This keeps
    // the undo action visible and prevents a second SnackBar from making the
    // first READY transition impossible to cancel.
    if (_pendingReadyOrderIds.isNotEmpty) return;

    final isPickup = _isPickup(order);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text(
          isPickup
              ? _t('Заказ готов к выдаче?', 'Тапсырыс беруге дайын ба?')
              : _t('Заказ готов?', 'Тапсырыс дайын ба?'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          isPickup
              ? _t(
                  'После подтверждения клиент увидит, что заказ можно забирать.',
                  'Растағаннан кейін клиент тапсырысты алып кетуге болатынын көреді.',
                )
              : _t(
                  'После подтверждения JETKIZ сможет начать назначение курьера. Проверьте, что заказ действительно готов.',
                  'Растағаннан кейін JETKIZ курьер тағайындауды бастай алады. Тапсырыстың шынымен дайын екенін тексеріңіз.',
                ),
          style: const TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_t('Назад', 'Артқа')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(_t('Да, готов', 'Иә, дайын')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final orderId = _orderId(order);
    if (orderId.isEmpty ||
        _pendingReadyOrderIds.contains(orderId) ||
        _updatingOrderIds.contains(orderId)) {
      return;
    }

    setState(() => _pendingReadyOrderIds.add(orderId));
    var canceled = false;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();

    final timer = Timer(const Duration(seconds: 5), () {
      _pendingReadyTimers.remove(orderId);
      _pendingReadyOrderIds.remove(orderId);
      if (canceled) {
        if (mounted) setState(() {});
        return;
      }
      unawaited(_commitReady(order, orderId));
    });
    _pendingReadyTimers[orderId] = timer;

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Text(
          isPickup
              ? _t(
                  'Заказ будет отмечен готовым к выдаче',
                  'Тапсырыс беруге дайын деп белгіленеді',
                )
              : _t(
                  'Заказ будет отмечен готовым',
                  'Тапсырыс дайын деп белгіленеді',
                ),
        ),
        action: SnackBarAction(
          label: _t('Отменить действие', 'Әрекетті болдырмау'),
          onPressed: () {
            canceled = true;
            _pendingReadyTimers.remove(orderId)?.cancel();
            _pendingReadyOrderIds.remove(orderId);
            if (!mounted) return;
            setState(() {});
            _showSnackBar(_t('Действие отменено', 'Әрекет болдырылмады'));
          },
        ),
      ),
    );
  }

  Future<void> _commitReady(
    Map<String, dynamic> order,
    String orderId,
  ) async {
    _updatingOrderIds.add(orderId);
    if (mounted) setState(() {});

    try {
      final updated = await _ordersApi.updateOrderStatus(
        id: orderId,
        status: 'READY',
      );

      if (!mounted) return;
      setState(() {
        _allOrders = _allOrders.map((item) {
          return _orderId(item) == orderId ? updated : item;
        }).toList();
        _applyFilter();
      });
      _showSnackBar(
        _statusChangedMessage('READY', isPickup: _isPickup(order)),
      );
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(
        _safeError(
          error,
          'Не удалось отметить заказ готовым. Попробуйте ещё раз.',
          'Тапсырысты дайын деп белгілеу мүмкін болмады. Қайта көріңіз.',
        ),
      );
    } finally {
      _updatingOrderIds.remove(orderId);
      if (mounted) setState(() {});
    }
  }

  String _statusChangedMessage(String status, {required bool isPickup}) {
    switch (status) {
      case 'ACCEPTED':
        return 'Заказ принят';
      case 'COOKING':
        return 'Заказ переведён в приготовление';
      case 'READY':
        return isPickup ? 'Заказ готов к выдаче' : 'Заказ готов';
      case 'CANCELED':
        return 'Заказ отменён';
      case 'REJECTED':
        return 'Заказ отклонён';
      default:
        return 'Статус заказа обновлён';
    }
  }

  String _status(Map<String, dynamic> order) {
    return _string(order['status']).toUpperCase();
  }

  String _fulfillmentType(Map<String, dynamic> order) {
    return _string(order['fulfillmentType']).toUpperCase();
  }

  bool _isPickup(Map<String, dynamic> order) {
    return _fulfillmentType(order) == 'PICKUP';
  }

  bool _isPickupVerified(Map<String, dynamic> order) {
    return _dateTime(order['pickupCodeVerifiedAt']) != null;
  }

  bool _isIssuedPickup(Map<String, dynamic> order) {
    return _isPickup(order) &&
        (_isPickupVerified(order) || _status(order) == 'DELIVERED');
  }

  String _orderId(Map<String, dynamic> order) {
    return _string(order['id']);
  }

  String _orderNumber(Map<String, dynamic> order) {
    final number = order['number'];

    if (number == null) return '—';

    final text = number.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '—';

    return '#$text';
  }

  int _money(Map<String, dynamic> order, String key) {
    return _int(order[key]);
  }

  int _itemsCount(Map<String, dynamic> order) {
    final rawItemsCount = _int(order['itemsCount']);

    if (rawItemsCount > 0) return rawItemsCount;

    final items = order['items'];
    if (items is List) return items.length;

    final previewItems = order['previewItems'];
    if (previewItems is List) return previewItems.length;

    return 0;
  }

  List<_OrderPreviewItem> _previewItems(Map<String, dynamic> order) {
    final raw = order['previewItems'] is List
        ? order['previewItems'] as List
        : order['items'] is List
        ? order['items'] as List
        : const <dynamic>[];

    return raw
        .whereType<Map>()
        .map(
          (item) => _OrderPreviewItem(
            title: _string(item['title']).isEmpty
                ? 'Позиция'
                : _string(item['title']),
            quantity: _int(item['quantity']),
            price: _int(item['price']),
          ),
        )
        .toList();
  }

  bool _isTerminal(Map<String, dynamic> order) {
    final status = _status(order);
    return status == 'DELIVERED' || status == 'REJECTED' || status == 'CANCELED';
  }

  String _clientName(Map<String, dynamic> order) {
    final user = order['user'];

    if (user is Map) {
      final firstName = _string(user['firstName']);
      final lastName = _string(user['lastName']);
      final fullName = '$firstName $lastName'.trim();

      if (fullName.isNotEmpty) return fullName;

      if (!_isTerminal(order)) {
        final phone = _string(user['phone']);
        if (phone.isNotEmpty) return phone;
      }
    }

    if (!_isTerminal(order)) {
      final phone = _string(order['phone']);
      if (phone.isNotEmpty) return phone;
    }

    return 'Клиент';
  }

  String _courierName(Map<String, dynamic> order) {
    final courier = order['courier'];

    if (courier is Map) {
      final firstName = _string(courier['firstName']);
      final lastName = _string(courier['lastName']);
      final fullName = '$firstName $lastName'.trim();

      if (fullName.isNotEmpty) return fullName;

      final phone = _string(courier['phone']);
      if (phone.isNotEmpty) return phone;
    }

    return 'Курьер не назначен';
  }

  DateTime? _createdAt(Map<String, dynamic> order) {
    return _dateTime(order['createdAt']);
  }

  DateTime? _promisedAt(Map<String, dynamic> order) {
    return _dateTime(order['promisedAt']);
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '—';

    final local = value.toLocal();

    return '${_two(local.day)}.${_two(local.month)}.${local.year} '
        '${_two(local.hour)}:${_two(local.minute)}';
  }

  String _two(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _string(dynamic value) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return '';
    }

    return text;
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();

    final text = value?.toString().trim() ?? '';

    if (text.isEmpty || text.toLowerCase() == 'null') return 0;

    return int.tryParse(text) ?? double.tryParse(text)?.round() ?? 0;
  }

  DateTime? _dateTime(dynamic value) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty || text.toLowerCase() == 'null') return null;

    return DateTime.tryParse(text);
  }

  bool _isUpdating(Map<String, dynamic> order) {
    final orderId = _orderId(order);
    return _updatingOrderIds.contains(orderId) ||
        _pendingReadyOrderIds.contains(orderId);
  }

  List<_OrderAction> _actionsFor(Map<String, dynamic> order) {
    final status = _status(order);
    final isPickup = _isPickup(order);

    switch (status) {
      case 'CREATED':
        return const [
          _OrderAction(
            label: 'Принять',
            nextStatus: 'ACCEPTED',
            icon: Icons.check_circle_outline,
            isPrimary: true,
          ),
          _OrderAction(
            label: 'Отклонить',
            nextStatus: 'REJECTED',
            icon: Icons.cancel_outlined,
            isDanger: true,
          ),
        ];
      case 'ACCEPTED':
        return const [
          _OrderAction(
            label: 'Готовить',
            nextStatus: 'COOKING',
            icon: Icons.restaurant_rounded,
            isPrimary: true,
          ),
          _OrderAction(
            label: 'Отменить',
            nextStatus: 'CANCELED',
            icon: Icons.close_rounded,
            isDanger: true,
          ),
        ];
      case 'COOKING':
        return [
          _OrderAction(
            label: isPickup ? 'Готов к выдаче' : 'Готов',
            nextStatus: 'READY',
            icon: Icons.done_all_rounded,
            isPrimary: true,
          ),
          const _OrderAction(
            label: 'Отменить',
            nextStatus: 'CANCELED',
            icon: Icons.close_rounded,
            isDanger: true,
          ),
        ];
      default:
        return const [];
    }
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF030712);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _OrdersHeader(
              totalCount: _allOrders.length,
              selectedStatus: _selectedStatus,
              filters: _filters,
              onFilterSelected: _selectFilter,
            ),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF489F2A),
                backgroundColor: const Color(0xFF111827),
                onRefresh: _refresh,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 180),
        children: const [
          Center(child: CircularProgressIndicator(color: Color(0xFF489F2A))),
        ],
      );
    }

    if (_error != null) {
      return _OrdersErrorState(message: _error!, onRetry: _loadOrders);
    }

    if (_visibleOrders.isEmpty) {
      return _OrdersEmptyState(selectedStatus: _selectedStatus);
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 14, 16, widget.hideBottomBar ? 120 : 24),
      itemCount: _visibleOrders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = _visibleOrders[index];
        final isPickup = _isPickup(order);

        return _RestaurantOrderCard(
          orderNumber: _orderNumber(order),
          status: _status(order),
          isPickup: isPickup,
          isIssuedPickup: _isIssuedPickup(order),
          total: _money(order, 'total'),
          subtotal: _money(order, 'subtotal'),
          deliveryFee: _money(order, 'deliveryFee'),
          paymentStatus: _string(order['paymentStatus']),
          clientName: _clientName(order),
          courierName: isPickup ? 'Клиент заберёт сам' : _courierName(order),
          createdAt: _formatDateTime(_createdAt(order)),
          promisedAt: _formatDateTime(_promisedAt(order)),
          itemsCount: _itemsCount(order),
          previewItems: _previewItems(order),
          isUpdating: _isUpdating(order),
          actions: _actionsFor(order),
          blinkController: _blinkController,
          onTap: () => _openOrder(order),
          onActionTap: (action) {
            if (action.nextStatus == 'REJECTED') {
              unawaited(_confirmReject(order));
              return;
            }
            if (action.nextStatus == 'CANCELED') {
              unawaited(_confirmCancel(order));
              return;
            }
            if (action.nextStatus == 'READY') {
              unawaited(_confirmReady(order));
              return;
            }

            unawaited(_changeStatus(order, action.nextStatus));
          },
        );
      },
    );
  }
}

class _OrdersHeader extends StatelessWidget {
  const _OrdersHeader({
    required this.totalCount,
    required this.selectedStatus,
    required this.filters,
    required this.onFilterSelected,
  });

  final int totalCount;
  final String selectedStatus;
  final List<_OrderFilterItem> filters;
  final ValueChanged<String> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF489F2A), Color(0xFF3A7E21)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'jetkiz',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Заказы',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$totalCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = filters[index];
                final selected = selectedStatus == item.code;

                return InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onFilterSelected(item.code),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFF489F2A)
                            : Colors.white.withValues(alpha: 0.92),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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
    required this.status,
    required this.isPickup,
    required this.isIssuedPickup,
    required this.total,
    required this.subtotal,
    required this.deliveryFee,
    required this.paymentStatus,
    required this.clientName,
    required this.courierName,
    required this.createdAt,
    required this.promisedAt,
    required this.itemsCount,
    required this.previewItems,
    required this.isUpdating,
    required this.actions,
    required this.blinkController,
    required this.onTap,
    required this.onActionTap,
  });

  final String orderNumber;
  final String status;
  final bool isPickup;
  final bool isIssuedPickup;
  final int total;
  final int subtotal;
  final int deliveryFee;
  final String paymentStatus;
  final String clientName;
  final String courierName;
  final String createdAt;
  final String promisedAt;
  final int itemsCount;
  final List<_OrderPreviewItem> previewItems;
  final bool isUpdating;
  final List<_OrderAction> actions;
  final AnimationController blinkController;
  final VoidCallback onTap;
  final ValueChanged<_OrderAction> onActionTap;

  @override
  Widget build(BuildContext context) {
    final meta = _OrderStatusMeta.fromStatus(
      status,
      isPickup: isPickup,
      isIssuedPickup: isIssuedPickup,
    );
    final isNew = status == 'CREATED';

    return AnimatedBuilder(
      animation: blinkController,
      builder: (context, child) {
        final borderAlpha = isNew
            ? 0.35 + (blinkController.value * 0.35)
            : 0.16;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: meta.textColor.withValues(alpha: borderAlpha),
                  width: isNew ? 1.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.26),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusBadge(meta: meta),
              if (isPickup) ...[const SizedBox(width: 8), const _PickupBadge()],
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  orderNumber == '—' ? 'Заказ' : 'Заказ $orderNumber',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$total ₸',
                style: const TextStyle(
                  color: Color(0xFF86EFAC),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SmallInfoBlock(
                  label: 'Клиент',
                  value: clientName,
                  icon: Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallInfoBlock(
                  label: isPickup ? 'Получение' : 'Курьер',
                  value: courierName,
                  icon: isPickup
                      ? Icons.storefront_rounded
                      : Icons.delivery_dining_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SmallInfoBlock(
                  label: 'Создан',
                  value: createdAt,
                  icon: Icons.schedule_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallInfoBlock(
                  label: 'Обещано к',
                  value: promisedAt,
                  icon: Icons.timer_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MoneyRow(
            subtotal: subtotal,
            deliveryFee: deliveryFee,
            total: total,
            paymentStatus: paymentStatus,
            isPickup: isPickup,
          ),
          const SizedBox(height: 12),
          _ItemsPreview(itemsCount: itemsCount, items: previewItems),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: actions.map((action) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: action == actions.last ? 0 : 8,
                    ),
                    child: _OrderActionButton(
                      action: action,
                      isLoading: isUpdating,
                      onTap: () => onActionTap(action),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _PickupBadge extends StatelessWidget {
  const _PickupBadge();

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFB0BEC5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storefront_rounded, size: 13, color: color),
          SizedBox(width: 5),
          Text(
            'Самовывоз',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.meta});

  final _OrderStatusMeta meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: meta.backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: meta.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 14, color: meta.textColor),
          const SizedBox(width: 5),
          Text(
            meta.label,
            style: TextStyle(
              color: meta.textColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallInfoBlock extends StatelessWidget {
  const _SmallInfoBlock({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.trim().isEmpty ? '—' : value.trim();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  safeValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.paymentStatus,
    required this.isPickup,
  });

  final int subtotal;
  final int deliveryFee;
  final int total;
  final String paymentStatus;
  final bool isPickup;

  @override
  Widget build(BuildContext context) {
    final paymentText = _paymentStatusLabel(paymentStatus);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        children: [
          _Line(label: 'Подытог', value: '$subtotal ₸'),
          const SizedBox(height: 5),
          _Line(
            label: 'Доставка',
            value: isPickup ? 'Самовывоз' : '$deliveryFee ₸',
          ),
          const SizedBox(height: 5),
          _Line(label: 'Оплата', value: paymentText),
          const Divider(height: 16, color: Color(0xFF1F2937)),
          _Line(label: 'Итого', value: '$total ₸', strong: true),
        ],
      ),
    );
  }

  static String _paymentStatusLabel(String status) {
    switch (status.trim().toUpperCase()) {
      case 'PAID':
        return 'Оплачено';
      case 'PENDING':
        return 'Ожидает оплаты';
      case 'FAILED':
        return 'Ошибка оплаты';
      case 'REFUNDED':
        return 'Возврат';
      case 'CANCELED':
      case 'CANCELLED':
        return 'Отменено';
      default:
        return status.trim().isEmpty ? 'Не указано' : status;
    }
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: strong ? Colors.white : const Color(0xFF94A3B8),
              fontSize: strong ? 14 : 12,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: strong ? const Color(0xFF86EFAC) : Colors.white,
            fontSize: strong ? 15 : 12,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ItemsPreview extends StatelessWidget {
  const _ItemsPreview({required this.itemsCount, required this.items});

  final int itemsCount;
  final List<_OrderPreviewItem> items;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.restaurant_menu_rounded,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  itemsCount > 0
                      ? 'Позиции заказа: $itemsCount'
                      : 'Позиции заказа',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (visibleItems.isEmpty)
            const Text(
              'Позиции не указаны',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            )
          else
            ...visibleItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.quantity} × ${item.price} ₸',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (items.length > 3)
            Text(
              'Ещё ${items.length - 3} поз.',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderActionButton extends StatelessWidget {
  const _OrderActionButton({
    required this.action,
    required this.isLoading,
    required this.onTap,
  });

  final _OrderAction action;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = action.isDanger
        ? const Color(0xFFDC2626)
        : action.isPrimary
        ? const Color(0xFF489F2A)
        : const Color(0xFF1F2937);

    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onTap,
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(action.icon, size: 18),
        label: Text(
          isLoading ? 'Обновление...' : action.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          disabledBackgroundColor: bg.withValues(alpha: 0.55),
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _OrdersErrorState extends StatelessWidget {
  const _OrdersErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 140, 24, 120),
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: Color(0xFFEF4444),
          size: 46,
        ),
        const SizedBox(height: 14),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF489F2A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Повторить'),
          ),
        ),
      ],
    );
  }
}

class _OrdersEmptyState extends StatelessWidget {
  const _OrdersEmptyState({required this.selectedStatus});

  final String selectedStatus;

  @override
  Widget build(BuildContext context) {
    final text = selectedStatus == 'ALL'
        ? 'Заказов пока нет'
        : 'Заказов с выбранным статусом нет';

    final subtitle = selectedStatus == 'ALL'
        ? 'Новые заказы появятся на этом экране'
        : 'Попробуйте выбрать другой фильтр';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 140, 24, 120),
      children: [
        const Icon(
          Icons.receipt_long_outlined,
          color: Color(0xFF6B7280),
          size: 54,
        ),
        const SizedBox(height: 14),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
        ),
      ],
    );
  }
}

class _OrderFilterItem {
  const _OrderFilterItem({required this.code, required this.label});

  final String code;
  final String label;
}

class _OrderPreviewItem {
  const _OrderPreviewItem({
    required this.title,
    required this.quantity,
    required this.price,
  });

  final String title;
  final int quantity;
  final int price;
}

class _OrderAction {
  const _OrderAction({
    required this.label,
    required this.nextStatus,
    required this.icon,
    this.isPrimary = false,
    this.isDanger = false,
  });

  final String label;
  final String nextStatus;
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

  static _OrderStatusMeta fromStatus(
    String status, {
    required bool isPickup,
    required bool isIssuedPickup,
  }) {
    final normalizedStatus = status.trim().toUpperCase();

    if (isPickup && isIssuedPickup) {
      return const _OrderStatusMeta(
        label: 'Выдан',
        icon: Icons.verified_rounded,
        textColor: Color(0xFF7CFF9E),
        backgroundColor: Color(0x1A7CFF9E),
        borderColor: Color(0x337CFF9E),
      );
    }

    switch (normalizedStatus) {
      case 'CREATED':
        return const _OrderStatusMeta(
          label: 'Новый',
          icon: Icons.fiber_new_rounded,
          textColor: Color(0xFF60A5FA),
          backgroundColor: Color(0x1A60A5FA),
          borderColor: Color(0x3360A5FA),
        );
      case 'ACCEPTED':
        return const _OrderStatusMeta(
          label: 'Принят',
          icon: Icons.check_circle_outline,
          textColor: Color(0xFF7CFF9E),
          backgroundColor: Color(0x1A7CFF9E),
          borderColor: Color(0x337CFF9E),
        );
      case 'COOKING':
        return const _OrderStatusMeta(
          label: 'Готовится',
          icon: Icons.restaurant_rounded,
          textColor: Color(0xFFFFC857),
          backgroundColor: Color(0x1AFFC857),
          borderColor: Color(0x33FFC857),
        );
      case 'READY':
        return _OrderStatusMeta(
          label: isPickup ? 'Готов к выдаче' : 'Готов',
          icon: Icons.done_all_rounded,
          textColor: const Color(0xFFB46CFF),
          backgroundColor: const Color(0x1AB46CFF),
          borderColor: const Color(0x33B46CFF),
        );
      case 'ON_THE_WAY':
        return const _OrderStatusMeta(
          label: 'В пути',
          icon: Icons.delivery_dining_rounded,
          textColor: Color(0xFFFF9E57),
          backgroundColor: Color(0x1AFF9E57),
          borderColor: Color(0x33FF9E57),
        );
      case 'DELIVERED':
        return _OrderStatusMeta(
          label: isPickup ? 'Выдан' : 'Доставлен',
          icon: Icons.verified_rounded,
          textColor: const Color(0xFF7CFF9E),
          backgroundColor: const Color(0x1A7CFF9E),
          borderColor: const Color(0x337CFF9E),
        );
      case 'REJECTED':
        return const _OrderStatusMeta(
          label: 'Отклонён',
          icon: Icons.cancel_outlined,
          textColor: Color(0xFFFF7C7C),
          backgroundColor: Color(0x1AFF7C7C),
          borderColor: Color(0x33FF7C7C),
        );
      case 'CANCELED':
      case 'CANCELLED':
        return const _OrderStatusMeta(
          label: 'Отменён',
          icon: Icons.cancel_outlined,
          textColor: Color(0xFFFF7C7C),
          backgroundColor: Color(0x1AFF7C7C),
          borderColor: Color(0x33FF7C7C),
        );
      default:
        return const _OrderStatusMeta(
          label: 'Неизвестно',
          icon: Icons.help_outline_rounded,
          textColor: Color(0xFFB0BEC5),
          backgroundColor: Color(0x1AB0BEC5),
          borderColor: Color(0x33B0BEC5),
        );
    }
  }
}
