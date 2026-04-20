import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/screens/analytics_screen.dart';
import 'package:invoice_discounting_app/screens/e_collect_screen.dart';
import 'package:invoice_discounting_app/screens/home_screen.dart';
import 'package:invoice_discounting_app/screens/portfolio_screen.dart';
import 'package:invoice_discounting_app/screens/unlock_screen.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';
import 'package:invoice_discounting_app/widgets/back_gesture_handler.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const platform = MethodChannel('widget_navigation');

  static const int _tabCount = 3;
  int _currentIndex = 0;

  /// Tab history for back-navigation. Only stores unique consecutive entries.
  /// Max depth of 10 to prevent unbounded growth.
  final List<int> _tabHistory = [];
  static const int _maxHistoryDepth = 10;

  DateTime? _backgroundTime;
  static const _lockTimeout = Duration(seconds: 300);

  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    _tabCount,
    (_) => GlobalKey<NavigatorState>(),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    platform.setMethodCallHandler((call) async {
      if (call.method == 'openTab' && call.arguments == 'marketplace') {
        _changeTab(1);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
        unawaited(
          Navigator.pushAndRemoveUntil<void>(
            context,
            SmoothPageRoute<void>(builder: (_) => const UnlockScreen()),
            (route) => false,
          ),
        );
      }
    }
  }

  // ─────────────────────── Tab switching via bottom nav ──────────────────────

  void _changeTab(int index) {
    if (_currentIndex == index) {
      // If tapping the current tab, pop to root of that tab's navigator
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }

    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final previousIndex = _currentIndex;

    setState(() {
      // Push previous index to history, avoiding consecutive duplicates
      if (_tabHistory.isEmpty || _tabHistory.last != previousIndex) {
        _tabHistory.add(previousIndex);
        // Trim history to prevent unbounded growth
        if (_tabHistory.length > _maxHistoryDepth) {
          _tabHistory.removeAt(0);
        }
      }
      _currentIndex = index;
    });
  }

  // ──────────────────────── Nested tab navigators ──────────────────────────

  Widget _buildTabNavigator(int index) {
    const screens = [
      HomeScreen(),
      ECollectScreen(),
      PortfolioScreen(),
    ];

    // No NavigatorPopHandler — we handle pops manually in _handleBackPressed.
    // This avoids the NavigationNotification + IndexedStack conflict that
    // caused blank screens. Each Navigator has its own key for direct access.
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (settings) => SmoothPageRoute<void>(
        builder: (_) => screens[index],
        settings: settings,
      ),
    );
  }

  // ────────────────── Back navigation ──────────────────

  /// Called by [RootBackHandler] on every back gesture.
  /// Returns true if handled, false for exit-toast.
  Future<bool> _handleBackPressed() async {
    // 1. If current tab's navigator has pushed routes, pop them.
    final currentNav = _navigatorKeys[_currentIndex].currentState;
    if (currentNav != null && currentNav.canPop()) {
      currentNav.pop();
      unawaited(AppHaptics.selection());
      return true;
    }

    // 2. Navigate back through tab history.
    if (_tabHistory.isNotEmpty) {
      final prevIndex = _tabHistory.removeLast();
      _switchToTab(prevIndex);
      unawaited(AppHaptics.selection());
      return true;
    }

    // 3. If not on Home, go to Home first.
    if (_currentIndex != 0) {
      _switchToTab(0);
      _tabHistory.clear();
      unawaited(AppHaptics.selection());
      return true;
    }

    // 4. At root of Home tab with no history → show exit toast.
    return false;
  }

  /// Switch to [index] via back-navigation (no history push).
  void _switchToTab(int index) {
    if (_currentIndex == index) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _currentIndex = index);
  }

  // ───────────────────────────── Build ──────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return RootBackHandler(
      onBackPressed: _handleBackPressed,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: Stack(
          children: [
            // 1. Content Area (IndexedStack)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 74),
                child: IndexedStack(
                  index: _currentIndex,
                  children: List.generate(_tabCount, _buildTabNavigator),
                ),
              ),
            ),

            // 2. Fixed Bottom Navigation Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainer.withValues(alpha: 0.8),
                        border: Border(
                          top: BorderSide(
                            color: cs.outlineVariant.withValues(alpha: 0.1),
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          child: SizedBox(
                            height: 64,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Shared Sliding Indicator
                                AnimatedAlign(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.elasticOut,
                                  alignment: Alignment(
                                    -1.0 +
                                        (_currentIndex *
                                            (2.0 / (_tabCount - 1))),
                                    0,
                                  ),
                                  child: FractionallySizedBox(
                                    widthFactor: 1 / _tabCount,
                                    child: Container(
                                      alignment: const Alignment(0, -0.28),
                                      child: Container(
                                        width: 56,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: cs.primary
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: cs.primary
                                                .withValues(alpha: 0.15),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: _NavItem(
                                        icon: AppIcons.home,
                                        activeIcon: AppIcons.homeBold,
                                        label: 'Home',
                                        index: 0,
                                        current: _currentIndex,
                                        onTap: _changeTab,
                                      ),
                                    ),
                                    Expanded(
                                      child: _NavItem(
                                        icon: AppIcons.bank,
                                        activeIcon: AppIcons.bank,
                                        label: 'E-Collect',
                                        index: 1,
                                        current: _currentIndex,
                                        onTap: _changeTab,
                                      ),
                                    ),
                                    Expanded(
                                      child: _NavItem(
                                        icon: AppIcons.portfolio,
                                        activeIcon: AppIcons.portfolioBold,
                                        label: 'Portfolio',
                                        index: 2,
                                        current: _currentIndex,
                                        onTap: _changeTab,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;

  @override
  ConsumerState<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends ConsumerState<_NavItem>
    with TickerProviderStateMixin {
  // ── Main activation controller (pill + crossfade) ──
  late final AnimationController _ctrl;
  late final CurvedAnimation _curve;

  // ── Bounce controller (scale pop on tap) ──
  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceAnim;

  void _showLabel(BuildContext context) {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject()! as RenderBox;
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

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    if (widget.index == widget.current) _ctrl.value = 1.0;

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.18, end: 0.95)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.95, end: 1.0)
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
        unawaited(_ctrl.forward(from: 0));
        unawaited(_bounceCtrl.forward(from: 0));
      } else if (widget.index == old.current) {
        unawaited(_ctrl.reverse());
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

          final iconYOffset = -1.0 * t;

          return Semantics(
            label: widget.label,
            button: true,
            selected: active,
            child: GestureDetector(
              onTapDown: (_) {
                unawaited(_bounceCtrl.forward(from: 0));
              },
              onTap: () async {
                unawaited(AppHaptics.navTap());
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
                    SizedBox(
                      width: 64,
                      height: 28,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (t > 0)
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: cs.primary.withValues(
                                      alpha: 0.15 * t.clamp(0.0, 1.0),
                                    ),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
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
                                    Icon(
                                      widget.icon,
                                      color: iconColor.withValues(
                                        alpha: (1.0 - t).clamp(0.0, 1.0),
                                      ),
                                      size: 24,
                                    ),
                                    Icon(
                                      widget.activeIcon,
                                      color: iconColor.withValues(
                                        alpha: t.clamp(0.0, 1.0),
                                      ),
                                      size: 24,
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
