import 'package:flutter/material.dart';

class UI {
  // ── 8dp grid spacing ──
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  // ── radius tokens (tightened for cleaner look) ──
  static const double radiusSm = 8;
  static const double radiusMd = 14;
  static const double radiusLg = 20;

  static const BorderRadius cardRadius =
  BorderRadius.all(Radius.circular(20));

  static const BorderRadius sheetRadius =
  BorderRadius.vertical(top: Radius.circular(20));

  // ── animation ──
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 250);

  // ── shared auth gradient ──
  static List<Color> authGradient(bool isDark) => isDark
      ? const [Color(0xFF000000), Color(0xFF0A0A0A), Color(0xFF000000)]
      : const [Color(0xFFFFFFFF), Color(0xFFF5F5F5), Color(0xFFFFFFFF)];
}