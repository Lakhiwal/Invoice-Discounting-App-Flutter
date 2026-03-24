import 'package:flutter/material.dart';

/// A page route optimised for Hero fly + slide-up content.
///
/// The Hero widget animates independently (Flutter handles that).
/// The rest of the page fades in and slides up from a slight offset,
/// giving the CRED / Google Pay feel of content rising behind
/// the flying avatar.
///
/// Duration is slightly longer than SmoothPageRoute (320ms vs 220ms)
/// so the avatar has room to travel smoothly across the screen.
class HeroPageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  HeroPageRoute({
    required this.builder,
    super.settings,
  }) : super(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) {
      return builder(context);
    },
    transitionsBuilder:
        (context, animation, secondaryAnimation, child) {
      // Incoming: fade + slide up (content rises behind the Hero)
      final fade = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.15, 1.0, curve: Curves.easeOut),
      );

      // Outgoing: subtle scale-down for depth
      final secondaryScale = Tween<double>(
        begin: 1.0,
        end: 0.96,
      ).animate(CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeIn,
      ));

      final secondaryFade = Tween<double>(
        begin: 1.0,
        end: 0.85,
      ).animate(CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ));

      return ScaleTransition(
        scale: secondaryScale,
        child: FadeTransition(
          opacity: fade,
          child: child,
        ),
      );
    },
  );
}