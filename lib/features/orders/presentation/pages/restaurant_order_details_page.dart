import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/orders/data/restaurant_orders_api.dart';
import 'package:jetkiz_restaurant/features/orders/domain/restaurant_order_details.dart';

// JETKIZ RESTAURANT APP
// Restaurant order details page.
//
// BACKEND:
// - GET /orders/:id
// - POST /orders/:id/verify-pickup
//
// PICKUP:
// Restaurant issues pickup orders only through client pickup code.
// Never mark PICKUP as DELIVERED through regular status update from this screen.

class RestaurantOrderDetailsPage extends StatefulWidget {
  const RestaurantOrderDetailsPage({super.key, required this.orderId});

  final String orderId;

  @override
  State<RestaurantOrderDetailsPage> createState() =>
      _RestaurantOrderDetailsPageState();
}

class _RestaurantOrderDetailsPageState
    extends State<RestaurantOrderDetailsPage> {
  late final ApiClient _apiClient;
  late final RestaurantOrdersApi _ordersApi;

  Future<RestaurantOrderDetails>? _orderFuture;
  bool _isVerifyingPickup = false;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _ordersApi = RestaurantOrdersApi(apiClient: _apiClient);
    _loadOrder();
  }

  void _loadOrder() {
    setState(() {
      _orderFuture = _getOrderDetails();
    });
  }

  Future<void> _refresh() async {
    _loadOrder();
    await _orderFuture;
  }

  Future<RestaurantOrderDetails> _getOrderDetails() async {
    final dynamic response = await _apiClient.get('/orders/${widget.orderId}');

    if (response is Map<String, dynamic>) {
      return RestaurantOrderDetails.fromJson(response);
    }

    if (response is Map) {
      return RestaurantOrderDetails.fromJson(
        Map<String, dynamic>.from(response),
      );
    }

    throw Exception('Некорректный ответ по заказу');
  }

  Future<void> _showPickupCodeSheet(RestaurantOrderDetails order) async {
    final result = await showModalBottomSheet<_PickupIssueResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _PickupCodeBottomSheet(
          cleanErrorMessage: _cleanErrorMessage,
          onSubmit: (pickupCode) async {
            if (_isVerifyingPickup) {
              return _PickupIssueResult.none;
            }

            if (mounted) {
              setState(() {
                _isVerifyingPickup = true;
              });
            } else {
              _isVerifyingPickup = true;
            }

            try {
              await _ordersApi.verifyPickup(
                id: order.id,
                pickupCode: pickupCode,
              );

              return _PickupIssueResult.issued;
            } catch (error) {
              if (_isAlreadyIssuedPickupError(error)) {
                return _PickupIssueResult.alreadyIssued;
              }

              rethrow;
            } finally {
              if (mounted) {
                setState(() {
                  _isVerifyingPickup = false;
                });
              } else {
                _isVerifyingPickup = false;
              }
            }
          },
        );
      },
    );

    if (!mounted || result == null || result == _PickupIssueResult.none) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == _PickupIssueResult.alreadyIssued
              ? 'Заказ уже выдан'
              : 'Заказ выдан',
        ),
        backgroundColor: const Color(0xFF489F2A),
      ),
    );

    _loadOrder();
  }

  String _cleanErrorMessage(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();

    if (message.isEmpty) {
      return 'Не удалось подтвердить выдачу';
    }

    return message;
  }

  bool _isAlreadyIssuedPickupError(Object error) {
    final message = _cleanErrorMessage(error).toLowerCase();

    return message.contains('current status: delivered') ||
        message.contains('already delivered') ||
        message.contains('already verified') ||
        message.contains('уже выдан') ||
        message.contains('уже доставлен');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09111C),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Детали заказа',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<RestaurantOrderDetails>(
          future: _orderFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _DetailsErrorState(
                message: snapshot.error.toString().replaceFirst(
                  'Exception: ',
                  '',
                ),
                onRetry: _loadOrder,
              );
            }

            final order = snapshot.data;
            if (order == null) {
              return _DetailsErrorState(
                message: 'Заказ не найден',
                onRetry: _loadOrder,
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.number != null
                                    ? 'Заказ #${order.number}'
                                    : 'Заказ',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _StatusBadge(
                              status: order.status,
                              isPickup: order.isPickup,
                              isIssuedPickup: order.isIssuedPickup,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _FulfillmentBadge(isPickup: order.isPickup),
                        const SizedBox(height: 14),
                        _InfoRow(label: 'ID', value: order.id),
                        _InfoRow(
                          label: 'Статус оплаты',
                          value: order.paymentStatus ?? 'Не указан',
                        ),
                        _InfoRow(
                          label: 'Оплата',
                          value: order.paymentMethod ?? 'Не указана',
                        ),
                        _InfoRow(
                          label: 'Подытог',
                          value: '${order.subtotal} ₸',
                        ),
                        _InfoRow(
                          label: 'Доставка',
                          value: order.isPickup
                              ? 'Самовывоз'
                              : '${order.deliveryFee} ₸',
                        ),
                        _InfoRow(label: 'Итого', value: '${order.total} ₸'),
                        if (order.createdAt != null)
                          _InfoRow(
                            label: 'Создан',
                            value: _formatDateTime(order.createdAt!.toLocal()),
                          ),
                        if (order.readyAt != null)
                          _InfoRow(
                            label: order.isPickup ? 'Готов к выдаче' : 'Готов',
                            value: _formatDateTime(order.readyAt!.toLocal()),
                          ),
                        if (order.promisedAt != null)
                          _InfoRow(
                            label: 'Обещано к',
                            value: _formatDateTime(order.promisedAt!.toLocal()),
                          ),
                        if (order.pickupCodeVerifiedAt != null)
                          _InfoRow(
                            label: 'Выдан',
                            value: _formatDateTime(
                              order.pickupCodeVerifiedAt!.toLocal(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('Клиент'),
                        const SizedBox(height: 12),
                        _InfoRow(
                          label: 'Имя',
                          value: order.user?.displayName ?? 'Не указан',
                        ),
                        _InfoRow(
                          label: 'Телефон',
                          value: (order.phone ?? '').trim().isNotEmpty
                              ? order.phone!.trim()
                              : ((order.user?.phone ?? '').trim().isNotEmpty
                                    ? order.user!.phone!.trim()
                                    : 'Не указан'),
                        ),
                        if (order.isPickup)
                          const _InfoRow(
                            label: 'Получение',
                            value: 'Клиент заберёт сам',
                          )
                        else ...[
                          _InfoRow(
                            label: 'Оставить у двери',
                            value: order.leaveAtDoor ? 'Да' : 'Нет',
                          ),
                          if ((order.address ?? '').trim().isNotEmpty)
                            _InfoRow(
                              label: 'Адрес',
                              value: order.address!.trim(),
                            ),
                        ],
                        if ((order.comment ?? '').trim().isNotEmpty)
                          _InfoRow(
                            label: 'Комментарий',
                            value: order.comment!.trim(),
                          ),
                      ],
                    ),
                  ),
                  if (order.isPickup) ...[
                    const SizedBox(height: 14),
                    _PickupIssueCard(
                      order: order,
                      onIssuePressed:
                          order.isReadyForPickupIssue && !_isVerifyingPickup
                          ? () => _showPickupCodeSheet(order)
                          : null,
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (order.isDelivery && order.courier != null) ...[
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle('Курьер'),
                          const SizedBox(height: 12),
                          _InfoRow(
                            label: 'Имя',
                            value: order.courier!.displayName,
                          ),
                          _InfoRow(
                            label: 'Телефон',
                            value:
                                (order.courier!.phone ?? '').trim().isNotEmpty
                                ? order.courier!.phone!.trim()
                                : 'Не указан',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('Состав заказа'),
                        const SizedBox(height: 12),
                        if (order.items.isEmpty)
                          const Text(
                            'Позиции отсутствуют',
                            style: TextStyle(color: Colors.white70),
                          )
                        else
                          ...order.items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _OrderItemTile(item: item),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime dateTime) {
    return '${_two(dateTime.day)}.${_two(dateTime.month)}.${dateTime.year} '
        '${_two(dateTime.hour)}:${_two(dateTime.minute)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

enum _PickupIssueResult { none, issued, alreadyIssued }

class _PickupCodeBottomSheet extends StatefulWidget {
  const _PickupCodeBottomSheet({
    required this.onSubmit,
    required this.cleanErrorMessage,
  });

  final Future<_PickupIssueResult> Function(String pickupCode) onSubmit;
  final String Function(Object error) cleanErrorMessage;

  @override
  State<_PickupCodeBottomSheet> createState() => _PickupCodeBottomSheetState();
}

class _PickupCodeBottomSheetState extends State<_PickupCodeBottomSheet> {
  final TextEditingController _controller = TextEditingController();

  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final pickupCode = _controller.text.trim();

    if (pickupCode.isEmpty) {
      setState(() {
        _errorText = 'Введите код клиента';
      });
      return;
    }

    if (pickupCode.length != 4) {
      setState(() {
        _errorText = 'Код должен состоять из 4 цифр';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final result = await widget.onSubmit(pickupCode);

      if (!mounted) return;

      if (result == _PickupIssueResult.issued ||
          result == _PickupIssueResult.alreadyIssued) {
        Navigator.of(context).pop(result);
        return;
      }

      setState(() {
        _isSubmitting = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _errorText = widget.cleanErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
        decoration: const BoxDecoration(
          color: Color(0xFF131E2D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Подтвердить выдачу',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Введите 4-значный код, который клиент показывает при получении заказа.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                enabled: !_isSubmitting,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '0000',
                  hintStyle: const TextStyle(
                    color: Colors.white24,
                    letterSpacing: 6,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1A2738),
                  errorText: _errorText,
                  errorStyle: const TextStyle(
                    color: Color(0xFFFF8A8A),
                    fontWeight: FontWeight.w600,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF26364A)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF26364A)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF70D74D),
                      width: 1.4,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFFF8A8A)),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFFFF8A8A),
                      width: 1.4,
                    ),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF489F2A),
                    disabledBackgroundColor: Colors.white12,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Подтвердить',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickupIssueCard extends StatelessWidget {
  const _PickupIssueCard({required this.order, required this.onIssuePressed});

  final RestaurantOrderDetails order;
  final VoidCallback? onIssuePressed;

  @override
  Widget build(BuildContext context) {
    final title = order.isIssuedPickup
        ? 'Заказ выдан'
        : order.isReadyForPickupIssue
        ? 'Готов к выдаче'
        : 'Самовывоз';

    final description = order.isIssuedPickup
        ? 'Код клиента подтверждён. Заказ закрыт как выданный.'
        : order.isReadyForPickupIssue
        ? 'Попросите клиента назвать или показать код получения.'
        : 'Клиент заберёт заказ сам. Курьер для этого заказа не нужен.';

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront, color: Color(0xFF70D74D), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          if (onIssuePressed != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: onIssuePressed,
                icon: const Icon(Icons.password),
                label: const Text(
                  'Выдать заказ',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF489F2A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FulfillmentBadge extends StatelessWidget {
  const _FulfillmentBadge({required this.isPickup});

  final bool isPickup;

  @override
  Widget build(BuildContext context) {
    final label = isPickup ? 'Самовывоз' : 'Доставка';
    final icon = isPickup ? Icons.storefront : Icons.delivery_dining;

    final color = isPickup
        ? const Color(0xFFB0BEC5) // серый для самовывоза
        : const Color(0xFF66D7FF); // синий для доставки

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131E2D),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  const _OrderItemTile({required this.item});

  final RestaurantOrderDetailsItem item;

  @override
  Widget build(BuildContext context) {
    final total = item.price * item.quantity;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2738),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${item.quantity} × ${item.price} ₸',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$total ₸',
            style: const TextStyle(
              color: Color(0xFF70D74D),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsErrorState extends StatelessWidget {
  const _DetailsErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFFF8A8A), size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
    required this.isPickup,
    required this.isIssuedPickup,
  });

  final String status;
  final bool isPickup;
  final bool isIssuedPickup;

  @override
  Widget build(BuildContext context) {
    final meta = _OrderStatusMeta.fromStatus(
      status,
      isPickup: isPickup,
      isIssuedPickup: isIssuedPickup,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
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
        icon: Icons.verified,
        textColor: Color(0xFF7CFF9E),
        backgroundColor: Color(0x1A7CFF9E),
        borderColor: Color(0x337CFF9E),
      );
    }

    switch (normalizedStatus) {
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
        return _OrderStatusMeta(
          label: isPickup ? 'Готов к выдаче' : 'Готов',
          icon: Icons.done_all,
          textColor: const Color(0xFFB46CFF),
          backgroundColor: const Color(0x1AB46CFF),
          borderColor: const Color(0x33B46CFF),
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
        return _OrderStatusMeta(
          label: isPickup ? 'Выдан' : 'Доставлен',
          icon: Icons.verified,
          textColor: const Color(0xFF7CFF9E),
          backgroundColor: const Color(0x1A7CFF9E),
          borderColor: const Color(0x337CFF9E),
        );
      case 'CANCELED':
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
          icon: Icons.help_outline,
          textColor: Color(0xFFB0BEC5),
          backgroundColor: Color(0x1AB0BEC5),
          borderColor: Color(0x33B0BEC5),
        );
    }
  }
}
