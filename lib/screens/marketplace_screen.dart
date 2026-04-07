import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_haptics.dart';
import '../widgets/app_logo_header.dart';
import '../widgets/liquidity_refresh_indicator.dart';
import '../view_models/marketplace_view_model.dart';
import '../widgets/marketplace/marketplace_filters.dart';
import '../widgets/marketplace/marketplace_search.dart';
import '../widgets/marketplace/marketplace_list.dart';
import '../widgets/marketplace/fast_scrollbar.dart';
import '../widgets/skeleton.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  final GlobalKey<FastScrollbarState> _scrollbarKey = GlobalKey();
  bool _searchVisible = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final state = ref.read(marketplaceProvider);
    state.whenData((data) {
      if (data.isLoadingMore || !data.hasMore) return;
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.8) {
        ref.read(marketplaceProvider.notifier).loadMore();
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
      body: LiquidityRefreshIndicator(
        onRefresh: () => notifier.refresh(silent: true),
        color: cs.primary,
        child: marketplaceAsync.when(
          skipLoadingOnRefresh: true,
          loading: () => const SkeletonMarketplaceContent(),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 40, color: cs.error),
                const SizedBox(height: 16),
                Text('Error loading marketplace',
                    style: TextStyle(color: cs.error)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => notifier.refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (data) => Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                slivers: [
                  AppLogoHeader(
                    title: 'Marketplace',
                    actions: [
                      IconButton(
                        icon: Icon(
                            _searchVisible
                                ? Icons.search_off_rounded
                                : Icons.search_rounded,
                            color: cs.primary),
                        onPressed: () {
                          setState(() => _searchVisible = !_searchVisible);
                          if (!_searchVisible) {
                            _searchCtrl.clear();
                            notifier.setSearchQuery('');
                          }
                          AppHaptics.selection();
                        },
                      ),
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.tune_rounded),
                            onPressed: () {
                              AppHaptics.selection();
                              _showFilterSheet(context, data, notifier);
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
                                        shape: BoxShape.circle))),
                        ],
                      ),
                    ],
                  ),
                  if (_searchVisible)
                    SliverToBoxAdapter(
                      child: MarketplaceSearch(
                          controller: _searchCtrl,
                          notifier: notifier,
                          currentQuery: data.searchQuery),
                    ),
                  const SliverToBoxAdapter(
                    child: MarketplaceFilters(),
                  ),
                  MarketplaceList(
                    state: data,
                    notifier: notifier,
                    scrollController: _scrollController,
                    scrollbarKey: _scrollbarKey,
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
              if (data.filtered.length > 5)
                Positioned(
                  right: 4,
                  top: 180,
                  bottom: 100,
                  child: FastScrollbar(
                      key: _scrollbarKey,
                      controller: _scrollController,
                      itemCount: data.filtered.length),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context, MarketplaceState data,
      MarketplaceNotifier notifier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Filters',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                TextButton(
                    onPressed: () {
                      notifier.clearFilters();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Reset')),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Sort By',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SortChip(
                    label: 'ROI (High to Low)',
                    selected: data.sortBy == 'roi_high',
                    onSelected: (s) =>
                        notifier.setSortBy(s ? 'roi_high' : 'default')),
                _SortChip(
                    label: 'Days Left',
                    selected: data.sortBy == 'days_low',
                    onSelected: (s) =>
                        notifier.setSortBy(s ? 'days_low' : 'default')),
                _SortChip(
                    label: 'Investment Amount',
                    selected: data.sortBy == 'amount_high',
                    onSelected: (s) =>
                        notifier.setSortBy(s ? 'amount_high' : 'default')),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortChip extends ConsumerWidget {
  final String label;
  final bool selected;
  final Function(bool) onSelected;

  const _SortChip(
      {required this.label, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (s) {
        onSelected(s);
        AppHaptics.selection();
      },
    );
  }
}
