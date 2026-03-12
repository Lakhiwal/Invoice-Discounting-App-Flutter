import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../theme/theme_provider.dart';
import '../utils/formatters.dart';
import '../utils/app_haptics.dart'; // Item #34
import '../services/portfolio_cache.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic>? _portfolio;
  bool _isLoading = true;

  // FIX #24: track error state for proper empty/error UI
  bool _hasError = false;

  // Cached — computed once when _portfolio changes, never inside build()
  List<Map<String, dynamic>> _sectorData = [];
  double _totalInvested = 0;

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
    // FIX #24: was missing try/catch — any network error crashed the screen
    try {
      final data = await PortfolioCache.getPortfolio();
      if (mounted) {
        final sd = _computeSectorData(data);
        setState(() {
          _portfolio = data;
          _sectorData = sd;
          _totalInvested =
              sd.fold(0.0, (sum, s) => sum + (s['amount'] as double));
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  List<Map<String, dynamic>> _computeSectorData(
      Map<String, dynamic>? portfolio) {
    final active = (portfolio?['active'] as List?) ?? [];
    final Map<String, double> sectorMap = {};

    for (final inv in active) {
      final sector = inv['particular'] ?? 'Other';
      final amount = double.tryParse(inv['amount'].toString()) ?? 0;
      sectorMap[sector] = (sectorMap[sector] ?? 0) + amount;
    }

    final colors = [
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF4C8BF5), // Blue
      const Color(0xFFEF4444), // Rose
      const Color(0xFFB06DFF), // Purple
      const Color(0xFF00D4FF), // Cyan
    ];

    return sectorMap.entries
        .toList()
        .asMap()
        .entries
        .map((e) {
      return {
        'label': e.value.key,
        'amount': e.value.value,
        'color': colors[e.key % colors.length],
      };
    }).toList();
  }

  Future<void> _generatePDF() async {
    final pdf = pw.Document();
    final logoBytes = (await rootBundle.load('assets/images/logo-colored.png'))
        .buffer
        .asUint8List();
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    final summary = _portfolio?['summary'];
    // FIX #14: use cached _sectorData instead of recomputing — previously
    // _computeSectorData(_portfolio) was called again, which could produce
    // different numbers than what was shown on screen if data changed.
    final sectorData = _sectorData;

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: ttf, bold: ttf),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) =>
        [
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
                    pw.Text('Portfolio Statement',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                        'Generated: ${DateTime.now().toString().substring(
                            0, 16)}',
                        style: const pw.TextStyle(
                            color: PdfColors.grey, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text('Portfolio Summary',
              style:
              pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _pdfStat('Invested',
                    '₹${fmtAmountFull(summary?['total_invested'])}'),
                _pdfStat(
                    'Returns', '₹${fmtAmountFull(summary?['total_returns'])}'),
                _pdfStat('Active', '${summary?['active_count'] ?? 0}'),
                _pdfStat('Repaid', '${summary?['repaid_count'] ?? 0}'),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          if (sectorData.isNotEmpty) ...[
            pw.Text('Sector Breakdown',
                style:
                pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              context: context,
              data: [
                ['Sector', 'Amount', 'Share'],
                ...sectorData.map((s) =>
                [
                  s['label'],
                  // FIX #15: was printing raw double e.g. '₹125000.0'
                  '₹${fmtAmount(s['amount'])}',
                  '${((s['amount'] as double) / _totalInvested * 100)
                      .toStringAsFixed(1)}%'
                ])
              ],
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  pw.Widget _pdfStat(String label, String value) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(value,
              style:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.Text(label,
              style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme
        .of(context)
        .colorScheme;
    final summary = _portfolio?['summary'];
    final sectorData = _sectorData;
    final totalInvested = _totalInvested;

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 48,
                color: colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('Could not load analytics',
                style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 15)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : _sectorData.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline_rounded,
                size: 48,
                color: colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No investments yet',
                style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 15)),
          ],
        ),
      )
          : CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            stretch: true,
            backgroundColor: colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('Analytics',
                  style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      letterSpacing: -0.5)),
              centerTitle: false,
              titlePadding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 16),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  AppHaptics.selection(); // Item #34
                  _generatePDF();
                },
                icon: Icon(Icons.download_rounded,
                    color: colorScheme.primary),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Summary cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                _SummaryTile(
                  label: 'Total Invested',
                  value:
                  '₹${fmtAmount(summary?['total_invested'] ?? '0')}',
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                _SummaryTile(
                  label: 'Total Returns',
                  value:
                  '₹${fmtAmount(summary?['total_returns'] ?? '0')}',
                  color: AppColors.success(context),
                ),
              ]),
            ),
          ),

          // Pie chart
          if (sectorData.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                        color: colorScheme.outlineVariant
                            .withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sector Breakdown',
                          style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 220,
                        child: _SectorPieChart(
                          sectorData: sectorData,
                          totalInvested: totalInvested,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Investment stats
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Investment Stats',
                      style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 16),
                  _StatTile(
                    label: 'Active Investments',
                    value: '${summary?['active_count'] ?? 0}',
                    icon: Icons.bolt_rounded,
                    color: AppColors.success(context),
                  ),
                  _StatTile(
                    label: 'Repaid Invoices',
                    value: '${summary?['repaid_count'] ?? 0}',
                    icon: Icons.check_circle_rounded,
                    color: colorScheme.primary,
                  ),
                  _StatTile(
                    label: 'Total Yield',
                    value:
                    '${summary?['total_returns_yield'] ?? '12.60'}%',
                    icon: Icons.trending_up_rounded,
                    color: AppColors.warning(context),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label, value;
  final Color color;

  const _SummaryTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme
        .of(context)
        .colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.w900)),
            Text(label,
                style: TextStyle(
                    color: colorScheme.onSurfaceVariant, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _StatTile({required this.label,
    required this.value,
    required this.icon,
    required this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme
        .of(context)
        .colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.05)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 16),
        Expanded(
            child: Text(label,
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600))),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 15, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _SectorPieChart extends StatefulWidget {
  final List<Map<String, dynamic>> sectorData;
  final double totalInvested;

  const _SectorPieChart(
      {required this.sectorData, required this.totalInvested});

  @override
  State<_SectorPieChart> createState() => _SectorPieChartState();
}

class _SectorPieChartState extends State<_SectorPieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: PieChart(
          PieChartData(
            pieTouchData: PieTouchData(
              touchCallback: (event, response) {
                setState(() {
                  if (!event.isInterestedForInteractions ||
                      response == null ||
                      response.touchedSection == null) {
                    _touchedIndex = -1;
                    return;
                  }
                  _touchedIndex = response.touchedSection!.touchedSectionIndex;
                });
              },
            ),
            sections: widget.sectorData
                .asMap()
                .entries
                .map((e) {
              final isTouched = e.key == _touchedIndex;
              final pct = widget.totalInvested > 0
                  ? (e.value['amount'] as double) / widget.totalInvested * 100
                  : 0.0;
              return PieChartSectionData(
                color: e.value['color'] as Color,
                value: e.value['amount'] as double,
                title: '${pct.toStringAsFixed(1)}%',
                radius: isTouched ? 80 : 65,
                titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              );
            }).toList(),
            sectionsSpace: 3,
            centerSpaceRadius: 40,
          ),
        ),
      ),
      const SizedBox(width: 16),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.sectorData.map((s) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: s['color'] as Color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(s['label'] as String,
                  style: TextStyle(
                      color: Theme
                          .of(context)
                          .colorScheme
                          .onSurfaceVariant,
                      fontSize: 11)),
            ]),
          );
        }).toList(),
      ),
    ]);
  }
}