import 'package:flutter/services.dart';

class RefreshRateController {

  static const _channel = MethodChannel("app/display");

  static Future<void> setMax() async {
    try {
      await _channel.invokeMethod("setRefreshMode", {"mode": "max"});
    } catch (_) {}
  }

  static Future<void> set60Hz() async {
    try {
      await _channel.invokeMethod("setRefreshMode", {"mode": "60"});
    } catch (_) {}
  }
}