import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Pressable
//
//  A tap target that scales its child down on press and springs back on
//  release. Gives every tappable element a physical, tactile quality.
//
//  Usage:
//    Pressable(
//      onTap: () { ... },
//      child: MyCard(),
//    )
//
//  Parameters:
//    scale   — how far it compresses. 0.96 is the default (4% smaller).
//              Use 0.98 for large cards, 0.94 for small chips.
//    haptic  — set false when the caller handles haptics manually.
//    enabled — when false the widget is inert (no visual change).
// ─────────────────────────────────────────────────────────────────────────────

class Pressable extends ConsumerStatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  final bool enabled;
  final Duration downDuration;
  final Duration upDuration;
  final Curve upCurve;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.965,
    this.haptic = false, // most callers set their own haptics
    this.enabled = true,
    this.downDuration = const Duration(milliseconds: 75),
    this.upDuration = const Duration(milliseconds: 240),
    this.upCurve = Curves.elasticOut,
  });

  @override
  ConsumerState<Pressable> createState() => _PressableState();
}

class _PressableState extends ConsumerState<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.downDuration);
    _scaleAnim = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!widget.enabled || widget.onTap == null) return;
    _ctrl.animateTo(1.0, duration: widget.downDuration, curve: Curves.easeOut);
  }

  void _onTapUp(TapUpDetails _) {
    _spring();
  }

  void _onTapCancel() {
    _spring();
  }

  void _spring() {
    _ctrl.animateTo(
      0.0,
      duration: widget.upDuration,
      curve: widget.upCurve,
    );
  }

  void _onTap() {
    if (!widget.enabled) return;
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: _onTap,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
