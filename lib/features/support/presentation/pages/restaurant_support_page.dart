import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/features/cms/data/restaurant_app_cms_session.dart';
import 'package:jetkiz_restaurant/features/cms/domain/restaurant_app_bootstrap.dart';
import 'package:jetkiz_restaurant/features/notifications/data/restaurant_notifications_api.dart';
import 'package:jetkiz_restaurant/features/notifications/presentation/pages/restaurant_notifications_page.dart';
import 'package:url_launcher/url_launcher.dart';

class RestaurantSupportPage extends StatefulWidget {
  const RestaurantSupportPage({super.key});

  @override
  State<RestaurantSupportPage> createState() => _RestaurantSupportPageState();
}

class _RestaurantSupportPageState extends State<RestaurantSupportPage> {
  final RestaurantNotificationsApi _notificationsApi =
      RestaurantNotificationsApi();

  RestaurantAppBootstrap? _bootstrap;
  int _unreadCount = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        RestaurantAppCmsSession.instance.refresh(),
        _notificationsApi.getUnreadCount(),
      ]);

      if (!mounted) return;
      setState(() {
        _bootstrap = results[0] as RestaurantAppBootstrap;
        _unreadCount = results[1] as int;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _bootstrap = RestaurantAppCmsSession.instance.state.value;
        _error = error.toString().replaceFirst('Exception: ', '').trim();
        _loading = false;
      });
    }
  }

  Future<void> _open(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку')),
      );
    }
  }

  Future<void> _openRawUrl(String? value) async {
    final url = value?.trim() ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Контакт поддержки пока недоступен')),
        );
      }
      return;
    }
    await _open(uri);
  }

  Future<void> _call(String? phone) async {
    final normalized = phone?.replaceAll(RegExp(r'[^0-9+]'), '') ?? '';
    if (normalized.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Телефон поддержки пока не указан')),
        );
      }
      return;
    }
    await _open(Uri(scheme: 'tel', path: normalized));
  }

  Future<void> _requestAccountDeletion() async {
    final support = _bootstrap?.support;
    final whatsapp = support?.whatsappUrl?.trim() ?? '';

    if (whatsapp.isNotEmpty) {
      final uri = Uri.tryParse(whatsapp);
      if (uri != null && uri.hasScheme) {
        await _open(uri);
        return;
      }
    }

    await _call(support?.phone);
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RestaurantNotificationsPage()),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final support = _bootstrap?.support;

    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF09111C),
        title: const Text(
          'Поддержка',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF489F2A),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: LinearProgressIndicator(color: Color(0xFF489F2A)),
              ),
            if (_error != null)
              _MessageCard(
                icon: Icons.cloud_off_rounded,
                title: 'Не удалось обновить контакты',
                body: _error!,
              ),
            if ((support?.emergencyTextRu ?? '').trim().isNotEmpty)
              _MessageCard(
                icon: Icons.campaign_rounded,
                title: 'Важная информация',
                body: support!.emergencyTextRu!.trim(),
              ),
            _SupportAction(
              icon: Icons.notifications_rounded,
              title: 'Уведомления',
              subtitle: _unreadCount > 0
                  ? 'Непрочитанных: $_unreadCount'
                  : 'Все сообщения JETKIZ',
              onTap: _openNotifications,
            ),
            _SupportAction(
              icon: Icons.chat_rounded,
              title: 'WhatsApp',
              subtitle: 'Написать в поддержку',
              enabled: (support?.whatsappUrl ?? '').trim().isNotEmpty,
              onTap: () => _openRawUrl(support?.whatsappUrl),
            ),
            _SupportAction(
              icon: Icons.send_rounded,
              title: 'Telegram',
              subtitle: 'Открыть поддержку в Telegram',
              enabled: (support?.telegramUrl ?? '').trim().isNotEmpty,
              onTap: () => _openRawUrl(support?.telegramUrl),
            ),
            _SupportAction(
              icon: Icons.phone_rounded,
              title: 'Позвонить',
              subtitle: support?.phone?.trim().isNotEmpty == true
                  ? support!.phone!.trim()
                  : 'Телефон пока не указан',
              enabled: support?.phone?.trim().isNotEmpty == true,
              onTap: () => _call(support?.phone),
            ),
            if ((support?.workingHoursRu ?? '').trim().isNotEmpty)
              _MessageCard(
                icon: Icons.schedule_rounded,
                title: 'Время работы поддержки',
                body: support!.workingHoursRu!.trim(),
              ),
            const SizedBox(height: 8),
            const Text(
              'Документы и аккаунт',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _SupportAction(
              icon: Icons.privacy_tip_outlined,
              title: 'Политика конфиденциальности',
              subtitle: 'Открыть jetkiz.asia/privacy',
              onTap: () => _open(Uri.parse('https://jetkiz.asia/privacy')),
            ),
            _SupportAction(
              icon: Icons.delete_outline_rounded,
              title: 'Удаление аккаунта',
              subtitle: 'Отправить запрос в поддержку JETKIZ',
              onTap: _requestAccountDeletion,
            ),
            const SizedBox(height: 18),
            const Center(
              child: Text(
                'JETKIZ Restaurant · 1.0.0',
                style: TextStyle(color: Color(0xFF6F7D91), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportAction extends StatelessWidget {
  const _SupportAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF243043)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0x2239A529),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: enabled
                        ? const Color(0xFF65C044)
                        : const Color(0xFF526070),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: enabled ? Colors.white : Colors.white38,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: enabled
                              ? const Color(0xFF9EABBE)
                              : const Color(0xFF526070),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: enabled ? Colors.white38 : Colors.transparent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF172033),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A3850)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF65C044)),
          const SizedBox(width: 12),
          Expanded(
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
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFFB7C0CE),
                    height: 1.4,
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
