import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/formatters.dart';
import 'package:invoice_discounting_app/widgets/animated_amount_text.dart';

const String _kMaskedShort = '● ● ●';
const String _kMasked = '● ● ● ● ●';

class MaturityCalendar extends ConsumerWidget {
  const MaturityCalendar({
    required this.data,
    required this.hideBalance,
    super.key,
  });
  final List<Map<String, dynamic>> data;
  final bool hideBalance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(UI.radiusLg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Maturity calendar',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.9,
            ),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final m = data[index];
              final isOverdue = m['isOverdue'] as bool;
              final color =
                  isOverdue ? const Color(0xFFEF4444) : const Color(0xFF12B76A);
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(UI.radiusMd),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      m['label'] as String,
                      style:
                          TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    if (hideBalance)
                      Text(
                        '₹$_kMasked',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else
                      AnimatedAmountText(
                        value: (m['amount'] as num).toDouble(),
                        prefix: '₹',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      '${m['count']} invoice${(m['count'] as int) > 1 ? 's' : ''}',
                      style: TextStyle(color: color, fontSize: 10),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class RiskCard extends ConsumerWidget {
  const RiskCard({
    required this.buckets,
    required this.total,
    required this.hideBalance,
    super.key,
  });
  final Map<String, double> buckets;
  final double total;
  final bool hideBalance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final safe = buckets['safe'] ?? 0;
    final approaching = buckets['approaching'] ?? 0;
    final urgent = buckets['urgent'] ?? 0;
    final overdue = buckets['overdue'] ?? 0;
    double pct(double v) => total > 0 ? (v / total * 100) : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(UI.radiusLg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Risk distribution',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(UI.radiusMd),
            child: SizedBox(
              height: 22,
              child: Row(
                children: [
                  if (safe > 0)
                    Expanded(
                      flex: pct(safe).round().clamp(1, 100),
                      child: Container(color: const Color(0xFF12B76A)),
                    ),
                  if (approaching > 0)
                    Expanded(
                      flex: pct(approaching).round().clamp(1, 100),
                      child: Container(color: const Color(0xFFF59E0B)),
                    ),
                  if (urgent > 0)
                    Expanded(
                      flex: pct(urgent).round().clamp(1, 100),
                      child: Container(color: const Color(0xFFF97316)),
                    ),
                  if (overdue > 0)
                    Expanded(
                      flex: pct(overdue).round().clamp(1, 100),
                      child: Container(color: const Color(0xFFEF4444)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              if (safe > 0)
                _RiskLabel(
                  color: const Color(0xFF12B76A),
                  label: 'Safe 30d+',
                  value: hideBalance ? _kMaskedShort : '₹${fmtAmount(safe)}',
                ),
              if (approaching > 0)
                _RiskLabel(
                  color: const Color(0xFFF59E0B),
                  label: '7–30d',
                  value: hideBalance
                      ? _kMaskedShort
                      : '₹${fmtAmount(approaching)}',
                ),
              if (urgent > 0)
                _RiskLabel(
                  color: const Color(0xFFF97316),
                  label: '<7d',
                  value: hideBalance ? _kMaskedShort : '₹${fmtAmount(urgent)}',
                ),
              if (overdue > 0)
                _RiskLabel(
                  color: const Color(0xFFEF4444),
                  label: 'Overdue',
                  value: hideBalance ? _kMaskedShort : '₹${fmtAmount(overdue)}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RiskLabel extends ConsumerWidget {
  const _RiskLabel({
    required this.color,
    required this.label,
    required this.value,
  });
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$label $value',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      );
}

class SectorCard extends ConsumerStatefulWidget {
  const SectorCard({
    required this.sectorData,
    required this.totalInvested,
    super.key,
  });
  final List<Map<String, dynamic>> sectorData;
  final double totalInvested;

  @override
  ConsumerState<SectorCard> createState() => _SectorCardState();
}

class _SectorCardState extends ConsumerState<SectorCard> {
  int _touchedIndex = -1;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(UI.radiusLg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sector breakdown',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                response?.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex =
                                response!.touchedSection!.touchedSectionIndex;
                          });
                          if (_touchedIndex >= 0) AppHaptics.selection();
                        },
                      ),
                      sections: widget.sectorData.asMap().entries.map((e) {
                        final isTouched = e.key == _touchedIndex;
                        final pct = widget.totalInvested > 0
                            ? (e.value['amount'] as double) /
                                widget.totalInvested *
                                100
                            : 0.0;
                        return PieChartSectionData(
                          color: e.value['color'] as Color,
                          value: e.value['amount'] as double,
                          title: '${pct.toStringAsFixed(0)}%',
                          radius: isTouched ? 75 : 60,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 3,
                      centerSpaceRadius: 36,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.sectorData
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: s['color'] as Color,
                                  borderRadius: BorderRadius.circular(UI.radiusSm),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                s['label'] as String,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TopHoldingsCard extends ConsumerWidget {
  const TopHoldingsCard({
    required this.holdings,
    required this.hideBalance,
    super.key,
  });
  final List<Map<String, dynamic>> holdings;
  final bool hideBalance;

  static const _rankColors = [
    Color(0xFF12B76A),
    Color(0xFFF59E0B),
    Color(0xFF4C8BF5),
    Color(0xFFB06DFF),
    Color(0xFF00D4FF),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(UI.radiusLg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top holdings',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          ...holdings.asMap().entries.map((e) {
            final i = e.key;
            final inv = e.value;
            final color = _rankColors[i % _rankColors.length];
            return Column(
              children: [
                if (i > 0)
                  Divider(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.15),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(UI.radiusSm),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (inv['debtor'] as String?) ??
                                  (inv['company'] as String?) ??
                                  '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${inv['particular'] ?? ''} · ${inv['days_left']}d',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            hideBalance
                                ? '₹$_kMaskedShort'
                                : '₹${fmtAmount(double.tryParse(inv['amount']?.toString() ?? '0') ?? 0)}',
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${double.tryParse(inv['investor_rate']?.toString() ?? '0')?.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Color(0xFF12B76A),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
