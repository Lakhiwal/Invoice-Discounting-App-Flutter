import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/widgets/animated_amount_text.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Stats Row — Invested · Avg Return · Active Deals
// ═══════════════════════════════════════════════════════════════════════════════

class ProfileStatsRow extends ConsumerWidget {
  const ProfileStatsRow({
    required this.totalInvested,
    required this.avgReturn,
    required this.activeCount,
    super.key,
  });
  final double totalInvested;
  final double avgReturn;
  final int activeCount;

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
              suffix: ' deals',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends ConsumerWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.valueColor,
    this.isAmount = false,
    this.prefix = '',
    this.suffix = '',
  });
  final double value;
  final String label;
  final Color valueColor;
  final bool isAmount;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final hideBalance = ref.watch(themeProvider.select((p) => p.hideBalance));

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: valueColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getIconForLabel(label),
              size: 14,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedAmountText(
            value: value,
            prefix: prefix,
            suffix: suffix,
            hideValue: hideBalance,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForLabel(String label) => switch (label.toLowerCase()) {
      'invested' => AppIcons.bank,
      'avg return' => AppIcons.trendingUp,
      'active' => AppIcons.layers,
      _ => AppIcons.info,
    };
}
