import 'package:flutter/material.dart';

import 'restaurant_auth_page.dart';
import 'restaurant_password_login_page.dart';

class RestaurantAuthGatewayPage extends StatelessWidget {
  const RestaurantAuthGatewayPage({super.key});

  String? _normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) digits = '7$digits';
    if (digits.length == 11 && digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    }
    if (digits.length != 11 || !digits.startsWith('7')) return null;
    return '+$digits';
  }

  Future<void> _openPasswordLogin(BuildContext context) async {
    final controller = TextEditingController();
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();
    final isKk = locale == 'kk';

    final phone = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isKk ? 'Құпиясөзбен кіру' : 'Вход по паролю'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Телефон',
            hintText: '+7 700 000 00 00',
          ),
          onSubmitted: (_) {
            final normalized = _normalizePhone(controller.text);
            if (normalized != null) Navigator.of(dialogContext).pop(normalized);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(isKk ? 'Бас тарту' : 'Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final normalized = _normalizePhone(controller.text);
              if (normalized == null) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        isKk
                            ? 'Телефон нөмірін дұрыс енгізіңіз'
                            : 'Введите корректный номер телефона',
                      ),
                    ),
                  );
                return;
              }
              Navigator.of(dialogContext).pop(normalized);
            },
            child: Text(isKk ? 'Жалғастыру' : 'Продолжить'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (phone == null || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RestaurantPasswordLoginPage(
          phone: phone,
          languageCode: isKk ? 'kk' : 'ru',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKk = Localizations.localeOf(context).languageCode.toLowerCase() == 'kk';

    return Stack(
      fit: StackFit.expand,
      children: [
        const RestaurantAuthPage(),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 0, 0),
              child: Material(
                color: const Color(0xFF121B2C),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  key: const ValueKey('restaurant_password_login_direct'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _openPasswordLogin(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 17,
                          color: Color(0xFF8FD56F),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          isKk ? 'Құпиясөзбен кіру' : 'Вход по паролю',
                          style: const TextStyle(
                            color: Color(0xFF8FD56F),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
