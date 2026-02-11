import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import 'notification_routes.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'fixit_high_importance';

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  bool _isInitialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;
  final List<Map<String, dynamic>> _pendingPayloads = [];

  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    debugPrint('Background message received: ${message.messageId}');
    debugPrint('Data: ${message.data}');
  }

  void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    _flushPendingNavigation();
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    final granted = await _requestPermission();
    if (!granted) {
      debugPrint('Notification permission denied');
      return;
    }

    await _initializeLocalNotifications();
    await _getFCMToken();

    _messaging.onTokenRefresh.listen((newToken) async {
      _fcmToken = newToken;
      await updateUserToken();
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    await _checkInitialMessage();

    _isInitialized = true;
    debugPrint('Notification service initialized');
  }

  Future<bool> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> _getFCMToken() async {
    if (Platform.isIOS) {
      await _messaging.getAPNSToken();
    }

    _fcmToken = await _messaging.getToken();

    if (_fcmToken != null) {
      await updateUserToken();
    }
  }

  Future<void> updateUserToken([String? userId]) async {
    final fallbackUser = FirebaseAuth.instance.currentUser;
    final uid = userId ?? fallbackUser?.uid;

    if (uid == null || _fcmToken == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': _fcmToken,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('FCM token saved for user: $uid');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  Future<void> syncProfessionalTopics() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userSnap = await userRef.get();
    final data = userSnap.data();
    if (data == null) return;

    final role = (data['role'] ?? '').toString();
    final service = (data['service'] ?? '').toString();
    final previousTopic = (data['subscribedJobTopic'] ?? '').toString();

    if (role != 'professional') {
      if (previousTopic.isNotEmpty) {
        await unsubscribeFromTopic(previousTopic);
        await userRef.set({
          'subscribedJobTopic': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return;
    }

    if (service.isEmpty) return;

    final currentTopic = jobTopicForCategory(service);

    if (previousTopic.isNotEmpty && previousTopic != currentTopic) {
      await unsubscribeFromTopic(previousTopic);
    }

    await subscribeToTopic(currentTopic);

    await userRef.set({
      'subscribedJobTopic': currentTopic,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;

        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            _navigateBasedOnPayload(decoded);
          }
        } catch (e) {
          debugPrint('Failed to parse local notification payload: $e');
        }
      },
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        'FixIt Notifications',
        description: 'Important notifications for FixIt app',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title ?? 'FixIt',
      notification.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'FixIt Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    _navigateBasedOnPayload(message.data);
  }

  Future<void> _checkInitialMessage() async {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _navigateBasedOnPayload(initialMessage.data);
    }
  }

  void _navigateBasedOnPayload(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      _pendingPayloads.add(data);
      return;
    }

    final request = NotificationRoutes.fromData(data);
    navigator.pushNamed(request.routeName, arguments: request.arguments);
  }

  void _flushPendingNavigation() {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null || _pendingPayloads.isEmpty) return;

    while (_pendingPayloads.isNotEmpty) {
      final payload = _pendingPayloads.removeAt(0);
      final request = NotificationRoutes.fromData(payload);
      navigator.pushNamed(request.routeName, arguments: request.arguments);
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    final normalized = _normalizeTopic(topic);
    if (normalized.isEmpty) return;
    await _messaging.subscribeToTopic(normalized);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    final normalized = _normalizeTopic(topic);
    if (normalized.isEmpty) return;
    await _messaging.unsubscribeFromTopic(normalized);
  }

  Future<void> subscribeToTopics(List<String> topics) async {
    for (final topic in topics) {
      await subscribeToTopic(topic);
    }
  }

  Future<void> unsubscribeFromTopics(List<String> topics) async {
    for (final topic in topics) {
      await unsubscribeFromTopic(topic);
    }
  }

  String jobTopicForCategory(String category) {
    return 'jobs_${_normalizeTopic(category)}';
  }

  String _normalizeTopic(String topic) {
    return topic
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
  }

  Future<void> showTestNotification() async {
    await _localNotifications.show(
      0,
      'Test Notification',
      'If you see this, notifications are working.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'FixIt Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
