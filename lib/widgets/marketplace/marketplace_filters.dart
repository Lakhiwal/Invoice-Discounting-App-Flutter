import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/view_models/marketplace_view_model.dart';

class MarketplaceFilters extends ConsumerWidget {
  const MarketplaceFilters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final marketplaceAsync = ref.watch(marketplaceProvider);
    final notifier = ref.read(marketplaceProvider.notifier);

    return marketplaceAsync.maybeWhen(
      data: (data) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            ...Marketplace.statusFilters.map(
              (f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f),
                  selected: data.selectedStatus == f,
                  onSelected: (s) {
                    if (s) notifier.setStatus(f);
                    AppHaptics.selection();
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 24,
              width: 1,
              color: cs.outlineVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 8),
            ...Marketplace.quickFilters.map(
              (f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f),
                  avatar: Icon(
                    AppIcons.flash,
                    size: 14,
                    color:
                        data.activeQuickFilter == f ? cs.onPrimary : cs.primary,
                  ),
                  selected: data.activeQuickFilter == f,
                  onSelected: (_) {
                    notifier.toggleQuickFilter(f);
                    AppHaptics.selection();
                  },
                ),
              ),
            ),
            if (data.activeQuickFilter != null || data.selectedStatus != 'All')
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: ActionChip(
                  label: const Text('Clear'),
                  avatar: Icon(AppIcons.close, size: 14),
                  onPressed: () {
                    notifier.clearFilters();
                    AppHaptics.selection();
                  },
                ),
              ),
          ],
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
