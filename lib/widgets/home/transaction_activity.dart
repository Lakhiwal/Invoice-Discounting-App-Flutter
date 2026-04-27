import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/formatters.dart';

const String _kMaskedShort = '● ● ●';

class TransactionActivityTile extends ConsumerWidget {
  const TransactionActivityTile({
    required this.tx,
    super.key,
  });
  final Map<String, dynamic> tx;

  static final Map<String, (IconData, bool)> _iconMap = {
    'invest': (AppIcons.trendingUp, false),
    'investment': (AppIcons.trendingUp, false),
    'return': (AppIcons.receipt, true),
    'repay': (AppIcons.receipt, true),
    'settlement': (AppIcons.receipt, true),
    'withdraw': (AppIcons.arrowDown, false),
    'add': (AppIcons.arrowUp, true),
    'deposit': (AppIcons.arrowUp, true),
    'credit': (AppIcons.arrowUp, true),
    'top-up': (AppIcons.arrowUp, true),
    'failed': (AppIcons.error, false),
    'expired': (AppIcons.timer, false),
  };

  (IconData, bool) _resolveIcon(String desc, String status, bool isCredit) {
    if (status == 'failed') return (AppIcons.error, false);
    if (status == 'expired') return (AppIcons.timer, false);

    final lower = desc.toLowerCase();
    for (final entry in _iconMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return isCredit
        ? (AppIcons.trendingDown, true)
        : (AppIcons.trendingUp, false);
  }

  static ({String title, String? interestLabel}) _parseSettlement(String desc) {
    if (!desc.toLowerCase().startsWith('settlement')) {
      return (title: desc, interestLabel: null);
    }
    final pipeIdx = desc.indexOf('|');
    final title = pipeIdx > 0 ? desc.substring(0, pipeIdx).trim() : desc;
    final match = RegExp(r'Interest\s*₹?([\d,.]+)').firstMatch(desc);
    if (match != null) {
      final val = double.tryParse(match.group(1)!.replaceAll(',', ''));
      if (val != null && val > 0) {
        return (title: title, interestLabel: '+₹${fmtAmount(val)} received');
      }
    }
    return (title: title, interestLabel: null);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideBalance = ref.watch(themeProvider.select((p) => p.hideBalance));
    final colorScheme = Theme.of(context).colorScheme;
    final isDebit = tx['type'] == 'debit';
    final desc = tx['description']?.toString() ?? 'Transaction';
    final txStatus = tx['status']?.toString() ?? 'completed';
    final isFailed = txStatus == 'failed' || txStatus == 'expired';
    final (icon, _) = _resolveIcon(desc, txStatus, !isDebit);
    final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;

    final parsed = _parseSettlement(desc);

    final Color accentColor;
    if (isFailed) {
      accentColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
    } else {
      accentColor = isDebit ? colorScheme.error : const Color(0xFF10B981);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(UI.radiusSm),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parsed.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isFailed
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    decoration: isFailed
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor:
                        colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      (tx['date'] as String?) ?? '',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    if (parsed.interestLabel != null &&
                        !isFailed &&
                        !hideBalance) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(UI.radiusSm),
                        ),
                        child: Text(
                          parsed.interestLabel!,
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    if (isFailed) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: txStatus == 'failed'
                              ? colorScheme.error.withValues(alpha: 0.1)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(UI.radiusSm),
                        ),
                        child: Text(
                          txStatus == 'failed' ? 'Failed' : 'Expired',
                          style: TextStyle(
                            color: txStatus == 'failed'
                                ? colorScheme.error
                                : const Color(0xFFF59E0B),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            hideBalance
                ? '${isDebit ? '-' : '+'}₹$_kMaskedShort'
                : '${isDebit ? '-' : '+'}₹${fmtAmount(amount)}',
            style: TextStyle(
              color: isFailed
                  ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                  : accentColor,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              decoration:
                  isFailed ? TextDecoration.lineThrough : TextDecoration.none,
              decorationColor:
                  colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyActivityPlaceholder extends ConsumerWidget {
  const EmptyActivityPlaceholder({
    required this.onExplore,
    super.key,
    this.isBlackMode = false,
  });
  final bool isBlackMode;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isBlackMode
              ? const Color(0xFF0A0A0A)
              : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(UI.radiusMd),
          border: Border.all(
            color: colorScheme.outlineVariant
                .withValues(alpha: isBlackMode ? 0.06 : 0.3),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(UI.radiusMd),
              ),
              child: Icon(
                AppIcons.receipt,
                size: 30,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No activity yet',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start investing to see your\ntransactions here',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onExplore,
                icon: Icon(AppIcons.market, size: 16),
                label: const Text('Explore Marketplace'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colorScheme.primary),
                  foregroundColor: colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UI.radiusSm),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
