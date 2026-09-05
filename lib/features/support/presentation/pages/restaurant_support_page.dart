import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/config/app_build_info.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/cms/data/restaurant_app_cms_session.dart';
import 'package:jetkiz_restaurant/features/cms/domain/restaurant_app_bootstrap.dart';
import 'package:jetkiz_restaurant/features/notifications/data/restaurant_notifications_api.dart';
import 'package:jetkiz_restaurant/features/notifications/presentation/pages/restaurant_notifications_page.dart';
import 'package:jetkiz_restaurant/features/restaurant/data/restaurant_api.dart';
import 'package:url_launcher/url_launcher.dart';

class RestaurantSupportPage extends StatefulWidget {
  const RestaurantSupportPage({super.key});

  @override
  State<RestaurantSupportPage> createState() => _RestaurantSupportPageState();
}

class _RestaurantSupportPageState extends State<RestaurantSupportPage> {
  static const String _fallbackPhone = '+7 708 681 06 93';
  static const String _fallbackWhatsapp = 'https://wa.me/77086810693';
  static const String _fallbackTelegram = 'https://t.me/+Bp5uSFWWlBkyYjMy';

  static const Set<String> _telegramHosts = <String>{
    't.me',
    'telegram.me',
  };
  static const Set<String> _whatsappHosts = <String>{
    'wa.me',
    'api.whatsapp.com',
    'whatsapp.com',
    'www.whatsapp.com',
  };

  final RestaurantNotificationsApi _notificationsApi =
      RestaurantNotificationsApi();
  late final RestaurantApi _restaurantApi = RestaurantApi(ApiClient.instance);

  RestaurantAppBootstrap? _bootstrap;
  int _unreadCount = 0;
  bool _loading = true;
  bool _requestingDeletion = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    var bootstrap = RestaurantAppCmsSession.instance.state.value;
    var unreadCount = _unreadCount;

    try {
      bootstrap = await RestaurantAppCmsSession.instance.refresh();
    } catch (_) {
      // Support actions have verified production fallbacks, so a temporary CMS
      // refresh failure must not make the support screen look broken.
    }

    try {
      unreadCount = await _notificationsApi.getUnreadCount();
    } catch (_) {
      // Notifications are auxiliary on this screen; keep the last known count.
    }

    if (!mounted) return;
    setState(() {
      _bootstrap = bootstrap;
      _unreadCount = unreadCount;
      _loading = false;
    });
  }

  Future<void> _open(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку')),
      );
    }
  }

  Uri? _validatedHttpsUrl(String? value, Set<String> allowedHosts) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;

    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.host.trim().isEmpty) {
      return null;
    }

    final host = uri.host.toLowerCase();
    if (!allowedHosts.contains(host)) return null;

    return uri;
  }

  String? _normalizedPhone(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;

    final hasPlus = raw.startsWith('+');
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 15) return null;

    return '${hasPlus ? '+' : ''}$digits';
  }

  Future<void> _callSupport(String value) async {
    final phone = _normalizedPhone(value);
    if (phone == null) return;
    await _open(Uri(scheme: 'tel', path: phone));
  }

  Future<void> _requestAccountDeletion() async {
    if (_requestingDeletion) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Запросить удаление аккаунта?'),
        content: const Text(
          'Аккаунт не будет удалён автоматически. JETKIZ получит заявку и свяжется с вами для проверки активных заказов и дальнейших действий.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Отправить запрос'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _requestingDeletion = true;
    });

    try {
      final response = await _restaurantApi.requestAccountDeletion();
      if (!mounted) return;

      final message = response['message']?.toString().trim().isNotEmpty == true
          ? response['message'].toString().trim()
          : 'Запрос на удаление аккаунта отправлен';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst('Exception: ', '').trim(),
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _requestingDeletion = false;
        });
      }
    }
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
    final phone = _normalizedPhone(support?.phone) ?? _fallbackPhone;
    final whatsapp =
        _validatedHttpsUrl(support?.whatsappUrl, _whatsappHosts) ??
        Uri.parse(_fallbackWhatsapp);
    final telegram =
        _validatedHttpsUrl(support?.telegramUrl, _telegramHosts) ??
        Uri.parse(_fallbackTelegram);

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
            if ((support?.emergencyTextRu ?? '').trim().isNotEmpty)
              _MessageCard(
                icon: Icons.campaign_rounded,
                title: 'Важная информация',
                body: support!.emergencyTextRu!.trim(),
              ),
            _SupportAction(
              icon: Icons.phone_rounded,
              title: 'Позвонить в JETKIZ',
              subtitle: phone,
              onTap: () => _callSupport(phone),
            ),
            _SupportAction(
              icon: Icons.chat_rounded,
              title: 'WhatsApp JETKIZ',
              subtitle: 'Открыть чат поддержки в WhatsApp',
              onTap: () => _open(whatsapp),
            ),
            _SupportAction(
              icon: Icons.send_rounded,
              title: 'Telegram JETKIZ',
              subtitle: 'Открыть канал JETKIZ в Telegram',
              onTap: () => _open(telegram),
            ),
            _SupportAction(
              icon: Icons.notifications_rounded,
              title: 'Уведомления',
              subtitle: _unreadCount > 0
                  ? 'Непрочитанных: $_unreadCount'
                  : 'Все сообщения JETKIZ',
              onTap: _openNotifications,
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
              onTap: () => _open(Uri.parse('https://jetkiz.asia/privacy')),
            ),
            _SupportAction(
              icon: Icons.delete_outline_rounded,
              title: 'Запросить удаление аккаунта',
              subtitle: _requestingDeletion
                  ? 'Отправляем запрос…'
                  : 'Отправить официальный запрос в JETKIZ',
              enabled: !_requestingDeletion,
              onTap: _requestAccountDeletion,
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                'JETKIZ Restaurant · ${AppBuildInfo.fullVersion}',
                style: const TextStyle(
                  color: Color(0xFF6F7D91),
                  fontSize: 12,
                ),
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
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final resolvedSubtitle = subtitle?.trim() ?? '';

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
                      if (resolvedSubtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          resolvedSubtitle,
                          style: TextStyle(
                            color: enabled
                                ? const Color(0xFF9EABBE)
                                : const Color(0xFF526070),
                            fontSize: 12,
                          ),
                        ),
                      ],
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
                  style: const TextStyle(color: Color(0xFFB7C0CE), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
