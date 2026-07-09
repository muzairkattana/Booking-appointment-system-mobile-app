import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../routes/app_router.dart';

// Background message handler required by firebase_messaging
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  final data = message.data;
  final notification = message.notification;
  String? title = notification?.title;
  String? body = notification?.body;

  if (title == null || body == null) {
    title = data['title'] ?? data['notification_title'] ?? 'GCT Clinic Alert';
    body = data['body'] ?? data['notification_body'] ?? 'You have a new update.';
  }

  final localNotifications = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  final iosInit = DarwinInitializationSettings();
  final initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
  await localNotifications.initialize(initSettings);

  const androidDetails = AndroidNotificationDetails(
    'gct_channel_01',
    'GCT Notifications',
    channelDescription: 'General notifications for GCT app',
    importance: Importance.max,
    priority: Priority.high,
  );
  const iosDetails = DarwinNotificationDetails();
  final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

  String? payload;
  final appointmentId = data['appointmentId'] ?? data['appointment_id'];
  if (appointmentId != null && appointmentId.toString().isNotEmpty) {
    payload = '/appointment/${appointmentId.toString()}';
  } else {
    final screen = data['screen']?.toString().toLowerCase();
    if (screen != null) {
      payload = '/$screen';
    }
  }

  await localNotifications.show(
    0,
    title,
    body,
    details,
    payload: payload,
  );
}

class NotificationService {
  NotificationService._private();
  static final NotificationService _instance = NotificationService._private();
  factory NotificationService() => _instance;

  FirebaseMessaging? _fcm;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    try {
      tz.initializeTimeZones();
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
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _handleNotificationResponse(response);
        },
      );

      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _local
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission();
        } catch (e) {
          if (kDebugMode) print('Failed to request Android notification permission: $e');
        }
      }

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

      // Handle message that opened the app when terminated (FCM)
      final initialMessage = await _fcm?.getInitialMessage();
      if (initialMessage != null) {
        _navigateToRoute(_routeFromMessage(initialMessage));
      }

      // Handle message that opened the app when terminated (Local Notification)
      final launchDetails = await _local.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final payload = launchDetails.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          _navigateToRoute(payload);
        }
      }
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
      0,
      title,
      body,
      details,
      payload: payload,
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
    _performNavigation(route);
  }

  Future<void> _performNavigation(String route) async {
    int attempts = 0;
    // Wait until navigator context is loaded and ready
    while (appNavigatorKey.currentContext == null && attempts < 100) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

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

  Future<void> scheduleLocalNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'gct_scheduled_channel',
      'GCT Reminders',
      channelDescription: 'Scheduled reminders for GCT app',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final tzScheduledDate = tz.TZDateTime.from(scheduledDate.toUtc(), tz.UTC);

    await _local.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _local.cancel(id);
    } catch (e) {
      if (kDebugMode) print('Failed to cancel notification $id: $e');
    }
  }
}
