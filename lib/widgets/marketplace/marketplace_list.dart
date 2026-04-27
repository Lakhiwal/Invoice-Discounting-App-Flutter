import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/view_models/marketplace_view_model.dart';
import 'package:invoice_discounting_app/widgets/marketplace/fast_scrollbar.dart';
import 'package:invoice_discounting_app/widgets/marketplace/invoice_card.dart';
import 'package:invoice_discounting_app/widgets/skeleton.dart';
import 'package:invoice_discounting_app/widgets/stagger_list.dart';
import 'package:invoice_discounting_app/widgets/vibe_state_wrapper.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class MarketplaceList extends ConsumerWidget {
  const MarketplaceList({
    required this.state,
    required this.notifier,
    required this.scrollController,
    required this.scrollbarKey,
    super.key,
  });
  final MarketplaceState state;
  final MarketplaceNotifier notifier;
  final ScrollController scrollController;
  final GlobalKey<FastScrollbarState> scrollbarKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: UI.lg, vertical: 8),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == 0) {
                var listState = VibeState.success;
                if (state.allInvoices.isEmpty) {
                  listState =
                      state.isLoadingMore ? VibeState.loading : VibeState.empty;
                } else if (state.filtered.isEmpty) {
                  listState = VibeState.empty;
                }

                return VibeStateWrapper(
                  state: listState,
                  loadingSkeleton: const SkeletonMarketplaceItems(),
                  errorMessage: state.errorMessage,
                  onRetry: notifier.refresh,
                  emptyIcon: AppIcons.searchOff,
                  emptyTitle: state.allInvoices.isEmpty
                      ? 'No invoices found'
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: LoadingAnimationWidget.staggeredDotsWave(color: Theme.of(context).colorScheme.primary, size: 24)),
                  );
                }
                return null;
              }

              return StaggerItem(
                index: invoiceIndex,
                child: InvoiceCard(item: state.filtered[invoiceIndex]),
              );
            },
            childCount:
                state.filtered.length + 1 + (state.isLoadingMore ? 1 : 0),
          ),
        ),
      );
}

class SkeletonMarketplaceItems extends ConsumerWidget {
  const SkeletonMarketplaceItems({super.key, this.cardCount = 3});
  final int cardCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        children: List.generate(
          cardCount,
          (index) => const SkeletonCard(margin: EdgeInsets.only(bottom: 16)),
        ),
      );
}
