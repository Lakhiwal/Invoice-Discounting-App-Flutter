import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:invoice_discounting_app/screens/unlock_screen.dart';
import '../utils/app_haptics.dart';

import '../utils/smooth_page_route.dart';
import 'analytics_screen.dart';
import 'home_screen.dart';
import 'marketplace_screen.dart';
import 'portfolio_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const platform = MethodChannel('widget_navigation');

  static const int _tabCount = 4;
  int _currentIndex = 0;
  late final List<Widget> _tabs;
  DateTime? _backgroundTime;
  static const _lockTimeout = Duration(seconds: 300);

  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    _tabCount,
    (_) => GlobalKey<NavigatorState>(),
  );

  final List<AnimationController> _tabControllers = [];
  final List<Animation<double>> _tabFades = [];
  final List<Animation<Offset>> _tabSlides = [];

  // Tab observers to trigger rebuilds for Predictive Back canPop state
  late final List<NavigatorObserver> _observers;

  @override
  void initState() {
    super.initState();
    _currentIndex = 0;
    _observers = List.generate(
        _tabCount,
        (_) => _TabNavigatorObserver(() {
              if (mounted) setState(() {});
            }));
    WidgetsBinding.instance.addObserver(this);
    _tabs = List.generate(_tabCount, _buildTabNavigator);

    for (int i = 0; i < _tabCount; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      );
      _tabFades.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: ctrl, curve: Curves.easeOut),
        ),
      );
      _tabSlides.add(
        Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut)),
      );
      _tabControllers.add(ctrl);
    }
    _tabControllers[0].value = 1.0;

    platform.setMethodCallHandler((call) async {
      if (call.method == 'openTab' && call.arguments == 'marketplace') {
        _changeTab(1);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final ctrl in _tabControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundTime = DateTime.now();
    }

    if (state == AppLifecycleState.resumed) {
      if (_backgroundTime == null) return;
      final difference = DateTime.now().difference(_backgroundTime!);
      if (difference > _lockTimeout) {
        Navigator.pushAndRemoveUntil(
          context,
          SmoothPageRoute(builder: (_) => const UnlockScreen()),
          (route) => false,
        );
      }
    }
  }

  void _changeTab(int index) {
    if (_currentIndex == index) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final previousIndex = _currentIndex;
    setState(() => _currentIndex = index);

    _tabControllers[previousIndex].reverse();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tabControllers[index].forward(from: 0);
    });
  }

  Widget _buildTabNavigator(int index) {
    const screens = [
      HomeScreen(),
      MarketplaceScreen(),
      PortfolioScreen(),
      AnalyticsScreen(),
    ];

    return Navigator(
      key: _navigatorKeys[index],
      observers: [_observers[index]],
      onGenerateRoute: (settings) => SmoothPageRoute(
        builder: (_) => screens[index],
        settings: settings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final currentNav = _navigatorKeys[_currentIndex].currentState;
    final bool canPopNested = currentNav?.canPop() ?? false;
    final bool isHome = _currentIndex == 0;
    final bool canExit = !canPopNested && isHome;

    return PopScope(
      canPop: canExit,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (canPopNested) {
          currentNav?.pop();
        } else if (!isHome) {
          _changeTab(0);
        }
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: List.generate(_tabCount, (i) {
            final active = i == _currentIndex;
            return IgnorePointer(
              ignoring: !active,
              child: TickerMode(
                enabled: active || _tabControllers[i].value > 0,
                child: RepaintBoundary(
                  child: FadeTransition(
                    opacity: _tabFades[i],
                    child: SlideTransition(
                      position: _tabSlides[i],
                      child: _tabs[i],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        bottomNavigationBar: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Material(
              color: cs.surfaceContainer.withValues(alpha: 0.8),
              elevation: 0,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    0,
                    2,
                    0,
                    MediaQuery.of(context).padding.bottom,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _NavItem(
                            icon: Icons.home_outlined,
                            activeIcon: Icons.home_rounded,
                            label: 'Home',
                            index: 0,
                            current: _currentIndex,
                            onTap: _changeTab),
                      ),
                      Expanded(
                        child: _NavItem(
                            icon: Icons.storefront_outlined,
                            activeIcon: Icons.storefront_rounded,
                            label: 'Market',
                            index: 1,
                            current: _currentIndex,
                            onTap: _changeTab),
                      ),
                      Expanded(
                        child: _NavItem(
                            icon: Icons.pie_chart_outline_rounded,
                            activeIcon: Icons.pie_chart_rounded,
                            label: 'Portfolio',
                            index: 2,
                            current: _currentIndex,
                            onTap: _changeTab),
                      ),
                      Expanded(
                        child: _NavItem(
                            icon: Icons.bar_chart_outlined,
                            activeIcon: Icons.bar_chart_rounded,
                            label: 'Analytics',
                            index: 3,
                            current: _currentIndex,
                            onTap: _changeTab),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav item — M3 Navigation Bar indicator
// Animations: bounce/scale pop, outlined↔filled crossfade, pill width expand
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends ConsumerStatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int current;
  final Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  ConsumerState<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends ConsumerState<_NavItem> with TickerProviderStateMixin {
  // ── Main activation controller (pill + crossfade) ──
  late final AnimationController _ctrl;
  late final CurvedAnimation _curve;

  // ── Bounce controller (scale pop on tap) ──
  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceAnim;

  void _showLabel(BuildContext context) {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: position.dx + size.width / 2 - 30 + 10,
        top: position.dy - 30,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.inverseSurface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 9,
                color: Theme.of(context).colorScheme.onInverseSurface,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 1), entry.remove);
  }

  @override
  void initState() {
    super.initState();

    // Main activation animation (drives pill width + crossfade + colors)
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    if (widget.index == widget.current) _ctrl.value = 1.0;

    // Bounce: quick scale pop using a spring-like sequence
    // 1.0 → 1.18 → 0.95 → 1.0  (overshoot then settle)
    _bounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.18, end: 0.95)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.95, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
    ]).animate(_bounceCtrl);
  }

  @override
  void didUpdateWidget(_NavItem old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current) {
      if (widget.index == widget.current) {
        // Becoming active: play both activation + bounce
        _ctrl.forward(from: 0.0);
        _bounceCtrl.forward(from: 0.0);
      } else if (widget.index == old.current) {
        // Becoming inactive: reverse activation, no bounce
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _ctrl.dispose();
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = widget.index == widget.current;

    final activeIconColor = cs.onPrimaryContainer;
    final inactiveIconColor = cs.onSurfaceVariant;
    final activeLabelColor = cs.onPrimaryContainer;
    final inactiveLabelColor = cs.onSurfaceVariant;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_ctrl, _bounceCtrl]),
        builder: (context, _) {
          final t = _curve.value;
          final bounce = _bounceAnim.value;

          final iconColor = Color.lerp(
            inactiveIconColor,
            activeIconColor,
            Curves.easeOut.transform(t),
          )!;

          final labelColor = Color.lerp(
            inactiveLabelColor,
            activeLabelColor,
            Curves.easeOut.transform(t),
          )!;

          // Pill width: 0 → 64 driven by t
          final pillWidth = 64.0 * t;

          // Icon vertical shift: nudge up 2px when active
          final iconYOffset = -1.0 * t;

          return Semantics(
            label: widget.label,
            button: true,
            selected: active,
            child: GestureDetector(
              onTapDown: (_) {
                _bounceCtrl.forward(from: 0.0);
              },
              onTap: () async {
                await AppHaptics.navTap();
                widget.onTap(widget.index);
              },
              onLongPress: () => _showLabel(context),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 64,
                height: 64,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Icon + pill container ──
                    SizedBox(
                      width: 64,
                      height: 28,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Pill indicator with width animation
                          if (t > 0)
                            Opacity(
                              opacity: t.clamp(0.0, 1.0),
                              child: Container(
                                width: pillWidth,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: Color.lerp(cs.secondaryContainer,
                                      cs.onSurface, 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),

                          // Icon with bounce scale + vertical shift
                          Transform.translate(
                            offset: Offset(0, iconYOffset),
                            child: Transform.scale(
                              scale: bounce,
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Outlined icon (fades out)
                                    Opacity(
                                      opacity: (1.0 - t).clamp(0.0, 1.0),
                                      child: Icon(
                                        widget.icon,
                                        color: iconColor,
                                        size: 24,
                                      ),
                                    ),
                                    // Filled icon (fades in)
                                    Opacity(
                                      opacity: t.clamp(0.0, 1.0),
                                      child: Icon(
                                        widget.activeIcon,
                                        color: iconColor,
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    // ── Label ──
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                      ),
                      child: Text(widget.label),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TabNavigatorObserver extends NavigatorObserver {
  final VoidCallback onStateChange;
  _TabNavigatorObserver(this.onStateChange);

  @override
  void didPush(Route route, Route? previousRoute) => onStateChange();

  @override
  void didPop(Route route, Route? previousRoute) => onStateChange();

  @override
  void didRemove(Route route, Route? previousRoute) => onStateChange();

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) => onStateChange();
}
