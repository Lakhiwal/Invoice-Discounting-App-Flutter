import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:invoice_discounting_app/main.dart';
import 'package:invoice_discounting_app/screens/invoice_detail_screen.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Background handler — top-level function, runs in a separate isolate.
// FCM calls this when the app is in background/terminated.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  if (await NotificationService.isQuietHours()) {
    return;
  }

  // Save to local storage for the Notification Center
  await NotificationService.saveNotificationLocally(message);

  // Handle data-only messages (no notification key) — show manually
  final data = message.data;
  if (message.notification == null && data.isNotEmpty) {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await plugin.show(
      id: message.hashCode,
      title: (data['title'] ?? 'New Alert').toString(),
      body: (data['body'] ?? '').toString(),
      notificationDetails: const NotificationDetails(
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
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _prefKeyPush = 'push_enabled';
  static const String _prefKeyQuietStart = 'quiet_start';
  static const String _prefKeyQuietEnd = 'quiet_end';
  static const String _prefKeyLocalStore = 'local_notifications';

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
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse: _onNotificationTapped,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      try {
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          handleDeepLink(initialMessage.data);
        }
      } catch (e) {
        debugPrint('NotificationService error: $e');
      }

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        handleDeepLink(message.data);
      });

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      _messaging.onTokenRefresh.listen((token) async {
        if (await isPushEnabled()) {
          await ApiService.registerFcmToken(token);
        }
      });
    } catch (e) {
      debugPrint('NotificationService error: $e');
    }
  }

  // ─────────────────────────── DEEP LINK ─────────────────────────────────

  static Future<void> handleDeepLink(Map<String, dynamic> data) async {
    try {
      final type = data['type'];
      final invoiceIdStr = data['invoice_id'];

      if (type == 'new_invoice' && invoiceIdStr != null) {
        final invoiceId = int.tryParse(invoiceIdStr.toString());
        if (invoiceId == null) return;

        final invoice = await ApiService.getInvoiceDetail(invoiceId);
        if (invoice == null) return;

        unawaited(
          navigatorKey.currentState?.push(
            SmoothPageRoute<void>(
              builder: (_) => InvoiceDetailScreen.fromMap(
                invoice,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      assert(() {
        debugPrint('Deep link error: $e');
        return true;
      }());
    }
  }

  // ────────────────────────── FOREGROUND ─────────────────────────────────

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    try {
      if (!await isPushEnabled()) return;

      if (await isQuietHours()) {
        return;
      }

      // Save to local storage
      await saveNotificationLocally(message);

      final invoiceId = message.data['invoice_id'] ?? '';
      final type = message.data['type'] ?? '';
      final payload = '$type|$invoiceId';

      final title = message.notification?.title ??
          (message.data['title'] as String?) ??
          'New Alert';
      final body =
          message.notification?.body ?? (message.data['body'] as String?) ?? '';

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
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificationService error: $e');
    }
  }

  @pragma('vm:entry-point')
  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || !payload.contains('|')) return;
    final parts = payload.split('|');
    handleDeepLink({'type': parts[0], 'invoice_id': parts[1]});
  }

  // ────────────────────────── LOCAL STORAGE ──────────────────────────────

  static Future<void> saveNotificationLocally(RemoteMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefKeyLocalStore) ?? [];

      final notificationData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': message.notification?.title ??
            (message.data['title'] as String?) ??
            'New Alert',
        'body': message.notification?.body ??
            (message.data['body'] as String?) ??
            '',
        'type': message.data['type'] ?? 'system',
        'invoice_id': message.data['invoice_id'],
        'timestamp': DateTime.now().toIso8601String(),
        'is_read': false,
      };

      saved.add(jsonEncode(notificationData));

      // Keep only last 50 notifications
      if (saved.length > 50) {
        saved.removeRange(0, saved.length - 50);
      }

      await prefs.setStringList(_prefKeyLocalStore, saved);
    } catch (e) {
      debugPrint('NotificationService error: $e');
    }
  }

  // ──────────────────────────── PERMISSION ───────────────────────────────

  static Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      return false;
    }
  }

  static Future<void> revokePermission() async {
    try {
      await _messaging.unsubscribeFromTopic('investors');
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('NotificationService error: $e');
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
        debugPrint('NotificationService error: $e');
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

  static Future<void> setQuietHours(TimeOfDay? start, TimeOfDay? end) async {
    final prefs = await SharedPreferences.getInstance();

    if (start == null || end == null) {
      await prefs.remove(_prefKeyQuietStart);
      await prefs.remove(_prefKeyQuietEnd);
    } else {
      await prefs.setString(
        _prefKeyQuietStart,
        '${start.hour}:${start.minute}',
      );
      await prefs.setString(_prefKeyQuietEnd, '${end.hour}:${end.minute}');
    }

    try {
      await ApiService.updateQuietHours(start, end);
    } catch (e) {
      debugPrint('NotificationService error: $e');
    }
  }

  static Future<bool> isQuietHours() async {
    final (start, end) = await getQuietHours();
    if (start == null || end == null) return false;

    final now = TimeOfDay.now();
    final nowMins = now.hour * 60 + now.minute;
    final startM = start.hour * 60 + start.minute;
    final endM = end.hour * 60 + end.minute;

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

  // ──────────────────────── SMART LIQUIDITY ──────────────────────────────

  /// Simulates a smart liquidity alert for high-yield invoices matching
  /// the user's historical investment patterns.
  static Future<void> sendSmartLiquidityAlert({
    required int invoiceId,
    required String company,
    required double annualReturn,
  }) async {
    try {
      if (!await isPushEnabled() || await isQuietHours()) return;

      final message = RemoteMessage(
        data: {
          'type': 'new_invoice',
          'invoice_id': invoiceId.toString(),
          'title': '⚡ Smart Match Found',
          'body':
              'A high-yield invoice from $company ($annualReturn% p.a.) matches your portfolio pattern. Invest now!',
        },
      );

      // Save locally first
      await saveNotificationLocally(message);

      // Show local push
      await _localNotifications.show(
        id: invoiceId.hashCode,
        title: '⚡ Smart Match Found',
        body: 'Invest in $company at $annualReturn% p.a. - tailored for you.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'smart_liquidity',
            'Smart Liquidity Alerts',
            channelDescription: 'Targeted high-yield invoice matches',
            importance: Importance.max,
            priority: Priority.max,
            color: Color(0xFF6366F1), // Indigo primary
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.critical,
          ),
        ),
        payload: 'new_invoice|$invoiceId',
      );
    } catch (e) {}
  }
}
