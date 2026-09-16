import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/localization/app_locale_controller.dart';
import 'core/push/restaurant_push_notification_service.dart';
import 'core/testing/restaurant_auth_smoke.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppLocaleController.instance.load();

  final authSmoke = await runRestaurantAuthSmokeIfRequested();
  if (authSmoke != null) {
    runApp(_RestaurantAuthSmokeApp(result: authSmoke));
    return;
  }

  final firebaseReady = await _initializeFirebaseSafely();
  if (firebaseReady) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  runApp(const JetkizRestaurantApp());

  if (firebaseReady) {
    unawaited(_initializeFirebaseServicesSafely());
  }
}

class _RestaurantAuthSmokeApp extends StatelessWidget {
  const _RestaurantAuthSmokeApp({required this.result});

  final RestaurantAuthSmokeResult result;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            result.success
                ? 'JETKIZ_RESTAURANT_E2E_AUTH_OK'
                : 'JETKIZ_RESTAURANT_E2E_AUTH_FAILED',
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );
  }
}

Future<bool> _initializeFirebaseSafely() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    return true;
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('Firebase initialization failed: $error');
      debugPrint('$stackTrace');
    }
    return false;
  }
}

Future<void> _initializeFirebaseServicesSafely() async {
  try {
    await _configureCrashReporting();
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('Crashlytics bootstrap failed: $error');
      debugPrint('$stackTrace');
    }
  }

  try {
    await RestaurantPushNotificationService.instance.init();
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('Restaurant push bootstrap failed: $error');
      debugPrint('$stackTrace');
    }
  }
}

Future<void> _configureCrashReporting() async {
  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(kReleaseMode);

  FlutterError.onError = (details) {
    if (kDebugMode) FlutterError.presentError(details);
    crashlytics.recordFlutterFatalError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };
}
