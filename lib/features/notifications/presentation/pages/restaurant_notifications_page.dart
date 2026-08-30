import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jetkiz_restaurant/features/notifications/data/restaurant_notifications_api.dart';
import 'package:jetkiz_restaurant/features/orders/presentation/pages/restaurant_order_details_page.dart';

class RestaurantNotificationsPage extends StatefulWidget {
  const RestaurantNotificationsPage({super.key});

  @override
  State<RestaurantNotificationsPage> createState() =>
      _RestaurantNotificationsPageState();
}

class _RestaurantNotificationsPageState
    extends State<RestaurantNotificationsPage> {
  final RestaurantNotificationsApi _api = RestaurantNotificationsApi();
  final ScrollController _scrollController = ScrollController();

  final List<RestaurantNotification> _items = <RestaurantNotification>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _markingAll = false;
  String? _error;
  int _page = 1;
  int _total = 0;

  bool get _hasMore => _items.length < _total;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || !_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 280) {
      _loadMore();
    }
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    }

    try {
      final result = await _api.getNotifications(page: reset ? 1 : _page);
      if (!mounted) return;

      setState(() {
        _total = result.total;
        if (reset) {
          _items
            ..clear()
            ..addAll(result.items);
        } else {
          _items.addAll(result.items);
        }
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '').trim();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() {
      _loadingMore = true;
      _page += 1;
    });
    await _load(reset: false);
  }

  Future<void> _refresh() => _load(reset: true);

  Future<void> _markAllRead() async {
    if (_markingAll || !_items.any((item) => !item.isRead)) return;
    setState(() => _markingAll = true);

    try {
      await _api.markAllRead();
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          _items[i] = _items[i].copyWith(isRead: true);
        }
      });
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _openNotification(RestaurantNotification item) async {
    if (!item.isRead && item.id.isNotEmpty) {
      try {
        await _api.markRead(item.id);
        if (mounted) {
          final index = _items.indexWhere((value) => value.id == item.id);
          if (index >= 0) {
            setState(() {
              _items[index] = _items[index].copyWith(isRead: true);
            });
          }
        }
      } catch (_) {
        // Navigation must remain available even if read-state sync fails.
      }
    }

    final orderId = _readString(item.data['orderId']);
    if (!mounted || orderId == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RestaurantOrderDetailsPage(orderId: orderId),
      ),
    );
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', '').trim(),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09111C),
        title: const Text('Уведомления'),
        actions: [
          TextButton(
            onPressed: _markingAll ? null : _markAllRead,
            child: Text(_markingAll ? '...' : 'Прочитать все'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF489F2A)),
      );
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _refresh,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFF489F2A),
        child: ListView(
          children: const [
            SizedBox(height: 180),
            Icon(Icons.notifications_none_rounded,
                color: Colors.white38, size: 48),
            SizedBox(height: 12),
            Center(
              child: Text(
                'Уведомлений пока нет',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF489F2A),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF489F2A),
                  strokeWidth: 2,
                ),
              ),
            );
          }

          final item = _items[index];
          return _NotificationCard(
            item: item,
            onTap: () => _openNotification(item),
          );
        },
      ),
    );
  }

  String? _readString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty || text.toLowerCase() == 'null'
        ? null
        : text;
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final RestaurantNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = item.createdAt?.toLocal();
    final dateText = date == null
        ? ''
        : DateFormat('dd.MM.yyyy HH:mm', 'ru_RU').format(date);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.isRead
                ? const Color(0xFF111827)
                : const Color(0xFF14251A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: item.isRead
                  ? const Color(0xFF243043)
                  : const Color(0xFF3D7D31),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0x2239A529),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_rounded,
                  color: Color(0xFF65C044),
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.isEmpty ? 'JETKIZ' : item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.body,
                        style: const TextStyle(
                          color: Color(0xFFB8C0CE),
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (dateText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        dateText,
                        style: const TextStyle(
                          color: Color(0xFF6F7D91),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!item.isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF65C044),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
