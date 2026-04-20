import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/models/invoice_item.dart';
import 'package:invoice_discounting_app/screens/secondary_market_screen.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/view_models/marketplace_view_model.dart';
import 'package:invoice_discounting_app/widgets/app_logo_header.dart';
import 'package:invoice_discounting_app/widgets/liquidity_refresh_indicator.dart';
import 'package:invoice_discounting_app/widgets/marketplace/fast_scrollbar.dart';
import 'package:invoice_discounting_app/widgets/marketplace/invoice_card.dart';
import 'package:invoice_discounting_app/widgets/marketplace/marketplace_filters.dart';
import 'package:invoice_discounting_app/widgets/marketplace/marketplace_list.dart';
import 'package:invoice_discounting_app/widgets/marketplace/marketplace_search.dart';
import 'package:invoice_discounting_app/utils/momentum_haptics.dart';
import 'package:invoice_discounting_app/widgets/skeleton.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _primaryScrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey<FastScrollbarState> _scrollbarKey = GlobalKey();
  final MomentumHaptics _momentumHaptics = MomentumHaptics();
  bool _searchVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _primaryScrollCtrl.addListener(_onScroll);
  }

  void _onTabChanged() {
    // We only want to trigger haptics when the animation finishes
    // or when the index is definitively different.
    if (!_tabController.indexIsChanging) {
      unawaited(AppHaptics.navTap());
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _primaryScrollCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    _momentumHaptics.onScroll(_primaryScrollCtrl.position.pixels);

    final state = ref.read(marketplaceProvider);
    state.whenData((data) {
      if (data.isLoadingMore || !data.hasMore) return;
      if (_primaryScrollCtrl.position.pixels >=
          _primaryScrollCtrl.position.maxScrollExtent * 0.8) {
        unawaited(ref.read(marketplaceProvider.notifier).loadMore());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final marketplaceAsync = ref.watch(marketplaceProvider);
    final notifier = ref.read(marketplaceProvider.notifier);

    return Scaffold(
      backgroundColor: cs.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            AppLogoHeader(
              title: 'Marketplace',
              actions: [
                IconButton(
                  icon: Icon(
                    _searchVisible ? AppIcons.searchOff : AppIcons.search,
                    color: cs.primary,
                  ),
                  onPressed: () {
                    setState(() => _searchVisible = !_searchVisible);
                    if (!_searchVisible) {
                      _searchCtrl.clear();
                      notifier.setSearchQuery('');
                    } else {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _searchFocusNode.canRequestFocus) {
                          _searchFocusNode.requestFocus();
                        }
                      });
                    }
                    unawaited(AppHaptics.selection());
                  },
                ),
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(AppIcons.filter),
                      onPressed: () async {
                        unawaited(AppHaptics.selection());
                        if (mounted && marketplaceAsync.valueOrNull != null) {
                          _showFilterSheet(
                              context, marketplaceAsync.value!, notifier);
                        }
                      },
                    ),
                    if (notifier.getActiveFilterCount() > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: cs.primary,
                indicatorWeight: 4.0,
                labelColor: cs.primary,
                unselectedLabelColor: cs.onSurfaceVariant,
                indicatorSize: TabBarIndicatorSize.label,
                isScrollable: false,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'Primary Market'),
                  Tab(text: 'Secondary Market'),
                  Tab(text: 'Upcoming Invoice'),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Primary Market
            _buildPrimaryMarketTab(marketplaceAsync, notifier, cs),

            // Tab 2: Secondary Market
            const SecondaryMarketScreen(isEmbedded: true),

            // Tab 3: Upcoming Invoices
            const _UpcomingInvoicesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryMarketTab(
    AsyncValue<MarketplaceState> marketplaceAsync,
    MarketplaceNotifier notifier,
    ColorScheme cs,
  ) {
    return LiquidityRefreshIndicator(
      onRefresh: () => notifier.refresh(silent: true),
      color: cs.primary,
      child: marketplaceAsync.when(
        skipLoadingOnRefresh: true,
        loading: () => const CustomScrollView(
          physics: NeverScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              child: SkeletonMarketplaceContent(),
            ),
          ],
        ),
        error: (err, stack) => CustomScrollView(
          slivers: [
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(AppIcons.error, size: 40, color: cs.error),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading Primary Market',
                      style: TextStyle(color: cs.error),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: notifier.refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        data: (data) => Stack(
          children: [
            CustomScrollView(
              controller: _primaryScrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                if (_searchVisible)
                  SliverToBoxAdapter(
                    child: MarketplaceSearch(
                      controller: _searchCtrl,
                      focusNode: _searchFocusNode,
                      notifier: notifier,
                      currentQuery: data.searchQuery,
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: MarketplaceFilters(),
                ),
                MarketplaceList(
                  state: data,
                  notifier: notifier,
                  scrollController: _primaryScrollCtrl,
                  scrollbarKey: _scrollbarKey,
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
            if (data.filtered.length > 5)
              Positioned(
                right: 4,
                top: 40,
                bottom: 100,
                child: FastScrollbar(
                  key: _scrollbarKey,
                  controller: _primaryScrollCtrl,
                  itemCount: data.filtered.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(
    BuildContext context,
    MarketplaceState data,
    MarketplaceNotifier notifier,
  ) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        showDragHandle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            MediaQuery.of(context).padding.bottom + 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  TextButton(
                    onPressed: () {
                      AppHaptics.selection();
                      notifier.clearFilters();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Sort By',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _SortChip(
                    label: 'ROI (High to Low)',
                    selected: data.sortBy == 'roi_high',
                    onSelected: (s) =>
                        notifier.setSortBy(s ? 'roi_high' : 'default'),
                  ),
                  _SortChip(
                    label: 'Days Left',
                    selected: data.sortBy == 'days_low',
                    onSelected: (s) =>
                        notifier.setSortBy(s ? 'days_low' : 'default'),
                  ),
                  _SortChip(
                    label: 'Investment Amount',
                    selected: data.sortBy == 'amount_high',
                    onSelected: (s) =>
                        notifier.setSortBy(s ? 'amount_high' : 'default'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(UI.radiusMd),
                    ),
                  ),
                  onPressed: () {
                    AppHaptics.selection();
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingInvoicesTab extends StatefulWidget {
  const _UpcomingInvoicesTab();

  @override
  State<_UpcomingInvoicesTab> createState() => _UpcomingInvoicesTabState();
}

class _UpcomingInvoicesTabState extends State<_UpcomingInvoicesTab> {
  bool _isLoading = true;
  bool _hasError = false;
  List<InvoiceItem> _invoices = [];

  @override
  void initState() {
    super.initState();
    _fetchUpcoming();
  }

  Future<void> _fetchUpcoming() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final raw = await ApiService.getInvoices(limit: 50, status: 'upcoming');
      if (mounted) {
        setState(() {
          _invoices = raw
              .map((e) => InvoiceItem.fromMap(e as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CustomScrollView(
        physics: NeverScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            child: SkeletonUpcomingInvoices(),
          ),
        ],
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.error,
                size: 40, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            const Text('Error loading Upcoming Invoices'),
            TextButton(
              onPressed: _fetchUpcoming,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.searchOff,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            const Text(
              'No upcoming invoices',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: UI.lg, vertical: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                // Wrapper to disable interactions and make it look disabled
                return IgnorePointer(
                  child: Opacity(
                    opacity: 0.6,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: InvoiceCard(item: _invoices[index]),
                    ),
                  ),
                );
              },
              childCount: _invoices.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

class _SortChip extends ConsumerWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final Function(bool) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (s) {
          onSelected(s);
          unawaited(AppHaptics.selection());
        },
      );
}
