import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FastScrollbar extends ConsumerStatefulWidget {
  final ScrollController controller;
  final int itemCount;

  const FastScrollbar({
    super.key,
    required this.controller,
    required this.itemCount,
  });

  @override
  ConsumerState<FastScrollbar> createState() => FastScrollbarState();
}

class FastScrollbarState extends ConsumerState<FastScrollbar> with SingleTickerProviderStateMixin {
  bool _visible = false;
  bool _dragging = false;
  double _thumbFraction = 0;
  int _lastHapticIndex = -1;
  Timer? _hideTimer;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  static const double _thumbH = 46;
  static const double _hitWidth = 32;

  void show() {
    if (!mounted) return;
    setState(() => _visible = true);
    _fadeCtrl.forward();
    _scheduleHide();
  }

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_onScroll);
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_dragging || !mounted) return;
    final pos = widget.controller.position;
    final fraction = (pos.pixels / pos.maxScrollExtent).clamp(0.0, 1.0);
    setState(() => _thumbFraction = fraction);
    if (!_visible) show();
    else _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_dragging) return;
    _hideTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _fadeCtrl.reverse();
        setState(() => _visible = false);
      }
    });
  }

  void _onDragUpdate(DragUpdateDetails details, double maxHeight) {
    if (!mounted) return;
    final pos = details.localPosition.dy.clamp(0.0, maxHeight);
    final fraction = pos / maxHeight;
    setState(() {
      _thumbFraction = fraction;
      _dragging = true;
    });
    
    final targetPixel = fraction * widget.controller.position.maxScrollExtent;
    widget.controller.jumpTo(targetPixel);
    
    final index = (fraction * widget.itemCount).floor().clamp(0, widget.itemCount - 1);
    if (index != _lastHapticIndex) {
      _lastHapticIndex = index;
      AppHaptics.scrollTick();
    }
    show();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _fadeAnim,
      child: IgnorePointer(
        ignoring: !_visible,
        child: GestureDetector(
          onVerticalDragStart: (_) => setState(() => _dragging = true),
          onVerticalDragUpdate: (d) => _onDragUpdate(d, MediaQuery.of(context).size.height * 0.6),
          onVerticalDragEnd: (_) {
            setState(() => _dragging = false);
            _scheduleHide();
          },
          child: Container(
            width: _hitWidth,
            color: Colors.transparent,
            alignment: Alignment.topRight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                return Stack(
                  children: [
                    Positioned(
                      top: _thumbFraction * (h - _thumbH),
                      right: 4,
                      child: Container(
                        width: 4,
                        height: _thumbH,
                        decoration: BoxDecoration(color: cs.primary.withValues(alpha: _dragging ? 1.0 : 0.5), borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
