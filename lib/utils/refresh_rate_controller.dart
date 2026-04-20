
class RefreshRateController {

  /// Frame rate is now handled automatically at the native level
  /// for a consistent 120Hz premium experience.
  static Future<void> setMax() async {
    // No-op: Native MainActivity.java now handles this on launch
  }
}
