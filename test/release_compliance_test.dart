import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jetkiz_restaurant/features/auth/presentation/pages/restaurant_auth_page.dart';
import 'package:jetkiz_restaurant/features/auth/presentation/pages/restaurant_sms_page.dart';

void main() {
  testWidgets('restaurant registration exposes privacy consent controls', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RestaurantAuthPage()));

    await tester.tap(find.text('Регистрация'));
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('Политика конфиденциальности'), findsOneWidget);
    expect(find.text('Согласие на обработку данных'), findsOneWidget);
  });

  testWidgets('OTP screen uses channel-neutral confirmation copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RestaurantSmsPage(phone: '+7 700 000 00 00', isNewUser: false),
      ),
    );

    expect(find.textContaining('Введите код подтверждения'), findsOneWidget);
    expect(find.textContaining('SMS'), findsNothing);
  });
  test('restaurant exposes in-app account deletion request flow', () {
    final profileSource = File(
      'lib/features/restaurant_profile/presentation/pages/restaurant_profile_page.dart',
    ).readAsStringSync();
    final supportSource = File(
      'lib/features/support/presentation/pages/restaurant_support_page.dart',
    ).readAsStringSync();
    final apiSource = File(
      'lib/features/restaurant/data/restaurant_api.dart',
    ).readAsStringSync();

    expect(profileSource, contains("RestaurantSupportPage"));
    expect(profileSource, contains("'Удалить аккаунт'"));
    expect(supportSource, contains('_requestAccountDeletion'));
    expect(supportSource, contains('Запросить удаление аккаунта'));
    expect(apiSource, contains('/restaurants/me/deletion-request'));
  });

}
