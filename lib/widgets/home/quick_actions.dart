import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/widgets/pressable.dart';

class QuickActions extends ConsumerWidget {
  const QuickActions({
    required this.isBlackMode,
    required this.onAdd,
    required this.onWithdraw,
    required this.onMarketplace,
    super.key,
  });
  final bool isBlackMode;
  final VoidCallback onAdd;
  final VoidCallback onWithdraw;
  final VoidCallback onMarketplace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isBlackMode ? Colors.transparent : colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(UI.radiusMd),
        border: Border.all(
          color: colorScheme.outlineVariant
              .withValues(alpha: isBlackMode ? 0.06 : 0.3),
        ),
      ),
      child: Row(
        children: [
          ActionButton(
            icon: AppIcons.add,
            label: 'Funds',
            color: const Color(0xFF10B981), // Fixed color for success
            onTap: onAdd,
          ),
          const ActionDivider(),
          ActionButton(
            icon: AppIcons.withdraw,
            label: 'Payout',
            color: colorScheme.error,
            onTap: onWithdraw,
          ),
          const ActionDivider(),
          ActionButton(
            icon: AppIcons.market,
            label: 'Market',
            color: colorScheme.primary,
            onTap: onMarketplace,
          ),
        ],
      ),
    );
  }
}

class ActionDivider extends ConsumerWidget {
  const ActionDivider({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        width: 1,
        height: 36,
        color:
            Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
      );
}

class ActionButton extends ConsumerWidget {
  const ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Expanded(
        child: Pressable(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(UI.radiusMd),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
