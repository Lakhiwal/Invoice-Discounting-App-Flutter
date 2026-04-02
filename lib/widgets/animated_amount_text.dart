import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/formatters.dart';

class AnimatedAmountText extends StatefulWidget {
  final double value;
  final TextStyle style;
  final String prefix;
  final String suffix;
  final bool hideValue;
  final VoidCallback? onCompleted;

  const AnimatedAmountText({
    super.key,
    required this.value,
    required this.style,
    this.prefix = '',
    this.suffix = '',
    this.hideValue = false,
    this.onCompleted,
  });

  @override
  State<AnimatedAmountText> createState() => _AnimatedAmountTextState();
}

class _AnimatedAmountTextState extends State<AnimatedAmountText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  
  static const String _kMasked = '● ●,● ● ●';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
        
    // Always start from 0 on completely fresh load
    _anim = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutExpo),
    );
    
    // Defer the animation lightly to let route transitions clear
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ctrl.addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            widget.onCompleted?.call();
          }
        });
        _ctrl.forward();
      }
    });
  }

  @override
  void didUpdateWidget(AnimatedAmountText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _anim = Tween<double>(begin: oldWidget.value, end: widget.value).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutExpo),
      );
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hideValue) {
      return Text(
        '${widget.prefix}$_kMasked${widget.suffix}',
        style: widget.style.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Text(
        '${widget.prefix}${fmtAmount(_anim.value)}${widget.suffix}',
        style: widget.style.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
