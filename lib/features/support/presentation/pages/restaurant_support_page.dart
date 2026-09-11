import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/localization/app_locale_controller.dart';
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
  static final Uri _jetkizSupportTelegram =
      Uri.parse('https://t.me/+Bp5uSFWWlBkyYjMy');

  final RestaurantNotificationsApi _notificationsApi =
      RestaurantNotificationsApi();
  late final RestaurantApi _restaurantApi = RestaurantApi(ApiClient.instance);

  RestaurantAppBootstrap? _bootstrap;
  int _unreadCount = 0;
  bool _loading = true;
  bool _requestingDeletion = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bootstrap = RestaurantAppCmsSession.instance.state.value;
        _loadFailed = true;
        _loading = false;
      });
    }
  }

  String? _localizedValue(String? ru, String? kk) {
    final primary = (context.isKazakh ? kk : ru)?.trim();
    if (primary != null && primary.isNotEmpty) return primary;
    final fallback = (context.isKazakh ? ru : kk)?.trim();
    return fallback == null || fallback.isEmpty ? null : fallback;
  }

  Future<void> _open(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Не удалось открыть ссылку', 'Сілтемені ашу мүмкін болмады'),
          ),
        ),
      );
    }
  }

  Future<void> _requestAccountDeletion() async {
    if (_requestingDeletion) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.tr(
            'Запросить удаление аккаунта?',
            'Аккаунтты жоюға өтініш беру керек пе?',
          ),
        ),
        content: Text(
          context.tr(
            'Аккаунт не будет удалён автоматически. JETKIZ получит заявку и свяжется с вами для проверки активных заказов и дальнейших действий.',
            'Аккаунт автоматты түрде жойылмайды. JETKIZ өтінішті қабылдап, белсенді тапсырыстарды тексеру және келесі қадамдар үшін сізбен байланысады.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('Отмена', 'Бас тарту')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('Отправить запрос', 'Өтініш жіберу')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _requestingDeletion = true);
    try {
      final response = await _restaurantApi.requestAccountDeletion();
      if (!mounted) return;

      final serverMessage = response['message']?.toString().trim() ?? '';
      final message = !context.isKazakh && serverMessage.isNotEmpty
          ? serverMessage
          : context.tr(
              'Запрос на удаление аккаунта отправлен',
              'Аккаунтты жою туралы өтініш жіберілді',
            );

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'Не удалось отправить запрос. Проверьте интернет и попробуйте ещё раз.',
                'Өтінішті жіберу мүмкін болмады. Интернетті тексеріп, қайта көріңіз.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _requestingDeletion = false);
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const RestaurantNotificationsPage(),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final support = _bootstrap?.support;
    final emergencyText = _localizedValue(
      support?.emergencyTextRu,
      support?.emergencyTextKk,
    );
    final workingHours = _localizedValue(
      support?.workingHoursRu,
      support?.workingHoursKk,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF09111C),
        title: Text(
          context.tr('Поддержка', 'Қолдау'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: AppLocaleController.instance.toggle,
            child: Text(
              context.isKazakh ? 'RU' : 'ҚАЗ',
              style: const TextStyle(
                color: Color(0xFF65C044),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
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
            if (_loadFailed)
              _MessageCard(
                icon: Icons.wifi_off_rounded,
                title: context.tr(
                  'Не удалось обновить информацию',
                  'Ақпаратты жаңарту мүмкін болмады',
                ),
                body: context.tr(
                  'Часть данных может быть устаревшей. Проверьте интернет и потяните экран вниз, чтобы повторить.',
                  'Кейбір деректер ескірген болуы мүмкін. Интернетті тексеріп, қайталау үшін экранды төмен тартыңыз.',
                ),
              ),
            if (emergencyText != null)
              _MessageCard(
                icon: Icons.campaign_rounded,
                title: context.tr('Важная информация', 'Маңызды ақпарат'),
                body: emergencyText,
              ),
            _SupportAction(
              icon: Icons.send_rounded,
              title: context.tr('Поддержка JETKIZ', 'JETKIZ қолдауы'),
              subtitle: context.tr(
                'Написать команде JETKIZ в Telegram',
                'JETKIZ командасына Telegram арқылы жазу',
              ),
              onTap: () => _open(_jetkizSupportTelegram),
            ),
            _SupportAction(
              icon: Icons.notifications_rounded,
              title: context.tr('Уведомления', 'Хабарландырулар'),
              subtitle: _unreadCount > 0
                  ? context.tr(
                      'Непрочитанных: $_unreadCount',
                      'Оқылмаған: $_unreadCount',
                    )
                  : context.tr('Все сообщения JETKIZ', 'JETKIZ хабарламалары'),
              onTap: _openNotifications,
            ),
            if (workingHours != null)
              _MessageCard(
                icon: Icons.schedule_rounded,
                title: context.tr(
                  'Время работы поддержки',
                  'Қолдау қызметінің жұмыс уақыты',
                ),
                body: workingHours,
              ),
            const SizedBox(height: 8),
            Text(
              context.tr('Документы и аккаунт', 'Құжаттар және аккаунт'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _SupportAction(
              icon: Icons.privacy_tip_outlined,
              title: context.tr(
                'Политика конфиденциальности',
                'Құпиялылық саясаты',
              ),
              subtitle: context.tr('Открыть документ', 'Құжатты ашу'),
              onTap: () => _open(Uri.parse('https://jetkiz.asia/privacy')),
            ),
            _SupportAction(
              icon: Icons.info_outline_rounded,
              title: context.tr(
                'Удаление аккаунта и данных',
                'Аккаунт пен деректерді жою',
              ),
              subtitle: context.tr(
                'Как проходит удаление аккаунта',
                'Аккаунтты жою тәртібі',
              ),
              onTap: () =>
                  _open(Uri.parse('https://jetkiz.asia/account-deletion')),
            ),
            _SupportAction(
              icon: Icons.delete_outline_rounded,
              title: context.tr(
                'Запросить удаление аккаунта',
                'Аккаунтты жоюға өтініш беру',
              ),
              subtitle: _requestingDeletion
                  ? context.tr('Отправляем запрос…', 'Өтініш жіберілуде…')
                  : context.tr(
                      'Отправить запрос команде JETKIZ',
                      'JETKIZ командасына өтініш жіберу',
                    ),
              enabled: !_requestingDeletion,
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
