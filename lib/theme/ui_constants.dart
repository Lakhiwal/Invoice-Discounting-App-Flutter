import 'package:flutter/material.dart';

class UI {
  // ── 8dp grid spacing ──
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  // ── radius tokens (sharpened for a crisp fintech aesthetic) ──
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(8));

  static const BorderRadius sheetRadius =
      BorderRadius.vertical(top: Radius.circular(16));

  // ── animation ──
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 250);

  // ── shared auth gradient ──
  static List<Color> authGradient(bool isDark) => isDark
      ? const [Color(0xFF050508), Color(0xFF0D121F)]
      : const [Color(0xFFF8FAFF), Color(0xFFFFFFFF)];
}
