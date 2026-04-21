import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';

class PremiumSelectionSheet extends StatelessWidget {
  const PremiumSelectionSheet({
    required this.title, required this.items, required this.selectedValue, required this.onSelected, super.key,
  });

  final String title;
  final List<String> items;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<String> items,
    required String selectedValue,
    required ValueChanged<String> onSelected,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PremiumSelectionSheet(
        title: title,
        items: items,
        selectedValue: selectedValue,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use a slightly elevated surface color for the sheet body
    final bgColor = isDark ? const Color(0xFF151D33) : Colors.white;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: UI.sheetRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle & Title Header
            ClipRRect(
              borderRadius: UI.sheetRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: cs.surface.withOpacity(0.5),
                    border: Border(
                      bottom: BorderSide(
                        color: cs.outlineVariant.withOpacity(0.2),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.onSurfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              AppHaptics.selection();
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cs.onSurfaceVariant.withOpacity(0.1),
                              ),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // List Items
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  indent: 24,
                  endIndent: 24,
                  color: cs.outlineVariant.withOpacity(0.15),
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = item == selectedValue;

                  return InkWell(
                    onTap: () {
                      AppHaptics.selection();
                      onSelected(item);
                      Future.delayed(const Duration(milliseconds: 150), () {
                        if (context.mounted) Navigator.pop(context);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      color: isSelected
                          ? cs.primary.withOpacity(isDark ? 0.08 : 0.06)
                          : Colors.transparent,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected ? cs.primary : cs.onSurface,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              AppIcons.check,
                              color: cs.primary,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
