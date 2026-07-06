import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../routes/app_router.dart';

// Background message handler required by firebase_messaging
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Note: keep this handler lightweight. Android/iOS background notifications
  // should be handled by the platform when possible. This is a fallback to
  // show a local notification when a data message arrives in background.
  // Flutter isolates are limited here; we intentionally keep logic minimal.
}

class NotificationService {
  NotificationService._private();
  static final NotificationService _instance = NotificationService._private();
  factory NotificationService() => _instance;

  FirebaseMessaging? _fcm;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    try {
      // Configure Firebase Messaging only if Firebase is initialized.
      try {
        if (Firebase.apps.isNotEmpty) {
          _fcm = FirebaseMessaging.instance;
          // Configure background handler
          FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

          // Request permissions (iOS/macOS)
          await _fcm!.requestPermission(alert: true, badge: true, sound: true);
        } else {
          if (kDebugMode) print('Firebase not initialized; skipping FCM setup.');
        }
      } catch (e) {
        if (kDebugMode) print('FCM setup skipped or failed: $e');
      }

      // Initialize local notifications
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      final iosInit = DarwinInitializationSettings();
      final initSettings = InitializationSettings(android: androidInit, iOS: iosInit, macOS: null);

      await _local.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _handleNotificationResponse(response);
        },
      );

      // Foreground message handler to display local notification
      FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
        try {
          final notification = msg.notification;
          if (notification != null) {
            showLocalNotification(
              notification.title ?? '',
              notification.body ?? '',
              payload: _routeFromMessage(msg),
            );
          }
        } catch (e) {
          if (kDebugMode) print('Error showing local notification: $e');
        }
      });

      // Optionally handle messages opened from terminated/background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
        _navigateToRoute(_routeFromMessage(msg));
      });
    } catch (e) {
      if (kDebugMode) print('Notification initialization failed: $e');
    }
  }

  Future<void> showLocalNotification(String title, String body, {String? payload}) async {
    const androidDetails = AndroidNotificationDetails(
      'gct_channel_01',
      'GCT Notifications',
      channelDescription: 'General notifications for GCT app',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _local.show(
      id: 0,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: details,
    );
  }

  Future<String?> getDeviceToken() async {
    try {
      return await _fcm?.getToken();
    } catch (e) {
      if (kDebugMode) print('Failed to get FCM token: $e');
      return null;
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      _navigateToRoute(payload);
    }
  }

  String _routeFromMessage(RemoteMessage message) {
    final data = message.data;
    final appointmentId = data['appointmentId'] ?? data['appointment_id'];
    if (appointmentId != null && appointmentId.toString().isNotEmpty) {
      return '/appointment/${appointmentId.toString()}';
    }

    final screen = data['screen']?.toString().toLowerCase();
    if (screen == 'profile') {
      return '/profile';
    }
    if (screen == 'appointments') {
      return '/appointments';
    }
    if (screen == 'dashboard') {
      return '/dashboard';
    }
    return '/dashboard';
  }

  void _navigateToRoute(String route) {
    final context = appNavigatorKey.currentContext;
    if (context == null) {
      if (kDebugMode) print('Unable to navigate: app context is not ready yet.');
      return;
    }

    try {
      GoRouter.of(context).go(route);
    } catch (e) {
      if (kDebugMode) print('Failed to navigate to route "$route": $e');
    }
  }
}
