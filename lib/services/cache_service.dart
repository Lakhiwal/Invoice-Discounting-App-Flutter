import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// ─────────────────────────────────────────────────────────
/// CacheService
/// ─────────────────────────────────────────────────────────
/// Lightweight persistence layer for "Stale-While-Revalidate"
/// and "Instant-On" loading.
class CacheService {
  static const String _boxName = 'api_cache';
  static late Box _box;

  /// Initialize Hive and the cache box.
  static Future<void> initialize() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  /// Save raw JSON data for a specific endpoint/key.
  static Future<void> save(String key, dynamic data) async {
    final timestamp = DateTime.now().toIso8601String();
    final entry = {
      'data': data,
      'timestamp': timestamp,
    };
    await _box.put(key, jsonEncode(entry));
  }

  /// Retrieve cached JSON data. Returns null if missing.
  static Map<String, dynamic>? get(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Get the age of the cached data in hours.
  static int? getAgeInHours(String key) {
    final entry = get(key);
    if (entry == null) return null;
    final timestamp = DateTime.parse(entry['timestamp']);
    return DateTime.now().difference(timestamp).inHours;
  }

  /// Clear specific cache or entire box.
  static Future<void> clear([String? key]) async {
    if (key != null) {
      await _box.delete(key);
    } else {
      await _box.clear();
    }
  }
}
