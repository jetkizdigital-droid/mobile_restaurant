import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jetkiz_restaurant/core/localization/app_locale_controller.dart';
import 'package:jetkiz_restaurant/core/navigation/app_page_route.dart';
import 'package:jetkiz_restaurant/features/restaurant/data/restaurant_metrics_api.dart';
import 'package:jetkiz_restaurant/features/restaurant/domain/restaurant_metrics_data.dart';
import 'package:jetkiz_restaurant/features/reviews/presentation/pages/restaurant_reviews_page.dart';

class RestaurantStatisticsTab extends StatefulWidget {
  const RestaurantStatisticsTab({
    super.key,
    required this.restaurantId,
  });

  final String restaurantId;

  @override
  State<RestaurantStatisticsTab> createState() =>
      _RestaurantStatisticsTabState();
}

enum _PeriodMode { day, week, month, year, custom }

enum _ChartMode { revenue, orders }

class _RestaurantStatisticsTabState extends State<RestaurantStatisticsTab> {
  late final RestaurantMetricsApi _metricsApi;
  late Future<RestaurantMetricsData> _metricsFuture;

  _PeriodMode _periodMode = _PeriodMode.week;
  DateTime? _customFrom;
  DateTime? _customTo;

  String _t(String ru, String kk) => context.tr(ru, kk);

  @override
  void initState() {
    super.initState();
    _metricsApi = RestaurantMetricsApi();
    _metricsFuture = _loadMetrics();
  }

  Future<RestaurantMetricsData> _loadMetrics() {
    switch (_periodMode) {
      case _PeriodMode.day:
        return _metricsApi.getMetrics(restaurantId: widget.restaurantId, days: 1);
      case _PeriodMode.week:
        return _metricsApi.getMetrics(restaurantId: widget.restaurantId, days: 7);
      case _PeriodMode.month:
        return _metricsApi.getMetrics(restaurantId: widget.restaurantId, days: 30);
      case _PeriodMode.year:
        return _metricsApi.getMetrics(restaurantId: widget.restaurantId, days: 365);
      case _PeriodMode.custom:
        if (_customFrom != null && _customTo != null) {
          return _metricsApi.getMetrics(
            restaurantId: widget.restaurantId,
            from: _ymd(_customFrom!),
            to: _ymd(_customTo!),
          );
        }
        return _metricsApi.getMetrics(restaurantId: widget.restaurantId, days: 7);
    }
  }

  Future<void> _refresh() async {
    setState(() => _metricsFuture = _loadMetrics());
    await _metricsFuture;
  }

  void _setPeriod(_PeriodMode mode) {
    if (_periodMode == mode) return;
    setState(() {
      _periodMode = mode;
      if (mode == _PeriodMode.custom) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        _customTo ??= today;
        _customFrom ??= today.subtract(const Duration(days: 6));
      } else {
        _metricsFuture = _loadMetrics();
      }
    });
  }

  Future<void> _pickDate({required bool from}) async {
    final now = DateTime.now();
    final min = DateTime(now.year - 3, 1, 1);
    final max = DateTime(now.year + 1, 12, 31);
    var initial = from
        ? (_customFrom ?? now.subtract(const Duration(days: 6)))
        : (_customTo ?? now);
    if (initial.isBefore(min)) initial = min;
    if (initial.isAfter(max)) initial = max;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: min,
      lastDate: max,
      locale: Locale(context.isKazakh ? 'kk' : 'ru'),
      helpText: from
          ? _t('Дата начала', 'Басталу күні')
          : _t('Дата окончания', 'Аяқталу күні'),
      cancelText: _t('Отмена', 'Бас тарту'),
      confirmText: _t('Готово', 'Дайын'),
      builder: (context, child) => Theme(
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
      ),
    );
    if (picked == null) return;

    setState(() {
      final normalized = DateTime(picked.year, picked.month, picked.day);
      if (from) {
        _customFrom = normalized;
        if (_customTo != null && _customTo!.isBefore(normalized)) {
          _customTo = normalized;
        }
      } else {
        _customTo = normalized;
        if (_customFrom != null && _customFrom!.isAfter(normalized)) {
          _customFrom = normalized;
        }
      }
    });
  }

  void _applyCustom() {
    if (_customFrom == null || _customTo == null) {
      _message(
        _t(
          'Выберите даты начала и окончания периода.',
          'Кезеңнің басталу және аяқталу күндерін таңдаңыз.',
        ),
      );
      return;
    }
    if (_customFrom!.isAfter(_customTo!)) {
      _message(
        _t(
          'Дата начала не может быть позже даты окончания.',
          'Басталу күні аяқталу күнінен кейін болмауы керек.',
        ),
      );
      return;
    }
    setState(() => _metricsFuture = _loadMetrics());
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
        lower.contains('http 5')) {
      return _t(
        'Не удалось загрузить статистику. Проверьте интернет и повторите.',
        'Статистиканы жүктеу мүмкін болмады. Интернетті тексеріп, қайталаңыз.',
      );
    }
    return raw;
  }

  String _ymd(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _date(DateTime? date) =>
      date == null ? '—' : DateFormat('dd.MM.yyyy').format(date);

  String _periodLabel(RestaurantMetricsPeriod period) {
    if (_periodMode == _PeriodMode.custom &&
        _customFrom != null &&
        _customTo != null) {
      return '${_date(_customFrom)} — ${_date(_customTo)}';
    }
    final from = DateTime.tryParse(period.from ?? '');
    final to = DateTime.tryParse(period.to ?? '');
    if (from != null && to != null) return '${_date(from)} — ${_date(to)}';

    switch (_periodMode) {
      case _PeriodMode.day:
        return _t('Сегодня', 'Бүгін');
      case _PeriodMode.week:
        return _t('Последние 7 дней', 'Соңғы 7 күн');
      case _PeriodMode.month:
        return _t('Последние 30 дней', 'Соңғы 30 күн');
      case _PeriodMode.year:
        return _t('Последние 365 дней', 'Соңғы 365 күн');
      case _PeriodMode.custom:
        return _t('Выберите даты', 'Күндерді таңдаңыз');
    }
  }

  String _currency(int value) => '$value ₸';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RestaurantMetricsData>(
      future: _metricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _StateMessage(
            message: _safeError(snapshot.error!),
            action: _t('Повторить', 'Қайталау'),
            onPressed: _refresh,
          );
        }

        final metrics = snapshot.data;
        if (metrics == null) {
          return _StateMessage(
            message: _t('Статистика недоступна', 'Статистика қолжетімсіз'),
            action: _t('Обновить', 'Жаңарту'),
            onPressed: _refresh,
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF489F2A),
          backgroundColor: const Color(0xFF121B2C),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              _PeriodCard(
                mode: _periodMode,
                from: _customFrom,
                to: _customTo,
                selectedLabel: _periodLabel(metrics.period),
                onMode: _setPeriod,
                onFrom: () => _pickDate(from: true),
                onTo: () => _pickDate(from: false),
                onApply: _applyCustom,
              ),
              const SizedBox(height: 14),
              _ReviewsCard(
                count: metrics.reviews.reviewsCount,
                rating: metrics.reviews.averageRating,
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
                    title: _t('Оборот блюд', 'Тағамдар айналымы'),
                    value: _currency(metrics.overview.totalRevenue),
                    subtitle: '${_t('Средняя сумма', 'Орташа сома')} ${_currency(metrics.overview.avgCheckRevenue)}',
                  ),
                  _MetricTile(
                    icon: Icons.receipt_long_rounded,
                    title: _t('Заказы', 'Тапсырыстар'),
                    value: '${metrics.overview.totalOrders}',
                    subtitle: '${_t('Выполнено', 'Орындалды')}: ${metrics.overview.deliveredCount} · ${_t('Отменено', 'Бас тартылды')}: ${metrics.overview.canceledCount}',
                  ),
                  _MetricTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: _t('Выплаты', 'Төлемдер'),
                    value: '${metrics.overview.paidRatePercent}%',
                    subtitle: '${_t('Выплачено заказов', 'Төленген тапсырыстар')}: ${metrics.overview.paidCount}',
                  ),
                  _MetricTile(
                    icon: Icons.cancel_outlined,
                    title: _t('Отмены ресторана', 'Мейрамхана бас тартулары'),
                    value: '${metrics.overview.cancelRatePercent}%',
                    subtitle: '${_t('Отменено рестораном', 'Мейрамхана бас тартқан')}: ${metrics.overview.canceledCount}',
                  ),
                  _MetricTile(
                    icon: Icons.people_outline_rounded,
                    title: _t('Клиенты', 'Клиенттер'),
                    value: '${metrics.customers.activeCustomers}',
                    subtitle: '${_t('Новые', 'Жаңа')}: ${metrics.customers.newCustomers} · ${_t('Повторные', 'Қайта келген')}: ${metrics.customers.repeatRatePercent}%',
                  ),
                  _MetricTile(
                    icon: Icons.calendar_today_outlined,
                    title: _t('Активные 7 дней', '7 күн белсенді'),
                    value: '${metrics.customers.activeCustomersLast7}',
                    subtitle: _t('активных', 'белсенді'),
                  ),
                  _MetricTile(
                    icon: Icons.event_note_outlined,
                    title: _t('Активные 30 дней', '30 күн белсенді'),
                    value: '${metrics.customers.activeCustomersLast30}',
                    subtitle: _t('активных', 'белсенді'),
                  ),
                  _MetricTile(
                    icon: Icons.star_border_rounded,
                    title: _t('Рейтинг', 'Рейтинг'),
                    value: metrics.reviews.averageRating > 0
                        ? metrics.reviews.averageRating.toStringAsFixed(1)
                        : '0.0',
                    subtitle: '${_t('Отзывы', 'Пікірлер')}: ${metrics.reviews.reviewsCount} · ${metrics.reviews.reviewRatePercent}%',
                  ),
                  _MetricTile(
                    icon: Icons.verified_outlined,
                    title: _t('Доставлено', 'Жеткізілді'),
                    value: '${metrics.overview.deliveredRatePercent}%',
                    subtitle: '${metrics.overview.deliveredCount} ${_t('из', 'ішінен')} ${metrics.overview.totalOrders}',
                  ),
                  _MetricTile(
                    icon: Icons.payments_outlined,
                    title: _t('Начислено ресторану', 'Мейрамханаға есептелді'),
                    value: _currency(metrics.overview.totalDelivered),
                    subtitle: '${_t('Выплачено', 'Төленді')} ${_currency(metrics.overview.totalPaid)}',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _LineChartCard(
                title: _t('Оборот блюд по дням', 'Тағамдар айналымы күндер бойынша'),
                subtitle: _t(
                  'Сумма блюд по доставленным оплаченным заказам',
                  'Жеткізілген және төленген тапсырыстардағы тағамдар сомасы',
                ),
                items: metrics.daily,
                mode: _ChartMode.revenue,
              ),
              const SizedBox(height: 12),
              _LineChartCard(
                title: _t('Заказы по дням', 'Тапсырыстар күндер бойынша'),
                subtitle: _t(
                  'Количество заказов за выбранный период',
                  'Таңдалған кезеңдегі тапсырыстар саны',
                ),
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
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.mode,
    required this.from,
    required this.to,
    required this.selectedLabel,
    required this.onMode,
    required this.onFrom,
    required this.onTo,
    required this.onApply,
  });

  final _PeriodMode mode;
  final DateTime? from;
  final DateTime? to;
  final String selectedLabel;
  final ValueChanged<_PeriodMode> onMode;
  final VoidCallback onFrom;
  final VoidCallback onTo;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final labels = <_PeriodMode, String>{
      _PeriodMode.day: context.tr('День', 'Күн'),
      _PeriodMode.week: context.tr('Неделя', 'Апта'),
      _PeriodMode.month: context.tr('Месяц', 'Ай'),
      _PeriodMode.year: context.tr('Год', 'Жыл'),
      _PeriodMode.custom: context.tr('Период', 'Кезең'),
    };
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Период', 'Кезең'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: _PeriodMode.values.map((value) {
              final active = value == mode;
              return ChoiceChip(
                label: Text(labels[value]!),
                selected: active,
                showCheckmark: false,
                onSelected: (_) => onMode(value),
                selectedColor: const Color(0xFF489F2A),
                backgroundColor: const Color(0xFF1A2437),
                labelStyle: const TextStyle(color: Colors.white),
                side: BorderSide.none,
              );
            }).toList(),
          ),
          if (mode == _PeriodMode.custom) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: context.tr('С', 'Бастап'),
                    date: from,
                    onTap: onFrom,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateButton(
                    label: context.tr('До', 'Дейін'),
                    date: to,
                    onTap: onTo,
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
                child: Text(context.tr('Применить период', 'Кезеңді қолдану')),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '${context.tr('Выбранный период', 'Таңдалған кезең')}: $selectedLabel',
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

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.date, required this.onTap});
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final value = date == null ? '—' : DateFormat('dd.MM.yyyy').format(date!);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today_outlined, size: 16),
      label: Text('$label: $value'),
    );
  }
}

class _ReviewsCard extends StatelessWidget {
  const _ReviewsCard({required this.count, required this.rating, required this.onTap});
  final int count;
  final double rating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            const Icon(Icons.rate_review_rounded, color: Color(0xFF65C044)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Отзывы', 'Пікірлер'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$count · ${context.tr('рейтинг', 'рейтинг')} ${rating > 0 ? rating.toStringAsFixed(1) : '0.0'}',
                    style: const TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF65C044), size: 20),
          const Spacer(),
          Text(
            title,
            maxLines: 2,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

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
    final values = items.map((item) {
      return mode == _ChartMode.revenue
          ? item.revenue.toDouble()
          : item.orders.toDouble();
    }).toList();
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: CustomPaint(
              painter: _MiniLineChartPainter(
                values: values,
                lineColor: mode == _ChartMode.revenue
                    ? const Color(0xFF00E79A)
                    : const Color(0xFF5EA3FF),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(_dayLabel(items.first.date), style: _dateStyle),
                const Spacer(),
                Text(_dayLabel(items[items.length ~/ 2].date), style: _dateStyle),
                const Spacer(),
                Text(_dayLabel(items.last.date), style: _dateStyle),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static const _dateStyle = TextStyle(color: Colors.white30, fontSize: 10);

  static String _dayLabel(String raw) {
    final date = DateTime.tryParse(raw);
    return date == null ? raw : DateFormat('dd.MM').format(date);
  }
}

class _MiniLineChartPainter extends CustomPainter {
  _MiniLineChartPainter({required this.values, required this.lineColor});
  final List<double> values;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0x223E4B62)
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (values.isEmpty) return;

    final safe = values.map((value) => value.isFinite ? value : 0.0).toList();
    final maximum = math.max<double>(
      1,
      safe.fold<double>(0, (previous, value) => math.max(previous, value)),
    );
    final dx = safe.length == 1 ? 0.0 : size.width / (safe.length - 1);
    final path = Path();
    final points = <Offset>[];

    for (var index = 0; index < safe.length; index++) {
      final point = Offset(
        dx * index,
        size.height - (safe[index] / maximum * (size.height - 8)) - 4,
      );
      points.add(point);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    final fill = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          colors: [
            lineColor.withValues(alpha: 0.28),
            lineColor.withValues(alpha: 0.02),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniLineChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.lineColor != lineColor;
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trends});
  final RestaurantTrendStats trends;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Тренды', 'Трендтер'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _TrendRow(
            label: context.tr(
              'Оборот блюд к предыдущему периоду',
              'Тағамдар айналымы алдыңғы кезеңмен салыстырғанда',
            ),
            value: trends.trendRevenuePercent,
          ),
          const SizedBox(height: 8),
          _TrendRow(
            label: context.tr(
              'Заказы к предыдущему периоду',
              'Тапсырыстар алдыңғы кезеңмен салыстырғанда',
            ),
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
    final text = value == null
        ? '—'
        : '${positive ? '+' : ''}${value!.toStringAsFixed(1)}%';
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
        Text(
          text,
          style: TextStyle(
            color: value == null
                ? Colors.white54
                : positive
                    ? const Color(0xFF00E79A)
                    : const Color(0xFFFF7C7C),
            fontWeight: FontWeight.w800,
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
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Рекомендации', 'Ұсыныстар'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...suggestions.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.isWarning
                        ? Icons.warning_amber_rounded
                        : item.isSuccess
                            ? Icons.check_circle_outline_rounded
                            : Icons.auto_awesome_outlined,
                    color: item.isWarning
                        ? const Color(0xFFFFB24A)
                        : item.isSuccess
                            ? const Color(0xFF65C044)
                            : const Color(0xFF7BC6FF),
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.title.trim().isNotEmpty)
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (item.title.trim().isNotEmpty) const SizedBox(height: 2),
                        Text(
                          item.text,
                          style: const TextStyle(color: Colors.white70, height: 1.35),
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
}

class _TopClientsCard extends StatelessWidget {
  const _TopClientsCard({required this.clients});
  final List<RestaurantTopClientMetric> clients;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Топ клиентов', 'Үздік клиенттер'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...clients.take(5).map((client) {
            final name = client.name?.trim() ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  const Icon(Icons.person_outline_rounded, color: Colors.white54),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? context.tr('Клиент', 'Клиент') : name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${client.ordersCount} ${context.tr('заказов', 'тапсырыс')} · ${client.spent} ₸',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RecentOrdersCard extends StatelessWidget {
  const _RecentOrdersCard({required this.orders});
  final List<RestaurantRecentOrderMetric> orders;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Последние заказы', 'Соңғы тапсырыстар'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...orders.take(5).map((order) {
            final name = order.customerName?.trim() ?? '';
            final date = order.deliveredAt ?? order.createdAt;
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined, color: Colors.white54),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? context.tr('Клиент', 'Клиент') : name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (date != null)
                          Text(
                            DateFormat('dd.MM.yyyy HH:mm').format(date.toLocal()),
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${order.total} ₸',
                    style: const TextStyle(
                      color: Color(0xFF86EFAC),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF121B2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22314A)),
      ),
      child: child,
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.message,
    required this.action,
    required this.onPressed,
  });

  final String message;
  final String action;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF489F2A),
              ),
              child: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}
