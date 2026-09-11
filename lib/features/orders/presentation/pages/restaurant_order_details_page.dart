import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jetkiz_restaurant/core/localization/app_locale_controller.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/orders/data/restaurant_orders_api.dart';
import 'package:jetkiz_restaurant/features/orders/domain/restaurant_order_details.dart';

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
  late final ApiClient _apiClient;
  late final RestaurantOrdersApi _ordersApi;

  Future<RestaurantOrderDetails>? _orderFuture;
  bool _isVerifyingPickup = false;

  String _t(String ru, String kk) => context.tr(ru, kk);

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _ordersApi = RestaurantOrdersApi(apiClient: _apiClient);
    _loadOrder();
  }

  void _loadOrder() {
    final future = _getOrderDetails();
    setState(() {
      _orderFuture = future;
    });
  }

  Future<void> _refresh() async {
    _loadOrder();
    await _orderFuture;
  }

  Future<RestaurantOrderDetails> _getOrderDetails() async {
    final response = await _apiClient.get('/orders/${widget.orderId}');
    if (response is Map<String, dynamic>) {
      return RestaurantOrderDetails.fromJson(response);
    }
    if (response is Map) {
      return RestaurantOrderDetails.fromJson(Map<String, dynamic>.from(response));
    }
    throw const _OrderDetailsLoadException();
  }

  Future<void> _showPickupCodeSheet(RestaurantOrderDetails order) async {
    final result = await showModalBottomSheet<_PickupIssueResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickupCodeBottomSheet(
        onSubmit: (pickupCode) async {
          if (_isVerifyingPickup) return _PickupIssueResult.none;
          if (mounted) {
            setState(() => _isVerifyingPickup = true);
          } else {
            _isVerifyingPickup = true;
          }

          try {
            await _ordersApi.verifyPickup(id: order.id, pickupCode: pickupCode);
            return _PickupIssueResult.issued;
          } catch (error) {
            if (_isAlreadyIssuedPickupError(error)) {
              return _PickupIssueResult.alreadyIssued;
            }
            rethrow;
          } finally {
            if (mounted) {
              setState(() => _isVerifyingPickup = false);
            } else {
              _isVerifyingPickup = false;
            }
          }
        },
      ),
    );

    if (!mounted || result == null || result == _PickupIssueResult.none) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == _PickupIssueResult.alreadyIssued
              ? _t('Заказ уже выдан', 'Тапсырыс бұрын берілген')
              : _t('Заказ выдан', 'Тапсырыс берілді'),
        ),
        backgroundColor: const Color(0xFF489F2A),
      ),
    );
    _loadOrder();
  }

  String _rawError(Object error) =>
      error.toString().replaceFirst('Exception: ', '').trim();

  String _safeError(Object error) {
    final raw = _rawError(error);
    final lower = raw.toLowerCase();
    if (error is _OrderDetailsLoadException ||
        raw.isEmpty ||
        raw.length > 180 ||
        lower.contains('dioexception') ||
        lower.contains('socketexception') ||
        lower.contains('exception') ||
        lower.contains('backend') ||
        lower.contains('endpoint') ||
        lower.contains('status code') ||
        lower.contains('http 4') ||
        lower.contains('http 5') ||
        lower.contains('current status')) {
      return _t(
        'Не удалось загрузить заказ. Проверьте интернет и повторите.',
        'Тапсырысты жүктеу мүмкін болмады. Интернетті тексеріп, қайталаңыз.',
      );
    }
    return raw;
  }

  bool _isAlreadyIssuedPickupError(Object error) {
    final message = _rawError(error).toLowerCase();
    return message.contains('current status: delivered') ||
        message.contains('already delivered') ||
        message.contains('already verified') ||
        message.contains('уже выдан') ||
        message.contains('уже доставлен');
  }

  String _customerName(RestaurantOrderDetails order) {
    final user = order.user;
    if (user != null) {
      final full = <String>[
        user.firstName?.trim() ?? '',
        user.lastName?.trim() ?? '',
      ].where((value) => value.isNotEmpty).join(' ');
      if (full.isNotEmpty) return full;
    }
    return _t('Клиент', 'Клиент');
  }

  String _customerPhone(RestaurantOrderDetails order) {
    final direct = order.phone?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final nested = order.user?.phone?.trim() ?? '';
    if (nested.isNotEmpty) return nested;
    return _t('Не указан', 'Көрсетілмеген');
  }

  String _courierName(RestaurantOrderDetailsCourier courier) {
    final full = <String>[
      courier.firstName?.trim() ?? '',
      courier.lastName?.trim() ?? '',
    ].where((value) => value.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    return _t('Курьер', 'Курьер');
  }

  String _paymentStatus(String? value) {
    switch ((value ?? '').trim().toUpperCase()) {
      case 'PAID':
        return _t('Оплачено', 'Төленді');
      case 'PENDING':
        return _t('Ожидает оплаты', 'Төлем күтілуде');
      case 'FAILED':
        return _t('Оплата не прошла', 'Төлем орындалмады');
      case 'REFUNDED':
        return _t('Возвращено', 'Қайтарылды');
      case 'CANCELED':
      case 'CANCELLED':
        return _t('Отменено', 'Бас тартылды');
      default:
        return _t('Не указан', 'Көрсетілмеген');
    }
  }

  String _paymentMethod(String? value) {
    switch ((value ?? '').trim().toUpperCase()) {
      case 'CASH':
        return _t('Наличными', 'Қолма-қол');
      case 'CARD':
      case 'ONLINE':
      case 'PAYLINK':
        return _t('Онлайн', 'Онлайн');
      case 'KASPI':
      case 'KASPI_PAY':
        return 'Kaspi';
      default:
        return _t('Не указана', 'Көрсетілмеген');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09111C),
        elevation: 0,
        centerTitle: true,
        title: Text(
          _t('Детали заказа', 'Тапсырыс мәліметтері'),
          style: const TextStyle(
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
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _DetailsErrorState(
                message: _safeError(snapshot.error!),
                onRetry: _loadOrder,
              );
            }

            final order = snapshot.data;
            if (order == null) {
              return _DetailsErrorState(
                message: _t('Заказ не найден', 'Тапсырыс табылмады'),
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
                                    ? '${_t('Заказ', 'Тапсырыс')} #${order.number}'
                                    : _t('Заказ', 'Тапсырыс'),
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
                        _InfoRow(
                          label: _t('Статус оплаты', 'Төлем мәртебесі'),
                          value: _paymentStatus(order.paymentStatus),
                        ),
                        _InfoRow(
                          label: _t('Оплата', 'Төлем'),
                          value: _paymentMethod(order.paymentMethod),
                        ),
                        _InfoRow(
                          label: _t('Подытог', 'Аралық сома'),
                          value: '${order.subtotal} ₸',
                        ),
                        _InfoRow(
                          label: _t('Доставка', 'Жеткізу'),
                          value: order.isPickup
                              ? _t('Самовывоз', 'Өзі алып кету')
                              : '${order.deliveryFee} ₸',
                        ),
                        _InfoRow(
                          label: _t('Итого', 'Барлығы'),
                          value: '${order.total} ₸',
                        ),
                        if (order.createdAt != null)
                          _InfoRow(
                            label: _t('Создан', 'Құрылды'),
                            value: _formatDateTime(order.createdAt!.toLocal()),
                          ),
                        if (order.readyAt != null)
                          _InfoRow(
                            label: order.isPickup
                                ? _t('Готов к выдаче', 'Беруге дайын')
                                : _t('Готов', 'Дайын'),
                            value: _formatDateTime(order.readyAt!.toLocal()),
                          ),
                        if (order.promisedAt != null)
                          _InfoRow(
                            label: _t('Обещано к', 'Дайын болу уақыты'),
                            value: _formatDateTime(order.promisedAt!.toLocal()),
                          ),
                        if (order.pickupCodeVerifiedAt != null)
                          _InfoRow(
                            label: _t('Выдан', 'Берілді'),
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
                        _SectionTitle(_t('Клиент', 'Клиент')),
                        const SizedBox(height: 12),
                        _InfoRow(
                          label: _t('Имя', 'Аты'),
                          value: _customerName(order),
                        ),
                        _InfoRow(
                          label: _t('Телефон', 'Телефон'),
                          value: _customerPhone(order),
                        ),
                        if (order.isPickup)
                          _InfoRow(
                            label: _t('Получение', 'Алу'),
                            value: _t(
                              'Клиент заберёт сам',
                              'Клиент өзі алып кетеді',
                            ),
                          )
                        else ...[
                          _InfoRow(
                            label: _t('Оставить у двери', 'Есік алдына қалдыру'),
                            value: order.leaveAtDoor
                                ? _t('Да', 'Иә')
                                : _t('Нет', 'Жоқ'),
                          ),
                          if ((order.address ?? '').trim().isNotEmpty)
                            _InfoRow(
                              label: _t('Адрес', 'Мекенжай'),
                              value: order.address!.trim(),
                            ),
                        ],
                        if ((order.comment ?? '').trim().isNotEmpty)
                          _InfoRow(
                            label: _t('Комментарий', 'Пікір'),
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
                  if (order.isDelivery && order.courier != null) ...[
                    const SizedBox(height: 14),
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(_t('Курьер', 'Курьер')),
                          const SizedBox(height: 12),
                          _InfoRow(
                            label: _t('Имя', 'Аты'),
                            value: _courierName(order.courier!),
                          ),
                          _InfoRow(
                            label: _t('Телефон', 'Телефон'),
                            value: (order.courier!.phone ?? '').trim().isNotEmpty
                                ? order.courier!.phone!.trim()
                                : _t('Не указан', 'Көрсетілмеген'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(_t('Состав заказа', 'Тапсырыс құрамы')),
                        const SizedBox(height: 12),
                        if (order.items.isEmpty)
                          Text(
                            _t('Позиции отсутствуют', 'Тауарлар жоқ'),
                            style: const TextStyle(color: Colors.white70),
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

class _OrderDetailsLoadException implements Exception {
  const _OrderDetailsLoadException();
}

enum _PickupIssueResult { none, issued, alreadyIssued }

class _PickupCodeBottomSheet extends StatefulWidget {
  const _PickupCodeBottomSheet({required this.onSubmit});

  final Future<_PickupIssueResult> Function(String pickupCode) onSubmit;

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

  String _safeIssueError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    if (raw.isEmpty ||
        raw.length > 160 ||
        lower.contains('dioexception') ||
        lower.contains('socketexception') ||
        lower.contains('exception') ||
        lower.contains('backend') ||
        lower.contains('endpoint') ||
        lower.contains('status code') ||
        lower.contains('http') ||
        lower.contains('current status')) {
      return context.tr(
        'Не удалось подтвердить выдачу. Проверьте код и попробуйте снова.',
        'Беруді растау мүмкін болмады. Кодты тексеріп, қайта көріңіз.',
      );
    }
    return raw;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final pickupCode = _controller.text.trim();
    if (pickupCode.isEmpty) {
      setState(() => _errorText = context.tr('Введите код клиента', 'Клиент кодын енгізіңіз'));
      return;
    }
    if (pickupCode.length != 4) {
      setState(() {
        _errorText = context.tr(
          'Код должен состоять из 4 цифр',
          'Код 4 цифрдан тұруы керек',
        );
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
      setState(() => _isSubmitting = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = _safeIssueError(error);
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
              Text(
                context.tr('Подтвердить выдачу', 'Беруді растау'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'Введите 4-значный код, который клиент показывает при получении заказа.',
                  'Клиент тапсырысты алған кезде көрсететін 4 таңбалы кодты енгізіңіз.',
                ),
                style: const TextStyle(
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
                      : Text(
                          context.tr('Подтвердить', 'Растау'),
                          style: const TextStyle(
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
  const _PickupIssueCard({
    required this.order,
    required this.onIssuePressed,
  });

  final RestaurantOrderDetails order;
  final VoidCallback? onIssuePressed;

  @override
  Widget build(BuildContext context) {
    final title = order.isIssuedPickup
        ? context.tr('Заказ выдан', 'Тапсырыс берілді')
        : order.isReadyForPickupIssue
            ? context.tr('Готов к выдаче', 'Беруге дайын')
            : context.tr('Самовывоз', 'Өзі алып кету');
    final description = order.isIssuedPickup
        ? context.tr(
            'Код клиента подтверждён. Заказ закрыт как выданный.',
            'Клиент коды расталды. Тапсырыс берілген ретінде жабылды.',
          )
        : order.isReadyForPickupIssue
            ? context.tr(
                'Попросите клиента назвать или показать код получения.',
                'Клиенттен алу кодын айтуын немесе көрсетуін сұраңыз.',
              )
            : context.tr(
                'Клиент заберёт заказ сам. Курьер для этого заказа не нужен.',
                'Клиент тапсырысты өзі алып кетеді. Бұл тапсырысқа курьер қажет емес.',
              );

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.storefront,
                color: Color(0xFF70D74D),
                size: 22,
              ),
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
                label: Text(
                  context.tr('Выдать заказ', 'Тапсырысты беру'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
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
    final label = isPickup
        ? context.tr('Самовывоз', 'Өзі алып кету')
        : context.tr('Доставка', 'Жеткізу');
    final icon = isPickup ? Icons.storefront : Icons.delivery_dining;
    final color = isPickup
        ? const Color(0xFFB0BEC5)
        : const Color(0xFF66D7FF);

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
            width: 118,
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
            const Icon(
              Icons.error_outline,
              color: Color(0xFFFF8A8A),
              size: 40,
            ),
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
              child: Text(context.tr('Повторить', 'Қайталау')),
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
      context,
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
    BuildContext context,
    String status, {
    required bool isPickup,
    required bool isIssuedPickup,
  }) {
    if (isPickup && isIssuedPickup) {
      return _OrderStatusMeta(
        label: context.tr('Выдан', 'Берілді'),
        icon: Icons.verified,
        textColor: const Color(0xFF7CFF9E),
        backgroundColor: const Color(0x1A7CFF9E),
        borderColor: const Color(0x337CFF9E),
      );
    }

    switch (status.trim().toUpperCase()) {
      case 'CREATED':
        return _OrderStatusMeta(
          label: context.tr('Новый', 'Жаңа'),
          icon: Icons.fiber_new,
          textColor: const Color(0xFF66D7FF),
          backgroundColor: const Color(0x1A66D7FF),
          borderColor: const Color(0x3366D7FF),
        );
      case 'ACCEPTED':
        return _OrderStatusMeta(
          label: context.tr('Принят', 'Қабылданды'),
          icon: Icons.check_circle_outline,
          textColor: const Color(0xFF00E676),
          backgroundColor: const Color(0x1A00E676),
          borderColor: const Color(0x3300E676),
        );
      case 'COOKING':
        return _OrderStatusMeta(
          label: context.tr('Готовится', 'Дайындалуда'),
          icon: Icons.local_fire_department_outlined,
          textColor: const Color(0xFFFFC857),
          backgroundColor: const Color(0x1AFFC857),
          borderColor: const Color(0x33FFC857),
        );
      case 'READY':
        return _OrderStatusMeta(
          label: isPickup
              ? context.tr('Готов к выдаче', 'Беруге дайын')
              : context.tr('Готов', 'Дайын'),
          icon: Icons.done_all,
          textColor: const Color(0xFFB46CFF),
          backgroundColor: const Color(0x1AB46CFF),
          borderColor: const Color(0x33B46CFF),
        );
      case 'ON_THE_WAY':
        return _OrderStatusMeta(
          label: context.tr('В пути', 'Жолда'),
          icon: Icons.delivery_dining,
          textColor: const Color(0xFFFF9E57),
          backgroundColor: const Color(0x1AFF9E57),
          borderColor: const Color(0x33FF9E57),
        );
      case 'DELIVERED':
        return _OrderStatusMeta(
          label: isPickup
              ? context.tr('Выдан', 'Берілді')
              : context.tr('Доставлен', 'Жеткізілді'),
          icon: Icons.verified,
          textColor: const Color(0xFF7CFF9E),
          backgroundColor: const Color(0x1A7CFF9E),
          borderColor: const Color(0x337CFF9E),
        );
      case 'REJECTED':
        return _OrderStatusMeta(
          label: context.tr('Отклонён', 'Қабылданбады'),
          icon: Icons.cancel_outlined,
          textColor: const Color(0xFFFF7C7C),
          backgroundColor: const Color(0x1AFF7C7C),
          borderColor: const Color(0x33FF7C7C),
        );
      case 'CANCELED':
      case 'CANCELLED':
        return _OrderStatusMeta(
          label: context.tr('Отменён', 'Бас тартылды'),
          icon: Icons.cancel_outlined,
          textColor: const Color(0xFFFF7C7C),
          backgroundColor: const Color(0x1AFF7C7C),
          borderColor: const Color(0x33FF7C7C),
        );
      default:
        return _OrderStatusMeta(
          label: context.tr('Неизвестно', 'Белгісіз'),
          icon: Icons.help_outline,
          textColor: const Color(0xFFB0BEC5),
          backgroundColor: const Color(0x1AB0BEC5),
          borderColor: const Color(0x33B0BEC5),
        );
    }
  }
}
