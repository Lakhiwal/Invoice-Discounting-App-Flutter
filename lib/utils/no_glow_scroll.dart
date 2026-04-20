import 'package:flutter/material.dart';
import 'package:invoice_discounting_app/utils/smooth_scroll_physics.dart';

class NoGlowScrollBehavior extends ScrollBehavior {
  const NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const SmoothScrollPhysics();
}
