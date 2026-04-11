import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../data/api/restaurant_finance_api.dart';
import '../../data/models/restaurant_finance_models.dart';

enum FinancePeriod {
  today,
  yesterday,
  week,
  month,
  custom,
}

class RestaurantFinancePage extends StatefulWidget {
  const RestaurantFinancePage({super.key});

  @override
  State<RestaurantFinancePage> createState() => _RestaurantFinancePageState();
}

class _RestaurantFinancePageState extends State<RestaurantFinancePage> {
  late final RestaurantFinanceApi _api;

  FinancePeriod _period = FinancePeriod.today;
  bool _showDatePicker = false;
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
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _api.getFinance(
        period: _periodToApiValue(_period),
        startDate: _period == FinancePeriod.custom ? _customStartDate : null,
        endDate: _period == FinancePeriod.custom ? _customEndDate : null,
      );

      debugPrint('FINANCE OK: orders=${result.summary.deliveredOrdersCount}');
      debugPrint('FINANCE payout pending=${result.payouts.pendingPayoutAmount}');
      debugPrint('FINANCE payouts rows=${result.payouts.rows.length}');
      debugPrint(
        'FINANCE recent orders=${result.recentDeliveredOrders.length}',
      );

      if (!mounted) return;

      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('FINANCE LOAD ERROR: $e');
      debugPrint('$st');

      if (!mounted) return;

      setState(() {
        _error = 'Не удалось загрузить финансы: $e';
        _loading = false;
      });
    }
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

  void _handlePeriodChange(FinancePeriod newPeriod) {
    setState(() {
      _period = newPeriod;
      _showDatePicker = newPeriod == FinancePeriod.custom;
    });

    if (newPeriod != FinancePeriod.custom) {
      _loadFinance();
    }
  }

  void _applyCustomDateRange() {
    if (_customStartDate.isEmpty || _customEndDate.isEmpty) return;

    setState(() {
      _showDatePicker = false;
    });

    _loadFinance();
  }

  void _toggleOrderExpand(String orderId) {
    setState(() {
      _expandedOrderId = _expandedOrderId == orderId ? null : orderId;
    });
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

  String _formatMoney(num value) {
    return '${_moneyFormat.format(value).replaceAll(',', ' ')} ₸';
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '—';
    return _dateFormat.format(value.toLocal());
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '—';
    return _dateTimeFormat.format(value.toLocal());
  }

  String _formatPeriodRange(DateTime? start, DateTime? end) {
    return '${_formatDate(start)} — ${_formatDate(end)}';
  }

  String _payoutStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return 'Выплачено';
      case 'PENDING':
        return 'Ожидает';
      case 'CANCELED':
        return 'Отменено';
      default:
        return status;
    }
  }

  Color _payoutStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return const Color(0xFF22C55E);
      case 'PENDING':
        return const Color(0xFFF59E0B);
      case 'CANCELED':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF030712);
    const headerGreen = Color(0xFF489F2A);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF489F2A), Color(0xFF3A7E21)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'jetkiz',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_data != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _periodLabel(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _FinancePeriodTabs(
                    selectedPeriod: _period,
                    onChanged: _handlePeriodChange,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: headerGreen),
                    )
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.white),
                          ),
                        )
                      : RefreshIndicator(
                          color: headerGreen,
                          onRefresh: _loadFinance,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            children: [
                              if (_showDatePicker)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _FinanceCustomPeriodPicker(
                                    startDate: _customStartDate,
                                    endDate: _customEndDate,
                                    onStartChanged: (value) {
                                      setState(() {
                                        _customStartDate = value;
                                      });
                                    },
                                    onEndChanged: (value) {
                                      setState(() {
                                        _customEndDate = value;
                                      });
                                    },
                                    onApply: _applyCustomDateRange,
                                  ),
                                ),
                              _FinanceRevenueCard(
                                title: 'К выводу',
                                amount: _data!.availableToWithdraw,
                                subtitle: 'За ${_periodLabel().toLowerCase()}',
                                money: _formatMoney,
                              ),
                              const SizedBox(height: 12),
                              _FinanceCommissionCard(
                                commissionType:
                                    _data!.restaurant.hasIndividualCommission
                                        ? 'Индивидуальная'
                                        : 'Общая',
                                commissionRate: _data!
                                        .restaurant
                                        .restaurantCommissionPctOverride
                                        ?.toDouble() ??
                                    0,
                                commissionAmount: _data!.commissionAmount,
                                money: _formatMoney,
                              ),
                              const SizedBox(height: 12),
                              _FinanceBalancesCard(
                                data: _data!,
                                money: _formatMoney,
                              ),
                              const SizedBox(height: 12),
                              _FinanceStatsGrid(
                                data: _data!,
                                money: _formatMoney,
                              ),
                              const SizedBox(height: 16),
                              _SectionTitle(
                                title: 'История выплат',
                                trailing: '${_data!.payouts.rows.length}',
                              ),
                              const SizedBox(height: 10),
                              _PayoutHistorySection(
                                rows: _data!.payouts.rows,
                                money: _formatMoney,
                                dateTime: _formatDateTime,
                                period: _formatPeriodRange,
                                statusLabel: _payoutStatusLabel,
                                statusColor: _payoutStatusColor,
                              ),
                              const SizedBox(height: 16),
                              _SectionTitle(
                                title: 'Последние доставленные заказы',
                                trailing:
                                    '${_data!.recentDeliveredOrders.length}',
                              ),
                              const SizedBox(height: 10),
                              _RecentOrdersSection(
                                orders: _data!.recentDeliveredOrders,
                                expandedOrderId: _expandedOrderId,
                                money: _formatMoney,
                                dateTime: _formatDateTime,
                                onToggleExpand: _toggleOrderExpand,
                              ),
                              const SizedBox(height: 16),
                              _FinanceSummarySection(
                                periodLabel: _periodLabel(),
                                data: _data!,
                                money: _formatMoney,
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

class _FinancePeriodTabs extends StatelessWidget {
  const _FinancePeriodTabs({
    required this.selectedPeriod,
    required this.onChanged,
  });

  final FinancePeriod selectedPeriod;
  final ValueChanged<FinancePeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <({FinancePeriod value, String label})>[
      (value: FinancePeriod.today, label: 'Сегодня'),
      (value: FinancePeriod.yesterday, label: 'Вчера'),
      (value: FinancePeriod.week, label: '7 дней'),
      (value: FinancePeriod.month, label: '30 дней'),
      (value: FinancePeriod.custom, label: 'Период'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final selected = selectedPeriod == item.value;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(item.value),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: selected ? const Color(0xFF14532D) : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FinanceCustomPeriodPicker extends StatelessWidget {
  const _FinanceCustomPeriodPicker({
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'От',
                  value: startDate,
                  onChanged: onStartChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                  label: 'До',
                  value: endDate,
                  onChanged: onEndChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF489F2A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Применить',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatefulWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _DateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: '2026-04-06',
        hintStyle: const TextStyle(color: Color(0xFF6B7280)),
        labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFF030712),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1F2937)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1F2937)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF489F2A)),
        ),
      ),
    );
  }
}

class _FinanceRevenueCard extends StatelessWidget {
  const _FinanceRevenueCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.money,
  });

  final String title;
  final double amount;
  final String subtitle;
  final String Function(num value) money;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF489F2A).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Color(0xFF86EFAC),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  money(amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
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

class _FinanceCommissionCard extends StatelessWidget {
  const _FinanceCommissionCard({
    required this.commissionType,
    required this.commissionRate,
    required this.commissionAmount,
    required this.money,
  });

  final String commissionType;
  final double commissionRate;
  final double commissionAmount;
  final String Function(num value) money;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.percent_rounded,
            color: Color(0xFFF59E0B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Комиссия ресторана',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$commissionType · ${commissionRate.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            money(commissionAmount),
            style: const TextStyle(
              color: Color(0xFFFBBF24),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceBalancesCard extends StatelessWidget {
  const _FinanceBalancesCard({
    required this.data,
    required this.money,
  });

  final RestaurantFinanceResponse data;
  final String Function(num value) money;

  @override
  Widget build(BuildContext context) {
    Widget item(String title, double value, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                money(value),
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        item('К выводу', data.availableToWithdraw, const Color(0xFF86EFAC)),
        const SizedBox(width: 10),
        item('Выплачено', data.paidAmount, const Color(0xFF93C5FD)),
        const SizedBox(width: 10),
        item(
          'Назначено',
          data.assignedButUnpaidAmount,
          const Color(0xFFFDE68A),
        ),
      ],
    );
  }
}

class _FinanceStatsGrid extends StatelessWidget {
  const _FinanceStatsGrid({
    required this.data,
    required this.money,
  });

  final RestaurantFinanceResponse data;
  final String Function(num value) money;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, String value})>[
      (
        label: 'Доставлено заказов',
        value: '${data.summary.deliveredOrdersCount}',
      ),
      (
        label: 'Оборот',
        value: money(data.summary.grossTotal),
      ),
      (
        label: 'Средний payout',
        value: money(data.summary.averagePayoutPerOrder),
      ),
      (
        label: 'Средний чек',
        value: money(data.summary.averageGrossOrderValue),
      ),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 96,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final item = items[index];

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                item.value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.trailing,
  });

  final String title;
  final String trailing;

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
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: Text(
            trailing,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PayoutHistorySection extends StatelessWidget {
  const _PayoutHistorySection({
    required this.rows,
    required this.money,
    required this.dateTime,
    required this.period,
    required this.statusLabel,
    required this.statusColor,
  });

  final List<RestaurantFinancePayoutRow> rows;
  final String Function(num value) money;
  final String Function(DateTime? value) dateTime;
  final String Function(DateTime? start, DateTime? end) period;
  final String Function(String status) statusLabel;
  final Color Function(String status) statusColor;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyCard(
        title: 'История выплат пуста',
        subtitle: 'Пока нет payout-записей из админки за этот период',
      );
    }

    return Column(
      children: rows.map((row) {
        final chipColor = statusColor(row.status);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
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
                      color: chipColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel(row.status),
                      style: TextStyle(
                        color: chipColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Период: ${period(row.periodFrom, row.periodTo)}',
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 13,
                ),
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
              const SizedBox(height: 8),
              if ((row.paymentReference ?? '').isNotEmpty)
                Text(
                  'Референс: ${row.paymentReference}',
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 12,
                  ),
                ),
              if ((row.paymentComment ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Комментарий: ${row.paymentComment}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ),
              if ((row.note ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Заметка: ${row.note}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Создано: ${dateTime(row.createdAt)}',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                ),
              ),
              Text(
                row.paidAt != null
                    ? 'Оплачено: ${dateTime(row.paidAt)}'
                    : 'Оплачено: —',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _RecentOrdersSection extends StatelessWidget {
  const _RecentOrdersSection({
    required this.orders,
    required this.expandedOrderId,
    required this.money,
    required this.dateTime,
    required this.onToggleExpand,
  });

  final List<RestaurantFinanceOrder> orders;
  final String? expandedOrderId;
  final String Function(num value) money;
  final String Function(DateTime? value) dateTime;
  final ValueChanged<String> onToggleExpand;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const _EmptyCard(
        title: 'Нет доставленных заказов',
        subtitle: 'За выбранный период заказов пока нет',
      );
    }

    return Column(
      children: orders.map((order) {
        final expanded = expandedOrderId == order.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onToggleExpand(order.id),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Заказ №${order.number}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.user?.displayName ?? 'Клиент',
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Доставлен: ${dateTime(order.deliveredAt)}',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
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
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.isAssignedToPayout
                                ? 'Назначен в payout'
                                : 'Ожидает выплаты',
                            style: TextStyle(
                              color: order.isAssignedToPayout
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFF93C5FD),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF6B7280),
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
                      const Divider(color: Color(0xFF1F2937)),
                      _DetailRow(label: 'Subtotal', value: money(order.subtotal)),
                      _DetailRow(
                        label: 'Delivery fee',
                        value: money(order.deliveryFee),
                      ),
                      _DetailRow(
                        label: 'Discount',
                        value: money(order.discountAmount),
                      ),
                      _DetailRow(
                        label: 'Delivery discount',
                        value: money(order.deliveryDiscountAmount),
                      ),
                      _DetailRow(
                        label: 'Итог заказа',
                        value: money(order.total),
                      ),
                      _DetailRow(
                        label: 'Комиссия',
                        value: money(order.restaurantCommissionAmount),
                      ),
                      _DetailRow(
                        label: 'Ставка комиссии',
                        value:
                            '${order.restaurantCommissionPctApplied.toStringAsFixed(0)}%',
                      ),
                      const SizedBox(height: 10),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Позиции',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...order.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
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
        );
      }).toList(),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

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
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceSummarySection extends StatelessWidget {
  const _FinanceSummarySection({
    required this.periodLabel,
    required this.data,
    required this.money,
  });

  final String periodLabel;
  final RestaurantFinanceResponse data;
  final String Function(num value) money;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Итог за $periodLabel',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _DetailRow(
            label: 'Заказов доставлено',
            value: '${data.summary.deliveredOrdersCount}',
          ),
          _DetailRow(
            label: 'Оборот',
            value: money(data.summary.grossTotal),
          ),
          _DetailRow(
            label: 'Комиссия сервиса',
            value: money(data.summary.commissionAmount),
          ),
          _DetailRow(
            label: 'Начислено ресторану',
            value: money(data.summary.payoutAmount),
          ),
          _DetailRow(
            label: 'К выводу',
            value: money(data.availableToWithdraw),
          ),
          _DetailRow(
            label: 'Уже выплачено',
            value: money(data.paidAmount),
          ),
          _DetailRow(
            label: 'Назначено в payout',
            value: money(data.assignedButUnpaidAmount),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            color: Color(0xFF6B7280),
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}