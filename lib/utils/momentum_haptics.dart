import 'package:flutter/services.dart';

/// A utility to trigger tactile "pips" during high-speed scrolling.
/// This mimics a mechanical click/haptic sensation when momentum is high.
class MomentumHaptics {
  double _lastPosition = 0;
  double _accumulatedDelta = 0;
  DateTime _lastTime = DateTime.now();
  
  /// The distance interval (in pixels) between haptic "pips".
  final double interval;
  
  /// The minimum velocity (pixels/sec) required to trigger haptics.
  final double velocityThreshold;

  MomentumHaptics({
    this.interval = 120.0,
    this.velocityThreshold = 1500.0,
  });

  /// Processes a scroll update and triggers haptics if conditions are met.
  void onScroll(double pixels) {
    final now = DateTime.now();
    final dt = now.difference(_lastTime).inMicroseconds / 1000000.0;
    
    if (dt <= 0) return;

    final delta = (pixels - _lastPosition).abs();
    final velocity = delta / dt;

    if (velocity > velocityThreshold) {
      _accumulatedDelta += delta;
      
      if (_accumulatedDelta >= interval) {
        _accumulatedDelta = 0;
        // Trigger a very light selection click
        HapticFeedback.selectionClick();
      }
    } else {
      // Reset accumulation if scrolling slowly to prevent "late" pips
      _accumulatedDelta = 0;
    }

    _lastPosition = pixels;
    _lastTime = now;
  }
}
