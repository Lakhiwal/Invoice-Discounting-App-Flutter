import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

/// A premium, custom pull-to-refresh widget with a 'Frosted Glass Reveal' effect.
class LiquidityRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? color;
  final double displacement;

  const LiquidityRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.color,
    this.displacement = 40.0,
  });

  @override
  State<LiquidityRefreshIndicator> createState() => _LiquidityRefreshIndicatorState();
}

enum _RefreshState { idle, dragging, armed, refreshing, complete }

class _LiquidityRefreshIndicatorState extends State<LiquidityRefreshIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  double _pullDistance = 0.0;
  _RefreshState _state = _RefreshState.idle;

  static const double _kTriggerThreshold = 120.0;
  static const double _kMaxPull = 200.0;

  double get _dampenedPullDistance {
    if (_state == _RefreshState.refreshing) return widget.displacement + 60;
    if (_pullDistance <= 0) return 0;
    // Apply resistance physics (logarithmic-like damping)
    return math.pow(_pullDistance.clamp(0.0, _kMaxPull), 0.8) * 3.0;
  }

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      if (_state == _RefreshState.refreshing || _state == _RefreshState.complete) return;

      final double offset = notification.metrics.pixels;
      if (offset < 0) {
        setState(() {
          _pullDistance = offset.abs();
          if (_pullDistance >= _kTriggerThreshold) {
            if (_state != _RefreshState.armed) {
              HapticFeedback.mediumImpact();
              _state = _RefreshState.armed;
            }
          } else {
            _state = _RefreshState.dragging;
          }
        });
      } else if (_pullDistance > 0) {
        setState(() {
          _pullDistance = 0.0;
          _state = _RefreshState.idle;
        });
      }
    } else if (notification is ScrollEndNotification) {
      if (_state == _RefreshState.armed) {
        _triggerRefresh();
      } else if (_state != _RefreshState.refreshing) {
        _reset();
      }
    }
  }

  Future<void> _triggerRefresh() async {
    setState(() {
      _state = _RefreshState.refreshing;
      _pullDistance = _kTriggerThreshold;
    });

    HapticFeedback.heavyImpact();
    await widget.onRefresh();

    if (mounted) {
      setState(() {
        _state = _RefreshState.complete;
      });
      await Future.delayed(const Duration(milliseconds: 400));
      _reset();
    }
  }

  void _reset() {
    if (mounted) {
      setState(() {
        _state = _RefreshState.idle;
        _pullDistance = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dampenedDistance = _dampenedPullDistance;
    final progress = (_pullDistance / _kTriggerThreshold).clamp(0.0, 1.0);
    final blurSigma = (progress * 15.0).clamp(0.0, 15.0);
    final indicatorOpacity = (dampenedDistance / 40.0).clamp(0.0, 1.0);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _handleScrollNotification(notification);
        return false;
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Background Orbs (Behind the glass) ─────────────────────────
          if (_pullDistance > 0 || _state == _RefreshState.refreshing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: dampenedDistance,
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, child) {
                    return Stack(
                      children: [
                        // Orb 1: Brand primary
                        _GlowingOrb(
                          color: (widget.color ?? colorScheme.primary)
                              .withValues(alpha: 0.4),
                          size: 150 * progress,
                          offset: Offset(
                            math.sin(_waveController.value * 2 * math.pi) * 30,
                            math.cos(_waveController.value * 2 * math.pi) * 10,
                          ),
                        ),
                        // Orb 2: Complementary accent
                        _GlowingOrb(
                          color: colorScheme.secondary.withValues(alpha: 0.3),
                          size: 100 * progress,
                          offset: Offset(
                            math.cos(_waveController.value * 2 * math.pi) * 50,
                            math.sin(_waveController.value * 2 * math.pi) * 20,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

          // ── Content Translation ────────────────────────────────────────
          Transform.translate(
            offset: Offset(0, dampenedDistance),
            child: widget.child,
          ),

          // ── Frosted Glass Pane ─────────────────────────────────────────
          if (_pullDistance > 0 || _state == _RefreshState.refreshing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: dampenedDistance,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.15),
                      border: Border(
                        bottom: BorderSide(
                          color: (widget.color ?? colorScheme.primary).withValues(alpha: 0.2 * progress),
                          width: 1,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: progress.clamp(0.0, 1.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _state == _RefreshState.refreshing
                                ? Icons.sync_rounded
                                : (_state == _RefreshState.armed ? Icons.unfold_less_rounded : Icons.unfold_more_rounded),
                            color: (widget.color ?? colorScheme.primary),
                            size: 22,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _state == _RefreshState.refreshing
                                ? 'SYNCING DATA...'
                                : (_state == _RefreshState.armed ? 'RELEASE TO SYNC' : 'PULL TO REFRESH'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: (widget.color ?? colorScheme.primary).withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}



class _GlowingOrb extends StatelessWidget {
  final Color color;
  final double size;
  final Offset offset;

  const _GlowingOrb({
    required this.color,
    required this.size,
    required this.offset,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: offset,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color,
                color.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
