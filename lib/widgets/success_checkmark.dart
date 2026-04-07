import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── SuccessCheckmark ──────────────────────────────────────────────────────────
//
// Two-phase animation shown after a successful investment:
//   Phase 1 (0–400ms): Circle + checkmark scale in with elastic bounce
//   Phase 2 (400–900ms): Checkmark path "draws on" with easeOut
//
// Usage:
//   if (_isSuccess) SuccessCheckmark(color: AppColors.emerald, size: 64)

class SuccessCheckmark extends ConsumerStatefulWidget {
  final Color color;
  final double size;

  const SuccessCheckmark({
    super.key,
    required this.color,
    this.size = 64,
  });

  @override
  ConsumerState<SuccessCheckmark> createState() => _SuccessCheckmarkState();
}

class _SuccessCheckmarkState extends ConsumerState<SuccessCheckmark>
    with TickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final AnimationController _drawCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _draw;

  @override
  void initState() {
    super.initState();

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _drawCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut),
    );
    _draw = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _drawCtrl, curve: Curves.easeOut),
    );

    // Chain: scale in first, then draw the tick
    _scaleCtrl.forward().then((_) => _drawCtrl.forward());
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _drawCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleCtrl, _drawCtrl]),
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _CheckPainter(
              progress: _draw.value,
              color: widget.color,
              strokeWidth: widget.size * 0.075,
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  const _CheckPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - strokeWidth / 2;

    // Circle (always full — scale handles the entrance)
    canvas.drawCircle(c, r, paint);

    if (progress <= 0) return;

    // Checkmark path: p1 → p2 (short diagonal down) → p3 (longer diagonal up)
    final p1 = Offset(size.width * 0.27, size.height * 0.50);
    final p2 = Offset(size.width * 0.43, size.height * 0.66);
    final p3 = Offset(size.width * 0.73, size.height * 0.36);

    final seg1 = (p2 - p1).distance;
    final seg2 = (p3 - p2).distance;
    final total = seg1 + seg2;
    final drawn = total * progress;

    final path = Path()..moveTo(p1.dx, p1.dy);

    if (drawn <= seg1) {
      final t = drawn / seg1;
      path.lineTo(
        p1.dx + (p2.dx - p1.dx) * t,
        p1.dy + (p2.dy - p1.dy) * t,
      );
    } else {
      path.lineTo(p2.dx, p2.dy);
      final rem = (drawn - seg1) / seg2;
      path.lineTo(
        p2.dx + (p3.dx - p2.dx) * rem.clamp(0.0, 1.0),
        p2.dy + (p3.dy - p2.dy) * rem.clamp(0.0, 1.0),
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}
