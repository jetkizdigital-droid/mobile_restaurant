import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/push/restaurant_push_notification_service.dart';
import '../features/auth/presentation/pages/restaurant_entry_page.dart';

class JetkizRestaurantApp extends StatelessWidget {
  const JetkizRestaurantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: RestaurantPushNotificationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'JETKIZ Ресторан',
      supportedLocales: const [
        Locale('ru'),
        Locale('kk'),
      ],
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        // Product rule: Russian is the default language. Only a Kazakh device
        // locale switches the first launch to Kazakh; every other locale falls
        // back to Russian.
        if (deviceLocale?.languageCode.toLowerCase() == 'kk') {
          return const Locale('kk');
        }
        return const Locale('ru');
      },
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
      home: const RestaurantEntryPage(),
    );
  }
}
