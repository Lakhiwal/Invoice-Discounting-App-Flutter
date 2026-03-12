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

  // ── Per-tab fade-up controllers ─────────────────────────────────────────
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

        // 1️⃣ Pop inner routes if present
        if (currentNav != null && currentNav.canPop()) {
          currentNav.pop();
          _lastBackPress = null;
          return;
        }

        // 2️⃣ If not on Home tab → switch to Home
        if (_currentIndex != 0) {
          _changeTab(0);
          return;
        }

        final now = DateTime.now();

        // 3️⃣ First press → show snackbar
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;

          await AppHaptics.buttonPress();

          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Tap again to exit',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF26292F),
                duration: const Duration(seconds: 2),
                elevation: 0,
                margin: EdgeInsets.fromLTRB(
                  12,
                  0,
                  12,
                  MediaQuery.of(context).padding.bottom + 68,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            );

          return;
        }

        // 4️⃣ Second press → exit
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
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w500,
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
