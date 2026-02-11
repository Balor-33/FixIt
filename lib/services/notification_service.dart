import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ✅ Top-level background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 Background message: ${message.messageId}');
  print('Title: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
  print('Data: ${message.data}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // ✅ Track initialization state
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ Notification service already initialized');
      return;
    }

    print('🚀 Initializing Notification Service...');

    try {
      // 1. Request permission FIRST
      final permissionGranted = await _requestPermission();
      if (!permissionGranted) {
        print('❌ Notification permission not granted');
        return;
      }

      // 2. Initialize local notifications
      await _initializeLocalNotifications();

      // 3. Set up background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 4. Get FCM token
      await _getFCMToken();

      // 5. Token refresh listener
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        print('✅ FCM Token refreshed: $newToken');
        _updateTokenInFirestore(newToken);
      });

      // 6. Foreground message handler
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 7. Background tap handler
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // 8. Check if opened from notification
      await _checkInitialMessage();

      _isInitialized = true;
      print('✅ Notification Service initialized successfully');
    } catch (e) {
      print('❌ Error initializing notifications: $e');
    }
  }

  // ✅ Return bool to indicate success
  Future<bool> _requestPermission() async {
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ User granted notification permission');
        return true;
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('⚠️ User granted provisional notification permission');
        return true;
      } else {
        print('❌ User declined notification permission');
        return false;
      }
    } catch (e) {
      print('❌ Error requesting permission: $e');
      return false;
    }
  }

  Future<void> _getFCMToken() async {
    try {
      // For iOS, wait for APNS token
      if (Platform.isIOS) {
        String? apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          print('⚠️ Waiting for APNS token...');
          await Future.delayed(const Duration(seconds: 3));
          apnsToken = await _messaging.getAPNSToken();
        }
        print('📱 APNS Token: $apnsToken');
      }

      _fcmToken = await _messaging.getToken();

      if (_fcmToken != null) {
        print('✅ FCM Token: $_fcmToken');
        
        // Save token immediately if user is logged in
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await updateUserToken(user.uid);
        }
      } else {
        print('❌ Failed to get FCM token');
      }
    } catch (e) {
      print('❌ Error getting FCM token: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // ✅ Create Android notification channel
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'fixit_high_importance', // ✅ Changed ID to be more specific
        'FixIt Notifications',
        description: 'Important notifications for FixIt app',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      print('✅ Android notification channel created');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('📩 Foreground message: ${message.messageId}');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');

    // ✅ Show notification in foreground
    _showLocalNotification(
      title: message.notification?.title ?? 'FixIt',
      body: message.notification?.body ?? 'You have a new notification',
      payload: message.data.toString(),
      data: message.data,
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('🔔 Notification tapped: ${message.data}');
    _navigateBasedOnPayload(message.data);
  }

  Future<void> _checkInitialMessage() async {
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      print('🔔 App opened from notification');
      await Future.delayed(const Duration(seconds: 1));
      _navigateBasedOnPayload(initialMessage.data);
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    print('🔔 Local notification tapped: ${response.payload}');
    // TODO: Parse payload and navigate
  }

  // ✅ Improved local notification display
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    Map<String, dynamic>? data,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'fixit_high_importance', // ✅ Must match channel ID
        'FixIt Notifications',
        channelDescription: 'Important notifications for FixIt app',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _localNotifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      print('✅ Local notification shown: $title');
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }

  void _navigateBasedOnPayload(Map<String, dynamic> data) {
    final String? type = data['type'];
    final String? issueId = data['issueId'];

    print('📍 Navigation data - type: $type, issueId: $issueId');

    // TODO: Implement navigation
  }

  Future<void> updateUserToken(String userId) async {
    if (_fcmToken == null) {
      print('⚠️ Getting FCM token...');
      await _getFCMToken();
    }

    if (_fcmToken == null) {
      print('❌ No FCM token available');
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'fcmToken': _fcmToken,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ FCM token saved for user: $userId');
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  Future<void> _updateTokenInFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await updateUserToken(user.uid);
    }
  }

  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
        });
      }

      _fcmToken = null;
      print('✅ FCM token deleted');
    } catch (e) {
      print('❌ Error deleting token: $e');
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      print('✅ Subscribed to topic: $topic');
    } catch (e) {
      print('❌ Error subscribing to topic: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      print('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      print('❌ Error unsubscribing: $e');
    }
  }

  // ✅ Manual test notification
  Future<void> showTestNotification() async {
    await _showLocalNotification(
      title: 'Test Notification',
      body: 'If you see this, notifications are working! 🎉',
      payload: 'test',
    );
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
    print('✅ All notifications cancelled');
  }
}