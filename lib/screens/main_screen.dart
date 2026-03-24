import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widget_previews.dart';
import 'package:invoice_discounting_app/screens/unlock_screen.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';

import '../utils/app_haptics.dart';
import 'analytics_screen.dart';
import 'home_screen.dart';
import 'marketplace_screen.dart';
import 'portfolio_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const platform = MethodChannel('widget_navigation');

  static const int _tabCount = 4;
  int _currentIndex = 0;
  DateTime? _lastBackPress;
  late final List<Widget> _tabs;
  DateTime? _backgroundTime;
  static const _lockTimeout = Duration(seconds: 30);

  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    _tabCount,
    (_) => GlobalKey<NavigatorState>(),
  );

  final List<AnimationController> _tabControllers = [];
  final List<Animation<double>> _tabFades = [];
  final List<Animation<Offset>> _tabSlides = [];

  @override
  void initState() {
    super.initState();
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

    _lastBackPress = null;
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
      onGenerateRoute: (settings) => SmoothPageRoute(
        builder: (_) => screens[index],
        settings: settings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;

        final currentNav = _navigatorKeys[_currentIndex].currentState;

        if (currentNav != null && currentNav.canPop()) {
          currentNav.pop();
          _lastBackPress = null;
          return;
        }

        if (_currentIndex != 0) {
          _changeTab(0);
          return;
        }

        final now = DateTime.now();

        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;

          await AppHaptics.buttonPress();

          if (!context.mounted) return;

          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.exit_to_app_rounded,
                          color: Colors.white70, size: 18),
                      SizedBox(width: 10),
                      Text('Tap again to exit',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ],
                  ),
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF26292F),
                duration: const Duration(seconds: 2),
                elevation: 0,
                margin: EdgeInsets.fromLTRB(
                    16, 0, 16, MediaQuery.of(context).padding.bottom),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08), width: 1),
                ),
              ),
            );

          return;
        }

        await AppHaptics.error();
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(_tabCount, (i) {
            return RepaintBoundary(
              child: FadeTransition(
                opacity: _tabFades[i],
                child: SlideTransition(
                  position: _tabSlides[i],
                  child: _tabs[i],
                ),
              ),
            );
          }),
        ),
        bottomNavigationBar: Material(
          // M3: surfaceContainer gives a tone-based lift that's visually
          // distinct from the scaffold's cs.surface background.
          color: cs.surfaceContainer,
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav item — M3 Navigation Bar indicator
// Animations: bounce/scale pop, outlined↔filled crossfade, pill width expand
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatefulWidget {
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
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with TickerProviderStateMixin {
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
            child: InkResponse(
              onTap: () async {
                await AppHaptics.navTap();
                widget.onTap(widget.index);
              },
              onLongPress: () => _showLabel(context),
              containedInkWell: false,
              highlightShape: BoxShape.circle,
              radius: 64,
              splashFactory: InkRipple.splashFactory,
              splashColor: cs.onSecondaryContainer.withValues(alpha: 0.12),
              highlightColor: cs.onSecondaryContainer.withValues(alpha: 0.06),
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

@Preview(name: 'Nav Bar Only')
Widget navBarPreview() => const NavBarPreview();

class NavBarPreview extends StatelessWidget {
  const NavBarPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MainScreen(),
    );
  }
}