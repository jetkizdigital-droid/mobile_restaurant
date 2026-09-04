import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jetkiz_restaurant/core/navigation/app_page_route.dart';
import 'package:jetkiz_restaurant/features/restaurant/data/restaurant_metrics_api.dart';
import 'package:jetkiz_restaurant/features/restaurant/domain/restaurant_metrics_data.dart';
import 'package:jetkiz_restaurant/features/reviews/presentation/pages/restaurant_reviews_page.dart';

class RestaurantStatisticsTab extends StatefulWidget {
  const RestaurantStatisticsTab({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  State<RestaurantStatisticsTab> createState() =>
      _RestaurantStatisticsTabState();
}

enum _StatisticsPeriodMode { day, week, month, year, custom }

class _RestaurantStatisticsTabState extends State<RestaurantStatisticsTab> {
  late final RestaurantMetricsApi _metricsApi;
  late Future<RestaurantMetricsData> _metricsFuture;

  _StatisticsPeriodMode _periodMode = _StatisticsPeriodMode.week;

  DateTime? _customFrom;
  DateTime? _customTo;

  @override
  void initState() {
    super.initState();
    _metricsApi = RestaurantMetricsApi();
    _metricsFuture = _loadMetrics();
  }

  Future<RestaurantMetricsData> _loadMetrics() {
    switch (_periodMode) {
      case _StatisticsPeriodMode.day:
        return _metricsApi.getMetrics(
          restaurantId: widget.restaurantId,
          days: 1,
        );
      case _StatisticsPeriodMode.week:
        return _metricsApi.getMetrics(
          restaurantId: widget.restaurantId,
          days: 7,
        );
      case _StatisticsPeriodMode.month:
        return _metricsApi.getMetrics(
          restaurantId: widget.restaurantId,
          days: 30,
        );
      case _StatisticsPeriodMode.year:
        return _metricsApi.getMetrics(
          restaurantId: widget.restaurantId,
          days: 365,
        );
      case _StatisticsPeriodMode.custom:
        if (_customFrom != null && _customTo != null) {
          return _metricsApi.getMetrics(
            restaurantId: widget.restaurantId,
            from: _ymd(_customFrom!),
            to: _ymd(_customTo!),
          );
        }

        return _metricsApi.getMetrics(
          restaurantId: widget.restaurantId,
          days: 7,
        );
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _metricsFuture = _loadMetrics();
    });
    await _metricsFuture;
  }

  void _setPeriodMode(_StatisticsPeriodMode mode) {
    if (_periodMode == mode) return;

    setState(() {
      _periodMode = mode;

      if (mode == _StatisticsPeriodMode.custom) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        _customTo ??= today;
        _customFrom ??= today.subtract(const Duration(days: 6));

        if (_customFrom!.isAfter(_customTo!)) {
          _customFrom = _customTo;
        }
      } else {
        _metricsFuture = _loadMetrics();
      }
    });
  }

  Future<void> _pickCustomFrom() async {
    final now = DateTime.now();
    final minDate = DateTime(now.year - 3, 1, 1);
    final maxDate = _customTo ?? DateTime(now.year + 1, 12, 31);

    DateTime initialDate = _customFrom ?? now.subtract(const Duration(days: 6));

    if (initialDate.isBefore(minDate)) {
      initialDate = minDate;
    }
    if (initialDate.isAfter(maxDate)) {
      initialDate = maxDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minDate,
      lastDate: maxDate,
      locale: const Locale('ru'),
      helpText: 'Дата начала',
      cancelText: 'Отмена',
      confirmText: 'Готово',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF489F2A),
              surface: Color(0xFF121B2C),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF09111C),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _customFrom = DateTime(picked.year, picked.month, picked.day);

      if (_customTo != null && _customTo!.isBefore(_customFrom!)) {
        _customTo = _customFrom;
      }
    });
  }

  Future<void> _pickCustomTo() async {
    final now = DateTime.now();
    final minDate = _customFrom ?? DateTime(now.year - 3, 1, 1);
    final maxDate = DateTime(now.year + 1, 12, 31);

    DateTime initialDate = _customTo ?? _customFrom ?? now;

    if (initialDate.isBefore(minDate)) {
      initialDate = minDate;
    }
    if (initialDate.isAfter(maxDate)) {
      initialDate = maxDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minDate,
      lastDate: maxDate,
      locale: const Locale('ru'),
      helpText: 'Дата конца',
      cancelText: 'Отмена',
      confirmText: 'Готово',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF489F2A),
              surface: Color(0xFF121B2C),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF09111C),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _customTo = DateTime(picked.year, picked.month, picked.day);

      if (_customFrom != null && _customFrom!.isAfter(_customTo!)) {
        _customFrom = _customTo;
      }
    });
  }

  void _applyCustomPeriod() {
    if (_customFrom == null || _customTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите даты начала и конца периода')),
      );
      return;
    }

    if (_customFrom!.isAfter(_customTo!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Дата начала не может быть позже даты конца'),
        ),
      );
      return;
    }

    setState(() {
      _metricsFuture = _loadMetrics();
    });
  }

  String _ymd(DateTime date) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  String _displayDate(DateTime? date) {
    if (date == null) return 'дд.мм.гггг';
    return DateFormat('dd.MM.yyyy').format(date);
  }

  String _buildSelectedPeriodLabel(RestaurantMetricsPeriod period) {
    if (_periodMode == _StatisticsPeriodMode.custom &&
        _customFrom != null &&
        _customTo != null) {
      return '${_displayDate(_customFrom)} — ${_displayDate(_customTo)}';
    }

    final from = DateTime.tryParse(period.from ?? '');
    final to = DateTime.tryParse(period.to ?? '');

    if (from != null && to != null) {
      return '${_displayDate(from)} — ${_displayDate(to)}';
    }

    switch (_periodMode) {
      case _StatisticsPeriodMode.day:
        return 'Сегодня';
      case _StatisticsPeriodMode.week:
        return 'Последние 7 дней';
      case _StatisticsPeriodMode.month:
        return 'Последние 30 дней';
      case _StatisticsPeriodMode.year:
        return 'Последние 365 дней';
      case _StatisticsPeriodMode.custom:
        return 'Выберите даты';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RestaurantMetricsData>(
      future: _metricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ошибка загрузки статистики: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _refresh,
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

        final metrics = snapshot.data;
        if (metrics == null) {
          return const Center(
            child: Text(
              'Статистика недоступна',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF489F2A),
          backgroundColor: const Color(0xFF121B2C),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              _StatisticsPeriodCard(
                mode: _periodMode,
                customFrom: _customFrom,
                customTo: _customTo,
                selectedPeriodLabel: _buildSelectedPeriodLabel(metrics.period),
                onModeSelected: _setPeriodMode,
                onPickFrom: _pickCustomFrom,
                onPickTo: _pickCustomTo,
                onApplyCustom: _applyCustomPeriod,
                displayDate: _displayDate,
              ),
              const SizedBox(height: 14),
              _ReviewsNavigationCard(
                reviewsCount: metrics.reviews.reviewsCount,
                averageRating: metrics.reviews.averageRating,
                onTap: () {
                  Navigator.of(context).push(
                    AppPageRoute<void>(
                      page: RestaurantReviewsPage(
                        restaurantId: widget.restaurantId,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 0.92,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _MetricTile(
                    icon: Icons.trending_up_rounded,
                    iconBg: const Color(0x3329D391),
                    iconColor: const Color(0xFF00E79A),
                    title: 'Оборот блюд',
                    value: _currency(metrics.overview.totalRevenue),
                    subtitle:
                        'Средняя сумма ${_currency(metrics.overview.avgCheckRevenue)}',
                  ),
                  _MetricTile(
                    icon: Icons.receipt_long_rounded,
                    iconBg: const Color(0x332A7BFF),
                    iconColor: const Color(0xFF5EA3FF),
                    title: 'Заказы',
                    value: '${metrics.overview.totalOrders}',
                    subtitle:
                        'Выполнено: ${metrics.overview.deliveredCount}, Отменено: ${metrics.overview.canceledCount}',
                  ),
                  _MetricTile(
                    icon: Icons.account_balance_wallet_outlined,
                    iconBg: const Color(0x3300D0FF),
                    iconColor: const Color(0xFF00D9FF),
                    title: 'Выплаты',
                    value: '${metrics.overview.paidRatePercent}%',
                    subtitle:
                        'Выплачено заказов: ${metrics.overview.paidCount}',
                  ),
                  _MetricTile(
                    icon: Icons.cancel_outlined,
                    iconBg: const Color(0x33FF5A6E),
                    iconColor: const Color(0xFFFF6B7C),
                    title: 'Отмены',
                    value: '${metrics.overview.cancelRatePercent}%',
                    subtitle: 'Отменено: ${metrics.overview.canceledCount}',
                  ),
                  _MetricTile(
                    icon: Icons.people_outline_rounded,
                    iconBg: const Color(0x334E3BFF),
                    iconColor: const Color(0xFF9A8BFF),
                    title: 'Клиенты',
                    value: '${metrics.customers.activeCustomers}',
                    subtitle:
                        'Новые: ${metrics.customers.newCustomers}, Повторные: ${metrics.customers.repeatRatePercent}%',
                  ),
                  _MetricTile(
                    icon: Icons.calendar_today_outlined,
                    iconBg: const Color(0x334F5D75),
                    iconColor: const Color(0xFFD0D7E2),
                    title: 'Активные 7 дней',
                    value: '${metrics.customers.activeCustomersLast7}',
                    subtitle: 'активных',
                  ),
                  _MetricTile(
                    icon: Icons.event_note_outlined,
                    iconBg: const Color(0x334F5D75),
                    iconColor: const Color(0xFFD0D7E2),
                    title: 'Активные 30 дней',
                    value: '${metrics.customers.activeCustomersLast30}',
                    subtitle: 'активных',
                  ),
                  _MetricTile(
                    icon: Icons.star_border_rounded,
                    iconBg: const Color(0x33FF9800),
                    iconColor: const Color(0xFFFFB24A),
                    title: 'Рейтинг',
                    value: metrics.reviews.averageRating > 0
                        ? metrics.reviews.averageRating.toStringAsFixed(1)
                        : '0.0',
                    subtitle:
                        'Отзывы: ${metrics.reviews.reviewsCount}, доля ${metrics.reviews.reviewRatePercent}%',
                  ),
                  _MetricTile(
                    icon: Icons.verified_outlined,
                    iconBg: const Color(0x3329D391),
                    iconColor: const Color(0xFF00E79A),
                    title: 'Доставлено',
                    value: '${metrics.overview.deliveredRatePercent}%',
                    subtitle:
                        '${metrics.overview.deliveredCount} из ${metrics.overview.totalOrders}',
                  ),
                  _MetricTile(
                    icon: Icons.payments_outlined,
                    iconBg: const Color(0x333CCB7F),
                    iconColor: const Color(0xFF5CF2A0),
                    title: 'Начислено ресторану',
                    value: _currency(metrics.overview.totalDelivered),
                    subtitle:
                        'Выплачено ${_currency(metrics.overview.totalPaid)}',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _LineChartCard(
                title: 'Оборот блюд по дням',
                subtitle: 'Сумма блюд по доставленным оплаченным заказам',
                items: metrics.daily,
                mode: _ChartMode.revenue,
              ),
              const SizedBox(height: 12),
              _LineChartCard(
                title: 'Заказы по дням',
                subtitle: 'Количество заказов за выбранный период',
                items: metrics.daily,
                mode: _ChartMode.orders,
              ),
              if (metrics.trends.trendRevenuePercent != null ||
                  metrics.trends.trendOrdersPercent != null) ...[
                const SizedBox(height: 12),
                _TrendCard(trends: metrics.trends),
              ],
              if (metrics.suggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SuggestionsCard(suggestions: metrics.suggestions),
              ],
              if (metrics.topClients.isNotEmpty) ...[
                const SizedBox(height: 12),
                _TopClientsCard(clients: metrics.topClients),
              ],
              if (metrics.recentOrders.isNotEmpty) ...[
                const SizedBox(height: 12),
                _RecentOrdersCard(orders: metrics.recentOrders),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _currency(int value) {
    return '$value ₸';
  }
}

class _ReviewsNavigationCard extends StatelessWidget {
  const _ReviewsNavigationCard({
    required this.reviewsCount,
    required this.averageRating,
    required this.onTap,
  });

  final int reviewsCount;
  final double averageRating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratingText = averageRating > 0
        ? averageRating.toStringAsFixed(1)
        : '0.0';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF121B2C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF22314A)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0x33489F2A),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.rate_review_rounded,
                  color: Color(0xFF65C044),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Отзывы',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$reviewsCount отзывов • рейтинг $ratingText',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white54,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatisticsPeriodCard extends StatelessWidget {
  const _StatisticsPeriodCard({
    required this.mode,
    required this.customFrom,
    required this.customTo,
    required this.selectedPeriodLabel,
    required this.onModeSelected,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onApplyCustom,
    required this.displayDate,
  });

  final _StatisticsPeriodMode mode;
  final DateTime? customFrom;
  final DateTime? customTo;
  final String selectedPeriodLabel;
  final ValueChanged<_StatisticsPeriodMode> onModeSelected;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onApplyCustom;
  final String Function(DateTime?) displayDate;

  @override
  Widget build(BuildContext context) {
    final isCustom = mode == _StatisticsPeriodMode.custom;
    final canApply = customFrom != null && customTo != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22314A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                color: Color(0xFF65C044),
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Период',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PeriodChip(
                label: 'День',
                selected: mode == _StatisticsPeriodMode.day,
                onTap: () => onModeSelected(_StatisticsPeriodMode.day),
              ),
              _PeriodChip(
                label: 'Неделя',
                selected: mode == _StatisticsPeriodMode.week,
                onTap: () => onModeSelected(_StatisticsPeriodMode.week),
              ),
              _PeriodChip(
                label: 'Месяц',
                selected: mode == _StatisticsPeriodMode.month,
                onTap: () => onModeSelected(_StatisticsPeriodMode.month),
              ),
              _PeriodChip(
                label: 'Год',
                selected: mode == _StatisticsPeriodMode.year,
                onTap: () => onModeSelected(_StatisticsPeriodMode.year),
              ),
              _PeriodChip(
                label: 'Период',
                selected: mode == _StatisticsPeriodMode.custom,
                onTap: () => onModeSelected(_StatisticsPeriodMode.custom),
              ),
            ],
          ),
          if (isCustom) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFF25344B)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'С',
                    value: displayDate(customFrom),
                    onTap: onPickFrom,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'До',
                    value: displayDate(customTo),
                    onTap: onPickTo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canApply ? onApplyCustom : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D3A52),
                  disabledBackgroundColor: const Color(0xFF2A3346),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white38,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Применить период',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Выбранный период:',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              Expanded(
                child: Text(
                  selectedPeriodLabel,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF65C044),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = value == 'дд.мм.гггг';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1626),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A3A52)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        color: isPlaceholder
                            ? const Color(0xFF6F7C91)
                            : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: Colors.white54,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF489F2A) : const Color(0xFF1A2437),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFF65C044)
                  : const Color(0xFF233149),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(selected ? 1 : 0.82),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22314A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              height: 1.0,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChartMode { revenue, orders }

class _LineChartCard extends StatelessWidget {
  const _LineChartCard({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.mode,
  });

  final String title;
  final String subtitle;
  final List<RestaurantDailyMetric> items;
  final _ChartMode mode;

  @override
  Widget build(BuildContext context) {
    final values = items
        .map(
          (e) => mode == _ChartMode.revenue
              ? e.revenue.toDouble()
              : e.orders.toDouble(),
        )
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22314A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                mode == _ChartMode.revenue
                    ? Icons.insert_chart_outlined_rounded
                    : Icons.show_chart_rounded,
                color: Colors.white38,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 132,
            child: _MiniLineChart(
              values: values,
              lineColor: mode == _ChartMode.revenue
                  ? const Color(0xFF00E79A)
                  : const Color(0xFF5EA3FF),
            ),
          ),
          const SizedBox(height: 10),
          if (items.isNotEmpty)
            Row(
              children: [
                Text(
                  _labelFor(items.first.date),
                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                ),
                const Spacer(),
                Text(
                  _labelFor(items[items.length ~/ 2].date),
                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                ),
                const Spacer(),
                Text(
                  _labelFor(items.last.date),
                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String _labelFor(String raw) {
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    return DateFormat('MM-dd').format(date);
  }
}

class _MiniLineChart extends StatelessWidget {
  const _MiniLineChart({required this.values, required this.lineColor});

  final List<double> values;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MiniLineChartPainter(
        values: values,
        lineColor: lineColor,
        gridColor: const Color(0x223E4B62),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _MiniLineChartPainter extends CustomPainter {
  _MiniLineChartPainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.isEmpty) return;

    final safeValues = values.map((e) => e.isFinite ? e : 0.0).toList();

    final maxValue = math.max<double>(
      1.0,
      safeValues.fold<double>(0.0, (prev, e) => math.max<double>(prev, e)),
    );

    final dx = safeValues.length == 1
        ? 0.0
        : size.width / (safeValues.length - 1);

    final path = Path();
    final points = <Offset>[];

    for (var i = 0; i < safeValues.length; i++) {
      final x = dx * i;
      final ratio = safeValues[i] / maxValue;
      final y = size.height - (ratio * (size.height - 8)) - 4;
      final point = Offset(x, y);
      points.add(point);

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [lineColor.withOpacity(0.28), lineColor.withOpacity(0.02)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    final pointPaint = Paint()..color = lineColor;
    final pointFillPaint = Paint()..color = const Color(0xFF121B2C);

    for (final point in points) {
      canvas.drawCircle(point, 4.5, pointPaint);
      canvas.drawCircle(point, 2.4, pointFillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniLineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trends});

  final RestaurantTrendStats trends;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22314A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Тренды',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _TrendRow(
            label: 'Оборот блюд vs предыдущий период',
            value: trends.trendRevenuePercent,
          ),
          const SizedBox(height: 10),
          _TrendRow(
            label: 'Заказы vs предыдущий период',
            value: trends.trendOrdersPercent,
          ),
        ],
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final positive = (value ?? 0) >= 0;
    final display = value == null
        ? '—'
        : '${positive ? '+' : ''}${value!.toStringAsFixed(1)}%';

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: value == null
                ? const Color(0x33233149)
                : positive
                ? const Color(0x3329D391)
                : const Color(0x33FF5A6E),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            display,
            style: TextStyle(
              color: value == null
                  ? Colors.white54
                  : positive
                  ? const Color(0xFF00E79A)
                  : const Color(0xFFFF7C7C),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SuggestionsCard extends StatelessWidget {
  const _SuggestionsCard({required this.suggestions});

  final List<RestaurantSuggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22314A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Рекомендации',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...suggestions.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      _iconForSuggestion(item),
                      color: _colorForSuggestion(item),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.title.trim().isNotEmpty)
                          Text(
                            item.title,
                            style: TextStyle(
                              color: _colorForSuggestion(item),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (item.title.trim().isNotEmpty)
                          const SizedBox(height: 4),
                        Text(
                          item.text,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconForSuggestion(RestaurantSuggestion item) {
    if (item.isWarning) return Icons.warning_amber_rounded;
    if (item.isSuccess) return Icons.check_circle_outline_rounded;
    return Icons.auto_awesome_outlined;
  }

  static Color _colorForSuggestion(RestaurantSuggestion item) {
    if (item.isWarning) return const Color(0xFFFFB24A);
    if (item.isSuccess) return const Color(0xFF65C044);
    return const Color(0xFF7BC6FF);
  }
}

class _TopClientsCard extends StatelessWidget {
  const _TopClientsCard({required this.clients});

  final List<RestaurantTopClientMetric> clients;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22314A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Топ клиенты',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...clients
              .take(5)
              .map(
                (client) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2437),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.person_outline_rounded,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayClientName(client),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${client.ordersCount} заказов • ${client.spent} ₸',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x332A7BFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          client.status,
                          style: const TextStyle(
                            color: Color(0xFFB9C8FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  static String _displayClientName(RestaurantTopClientMetric client) {
    if (client.name?.trim().isNotEmpty == true) return client.name!.trim();
    if (client.phone?.trim().isNotEmpty == true) return client.phone!.trim();
    return 'Клиент';
  }
}

class _RecentOrdersCard extends StatelessWidget {
  const _RecentOrdersCard({required this.orders});

  final List<RestaurantRecentOrderMetric> orders;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22314A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Последние заказы',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...orders
              .take(5)
              .map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customerName?.trim().isNotEmpty == true
                                  ? order.customerName!.trim()
                                  : (order.phone?.trim().isNotEmpty == true
                                        ? order.phone!.trim()
                                        : 'Клиент'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${order.total} ₸ • ${order.status ?? '—'}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatDateTime(order.createdAt),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime? value) {
    if (value == null) return '—';
    return DateFormat('dd.MM HH:mm').format(value.toLocal());
  }
}
