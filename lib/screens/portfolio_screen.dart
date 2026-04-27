import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/services/portfolio_cache.dart';
import 'package:invoice_discounting_app/services/secondary_market_api_service.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/formatters.dart';
import 'package:invoice_discounting_app/utils/momentum_haptics.dart';
import 'package:invoice_discounting_app/widgets/animated_amount_text.dart';
import 'package:invoice_discounting_app/widgets/app_logo_header.dart';
import 'package:invoice_discounting_app/widgets/liquidity_refresh_indicator.dart';
import 'package:invoice_discounting_app/widgets/pressable.dart';
import 'package:invoice_discounting_app/widgets/skeleton.dart';
import 'package:invoice_discounting_app/widgets/stagger_list.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _fmtFull(dynamic v) {
  try {
    return double.parse(v.toString()).toStringAsFixed(2);
  } catch (_) {
    return '0.00';
  }
}

Color _cardBg(BuildContext c, bool isBlack) => isBlack
    ? const Color(0xFF0A0A0A)
    : Theme.of(c).colorScheme.surfaceContainer;

Color _cardBorder(BuildContext c, bool isBlack, [double darkAlpha = 0.15]) =>
    Theme.of(c)
        .colorScheme
        .outlineVariant
        .withValues(alpha: isBlack ? 0.06 : darkAlpha);

// ─────────────────────────────────────────────────────────────────────────────
// PortfolioScreen
// ─────────────────────────────────────────────────────────────────────────────

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;
  bool _isLoading = false;
  Map<String, dynamic>? _portfolio;
  final ValueNotifier<bool> _showFloatingSummary = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadPortfolio();
  }

  void _onScroll() {
    if (!mounted) return;
    final show = _scrollController.offset > 160;
    if (show != _showFloatingSummary.value) {
      _showFloatingSummary.value = show;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _showFloatingSummary.dispose();
    super.dispose();
  }

  Future<void> _loadPortfolio({
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    if (!mounted) return;

    final startTime = DateTime.now();
    if (!silent) {
      setState(() => _isLoading = true);
    }

    if (forceRefresh) PortfolioCache.invalidate();
    try {
      final data =
          await PortfolioCache.getPortfolio(forceRefresh: forceRefresh);

      if (forceRefresh) {
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        if (elapsed < 800) {
          await Future.delayed(Duration(milliseconds: 800 - elapsed));
        }
      }

      if (!mounted) return;
      setState(() {
        _portfolio = data;
        _isLoading = false;
      });
      unawaited(AppHaptics.numberReveal());
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = (_portfolio?['active'] as List?) ?? [];
    final repaid = (_portfolio?['repaid'] as List?) ?? [];
    final isBlack = ref.watch(themeProvider.select((p) => p.isBlackMode));

    final activeFresh =
        active.where((i) => !(i['is_secondary'] ?? false)).toList();
    final activeResell =
        active.where((i) => i['is_secondary'] ?? false).toList();

    final repaidPrimary =
        repaid.where((i) => !(i['is_secondary'] ?? false)).toList();
    final repaidSecondary =
        repaid.where((i) => i['is_secondary'] ?? false).toList();

    return Scaffold(
      body: LiquidityRefreshIndicator(
        onRefresh: () async => _loadPortfolio(forceRefresh: true, silent: true),
        child: Stack(
          children: [
            NestedScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              controller: _scrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                AppLogoHeader(
                  title: 'Portfolio',
                  actions: [
                    IconButton(
                      icon: Icon(AppIcons.refresh),
                      onPressed: () =>
                          unawaited(_loadPortfolio(forceRefresh: true)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(210),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Fixed Summary Tiles ──────────────────────────────────
                        if (!_isLoading)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: UI.lg),
                            child: Column(
                              children: [
                                const SizedBox(height: UI.lg),
                                Row(
                                  children: [
                                    _SummaryTile(
                                      label: 'Invested',
                                      value: _portfolio?['summary']
                                              ?['total_invested'] ??
                                          0,
                                      icon: AppIcons.wallet,
                                      color: colorScheme.primary,
                                      isBlackMode: isBlack,
                                    ),
                                    const SizedBox(width: 12),
                                    _SummaryTile(
                                      label: 'Returns',
                                      value: _portfolio?['summary']
                                              ?['total_returns'] ??
                                          0,
                                      icon: AppIcons.trendingUp,
                                      color: AppColors.emerald(context),
                                      isBlackMode: isBlack,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: UI.lg),
                            child: SkeletonPortfolioHeader(),
                          ),

                        // ── Fixed TabBar ─────────────────────────────────────────
                        Container(
                          color: colorScheme.surface,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: _isLoading
                              ? const SkeletonTabBar()
                              : TabBar(
                                  controller: _tabController,
                                  indicator: UnderlineTabIndicator(
                                    borderSide: BorderSide(
                                      color: colorScheme.primary,
                                      width: 3.5,
                                    ),
                                    insets: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                  ),
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  labelColor: colorScheme.primary,
                                  unselectedLabelColor:
                                      colorScheme.onSurfaceVariant,
                                  dividerColor: colorScheme.outlineVariant
                                      .withValues(alpha: 0.1),
                                  labelStyle: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    letterSpacing: 0.5,
                                  ),
                                  unselectedLabelStyle: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                  tabs: [
                                    Tab(
                                      text:
                                          'Active (${_portfolio?['summary']?['active_count'] ?? active.length})',
                                    ),
                                    Tab(
                                      text:
                                          'Repaid (${_portfolio?['summary']?['repaid_count'] ?? repaid.length})',
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _PagedPortfolioView(
                    key: const ValueKey('active-paged'),
                    mainCategory: 'Active',
                    primaryList: activeFresh,
                    secondaryList: activeResell,
                    isLoading: _isLoading,
                    isBlackMode: isBlack,
                  ),
                  _PagedPortfolioView(
                    key: const ValueKey('repaid-paged'),
                    mainCategory: 'Repaid',
                    primaryList: repaidPrimary,
                    secondaryList: repaidSecondary,
                    isLoading: _isLoading,
                    isBlackMode: isBlack,
                  ),
                ],
              ),
            ),
            _buildFloatingSummary(
              context,
              _portfolio?['summary'] as Map<String, dynamic>?,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingSummary(
    BuildContext context,
    Map<String, dynamic>? summary,
  ) {
    if (summary == null) return const SizedBox.shrink();

    final value = summary['total_invested'] ?? 0;
    final returns = summary['total_returns'] ?? 0;

    return ValueListenableBuilder<bool>(
      valueListenable: _showFloatingSummary,
      builder: (context, show, child) => AnimatedPositioned(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        bottom: show ? 24 : -100,
        left: 24,
        right: 24,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: show ? 1 : 0,
          child: child,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(UI.radiusLg),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              _SummaryMetric(
                label: 'Value',
                value: double.tryParse(value.toString()) ?? 0.0,
                color: Theme.of(context).colorScheme.primary,
              ),
              Container(
                width: 1,
                height: 24,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.2),
              ),
              _SummaryMetric(
                label: 'Returns',
                value: double.tryParse(returns.toString()) ?? 0.0,
                color: AppColors.emerald(context),
                staggerIndex: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryMetric extends ConsumerWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
    this.staggerIndex = 0,
  });
  final String label;
  final double value;
  final Color color;
  final int staggerIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, val, child) {
          final delay = staggerIndex * 0.1;
          final animValue = (val - delay).clamp(0.0, 1.0);
          return Opacity(
            opacity: animValue,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - animValue)),
              child: child,
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedAmountText(
              value: value,
              prefix: '₹',
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary tile
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryTile extends ConsumerWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isBlackMode = false,
  });
  final String label;
  final dynamic value;
  final IconData icon;
  final Color color;
  final bool isBlackMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Pressable(
        scale: 0.98,
        onTap: AppHaptics.selection,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(UI.radiusMd),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isBlackMode
                    ? color.withValues(alpha: 0.08)
                    : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(UI.radiusMd),
                border: Border.all(
                  color: isBlackMode
                      ? color.withValues(alpha: 0.12)
                      : color.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(height: 12),
                  AnimatedAmountText(
                    value: double.tryParse(value.toString()) ?? 0.0,
                    prefix: '₹',
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
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
// Paged portfolio view — vertical PageView with overscroll-triggered snap
// ─────────────────────────────────────────────────────────────────────────────
//
// Two pages stacked vertically: [Primary/Fresh] on top, [Secondary/Resell]
// below. User scrolls through page 1 normally with ClampingScrollPhysics —
// it HARD STOPS at the last invoice. A second, deliberate pull-up gesture
// at that stopped position accumulates overscroll; once it crosses
// `_overscrollThreshold` (80px), we programmatically animate to page 2.
// Same in reverse: at the top of page 2, a pull-down snaps back to page 1,
// which automatically restores its last scroll position (because the
// ScrollController is kept alive across page changes).
//
// The PageView's own swipe is disabled (NeverScrollableScrollPhysics) so
// pages only change via the overscroll-threshold logic — no accidental
// swipes. _overscrollAccumulator resets on every ScrollEndNotification,
// so one gesture's scrolling never bleeds into the next gesture's check.
// ─────────────────────────────────────────────────────────────────────────────

class _PagedPortfolioView extends ConsumerStatefulWidget {
  const _PagedPortfolioView({
    required this.mainCategory,
    required this.primaryList,
    required this.secondaryList,
    required this.isLoading,
    required this.isBlackMode,
    super.key,
  });

  final String mainCategory;
  final List<dynamic> primaryList;
  final List<dynamic> secondaryList;
  final bool isLoading;
  final bool isBlackMode;

  @override
  ConsumerState<_PagedPortfolioView> createState() =>
      _PagedPortfolioViewState();
}

class _PagedPortfolioViewState extends ConsumerState<_PagedPortfolioView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Pixels of overscroll at the boundary required before snapping to the
  // next / previous page. Higher = more deliberate "hard swipe" needed.
  static const double _overscrollThreshold = 80.0;

  late PageController _pageController;
  late ScrollController _primaryScrollController;
  late ScrollController _secondaryScrollController;

  int _currentPage = 0;
  bool _isAnimating = false;
  double _overscrollAccumulator = 0;
  bool _halfwayTickFired = false;
  final MomentumHaptics _momentumHaptics = MomentumHaptics();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _primaryScrollController = ScrollController();
    _secondaryScrollController = ScrollController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _primaryScrollController.dispose();
    _secondaryScrollController.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification, int page) {
    if (_isAnimating) return false;
    // Only the currently visible page's notifications matter
    if (page != _currentPage) return false;

    if (notification is OverscrollNotification) {
      // Page 0 — user is at the bottom and pulling up further → go to page 1
      if (page == 0 &&
          notification.overscroll > 0 &&
          widget.secondaryList.isNotEmpty) {
        _overscrollAccumulator += notification.overscroll;

        // Halfway tick (Premium feel)
        if (_overscrollAccumulator >= _overscrollThreshold / 2 &&
            !_halfwayTickFired) {
          _halfwayTickFired = true;
          unawaited(AppHaptics.selection());
        }

        if (_overscrollAccumulator >= _overscrollThreshold) {
          _snapToPage(1);
        }
      }
      // Page 1 — user is at the top and pulling down further → go to page 0
      else if (page == 1 && notification.overscroll < 0) {
        _overscrollAccumulator += notification.overscroll.abs();

        // Halfway tick
        if (_overscrollAccumulator >= _overscrollThreshold / 2 &&
            !_halfwayTickFired) {
          _halfwayTickFired = true;
          unawaited(AppHaptics.selection());
        }

        if (_overscrollAccumulator >= _overscrollThreshold) {
          _snapToPage(0);
        }
      }
    } else if (notification is ScrollUpdateNotification) {
      // Trigger momentum haptics for velocity-based pips
      _momentumHaptics.onScroll(notification.metrics.pixels);
    } else if (notification is ScrollEndNotification) {
      // Gesture finished — reset accumulator so the next gesture starts fresh
      _overscrollAccumulator = 0;
      _halfwayTickFired = false;
    }
    return false;
  }

  void _snapToPage(int page) {
    if (_isAnimating) return;
    _isAnimating = true;
    _overscrollAccumulator = 0;
    _halfwayTickFired = false;
    unawaited(AppHaptics.selection());
    _pageController
        .animateToPage(
      page,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    )
        .then((_) {
      if (mounted) {
        setState(() {
          _currentPage = page;
          _isAnimating = false;
        });
      } else {
        _isAnimating = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isRepaid = widget.mainCategory == 'Repaid';
    final primaryLabel = isRepaid ? 'Primary' : 'Fresh';
    final secondaryLabel = isRepaid ? 'Secondary' : 'Resell';

    if (widget.isLoading) {
      return const SkeletonPortfolioContent();
    }

    final hasPrimary = widget.primaryList.isNotEmpty;
    final hasSecondary = widget.secondaryList.isNotEmpty;

    // If both are empty, just show an empty primary page
    if (!hasPrimary && !hasSecondary) {
      return _PortfolioPage(
        label: primaryLabel,
        count: 0,
        list: const [],
        scrollController: _primaryScrollController,
        isRepaid: isRepaid,
        isBlackMode: widget.isBlackMode,
        showBottomHint: false,
        showTopHint: false,
        hintText: '',
        onScrollNotification: (_) => false,
      );
    }

    // If only one has data, skip the PageView
    if (hasPrimary && !hasSecondary) {
      return _PortfolioPage(
        label: primaryLabel,
        count: widget.primaryList.length,
        list: widget.primaryList,
        scrollController: _primaryScrollController,
        isRepaid: isRepaid,
        isBlackMode: widget.isBlackMode,
        showBottomHint: false,
        showTopHint: false,
        hintText: '',
        onScrollNotification: (_) => false,
      );
    }

    if (!hasPrimary && hasSecondary) {
      return _PortfolioPage(
        label: secondaryLabel,
        count: widget.secondaryList.length,
        list: widget.secondaryList,
        scrollController: _secondaryScrollController,
        isRepaid: isRepaid,
        isBlackMode: widget.isBlackMode,
        showBottomHint: false,
        showTopHint: false,
        hintText: '',
        onScrollNotification: (_) => false,
      );
    }

    // Both have data — show the PageView with hints
    return PageView(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (p) {
        if (mounted) {
          setState(() => _currentPage = p);
        }
      },
      children: [
        _PortfolioPage(
          label: primaryLabel,
          count: widget.primaryList.length,
          list: widget.primaryList,
          scrollController: _primaryScrollController,
          isRepaid: isRepaid,
          isBlackMode: widget.isBlackMode,
          showBottomHint: true,
          showTopHint: false,
          hintText: 'Pull up for $secondaryLabel',
          onScrollNotification: (n) => _handleScrollNotification(n, 0),
        ),
        _PortfolioPage(
          label: secondaryLabel,
          count: widget.secondaryList.length,
          list: widget.secondaryList,
          scrollController: _secondaryScrollController,
          isRepaid: isRepaid,
          isBlackMode: widget.isBlackMode,
          showBottomHint: false,
          showTopHint: true,
          hintText: 'Pull down for $primaryLabel',
          onScrollNotification: (n) => _handleScrollNotification(n, 1),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single portfolio page (one section rendered as its own scrollable page)
// ─────────────────────────────────────────────────────────────────────────────

class _PortfolioPage extends StatefulWidget {
  const _PortfolioPage({
    required this.label,
    required this.count,
    required this.list,
    required this.scrollController,
    required this.isRepaid,
    required this.isBlackMode,
    required this.onScrollNotification,
    required this.showBottomHint,
    required this.showTopHint,
    required this.hintText,
  });

  final String label;
  final int count;
  final List<dynamic> list;
  final ScrollController scrollController;
  final bool isRepaid;
  final bool isBlackMode;
  final bool Function(ScrollNotification) onScrollNotification;
  final bool showBottomHint;
  final bool showTopHint;
  final String hintText;

  @override
  State<_PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<_PortfolioPage>
    with AutomaticKeepAliveClientMixin {
  late List<dynamic> _items;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.list);
    // If the initial list is exactly 20 (our limit), there might be more.
    _hasMore = _items.length >= 20;
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(_PortfolioPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.list != widget.list) {
      setState(() {
        _items = List.from(widget.list);
        _page = 1;
        _hasMore = _items.length >= 20;
      });
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    if (widget.scrollController.position.pixels >
            widget.scrollController.position.maxScrollExtent - 600 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final type = widget.isRepaid ? 'repaid' : 'active';
      final isSecondary = widget.label.toLowerCase().contains('resell') ||
          widget.label.toLowerCase().contains('secondary');

      final data = await ApiService.getPortfolio(
        page: nextPage,
        type: type,
        isSecondary: isSecondary,
      );

      if (mounted) {
        final newList = (data?[type] as List?) ?? [];
        setState(() {
          _items.addAll(newList);
          _page = nextPage;
          _isLoadingMore = false;
          if (newList.length < 20) {
            _hasMore = false;
          }
        });
        if (newList.isNotEmpty) {
          unawaited(AppHaptics.selection());
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    const physics =
        AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics());
    final colorScheme = Theme.of(context).colorScheme;

    return NotificationListener<ScrollNotification>(
      onNotification: widget.onScrollNotification,
      child: CustomScrollView(
        controller: widget.scrollController,
        physics: physics,
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _SectionHeaderDelegate(
              label: widget.label,
              count: widget.count,
            ),
          ),
          if (widget.showTopHint)
            SliverToBoxAdapter(
              child: _PullHint(text: widget.hintText, pointingUp: false),
            ),
          if (_items.isEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 400,
                child: _MiniEmptyState(
                  label: widget.label,
                  isRepaid: widget.isRepaid,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => StaggerItem(
                    index: i,
                    child: _InvestmentCard(
                      inv: _items[i] as Map<String, dynamic>,
                      isRepaid: widget.isRepaid,
                      isBlackMode: widget.isBlackMode,
                    ),
                  ),
                  childCount: _items.length,
                ),
              ),
            ),
          if (_isLoadingMore)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: LoadingAnimationWidget.staggeredDotsWave(
                    color: colorScheme.primary,
                    size: 32,
                  ),
                ),
              ),
            ),
          if (widget.showBottomHint)
            SliverToBoxAdapter(
              child: _PullHint(text: widget.hintText, pointingUp: true),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header delegate (for sticky behavior inside the page)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SectionHeaderDelegate({required this.label, required this.count});
  final String label;
  final int count;

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    if (shrinkOffset > 0 && shrinkOffset < 1) {
      // Only trigger a light tick when we just start pinning
      AppHaptics.selection();
    }
    return _SectionHeaderBar(label: label, count: count);
  }

  @override
  bool shouldRebuild(_SectionHeaderDelegate old) =>
      old.label != label || old.count != count;
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header bar (top of each page)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeaderBar extends StatelessWidget {
  const _SectionHeaderBar({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: colorScheme.outlineVariant.withValues(alpha: 0.15),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pull hint (small indicator telling the user about the other page)
// ─────────────────────────────────────────────────────────────────────────────

class _PullHint extends StatelessWidget {
  const _PullHint({required this.text, required this.pointingUp});
  final String text;
  final bool pointingUp;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(
            pointingUp ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            size: 20,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Investment card
// ─────────────────────────────────────────────────────────────────────────────

class _InvestmentCard extends ConsumerWidget {
  const _InvestmentCard({
    required this.inv,
    required this.isRepaid,
    this.isBlackMode = false,
  });
  final Map<String, dynamic> inv;
  final bool isRepaid;
  final bool isBlackMode;

  double _progress() {
    try {
      final daysLeft = int.tryParse(inv['days_left']?.toString() ?? '0') ?? 0;
      final tenure = int.tryParse(inv['tenure_days']?.toString() ?? '0') ?? 0;
      if (tenure <= 0) return isRepaid ? 1.0 : 0.5;
      return ((tenure - daysLeft) / tenure).clamp(0.0, 1.0);
    } catch (_) {
      return isRepaid ? 1.0 : 0.5;
    }
  }

  bool get _isOverdue {
    if (isRepaid) return false;
    return (int.tryParse(inv['days_left']?.toString() ?? '0') ?? 0) < 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = _progress();
    final invested = double.tryParse(inv['amount']?.toString() ?? '0') ?? 0;
    final approved =
        double.tryParse(inv['approved_amount']?.toString() ?? '0') ?? 0;
    final fundedPct =
        approved > 0 ? ((invested / approved) * 100).clamp(0.0, 100.0) : 0.0;
    final isFull = approved > 0 && invested >= approved;

    final statusColor = isRepaid
        ? AppColors.emerald(context)
        : _isOverdue
            ? AppColors.rose(context)
            : colorScheme.primary;
    final progressColor =
        progress > 0.85 ? AppColors.amber(context) : AppColors.emerald(context);

    return Pressable(
      onTap: () async {
        unawaited(AppHaptics.selection());
        if (context.mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            showDragHandle: true,
            backgroundColor: colorScheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            builder: (_) => _InvestmentDetailSheet(
              inv: inv,
              isRepaid: isRepaid,
              isBlackMode: isBlackMode,
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardBg(context, isBlackMode),
          borderRadius: BorderRadius.circular(UI.radiusLg),
          border: Border.all(color: _cardBorder(context, isBlackMode, 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isBlackMode ? 0.3 : 0.05),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(UI.radiusSm),
                  ),
                  child: Center(
                    child: Text(
                      (inv['company']?.toString() ?? 'C').isNotEmpty
                          ? inv['company']!.toString()[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    inv['company']?.toString() ?? 'Company',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        statusColor.withValues(alpha: isBlackMode ? 0.08 : 0.1),
                    borderRadius: BorderRadius.circular(UI.radiusSm),
                  ),
                  child: Text(
                    isRepaid
                        ? 'Repaid'
                        : _isOverdue
                            ? 'Overdue'
                            : 'Active',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '₹${fmtAmount(invested)}',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Metric(
                  label: 'Investor Rate',
                  value: '${inv['investor_rate']}% p.a.',
                ),
                _Metric(
                  label: isRepaid ? 'Settled On' : 'Due Date',
                  value: inv['payment_date']?.toString() ?? '--',
                ),
              ],
            ),
            if (approved > 0) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(UI.radiusSm),
                child: LinearProgressIndicator(
                  value: (invested / approved).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor:
                      colorScheme.outlineVariant.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation(
                    isFull ? AppColors.emerald(context) : colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Funded ${fundedPct.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: isFull
                          ? AppColors.emerald(context)
                          : colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    isFull
                        ? 'Fully Funded'
                        : '₹${fmtAmount(approved - invested)} remaining',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
            if (!isRepaid) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(UI.radiusSm),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor:
                      colorScheme.outlineVariant.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation(progressColor),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isOverdue
                        ? 'Overdue by ${(int.tryParse(inv['days_left']?.toString() ?? '0') ?? 0).abs()} days'
                        : '${inv['days_left']} days remaining',
                    style: TextStyle(
                      color: _isOverdue
                          ? AppColors.rose(context)
                          : colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}% elapsed',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'View details',
                  style: TextStyle(
                    color: colorScheme.primary.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 3),
                const SizedBox(width: 3),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Investment detail bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _InvestmentDetailSheet extends ConsumerWidget {
  const _InvestmentDetailSheet({
    required this.inv,
    required this.isRepaid,
    this.isBlackMode = false,
  });
  final Map<String, dynamic> inv;
  final bool isRepaid;
  final bool isBlackMode;

  double get _amount => double.tryParse(inv['amount']?.toString() ?? '0') ?? 0;
  double get _investorRate =>
      double.tryParse(inv['investor_rate']?.toString() ?? '0') ?? 0;

  int get _daysLeft => int.tryParse(inv['days_left']?.toString() ?? '0') ?? 0;
  int get _tenure => int.tryParse(inv['tenure_days']?.toString() ?? '0') ?? 30;
  double get _expectedProfit =>
      double.tryParse(inv['expected_profit']?.toString() ?? '0') ?? 0;
  double get _expectedPayout =>
      double.tryParse(inv['maturity_value']?.toString() ?? '0') ?? 0;
  double get _actualReturns =>
      double.tryParse(inv['actual_returns']?.toString() ?? '0') ?? 0;

  double get _progress {
    if (_tenure <= 0) return isRepaid ? 1.0 : 0.5;
    return ((_tenure - _daysLeft) / _tenure).clamp(0.0, 1.0);
  }

  bool get _isOverdue => !isRepaid && _daysLeft < 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = isRepaid
        ? AppColors.emerald(context)
        : _isOverdue
            ? AppColors.rose(context)
            : colorScheme.primary;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 60),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inv['company']?.toString() ?? 'Investment',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (inv['particular'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        inv['particular'].toString(),
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(UI.radiusSm),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  isRepaid
                      ? '✓  Repaid'
                      : _isOverdue
                          ? '⚠  Overdue'
                          : '●  Active',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const _SheetSection('Investment Summary'),
          _DetailCard(
            isBlackMode: isBlackMode,
            rows: [
              _Row(
                'Amount Invested',
                '₹${_fmtFull(_amount)}',
                valueColor: colorScheme.primary,
                bold: true,
              ),
              _Row('Investment Date', inv['created_at']?.toString() ?? '--'),
              _Row('Invoice Date', inv['invoice_date']?.toString() ?? '--'),
              _Row(
                'Reference / Funding ID',
                inv['id']?.toString() ?? '--',
                onCopy: () => _copy(
                  context,
                  inv['id']?.toString() ?? '',
                  'Reference ID copied',
                ),
              ),
              _Row('Invoice No.', inv['invoice_number']?.toString() ?? '--'),
              const _Row('Platform', 'Finworks360'),
            ],
          ),
          const SizedBox(height: 20),
          const _SheetSection('Invoice Parties'),
          _DetailCard(
            isBlackMode: isBlackMode,
            rows: [
              _Row('Seller (SME)', inv['company']?.toString() ?? '--'),
              _Row('Debtor (Payer)', inv['debtor']?.toString() ?? '--'),
              _Row('Category', inv['particular']?.toString() ?? '--'),
            ],
          ),
          const SizedBox(height: 20),
          _SheetSection(isRepaid ? 'Settlement Details' : 'Expected Returns'),
          _DetailCard(
            isBlackMode: isBlackMode,
            rows: [
              _Row(
                'Investor Rate (p.a.)',
                '${_investorRate.toStringAsFixed(2)}% p.a.',
                valueColor: AppColors.emerald(context),
                bold: true,
              ),
              if (!isRepaid) ...[
                _Row(
                  'Expected Interest',
                  '₹${_fmtFull(_expectedProfit)}',
                  valueColor: AppColors.emerald(context),
                ),
                _Row(
                  'Expected Payout',
                  '₹${_fmtFull(_expectedPayout)}',
                  bold: true,
                ),
                _Row(
                  'Payment Due Date',
                  inv['payment_date']?.toString() ?? '--',
                ),
                _Row(
                  'Days Remaining',
                  _isOverdue
                      ? 'Overdue by ${_daysLeft.abs()} days'
                      : '$_daysLeft days',
                  valueColor: _isOverdue
                      ? AppColors.rose(context)
                      : _daysLeft < 7
                          ? AppColors.amber(context)
                          : colorScheme.onSurface,
                ),
              ] else ...[
                _Row('Principal Returned', '₹${_fmtFull(_amount)}'),
                _Row(
                  'Interest Received',
                  '₹${_fmtFull(_actualReturns > 0 ? _actualReturns : _expectedProfit)}',
                  valueColor: AppColors.emerald(context),
                  bold: true,
                ),
                _Row(
                  'Total Amount Received',
                  '₹${_fmtFull(_amount + (_actualReturns > 0 ? _actualReturns : _expectedProfit))}',
                  bold: true,
                ),
                _Row(
                  'Settlement Date',
                  inv['payment_date']?.toString() ?? '--',
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          if (!isRepaid) ...[
            const _SheetSection('Tenure Timeline'),
            _DetailCard(
              isBlackMode: isBlackMode,
              rows: [
                _TimelineRow(
                  progress: _progress,
                  daysLeft: _daysLeft,
                  tenure: _tenure,
                  startDate: inv['invoice_date']?.toString() ?? '--',
                  dueDate: inv['payment_date']?.toString() ?? '--',
                ),
                _Row('Total Tenure', _tenure > 0 ? '$_tenure days' : '--'),
                _Row(
                  'Days Elapsed',
                  _tenure > 0
                      ? '${(_tenure - _daysLeft).clamp(0, _tenure)} days'
                      : '--',
                ),
                _Row(
                  'Days Remaining',
                  _isOverdue
                      ? 'Overdue by ${_daysLeft.abs()} days'
                      : '$_daysLeft days',
                  valueColor: _isOverdue
                      ? AppColors.rose(context)
                      : _daysLeft < 7
                          ? AppColors.amber(context)
                          : colorScheme.onSurface,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          _Banner(
            icon: AppIcons.receipt,
            title: 'Tax Information',
            body:
                'Returns from invoice discounting are taxable as Interest Income '
                'per your applicable IT slab (Indian Income Tax Act). TDS may apply. '
                'Download your investment statement from the Analytics screen for your records. Consult a CA for tax advice.',
            color: AppColors.amber(context),
          ),
          const SizedBox(height: 10),
          _Banner(
            icon: AppIcons.shield,
            title: 'Risk Disclosure',
            body:
                'Invoice discounting involves credit risk. Repayment depends on '
                'the debtor honouring the invoice. In case of debtor default, '
                'principal recovery may be delayed or partial. '
                'This platform is not a bank or NBFC; funds are not covered by '
                "RBI's Deposit Insurance & Credit Guarantee Scheme (DICGC). "
                'Past performance does not guarantee future returns. '
                'Invest only funds you can afford to lock in for the tenure.\n\n'
                'Funds are managed via an escrow account operated by our '
                'regulated banking partner.\n\n'
                'Finworks360 is a technology platform facilitating invoice '
                'financing between businesses and investors. It does not '
                'provide investment advice or guaranteed returns.',
            color: AppColors.rose(context),
          ),
          const SizedBox(height: 10),
          _Banner(
            icon: AppIcons.phone,
            title: 'Grievance Redressal',
            body: 'For disputes or concerns regarding this investment, contact '
                'support at lakhiwal43@gmail.com. We aim to resolve all '
                'grievances within 7 working days as per our investor charter.',
            color: AppColors.blue(context),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () => _copy(
              context,
              _buildSummaryText(),
              'Investment summary copied to clipboard',
            ),
            icon: Icon(AppIcons.copy, size: 16),
            label: const Text('Copy Investment Summary'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UI.radiusMd),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            ),
          ),
          if (!isRepaid) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (inv['is_listed'] == true)
                  ? null
                  : () => _handleEarlyExit(context, ref),
              icon: Icon(AppIcons.trendingUp, size: 16),
              label: Text(
                (inv['is_listed'] == true)
                    ? 'Listing Active (${inv['listing_status']?.toString().toUpperCase()})'
                    : 'Sell Stake (Early Exit)',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: (inv['is_listed'] == true)
                    ? colorScheme.surfaceContainerHigh
                    : AppColors.rose(context).withValues(alpha: 0.1),
                foregroundColor: (inv['is_listed'] == true)
                    ? colorScheme.onSurfaceVariant
                    : AppColors.rose(context),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UI.radiusMd),
                  side: BorderSide(
                    color: (inv['is_listed'] == true)
                        ? colorScheme.outlineVariant
                        : AppColors.rose(context).withValues(alpha: 0.2),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleEarlyExit(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Early Exit?'),
        content: Text(
          'This will list your stake of ₹${fmtAmount(_amount)} in the secondary market. '
          'You will receive the principal + accrued interest once another investor purchases it.\n\n'
          'Admin approval is required before listing goes active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rose(context),
            ),
            child: const Text('Request Exit'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;

      unawaited(
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: LoadingAnimationWidget.hexagonDots(
              color: Theme.of(context).colorScheme.primary,
              size: 40,
            ),
          ),
        ),
      );

      final result = await SecondaryMarketApiService.requestExit(inv['id']);

      if (!context.mounted) return;
      Navigator.pop(context);

      if (result['success']) {
        await _showSuccess(context, result['message']);
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    }
  }

  Future<void> _showSuccess(BuildContext context, String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(AppIcons.check, color: AppColors.emerald(ctx), size: 48),
        title: const Text('Request Submitted'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _copy(BuildContext context, String text, String msg) {
    unawaited(AppHaptics.selection());
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  String _buildSummaryText() => [
        'Finworks360 — Investment Summary',
        '─────────────────────────────',
        'Company    : ${inv['company'] ?? '--'}',
        'Debtor     : ${inv['debtor'] ?? '--'}',
        'Amount     : ₹${_fmtFull(_amount)}',
        'Rate       : ${_investorRate.toStringAsFixed(2)}% p.a.',
        'Tenure     : $_tenure days',
        'Status     : ${isRepaid ? 'Repaid' : _isOverdue ? 'Overdue' : 'Active'}',
        'Due Date   : ${inv['payment_date'] ?? '--'}',
        if (!isRepaid) 'Exp. Payout: ₹${_fmtFull(_expectedPayout)}',
        if (isRepaid)
          'Received   : ₹${_fmtFull(_actualReturns > 0 ? _actualReturns : _expectedProfit)}',
        '─────────────────────────────',
        'Ref ID     : ${inv['id'] ?? '--'}',
        'Invoice No : ${inv['invoice_number'] ?? '--'}',
      ].join('\n');
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail sheet sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SheetSection extends ConsumerWidget {
  const _SheetSection(this.title);
  final String title;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      );
}

class _Row {
  const _Row(
    this.label,
    this.value, {
    this.valueColor,
    this.bold = false,
    this.onCopy,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  final VoidCallback? onCopy;
}

class _TimelineRow extends _Row {
  const _TimelineRow({
    required this.progress,
    required this.daysLeft,
    required this.tenure,
    required this.startDate,
    required this.dueDate,
  }) : super('', '');
  final double progress;
  final int daysLeft;
  final int tenure;
  final String startDate;
  final String dueDate;
}

class _DetailCard extends ConsumerWidget {
  const _DetailCard({required this.rows, this.isBlackMode = false});
  final List<_Row> rows;
  final bool isBlackMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final widgets = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is _TimelineRow) {
        widgets.add(_buildTimeline(context, row));
      } else {
        widgets.add(_buildRow(context, row));
      }
      if (i < rows.length - 1) {
        widgets.add(
          Divider(
            height: 1,
            color: _cardBorder(context, isBlackMode),
            indent: 16,
            endIndent: 16,
          ),
        );
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: _cardBg(context, isBlackMode),
        borderRadius: BorderRadius.circular(UI.radiusLg),
        border: Border.all(color: _cardBorder(context, isBlackMode)),
      ),
      child: Column(children: widgets),
    );
  }

  Widget _buildRow(BuildContext context, _Row row) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            row.label,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          Row(
            children: [
              Text(
                row.value,
                style: TextStyle(
                  color: row.valueColor ?? colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: row.bold ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (row.onCopy != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: row.onCopy,
                  child: Icon(
                    AppIcons.copy,
                    size: 14,
                    color: colorScheme.primary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, _TimelineRow r) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOverdue = r.daysLeft < 0;
    final progressColor = isOverdue
        ? AppColors.rose(context)
        : r.progress > 0.85
            ? AppColors.amber(context)
            : AppColors.emerald(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              Text(
                r.tenure > 0
                    ? '${(r.progress * 100).toStringAsFixed(0)}% of ${r.tenure}d'
                    : '--',
                style: TextStyle(
                  color:
                      isOverdue ? AppColors.rose(context) : colorScheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(UI.radiusSm),
            child: LinearProgressIndicator(
              value: r.progress,
              minHeight: 8,
              backgroundColor:
                  colorScheme.outlineVariant.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation(progressColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                r.startDate,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              Text(
                r.dueDate,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Banner extends ConsumerWidget {
  const _Banner({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(UI.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.8),
                      fontSize: 11,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Metric extends ConsumerWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _MiniEmptyState extends StatelessWidget {
  const _MiniEmptyState({required this.label, required this.isRepaid});
  final String label;
  final bool isRepaid;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.portfolio,
            size: 40,
            color: colorScheme.outline.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            'No $label investments',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isRepaid
                ? 'Your settled assets will appear here'
                : 'Explore listings to start investing',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
