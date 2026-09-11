import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/localization/app_locale_controller.dart';
import '../core/push/restaurant_push_notification_service.dart';
import '../features/auth/presentation/pages/restaurant_entry_page.dart';

class JetkizRestaurantApp extends StatelessWidget {
  const JetkizRestaurantApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeController = AppLocaleController.instance;

    return MaterialApp(
      navigatorKey: RestaurantPushNotificationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'JETKIZ Restaurant',
      // Keep the MaterialApp/Navigator identity stable. The active app locale is
      // overridden inside builder so changing RU/ҚАЗ never tears down routes,
      // dialogs, bottom sheets or focused text fields.
      locale: const Locale('ru'),
      supportedLocales: const [
        Locale('ru'),
        Locale('kk'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFF0B0B0C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF489F2A),
          secondary: Color(0xFF489F2A),
          surface: Color(0xFF151517),
        ),
      ),
      builder: (context, child) {
        return AnimatedBuilder(
          animation: localeController,
          child: child,
          builder: (context, stableNavigator) {
            return Localizations.override(
              context: context,
              locale: localeController.locale,
              child: stableNavigator ?? const SizedBox.shrink(),
            );
          },
        );
      },
      home: const RestaurantEntryPage(),
    );
  }
}
