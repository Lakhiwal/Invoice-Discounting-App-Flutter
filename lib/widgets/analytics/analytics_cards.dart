import 'package:flutter/material.dart';
import '../../utils/app_haptics.dart';
import '../../widgets/animated_amount_text.dart';
import '../../widgets/pressable.dart';
import 'dart:math' as math;
import '../../theme/ui_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HealthScoreCard extends ConsumerWidget {
  final int score;
  final String label;
  final Color color;
  final List<String> factors;

  const HealthScoreCard({
    super.key,
    required this.score,
    required this.label,
    required this.color,
    required this.factors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final progress = score / 100;

    return Pressable(
      onTap: () => AppHaptics.selection(),
      child: Container(
        padding: const EdgeInsets.all(UI.lg),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(UI.radiusLg),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text('Portfolio health', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 12),
            SizedBox(
              width: 100, height: 100,
              child: CustomPaint(
                painter: GaugePainter(
                  progress: progress,
                  color: color,
                  trackColor: cs.outlineVariant.withValues(alpha: 0.2),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$score', style: TextStyle(color: cs.onSurface, fontSize: 28, fontWeight: FontWeight.w800)),
                      Text(label, style: TextStyle(color: color, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12, runSpacing: 4, alignment: WrapAlignment.center,
              children: factors.map((f) {
                final good = !f.contains('Low') && !f.contains('below') && !f.contains('overdue') && !f.contains('urgent');
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    good ? Icons.check_circle_rounded : Icons.warning_rounded,
                    size: 14,
                    color: good ? const Color(0xFF12B76A) : const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 4),
                  Text(f, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
                ]);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class GaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  GaugePainter({required this.progress, required this.color, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 7.0;

    canvas.drawCircle(center, radius, Paint()..color = trackColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * progress, false,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(GaugePainter old) => old.progress != progress || old.color != color;
}

class MetricCard extends ConsumerWidget {
  final String label;
  final String? value;
  final double? numericValue;
  final String? prefix;
  final String? suffix;
  final Color color;
  final int staggerIndex;

  const MetricCard({
    super.key,
    required this.label,
    this.value,
    this.numericValue,
    this.prefix,
    this.suffix,
    required this.color,
    this.staggerIndex = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        final double delay = staggerIndex * 0.1;
        final double animValue = (val - delay).clamp(0.0, 1.0);
        return Opacity(
          opacity: animValue,
          child: Transform.translate(offset: Offset(0, 15 * (1 - animValue)), child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(UI.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(UI.radiusLg),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
            const SizedBox(height: 4),
            if (numericValue != null)
              AnimatedAmountText(
                value: numericValue!,
                prefix: prefix ?? '', suffix: suffix ?? '',
                style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.w800),
              )
            else
              Text(value ?? '', style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
