import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/widgets/jetkiz_wordmark.dart';
import 'package:jetkiz_restaurant/core/localization/app_locale_controller.dart';
import 'package:jetkiz_restaurant/core/navigation/app_page_route.dart';

import 'restaurant_auth_page.dart';
import 'restaurant_staff_password_page.dart';

class RestaurantAccessChoicePage extends StatelessWidget {
  const RestaurantAccessChoicePage({super.key});

  void _openOwnerFlow(BuildContext context) {
    Navigator.of(context).push(
      AppPageRoute<void>(page: const RestaurantAuthPage()),
    );
  }

  void _openStaffFlow(BuildContext context) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        page: RestaurantStaffPasswordPage(
          initialLanguageCode: AppLocaleController.instance.languageCode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocaleController.instance;

    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: locale.toggle,
                      child: Text(
                        context.isKazakh ? 'RU' : 'ҚАЗ',
                        style: const TextStyle(
                          color: Color(0xFF65C044),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: 110,
                    height: 66,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF26374F)),
                    ),
                    alignment: Alignment.center,
                    child: const JetkizWordmark(height: 34),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Jetkiz Ресторан',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      'Выберите способ входа в кабинет ресторана.',
                      'Мейрамхана кабинетіне кіру тәсілін таңдаңыз.',
                    ),
                    style: const TextStyle(
                      color: Color(0xFF95A0B3),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _AccessCard(
                    icon: Icons.storefront_outlined,
                    title: context.tr('Владелец ресторана', 'Мейрамхана иесі'),
                    description: context.tr(
                      'Вход по номеру телефона и коду подтверждения. Здесь же регистрация ресторана.',
                      'Телефон нөмірі және растау коды арқылы кіру. Мейрамхананы тіркеу де осында.',
                    ),
                    buttonText: context.tr(
                      'Войти или зарегистрироваться',
                      'Кіру немесе тіркелу',
                    ),
                    onPressed: () => _openOwnerFlow(context),
                  ),
                  const SizedBox(height: 14),
                  _AccessCard(
                    icon: Icons.badge_outlined,
                    title: context.tr('Сотрудник', 'Қызметкер'),
                    description: context.tr(
                      'Вход по телефону и паролю, который выдал владелец ресторана.',
                      'Мейрамхана иесі берген телефон мен құпиясөз арқылы кіру.',
                    ),
                    buttonText: context.tr(
                      'Войти как сотрудник',
                      'Қызметкер ретінде кіру',
                    ),
                    onPressed: () => _openStaffFlow(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111B2B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF26374F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF65C044), size: 32),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            style: const TextStyle(color: Color(0xFF95A0B3), height: 1.4),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF65C044),
                foregroundColor: const Color(0xFF061004),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                buttonText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
