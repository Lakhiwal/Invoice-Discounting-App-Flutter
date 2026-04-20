import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';

enum PaymentStatus { processing, success, failed }

class PaymentStatusScreen extends ConsumerStatefulWidget {
  const PaymentStatusScreen({
    required this.status,
    super.key,
    this.onDismiss,
  });
  final PaymentStatus status;
  final VoidCallback? onDismiss;

  @override
  ConsumerState<PaymentStatusScreen> createState() =>
      _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends ConsumerState<PaymentStatusScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.status != PaymentStatus.processing) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          widget.onDismiss?.call();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: widget.status != PaymentStatus.processing,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          widget.onDismiss?.call();
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: switch (widget.status) {
                    PaymentStatus.processing => const _ProcessingAnimation(),
                    PaymentStatus.success => const _SuccessAnimation(),
                    PaymentStatus.failed => const _FailedAnimation(),
                  },
                ),
                const SizedBox(height: 40),
                Text(
                  _getTitle(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getSubtitle(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (widget.status == PaymentStatus.failed) ...[
                  const SizedBox(height: 28),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onDismiss?.call();
                    },
                    child: const Text('Go Back'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTitle() => switch (widget.status) {
        PaymentStatus.processing => 'Processing Payment',
        PaymentStatus.success => 'Payment Successful',
        PaymentStatus.failed => 'Payment Failed',
      };

  String _getSubtitle() => switch (widget.status) {
        PaymentStatus.processing => 'Please wait, this may take a few seconds',
        PaymentStatus.success => 'Your E-Collect balance has been updated',
        PaymentStatus.failed => 'Something went wrong. Please try again',
      };
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROCESSING — Gradient arc spinner + breathing ₹ center
// ═══════════════════════════════════════════════════════════════════════════════

class _ProcessingAnimation extends ConsumerStatefulWidget {
  const _ProcessingAnimation();

  @override
  ConsumerState<_ProcessingAnimation> createState() => _ProcessingState();
}

class _ProcessingState extends ConsumerState<_ProcessingAnimation>
    with TickerProviderStateMixin {
  late AnimationController _spinCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _arcCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _arcCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // Haptic: subtle tick on mount to confirm screen appeared
    AppHaptics.selection();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _pulseCtrl.dispose();
    _arcCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge([_spinCtrl, _pulseCtrl, _arcCtrl]),
      builder: (_, __) => CustomPaint(
        painter: _ProcessingPainter(
          spin: _spinCtrl.value,
          pulse: _pulseCtrl.value,
          arc: _arcCtrl.value,
          primary: colorScheme.primary,
          surface: colorScheme.surfaceContainerHighest,
        ),
        child: Center(
          child: _RupeeSymbol(
            color: colorScheme.primary
                .withValues(alpha: 0.45 + _pulseCtrl.value * 0.35),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _ProcessingPainter extends CustomPainter {
  _ProcessingPainter({
    required this.spin,
    required this.pulse,
    required this.arc,
    required this.primary,
    required this.surface,
  });
  final double spin;
  final double pulse;
  final double arc;
  final Color primary;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // Outer track ring
    canvas.drawCircle(
      c,
      maxR - 8,
      Paint()
        ..color = surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    // Outer gradient arc
    final outerArcRect = Rect.fromCircle(center: c, radius: maxR - 8);
    const sweepAngle = math.pi * 0.8;
    final startAngle = spin * 2 * math.pi;

    final outerArcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: [primary, primary.withValues(alpha: 0)],
        stops: const [0.0, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(outerArcRect);

    canvas.drawArc(outerArcRect, startAngle, sweepAngle, false, outerArcPaint);

    // Head dot with glow
    final dotPos = Offset(
      c.dx + (maxR - 8) * math.cos(startAngle),
      c.dy + (maxR - 8) * math.sin(startAngle),
    );
    canvas.drawCircle(
      dotPos,
      6,
      Paint()
        ..color = primary.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(dotPos, 3.5, Paint()..color = primary);

    // Inner ring (counter-clockwise)
    canvas.drawCircle(
      c,
      maxR - 22,
      Paint()
        ..color = surface.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: maxR - 22),
      -arc * 2 * math.pi,
      math.pi * 0.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = primary.withValues(alpha: 0.4),
    );

    // Center breathing circle
    final centerR = maxR * (0.28 + pulse * 0.04);

    canvas.drawCircle(
      c,
      centerR + 10,
      Paint()
        ..color = primary.withValues(alpha: 0.06 + pulse * 0.04)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(
      c,
      centerR,
      Paint()..color = primary.withValues(alpha: 0.08 + pulse * 0.04),
    );
    canvas.drawCircle(
      c,
      centerR,
      Paint()
        ..color = primary.withValues(alpha: 0.15 + pulse * 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_ProcessingPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUCCESS — Ring draw → fill → checkmark → particle burst
// ═══════════════════════════════════════════════════════════════════════════════

class _SuccessAnimation extends ConsumerStatefulWidget {
  const _SuccessAnimation();

  @override
  ConsumerState<_SuccessAnimation> createState() => _SuccessState();
}

class _SuccessState extends ConsumerState<_SuccessAnimation>
    with TickerProviderStateMixin {
  late AnimationController _ringCtrl;
  late AnimationController _fillCtrl;
  late AnimationController _checkCtrl;
  late AnimationController _burstCtrl;
  late Animation<double> _ringSweep;
  late Animation<double> _fillScale;
  late Animation<double> _checkDraw;
  late Animation<double> _burstProg;

  @override
  void initState() {
    super.initState();

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _ringSweep = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeInOut);

    _fillCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fillScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1.08), weight: 65),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1), weight: 35),
    ]).animate(CurvedAnimation(parent: _fillCtrl, curve: Curves.easeOut));

    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _checkDraw =
        CurvedAnimation(parent: _checkCtrl, curve: Curves.easeOutCubic);

    _burstCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _burstProg = CurvedAnimation(parent: _burstCtrl, curve: Curves.easeOut);

    // Chain with haptics
    _ringCtrl.forward().then((_) {
      if (!mounted) return;
      AppHaptics.selection(); // ring complete
      _fillCtrl.forward().then((_) {
        if (!mounted) return;
        AppHaptics.success(); // fill pop — double-tap chord
        _checkCtrl.forward();
        _burstCtrl.forward();
      });
    });
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _fillCtrl.dispose();
    _checkCtrl.dispose();
    _burstCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation:
            Listenable.merge([_ringSweep, _fillScale, _checkDraw, _burstProg]),
        builder: (_, __) => CustomPaint(
          painter: _SuccessPainter(
            ringSweep: _ringSweep.value,
            fillScale: _fillScale.value,
            checkDraw: _checkDraw.value,
            burstProg: _burstProg.value,
          ),
        ),
      );
}

class _SuccessPainter extends CustomPainter {
  _SuccessPainter({
    required this.ringSweep,
    required this.fillScale,
    required this.checkDraw,
    required this.burstProg,
  });
  final double ringSweep;
  final double fillScale;
  final double checkDraw;
  final double burstProg;

  static const _green = Color(0xFF12B76A);
  static const _greenDark = Color(0xFF0B8A49);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = size.width * 0.42;

    // ── Ring stroke ──────────────────────────────────────────
    if (ringSweep > 0 && fillScale <= 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: maxR),
        -math.pi / 2,
        ringSweep * 2 * math.pi,
        false,
        Paint()
          ..color = _green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── Circle fill ──────────────────────────────────────────
    if (fillScale > 0) {
      final fr = maxR * fillScale;

      // Shadow
      canvas.drawCircle(
        Offset(c.dx, c.dy + 3),
        fr,
        Paint()
          ..color = _greenDark.withValues(alpha: 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );

      // Gradient
      canvas.drawCircle(
        c,
        fr,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_green, _greenDark],
          ).createShader(Rect.fromCircle(center: c, radius: fr)),
      );

      // Inner highlight
      canvas.drawCircle(
        c,
        fr,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.3),
            radius: 0.8,
            colors: [
              Colors.white.withValues(alpha: 0.14),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: fr)),
      );
    }

    // ── Particle burst ───────────────────────────────────────
    if (burstProg > 0) {
      final burstR = maxR * (1.0 + burstProg * 0.8);
      final alpha = (1.0 - burstProg).clamp(0.0, 1.0);

      for (var i = 0; i < 12; i++) {
        final angle = (i / 12) * 2 * math.pi - math.pi / 2;
        final dist = burstR + (i.isEven ? 0 : maxR * 0.1);
        final pos = Offset(
          c.dx + dist * math.cos(angle),
          c.dy + dist * math.sin(angle),
        );
        final dotR = (i.isEven ? 3.0 : 2.0) * (1 - burstProg * 0.5);
        canvas.drawCircle(
          pos,
          dotR,
          Paint()..color = _green.withValues(alpha: alpha * 0.6),
        );
      }
    }

    // ── Checkmark ────────────────────────────────────────────
    if (checkDraw > 0 && fillScale > 0) {
      final cr = maxR * fillScale;

      final checkPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = cr * 0.15 // thicker for visibility
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // Checkmark geometry — well-centered, proportional
      //  ↘ from top-left area to bottom-center
      //  ↗ from bottom-center to top-right area
      final sx = c.dx - cr * 0.30; // start left
      final sy = c.dy + cr * 0.0;
      final mx = c.dx - cr * 0.05; // bottom middle
      final my = c.dy + cr * 0.26;
      final ex = c.dx + cr * 0.33; // end right
      final ey = c.dy - cr * 0.26;

      final path = Path()..moveTo(sx, sy);

      // Segment 1: ↘ (0 → 0.38)
      final s1 = (checkDraw / 0.38).clamp(0.0, 1.0);
      path.lineTo(sx + (mx - sx) * s1, sy + (my - sy) * s1);

      // Segment 2: ↗ (0.33 → 1.0) — slight overlap for fluid feel
      if (checkDraw > 0.33) {
        final s2 = ((checkDraw - 0.33) / 0.67).clamp(0.0, 1.0);
        path.lineTo(mx + (ex - mx) * s2, my + (ey - my) * s2);
      }

      canvas.drawPath(path, checkPaint);
    }
  }

  @override
  bool shouldRepaint(_SuccessPainter old) =>
      old.ringSweep != ringSweep ||
      old.fillScale != fillScale ||
      old.checkDraw != checkDraw ||
      old.burstProg != burstProg;
}

// ═══════════════════════════════════════════════════════════════════════════════
// FAILED — Ring draw → fill → X → shake + pulse ring
// ═══════════════════════════════════════════════════════════════════════════════

class _FailedAnimation extends ConsumerStatefulWidget {
  const _FailedAnimation();

  @override
  ConsumerState<_FailedAnimation> createState() => _FailedState();
}

class _FailedState extends ConsumerState<_FailedAnimation>
    with TickerProviderStateMixin {
  late AnimationController _ringCtrl;
  late AnimationController _fillCtrl;
  late AnimationController _xCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _pulseCtrl;

  late Animation<double> _ringSweep;
  late Animation<double> _fillScale;
  late Animation<double> _xDraw;
  late Animation<double> _shake;

  @override
  void initState() {
    super.initState();

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _ringSweep = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeInOut);

    _fillCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fillScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1.06), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1), weight: 40),
    ]).animate(CurvedAnimation(parent: _fillCtrl, curve: Curves.easeOut));

    _xCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _xDraw = CurvedAnimation(parent: _xCtrl, curve: Curves.easeOutCubic);

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -12), weight: 12),
      TweenSequenceItem(tween: Tween(begin: -12, end: 12), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 12, end: -8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -8, end: 5), weight: 22),
      TweenSequenceItem(tween: Tween(begin: 5, end: 0), weight: 28),
    ]).animate(_shakeCtrl);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Chain with haptics
    _ringCtrl.forward().then((_) {
      if (!mounted) return;
      _fillCtrl.forward().then((_) {
        if (!mounted) return;
        AppHaptics.error(); // firm bump on fill
        _xCtrl.forward().then((_) {
          if (!mounted) return;
          AppHaptics.error(); // second bump when X completes + shake starts
          _shakeCtrl.forward();
          _pulseCtrl.forward();
        });
      });
    });
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _fillCtrl.dispose();
    _xCtrl.dispose();
    _shakeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge(
          [_ringSweep, _fillScale, _xDraw, _shake, _pulseCtrl],
        ),
        builder: (_, __) => Transform.translate(
          offset: Offset(_shake.value, 0),
          child: CustomPaint(
            painter: _FailedPainter(
              ringSweep: _ringSweep.value,
              fillScale: _fillScale.value,
              xDraw: _xDraw.value,
              pulseProg: _pulseCtrl.value,
            ),
          ),
        ),
      );
}

class _FailedPainter extends CustomPainter {
  _FailedPainter({
    required this.ringSweep,
    required this.fillScale,
    required this.xDraw,
    required this.pulseProg,
  });
  final double ringSweep;
  final double fillScale;
  final double xDraw;
  final double pulseProg;

  static const _red = Color(0xFFEF4444);
  static const _redDark = Color(0xFFDC2626);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = size.width * 0.42;

    // ── Pulse ring ───────────────────────────────────────────
    if (pulseProg > 0) {
      final pulseR = maxR * (1.0 + pulseProg * 0.35);
      final alpha = (1.0 - pulseProg).clamp(0.0, 1.0);
      canvas.drawCircle(
        c,
        pulseR,
        Paint()
          ..color = _red.withValues(alpha: alpha * 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // ── Ring stroke ──────────────────────────────────────────
    if (ringSweep > 0 && fillScale <= 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: maxR),
        -math.pi / 2,
        ringSweep * 2 * math.pi,
        false,
        Paint()
          ..color = _red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── Circle fill ──────────────────────────────────────────
    if (fillScale > 0) {
      final fr = maxR * fillScale;

      canvas.drawCircle(
        Offset(c.dx, c.dy + 3),
        fr,
        Paint()
          ..color = _redDark.withValues(alpha: 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );

      canvas.drawCircle(
        c,
        fr,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_red, _redDark],
          ).createShader(Rect.fromCircle(center: c, radius: fr)),
      );

      canvas.drawCircle(
        c,
        fr,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.3),
            radius: 0.8,
            colors: [
              Colors.white.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: fr)),
      );
    }

    // ── X mark ───────────────────────────────────────────────
    if (xDraw > 0 && fillScale > 0) {
      final xr = maxR * fillScale;
      final arm = xr * 0.28;

      final xPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = xr * 0.14 // thicker for weight
        ..strokeCap = StrokeCap.round;

      // Stroke 1: ╲ (0 → 0.5)
      final s1 = (xDraw / 0.5).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(c.dx - arm, c.dy - arm),
        Offset(c.dx - arm + arm * 2 * s1, c.dy - arm + arm * 2 * s1),
        xPaint,
      );

      // Stroke 2: ╱ (0.45 → 1.0) — slight overlap
      if (xDraw > 0.45) {
        final s2 = ((xDraw - 0.45) / 0.55).clamp(0.0, 1.0);
        canvas.drawLine(
          Offset(c.dx + arm, c.dy - arm),
          Offset(c.dx + arm - arm * 2 * s2, c.dy - arm + arm * 2 * s2),
          xPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FailedPainter old) =>
      old.ringSweep != ringSweep ||
      old.fillScale != fillScale ||
      old.xDraw != xDraw ||
      old.pulseProg != pulseProg;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ₹ Symbol Widget — uses TextPainter for a crisp, proper glyph
// ═══════════════════════════════════════════════════════════════════════════════

class _RupeeSymbol extends ConsumerWidget {
  const _RupeeSymbol({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Text(
        '₹',
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      );
}
