import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/invoice_detail_screen.dart';
import 'api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Background handler — top-level function, runs in a separate isolate.
// FCM calls this when the app is in background/terminated.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // ✅ FIX 1: Required before ANY plugin (SharedPreferences, local notifications)
  // works in a background isolate. Without these two lines, SharedPreferences
  // silently returns null for every key → isQuietHours() always returns false
  // → quiet hours were never enforced in the background/terminated state.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  if (await NotificationService.isQuietHours()) {
    print('🔕 Background notification suppressed (quiet hours)');
    return;
  }

  // Handle data-only messages (no notification key) — show manually
  final data = message.data;
  if (message.notification == null && data.isNotEmpty) {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await plugin.show(
      message.hashCode,
      data['title'] ?? 'New Alert',
      data['body'] ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'new_invoices',
          'New Invoice Alerts',
          channelDescription:
              'Alerts when a new invoice is available for investment',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: '${data['type'] ?? ''}|${data['invoice_id'] ?? ''}',
    );
  }

  print('Background notification: ${message.notification?.title}');
}

// Add to MaterialApp: navigatorKey: navigatorKey
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _prefKeyPush = 'push_enabled';
  static const String _prefKeyQuietStart = 'quiet_start';
  static const String _prefKeyQuietEnd = 'quiet_end';

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'new_invoices',
    'New Invoice Alerts',
    description: 'Alerts when a new invoice is available for investment',
    importance: Importance.high,
  );

  // ─────────────────────────────── INIT ──────────────────────────────────

  static Future<void> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse: _onNotificationTapped,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // App opened from terminated state via notification tap
      try {
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          await Future.delayed(const Duration(milliseconds: 500));
          _handleDeepLink(initialMessage.data);
        }
      } catch (e) {
        print('FCM getInitialMessage skipped: $e');
      }

      // App brought to foreground by tapping a notification
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleDeepLink(message.data);
      });

      // Foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Re-register FCM token only if push was previously enabled
      await _registerToken();

      // Keep token fresh after FCM rotates it
      _messaging.onTokenRefresh.listen((token) async {
        if (await isPushEnabled()) {
          await ApiService.registerFcmToken(token);
        }
      });
    } catch (e) {
      print('⚠️ NotificationService initialize skipped: $e');
    }
  }

  // ────────────────────────────── TOKEN ──────────────────────────────────

  static Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        print('⚠️ FCM token null');
        return;
      }
      print('✅ FCM TOKEN: $token');
      await ApiService.registerFcmToken(token);
    } catch (e) {
      print('⚠️ FCM disabled on this device: $e');
    }
  }

  // ─────────────────────────── DEEP LINK ─────────────────────────────────

  static Future<void> _handleDeepLink(Map<String, dynamic> data) async {
    try {
      final type = data['type'];
      final invoiceIdStr = data['invoice_id'];

      if (type == 'new_invoice' && invoiceIdStr != null) {
        final invoiceId = int.tryParse(invoiceIdStr.toString());
        if (invoiceId == null) return;

        final invoice = await ApiService.getInvoiceDetail(invoiceId);
        if (invoice == null) return;

        final context = navigatorKey.currentContext;
        if (context == null) return;

        Navigator.of(context, rootNavigator: true).push(
          SmoothPageRoute(
            builder: (_) => InvoiceDetailScreen.fromMap(invoice),
          ),
        );
      }
    } catch (e) {
      print('Deep link error: $e');
    }
  }

  // ────────────────────────── FOREGROUND ─────────────────────────────────

  static void _handleForegroundMessage(RemoteMessage message) async {
    try {
      if (!await isPushEnabled()) return;

      if (await isQuietHours()) {
        print('🔕 Foreground notification suppressed (quiet hours)');
        return;
      }

      final invoiceId = message.data['invoice_id'] ?? '';
      final type = message.data['type'] ?? '';
      final payload = '$type|$invoiceId';

      final title =
          message.notification?.title ?? message.data['title'] ?? 'New Alert';
      final body = message.notification?.body ?? message.data['body'] ?? '';

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'new_invoices',
          'New Invoice Alerts',
          channelDescription:
              'Alerts when a new invoice is available for investment',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _localNotifications.show(
        message.hashCode,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      print('Foreground notification error: $e');
    }
  }

  @pragma('vm:entry-point')
  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || !payload.contains('|')) return;
    final parts = payload.split('|');
    _handleDeepLink({'type': parts[0], 'invoice_id': parts[1]});
  }

  // ──────────────────────────── PERMISSION ───────────────────────────────

  static Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      print('⚠️ requestPermission error: $e');
      return false;
    }
  }

  static Future<void> revokePermission() async {
    try {
      await _messaging.unsubscribeFromTopic('investors');
      await _messaging.deleteToken();
    } catch (e) {
      print('⚠️ revokePermission error: $e');
    }
  }

  // ───────────────────────── PUSH TOGGLE ─────────────────────────────────

  static Future<bool> isPushEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_prefKeyPush)) {
      await prefs.setBool(_prefKeyPush, false);
      return false;
    }
    return prefs.getBool(_prefKeyPush) ?? false;
  }

  static Future<void> setPushEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyPush, enabled);

    if (enabled) {
      try {
        await _messaging.subscribeToTopic('investors');
        final token = await _messaging.getToken();
        if (token != null) await ApiService.registerFcmToken(token);
      } catch (e) {
        print('⚠️ setPushEnabled register token error: $e');
      }
    }
  }

  // ──────────────────────── QUIET HOURS ──────────────────────────────────

  static Future<(TimeOfDay?, TimeOfDay?)> getQuietHours() async {
    final prefs = await SharedPreferences.getInstance();
    final start = prefs.getString(_prefKeyQuietStart);
    final end = prefs.getString(_prefKeyQuietEnd);
    return (_parseTime(start), _parseTime(end));
  }

  /// Saves quiet hours locally AND syncs to server.
  /// Pass null for both to CLEAR quiet hours entirely.
  /// ProfileScreen already calls this correctly — no changes needed there.
  static Future<void> setQuietHours(TimeOfDay? start, TimeOfDay? end) async {
    final prefs = await SharedPreferences.getInstance();

    if (start == null || end == null) {
      await prefs.remove(_prefKeyQuietStart);
      await prefs.remove(_prefKeyQuietEnd);
    } else {
      await prefs.setString(
          _prefKeyQuietStart, '${start.hour}:${start.minute}');
      await prefs.setString(_prefKeyQuietEnd, '${end.hour}:${end.minute}');
    }

    // ✅ FIX 2: Sync to server so Django gates FCM sends before they leave
    // the server — reliable on iOS terminated state where client can't run.
    // Non-fatal: client-side isQuietHours() is the fallback if this fails.
    try {
      await ApiService.updateQuietHours(start, end);
    } catch (e) {
      print('⚠️ Failed to sync quiet hours to server: $e');
    }
  }

  /// Public + static so the background isolate handler can also call it.
  static Future<bool> isQuietHours() async {
    final (start, end) = await getQuietHours();
    if (start == null || end == null) return false;

    final now = TimeOfDay.now();
    final nowMins = now.hour * 60 + now.minute;
    final startM = start.hour * 60 + start.minute;
    final endM = end.hour * 60 + end.minute;

    // Correctly handles overnight ranges e.g. 22:00 – 07:00
    if (startM <= endM) {
      return nowMins >= startM && nowMins < endM;
    } else {
      return nowMins >= startM || nowMins < endM;
    }
  }

  static TimeOfDay? _parseTime(String? s) {
    if (s == null) return null;
    final parts = s.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }
}
