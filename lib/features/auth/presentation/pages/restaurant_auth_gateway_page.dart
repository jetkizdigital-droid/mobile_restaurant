import 'package:flutter/material.dart';

import 'restaurant_auth_page.dart';
import 'restaurant_password_login_page.dart';

class RestaurantAuthGatewayPage extends StatelessWidget {
  const RestaurantAuthGatewayPage({super.key});

  Future<void> _openPasswordLogin(BuildContext context) async {
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RestaurantPasswordLoginPage(
          languageCode: locale == 'kk' ? 'kk' : 'ru',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKk =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'kk';

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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
