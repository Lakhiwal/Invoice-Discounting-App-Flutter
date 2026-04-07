import 'package:flutter/material.dart';
import '../utils/formatters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnimatedAmountText extends ConsumerStatefulWidget {
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
  ConsumerState<AnimatedAmountText> createState() => _AnimatedAmountTextState();
}

class _AnimatedAmountTextState extends ConsumerState<AnimatedAmountText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  
  // 10/10 FIX: cache the last value globally per widget key to prevent 
  // "counting from zero" when slivers are rebuilt during scroll.
  static final Map<Key?, double> _lastSeenValues = {};
  
  static const String _kMasked = '● ●,● ● ●';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));

    final lastValue = _lastSeenValues[widget.key] ?? 0.0;
    
    _anim = Tween<double>(begin: lastValue, end: widget.value).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutExpo),
    );
    
    _lastSeenValues[widget.key] = widget.value;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ctrl.addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            widget.onCompleted?.call();
          }
        });
        if (lastValue != widget.value) {
          _ctrl.forward();
        }
      }
    });
  }

  @override
  void didUpdateWidget(AnimatedAmountText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _lastSeenValues[widget.key] = widget.value;
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
