import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../data/api/restaurant_finance_api.dart';
import '../../data/models/restaurant_finance_models.dart';

enum FinancePeriod { today, yesterday, week, month, custom }

class RestaurantFinancePage extends StatefulWidget {
  const RestaurantFinancePage({super.key});

  @override
  State<RestaurantFinancePage> createState() => _RestaurantFinancePageState();
}

class _RestaurantFinancePageState extends State<RestaurantFinancePage> {
  late final RestaurantFinanceApi _api;

  FinancePeriod _period = FinancePeriod.today;
  bool _showDatePicker = false;
  bool _showAllPayouts = false;
  bool _showAllOrders = false;
  String _customStartDate = '';
  String _customEndDate = '';
  String? _expandedOrderId;

  bool _loading = true;
  String? _error;
  RestaurantFinanceResponse? _data;

  final NumberFormat _moneyFormat = NumberFormat('#,##0', 'ru_RU');
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');
  final DateFormat _dateTimeFormat = DateFormat('dd.MM.yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _api = RestaurantFinanceApi(ApiClient());
    _loadFinance();
  }

  Future<void> _loadFinance() async {
    if (_period == FinancePeriod.custom &&
        (_customStartDate.trim().isEmpty || _customEndDate.trim().isEmpty)) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result = await _api.getFinance(
        period: _periodToApiValue(_period),
        startDate: _period == FinancePeriod.custom ? _customStartDate : null,
        endDate: _period == FinancePeriod.custom ? _customEndDate : null,
      );
      if (!mounted) return;
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _safeFinanceError(error);
        _loading = false;
      });
    }
  }

  String _safeFinanceError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    if (raw.isEmpty ||
        raw.length > 180 ||
        lower.contains('dioexception') ||
        lower.contains('socketexception') ||
        lower.contains('exception') ||
        lower.contains('backend') ||
        lower.contains('endpoint') ||
        lower.contains('status code') ||
        lower.contains('http 4') ||
        lower.contains('http 5') ||
        lower.contains('argumenterror')) {
      return 'Не удалось загрузить финансы. Проверьте интернет и повторите.';
    }
    return raw;
  }

  String _periodToApiValue(FinancePeriod period) {
    switch (period) {
      case FinancePeriod.today:
        return 'today';
      case FinancePeriod.yesterday:
        return 'yesterday';
      case FinancePeriod.week:
        return 'week';
      case FinancePeriod.month:
        return 'month';
      case FinancePeriod.custom:
        return 'custom';
    }
  }

  String _periodLabel() {
    switch (_period) {
      case FinancePeriod.today:
        return 'Сегодня';
      case FinancePeriod.yesterday:
        return 'Вчера';
      case FinancePeriod.week:
        return '7 дней';
      case FinancePeriod.month:
        return '30 дней';
      case FinancePeriod.custom:
        return 'Период';
    }
  }

  void _changePeriod(FinancePeriod period) {
    if (_period == period) return;
    setState(() {
      _period = period;
      _showDatePicker = period == FinancePeriod.custom;
      _showAllPayouts = false;
      _showAllOrders = false;
      _expandedOrderId = null;
    });
    if (period != FinancePeriod.custom) {
      _loadFinance();
    }
  }

  void _applyCustomPeriod() {
    final start = DateTime.tryParse(_customStartDate.trim());
    final end = DateTime.tryParse(_customEndDate.trim());
    if (start == null || end == null) {
      _showMessage('Укажите даты в формате ГГГГ-ММ-ДД.');
      return;
    }
    if (start.isAfter(end)) {
      _showMessage('Дата начала не может быть позже даты окончания.');
      return;
    }
    setState(() {
      _showDatePicker = false;
      _showAllPayouts = false;
      _showAllOrders = false;
      _expandedOrderId = null;
    });
    _loadFinance();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _money(num value) {
    return '${_moneyFormat.format(value).replaceAll(',', ' ')} ₸';
  }

  String _date(DateTime? value) {
    if (value == null) return '—';
    return _dateFormat.format(value.toLocal());
  }

  String _dateTime(DateTime? value) {
    if (value == null) return '—';
    return _dateTimeFormat.format(value.toLocal());
  }

  String _periodRange(DateTime? start, DateTime? end) {
    return '${_date(start)} — ${_date(end)}';
  }

  String _payoutStatus(String status) {
    switch (status.trim().toUpperCase()) {
      case 'PAID':
        return 'Оплачено';
      case 'PENDING':
        return 'Ожидает';
      case 'CANCELED':
      case 'CANCELLED':
        return 'Отменено';
      default:
        return 'Неизвестно';
    }
  }

  Color _payoutStatusColor(String status) {
    switch (status.trim().toUpperCase()) {
      case 'PAID':
        return const Color(0xFF22C55E);
      case 'PENDING':
        return const Color(0xFFF59E0B);
      case 'CANCELED':
      case 'CANCELLED':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  String _clientName(RestaurantFinanceOrder order) {
    final first = (order.user?.firstName ?? '').trim();
    final last = (order.user?.lastName ?? '').trim();
    final full = '$first $last'.trim();
    return full.isEmpty ? 'Клиент' : full;
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: SafeArea(
        child: Column(
          children: [
            _FinanceHeader(
              period: _period,
              periodLabel: _periodLabel(),
              onChanged: _changePeriod,
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF489F2A),
                      ),
                    )
                  : _error != null
                      ? _FinanceMessageState(
                          icon: Icons.error_outline_rounded,
                          title: _error!,
                          actionLabel: 'Повторить',
                          onAction: _loadFinance,
                        )
                      : data == null
                          ? _FinanceMessageState(
                              icon: Icons.account_balance_wallet_outlined,
                              title: 'Финансовых данных пока нет',
                              actionLabel: 'Обновить',
                              onAction: _loadFinance,
                            )
                          : RefreshIndicator(
                              color: const Color(0xFF489F2A),
                              onRefresh: _loadFinance,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                                children: [
                                  if (_showDatePicker) ...[
                                    _CustomPeriodCard(
                                      startDate: _customStartDate,
                                      endDate: _customEndDate,
                                      onStartChanged: (value) => setState(
                                        () => _customStartDate = value,
                                      ),
                                      onEndChanged: (value) => setState(
                                        () => _customEndDate = value,
                                      ),
                                      onApply: _applyCustomPeriod,
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  _PrimaryAmountCard(
                                    amount: _money(data.availableToWithdraw),
                                    periodLabel: _periodLabel(),
                                  ),
                                  const SizedBox(height: 12),
                                  _CommissionCard(
                                    individual:
                                        data.restaurant.hasIndividualCommission,
                                    rate: data.restaurant
                                        .restaurantCommissionPctOverride,
                                    amount: _money(data.commissionAmount),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _MetricCard(
                                          label: 'Выплачено',
                                          value: _money(data.paidAmount),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _MetricCard(
                                          label: 'Назначено',
                                          value: _money(
                                            data.assignedButUnpaidAmount,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _MetricCard(
                                          label: 'Доставлено',
                                          value:
                                              '${data.summary.deliveredOrdersCount}',
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _MetricCard(
                                          label: 'Сумма блюд',
                                          value: _money(data.summary.grossTotal),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _MetricCard(
                                          label: 'Среднее начисление',
                                          value: _money(
                                            data.summary.averagePayoutPerOrder,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _MetricCard(
                                          label: 'Средняя сумма блюд',
                                          value: _money(
                                            data.summary.averageGrossOrderValue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _SectionHeader(
                                    title: 'История выплат',
                                    count: data.payouts.rows.length,
                                  ),
                                  const SizedBox(height: 10),
                                  _PayoutList(
                                    rows: data.payouts.rows,
                                    showAll: _showAllPayouts,
                                    money: _money,
                                    dateTime: _dateTime,
                                    period: _periodRange,
                                    status: _payoutStatus,
                                    statusColor: _payoutStatusColor,
                                    onToggleAll: data.payouts.rows.length > 3
                                        ? () => setState(
                                              () => _showAllPayouts =
                                                  !_showAllPayouts,
                                            )
                                        : null,
                                  ),
                                  const SizedBox(height: 20),
                                  _SectionHeader(
                                    title: 'Последние доставленные заказы',
                                    count: data.recentDeliveredOrders.length,
                                  ),
                                  const SizedBox(height: 10),
                                  _RecentOrdersList(
                                    orders: data.recentDeliveredOrders,
                                    showAll: _showAllOrders,
                                    expandedOrderId: _expandedOrderId,
                                    money: _money,
                                    dateTime: _dateTime,
                                    clientName: _clientName,
                                    onToggleOrder: (id) => setState(() {
                                      _expandedOrderId =
                                          _expandedOrderId == id ? null : id;
                                    }),
                                    onToggleAll:
                                        data.recentDeliveredOrders.length > 3
                                            ? () => setState(
                                                  () => _showAllOrders =
                                                      !_showAllOrders,
                                                )
                                            : null,
                                  ),
                                  const SizedBox(height: 20),
                                  _PeriodSummaryCard(
                                    periodLabel: _periodLabel(),
                                    delivered:
                                        data.summary.deliveredOrdersCount,
                                    gross: _money(data.summary.grossTotal),
                                    commission:
                                        _money(data.summary.commissionAmount),
                                    payout: _money(data.summary.payoutAmount),
                                    available: _money(data.availableToWithdraw),
                                    paid: _money(data.paidAmount),
                                  ),
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceHeader extends StatelessWidget {
  const _FinanceHeader({
    required this.period,
    required this.periodLabel,
    required this.onChanged,
  });

  final FinancePeriod period;
  final String periodLabel;
  final ValueChanged<FinancePeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = <(FinancePeriod, String)>[
      (FinancePeriod.today, 'Сегодня'),
      (FinancePeriod.yesterday, 'Вчера'),
      (FinancePeriod.week, '7 дней'),
      (FinancePeriod.month, '30 дней'),
      (FinancePeriod.custom, 'Период'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF489F2A), Color(0xFF3A7E21)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'jetkiz',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Финансы',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                periodLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: items.map((item) {
                final selected = item.$1 == period;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selected,
                    showCheckmark: false,
                    label: Text(item.$2),
                    onSelected: (_) => onChanged(item.$1),
                    selectedColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      color: selected
                          ? const Color(0xFF14532D)
                          : Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomPeriodCard extends StatelessWidget {
  const _CustomPeriodCard({
    required this.startDate,
    required this.endDate,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onApply,
  });

  final String startDate;
  final String endDate;
  final ValueChanged<String> onStartChanged;
  final ValueChanged<String> onEndChanged;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Свой период',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'С даты',
                  initialValue: startDate,
                  onChanged: onStartChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                  label: 'По дату',
                  initialValue: endDate,
                  onChanged: onEndChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onApply,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF489F2A),
              ),
              child: const Text('Применить'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      keyboardType: TextInputType.datetime,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: '2026-09-10',
        labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        hintStyle: const TextStyle(color: Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFF030712),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
      ),
    );
  }
}

class _PrimaryAmountCard extends StatelessWidget {
  const _PrimaryAmountCard({required this.amount, required this.periodLabel});

  final String amount;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'К выплате',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          ),
          const SizedBox(height: 7),
          Text(
            amount,
            style: const TextStyle(
              color: Color(0xFF86EFAC),
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'За период: ${periodLabel.toLowerCase()}',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CommissionCard extends StatelessWidget {
  const _CommissionCard({
    required this.individual,
    required this.rate,
    required this.amount,
  });

  final bool individual;
  final int? rate;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final rateText = rate == null ? 'по умолчанию' : '$rate%';
    return _Card(
      child: Row(
        children: [
          const Icon(Icons.percent_rounded, color: Color(0xFFF59E0B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Комиссия сервиса',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${individual ? 'Индивидуальная комиссия' : 'Общая комиссия'} · $rateText',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              color: Color(0xFFFBBF24),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 11,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF263244)),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _PayoutList extends StatelessWidget {
  const _PayoutList({
    required this.rows,
    required this.showAll,
    required this.money,
    required this.dateTime,
    required this.period,
    required this.status,
    required this.statusColor,
    required this.onToggleAll,
  });

  final List<RestaurantFinancePayoutRow> rows;
  final bool showAll;
  final String Function(num value) money;
  final String Function(DateTime? value) dateTime;
  final String Function(DateTime? start, DateTime? end) period;
  final String Function(String status) status;
  final Color Function(String status) statusColor;
  final VoidCallback? onToggleAll;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyCard(
        title: 'Выплат пока нет',
        subtitle: 'Сформированные выплаты появятся здесь.',
      );
    }
    final visible = showAll ? rows : rows.take(3).toList();
    return Column(
      children: [
        ...visible.map((row) {
          final chip = statusColor(row.status);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          money(row.payoutAmount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: chip.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          status(row.status),
                          style: TextStyle(
                            color: chip,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Период: ${period(row.periodFrom, row.periodTo)}',
                    style: const TextStyle(color: Color(0xFFCBD5E1)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Заказов: ${row.ordersCount} · Сумма блюд: ${money(row.grossSubtotal)}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Комиссия: ${money(row.commissionAmount)}',
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 12,
                    ),
                  ),
                  if ((row.paymentReference ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      'Референс: ${row.paymentReference}',
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if ((row.paymentComment ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Комментарий оплаты: ${row.paymentComment}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if ((row.note ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Заметка: ${row.note}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Text(
                    row.paidAt == null
                        ? 'Создано: ${dateTime(row.createdAt)}'
                        : 'Оплачено: ${dateTime(row.paidAt)}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (onToggleAll != null)
          _ShowAllButton(
            expanded: showAll,
            total: rows.length,
            onPressed: onToggleAll!,
          ),
      ],
    );
  }
}

class _RecentOrdersList extends StatelessWidget {
  const _RecentOrdersList({
    required this.orders,
    required this.showAll,
    required this.expandedOrderId,
    required this.money,
    required this.dateTime,
    required this.clientName,
    required this.onToggleOrder,
    required this.onToggleAll,
  });

  final List<RestaurantFinanceOrder> orders;
  final bool showAll;
  final String? expandedOrderId;
  final String Function(num value) money;
  final String Function(DateTime? value) dateTime;
  final String Function(RestaurantFinanceOrder order) clientName;
  final ValueChanged<String> onToggleOrder;
  final VoidCallback? onToggleAll;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const _EmptyCard(
        title: 'Нет доставленных заказов',
        subtitle: 'За выбранный период доставленных заказов пока нет.',
      );
    }
    final visible = showAll ? orders : orders.take(3).toList();
    return Column(
      children: [
        ...visible.map((order) {
          final expanded = expandedOrderId == order.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Card(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => onToggleOrder(order.id),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Заказ #${order.number}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  clientName(order),
                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Доставлен: ${dateTime(order.deliveredAt)}',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                money(order.restaurantPayoutAmount),
                                style: const TextStyle(
                                  color: Color(0xFF86EFAC),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                order.isAssignedToPayout
                                    ? 'В выплате'
                                    : 'Ожидает выплаты',
                                style: TextStyle(
                                  color: order.isAssignedToPayout
                                      ? const Color(0xFFFDE68A)
                                      : const Color(0xFF93C5FD),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            expanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: const Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (expanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        children: [
                          const Divider(color: Color(0xFF263244)),
                          _DetailRow(
                            label: 'Сумма блюд',
                            value: money(order.subtotal),
                          ),
                          _DetailRow(
                            label: 'Скидка на блюда',
                            value: money(order.discountAmount),
                          ),
                          _DetailRow(
                            label: 'Комиссия сервиса',
                            value: money(order.restaurantCommissionAmount),
                          ),
                          _DetailRow(
                            label: 'Ставка комиссии',
                            value:
                                '${order.restaurantCommissionPctApplied.toStringAsFixed(0)}%',
                          ),
                          _DetailRow(
                            label: 'Начислено ресторану',
                            value: money(order.restaurantPayoutAmount),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Позиции: ${order.itemsCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (order.items.isEmpty)
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Позиции не указаны',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                            )
                          else
                            ...order.items.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: const TextStyle(
                                          color: Color(0xFFCBD5E1),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${item.quantity} × ${money(item.price)}',
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
        if (onToggleAll != null)
          _ShowAllButton(
            expanded: showAll,
            total: orders.length,
            onPressed: onToggleAll!,
          ),
      ],
    );
  }
}

class _ShowAllButton extends StatelessWidget {
  const _ShowAllButton({
    required this.expanded,
    required this.total,
    required this.onPressed,
  });

  final bool expanded;
  final int total;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          expanded
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
        ),
        label: Text(expanded ? 'Свернуть' : 'Показать все ($total)'),
      ),
    );
  }
}

class _PeriodSummaryCard extends StatelessWidget {
  const _PeriodSummaryCard({
    required this.periodLabel,
    required this.delivered,
    required this.gross,
    required this.commission,
    required this.payout,
    required this.available,
    required this.paid,
  });

  final String periodLabel;
  final int delivered;
  final String gross;
  final String commission;
  final String payout;
  final String available;
  final String paid;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Итог за $periodLabel',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _DetailRow(label: 'Доставленных заказов', value: '$delivered'),
          _DetailRow(label: 'Сумма блюд', value: gross),
          _DetailRow(label: 'Комиссия сервиса', value: commission),
          _DetailRow(label: 'Начислено ресторану', value: payout),
          _DetailRow(label: 'К выплате', value: available),
          _DetailRow(label: 'Уже выплачено', value: paid),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: child,
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            color: Color(0xFF64748B),
            size: 30,
          ),
          const SizedBox(height: 9),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceMessageState extends StatelessWidget {
  const _FinanceMessageState({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
      children: [
        Icon(icon, color: const Color(0xFF94A3B8), size: 46),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF489F2A),
            ),
            child: Text(actionLabel),
          ),
        ),
      ],
    );
  }
}
