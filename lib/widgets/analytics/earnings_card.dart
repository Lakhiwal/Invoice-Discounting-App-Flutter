import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/formatters.dart';

class EarningsCard extends ConsumerStatefulWidget {
  const EarningsCard({
    required this.data,
    required this.hideBalance,
    super.key,
  });
  final List<Map<String, dynamic>> data;
  final bool hideBalance;

  @override
  ConsumerState<EarningsCard> createState() => _EarningsCardState();
}

class _EarningsCardState extends ConsumerState<EarningsCard> {
  int _touchedIndex = -1;
  double _anim = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(
      const Duration(milliseconds: 200),
      () => setState(() => _anim = 1),
    );
  }

  List<FlSpot> _getLineSpots() {
    final spots = <FlSpot>[];
    for (var i = 0; i < widget.data.length; i++) {
      final d = widget.data[i];
      final val = (d['isPast'] as bool)
          ? (d['earned'] as double)
          : (d['projected'] as double);
      spots.add(FlSpot(i.toDouble(), val));
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxVal = widget.data.fold<double>(
      0.0,
      (m, d) => math.max(
        m,
        math.max(
          (d['earned'] as num?)?.toDouble() ?? 0.0,
          (d['projected'] as num?)?.toDouble() ?? 0.0,
        ),
      ),
    );

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
            'Monthly returns (estimated)',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: Stack(
              children: [
                LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (widget.data.length - 1).toDouble(),
                    minY: 0,
                    maxY: maxVal,
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        shadow: Shadow(
                          color: const Color(0xFF12B76A).withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                        spots: _getLineSpots()
                            .map(
                              (s) => FlSpot(
                                s.x,
                                s.y * Curves.easeOutCubic.transform(_anim),
                              ),
                            )
                            .toList(),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF12B76A), Color(0x4D12B76A)],
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x6612B76A),
                              Color(0x0D12B76A),
                            ],
                          ),
                        ),
                        barWidth: 1.8,
                        dotData: FlDotData(
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                            radius: _touchedIndex == index ? 6 : 2,
                            color: _touchedIndex == index
                                ? Colors.white
                                : const Color(0xFF12B76A),
                            strokeWidth: _touchedIndex == index ? 2 : 0,
                            strokeColor: const Color(0xFF12B76A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: widget.data.asMap().entries.map((entry) {
                    final index = entry.key;
                    final d = entry.value;
                    final val = (d['isPast'] as bool)
                        ? (d['earned'] as double)
                        : (d['projected'] as double);
                    final h = maxVal > 0 && val > 0
                        ? ((val / maxVal * 80).clamp(8.0, 100.0) as num)
                            .toDouble()
                        : 8.0;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _touchedIndex = index);
                          AppHaptics.selection();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (_touchedIndex == index && val > 0)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.surface,
                                    borderRadius:
                                        BorderRadius.circular(UI.radiusSm),
                                  ),
                                  child: Text(
                                    '₹${fmtAmount(val)}',
                                    style: TextStyle(
                                      color: cs.onSurface,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              Container(
                                height: h,
                                decoration: BoxDecoration(
                                  color: (d['isPast'] as bool)
                                      ? const Color(0xFF12B76A).withValues(
                                          alpha: _touchedIndex == index
                                              ? 1.0
                                              : 0.6,
                                        )
                                      : cs.primary.withValues(
                                          alpha: _touchedIndex == index
                                              ? 0.8
                                              : 0.4,
                                        ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(UI.radiusSm),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                d['label'] as String,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 9,
                                  fontWeight: _touchedIndex == index
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
