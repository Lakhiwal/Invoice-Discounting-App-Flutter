import 'package:flutter/material.dart';

class AnimatedPage extends StatefulWidget {
  final Widget child;

  const AnimatedPage({super.key, required this.child});

  @override
  State<AnimatedPage> createState() => _AnimatedPageState();
}

class _AnimatedPageState extends State<AnimatedPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late CurvedAnimation _fadeCurve;
  late CurvedAnimation _slideCurve;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeCurve = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideCurve = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _fade = _fadeCurve;
    _slide = Tween(begin: const Offset(0, 0.02), end: Offset.zero)
        .animate(_slideCurve);
    _controller.forward();
  }

  @override
  void dispose() {
    _fadeCurve.dispose();
    _slideCurve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
