import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount =>
      _notifications.where((n) => n['is_read'] == false).length;

  NotificationProvider() {
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final List<String> saved =
        prefs.getStringList('local_notifications') ?? [];

    _notifications =
        saved.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
    _notifications
        .sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n['id'] == id);
    if (index != -1) {
      _notifications[index]['is_read'] = true;
      await _save();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    for (var n in _notifications) {
      n['is_read'] = true;
    }
    await _save();
    notifyListeners();
  }

  Future<void> removeNotification(String id) async {
    _notifications.removeWhere((n) => n['id'] == id);
    await _save();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _notifications = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('local_notifications');
    notifyListeners();
  }

  Future<void> addNotification(Map<String, dynamic> notification) async {
    _notifications.insert(0, notification);
    // Cap at 50 to prevent unbounded growth
    if (_notifications.length > 50) {
      _notifications = _notifications.sublist(0, 50);
    }
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('local_notifications',
        _notifications.map((n) => jsonEncode(n)).toList());
  }
}