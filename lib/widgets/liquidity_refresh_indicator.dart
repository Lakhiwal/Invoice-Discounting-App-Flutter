import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

/// Pull-to-refresh with a frosted-glass reveal, spring-to-rest loading dock,
/// and a haptic chord on completion.
///
/// Behaviour
/// ─────────
///  1. Pull  →  rubber-band physics (live, no animation lag)
///  2. Release at threshold  →  content springs back to a rest height
///  3. While [onRefresh] is running  →  spinner stays at rest height
///  4. Done  →  medium + light haptic chord, then smooth dismiss
class LiquidityRefreshIndicator extends ConsumerStatefulWidget {
  const LiquidityRefreshIndicator({
    required this.child,
    required this.onRefresh,
    super.key,
    this.color,
  });
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? color;

  @override
  ConsumerState<LiquidityRefreshIndicator> createState() =>
      _LiquidityRefreshIndicatorState();
}

enum _RefreshState { idle, dragging, armed, refreshing, complete }

class _LiquidityRefreshIndicatorState
    extends ConsumerState<LiquidityRefreshIndicator>
    with TickerProviderStateMixin {
  // ── Controllers ─────────────────────────────────────────────────────────────

  /// Drives the orb animation (repeating wave).
  late final AnimationController _waveCtrl;

  /// Drives the spring-to-rest and dismiss height transitions.
  late final AnimationController _snapCtrl;

  /// The tween applied to [_snapCtrl] — swapped each phase.
  Tween<double> _snapTween = Tween<double>(begin: 0, end: 0);

  // ── Drag state ───────────────────────────────────────────────────────────────

  double _pullDistance = 0;
  _RefreshState _state = _RefreshState.idle;
  bool _halfwayTickFired = false;

  /// Locks refresh trigger so it can't be re-entered.
  bool _refreshing = false;

  // ── Constants ────────────────────────────────────────────────────────────────

  static const double _kTriggerThreshold = 120;
  static const double _kMaxPull = 200;

  /// Height the indicator rests at while data loads — roughly "half-way back".
  static const double _kRestHeight = 72;

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Logarithmic rubber-band: feels physical without going too far.
  double _rubberBand(double pull) =>
      math.pow(pull.clamp(0.0, _kMaxPull), 0.8) * 3.0;

  /// The pixel offset that drives both the content translation and indicator
  /// height.  Called from inside [AnimatedBuilder] every frame — no setState
  /// needed for animation-driven changes.
  double _computeOffset() {
    switch (_state) {
      case _RefreshState.idle:
        return 0;
      case _RefreshState.dragging:
      case _RefreshState.armed:
        return _rubberBand(_pullDistance);
      case _RefreshState.refreshing:
        final t = Curves.easeOutBack.transform(_snapCtrl.value.clamp(0.0, 1.0));
        return _snapTween.transform(t);
      case _RefreshState.complete:
        final t = Curves.easeInCubic.transform(_snapCtrl.value.clamp(0.0, 1.0));
        return _snapTween.transform(t);
    }
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _snapCtrl = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _snapCtrl.dispose();
    super.dispose();
  }

  // ── Scroll handling ──────────────────────────────────────────────────────────

  void _onScroll(ScrollNotification n) {
    if (n is ScrollUpdateNotification) {
      // Never interrupt an active refresh.
      if (_state == _RefreshState.refreshing ||
          _state == _RefreshState.complete) {
        return;
      }

      final pixels = n.metrics.pixels;
      if (pixels < 0) {
        final pull = pixels.abs();

        // 50% threshold tick (Premium mechanical feel)
        if (pull >= _kTriggerThreshold / 2 && !_halfwayTickFired) {
          _halfwayTickFired = true;
          HapticFeedback.lightImpact();
        }

        if (pull >= _kTriggerThreshold && _state != _RefreshState.armed) {
          HapticFeedback.mediumImpact();
          setState(() {
            _pullDistance = pull;
            _state = _RefreshState.armed;
          });
        } else {
          setState(() {
            _pullDistance = pull;
            if (_state != _RefreshState.armed) _state = _RefreshState.dragging;
          });
        }
      } else if (_pullDistance > 0) {
        setState(() {
          _pullDistance = 0;
          _state = _RefreshState.idle;
          _halfwayTickFired = false;
        });
      }
    } else if (n is ScrollEndNotification) {
      if (_state == _RefreshState.armed) {
        _triggerRefresh();
      } else if (_state == _RefreshState.dragging) {
        setState(() {
          _pullDistance = 0;
          _state = _RefreshState.idle;
          _halfwayTickFired = false;
        });
      }
    }
  }

  // ── Refresh lifecycle ────────────────────────────────────────────────────────

  Future<void> _triggerRefresh() async {
    if (_refreshing) return;
    _refreshing = true;

    // ① Transition to refreshing — snapshot the current rubber-band height so
    //    we can spring FROM it.
    final startOffset = _rubberBand(_pullDistance);
    _snapTween = Tween<double>(begin: startOffset, end: _kRestHeight);
    _snapCtrl.duration = const Duration(milliseconds: 420);

    setState(() => _state = _RefreshState.refreshing);
    HapticFeedback.heavyImpact();

    // Animate 0→1 (spring to rest).  .orCancel ensures the await resolves
    // even if the widget is disposed mid-animation.
    try {
      await _snapCtrl.forward(from: 0).orCancel;
    } on TickerCanceled {
      _refreshing = false;
      return;
    }

    if (!mounted) {
      _refreshing = false;
      return;
    }

    // ② Hold at rest height while data is loading.
    try {
      await widget.onRefresh();
    } catch (_) {
      // Never let a refresh error crash the indicator.
    }

    if (!mounted) {
      _refreshing = false;
      return;
    }

    // ③ Success haptic chord: medium → 80 ms → light.
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) {
      _refreshing = false;
      return;
    }
    HapticFeedback.lightImpact();

    // ④ Dismiss: animate _kRestHeight → 0.
    _snapTween = Tween<double>(begin: _kRestHeight, end: 0);
    _snapCtrl.duration = const Duration(milliseconds: 340);
    setState(() => _state = _RefreshState.complete);

    try {
      await _snapCtrl.forward(from: 0).orCancel;
    } on TickerCanceled {
      _refreshing = false;
      return;
    }

    _refreshing = false;
    if (mounted) {
      setState(() {
        _state = _RefreshState.idle;
        _pullDistance = 0;
        _halfwayTickFired = false;
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.color ?? cs.primary;

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        _onScroll(n);
        return false;
      },
      // AnimatedBuilder listens to both controllers and redraws every frame
      // — no setState needed inside animation callbacks.
      child: AnimatedBuilder(
        animation: Listenable.merge([_waveCtrl, _snapCtrl]),
        builder: (context, _) {
          final offset = _computeOffset();
          final dragProgress =
              (_pullDistance / _kTriggerThreshold).clamp(0.0, 1.0);
          final showIndicator = offset > 0;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Glowing orbs ─────────────────────────────────────────────
              if (showIndicator)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: offset,
                  child: ClipRect(
                    child: Stack(
                      children: [
                        _GlowingOrb(
                          color: color.withValues(alpha: 0.4),
                          size: 150 * dragProgress,
                          offset: Offset(
                            math.sin(_waveCtrl.value * 2 * math.pi) * 30,
                            math.cos(_waveCtrl.value * 2 * math.pi) * 10,
                          ),
                        ),
                        _GlowingOrb(
                          color: cs.secondary.withValues(alpha: 0.3),
                          size: 100 * dragProgress,
                          offset: Offset(
                            math.cos(_waveCtrl.value * 2 * math.pi) * 50,
                            math.sin(_waveCtrl.value * 2 * math.pi) * 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Content ──────────────────────────────────────────────────
              Transform.translate(
                offset: Offset(0, offset),
                child: widget.child,
              ),

              // ── Frosted glass + indicator ─────────────────────────────────
              if (showIndicator)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: offset,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(
                        sigmaX: (dragProgress * 15).clamp(0, 15),
                        sigmaY: (dragProgress * 15).clamp(0, 15),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.15),
                          border: Border(
                            bottom: BorderSide(
                              color:
                                  color.withValues(alpha: 0.2 * dragProgress),
                            ),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Opacity(
                          opacity: (offset / 40.0).clamp(0.0, 1.0),
                          child: _IndicatorContent(state: _state, color: color),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Indicator label / icon ────────────────────────────────────────────────────

class _IndicatorContent extends ConsumerWidget {
  const _IndicatorContent({required this.state, required this.color});
  final _RefreshState state;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String label;
    final Widget icon;

    switch (state) {
      case _RefreshState.refreshing:
        label = 'SYNCING DATA...';
        icon = SizedBox(
          width: 24,
          height: 24,
          child: LoadingAnimationWidget.hexagonDots(
            color: color,
            size: 24,
          ),
        );
      case _RefreshState.complete:
        label = 'ALL DONE';
        icon = Icon(AppIcons.check, color: color, size: 22);
      case _RefreshState.armed:
        label = 'RELEASE TO SYNC';
        icon = Icon(AppIcons.unfoldLess, color: color, size: 22);
      case _RefreshState.idle:
      case _RefreshState.dragging:
        label = 'PULL TO REFRESH';
        icon = Icon(AppIcons.unfoldMore, color: color, size: 22);
    }

    return Padding(
      padding: const EdgeInsets.only(
        top: 8,
      ), // Provide consistent padding for indicator elements
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Glowing orb ───────────────────────────────────────────────────────────────

class _GlowingOrb extends ConsumerWidget {
  const _GlowingOrb({
    required this.color,
    required this.size,
    required this.offset,
  });
  final Color color;
  final double size;
  final Offset offset;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
        child: Transform.translate(
          offset: offset,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      );
}
