import 'package:flutter/material.dart';
import '../../models/invoice_item.dart';
import '../../utils/app_haptics.dart';
import '../../screens/invoice_detail_screen.dart';
import '../../theme/ui_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InvoiceCard extends ConsumerWidget {
  final InvoiceItem item;

  const InvoiceCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(UI.radiusLg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            AppHaptics.selection();
            Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceDetailScreen(item: item)));
          },
          borderRadius: BorderRadius.circular(UI.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(UI.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.company, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                          const SizedBox(height: 2),
                          Text(item.debtor, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    _StatusBadge(status: item.status, display: item.statusDisplay),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MetricItem(label: 'ROI', value: item.roiDisplay, color: cs.primary),
                    _MetricItem(label: 'Tenure', value: item.tenureDisplay),
                    _MetricItem(label: 'Maturity', value: item.daysLeftDisplay),
                  ],
                ),
                const SizedBox(height: 20),
                _FundingProgress(pct: item.fundingPct, remaining: item.remainingDisplay),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends ConsumerWidget {
  final String status;
  final String display;
  const _StatusBadge({required this.status, required this.display});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isPartial = status.toLowerCase().contains('partial') || display.toLowerCase().contains('partial');
    final color = isPartial ? Colors.orange : (status.toLowerCase().contains('avail') ? Colors.green : cs.onSurfaceVariant);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(display, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
    );
  }
}

class _MetricItem extends ConsumerWidget {
  final String label;
  final String value;
  final Color? color;
  const _MetricItem({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color ?? cs.onSurface, fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _FundingProgress extends ConsumerWidget {
  final double pct;
  final String remaining;
  const _FundingProgress({required this.pct, required this.remaining});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${pct.toStringAsFixed(1)}% Funded', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
            Text('$remaining left', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(height: 6, decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(10))),
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              height: 6,
              width: MediaQuery.of(context).size.width * (pct / 100) * 0.8,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [cs.primary, cs.primary.withValues(alpha: 0.7)]),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 1))],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
