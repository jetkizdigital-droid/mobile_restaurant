from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'Expected block not found in {path}')
    if text.count(old) != 1:
        raise SystemExit(f'Expected one block in {path}, found {text.count(old)}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


Path('lib/core/config/app_build_info.dart').write_text(
    """/// Release metadata shared by CMS, push registration and diagnostics.
///
/// Keep this in sync with pubspec.yaml. CI verifies the contract on every
/// release build so a version bump cannot silently drift.
abstract final class AppBuildInfo {
  static const String versionName = '1.0.0';
  static const String buildNumber = '1';
  static const String fullVersion = '$versionName+$buildNumber';
}
""",
    encoding='utf-8',
)

Path('tool/verify_restaurant_release_contract.py').write_text(
    """#!/usr/bin/env python3
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
pubspec = (root / 'pubspec.yaml').read_text(encoding='utf-8')
match = re.search(r'^version:\\s*([^+\\s]+)\\+(\\d+)\\s*$', pubspec, re.M)
if not match:
    raise SystemExit('pubspec version must use versionName+buildNumber')
version_name, build_number = match.groups()

build_info = (root / 'lib/core/config/app_build_info.dart').read_text(encoding='utf-8')
if f"versionName = '{version_name}'" not in build_info:
    raise SystemExit('AppBuildInfo.versionName is out of sync with pubspec.yaml')
if f"buildNumber = '{build_number}'" not in build_info:
    raise SystemExit('AppBuildInfo.buildNumber is out of sync with pubspec.yaml')

gradle = (root / 'android/app/build.gradle.kts').read_text(encoding='utf-8')
app_id_match = re.search(r'applicationId\\s*=\\s*"([^"]+)"', gradle)
if not app_id_match:
    raise SystemExit('Android applicationId not found')
application_id = app_id_match.group(1)

google = json.loads((root / 'android/app/google-services.json').read_text(encoding='utf-8'))
if google.get('project_info', {}).get('project_id') != 'jetkiz-mobile':
    raise SystemExit('google-services.json must use Firebase project jetkiz-mobile')
packages = {
    item.get('client_info', {}).get('android_client_info', {}).get('package_name')
    for item in google.get('client', [])
}
if application_id not in packages:
    raise SystemExit(
        f'Firebase Android package mismatch: applicationId={application_id}, clients={sorted(packages)}'
    )

manifest = (root / 'android/app/src/main/AndroidManifest.xml').read_text(encoding='utf-8')
if 'android.permission.POST_NOTIFICATIONS' not in manifest:
    raise SystemExit('POST_NOTIFICATIONS permission is required')
if 'restaurant_new_orders_v2' not in manifest:
    raise SystemExit('Restaurant new-order default channel is missing')

push = (root / 'lib/core/push/restaurant_push_notification_service.dart').read_text(encoding='utf-8')
for required in (
    "'app': 'restaurant'",
    'jetkiz_default_channel',
    'restaurant_new_orders_v2',
    'ADMIN_CAMPAIGN',
    'AppBuildInfo.fullVersion',
):
    if required not in push:
        raise SystemExit(f'Push release contract missing: {required}')
if "'appVersion': '1.0.0'" in push:
    raise SystemExit('Push appVersion must not be hardcoded')

cms = (root / 'lib/features/cms/data/restaurant_app_cms_api.dart').read_text(encoding='utf-8')
if "'appVersion': '1.0.0'" in cms or 'appVersion=1.0.0' in cms:
    raise SystemExit('CMS appVersion must not be hardcoded')
if 'AppBuildInfo.versionName' not in cms:
    raise SystemExit('CMS must use AppBuildInfo.versionName')

print(f'Restaurant release contract PASS: {application_id} {version_name}+{build_number}')
""",
    encoding='utf-8',
)

cms = 'lib/features/cms/data/restaurant_app_cms_api.dart'
replace_once(
    cms,
    """import 'package:flutter/foundation.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
""",
    """import 'package:flutter/foundation.dart';
import 'package:jetkiz_restaurant/core/config/app_build_info.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
""",
)
replace_once(cms, """        'appVersion': '1.0.0',
""", """        'appVersion': AppBuildInfo.versionName,
""")

Path('lib/main.dart').write_text(
    """import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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
  }

  // UI availability is more important than observability or push bootstrap.
  // Neither Crashlytics nor FCM is allowed to hold the restaurant app startup.
  runApp(const JetkizRestaurantApp());

  if (firebaseReady) {
    unawaited(_initializeFirebaseServicesSafely());
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
""",
    encoding='utf-8',
)

push = 'lib/core/push/restaurant_push_notification_service.dart'
replace_once(
    push,
    """import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_storage.dart';
import 'package:jetkiz_restaurant/features/orders/presentation/pages/restaurant_order_details_page.dart';
""",
    """import 'package:jetkiz_restaurant/core/config/app_build_info.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_storage.dart';
import 'package:jetkiz_restaurant/features/finance/presentation/pages/restaurant_finance_page.dart';
import 'package:jetkiz_restaurant/features/menu/presentation/pages/restaurant_menu_page.dart';
import 'package:jetkiz_restaurant/features/notifications/presentation/pages/restaurant_notifications_page.dart';
import 'package:jetkiz_restaurant/features/orders/presentation/pages/restaurant_order_details_page.dart';
import 'package:jetkiz_restaurant/features/orders/presentation/pages/restaurant_orders_page.dart';
import 'package:jetkiz_restaurant/features/restaurant_profile/presentation/pages/restaurant_profile_page.dart';
import 'package:jetkiz_restaurant/features/reviews/presentation/pages/restaurant_reviews_page.dart';
""",
)
replace_once(
    push,
    """const String _restaurantNewOrderType = 'RESTAURANT_NEW_ORDER';
const String _androidNewOrderChannelId = 'restaurant_new_orders_v2';
""",
    """const String _restaurantNewOrderType = 'RESTAURANT_NEW_ORDER';
const String _adminCampaignType = 'ADMIN_CAMPAIGN';
const String _androidGeneralChannelId = 'jetkiz_default_channel';
const String _androidGeneralChannelName = 'JETKIZ';
const String _androidGeneralChannelDescription =
    'Обычные уведомления JETKIZ для ресторана';
const String _androidNewOrderChannelId = 'restaurant_new_orders_v2';
""",
)
replace_once(
    push,
    """  Future<void> registerCurrentToken() async {
    final accessToken = await _authStorage.getAccessToken();

    if (accessToken == null || accessToken.trim().isEmpty) {
      if (kDebugMode) {
        debugPrint('RestaurantPush: skip token registration, no access token');
      }

      return;
    }

    await _requestPermission();

    final token = await getToken();

    if (token == null || token.trim().isEmpty) {
      if (kDebugMode) {
        debugPrint('RestaurantPush: FCM token is empty');
      }

      return;
    }

    await _sendTokenToBackend(token);
  }
""",
    """  Future<void> registerCurrentToken({
    bool requestPermissionIfNeeded = true,
  }) async {
    final accessToken = await _authStorage.getAccessToken();

    if (accessToken == null || accessToken.trim().isEmpty) {
      if (kDebugMode) {
        debugPrint('RestaurantPush: skip token registration, no access token');
      }
      return;
    }

    final permissionGranted = await _ensureNotificationPermission(
      requestIfNeeded: requestPermissionIfNeeded,
    );
    if (!permissionGranted) {
      if (kDebugMode) {
        debugPrint('RestaurantPush: notifications are not permitted');
      }
      await _unregisterCurrentTokenBestEffort();
      return;
    }

    final token = await getToken();
    if (token == null || token.trim().isEmpty) {
      if (kDebugMode) debugPrint('RestaurantPush: FCM token is empty');
      return;
    }

    await _sendTokenToBackend(token);
  }
""",
)
replace_once(
    push,
    """    await _apiClient.post('/notification-devices/unregister', <String, dynamic>{
      'token': token.trim(),
      'deviceId': deviceId,
    });
""",
    """    await _apiClient.post('/notification-devices/unregister', <String, dynamic>{
      'token': token.trim(),
      'deviceId': deviceId,
      'app': 'restaurant',
    });
""",
)
replace_once(
    push,
    """  Future<void> _requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        debugPrint(
          'RestaurantPush: permission=${settings.authorizationStatus}',
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('RestaurantPush: permission failed: $error');
      }
    }
  }
""",
    """  Future<bool> _ensureNotificationPermission({
    required bool requestIfNeeded,
  }) async {
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final enabled = await androidPlugin?.areNotificationsEnabled();
        if (enabled == true) return true;
        if (!requestIfNeeded) return false;
        final requested = await androidPlugin?.requestNotificationsPermission();
        final afterRequest = await androidPlugin?.areNotificationsEnabled();
        return afterRequest ?? requested ?? false;
      }

      final current = await _messaging.getNotificationSettings();
      if (_isAuthorized(current.authorizationStatus)) return true;
      if (current.authorizationStatus == AuthorizationStatus.denied) {
        return false;
      }
      if (!requestIfNeeded) return false;

      final requested = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      return _isAuthorized(requested.authorizationStatus);
    } catch (error) {
      if (kDebugMode) debugPrint('RestaurantPush: permission failed: $error');
      return false;
    }
  }

  bool _isAuthorized(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  Future<void> _unregisterCurrentTokenBestEffort() async {
    try {
      await unregisterCurrentToken();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('RestaurantPush: stale token cleanup failed: $error');
      }
    }
  }
""",
)
replace_once(
    push,
    """    await androidPlugin?.createNotificationChannel(_androidNewOrderChannel);

    await _messaging.setForegroundNotificationPresentationOptions(
""",
    """    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidGeneralChannelId,
        _androidGeneralChannelName,
        description: _androidGeneralChannelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await androidPlugin?.createNotificationChannel(_androidNewOrderChannel);

    await _messaging.setForegroundNotificationPresentationOptions(
""",
)
replace_once(
    push,
    """    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      unawaited(_showForegroundNewOrderNotification(message));
    });
""",
    """    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      unawaited(_handleForegroundMessage(message));
    });
""",
)
replace_once(
    push,
    """        'deviceId': deviceId,
        'appVersion': '1.0.0',
      });
""",
    """        'deviceId': deviceId,
        'app': 'restaurant',
        'appVersion': AppBuildInfo.fullVersion,
      });
""",
)

p = Path(push)
text = p.read_text(encoding='utf-8')
marker = """  Future<void> _showForegroundNewOrderNotification(
"""
insert = """  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (_isRestaurantNewOrder(message.data)) {
      await _showForegroundNewOrderNotification(message);
      return;
    }
    if (_isRestaurantAdminCampaign(message.data)) {
      await _showForegroundAdminCampaignNotification(message);
    }
  }

  Future<void> _showForegroundAdminCampaignNotification(
    RemoteMessage message,
  ) async {
    if (!_markMessageHandled(message)) return;

    final title =
        _readString(message.notification?.title) ??
        _readString(message.data['title']) ??
        'JETKIZ';
    final body =
        _readString(message.notification?.body) ??
        _readString(message.data['body']) ??
        'Новое уведомление';
    final stableKey =
        _readString(message.data['notificationId']) ??
        _readString(message.data['campaignId']) ??
        message.messageId ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final payload = _notificationPayloadFromData(message.data);

    await _localNotifications.show(
      id: _stableNotificationId(stableKey),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidGeneralChannelId,
          _androidGeneralChannelName,
          channelDescription: _androidGeneralChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(payload),
    );
  }

"""
if marker not in text:
    raise SystemExit('Foreground marker not found')
p.write_text(text.replace(marker, insert + marker, 1), encoding='utf-8')

replace_once(
    push,
    """  Future<void> _handleNotificationOpen(
    RemoteMessage message, {
    required String source,
  }) async {
    if (!_isRestaurantNewOrder(message.data)) {
      return;
    }
""",
    """  Future<void> _handleNotificationOpen(
    RemoteMessage message, {
    required String source,
  }) async {
    if (_isRestaurantAdminCampaign(message.data)) {
      await markAppOpened();
      final payload = _notificationPayloadFromData(message.data);
      await _trackAdminCampaignOpen(payload, source: source);
      _queueOpenPayload(payload);
      return;
    }

    if (!_isRestaurantNewOrder(message.data)) return;
""",
)
replace_once(
    push,
    """      if (!_isRestaurantNewOrder(data)) {
        return;
      }

      final orderId = _readString(data['orderId']);
""",
    """      if (_isRestaurantAdminCampaign(data)) {
        final payload = _notificationPayloadFromData(data);
        await _trackAdminCampaignOpen(payload, source: source);
        _queueOpenPayload(payload);
        return;
      }

      if (!_isRestaurantNewOrder(data)) return;

      final orderId = _readString(data['orderId']);
""",
)
replace_once(
    push,
    """    final payload = _pendingOpenPayloads.removeAt(0);
    final orderId = _readString(payload['orderId']);

    if (orderId == null) {
      return;
    }

    final payloadRestaurantId = _readString(payload['restaurantId']);
    if (payloadRestaurantId != null &&
        payloadRestaurantId != selectedRestaurantId) {
      await _apiClient.setSelectedRestaurantId(payloadRestaurantId);
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => RestaurantOrderDetailsPage(orderId: orderId),
      ),
    );

    if (_pendingOpenPayloads.isNotEmpty) {
      _scheduleNavigationFlush();
    }
""",
    """    final payload = _pendingOpenPayloads.removeAt(0);
    final payloadRestaurantId = _readString(payload['restaurantId']);
    if (payloadRestaurantId != null &&
        payloadRestaurantId != selectedRestaurantId) {
      await _apiClient.setSelectedRestaurantId(payloadRestaurantId);
    }

    if (_readString(payload['type'])?.toUpperCase() == _adminCampaignType) {
      await _openAdminCampaignPayload(
        navigator,
        payload,
        payloadRestaurantId ?? selectedRestaurantId,
      );
    } else {
      final orderId = _readString(payload['orderId']);
      if (orderId != null) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => RestaurantOrderDetailsPage(orderId: orderId),
          ),
        );
      }
    }

    if (_pendingOpenPayloads.isNotEmpty) _scheduleNavigationFlush();
""",
)

p = Path(push)
text = p.read_text(encoding='utf-8')
marker = """  Future<void> _trackNotificationOpen({
"""
helpers = """  Future<void> _openAdminCampaignPayload(
    NavigatorState navigator,
    Map<String, String> payload,
    String restaurantId,
  ) async {
    final screen = (_readString(payload['screen']) ?? 'notifications')
        .toLowerCase();
    final orderId = _readString(payload['orderId']);

    Widget page;
    switch (screen) {
      case 'order':
      case 'order_details':
      case 'active_order':
        page = orderId == null
            ? const RestaurantOrdersPage(hideBottomBar: true)
            : RestaurantOrderDetailsPage(orderId: orderId);
        break;
      case 'home':
      case 'orders':
      case 'available_orders':
        page = const RestaurantOrdersPage(hideBottomBar: true);
        break;
      case 'menu':
        page = const RestaurantMenuPage();
        break;
      case 'finance':
      case 'balance':
        page = const RestaurantFinancePage();
        break;
      case 'profile':
        page = const RestaurantProfilePage(hideBottomBar: true);
        break;
      case 'reviews':
        page = RestaurantReviewsPage(restaurantId: restaurantId);
        break;
      case 'notifications':
      default:
        page = const RestaurantNotificationsPage();
        break;
    }

    navigator.push(MaterialPageRoute(builder: (_) => page));
  }

  bool _isRestaurantAdminCampaign(Map<String, dynamic> data) {
    final type = _readString(data['type'])?.toUpperCase();
    if (type != _adminCampaignType) return false;
    final app = _readString(data['app'])?.toLowerCase();
    return app == null || app == 'restaurant';
  }

  Map<String, String> _notificationPayloadFromData(
    Map<String, dynamic> data,
  ) {
    final payload = <String, String>{'type': _adminCampaignType};
    for (final key in <String>[
      'app',
      'screen',
      'orderId',
      'restaurantId',
      'campaignId',
      'notificationId',
      'route',
      'action',
    ]) {
      final value = _readString(data[key]);
      if (value != null) payload[key] = value;
    }
    payload['app'] = 'restaurant';
    return payload;
  }

  Future<void> _trackAdminCampaignOpen(
    Map<String, String> payload, {
    required String source,
  }) async {
    try {
      final accessToken = await _authStorage.getAccessToken();
      if (accessToken == null || accessToken.trim().isEmpty) return;
      final entityId =
          _readString(payload['campaignId']) ??
          _readString(payload['notificationId']) ??
          'restaurant-notification';
      await _apiClient.post('/client-events', {
        'eventName': 'notification_open',
        'entityType': 'notification_campaign',
        'entityId': entityId,
        'metadata': {
          'source': source,
          'app': 'RESTAURANT',
          if (_readString(payload['screen']) != null)
            'screen': _readString(payload['screen']),
          if (_readString(payload['notificationId']) != null)
            'notificationId': _readString(payload['notificationId']),
        },
      });
    } catch (error) {
      if (kDebugMode) {
        debugPrint('RestaurantPush: admin notification_open failed: $error');
      }
    }
  }

"""
if marker not in text:
    raise SystemExit('Track marker not found')
p.write_text(text.replace(marker, helpers + marker, 1), encoding='utf-8')

shell = 'lib/features/navigation/presentation/pages/restaurant_shell_page.dart'
replace_once(
    shell,
    """    unawaited(RestaurantPushNotificationService.instance.markAppOpened());
    unawaited(_loadRestaurant());
    _refreshActiveOrders();
""",
    """    unawaited(RestaurantPushNotificationService.instance.markAppOpened());
    unawaited(RestaurantPushNotificationService.instance.markNavigationReady());
    unawaited(
      RestaurantPushNotificationService.instance.registerCurrentToken(
        requestPermissionIfNeeded: false,
      ),
    );
    unawaited(_loadRestaurant());
    _refreshActiveOrders();
""",
)

ci = '.github/workflows/flutter-ci.yml'
replace_once(
    ci,
    """      - name: Verify Dart source encoding
        run: python3 tool/verify_dart_utf8.py

      - name: Analyze
""",
    """      - name: Verify Dart source encoding
        run: python3 tool/verify_dart_utf8.py

      - name: Verify restaurant release contract
        run: python3 tool/verify_restaurant_release_contract.py

      - name: Analyze
""",
)

print('Restaurant production root patch applied')
