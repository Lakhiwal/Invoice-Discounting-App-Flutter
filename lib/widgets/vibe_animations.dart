import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// VibeSuccessAnimation
/// A premium, high-fidelity checkmark animation using CustomPainter.
/// Replaces standard Lottie for better performance and 10/10 feel.
/// ─────────────────────────────────────────────────────────────────────────────

class VibeSuccessAnimation extends ConsumerStatefulWidget {
  const VibeSuccessAnimation({
    super.key,
    this.size = 100,
    this.color,
    this.onCompleted,
  });
  final double size;
  final Color? color;
  final VoidCallback? onCompleted;

  @override
  ConsumerState<VibeSuccessAnimation> createState() =>
      _VibeSuccessAnimationState();
}

class _VibeSuccessAnimationState extends ConsumerState<VibeSuccessAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _checkAnim;
  late Animation<double> _circleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _circleAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0, 0.4, curve: Curves.easeOutCubic),
    );

    _checkAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.4, 1, curve: Curves.elasticOut),
    );

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onCompleted?.call();
      }
    });

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _SuccessPainter(
          circleProgress: _circleAnim.value,
          checkProgress: _checkAnim.value,
          color: color,
        ),
      ),
    );
  }
}

class _SuccessPainter extends CustomPainter {
  _SuccessPainter({
    required this.circleProgress,
    required this.checkProgress,
    required this.color,
  });
  final double circleProgress;
  final double checkProgress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Draw background circle
    canvas.drawCircle(center, radius, paint);

    // Draw animated outline
    paint.color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * circleProgress,
      false,
      paint,
    );

    if (checkProgress > 0) {
      final path = Path();
      final p1 = Offset(size.width * 0.25, size.height * 0.5);
      final p2 = Offset(size.width * 0.45, size.height * 0.7);
      final p3 = Offset(size.width * 0.75, size.height * 0.3);

      path.moveTo(p1.dx, p1.dy);

      // Interpolate checkmark points
      if (checkProgress < 0.5) {
        final t = checkProgress * 2;
        path.lineTo(
          p1.dx + (p2.dx - p1.dx) * t,
          p1.dy + (p2.dy - p1.dy) * t,
        );
      } else {
        path.lineTo(p2.dx, p2.dy);
        final t = (checkProgress - 0.5) * 2;
        path.lineTo(
          p2.dx + (p3.dx - p2.dx) * t,
          p2.dy + (p3.dy - p2.dy) * t,
        );
      }

      canvas.drawPath(path, paint..strokeWidth = 6);
    }
  }

  @override
  bool shouldRepaint(covariant _SuccessPainter oldDelegate) => true;
}

/// ─────────────────────────────────────────────────────────────────────────────
/// VibePulseLoading
/// Premium financial loader using circular pulses.
/// ─────────────────────────────────────────────────────────────────────────────

class VibePulseLoading extends ConsumerStatefulWidget {
  const VibePulseLoading({super.key, this.size = 60, this.color});
  final double size;
  final Color? color;

  @override
  ConsumerState<VibePulseLoading> createState() => _VibePulseLoadingState();
}

class _VibePulseLoadingState extends ConsumerState<VibePulseLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _PulsePainter(progress: _ctrl.value, color: color),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < 3; i++) {
      final t = (progress + i / 3.0) % 1.0;
      final opacity = (1.0 - t).clamp(0.0, 1.0);
      final radius = size.width / 2 * t;

      canvas.drawCircle(
        center,
        radius,
        paint..color = color.withValues(alpha: opacity * 0.3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) => true;
}
