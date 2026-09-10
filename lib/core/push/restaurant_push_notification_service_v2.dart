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

import 'package:jetkiz_restaurant/core/config/app_build_info.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_api.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_storage.dart';
import 'package:jetkiz_restaurant/features/finance/presentation/pages/restaurant_finance_page.dart';
import 'package:jetkiz_restaurant/features/menu/presentation/pages/restaurant_menu_page.dart';
import 'package:jetkiz_restaurant/features/notifications/presentation/pages/restaurant_notifications_page.dart';
import 'package:jetkiz_restaurant/features/orders/presentation/pages/restaurant_order_details_page.dart';
import 'package:jetkiz_restaurant/features/orders/presentation/pages/restaurant_orders_localized_page.dart';
import 'package:jetkiz_restaurant/features/restaurant_profile/presentation/pages/restaurant_profile_page.dart';
import 'package:jetkiz_restaurant/features/reviews/presentation/pages/restaurant_reviews_page.dart';

const String _restaurantNewOrderType = 'RESTAURANT_NEW_ORDER';
const String _adminCampaignType = 'ADMIN_CAMPAIGN';
const String _androidGeneralChannelId = 'jetkiz_default_channel';
const String _androidGeneralChannelName = 'JETKIZ';
const String _androidGeneralChannelDescription =
    'Обычные уведомления JETKIZ для ресторана';
const String _androidNewOrderChannelId = 'restaurant_new_orders_v2';
const String _androidNewOrderChannelName = 'Новые заказы';
const String _androidNewOrderChannelDescription =
    'Громкие уведомления для новых заказов ресторана';
const String _restaurantOrderSoundName = 'restaurant_order';
const String _lastAppOpenedAtKey = 'restaurant_last_app_opened_at_ms';
const Duration _newOrderRepeatPause = Duration(seconds: 10);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  } catch (_) {
    return;
  }

  if (!Platform.isAndroid || !_isRestaurantOrderData(message.data)) return;
  final orderId = _readPushString(message.data['orderId']);
  if (orderId == null) return;

  final sequenceStartedAt = DateTime.now().millisecondsSinceEpoch;
  final plugin = FlutterLocalNotificationsPlugin();
  try {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await plugin.initialize(settings: initializationSettings);
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidNewOrderChannelId,
        _androidNewOrderChannelName,
        description: _androidNewOrderChannelDescription,
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_restaurantOrderSoundName),
        enableVibration: true,
      ),
    );
  } catch (_) {
    return;
  }

  final title = _readPushString(message.notification?.title) ??
      _readPushString(message.data['title']) ??
      'Новый заказ';
  final body = _readPushString(message.notification?.body) ??
      _readPushString(message.data['body']) ??
      'Откройте заказ и подтвердите приготовление';
  final restaurantId = _readPushString(message.data['restaurantId']);
  final orderNumber = _readPushString(message.data['orderNumber']);
  final notificationId = _readPushString(message.data['notificationId']);
  final payload = jsonEncode(<String, String>{
    'type': _restaurantNewOrderType,
    'orderId': orderId,
    if (restaurantId != null) 'restaurantId': restaurantId,
    if (orderNumber != null) 'orderNumber': orderNumber,
    if (notificationId != null) 'notificationId': notificationId,
  });

  for (var repeat = 1; repeat <= 2; repeat++) {
    await Future<void>.delayed(_newOrderRepeatPause);
    if (await _appWasOpenedAfter(sequenceStartedAt)) return;
    try {
      await plugin.show(
        id: _stablePushNotificationId(orderId),
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _androidNewOrderChannelId,
            _androidNewOrderChannelName,
            channelDescription: _androidNewOrderChannelDescription,
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            sound: RawResourceAndroidNotificationSound(_restaurantOrderSoundName),
            enableVibration: true,
            category: AndroidNotificationCategory.message,
            visibility: NotificationVisibility.private,
            ticker: 'Новый заказ',
          ),
        ),
        payload: payload,
      );
    } catch (_) {}
  }
}

Future<bool> _appWasOpenedAfter(int sequenceStartedAt) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return (prefs.getInt(_lastAppOpenedAtKey) ?? 0) >= sequenceStartedAt;
  } catch (_) {
    return false;
  }
}

bool _isRestaurantOrderData(Map<String, dynamic> data) =>
    _readPushString(data['type'])?.toUpperCase() == _restaurantNewOrderType;

String? _readPushString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  return text;
}

int _stablePushNotificationId(String key) {
  var hash = 17;
  for (final unit in key.codeUnits) {
    hash = ((hash * 31) + unit) & 0x7fffffff;
  }
  return hash;
}

class RestaurantPushNotificationService {
  RestaurantPushNotificationService._();

  static final RestaurantPushNotificationService instance =
      RestaurantPushNotificationService._();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String restaurantNewOrderType = _restaurantNewOrderType;
  static const String androidNewOrderChannelId = _androidNewOrderChannelId;
  static const String androidNewOrderChannelName = _androidNewOrderChannelName;
  static const String androidNewOrderChannelDescription =
      _androidNewOrderChannelDescription;
  static const String restaurantOrderSoundName = _restaurantOrderSoundName;

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
  final List<Map<String, String>> _pendingOpenPayloads = <Map<String, String>>[];
  final Set<String> _handledMessageKeys = <String>{};
  bool _initialized = false;
  bool _navigationFlushScheduled = false;
  bool _navigationReady = false;
  int _navigationGeneration = 0;

  Stream<void> get ordersRefreshEvents => _ordersRefreshController.stream;

  AndroidNotificationChannel get _androidNewOrderChannel =>
      const AndroidNotificationChannel(
        androidNewOrderChannelId,
        androidNewOrderChannelName,
        description: androidNewOrderChannelDescription,
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(restaurantOrderSoundName),
        enableVibration: true,
      );

  Future<void> init() async {
    if (_initialized) {
      await markAppOpened();
      return;
    }
    _initialized = true;
    await markAppOpened();
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

  Future<void> markAppOpened() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _lastAppOpenedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (error) {
      if (kDebugMode) debugPrint('RestaurantPush: getToken failed: $error');
      return null;
    }
  }

  Future<void> registerCurrentToken({
    bool requestPermissionIfNeeded = true,
  }) async {
    await _registerCurrentTokenVerified(
      requestPermissionIfNeeded: requestPermissionIfNeeded,
    );
  }

  Future<bool> ensureOrderNotificationsReady({
    bool requestPermissionIfNeeded = true,
  }) async {
    final registered = await _registerCurrentTokenVerified(
      requestPermissionIfNeeded: requestPermissionIfNeeded,
    );
    if (!registered) return false;
    if (!Platform.isAndroid) return true;
    return _isAndroidNewOrderChannelUsable();
  }

  Future<bool> _registerCurrentTokenVerified({
    required bool requestPermissionIfNeeded,
  }) async {
    final accessToken = await _authStorage.getAccessToken();
    if (accessToken == null || accessToken.trim().isEmpty) return false;

    final permitted = await _ensureNotificationPermission(
      requestIfNeeded: requestPermissionIfNeeded,
    );
    if (!permitted) {
      await _unregisterCurrentTokenBestEffort();
      return false;
    }

    final token = await getToken();
    if (token == null || token.trim().isEmpty) return false;
    return _sendTokenToBackend(token);
  }

  Future<bool> _isAndroidNewOrderChannelUsable() async {
    try {
      final android = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      await android.createNotificationChannel(_androidNewOrderChannel);
      final channels = await android.getNotificationChannels();
      if (channels == null) return false;
      for (final channel in channels) {
        if (channel.id == androidNewOrderChannelId) {
          return channel.importance != Importance.none;
        }
      }
      return false;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('RestaurantPush: channel readiness failed: $error');
      }
      return false;
    }
  }

  Future<void> unregisterCurrentToken() async {
    final token = await getToken();
    if (token == null || token.trim().isEmpty) return;
    final deviceId = await _getOrCreateDeviceId();
    await _apiClient.post('/notification-devices/unregister', <String, dynamic>{
      'token': token.trim(),
      'deviceId': deviceId,
      'app': 'restaurant',
    });
  }

  Future<void> markNavigationReady() async {
    await markAppOpened();
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
    _navigationFlushScheduled = false;
    _pendingOpenPayloads.clear();
  }

  Future<bool> _ensureNotificationPermission({required bool requestIfNeeded}) async {
    try {
      if (Platform.isAndroid) {
        final android = _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final enabled = await android?.areNotificationsEnabled();
        if (enabled == true) return true;
        if (!requestIfNeeded) return false;
        final requested = await android?.requestNotificationsPermission();
        final after = await android?.areNotificationsEnabled();
        return after ?? requested ?? false;
      }

      final current = await _messaging.getNotificationSettings();
      if (_isAuthorized(current.authorizationStatus)) return true;
      if (current.authorizationStatus == AuthorizationStatus.denied ||
          !requestIfNeeded) {
        return false;
      }
      final requested = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );
      return _isAuthorized(requested.authorizationStatus);
    } catch (_) {
      return false;
    }
  }

  bool _isAuthorized(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  Future<void> _unregisterCurrentTokenBestEffort() async {
    try {
      await unregisterCurrentToken();
    } catch (_) {}
  }

  Future<void> _initLocalNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        unawaited(_handleLocalNotificationTap(
          response.payload,
          source: 'foreground_local_tap',
        ));
      },
    );

    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidGeneralChannelId,
        _androidGeneralChannelName,
        description: _androidGeneralChannelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await android?.createNotificationChannel(_androidNewOrderChannel);
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
      unawaited(_handleForegroundMessage(message));
    });
  }

  Future<void> _listenNotificationOpen() async {
    await _openedAppSubscription?.cancel();
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      unawaited(_handleNotificationOpen(initialMessage, source: 'terminated'));
    }
    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(_handleNotificationOpen(message, source: 'background'));
    });
  }

  Future<bool> _sendTokenToBackend(String token) async {
    try {
      final accessToken = await _authStorage.getAccessToken();
      if (accessToken == null || accessToken.trim().isEmpty) return false;
      final deviceId = await _getOrCreateDeviceId();
      await _apiClient.post('/notification-devices/register', {
        'token': token.trim(),
        'platform': _backendPlatformName(),
        'deviceId': deviceId,
        'app': 'restaurant',
        'appVersion': AppBuildInfo.fullVersion,
      });
      return true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('RestaurantPush: token register failed: $error');
      }
      return false;
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (_isRestaurantNewOrder(message.data)) {
      await _showForegroundNewOrderNotification(message);
    } else if (_isRestaurantAdminCampaign(message.data)) {
      await _showForegroundAdminCampaignNotification(message);
    }
  }

  Future<void> _showForegroundAdminCampaignNotification(RemoteMessage message) async {
    if (!_markMessageHandled(message)) return;
    final title = _readString(message.notification?.title) ??
        _readString(message.data['title']) ??
        'JETKIZ';
    final body = _readString(message.notification?.body) ??
        _readString(message.data['body']) ??
        'Новое уведомление';
    final stableKey = _readString(message.data['notificationId']) ??
        _readString(message.data['campaignId']) ??
        message.messageId ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final payload = _notificationPayloadFromData(message.data);

    await _localNotifications.show(
      id: _stablePushNotificationId(stableKey),
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
          visibility: NotificationVisibility.private,
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

  Future<void> _showForegroundNewOrderNotification(RemoteMessage message) async {
    if (!_isRestaurantNewOrder(message.data) || !_markMessageHandled(message)) return;
    await markAppOpened();
    _ordersRefreshController.add(null);
    final orderId = _readString(message.data['orderId']);
    if (orderId == null) return;
    final restaurantId = _readString(message.data['restaurantId']);
    final title = _readString(message.notification?.title) ??
        _readString(message.data['title']) ??
        'Новый заказ';
    final body = _readString(message.notification?.body) ??
        _readString(message.data['body']) ??
        'Откройте заказ и подтвердите приготовление';

    await _localNotifications.show(
      id: _stablePushNotificationId(orderId),
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
          sound: const RawResourceAndroidNotificationSound(restaurantOrderSoundName),
          enableVibration: true,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.private,
          ticker: 'Новый заказ',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
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

  Future<void> _handleNotificationOpen(RemoteMessage message,
      {required String source}) async {
    await markAppOpened();
    if (_isRestaurantAdminCampaign(message.data)) {
      final payload = _notificationPayloadFromData(message.data);
      await _trackAdminCampaignOpen(payload, source: source);
      _queueOpenPayload(payload);
      return;
    }
    if (!_isRestaurantNewOrder(message.data)) return;
    final orderId = _readString(message.data['orderId']);
    if (orderId == null) return;
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

  Future<void> _handleLocalNotificationTap(String? rawPayload,
      {required String source}) async {
    if (rawPayload == null || rawPayload.trim().isEmpty) return;
    await markAppOpened();
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map) return;
      final data = decoded.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
      if (_isRestaurantAdminCampaign(data)) {
        final payload = _notificationPayloadFromData(data);
        await _trackAdminCampaignOpen(payload, source: source);
        _queueOpenPayload(payload);
        return;
      }
      if (!_isRestaurantNewOrder(data)) return;
      final orderId = _readString(data['orderId']);
      if (orderId == null) return;
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
      if (kDebugMode) debugPrint('RestaurantPush: payload decode failed: $error');
    }
  }

  void _queueOpenPayload(Map<String, String> payload) {
    _pendingOpenPayloads.add(payload);
    _scheduleNavigationFlush();
  }

  void _scheduleNavigationFlush() {
    if (_navigationFlushScheduled) return;
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
    if (navigator == null || _pendingOpenPayloads.isEmpty) return;

    final payload = _pendingOpenPayloads.removeAt(0);
    final payloadRestaurantId = _readString(payload['restaurantId']);
    final targetRestaurantId = payloadRestaurantId ?? selectedRestaurantId;
    final role = await _roleForRestaurant(targetRestaurantId);
    if (role == null) {
      if (_pendingOpenPayloads.isNotEmpty) _scheduleNavigationFlush();
      return;
    }
    if (targetRestaurantId != selectedRestaurantId) {
      await _apiClient.setSelectedRestaurantId(targetRestaurantId);
    }

    if (_readString(payload['type'])?.toUpperCase() == _adminCampaignType) {
      await _openAdminCampaignPayload(navigator, payload, targetRestaurantId, role);
    } else {
      final orderId = _readString(payload['orderId']);
      if (orderId != null) {
        navigator.push(MaterialPageRoute<void>(
          builder: (_) => RestaurantOrderDetailsPage(orderId: orderId),
        ));
      }
    }
    if (_pendingOpenPayloads.isNotEmpty) _scheduleNavigationFlush();
  }

  Future<String?> _roleForRestaurant(String restaurantId) async {
    try {
      final me = await AuthApi().getMe();
      final accesses = me['restaurantAccesses'];
      if (accesses is! List) return null;
      for (final raw in accesses) {
        if (raw is! Map) continue;
        final id = _readString(raw['restaurantId']);
        if (id != restaurantId) continue;
        final source = _readString(raw['source'])?.toUpperCase();
        final role = _readString(raw['role'])?.toUpperCase();
        if (source == 'OWNER' || role == 'OWNER') return 'OWNER';
        if (role == 'MANAGER') return 'MANAGER';
        if (role == 'STAFF') return 'STAFF';
        return null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openAdminCampaignPayload(
    NavigatorState navigator,
    Map<String, String> payload,
    String restaurantId,
    String role,
  ) async {
    var screen = (_readString(payload['screen']) ?? 'notifications').toLowerCase();
    final isManager = role == 'OWNER' || role == 'MANAGER';
    const restrictedForStaff = <String>{
      'menu',
      'finance',
      'balance',
      'profile',
      'reviews',
    };
    if (!isManager && restrictedForStaff.contains(screen)) {
      screen = 'orders';
    }

    final orderId = _readString(payload['orderId']);
    late final Widget page;
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
    navigator.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  bool _isRestaurantAdminCampaign(Map<String, dynamic> data) {
    final type = _readString(data['type'])?.toUpperCase();
    if (type != _adminCampaignType) return false;
    final app = _readString(data['app'])?.toLowerCase();
    return app == null || app == 'restaurant';
  }

  bool _isRestaurantNewOrder(Map<String, dynamic> data) =>
      _readString(data['type'])?.toUpperCase() == restaurantNewOrderType;

  Map<String, String> _notificationPayloadFromData(Map<String, dynamic> data) {
    final result = <String, String>{'type': _adminCampaignType, 'app': 'restaurant'};
    for (final key in <String>[
      'screen',
      'orderId',
      'restaurantId',
      'campaignId',
      'notificationId',
      'route',
      'action',
    ]) {
      final value = _readString(data[key]);
      if (value != null) result[key] = value;
    }
    return result;
  }

  Future<void> _trackAdminCampaignOpen(Map<String, String> payload,
      {required String source}) async {
    try {
      final accessToken = await _authStorage.getAccessToken();
      if (accessToken == null || accessToken.trim().isEmpty) return;
      final entityId = _readString(payload['campaignId']) ??
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
    } catch (_) {}
  }

  Future<void> _trackNotificationOpen({
    required String source,
    required String orderId,
    String? notificationId,
    String? restaurantId,
  }) async {
    try {
      final accessToken = await _authStorage.getAccessToken();
      if (accessToken == null || accessToken.trim().isEmpty) return;
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
    } catch (_) {}
  }

  bool _markMessageHandled(RemoteMessage message) {
    final key = message.messageId ??
        _readString(message.data['notificationId']) ??
        _readString(message.data['orderId']) ??
        DateTime.now().microsecondsSinceEpoch.toString();
    if (_handledMessageKeys.contains(key)) return false;
    _handledMessageKeys.add(key);
    if (_handledMessageKeys.length > 80) {
      _handledMessageKeys.remove(_handledMessageKeys.first);
    }
    return true;
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
    if (existing != null && existing.trim().isNotEmpty) return existing.trim();
    final random = Random.secure();
    final value = <String>[
      DateTime.now().millisecondsSinceEpoch.toRadixString(16),
      random.nextInt(1 << 32).toRadixString(16),
      random.nextInt(1 << 32).toRadixString(16),
    ].join('-');
    await prefs.setString(key, value);
    return value;
  }

  String? _readString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }
}
