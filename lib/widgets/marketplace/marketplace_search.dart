import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/view_models/marketplace_view_model.dart';

class MarketplaceSearch extends ConsumerWidget {
  const MarketplaceSearch({
    required this.controller,
    required this.notifier,
    required this.currentQuery,
    this.focusNode,
    super.key,
  });
  final TextEditingController controller;
  final MarketplaceNotifier notifier;
  final String currentQuery;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: notifier.setSearchQuery,
        decoration: InputDecoration(
          hintText: 'Search companies...',
          prefixIcon: Icon(
            AppIcons.search,
            color: cs.primary.withValues(alpha: 0.6),
          ),
          suffixIcon: currentQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(AppIcons.close, size: 20),
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
            borderRadius: BorderRadius.circular(UI.radiusMd),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
