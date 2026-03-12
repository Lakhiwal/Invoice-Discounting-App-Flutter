import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:invoice_discounting_app/screens/unlock_screen.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';

import '../theme/theme_provider.dart';
import '../utils/app_haptics.dart';
import 'home_screen.dart';
import 'marketplace_screen.dart';
import 'portfolio_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const platform = MethodChannel('widget_navigation');

  static const int _tabCount = 5;
  int _currentIndex = 0;
  DateTime? _lastBackPress;
  late final List<Widget> _tabs;
  DateTime? _backgroundTime;
  static const _lockTimeout = Duration(seconds: 30);

  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    _tabCount,
    (_) => GlobalKey<NavigatorState>(),
  );

  // ── Exit banner ─────────────────────────────────────────────────────────
  late AnimationController _bannerController;
  late CurvedAnimation _bannerOpacityCurve;
  late CurvedAnimation _bannerSlideCurve;
  late Animation<double> _bannerOpacity;
  late Animation<Offset> _bannerSlide;
  OverlayEntry? _bannerEntry;

  // ── Per-tab fade-up controllers ─────────────────────────────────────────
  final List<AnimationController> _tabControllers = [];
  final List<Animation<double>> _tabFades = [];
  final List<Animation<Offset>> _tabSlides = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabs = List.generate(_tabCount, _buildTabNavigator);

    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _bannerOpacityCurve =
        CurvedAnimation(parent: _bannerController, curve: Curves.easeOutCubic);
    _bannerOpacity = _bannerOpacityCurve;
    _bannerSlideCurve =
        CurvedAnimation(parent: _bannerController, curve: Curves.easeOutCubic);
    _bannerSlide = Tween<Offset>(
      begin: const Offset(0, 0.9),
      end: Offset.zero,
    ).animate(_bannerSlideCurve);

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
    _removeBanner();
    WidgetsBinding.instance.removeObserver(this);
    _bannerOpacityCurve.dispose();
    _bannerSlideCurve.dispose();
    _bannerController.dispose();
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

  void _removeBanner() {
    _bannerEntry?.remove();
    _bannerEntry = null;
  }

  void _changeTab(int index) {
    if (_currentIndex == index) return;
    _lastBackPress = null;
    _removeBanner();
    final previousIndex = _currentIndex;
    setState(() => _currentIndex = index);
    _tabControllers[previousIndex].reverse();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tabControllers[index].forward(from: 0);
    });
  }

  Future<void> _showExitBanner() async {
    if (_bannerEntry != null) {
      _bannerController.forward(from: 0);
      _startDismissTimer();
      return;
    }

    _bannerEntry = OverlayEntry(
      builder: (_) {
        final bottomInset = MediaQuery.viewPaddingOf(context).bottom +
            kBottomNavigationBarHeight +
            22;
        return Positioned(
          left: 4,
          right: 4,
          bottom: bottomInset,
          child: SlideTransition(
            position: _bannerSlide,
            child: FadeTransition(
              opacity: _bannerOpacity,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: 56,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2F33),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Tap again to exit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_bannerEntry!);
    _bannerController.forward(from: 0);
    _startDismissTimer();
  }

  Future<void> _startDismissTimer() async {
    final pressTime = _lastBackPress;
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted || _lastBackPress != pressTime) return;
    await _bannerController.reverse();
    _removeBanner();
    _lastBackPress = null;
  }

  Widget _buildTabNavigator(int index) {
    const screens = [
      HomeScreen(),
      MarketplaceScreen(),
      PortfolioScreen(),
      AnalyticsScreen(),
      ProfileScreen(),
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;

        final currentNav = _navigatorKeys[_currentIndex].currentState;

        // 1. If the current tab has inner routes, pop them
        if (currentNav != null && currentNav.canPop()) {
          currentNav.pop();
          _lastBackPress = null;
          _removeBanner();
          return;
        }

        // 2. If NOT on Home tab, switch to Home first
        if (_currentIndex != 0) {
          _changeTab(0);
          return;
        }

        // 3. On Home tab at root → double-tap to exit
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          _removeBanner();
          await AppHaptics.error();
          await SystemNavigator.pop();
        } else {
          _lastBackPress = now;
          await AppHaptics.buttonPress();
          _showExitBanner();
        }
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
          color: AppColors.navyLight(context),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.divider(context).withValues(alpha: 0.4),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 24),
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
                  Expanded(
                    child: _NavItem(
                        icon: Icons.person_outline_rounded,
                        activeIcon: Icons.person_rounded,
                        label: 'Profile',
                        index: 4,
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
// Nav item — Google Photos style pill
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

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final CurvedAnimation _curve;

  void _showLabel(BuildContext context) {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    const double horizontalAdjust = 10;

    final size = renderBox.size;

    final entry = OverlayEntry(
      builder: (_) {
        return Positioned(
          left: position.dx + size.width / 2 - 30 + horizontalAdjust,
          top: position.dy - 30,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 1), () {
      entry.remove();
    });
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    if (widget.index == widget.current) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_NavItem old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current) {
      if (widget.index == widget.current) {
        _ctrl.forward(from: 0.0);
      } else if (widget.index == old.current) {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.index == widget.current;
    final activeColor = AppColors.primary(context);
    final idleColor = AppColors.textSecondary(context);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _curve.value;

          final color = Color.lerp(
            idleColor.withValues(alpha: 0.7),
            activeColor,
            Curves.easeOut.transform(t),
          )!;

          return Semantics(
            label: widget.label,
            button: true,
            selected: active,
            child: InkResponse(
              onTap: () async {
                await AppHaptics.navTap();
                widget.onTap(widget.index);
              },
              onLongPress: () {
                _showLabel(context);
              },
              containedInkWell: false,
              highlightShape: BoxShape.circle,
              radius: 56,
              splashFactory: InkRipple.splashFactory,
              splashColor: activeColor.withValues(alpha: 0.12),
              highlightColor: activeColor.withValues(alpha: 0.06),
              child: SizedBox(
                width: 64,
                height: 72,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 32,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (t > 0)
                            Opacity(
                              opacity: t,
                              child: Container(
                                width: 60,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: activeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          Icon(
                            active ? widget.activeIcon : widget.icon,
                            color: color,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedOpacity(
                      opacity: active ? 1 : 0.7,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
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
