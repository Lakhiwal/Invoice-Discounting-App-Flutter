import 'package:flutter/material.dart';

// Uses BouncingScrollPhysics as parent for the premium iOS-style overscroll
// feel on all platforms, while preserving the tuned fling velocity range.
class SmoothScrollPhysics extends BouncingScrollPhysics {
  const SmoothScrollPhysics({super.parent});

  @override
  SmoothScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SmoothScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get minFlingVelocity => 20;

  @override
  double get maxFlingVelocity => 8000;
}