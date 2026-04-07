import 'package:flutter/material.dart';
import '../../view_models/marketplace_view_model.dart';
import '../vibe_state_wrapper.dart';
import '../stagger_list.dart';
import 'invoice_card.dart';
import 'fast_scrollbar.dart';
import '../../theme/ui_constants.dart';
import '../skeleton.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MarketplaceList extends ConsumerWidget {
  final MarketplaceState state;
  final MarketplaceNotifier notifier;
  final ScrollController scrollController;
  final GlobalKey<FastScrollbarState> scrollbarKey;

  const MarketplaceList({
    super.key,
    required this.state,
    required this.notifier,
    required this.scrollController,
    required this.scrollbarKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: UI.lg, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) {
              VibeState listState = VibeState.success;
              if (state.allInvoices.isEmpty) {
                listState =
                    state.isLoadingMore ? VibeState.loading : VibeState.empty;
              } else if (state.filtered.isEmpty) {
                listState = VibeState.empty;
              }

              return VibeStateWrapper(
                state: listState,
                loadingSkeleton: const SkeletonMarketplaceItems(cardCount: 3),
                errorMessage: state.errorMessage,
                onRetry: () => notifier.refresh(),
                emptyIcon: Icons.search_off_rounded,
                emptyTitle: state.allInvoices.isEmpty
                    ? 'No Invoices Found'
                    : 'No Results Found',
                emptySubtitle: state.allInvoices.isEmpty
                    ? 'Check back later for new opportunities'
                    : 'Try adjusting your filters or search query',
                child: const SizedBox.shrink(),
              );
            }

            final invoiceIndex = index - 1;
            if (invoiceIndex >= state.filtered.length) {
              if (state.isLoadingMore) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return null;
            }

            return StaggerItem(
              index: invoiceIndex,
              child: InvoiceCard(item: state.filtered[invoiceIndex]),
            );
          },
          childCount: state.filtered.length + 1 + (state.isLoadingMore ? 1 : 0),
        ),
      ),
    );
  }
}

class SkeletonMarketplaceItems extends ConsumerWidget {
  final int cardCount;
  const SkeletonMarketplaceItems({super.key, this.cardCount = 3});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: List.generate(
          cardCount,
          (index) => const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: SkeletonCard(height: 180),
              )),
    );
  }
}
