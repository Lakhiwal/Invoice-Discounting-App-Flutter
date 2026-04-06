import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../services/portfolio_cache.dart';
import '../theme/theme_provider.dart';
import '../utils/app_haptics.dart';
import '../utils/formatters.dart';
import '../widgets/skeleton.dart';
import '../widgets/animated_amount_text.dart';
import '../widgets/animated_empty_state.dart';
import '../widgets/app_logo_header.dart';
import '../widgets/liquidity_refresh_indicator.dart';
import '../widgets/pressable.dart';

// ── Masked constant ──────────────────────────────────────────────────────────
const String _kMaskedShort = '● ● ●';
const String _kMasked = '● ● ● ● ●';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic>? _portfolio;
  bool _isLoading = true;
  bool _hasError = false;

  // Raw data
  List<Map<String, dynamic>> _allActive = [];
  List<Map<String, dynamic>> _allRepaid = [];

  // Filters
  String _timeFilter = 'All';
  final List<String> _timeOptions = ['All', '3M', '6M', '1Y'];
  String _sectorFilter = 'All';

  // Computed (recomputed when filters change)
  List<Map<String, dynamic>> _filteredActive = [];
  List<Map<String, dynamic>> _filteredRepaid = [];
  List<Map<String, dynamic>> _sectorData = [];
  List<Map<String, dynamic>> _maturityData = [];
  Map<String, double> _riskBuckets = {};
  double _totalInvested = 0;
  double _totalReturns = 0;
  double _avgYield = 0;
  int _avgTenure = 0;
  int _healthScore = 0;
  String _healthLabel = '';
  Color _healthColor = const Color(0xFF12B76A);
  List<String> _healthFactors = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final data = await PortfolioCache.getPortfolio();
      if (mounted) {
        _portfolio = data;
        _parseRawData(data);
        _recompute();
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  void _parseRawData(Map<String, dynamic>? data) {
    _allActive = ((data?['active'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _allRepaid = ((data?['repaid'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

  }

  void _recompute() {
    // Apply filters
    _filteredActive = _applyFilters(_allActive);
    _filteredRepaid = _applyFilters(_allRepaid);

    final all = [..._filteredActive, ..._filteredRepaid];

    // Total invested
    _totalInvested = _filteredActive.fold(
        0.0, (s, i) => s + _dbl(i['amount']));

    // Total returns
    _totalReturns = _filteredRepaid.fold(0.0, (s, i) {
      final actual = _dbl(i['actual_returns']);
      return s + (actual > 0 ? actual : _dbl(i['expected_profit']));
    });

    // Avg yield (weighted by amount, active only)
    if (_filteredActive.isNotEmpty && _totalInvested > 0) {
      double weightedSum = 0;
      for (final inv in _filteredActive) {
        weightedSum += _dbl(inv['amount']) * _dbl(inv['investor_rate']);
      }
      _avgYield = weightedSum / _totalInvested;
    } else {
      _avgYield = 0;
    }

    // Avg tenure
    if (all.isNotEmpty) {
      final totalTenure =
      all.fold(0, (s, i) => s + (i['tenure_days'] as int? ?? 0));
      _avgTenure = (totalTenure / all.length).round();
    } else {
      _avgTenure = 0;
    }

    // Sector data
    _sectorData = _computeSectorData(_filteredActive);

    // Maturity calendar
    _maturityData = _computeMaturityData(_filteredActive);

    // Risk distribution
    _riskBuckets = _computeRiskBuckets(_filteredActive);

    // Health score
    _computeHealthScore();
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> items) {
    var result = items;

    // Sector filter
    if (_sectorFilter != 'All') {
      result = result
          .where((i) => (i['particular'] ?? 'Other') == _sectorFilter)
          .toList();
    }

    // Time filter
    if (_timeFilter != 'All') {
      final now = DateTime.now();
      DateTime cutoff;
      switch (_timeFilter) {
        case '3M':
          cutoff = DateTime(now.year, now.month - 3, now.day);
          break;
        case '6M':
          cutoff = DateTime(now.year, now.month - 6, now.day);
          break;
        case '1Y':
          cutoff = DateTime(now.year - 1, now.month, now.day);
          break;
        default:
          cutoff = DateTime(2000);
      }
      result = result.where((i) {
        final d = DateTime.tryParse(i['created_at']?.toString() ?? '');
        return d != null && d.isAfter(cutoff);
      }).toList();
    }

    return result;
  }

  // ── Sector breakdown ──────────────────────────────────────────────────────

  static const _sectorColors = [
    Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFF4C8BF5),
    Color(0xFFEF4444), Color(0xFFB06DFF), Color(0xFF00D4FF),
    Color(0xFFEC4899), Color(0xFF8B5CF6),
  ];

  List<Map<String, dynamic>> _computeSectorData(
      List<Map<String, dynamic>> active) {
    final Map<String, double> map = {};
    for (final inv in active) {
      final sector = inv['particular']?.toString() ?? 'Other';
      map[sector] = (map[sector] ?? 0) + _dbl(inv['amount']);
    }
    return map.entries.toList().asMap().entries.map((e) => {
      'label': e.value.key,
      'amount': e.value.value,
      'color': _sectorColors[e.key % _sectorColors.length],
    }).toList();
  }

  // ── Maturity calendar ─────────────────────────────────────────────────────

  List<Map<String, dynamic>> _computeMaturityData(
      List<Map<String, dynamic>> active) {
    final Map<String, List<Map<String, dynamic>>> byMonth = {};

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
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return {
        'label': '${months[dt.month - 1]} ${dt.year}',
        'amount': total,
        'count': e.value.length,
        'isOverdue': dt.isBefore(DateTime.now()),
      };
    }).toList();
  }

  // ── Risk distribution ─────────────────────────────────────────────────────

  Map<String, double> _computeRiskBuckets(
      List<Map<String, dynamic>> active) {
    double safe = 0, approaching = 0, urgent = 0, overdue = 0;
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

  // ── Health score ──────────────────────────────────────────────────────────

  void _computeHealthScore() {
    if (_filteredActive.isEmpty) {
      _healthScore = 0;
      _healthLabel = 'No data';
      _healthColor = Colors.grey;
      _healthFactors = [];
      return;
    }

    // 1. Diversification (40%)
    final sectorCount = _sectorData.length;
    final maxConcentration = _totalInvested > 0
        ? _sectorData.fold(0.0,
            (m, s) => math.max(m, (s['amount'] as double) / _totalInvested))
        : 1.0;
    double divScore;
    if (sectorCount >= 4 && maxConcentration < 0.4) {
      divScore = 100;
    } else if (sectorCount >= 3) {
      divScore = 75;
    } else if (sectorCount >= 2) {
      divScore = 50;
    } else {
      divScore = 20;
    }

    // 2. Yield (30%)
    final yieldScore = (_avgYield / 12.0 * 100).clamp(0.0, 100.0);

    // 3. Safety (30%)
    final totalAmt = _totalInvested > 0 ? _totalInvested : 1;
    final safeWeighted = (_riskBuckets['safe'] ?? 0) * 1.0 +
        (_riskBuckets['approaching'] ?? 0) * 0.7 +
        (_riskBuckets['urgent'] ?? 0) * 0.3 +
        (_riskBuckets['overdue'] ?? 0) * 0.0;
    final safetyScore = (safeWeighted / totalAmt * 100).clamp(0.0, 100.0);

    final score =
    (divScore * 0.4 + yieldScore * 0.3 + safetyScore * 0.3).round();
    _healthScore = score;

    if (score >= 80) {
      _healthLabel = 'Excellent';
      _healthColor = const Color(0xFF12B76A);
    } else if (score >= 60) {
      _healthLabel = 'Good';
      _healthColor = const Color(0xFFF59E0B);
    } else if (score >= 40) {
      _healthLabel = 'Fair';
      _healthColor = const Color(0xFFF97316);
    } else {
      _healthLabel = 'Needs attention';
      _healthColor = const Color(0xFFEF4444);
    }

    _healthFactors = [
      if (divScore >= 75) 'Diversified' else 'Low diversity',
      if (yieldScore >= 80) 'Strong yield' else 'Yield below target',
      if (safetyScore >= 80)
        'No overdue'
      else if ((_riskBuckets['overdue'] ?? 0) > 0)
        'Has overdue'
      else
        'Some urgent',
    ];
  }

  // ── Monthly earnings ──────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _monthlyEarnings {
    final Map<String, double> earned = {};
    final Map<String, double> projected = {};
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    // Earned
    for (final inv in _filteredRepaid) {
      final pd = DateTime.tryParse(inv['payment_date']?.toString() ?? '');
      if (pd == null) continue;
      final key = '${pd.year}-${pd.month}';

      final profit = _dbl(inv['actual_returns']) > 0
          ? _dbl(inv['actual_returns'])
          : _dbl(inv['expected_profit']);

      earned[key] = (earned[key] ?? 0) + profit;
    }

    // Projected
    for (final inv in _filteredActive) {
      final pd = DateTime.tryParse(inv['payment_date']?.toString() ?? '');
      if (pd == null) continue;
      final key = '${pd.year}-${pd.month}';

      projected[key] =
          (projected[key] ?? 0) + _dbl(inv['expected_profit']);
    }

    // Merge keys
    final allKeys = {...earned.keys, ...projected.keys}.toList()
      ..sort(); // chronological

    final result = <Map<String, dynamic>>[];

    for (final key in allKeys) {
      final parts = key.split('-');
      final month = int.parse(parts[1]);
      final label = months[month - 1];

      final dt = DateTime(int.parse(parts[0]), month, 1);
      final now = DateTime.now();
      final isPast = dt.isBefore(DateTime(now.year, now.month, 1));

      result.add({
        'label': label,
        'earned': earned[key] ?? 0.0,
        'projected': projected[key] ?? 0.0,
        'isPast': isPast,
      });
    }

    return result;
  }

  // ── Top holdings ──────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _topHoldings {
    final sorted = List<Map<String, dynamic>>.from(_filteredActive)
      ..sort((a, b) => _dbl(b['amount']).compareTo(_dbl(a['amount'])));
    return sorted.take(5).toList();
  }

  // ── PDF ───────────────────────────────────────────────────────────────────

  Future<void> _generatePDF() async {
    final pdf = pw.Document();
    final logoBytes = (await rootBundle.load('assets/images/logo-colored.png'))
        .buffer.asUint8List();
    final summary = _portfolio?['summary'];

    pdf.addPage(pw.MultiPage(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('0A0F2C'),
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(pw.MemoryImage(logoBytes), height: 40),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Portfolio Analytics',
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                      'Generated: ${DateTime.now().toString().substring(0, 16)}',
                      style: const pw.TextStyle(
                          color: PdfColors.grey, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 24),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          _pdfStat('Invested', '₹${fmtAmountFull(summary?['total_invested'])}'),
          _pdfStat('Returns', '₹${fmtAmountFull(summary?['total_returns'])}'),
          _pdfStat('Active', '${summary?['active_count'] ?? 0}'),
          _pdfStat('Health', '$_healthScore/100'),
        ]),
        pw.SizedBox(height: 24),
        if (_sectorData.isNotEmpty) ...[
          pw.Text('Sector Breakdown',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(context: ctx, data: [
            ['Sector', 'Amount', 'Share'],
            ..._sectorData.map((s) => [
              s['label'],
              '₹${fmtAmount(s['amount'])}',
              '${((s['amount'] as double) / (_totalInvested > 0 ? _totalInvested : 1) * 100).toStringAsFixed(1)}%',
            ])
          ]),
        ],
      ],
    ));
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  pw.Widget _pdfStat(String label, String value) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(value,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
      pw.Text(label,
          style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
    ],
  );

  // ── Helpers ───────────────────────────────────────────────────────────────

  static double _dbl(dynamic v) =>
      double.tryParse(v?.toString() ?? '0') ?? 0;

  void _setTimeFilter(String f) {
    setState(() {
      _timeFilter = f;
      _recompute();
    });
    AppHaptics.selection();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hide = context.select<ThemeProvider, bool>((p) => p.hideBalance);

    if (_isLoading) return const SkeletonAnalyticsContent();

    if (_hasError) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Center(
          child: AnimatedEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Connection Issue',
            subtitle: 'We couldn\'t load your analytics data at this time.',
            actionLabel: 'Try Again',
            onAction: _loadData,
          ),
        ),
      );
    }

    if (_allActive.isEmpty && _allRepaid.isEmpty) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Center(
          child: AnimatedEmptyState(
            icon: Icons.analytics_outlined,
            title: 'No Data Yet',
            subtitle: 'Start investing to see your portfolio analytics here.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          final currentIndex = _timeOptions.indexOf(_timeFilter);
          if (details.primaryVelocity! < 0 &&
              currentIndex < _timeOptions.length - 1) {
            _setTimeFilter(_timeOptions[currentIndex + 1]);
          } else if (details.primaryVelocity! > 0 &&
              currentIndex > 0) {
            _setTimeFilter(_timeOptions[currentIndex - 1]);
          }
        },
        child: LiquidityRefreshIndicator(
          onRefresh: () async => _loadData(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // ── App bar ──────────────────────────────────────────
              AppLogoHeader(
                title: 'Analytics',
                actions: [
                  IconButton(
                    onPressed: () {
                      AppHaptics.selection();
                      _generatePDF();
                    },
                    icon: Icon(Icons.download_rounded, color: cs.primary),
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // ── Filters ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: _timeOptions.map((f) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: f,
                          active: _timeFilter == f,
                          onTap: () => _setTimeFilter(f),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // ── Health ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _HealthScoreCard(
                    score: _healthScore,
                    label: _healthLabel,
                    color: _healthColor,
                    factors: _healthFactors,
                  ),
                ),
              ),

              // ── Metrics ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'Invested',
                        numericValue: hide ? null : _totalInvested,
                        value: hide ? '₹$_kMaskedShort' : null,
                        prefix: '₹',
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCard(
                        label: 'Returns',
                        numericValue: hide ? null : _totalReturns,
                        value: hide ? '₹$_kMaskedShort' : null,
                        prefix: '₹',
                        color: AppColors.success(context),
                      ),
                    ),
                  ]),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'Avg. yield',
                        numericValue: _avgYield,
                        suffix: '%',
                        color: AppColors.warning(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCard(
                        label: 'Active / Repaid',
                        value:
                            '${_filteredActive.length} / ${_filteredRepaid.length}',
                        color: cs.onSurface,
                      ),
                    ),
                  ]),
                ),
              ),

              // ── Maturity calendar ────────────────────────────────
              if (_maturityData.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _MaturityCalendar(
                        data: _maturityData, hideBalance: hide),
                  ),
                ),

              // ── Risk distribution ────────────────────────────────
              if (_totalInvested > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _RiskCard(
                      buckets: _riskBuckets,
                      total: _totalInvested,
                      hideBalance: hide,
                    ),
                  ),
                ),

              // ── Sector breakdown ─────────────────────────────────
              if (_sectorData.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _SectorCard(
                      sectorData: _sectorData,
                      totalInvested: _totalInvested,
                    ),
                  ),
                ),

              // ── Top holdings ─────────────────────────────────────
              if (_topHoldings.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _TopHoldingsCard(
                      holdings: _topHoldings,
                      hideBalance: hide,
                    ),
                  ),
                ),

              // ── Monthly earnings ─────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _EarningsCard(
                      key: ValueKey(_timeFilter),
                      data: _monthlyEarnings,
                      hideBalance: hide,
                    ),
                  ),
                ),
              ),

              // ── Stats ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _StatsCard(
                    activeCount: _filteredActive.length,
                    repaidCount: _filteredRepaid.length,
                    avgTenure: _avgTenure,
                    sectorCount: _sectorData.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

// ── Filter chip ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? cs.primary.withValues(alpha: 0.12)
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active
                  ? cs.primary
                  : cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? cs.primary : cs.onSurfaceVariant,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }
}

// ── Health score ────────────────────────────────────────────────────────────

class _HealthScoreCard extends StatelessWidget {
  final int score;
  final String label;
  final Color color;
  final List<String> factors;

  const _HealthScoreCard({
    required this.score,
    required this.label,
    required this.color,
    required this.factors,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = score / 100;

    return Pressable(
      onTap: () async {
        await AppHaptics.selection();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text('Portfolio health',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 12),
            SizedBox(
              width: 100,
              height: 100,
              child: CustomPaint(
                painter: _GaugePainter(
                  progress: progress,
                  color: color,
                  trackColor: cs.outlineVariant.withValues(alpha: 0.2),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$score',
                          style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 28,
                              fontWeight: FontWeight.w800)),
                      Text(label,
                          style: TextStyle(color: color, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: factors.map((f) {
                final good = !f.contains('Low') &&
                    !f.contains('below') &&
                    !f.contains('overdue') &&
                    !f.contains('urgent');
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    good ? Icons.check_circle_rounded : Icons.warning_rounded,
                    size: 14,
                    color: good
                        ? AppColors.success(context)
                        : AppColors.warning(context),
                  ),
                  const SizedBox(width: 4),
                  Text(f,
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 11)),
                ]);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _GaugePainter(
      {required this.progress, required this.color, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 7.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress || old.color != color;
}

// ── Metric card ─────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final String? value;
  final double? numericValue;
  final String? prefix;
  final String? suffix;
  final Color color;

  const _MetricCard({
    required this.label,
    this.value,
    this.numericValue,
    this.prefix,
    this.suffix,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
          const SizedBox(height: 4),
          if (numericValue != null)
            AnimatedAmountText(
              value: numericValue!,
              prefix: prefix ?? '',
              suffix: suffix ?? '',
              style: TextStyle(
                  color: color, fontSize: 19, fontWeight: FontWeight.w800),
            )
          else
            Text(
              value ?? '',
              style: TextStyle(
                  color: color, fontSize: 19, fontWeight: FontWeight.w800),
            ),
        ],
      ),
    );
  }
}

// ── Maturity calendar ───────────────────────────────────────────────────────

class _MaturityCalendar extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final bool hideBalance;

  const _MaturityCalendar({required this.data, required this.hideBalance});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border:
        Border.all(color: cs.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Maturity calendar',
            style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3)),
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
            final color = isOverdue
                ? AppColors.danger(context)
                : AppColors.success(context);
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(m['label'] as String,
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 11)),
                  const SizedBox(height: 2),
                  if (hideBalance)
                    Text('₹$_kMasked',
                        style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w800))
                  else
                    AnimatedAmountText(
                      value: (m['amount'] as num).toDouble(),
                      prefix: '₹',
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w800),
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
      ]),
    );
  }
}

// ── Risk distribution ───────────────────────────────────────────────────────

class _RiskCard extends StatelessWidget {
  final Map<String, double> buckets;
  final double total;
  final bool hideBalance;

  const _RiskCard(
      {required this.buckets, required this.total, required this.hideBalance});

  @override
  Widget build(BuildContext context) {
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
        borderRadius: BorderRadius.circular(24),
        border:
        Border.all(color: cs.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Risk distribution',
            style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3)),
        const SizedBox(height: 12),
        // Stacked bar
        ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: SizedBox(
            height: 22,
            child: Row(children: [
              if (safe > 0)
                Expanded(
                    flex: pct(safe).round().clamp(1, 100),
                    child: Container(color: AppColors.success(context))),
              if (approaching > 0)
                Expanded(
                    flex: pct(approaching).round().clamp(1, 100),
                    child: Container(color: AppColors.warning(context))),
              if (urgent > 0)
                Expanded(
                    flex: pct(urgent).round().clamp(1, 100),
                    child: Container(color: const Color(0xFFF97316))), // orange
              if (overdue > 0)
                Expanded(
                    flex: pct(overdue).round().clamp(1, 100),
                    child: Container(color: const Color(0xFFEF4444))), // red
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 4, children: [
          if (safe > 0)
            _RiskLabel(
                color: AppColors.success(context),
                label: 'Safe 30d+',
                value: hideBalance ? _kMaskedShort : '₹${fmtAmount(safe)}'),
          if (approaching > 0)
            _RiskLabel(
                color: AppColors.warning(context),
                label: '7–30d',
                value: hideBalance
                    ? _kMaskedShort
                    : '₹${fmtAmount(approaching)}'),
          if (urgent > 0)
            _RiskLabel(
                color: const Color(0xFFF97316),
                label: '<7d',
                value: hideBalance ? _kMaskedShort : '₹${fmtAmount(urgent)}'),
          if (overdue > 0)
            _RiskLabel(
                color: cs.error,
                label: 'Overdue',
                value:
                hideBalance ? _kMaskedShort : '₹${fmtAmount(overdue)}'),
        ]),
      ]),
    );
  }
}

class _RiskLabel extends StatelessWidget {
  final Color color;
  final String label, value;
  const _RiskLabel(
      {required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 8,
          height: 8,
          decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text('$label $value',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11)),
    ]);
  }
}

// ── Sector breakdown ────────────────────────────────────────────────────────

class _SectorCard extends StatefulWidget {
  final List<Map<String, dynamic>> sectorData;
  final double totalInvested;

  const _SectorCard(
      {required this.sectorData, required this.totalInvested});

  @override
  State<_SectorCard> createState() => _SectorCardState();
}

class _SectorCardState extends State<_SectorCard> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border:
        Border.all(color: cs.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sector breakdown',
            style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3)),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: Row(children: [
            Expanded(
              child: PieChart(PieChartData(
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
                        fontWeight: FontWeight.w700),
                  );
                }).toList(),
                sectionsSpace: 3,
                centerSpaceRadius: 36,
              )),
            ),
            const SizedBox(width: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.sectorData.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: s['color'] as Color,
                            borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 6),
                    Text(s['label'] as String,
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 11)),
                  ]),
                );
              }).toList(),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Top holdings ────────────────────────────────────────────────────────────

class _TopHoldingsCard extends StatelessWidget {
  final List<Map<String, dynamic>> holdings;
  final bool hideBalance;

  const _TopHoldingsCard(
      {required this.holdings, required this.hideBalance});

  static const _rankColors = [
    Color(0xFF12B76A),
    Color(0xFFF59E0B),
    Color(0xFF4C8BF5),
    Color(0xFFB06DFF),
    Color(0xFF00D4FF),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border:
        Border.all(color: cs.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Top holdings',
            style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3)),
        const SizedBox(height: 12),
        ...holdings.asMap().entries.map((e) {
          final i = e.key;
          final inv = e.value;
          final color = _rankColors[i % _rankColors.length];
          return Column(children: [
            if (i > 0)
              Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.15)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                      child: Text('${i + 1}',
                          style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w700))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inv['debtor'] ?? inv['company'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        Text(
                          '${inv['particular'] ?? ''} · ${inv['days_left']}d',
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 11),
                        ),
                      ]),
                ),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        hideBalance
                            ? '₹$_kMaskedShort'
                            : '₹${fmtAmount(_AnalyticsScreenState._dbl(inv['amount']))}',
                        style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${double.tryParse(inv['investor_rate']?.toString() ?? '0')?.toStringAsFixed(1)}%',
                        style: TextStyle(
                            color: AppColors.success(context), fontSize: 11),
                      ),
                    ]),
              ]),
            ),
          ]);
        }),
      ]),
    );
  }
}

// ── Monthly earnings ────────────────────────────────────────────────────────

class _EarningsCard extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final bool hideBalance;

  const _EarningsCard({
    super.key,
    required this.data,
    required this.hideBalance,
  });

  @override
  State<_EarningsCard> createState() => _EarningsCardState();
}

class _EarningsCardState extends State<_EarningsCard> {
  int _touchedIndex = -1;
  double _anim = 0;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 200), () {
      setState(() {
        _anim = 1;
      });
    });
  }
  List<FlSpot> _getLineSpots() {
    final spots = <FlSpot>[];

    for (int i = 0; i < widget.data.length; i++) {
      final d = widget.data[i];
      final isPast = d['isPast'] as bool;

      final val = isPast
          ? (d['earned'] as double? ?? 0)
          : (d['projected'] as double? ?? 0);

      spots.add(FlSpot(i.toDouble(), val));
    }

    return spots;
  }



  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final maxVal = widget.data.fold(0.0, (m, d) {
      final e = d['earned'] as double;
      final p = d['projected'] as double;
      return math.max(m, math.max(e, p));
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly earnings',
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),

          const SizedBox(height: 16),

          SizedBox(
            height: 160,
            child: Stack(
              children: [

                /// 🔥 LINE CHART (BACKGROUND)
                LineChart(
                  LineChartData(
                    lineTouchData: LineTouchData(
                      handleBuiltInTouches: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (spot) =>
                        Theme.of(context).colorScheme.surface,
                        getTooltipItems: (spots) {
                          return spots.map((s) {
                            return LineTooltipItem(
                              '₹${fmtAmount(s.y)}\n${widget.data[s.x.toInt()]['label']}',
                              TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),

                    minX: 0,
                    maxX: (widget.data.length - 1).toDouble(),
                    minY: 0,
                    maxY: widget.data.fold<double>(0.0, (m, d) {
                      final e = d['earned'] as double? ?? 0;
                      final p = d['projected'] as double? ?? 0;
                      final isPast = d['isPast'] as bool;
                      final val = isPast ? e : p;
                      return math.max(m, val);
                    }),

                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),

                    lineBarsData: [
                      LineChartBarData(
                        shadow: Shadow(
                          color: AppColors.success(context).withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                        spots: _getLineSpots()
                            .map((s) => FlSpot(
                          s.x,
                          s.y * Curves.easeOutCubic.transform(_anim),
                        ))
                            .toList(),
                        isCurved: true,
                        curveSmoothness: 0.2,
                        preventCurveOverShooting: true,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.success(context),
                            AppColors.success(context).withValues(alpha: 0.3),
                          ],
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.success(context).withValues(alpha: 0.4),
                              AppColors.success(context).withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                        barWidth: 1.8,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) {
                            final isSelected = index == _touchedIndex;

                            return FlDotCirclePainter(
                              radius: isSelected ? 6 : 2,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.success(context),
                              strokeWidth: isSelected ? 2 : 0,
                              strokeColor: AppColors.success(context),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                /// 🔥 BARS (FRONT)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: widget.data.asMap().entries.map((entry) {
                    final index = entry.key;
                    final d = entry.value;

                    final earned = d['earned'] as double;
                    final projected = d['projected'] as double;
                    final isPast = d['isPast'] as bool;

                    final val = isPast ? earned : projected;

                    final h = maxVal > 0 && val > 0
                        ? (val / maxVal * 80).clamp(8.0, 100.0)
                        : 8.0;

                    final isSelected = _touchedIndex == index;
                    final opacity = isSelected ? 1.0 : 0.6;
                    final barHeight = isSelected ? h + 6 : h;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _touchedIndex = index;
                          });
                          AppHaptics.selection();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [

                              /// TOOLTIP
                              if (_touchedIndex == index && val > 0)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '₹${fmtAmount(val)}',
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                ),

                              AnimatedContainer(
                                duration: const Duration(milliseconds: 400),

                                height: barHeight * Curves.easeOutCubic.transform(_anim),
                                decoration: BoxDecoration(
                                  gradient: isPast
                                      ? LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      AppColors.success(context).withValues(alpha: opacity),
                                      AppColors.success(context).withValues(alpha: opacity * 0.6),
                                    ],
                                  )
                                      : null,
                                  color: isPast
                                      ? null
                                      : Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: isSelected ? 0.35 : 0.15),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6)),
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text(d['label'] as String,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 9)),
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

          const SizedBox(height: 10),

          // Legend
          Row(children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.success(context),
                        AppColors.success(context).withValues(alpha: 0.3),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 4),
            Text('Earned',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10)),
            const SizedBox(width: 12),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: cs.outlineVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.5)),
              ),
            ),
            const SizedBox(width: 4),
            Text('Projected',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10)),
          ]),
        ],
      ),
    );
  }
}

// ── Stats card ──────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final int activeCount, repaidCount, avgTenure, sectorCount;

  const _StatsCard({
    required this.activeCount,
    required this.repaidCount,
    required this.avgTenure,
    required this.sectorCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = [
      (Icons.bolt_rounded, 'Active investments', '$activeCount',
      AppColors.success(context)),
      (Icons.check_circle_rounded, 'Repaid invoices', '$repaidCount',
      cs.primary),
      (Icons.schedule_rounded, 'Avg. tenure', '$avgTenure days', cs.onSurface),
      (Icons.category_rounded, 'Sectors diversified', '$sectorCount',
      cs.onSurface),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border:
        Border.all(color: cs.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Investment stats',
            style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3)),
        const SizedBox(height: 12),
        ...items.asMap().entries.map((e) {
          final (icon, label, value, color) = e.value;
          return Column(children: [
            if (e.key > 0)
              Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.12)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(label,
                        style: TextStyle(
                            color: cs.onSurface, fontSize: 13))),
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ]);
        }),
      ]),
    );
  }
}