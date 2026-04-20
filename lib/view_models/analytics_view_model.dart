import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:invoice_discounting_app/services/portfolio_cache.dart';
import 'package:invoice_discounting_app/view_models/analytics_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'analytics_view_model.g.dart';

@riverpod
class Analytics extends _$Analytics {
  @override
  FutureOr<AnalyticsState> build() async => _loadInitialData();

  Future<AnalyticsState> _loadInitialData() async {
    try {
      final data = await PortfolioCache.getPortfolio();
      final rawActive = ((data['active'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
      final rawRepaid = ((data['repaid'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);

      final initialState = AnalyticsState(
        allActive: rawActive,
        allRepaid: rawRepaid,
      );

      return _computeMetrics(initialState);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final data = await PortfolioCache.getPortfolio(forceRefresh: true);
      final rawActive = ((data['active'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
      final rawRepaid = ((data['repaid'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);

      final newState = AnalyticsState(
        allActive: rawActive,
        allRepaid: rawRepaid,
      );

      return _computeMetrics(newState);
    });
  }

  Future<void> setTimeFilter(String filter) async {
    final current = state.value;
    if (current == null || current.timeFilter == filter) return;

    final next = current.copyWith(timeFilter: filter);
    state = AsyncData(next);

    // Perform re-computation
    state = await AsyncValue.guard(() => _computeMetrics(next));
  }

  Future<AnalyticsState> _computeMetrics(AnalyticsState current) async {
    // If we have a lot of items, use compute to offload to another isolate
    if (current.allActive.length + current.allRepaid.length > 200) {
      return compute(_calculateMetricsIsolate, current);
    } else {
      return _calculateMetricsIsolate(current);
    }
  }
}

// Heavy calculation logic moved to a top-level function for Compute
AnalyticsState _calculateMetricsIsolate(AnalyticsState state) {
  // 1. Filter by time
  final filteredActive = _applyTimeFilter(state.allActive, state.timeFilter);
  final filteredRepaid = _applyTimeFilter(state.allRepaid, state.timeFilter);

  final all = [...filteredActive, ...filteredRepaid];

  // 2. Base metrics
  final totalInvested =
      filteredActive.fold(0.0, (s, i) => s + _dbl(i['amount']));

  final totalReturns = filteredRepaid.fold(0.0, (s, i) {
    final actual = _dbl(i['actual_returns']);
    return s + (actual > 0 ? actual : _dbl(i['expected_profit']));
  });

  var avgYield = 0.0;
  if (filteredActive.isNotEmpty && totalInvested > 0) {
    var weightedSum = 0.0;
    for (final inv in filteredActive) {
      weightedSum += _dbl(inv['amount']) * _dbl(inv['investor_rate']);
    }
    avgYield = weightedSum / totalInvested;
  }

  var avgTenure = 0;
  if (all.isNotEmpty) {
    final totalTenure =
        all.fold<int>(0, (s, i) => s + (i['tenure_days'] as int? ?? 0));
    avgTenure = (totalTenure / all.length).round();
  }

  // 3. Complex data segments
  final sectorData = _computeSectorData(filteredActive);
  final maturityData = _computeMaturityData(filteredActive);
  final riskBuckets = _computeRiskBuckets(filteredActive);
  final monthlyEarnings =
      _computeMonthlyEarnings(filteredActive, filteredRepaid);

  final topHoldings = List<Map<String, dynamic>>.from(filteredActive)
    ..sort((a, b) => _dbl(b['amount']).compareTo(_dbl(a['amount'])));
  final limitedTop = topHoldings.take(5).toList();

  // 4. Health Score
  final health = _calculateHealth(
    filteredActive,
    totalInvested,
    avgYield,
    sectorData,
    riskBuckets,
  );

  return state.copyWith(
    filteredActive: filteredActive,
    filteredRepaid: filteredRepaid,
    totalInvested: totalInvested,
    totalReturns: totalReturns,
    avgYield: avgYield,
    avgTenure: avgTenure,
    sectorData: sectorData,
    maturityData: maturityData,
    riskBuckets: riskBuckets,
    monthlyEarnings: monthlyEarnings,
    topHoldings: limitedTop,
    healthScore: health.score,
    healthLabel: health.label,
    healthColor: health.color,
    healthFactors: health.factors,
  );
}

// Helpers
List<Map<String, dynamic>> _applyTimeFilter(
  List<Map<String, dynamic>> items,
  String filter,
) {
  if (filter == 'All') return items;

  final now = DateTime.now();
  DateTime cutoff;
  switch (filter) {
    case '3M':
      cutoff = DateTime(now.year, now.month - 3, now.day);
    case '6M':
      cutoff = DateTime(now.year, now.month - 6, now.day);
    case '1Y':
      cutoff = DateTime(now.year - 1, now.month, now.day);
    default:
      cutoff = DateTime(2000);
  }

  return items.where((i) {
    final d = DateTime.tryParse(i['created_at']?.toString() ?? '');
    return d != null && d.isAfter(cutoff);
  }).toList();
}

double _dbl(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;

const _sectorColors = [
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFF4C8BF5),
  Color(0xFFEF4444),
  Color(0xFFB06DFF),
  Color(0xFF00D4FF),
  Color(0xFFEC4899),
  Color(0xFF8B5CF6),
];

List<Map<String, dynamic>> _computeSectorData(
  List<Map<String, dynamic>> active,
) {
  final map = <String, double>{};
  for (final inv in active) {
    final sector = inv['particular']?.toString() ?? 'Other';
    map[sector] = (map[sector] ?? 0) + _dbl(inv['amount']);
  }
  return map.entries
      .toList()
      .asMap()
      .entries
      .map(
        (e) => {
          'label': e.value.key,
          'amount': e.value.value,
          'color': _sectorColors[e.key % _sectorColors.length],
        },
      )
      .toList();
}

List<Map<String, dynamic>> _computeMaturityData(
  List<Map<String, dynamic>> active,
) {
  final byMonth = <String, List<Map<String, dynamic>>>{};
  for (final inv in active) {
    final pd = DateTime.tryParse(inv['payment_date']?.toString() ?? '');
    if (pd == null) continue;
    final key = '${pd.year}-${pd.month.toString().padLeft(2, '0')}';
    byMonth.putIfAbsent(key, () => []).add(inv);
  }
  final sorted = byMonth.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return sorted.map((e) {
    final total = e.value.fold(0.0, (s, i) => s + _dbl(i['amount']));
    final dt = DateTime.tryParse('${e.key}-01') ?? DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return {
      'label': '${months[dt.month - 1]} ${dt.year}',
      'amount': total,
      'count': e.value.length,
      'isOverdue': dt.isBefore(DateTime.now()),
    };
  }).toList();
}

Map<String, double> _computeRiskBuckets(List<Map<String, dynamic>> active) {
  var safe = 0.0;
  var approaching = 0.0;
  var urgent = 0.0;
  var overdue = 0.0;
  for (final inv in active) {
    final daysLeft = inv['days_left'] as int? ?? 0;
    final amount = _dbl(inv['amount']);
    if (daysLeft < 0) {
      overdue += amount;
    } else if (daysLeft < 7) {
      urgent += amount;
    } else if (daysLeft < 30) {
      approaching += amount;
    } else {
      safe += amount;
    }
  }
  return {
    'safe': safe,
    'approaching': approaching,
    'urgent': urgent,
    'overdue': overdue,
  };
}

List<Map<String, dynamic>> _computeMonthlyEarnings(
  List<Map<String, dynamic>> active,
  List<Map<String, dynamic>> repaid,
) {
  final earned = <String, double>{};
  final projected = <String, double>{};
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  for (final inv in repaid) {
    final pd = DateTime.tryParse(inv['payment_date']?.toString() ?? '');
    if (pd == null) continue;
    final key = '${pd.year}-${pd.month}';
    final profit = _dbl(inv['actual_returns']) > 0
        ? _dbl(inv['actual_returns'])
        : _dbl(inv['expected_profit']);
    earned[key] = (earned[key] ?? 0) + profit;
  }
  for (final inv in active) {
    final pd = DateTime.tryParse(inv['payment_date']?.toString() ?? '');
    if (pd == null) continue;
    final key = '${pd.year}-${pd.month}';
    projected[key] = (projected[key] ?? 0) + _dbl(inv['expected_profit']);
  }
  final allKeys = {...earned.keys, ...projected.keys}.toList()..sort();
  return allKeys.map((key) {
    final parts = key.split('-');
    final month = int.parse(parts[1]);
    final dt = DateTime(int.parse(parts[0]), month);
    return {
      'label': months[month - 1],
      'earned': earned[key] ?? 0.0,
      'projected': projected[key] ?? 0.0,
      'isPast':
          dt.isBefore(DateTime(DateTime.now().year, DateTime.now().month)),
    };
  }).toList();
}

class _HealthResult {
  _HealthResult(this.score, this.label, this.color, this.factors);
  final int score;
  final String label;
  final Color color;
  final List<String> factors;
}

_HealthResult _calculateHealth(
  List<Map<String, dynamic>> active,
  double totalInvested,
  double avgYield,
  List<Map<String, dynamic>> sectorData,
  Map<String, double> risk,
) {
  if (active.isEmpty) {
    return _HealthResult(0, 'No data', Colors.grey, []);
  }
  final sectorCount = sectorData.length;
  final maxConcentration = totalInvested > 0
      ? sectorData.fold(
          0.0,
          (m, s) =>
              math.max(m, ((s['amount'] as num?)?.toDouble() ?? 0.0) / totalInvested),
        )
      : 1.0;
  final divScore = (sectorCount >= 4 && maxConcentration < 0.4)
      ? 100
      : (sectorCount >= 3 ? 75 : (sectorCount >= 2 ? 50 : 20));
  final yieldScore = (avgYield / 12.0 * 100).clamp(0.0, 100.0);
  final totalAmt = totalInvested > 0 ? totalInvested : 1;
  final safeWeighted = (risk['safe'] ?? 0) * 1.0 +
      (risk['approaching'] ?? 0) * 0.7 +
      (risk['urgent'] ?? 0) * 0.3;
  final safetyScore = (safeWeighted / totalAmt * 100).clamp(0.0, 100.0);
  final score = (divScore * 0.4 + yieldScore * 0.3 + safetyScore * 0.3).round();

  String label;
  Color color;
  if (score >= 80) {
    label = 'Excellent';
    color = const Color(0xFF12B76A);
  } else if (score >= 60) {
    label = 'Good';
    color = const Color(0xFFF59E0B);
  } else if (score >= 40) {
    label = 'Fair';
    color = const Color(0xFFF97316);
  } else {
    label = 'Needs attention';
    color = const Color(0xFFEF4444);
  }

  final factors = [
    if (divScore >= 75) 'Diversified' else 'Low diversity',
    if (yieldScore >= 80) 'Strong yield' else 'Yield below target',
    if (safetyScore >= 80)
      'No overdue'
    else if ((risk['overdue'] ?? 0) > 0)
      'Has overdue'
    else
      'Some urgent',
  ];
  return _HealthResult(score, label, color, factors);
}
