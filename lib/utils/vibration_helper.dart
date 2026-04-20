import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-app vibration preference levels.
enum VibrationLevel { off, subtle, normal, strong }

/// iOS-style haptic helper backed by the `haptic_feedback` package.
///
/// ── pubspec.yaml ─────────────────────────────────────────────────────────────
///   dependencies:
///     haptic_feedback: ^0.6.4+3
///
/// ── Design philosophy ────────────────────────────────────────────────────────
///
///   "All of them feel pretty strong" → the fix is to use the haptic_feedback
///   package only for semantic confirmation events (success / error), and for
///   everything else drop back to Flutter's built-in HapticFeedback which maps
///   directly to the lightest system primitives — equivalent to iOS
///   UISelectionFeedbackGenerator, which is the subtlest tap Apple exposes.
///
///   Normal level target feel:
///     • Everyday taps (nav, refresh, toggle) → barely-there click,
///       like iPhone keyboard keys or scroll wheel detents
///     • Success                               → soft single confirmation
///     • Error                                 → two light pulses
///
/// ── Pattern → intent mapping ─────────────────────────────────────────────────
///
///   [0, 6]  @ 55            → tick         (nav, filter chips, tab switches)
///   [0, 8]  @ 60            → tick         (button taps, refresh, toggles)
///   [0, 10–12] @ 60–70      → selection    (heavier taps, calculator)
///   [0, 15, 60, 10] @ 80…   → soft         (success — invest, login, password)
///   [0, 20, 50, 15] @ 100…  → light        (error — auth fail, wrong password)
///
/// ── Level ladder ─────────────────────────────────────────────────────────────
///
///   Subtle → one step down from Normal mapping
///   Normal → as above
///   Strong → one step up from Normal mapping

class VibrationHelper {
  VibrationHelper._();

  static const String _kLevelKey = 'vibration_level';

  // FIX #19: in-memory cache so vibrate() doesn't hit SharedPreferences on
  // every haptic call. Previously getLevel() did SharedPreferences.getInstance()
  // on every tap — dozens of async reads per second on interactive screens.
  // The cache is initialised lazily on first call and updated in setLevel().
  static VibrationLevel? _cachedLevel;

  // ── Public API ────────────────────────────────────────────────────────────

  static const List<VibrationLevel> levels = VibrationLevel.values;

  static String levelLabel(VibrationLevel level) {
    switch (level) {
      case VibrationLevel.off:
        return 'Off';
      case VibrationLevel.subtle:
        return 'Subtle';
      case VibrationLevel.normal:
        return 'Normal';
      case VibrationLevel.strong:
        return 'Strong';
    }
  }

  static String levelSubtitle(VibrationLevel level) {
    switch (level) {
      case VibrationLevel.off:
        return 'No haptic feedback';
      case VibrationLevel.subtle:
        return 'Softer — one step lighter than intended';
      case VibrationLevel.normal:
        return 'Balanced — recommended (default)';
      case VibrationLevel.strong:
        return 'Punchier — one step heavier than intended';
    }
  }

  static Future<VibrationLevel> getLevel() async {
    // FIX #19: serve from memory cache when available
    if (_cachedLevel != null) return _cachedLevel!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLevelKey) ?? 'normal';
    _cachedLevel = _fromString(raw);
    return _cachedLevel!;
  }

  static VibrationLevel get cachedLevel =>
      _cachedLevel ?? VibrationLevel.normal;

  static Future<void> setLevel(VibrationLevel level) async {
    // FIX #19: update both cache and persistent storage
    _cachedLevel = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLevelKey, _toString(level));
  }

  static Future<void> vibrate({
    required List<int> pattern,
    required List<int> intensities,
  }) async {
    final canVibrate = await Haptics.canVibrate();
    if (!canVibrate) return;

    final level = await getLevel();
    if (level == VibrationLevel.off) return;

    final base = _inferType(pattern, intensities);
    final type = _applyLevel(base, level);

    await Haptics.vibrate(type);
  }

  // ── Pattern → semantic type ───────────────────────────────────────────────
  //
  // Ladder used internally (lightest → heaviest):
  //   tick → selection → soft → light → medium → heavy → rigid
  //
  // "tick" is HapticsType.selection run through the system's lightest
  // path — on iOS this is UISelectionFeedbackGenerator, on Android API 30+
  // it uses PRIMITIVE_TICK which is the smallest primitive available.

  static const List<HapticsType> _ladder = [
    HapticsType.selection, // used as "tick" — lightest available
    HapticsType.soft,
    HapticsType.light,
    HapticsType.medium,
    HapticsType.heavy,
    HapticsType.rigid,
  ];

  static HapticsType _inferType(List<int> pattern, List<int> intensities) {
    // Error: double-pulse, high intensity — [0,20,50,15] @ [0,100,0,70]
    if (pattern.length >= 4 &&
        pattern[1] >= 18 &&
        intensities.any((i) => i >= 90)) {
      return HapticsType.light; // was medium — still too strong
    }

    // Success: double-pulse, mid intensity — [0,15,60,10] @ [0,80,0,50]
    if (pattern.length >= 4 &&
        pattern[1] >= 12 &&
        intensities.any((i) => i >= 70 && i < 90)) {
      return HapticsType.soft; // was light — still too strong
    }

    // Heavier single tap — [0,10–12] @ [0,60–70]
    if (pattern.length == 2 && pattern[1] >= 9) {
      return HapticsType.selection; // was soft
    }

    // Everything else: nav taps, button taps, refresh
    // [0,6] @ 55  and  [0,8] @ 60
    return HapticsType.selection; // lightest available
  }

  // ── Level shift ───────────────────────────────────────────────────────────

  static HapticsType _applyLevel(HapticsType base, VibrationLevel level) {
    if (level == VibrationLevel.normal) return base;

    final idx = _ladder.indexOf(base);
    if (idx == -1) return base;

    if (level == VibrationLevel.subtle) {
      // Floor at selection — can't go lighter
      return _ladder[(idx - 1).clamp(0, _ladder.length - 1)];
    }
    if (level == VibrationLevel.strong) {
      return _ladder[(idx + 1).clamp(0, _ladder.length - 1)];
    }

    return base;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static VibrationLevel _fromString(String s) {
    switch (s) {
      case 'off':
        return VibrationLevel.off;
      case 'subtle':
        return VibrationLevel.subtle;
      case 'strong':
        return VibrationLevel.strong;
      default:
        return VibrationLevel.normal;
    }
  }

  static String _toString(VibrationLevel level) {
    switch (level) {
      case VibrationLevel.off:
        return 'off';
      case VibrationLevel.subtle:
        return 'subtle';
      case VibrationLevel.normal:
        return 'normal';
      case VibrationLevel.strong:
        return 'strong';
    }
  }
}
