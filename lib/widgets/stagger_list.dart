import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  StaggerList
//
//  Wraps a list of widgets so each one fades and slides up with a small
//  stagger delay between items. Makes lists feel alive when they load.
//
//  Usage:
//    StaggerList(
//      children: myCards.map((c) => MyCard(c)).toList(),
//    )
//
//  For existing ListView.builder (e.g. marketplace), use [StaggerItem] on
//  individual items instead:
//    itemBuilder: (_, i) => StaggerItem(index: i, child: MyCard()),
// ─────────────────────────────────────────────────────────────────────────────

class StaggerList extends StatefulWidget {
  final List<Widget> children;

  /// Delay between each item's animation start (ms).
  final int staggerMs;

  /// Slide distance in logical pixels.
  final double slideDistance;

  /// Duration of each item's own animation.
  final Duration itemDuration;

  const StaggerList({
    super.key,
    required this.children,
    this.staggerMs = 40,
    this.slideDistance = 18,
    this.itemDuration = const Duration(milliseconds: 320),
  });

  @override
  State<StaggerList> createState() => _StaggerListState();
}

class _StaggerListState extends State<StaggerList>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _fades;
  late final List<Animation<Offset>> _slides;

  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    final n = widget.children.length;
    _ctrls = List.generate(n,
            (_) => AnimationController(vsync: this, duration: widget.itemDuration));
    _fades = _ctrls
        .map((c) => Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();
    _slides = _ctrls
        .map((c) => Tween<Offset>(
        begin: Offset(0, widget.slideDistance / 400), end: Offset.zero)
        .animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)))
        .toList();

    _startStagger();
  }

  void _startStagger() async {
    for (int i = 0; i < _ctrls.length; i++) {
      await Future.delayed(Duration(milliseconds: widget.staggerMs));
      // FIX #9: check _disposed (set in dispose()) in addition to mounted.
      // Without this, the Future.delayed fires after dispose(), and calling
      // _ctrls[i].forward() on a disposed AnimationController throws
      // a TickerCanceled exception.
      if (_disposed || !mounted) return;
      _ctrls[i].forward();
    }
  }

  @override
  void dispose() {
    _disposed = true; // FIX #9: signal the async loop to stop immediately
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(widget.children.length, (i) {
        return FadeTransition(
          opacity: _fades[i],
          child: SlideTransition(
            position: _slides[i],
            child: widget.children[i],
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  StaggerItem
//
//  For use inside ListView.builder where you can't use StaggerList directly.
//  Each item triggers its own entrance animation based on its [index].
//
//  Usage:
//    ListView.builder(
//      itemBuilder: (_, i) => StaggerItem(
//        index: i,
//        child: MyCard(),
//      ),
//    )
// ─────────────────────────────────────────────────────────────────────────────

class StaggerItem extends StatefulWidget {
  final int index;
  final Widget child;

  /// Cap the stagger delay so late items don't wait too long.
  final int maxDelayMs;
  final int staggerMs;
  final Duration itemDuration;
  final double slideDistance;

  const StaggerItem({
    super.key,
    required this.index,
    required this.child,
    this.maxDelayMs = 280,
    this.staggerMs = 38,
    this.itemDuration = const Duration(milliseconds: 340),
    this.slideDistance = 16,
  });

  @override
  State<StaggerItem> createState() => _StaggerItemState();
}

class _StaggerItemState extends State<StaggerItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  bool _triggered = false;

  // Item #28: track already-animated indices to skip re-animation on revisit
  // (e.g. when IndexedStack brings a tab back into view).
  // Uses a per-type key so different lists don't collide.
  // Capped at 500 entries to prevent unbounded memory growth.
  static final Set<String> _animatedKeys = {};
  static const int _maxAnimatedKeys = 500;

  String get _itemKey => '${widget.key ?? widget.hashCode}_${widget.index}';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.itemDuration);
    _fade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(
        begin: Offset(0, widget.slideDistance / 400), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Item #28: if this item was already animated, skip to end immediately
    if (_animatedKeys.contains(_itemKey)) {
      _ctrl.value = 1.0;
      _triggered = true;
      return;
    }

    final delayMs =
    (widget.index * widget.staggerMs).clamp(0, widget.maxDelayMs);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted && !_triggered) {
        _triggered = true;
        if (_animatedKeys.length >= _maxAnimatedKeys) {
          _animatedKeys.clear();
        }
        _animatedKeys.add(_itemKey);
        _ctrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}