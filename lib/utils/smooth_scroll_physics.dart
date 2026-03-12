import 'package:flutter/material.dart';

class SmoothScrollPhysics extends ClampingScrollPhysics {
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