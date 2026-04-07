import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnimatedEmptyState extends ConsumerStatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? color;

  const AnimatedEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.color,
  });

  @override
  ConsumerState<AnimatedEmptyState> createState() => _AnimatedEmptyStateState();
}

class _AnimatedEmptyStateState extends ConsumerState<AnimatedEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.color ?? cs.onSurfaceVariant.withValues(alpha: 0.4);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                final y = math.sin(_ctrl.value * 2 * math.pi) * 8.0;
                final scale = 1.0 + math.sin(_ctrl.value * 2 * math.pi) * 0.03;
                final rot = _ctrl.value * 2 * math.pi;

                return Transform.translate(
                  offset: Offset(0, y),
                  child: Transform.scale(
                    scale: scale,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Rotating background ring
                        Transform.rotate(
                          angle: rot,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color.withValues(alpha: 0.1),
                                width: 2,
                                strokeAlign: BorderSide.strokeAlignOutside,
                              ),
                            ),
                          ),
                        ),
                        // Pulsing glow
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.15),
                                blurRadius: 40,
                                spreadRadius: 10 * scale,
                              ),
                            ],
                          ),
                        ),
                        Icon(widget.icon, size: 64, color: color),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                widget.subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          if (widget.actionLabel != null && widget.onAction != null) ...[
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: widget.onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                widget.actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
