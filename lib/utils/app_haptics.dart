import 'package:flutter/services.dart';
import 'package:invoice_discounting_app/utils/vibration_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AppHaptics — semantic haptic vocabulary
//
//  Every method checks VibrationHelper.getLevel() and scales intensity
//  accordingly:
//    Off    → no haptic
//    Subtle → one step lighter than intended
//    Normal → intended level
//    Strong → one step heavier than intended
// ─────────────────────────────────────────────────────────────────────────────

class AppHaptics {
  AppHaptics._();

  // ── Internal level-aware tap ──────────────────────────────────────────────

  // Item #7: cached vibration level — updated by refreshLevel()
  static VibrationLevel _cachedLevel = VibrationLevel.normal;
  static bool _levelLoaded = false;

  /// Call once at app start and whenever the user changes vibration settings.
  static Future<void> refreshLevel() async {
    _cachedLevel = await VibrationHelper.getLevel();
    _levelLoaded = true;
  }

  static Future<void> _tap(int baseLevel) async {
    if (!_levelLoaded) await refreshLevel(); // first call only
    final level = _cachedLevel;
    if (level == VibrationLevel.off) return;

    int adjusted = baseLevel;
    if (level == VibrationLevel.subtle) adjusted = (baseLevel - 1).clamp(0, 3);
    if (level == VibrationLevel.strong) adjusted = (baseLevel + 1).clamp(0, 3);

    switch (adjusted) {
      case 0:
        return HapticFeedback.selectionClick();
      case 1:
        return HapticFeedback.lightImpact();
      case 2:
        return HapticFeedback.mediumImpact();
      default:
        return HapticFeedback.heavyImpact();
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  static Future<void> navTap() => _tap(0);

  // ── Low-intent interactions ───────────────────────────────────────────────
  static Future<void> selection() => _tap(0);
  static Future<void> refresh() => _tap(1);
  static Future<void> scrollTick() => _tap(0);

  // FIX: numberReveal was intentionally silent (`async {}`), which meant
  // loading data gave zero physical feedback. Users couldn't tell if the
  // app had responded to their action.
  //
  // Now fires a single light impact — subtle enough not to be annoying on
  // every refresh, but present enough to confirm "your data just arrived".
  // Respects the user's vibration level setting like every other method.
  static Future<void> numberReveal() => _tap(1);

  // ── Counter milestone tick ────────────────────────────────────────────────
  // Called by _AnimatedCounter at 25/50/75/100% milestones during count-up.
  // Uses selectionClick (level 0) — the lightest possible feedback.
  // At "Subtle" setting this still fires (clamp keeps it at 0).
  // At "Off" it correctly skips (the _tap guard handles that).
  static Future<void> counterTick() => _tap(0);

  // ── Primary interactions ──────────────────────────────────────────────────
  static Future<void> buttonPress() => _tap(1);

  // ── Outcome feedback ──────────────────────────────────────────────────────

  /// Double-tap chord: medium → 110ms → light.
  static Future<void> success() async {
    if (!_levelLoaded) await refreshLevel();
    if (_cachedLevel == VibrationLevel.off) return;
    await _tap(2);
    await Future.delayed(const Duration(milliseconds: 110));
    await _tap(1);
  }

  /// Single firm bump for errors.
  static Future<void> error() => _tap(3);

  // ── High-intent confirmation ──────────────────────────────────────────────

  /// Rising triple-tap: light → 70ms → medium → 90ms → light.
  static Future<void> investmentConfirm() async {
    if (!_levelLoaded) await refreshLevel();
    if (_cachedLevel == VibrationLevel.off) return;
    await _tap(1);
    await Future.delayed(const Duration(milliseconds: 70));
    await _tap(2);
    await Future.delayed(const Duration(milliseconds: 90));
    await _tap(1);
  }
}