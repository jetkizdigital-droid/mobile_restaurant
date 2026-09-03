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
}
