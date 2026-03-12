import 'package:flutter/material.dart';

class UI {
  // ── 8dp grid spacing ──
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  // ── radius tokens (Item #9: single source of truth) ──
  static const double radiusSm = 12;
  static const double radiusMd = 20;
  static const double radiusLg = 28;

  static const BorderRadius cardRadius =
  BorderRadius.all(Radius.circular(24)); // matches FintechTheme.cardRadius

  static const BorderRadius sheetRadius =
  BorderRadius.vertical(top: Radius.circular(28));

  // ── animation ──
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 250);

  // Item #35: shared auth gradient colors (used by login, unlock, register, verify_otp)
  static List<Color> authGradient(bool isDark) => isDark
      ? const [Color(0xFF0B1120), Color(0xFF0F1D3A), Color(0xFF0B1120)]
      : const [Color(0xFFF0F5FF), Color(0xFFE8F0FE), Color(0xFFF0F5FF)];
}
