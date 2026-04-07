import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme_provider.dart';
import '../../../theme/ui_constants.dart';
import '../../../widgets/animated_amount_text.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Stats Row — Invested · Avg Return · Active Deals
// ═══════════════════════════════════════════════════════════════════════════════

class ProfileStatsRow extends ConsumerWidget {
  final double totalInvested;
  final double avgReturn;
  final int activeCount;

  const ProfileStatsRow({
    super.key,
    required this.totalInvested,
    required this.avgReturn,
    required this.activeCount,
  });

  static const String _masked = '● ● ●';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final hideBalance = ref.watch(themeProvider.select((p) => p.hideBalance));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              value: totalInvested,
              label: 'Invested',
              valueColor: AppColors.success(context),
              isAmount: true,
              prefix: '₹',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              value: avgReturn,
              label: 'Avg return',
              valueColor: colorScheme.primary,
              isAmount: true,
              suffix: '%',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              value: activeCount.toDouble(),
              label: 'Active',
              valueColor: AppColors.warning(context),
              isAmount: false,
              suffix: ' deals',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends ConsumerWidget {
  final double value;
  final String label;
  final Color valueColor;
  final bool isAmount;
  final String prefix;
  final String suffix;

  const _StatCard({
    required this.value,
    required this.label,
    required this.valueColor,
    this.isAmount = false,
    this.prefix = '',
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final hideBalance = ref.watch(themeProvider.select((p) => p.hideBalance));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(UI.radiusSm),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          AnimatedAmountText(
            value: value,
            prefix: prefix,
            suffix: suffix,
            hideValue: hideBalance,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}