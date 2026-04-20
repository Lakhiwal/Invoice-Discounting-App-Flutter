import 'package:flutter/services.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';

/// ─────────────────────────────────────────────────────────
/// VibeHapticsController
/// ─────────────────────────────────────────────────────────
/// Choreographed haptic sequences for a "premium tactile" feel.
/// Uses the existing [AppHaptics] preference system.
class VibeHaptics {
  /// A light, subtle "tick" for scrolling or minor interactions.
  static Future<void> lightTick() async {
    if (!AppHaptics.enabled) return;
    await HapticFeedback.selectionClick();
  }

  /// A firm "thud" for successful major actions (e.g., investment success).
  static Future<void> successThud() async {
    if (!AppHaptics.enabled) return;
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }

  /// A "warning" double-pulse for errors or blocked actions.
  static Future<void> errorAlert() async {
    if (!AppHaptics.enabled) return;
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await HapticFeedback.heavyImpact();
  }

  /// A "cascading" haptic for progress or loading completion.
  static Future<void> ripple() async {
    if (!AppHaptics.enabled) return;
    for (var i = 0; i < 3; i++) {
      await HapticFeedback.lightImpact();
      await Future<void>.delayed(Duration(milliseconds: 50 + (i * 20)));
    }
  }

  /// Tactile feedback for card expansion/contraction.
  static Future<void> spring() async {
    if (!AppHaptics.enabled) return;
    await HapticFeedback.mediumImpact();
  }
}
