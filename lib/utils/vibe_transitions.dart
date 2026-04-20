import 'package:flutter/material.dart';

class VibePageTransitionsBuilder extends PageTransitionsBuilder {
  const VibePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // ── Incoming Page Animation ──────────────────────────────────────────────
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    final slide =
        Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    );

    // ── Outgoing Page Animation (Spatial Depth) ──────────────────────────────
    final secondaryScale = Tween<double>(begin: 1, end: 0.96).animate(
      CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn),
    );
    final secondaryFade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Interval(0, 0.5, curve: Curves.easeIn),
      ),
    );

    return ScaleTransition(
      scale: secondaryScale,
      child: FadeTransition(
        opacity: secondaryFade.drive(Tween(begin: 1, end: 0.85)),
        child: FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: child),
        ),
      ),
    );
  }
}
