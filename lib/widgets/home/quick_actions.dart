import 'package:flutter/material.dart';
import '../pressable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuickActions extends ConsumerWidget {
  final bool isBlackMode;
  final VoidCallback onAdd, onWithdraw, onMarketplace;

  const QuickActions({
    super.key,
    required this.isBlackMode,
    required this.onAdd,
    required this.onWithdraw,
    required this.onMarketplace,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
          color:
              isBlackMode ? Colors.transparent : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: colorScheme.outlineVariant
                  .withValues(alpha: isBlackMode ? 0.06 : 0.3))),
      child: Row(children: [
        ActionButton(
            icon: Icons.add_rounded,
            label: 'Add Funds',
            color: const Color(0xFF10B981), // Fixed color for success
            onTap: onAdd),
        const ActionDivider(),
        ActionButton(
            icon: Icons.south_rounded,
            label: 'Withdraw',
            color: colorScheme.error,
            onTap: onWithdraw),
        const ActionDivider(),
        ActionButton(
            icon: Icons.storefront_outlined,
            label: 'Invest',
            color: colorScheme.primary,
            onTap: onMarketplace),
      ]),
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
          Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4));
}

class ActionButton extends ConsumerWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Expanded(
        child: Pressable(
            onTap: onTap,
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(icon, color: color, size: 18)),
                  const SizedBox(height: 5),
                  Text(label,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ]))));
  }
}
