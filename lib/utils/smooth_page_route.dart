import 'package:flutter/material.dart';

/// Custom page route that delegates to the theme's [PageTransitionsTheme]
/// on Android (enabling Predictive Back gesture animation) and uses a
/// smooth fade+slide transition on other platforms.
class SmoothPageRoute<T> extends PageRoute<T> {
  SmoothPageRoute({
    required this.builder,
    this.settings = const RouteSettings(),
  });
  final WidgetBuilder builder;
  @override
  final RouteSettings settings;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) =>
      builder(context);

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 180);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // On Android: delegate to theme's PageTransitionsTheme which uses
    // PredictiveBackPageTransitionsBuilder for predictive back gesture.
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.android) {
      return Theme.of(context).pageTransitionsTheme.buildTransitions<T>(
        this,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }

    // On iOS: use Cupertino-style transition from theme
    if (platform == TargetPlatform.iOS) {
      return Theme.of(context).pageTransitionsTheme.buildTransitions<T>(
        this,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }

    // Other platforms: smooth fade + slide up
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

    // Outgoing page — slight scale-down for spatial depth
    final secondaryScale = Tween<double>(
      begin: 1,
      end: 0.96,
    ).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeIn,
      ),
    );

    final secondaryFade = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(
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
          child: SlideTransition(
            position: slide,
            child: child,
          ),
        ),
      ),
    );
  }
}

class ParallaxSlidePageRoute<T> extends PageRouteBuilder<T> {
  ParallaxSlidePageRoute({required this.builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideIn = Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            );

            final slideOut = Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.35, 0),
            ).animate(
              CurvedAnimation(
                parent: secondaryAnimation,
                curve: Curves.easeOutCubic,
              ),
            );

            final fade = CurvedAnimation(
              parent: animation,
              curve: const Interval(0, 0.6, curve: Curves.easeOut),
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
  final WidgetBuilder builder;
}
