import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jetkiz_restaurant/core/localization/app_locale_controller.dart';

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

  String _t(String ru, String kk) => context.tr(ru, kk);

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
        period: _periodApiValue(_period),
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
        _error = _safeError(error);
        _loading = false;
      });
    }
  }

  String _safeError(Object error) {
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
      return _t(
        'Не удалось загрузить финансы. Проверьте интернет и повторите.',
        'Қаржы деректерін жүктеу мүмкін болмады. Интернетті тексеріп, қайталаңыз.',
      );
    }
    return raw;
  }

  String _periodApiValue(FinancePeriod period) {
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

  String _periodLabel([FinancePeriod? value]) {
    switch (value ?? _period) {
      case FinancePeriod.today:
        return _t('Сегодня', 'Бүгін');
      case FinancePeriod.yesterday:
        return _t('Вчера', 'Кеше');
      case FinancePeriod.week:
        return _t('7 дней', '7 күн');
      case FinancePeriod.month:
        return _t('30 дней', '30 күн');
      case FinancePeriod.custom:
        return _t('Период', 'Кезең');
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
    if (period != FinancePeriod.custom) _loadFinance();
  }

  void _applyCustomPeriod() {
    final start = DateTime.tryParse(_customStartDate.trim());
    final end = DateTime.tryParse(_customEndDate.trim());
    if (start == null || end == null) {
      _showMessage(
        _t(
          'Укажите даты в формате ГГГГ-ММ-ДД.',
          'Күндерді ЖЖЖЖ-АА-КК форматында енгізіңіз.',
        ),
      );
      return;
    }
    if (start.isAfter(end)) {
      _showMessage(
        _t(
          'Дата начала не может быть позже даты окончания.',
          'Басталу күні аяқталу күнінен кейін болмауы керек.',
        ),
      );
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

  String _money(num value) =>
      '${_moneyFormat.format(value).replaceAll(',', ' ')} ₸';

  String _date(DateTime? value) =>
      value == null ? '—' : _dateFormat.format(value.toLocal());

  String _dateTime(DateTime? value) =>
      value == null ? '—' : _dateTimeFormat.format(value.toLocal());

  String _range(DateTime? start, DateTime? end) =>
      '${_date(start)} — ${_date(end)}';

  String _payoutStatus(String status) {
    switch (status.trim().toUpperCase()) {
      case 'PAID':
        return _t('Оплачено', 'Төленді');
      case 'PENDING':
        return _t('Ожидает', 'Күтілуде');
      case 'CANCELED':
      case 'CANCELLED':
        return _t('Отменено', 'Бас тартылды');
      default:
        return _t('Неизвестно', 'Белгісіз');
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
    return full.isEmpty ? _t('Клиент', 'Клиент') : full;
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
              labelFor: _periodLabel,
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
                          actionLabel: _t('Повторить', 'Қайталау'),
                          onAction: _loadFinance,
                        )
                      : data == null
                          ? _FinanceMessageState(
                              icon: Icons.account_balance_wallet_outlined,
                              title: _t(
                                'Финансовых данных пока нет',
                                'Қаржы деректері әзірге жоқ',
                              ),
                              actionLabel: _t('Обновить', 'Жаңарту'),
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
                                  _metrics(data),
                                  const SizedBox(height: 20),
                                  _SectionHeader(
                                    title: _t(
                                      'История выплат',
                                      'Төлемдер тарихы',
                                    ),
                                    count: data.payouts.rows.length,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildPayouts(data.payouts.rows),
                                  const SizedBox(height: 20),
                                  _SectionHeader(
                                    title: _t(
                                      'Последние доставленные заказы',
                                      'Соңғы жеткізілген тапсырыстар',
                                    ),
                                    count: data.recentDeliveredOrders.length,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildOrders(data.recentDeliveredOrders),
                                  const SizedBox(height: 20),
                                  _PeriodSummaryCard(
                                    periodLabel: _periodLabel(),
                                    delivered: data.summary.deliveredOrdersCount,
                                    gross: _money(data.summary.grossTotal),
                                    commission: _money(data.summary.commissionAmount),
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

  Widget _metrics(RestaurantFinanceResponse data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: _t('Выплачено', 'Төленді'),
                value: _money(data.paidAmount),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: _t('Назначено', 'Тағайындалды'),
                value: _money(data.assignedButUnpaidAmount),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: _t('Доставлено', 'Жеткізілді'),
                value: '${data.summary.deliveredOrdersCount}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: _t('Сумма блюд', 'Тағамдар сомасы'),
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
                label: _t('Среднее начисление', 'Орташа есептеу'),
                value: _money(data.summary.averagePayoutPerOrder),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: _t('Средняя сумма блюд', 'Тағамдардың орташа сомасы'),
                value: _money(data.summary.averageGrossOrderValue),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPayouts(List<RestaurantFinancePayoutRow> rows) {
    if (rows.isEmpty) {
      return _EmptyCard(
        title: _t('Выплат пока нет', 'Төлемдер әзірге жоқ'),
        subtitle: _t(
          'Сформированные выплаты появятся здесь.',
          'Қалыптастырылған төлемдер осында көрсетіледі.',
        ),
      );
    }

    final visible = _showAllPayouts ? rows : rows.take(3).toList();
    return Column(
      children: [
        ...visible.map((row) {
          final color = _payoutStatusColor(row.status);
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
                          _money(row.payoutAmount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _StatusChip(
                        label: _payoutStatus(row.status),
                        color: color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _range(row.periodFrom, row.periodTo),
                    style: const TextStyle(color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_t('Заказов', 'Тапсырыс')}: ${row.ordersCount} · ${_t('Комиссия', 'Комиссия')}: ${_money(row.commissionAmount)}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                  if (row.paidAt != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      '${_t('Оплачено', 'Төленді')}: ${_dateTime(row.paidAt)}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
        if (rows.length > 3)
          TextButton(
            onPressed: () => setState(() => _showAllPayouts = !_showAllPayouts),
            child: Text(
              _showAllPayouts
                  ? _t('Свернуть', 'Жинау')
                  : '${_t('Показать все', 'Барлығын көрсету')} (${rows.length})',
            ),
          ),
      ],
    );
  }

  Widget _buildOrders(List<RestaurantFinanceOrder> orders) {
    if (orders.isEmpty) {
      return _EmptyCard(
        title: _t('Доставленных заказов пока нет', 'Жеткізілген тапсырыс әзірге жоқ'),
        subtitle: _t(
          'После доставки заказы появятся здесь.',
          'Жеткізілгеннен кейін тапсырыстар осында көрсетіледі.',
        ),
      );
    }

    final visible = _showAllOrders ? orders : orders.take(3).toList();
    return Column(
      children: [
        ...visible.map((order) {
          final expanded = _expandedOrderId == order.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Card(
              padding: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() {
                  _expandedOrderId = expanded ? null : order.id;
                }),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.number > 0
                                  ? '${_t('Заказ', 'Тапсырыс')} #${order.number}'
                                  : _t('Заказ', 'Тапсырыс'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            _money(order.restaurantPayoutAmount),
                            style: const TextStyle(
                              color: Color(0xFF86EFAC),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            expanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            color: const Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_clientName(order)} · ${_dateTime(order.deliveredAt)}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                      if (expanded) ...[
                        const Divider(height: 22, color: Color(0xFF263244)),
                        _SummaryLine(
                          label: _t('Сумма блюд', 'Тағамдар сомасы'),
                          value: _money(order.subtotal),
                        ),
                        _SummaryLine(
                          label: _t('Комиссия', 'Комиссия'),
                          value: _money(order.restaurantCommissionAmount),
                        ),
                        _SummaryLine(
                          label: _t('Начислено ресторану', 'Мейрамханаға есептелді'),
                          value: _money(order.restaurantPayoutAmount),
                          strong: true,
                        ),
                        if (order.items.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _t('Состав заказа', 'Тапсырыс құрамы'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...order.items.take(10).map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '${item.quantity} × ${item.title} · ${_money(item.price)}',
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        if (orders.length > 3)
          TextButton(
            onPressed: () => setState(() => _showAllOrders = !_showAllOrders),
            child: Text(
              _showAllOrders
                  ? _t('Свернуть', 'Жинау')
                  : '${_t('Показать все', 'Барлығын көрсету')} (${orders.length})',
            ),
          ),
      ],
    );
  }
}

class _FinanceHeader extends StatelessWidget {
  const _FinanceHeader({
    required this.period,
    required this.periodLabel,
    required this.labelFor,
    required this.onChanged,
  });

  final FinancePeriod period;
  final String periodLabel;
  final String Function(FinancePeriod period) labelFor;
  final ValueChanged<FinancePeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = FinancePeriod.values;
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
              Expanded(
                child: Text(
                  context.tr('Финансы', 'Қаржы'),
                  style: const TextStyle(
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
                final selected = item == period;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selected,
                    showCheckmark: false,
                    label: Text(labelFor(item)),
                    onSelected: (_) => onChanged(item),
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
          Text(
            context.tr('Свой период', 'Өз кезеңі'),
            style: const TextStyle(
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
                  label: context.tr('С даты', 'Бастап'),
                  initialValue: startDate,
                  onChanged: onStartChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                  label: context.tr('По дату', 'Дейін'),
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
              child: Text(context.tr('Применить', 'Қолдану')),
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
          Text(
            context.tr('К выплате', 'Төлеуге'),
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
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
            '${context.tr('За период', 'Кезең')}: $periodLabel',
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
    final rateText = rate == null
        ? context.tr('по умолчанию', 'әдепкі')
        : '$rate%';
    final kind = individual
        ? context.tr('Индивидуальная комиссия', 'Жеке комиссия')
        : context.tr('Общая комиссия', 'Жалпы комиссия');
    return _Card(
      child: Row(
        children: [
          const Icon(Icons.percent_rounded, color: Color(0xFFF59E0B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Комиссия сервиса', 'Сервис комиссиясы'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$kind · $rateText',
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
            '${context.tr('Итог за период', 'Кезең қорытындысы')} · $periodLabel',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _SummaryLine(
            label: context.tr('Доставлено заказов', 'Жеткізілген тапсырыстар'),
            value: '$delivered',
          ),
          _SummaryLine(
            label: context.tr('Сумма блюд', 'Тағамдар сомасы'),
            value: gross,
          ),
          _SummaryLine(
            label: context.tr('Комиссия', 'Комиссия'),
            value: commission,
          ),
          _SummaryLine(
            label: context.tr('Начислено ресторану', 'Мейрамханаға есептелді'),
            value: payout,
          ),
          _SummaryLine(
            label: context.tr('К выплате', 'Төлеуге'),
            value: available,
            strong: true,
          ),
          _SummaryLine(
            label: context.tr('Уже выплачено', 'Төленіп қойды'),
            value: paid,
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value, this.strong = false});
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: strong ? Colors.white : const Color(0xFF94A3B8),
                fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              color: strong ? const Color(0xFF86EFAC) : Colors.white,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});
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
            size: 34,
          ),
          const SizedBox(height: 8),
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
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF94A3B8), size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF489F2A),
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
