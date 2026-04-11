import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/orders/domain/restaurant_order_details.dart';

// JETKIZ RESTAURANT APP
// Restaurant order details page.
//
// BACKEND:
// - GET /orders/:id
//
// IMPORTANT:
// This screen is intentionally kept read-only now.
// User request was only:
// "нажимая на заказ открыть подробнее"
// So no extra status-change logic is added here.

class RestaurantOrderDetailsPage extends StatefulWidget {
  const RestaurantOrderDetailsPage({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  State<RestaurantOrderDetailsPage> createState() =>
      _RestaurantOrderDetailsPageState();
}

class _RestaurantOrderDetailsPageState extends State<RestaurantOrderDetailsPage> {
  final ApiClient _apiClient = ApiClient();
  Future<RestaurantOrderDetails>? _orderFuture;

  @override
  void initState() {
    super.initState();
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
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<RestaurantOrderDetails>(
          future: _orderFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return _DetailsErrorState(
                message: snapshot.error.toString().replaceFirst('Exception: ', ''),
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
                            _StatusBadge(status: order.status),
                          ],
                        ),
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
                          value: '${order.deliveryFee} ₸',
                        ),
                        _InfoRow(
                          label: 'Итого',
                          value: '${order.total} ₸',
                        ),
                        if (order.createdAt != null)
                          _InfoRow(
                            label: 'Создан',
                            value: _formatDateTime(order.createdAt!.toLocal()),
                          ),
                        if (order.promisedAt != null)
                          _InfoRow(
                            label: 'Обещано к',
                            value: _formatDateTime(order.promisedAt!.toLocal()),
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
                        _InfoRow(
                          label: 'Оставить у двери',
                          value: order.leaveAtDoor ? 'Да' : 'Нет',
                        ),
                        if ((order.comment ?? '').trim().isNotEmpty)
                          _InfoRow(
                            label: 'Комментарий',
                            value: order.comment!.trim(),
                          ),
                        if ((order.address ?? '').trim().isNotEmpty)
                          _InfoRow(
                            label: 'Адрес',
                            value: order.address!.trim(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (order.courier != null) ...[
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
                            value: (order.courier!.phone ?? '').trim().isNotEmpty
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
  });

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
  const _OrderItemTile({
    required this.item,
  });

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
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
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
  const _InfoRow({
    required this.label,
    required this.value,
  });

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
  const _DetailsErrorState({
    required this.message,
    required this.onRetry,
  });

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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final meta = _OrderStatusMeta.fromStatus(status);

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