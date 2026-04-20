import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Premium haptic vocabulary — on/off toggle, no levels.
///
/// Every tap hits at intentional intensity:
///   selection/nav  → light (crisp)
///   buttonPress    → medium (solid)
///   success        → heavy+medium chord (satisfying)
///   error          → heavy (firm bump)
class AppHaptics {
  AppHaptics._();

  static const _kKey = 'haptics_enabled';
  static const _platform = MethodChannel('app/haptics');
  static bool _enabled = true;
  static bool _loaded = false;

  static bool get enabled => _enabled;

  /// Call once at app start.
  static Future<void> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kKey) ?? true;
    _loaded = true;
  }

  static Future<void> setEnabled({required bool enabled}) async {
    _enabled = enabled;
    if (enabled) await HapticFeedback.mediumImpact(); // instant feedback
    (await SharedPreferences.getInstance()).setBool(_kKey, enabled);
  }

  // ── Core taps ─────────────────────────────────────────────────────────────

  static Future<void> _light() async {
    if (!_loaded) await loadPreference();
    if (!_enabled) return;
    HapticFeedback.lightImpact();
  }

  static Future<void> _medium() async {
    if (!_loaded) await loadPreference();
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
  }

  static Future<void> _heavy() async {
    if (!_loaded) await loadPreference();
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  static Future<void> navTap() => _light();

  // ── Low-intent interactions ───────────────────────────────────────────────
  static Future<void> selection() => _light();
  static Future<void> refresh() => _medium();
  static Future<void> scrollTick() => _light();
  static Future<void> numberReveal() => _medium();
  static Future<void> counterTick() => _light();

  // ── Primary interactions ──────────────────────────────────────────────────
  static Future<void> buttonPress() => _medium();

  // ── Outcome feedback ──────────────────────────────────────────────────────

  /// Multi-pulse chord on Android, fallback to heavy+medium on other.
  static Future<void> success() async {
    if (!_loaded) await loadPreference();
    if (!_enabled) return;

    try {
      await _platform.invokeMethod('success');
    } catch (_) {
      // Fallback
      await _heavy();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await _medium();
    }
  }

  /// Firm bump.
  static Future<void> error() async {
    if (!_loaded) await loadPreference();
    if (!_enabled) return;

    try {
      await _platform.invokeMethod('error');
    } catch (_) {
      await _heavy();
    }
  }

  /// Warning pulse.
  static Future<void> warning() async {
    if (!_loaded) await loadPreference();
    if (!_enabled) return;

    try {
      await _platform.invokeMethod('warning');
    } catch (_) {
      await _medium();
    }
  }

  // ── High-intent confirmation ──────────────────────────────────────────────

  /// Rising triple-tap: medium → 70ms → heavy → 80ms → medium.
  static Future<void> investmentConfirm() async {
    if (!_loaded) await loadPreference();
    if (!_enabled) return;
    await _medium();
    await Future<void>.delayed(const Duration(milliseconds: 70));
    await _heavy();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await _medium();
  }
}
