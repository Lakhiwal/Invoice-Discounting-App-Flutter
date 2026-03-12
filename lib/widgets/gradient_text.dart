import 'package:flutter/material.dart';

// ── GradientText ──────────────────────────────────────────────────────────────
//
// Renders text with a horizontal gradient using ShaderMask.
// Used on ROI %, total invested, and key financial numbers.
//
// Predefined gradients:
//   GradientText.emerald  — green to teal   (ROI, returns)
//   GradientText.blue     — blue shimmer    (total invested, hero numbers)
//   GradientText.amber    — gold shimmer    (yields, maturity amounts)
//
// Usage:
//   GradientText(
//     '₹ 2.45L',
//     gradient: GradientText.blue,
//     style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
//   )

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient gradient;

  // ── Named presets ─────────────────────────────────────────────────────────

  static const Gradient blue = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFB8D4FF)],
  );

  static const Gradient emerald = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF6EE7C7)],
  );

  static const Gradient amber = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFFDE68A)],
  );

  static const Gradient primary = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF93C5FD)],
  );

  const GradientText(
    this.text, {
    super.key,
    this.style,
    this.gradient = GradientText.blue,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(text, style: style),
    );
  }
}
