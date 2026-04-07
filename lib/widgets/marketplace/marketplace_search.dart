import 'package:flutter/material.dart';
import '../../utils/app_haptics.dart';
import '../../view_models/marketplace_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MarketplaceSearch extends ConsumerWidget {
  final TextEditingController controller;
  final MarketplaceNotifier notifier;
  final String currentQuery;

  const MarketplaceSearch({
    super.key,
    required this.controller,
    required this.notifier,
    required this.currentQuery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: TextField(
        controller: controller,
        autofocus: true,
        onChanged: notifier.setSearchQuery,
        decoration: InputDecoration(
          hintText: 'Search companies...',
          prefixIcon: Icon(Icons.search_rounded, color: cs.primary.withValues(alpha: 0.6)),
          suffixIcon: currentQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () {
                    controller.clear();
                    notifier.setSearchQuery('');
                    AppHaptics.selection();
                  },
                )
              : null,
          filled: true,
          fillColor: cs.surfaceContainerHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
