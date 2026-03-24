import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/theme_provider.dart';
import '../../../theme/ui_constants.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Stats Row — Invested · Avg Return · Active Deals
// ═══════════════════════════════════════════════════════════════════════════════

class ProfileStatsRow extends StatelessWidget {
  final double totalInvested;
  final double avgReturn;
  final int activeCount;
  final bool hideBalance;

  const ProfileStatsRow({
    super.key,
    required this.totalInvested,
    required this.avgReturn,
    required this.activeCount,
    this.hideBalance = false,
  });

  String _formatCompact(double value) {
    if (value >= 10000000) return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '₹${(value / 1000).toStringAsFixed(1)}K';
    return '₹${value.toStringAsFixed(0)}';
  }

  static const String _masked = '● ● ●';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
              value: hideBalance ? '₹$_masked' : _formatCompact(totalInvested),
              label: 'Invested',
              valueColor: AppColors.success(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              value: hideBalance
                  ? '$_masked%'
                  : '${avgReturn.toStringAsFixed(1)}%',
              label: 'Avg return',
              valueColor: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              value: hideBalance ? _masked : '$activeCount deals',
              label: 'Active',
              valueColor: AppColors.warning(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const _StatCard({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 16,
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