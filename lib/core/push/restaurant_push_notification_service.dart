import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_storage.dart';
import 'package:jetkiz_restaurant/features/orders/presentation/pages/restaurant_order_details_page.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {
    // Background handler must never crash the process.
  }
}

class RestaurantPushNotificationService {
  RestaurantPushNotificationService._();

  static final RestaurantPushNotificationService instance =
      RestaurantPushNotificationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String restaurantNewOrderType = 'RESTAURANT_NEW_ORDER';

  static const String androidNewOrderChannelId = 'restaurant_new_orders_v2';
  static const String androidNewOrderChannelName = 'Новые заказы';
  static const String androidNewOrderChannelDescription =
      'Громкие уведомления для новых заказов ресторана';

  static const String restaurantOrderSoundName = 'restaurant_order';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ApiClient _apiClient = ApiClient.instance;
  final AuthStorage _authStorage = AuthStorage();
  final StreamController<void> _ordersRefreshController =
      StreamController<void>.broadcast();

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;

  final List<Map<String, String>> _pendingOpenPayloads =
      <Map<String, String>>[];
  final Set<String> _handledMessageKeys = <String>{};

  bool _initialized = false;
  bool _navigationFlushScheduled = false;
  bool _navigationReady = false;
  int _navigationGeneration = 0;

  Stream<void> get ordersRefreshEvents => _ordersRefreshController.stream;

  AndroidNotificationChannel get _androidNewOrderChannel {
    return const AndroidNotificationChannel(
      androidNewOrderChannelId,
      androidNewOrderChannelName,
      description: androidNewOrderChannelDescription,
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(restaurantOrderSoundName),
      enableVibration: true,
    );
  }

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    await _requestPermission();
    await _initLocalNotifications();
    await _listenTokenRefresh();
    await _listenForegroundMessages();
    await _listenNotificationOpen();
    await registerCurrentToken();
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedAppSubscription?.cancel();

    _tokenRefreshSubscription = null;
    _foregroundSubscription = null;
    _openedAppSubscription = null;
    _initialized = false;
  }

  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('RestaurantPush: getToken failed: $error');
      }

      return null;
    }
  }

  Future<void> registerCurrentToken() async {
    final accessToken = await _authStorage.getAccessToken();

    if (accessToken == null || accessToken.trim().isEmpty) {
      if (kDebugMode) {
        debugPrint('RestaurantPush: skip token registration, no access token');
      }

      return;
    }

    final token = await getToken();

    if (token == null || token.trim().isEmpty) {
      if (kDebugMode) {
        debugPrint('RestaurantPush: FCM token is empty');
      }

      return;
    }

    await _sendTokenToBackend(token);
  }

  Future<void> unregisterCurrentToken() async {
    final token = await getToken();
    if (token == null || token.trim().isEmpty) return;

    final deviceId = await _getOrCreateDeviceId();

    await _apiClient.post('/notification-devices/unregister', <String, dynamic>{
      'token': token.trim(),
      'deviceId': deviceId,
    });
  }

  Future<void> markNavigationReady() async {
    final generation = _navigationGeneration;
    final hasSession = await _authStorage.hasSession();
    final restaurantId = await _authStorage.getSelectedRestaurantId();
    if (generation != _navigationGeneration) return;
    _navigationReady = hasSession && restaurantId != null;
    if (_navigationReady) _scheduleNavigationFlush();
  }

  void markNavigationUnavailable() {
    _navigationGeneration++;
    _navigationReady = false;
  }

  Future<void> _requestPermission() async {
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

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        unawaited(
          _handleLocalNotificationTap(
            response.payload,
            source: 'foreground_local_tap',
          ),
        );
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_androidNewOrderChannel);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _listenTokenRefresh() async {
    await _tokenRefreshSubscription?.cancel();

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
      unawaited(_sendTokenToBackend(token));
    });
  }

  Future<void> _listenForegroundMessages() async {
    await _foregroundSubscription?.cancel();

    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      unawaited(_showForegroundNewOrderNotification(message));
    });
  }

  Future<void> _listenNotificationOpen() async {
    await _openedAppSubscription?.cancel();

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      unawaited(_handleNotificationOpen(initialMessage, source: 'terminated'));
    }

    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      unawaited(_handleNotificationOpen(message, source: 'background'));
    });
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      final accessToken = await _authStorage.getAccessToken();

      if (accessToken == null || accessToken.trim().isEmpty) {
        return;
      }

      final deviceId = await _getOrCreateDeviceId();

      await _apiClient.post('/notification-devices/register', {
        'token': token.trim(),
        'platform': _backendPlatformName(),
        'deviceId': deviceId,
        'appVersion': '1.0.0',
      });

      if (kDebugMode) {
        debugPrint('RestaurantPush: FCM token registered');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('RestaurantPush: token register failed: $error');
      }
    }
  }

  Future<void> _showForegroundNewOrderNotification(
    RemoteMessage message,
  ) async {
    if (!_isRestaurantNewOrder(message.data)) {
      return;
    }

    if (!_markMessageHandled(message)) {
      return;
    }

    _ordersRefreshController.add(null);

    final orderId = _readString(message.data['orderId']);
    if (orderId == null) {
      return;
    }

    final restaurantId = _readString(message.data['restaurantId']);
    final title =
        _readString(message.notification?.title) ??
        _readString(message.data['title']) ??
        'Новый заказ';

    final body =
        _readString(message.notification?.body) ??
        _readString(message.data['body']) ??
        'Откройте заказ и подтвердите приготовление';

    await _localNotifications.show(
      id: _stableNotificationId(orderId),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          androidNewOrderChannelId,
          androidNewOrderChannelName,
          channelDescription: androidNewOrderChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound(
            restaurantOrderSoundName,
          ),
          enableVibration: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          fullScreenIntent: true,
          ticker: 'Новый заказ',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'restaurant_order.wav',
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: jsonEncode(<String, String>{
        'type': restaurantNewOrderType,
        'orderId': orderId,
        if (restaurantId != null) 'restaurantId': restaurantId,
        if (_readString(message.data['orderNumber']) != null)
          'orderNumber': _readString(message.data['orderNumber'])!,
        if (_readString(message.data['notificationId']) != null)
          'notificationId': _readString(message.data['notificationId'])!,
      }),
    );
  }

  Future<void> _handleNotificationOpen(
    RemoteMessage message, {
    required String source,
  }) async {
    if (!_isRestaurantNewOrder(message.data)) {
      return;
    }

    final orderId = _readString(message.data['orderId']);

    if (orderId == null) {
      return;
    }

    final restaurantId = _readString(message.data['restaurantId']);

    _ordersRefreshController.add(null);

    await _trackNotificationOpen(
      source: source,
      notificationId: _readString(message.data['notificationId']),
      orderId: orderId,
      restaurantId: restaurantId,
    );

    _queueOpenPayload(<String, String>{
      'type': restaurantNewOrderType,
      'orderId': orderId,
      if (restaurantId != null) 'restaurantId': restaurantId,
    });
  }

  Future<void> _handleLocalNotificationTap(
    String? payload, {
    required String source,
  }) async {
    if (payload == null || payload.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(payload);

      if (decoded is! Map) {
        return;
      }

      final data = decoded.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );

      if (!_isRestaurantNewOrder(data)) {
        return;
      }

      final orderId = _readString(data['orderId']);

      if (orderId == null) {
        return;
      }

      final restaurantId = _readString(data['restaurantId']);

      await _trackNotificationOpen(
        source: source,
        notificationId: _readString(data['notificationId']),
        orderId: orderId,
        restaurantId: restaurantId,
      );

      _queueOpenPayload(<String, String>{
        'type': restaurantNewOrderType,
        'orderId': orderId,
        if (restaurantId != null) 'restaurantId': restaurantId,
      });
    } catch (error) {
      if (kDebugMode) {
        debugPrint('RestaurantPush: local payload decode failed: $error');
      }
    }
  }

  void _queueOpenPayload(Map<String, String> payload) {
    _pendingOpenPayloads.add(payload);
    _scheduleNavigationFlush();
  }

  void _scheduleNavigationFlush() {
    if (_navigationFlushScheduled) {
      return;
    }

    _navigationFlushScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationFlushScheduled = false;
      unawaited(_flushPendingOpenPayloads());
    });

    Future<void>.delayed(const Duration(milliseconds: 400), () {
      unawaited(_flushPendingOpenPayloads());
    });
  }

  Future<void> _flushPendingOpenPayloads() async {
    if (!_navigationReady) return;

    final hasSession = await _authStorage.hasSession();
    final selectedRestaurantId = await _authStorage.getSelectedRestaurantId();
    if (!hasSession || selectedRestaurantId == null) {
      _navigationReady = false;
      return;
    }

    final navigator = navigatorKey.currentState;

    if (navigator == null || _pendingOpenPayloads.isEmpty) {
      return;
    }

    final payload = _pendingOpenPayloads.removeAt(0);
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
  }

  Future<void> _trackNotificationOpen({
    required String source,
    required String orderId,
    String? notificationId,
    String? restaurantId,
  }) async {
    try {
      final accessToken = await _authStorage.getAccessToken();

      if (accessToken == null || accessToken.trim().isEmpty) {
        return;
      }

      await _apiClient.post('/client-events', {
        'eventName': 'notification_open',
        'entityType': 'order',
        'entityId': orderId,
        'metadata': {
          'source': source,
          'app': 'RESTAURANT',
          if (restaurantId != null && restaurantId.isNotEmpty)
            'restaurantId': restaurantId,
          if (notificationId != null && notificationId.isNotEmpty)
            'notificationId': notificationId,
        },
      });
    } catch (error) {
      if (kDebugMode) {
        debugPrint('RestaurantPush: notification_open failed: $error');
      }
    }
  }

  bool _isRestaurantNewOrder(Map<String, dynamic> data) {
    final type = _readString(data['type'])?.toUpperCase();

    return type == restaurantNewOrderType;
  }

  bool _markMessageHandled(RemoteMessage message) {
    final key =
        message.messageId ??
        _readString(message.data['notificationId']) ??
        _readString(message.data['orderId']) ??
        DateTime.now().microsecondsSinceEpoch.toString();

    if (_handledMessageKeys.contains(key)) {
      return false;
    }

    _handledMessageKeys.add(key);

    if (_handledMessageKeys.length > 80) {
      _handledMessageKeys.remove(_handledMessageKeys.first);
    }

    return true;
  }

  int _stableNotificationId(String orderId) {
    return orderId.hashCode & 0x7fffffff;
  }

  String _backendPlatformName() {
    if (Platform.isAndroid) return 'ANDROID';
    if (Platform.isIOS) return 'IOS';
    return 'UNKNOWN';
  }

  Future<String> _getOrCreateDeviceId() async {
    const key = 'restaurant_device_id';

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(key);

    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }

    final random = Random.secure();
    final value = [
      DateTime.now().millisecondsSinceEpoch.toRadixString(16),
      random.nextInt(1 << 32).toRadixString(16),
      random.nextInt(1 << 32).toRadixString(16),
    ].join('-');

    await prefs.setString(key, value);

    return value;
  }

  String? _readString(dynamic value) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }

    return text;
  }
}
