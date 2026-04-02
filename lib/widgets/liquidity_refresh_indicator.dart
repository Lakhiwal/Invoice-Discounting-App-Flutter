import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

/// A premium pull-to-refresh with a frosted-glass reveal, spring-to-rest
/// loading position, and a haptic chord on completion.
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
    with TickerProviderStateMixin {

  late final AnimationController _waveController;
  late final AnimationController _snapController;

  double _pullDistance = 0.0;
  _RefreshState _state = _RefreshState.idle;

  /// The offset that drives the content translation and indicator height.
  /// During drag phases this is computed live; during refreshing/complete it
  /// is driven by [_snapController] via [_snapAnim].
  double _displayOffset = 0.0;

  /// Rebuilt each time we start a new snap/dismiss animation.
  late Animation<double> _snapAnim;

  static const double _kTriggerThreshold = 120.0;
  static const double _kMaxPull        = 200.0;

  /// The height the indicator rests at while data is loading —
  /// roughly "half-way back" from a full pull.
  static const double _kRestHeight = 72.0;

  double _rubberBand(double pull) {
    if (pull <= 0) return 0;
    return math.pow(pull.clamp(0.0, _kMaxPull), 0.8) * 3.0;
  }

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _snapController = AnimationController(vsync: this);
    _snapAnim = const AlwaysStoppedAnimation(0.0);
  }

  @override
  void dispose() {
    _waveController.dispose();
    _snapController.dispose();
    super.dispose();
  }

  // ── Scroll handling ─────────────────────────────────────────────────────────

  void _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      if (_state == _RefreshState.refreshing || _state == _RefreshState.complete) return;

      final offset = notification.metrics.pixels;
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
        setState(() {
          _pullDistance = 0.0;
          _state = _RefreshState.idle;
        });
      }
    }
  }

  // ── Refresh lifecycle ────────────────────────────────────────────────────────

  Future<void> _triggerRefresh() async {
    // ① Spring from current rubber-band position → _kRestHeight
    final startOffset = _rubberBand(_pullDistance);
    _snapController.duration = const Duration(milliseconds: 400);
    _snapAnim = Tween<double>(begin: startOffset, end: _kRestHeight).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutBack),
    )..addListener(_onSnapValue);

    setState(() {
      _state = _RefreshState.refreshing;
      _displayOffset = startOffset;
    });

    HapticFeedback.heavyImpact();
    await _snapController.forward(from: 0);
    _snapAnim.removeListener(_onSnapValue);

    // ② Hold at rest height while data loads
    if (!mounted) return;
    await widget.onRefresh();
    if (!mounted) return;

    // ③ Success haptic chord: medium → 80ms → light
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    if (mounted) HapticFeedback.lightImpact();

    // ④ Smooth dismiss: _kRestHeight → 0
    _snapController.reset();
    _snapController.duration = const Duration(milliseconds: 320);
    _snapAnim = Tween<double>(begin: _kRestHeight, end: 0).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeInCubic),
    )..addListener(_onSnapValue);

    setState(() => _state = _RefreshState.complete);
    await _snapController.forward(from: 0);
    _snapAnim.removeListener(_onSnapValue);

    if (mounted) {
      setState(() {
        _state = _RefreshState.idle;
        _pullDistance = 0.0;
        _displayOffset = 0.0;
      });
    }
  }

  void _onSnapValue() {
    if (mounted) setState(() => _displayOffset = _snapAnim.value);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Live rubber-band during drag; animation-driven during refresh/complete.
    final offset = (_state == _RefreshState.dragging || _state == _RefreshState.armed)
        ? _rubberBand(_pullDistance)
        : _displayOffset;

    final progress = (_pullDistance / _kTriggerThreshold).clamp(0.0, 1.0);
    final blurSigma = (progress * 15.0).clamp(0.0, 15.0);
    final indicatorOpacity = (offset / 40.0).clamp(0.0, 1.0);

    final isActive = offset > 0;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _handleScrollNotification(notification);
        return false;
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Background orbs (behind the glass) ────────────────────────────
          if (isActive)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: offset,
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, _) {
                    return Stack(
                      children: [
                        _GlowingOrb(
                          color: (widget.color ?? colorScheme.primary)
                              .withValues(alpha: 0.4),
                          size: 150 * progress,
                          offset: Offset(
                            math.sin(_waveController.value * 2 * math.pi) * 30,
                            math.cos(_waveController.value * 2 * math.pi) * 10,
                          ),
                        ),
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

          // ── Content pushed down by current offset ─────────────────────────
          Transform.translate(
            offset: Offset(0, offset),
            child: widget.child,
          ),

          // ── Frosted glass pane ─────────────────────────────────────────────
          if (isActive)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: offset,
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
                          color: (widget.color ?? colorScheme.primary)
                              .withValues(alpha: 0.2 * progress),
                          width: 1,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: indicatorOpacity,
                      child: _RefreshIndicatorContent(
                        state: _state,
                        color: widget.color ?? colorScheme.primary,
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

// ── Indicator content widget ──────────────────────────────────────────────────

class _RefreshIndicatorContent extends StatelessWidget {
  final _RefreshState state;
  final Color color;

  const _RefreshIndicatorContent({required this.state, required this.color});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String label;

    switch (state) {
      case _RefreshState.refreshing:
        icon = Icons.sync_rounded;
        label = 'SYNCING DATA...';
      case _RefreshState.complete:
        icon = Icons.check_circle_rounded;
        label = 'ALL DONE';
      case _RefreshState.armed:
        icon = Icons.unfold_less_rounded;
        label = 'RELEASE TO SYNC';
      default:
        icon = Icons.unfold_more_rounded;
        label = 'PULL TO REFRESH';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        state == _RefreshState.refreshing
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: color,
                  strokeWidth: 2.0,
                ),
              )
            : Icon(icon, color: color, size: 22),
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
    );
  }
}

// ── Glowing orb ───────────────────────────────────────────────────────────────

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
              colors: [color, color.withValues(alpha: 0.0)],
            ),
          ),
        ),
      ),
    );
  }
}
