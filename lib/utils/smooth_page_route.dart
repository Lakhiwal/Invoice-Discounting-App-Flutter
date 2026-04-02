import 'package:flutter/material.dart';

class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  SmoothPageRoute({
    required this.builder,
    super.settings,
  }) : super(
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) {
      return builder(context);
    },
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Incoming page: fade + slight slide up
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );

      final slide = Tween<Offset>(
        begin: const Offset(0, 0.03),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
      );

      // Item #30: outgoing page — slight scale-down for spatial depth
      final secondaryScale = Tween<double>(
        begin: 1.0,
        end: 0.96,
      ).animate(
        CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeIn,
        ),
      );

      final secondaryFade = Tween<double>(
        begin: 1.0,
        end: 0.0,
      ).animate(
        CurvedAnimation(
          parent: secondaryAnimation,
          curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
        ),
      );

      return ScaleTransition(
        scale: secondaryScale,
        child: FadeTransition(
          opacity: secondaryFade.drive(Tween(begin: 1.0, end: 0.85)),
          child: FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

class ParallaxSlidePageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  ParallaxSlidePageRoute({required this.builder, super.settings})
      : super(
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slideIn = Tween<Offset>(
        begin: const Offset(1.0, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ));

      final slideOut = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.35, 0),
      ).animate(CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
      ));

      final fade = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      );

      return SlideTransition(
        position: slideOut,
        child: SlideTransition(
          position: slideIn,
          child: FadeTransition(
            opacity: fade,
            child: child,
          ),
        ),
      );
    },
  );
}
