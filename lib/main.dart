import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/push/restaurant_push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseReady = await _initializeFirebaseSafely();

  if (firebaseReady) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await RestaurantPushNotificationService.instance.init();
  }

  runApp(const JetkizRestaurantApp());
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
