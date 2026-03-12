import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/portfolio_cache.dart';
import '../theme/theme_provider.dart';
import '../utils/app_haptics.dart';
// FIX #17: use shared fmtAmount from formatters.dart
import '../utils/formatters.dart';
import '../widgets/pressable.dart';
import '../widgets/stagger_list.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

// FIX #17: fmtAmount() removed — replaced by fmtAmount() from formatters.dart.

String _fmtFull(dynamic v) {
  try {
    return double.parse(v.toString()).toStringAsFixed(2);
  } catch (_) {
    return '0.00';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PortfolioScreen
// ─────────────────────────────────────────────────────────────────────────────

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _portfolio;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPortfolio();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPortfolio({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);

    // FIX #16: only bypass cache on explicit pull-to-refresh (forceRefresh=true).
    // Previously invalidate() was called unconditionally, so the initial load
    // always skipped the 10-second cache and made a network call — even when
    // HomeScreen had just fetched fresh data moments before.
    if (forceRefresh) PortfolioCache.invalidate();

    try {
      final data = await PortfolioCache.getPortfolio();
      if (!mounted) return;
      setState(() {
        _portfolio = data;
        _isLoading = false;
      });
      AppHaptics.numberReveal();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final summary = _portfolio?['summary'];
    final active = (_portfolio?['active'] as List?) ?? [];
    final repaid = (_portfolio?['repaid'] as List?) ?? [];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _loadPortfolio(forceRefresh: true),
        child: CustomScrollView(
          // Item #13: platform-adaptive scroll physics
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── App bar ────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 120,
              pinned: true,
              stretch: true,
              backgroundColor: colorScheme.surface,
              flexibleSpace: FlexibleSpaceBar(
                title: Text('Portfolio',
                    style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: -0.5)),
                centerTitle: false,
                titlePadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
              actions: [
                IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => _loadPortfolio(forceRefresh: true)),
                const SizedBox(width: 8),
              ],
            ),

            // ── Summary tiles ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    _SummaryTile(
                        label: 'Invested',
                        value: '₹${fmtAmount(summary?['total_invested'] ?? 0)}',
                        icon: Icons.account_balance_wallet_rounded,
                        color: colorScheme.primary),
                    const SizedBox(width: 12),
                    _SummaryTile(
                        label: 'Returns',
                        value: '₹${fmtAmount(summary?['total_returns'] ?? 0)}',
                        icon: Icons.trending_up_rounded,
                        color: AppColors.emerald(context)),
                  ],
                ),
              ),
            ),

            // ── Pinned tab bar ─────────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabDelegate(
                child: Container(
                  color: colorScheme.surface,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(12)),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: colorScheme.onPrimary,
                    unselectedLabelColor: colorScheme.onSurfaceVariant,
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(text: 'Active (${active.length})'),
                      Tab(text: 'Repaid (${repaid.length})'),
                    ],
                  ),
                ),
              ),
            ),

            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _InvestmentList(
                      investments: active,
                      isRepaid: false,
                      isLoading: _isLoading),
                  _InvestmentList(
                      investments: repaid,
                      isRepaid: true,
                      isLoading: _isLoading),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary tile
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _SummaryTile(
      {required this.label,
        required this.value,
        required this.icon,
        required this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.1))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
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

// ─────────────────────────────────────────────────────────────────────────────
// Investment list
// ─────────────────────────────────────────────────────────────────────────────

class _InvestmentList extends StatelessWidget {
  final List investments;
  final bool isRepaid, isLoading;

  const _InvestmentList(
      {required this.investments,
        required this.isRepaid,
        required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (investments.isEmpty) {
      return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pie_chart_outline_rounded,
                    size: 64,
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(
                  isRepaid ? 'No repaid investments' : 'No active investments',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 15),
                ),
              ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      itemCount: investments.length,
      itemBuilder: (ctx, i) => StaggerItem(
          index: i,
          child: _InvestmentCard(
              inv: investments[i] as Map<String, dynamic>,
              isRepaid: isRepaid)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Investment card
// ─────────────────────────────────────────────────────────────────────────────

class _InvestmentCard extends StatelessWidget {
  final Map<String, dynamic> inv;
  final bool isRepaid;

  const _InvestmentCard({required this.inv, required this.isRepaid});

  // FIX: tenure_days now comes from the API (invoice_date → payment_date).
  // days_left can be negative (overdue) — API no longer caps it at 0.
  double _progress() {
    try {
      final daysLeft = int.tryParse(inv['days_left']?.toString() ?? '0') ?? 0;
      final tenure = int.tryParse(inv['tenure_days']?.toString() ?? '0') ?? 0;
      if (tenure <= 0) return isRepaid ? 1.0 : 0.5;
      return ((tenure - daysLeft) / tenure).clamp(0.0, 1.0);
    } catch (_) {
      return isRepaid ? 1.0 : 0.5;
    }
  }

  // FIX: days_left is no longer capped at 0, so negative → overdue.
  bool get _isOverdue {
    if (isRepaid) return false;
    return (int.tryParse(inv['days_left']?.toString() ?? '0') ?? 0) < 0;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = _progress();

    final statusColor = isRepaid
        ? AppColors.emerald(context)
        : _isOverdue
        ? AppColors.rose(context)
        : colorScheme.primary;

    final progressColor = progress > 0.85
        ? AppColors.amber(context)
        : AppColors.emerald(context);

    // Item #15: Pressable for consistent spring-back feedback
    return Pressable(
      onTap: () async {
        await AppHaptics.selection();
        if (context.mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            backgroundColor: colorScheme.surface,
            shape: const RoundedRectangleBorder(
                borderRadius:
                BorderRadius.vertical(top: Radius.circular(28))),
            builder: (_) =>
                _InvestmentDetailSheet(inv: inv, isRepaid: isRepaid),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.1))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Text(inv['company']?.toString() ?? 'Company',
                        style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                            fontSize: 16))),
                Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(
                        isRepaid
                            ? 'Repaid'
                            : _isOverdue
                            ? 'Overdue'
                            : 'Active',
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800))),
              ],
            ),
            const SizedBox(height: 16),

            // ── Metrics ─────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Metric(
                    label: 'Invested',
                    value: '₹${fmtAmount(inv['amount'])}'),
                // FIX: show investor_rate (what they earn), not gross roi
                _Metric(
                    label: 'Investor Rate',
                    value: '${inv['investor_rate']}% p.a.'),
                _Metric(
                    label: isRepaid ? 'Settled On' : 'Due Date',
                    value: inv['payment_date']?.toString() ?? '--'),
              ],
            ),

            // ── Progress bar (active only) ───────────────────────────
            if (!isRepaid) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor:
                  colorScheme.outlineVariant.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation(progressColor),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isOverdue
                        ? 'Overdue by ${(int.tryParse(inv['days_left']?.toString() ?? '0') ?? 0).abs()} days'
                        : '${inv['days_left']} days remaining',
                    style: TextStyle(
                        color: _isOverdue
                            ? AppColors.rose(context)
                            : colorScheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                  Text('${(progress * 100).toStringAsFixed(0)}% elapsed',
                      style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11)),
                ],
              ),
            ],

            // ── Tap hint ─────────────────────────────────────────────
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('View details',
                  style: TextStyle(
                      color: colorScheme.primary.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 3),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 9,
                  color: colorScheme.primary.withValues(alpha: 0.7)),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Investment detail bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _InvestmentDetailSheet extends StatelessWidget {
  final Map<String, dynamic> inv;
  final bool isRepaid;

  const _InvestmentDetailSheet(
      {required this.inv, required this.isRepaid});

  double get _amount =>
      double.tryParse(inv['amount']?.toString() ?? '0') ?? 0;

  // FIX: use investor_rate (what investor earns), not gross roi
  double get _investorRate =>
      double.tryParse(inv['investor_rate']?.toString() ?? '0') ?? 0;

  double get _grossRoi =>
      double.tryParse(inv['roi']?.toString() ?? '0') ?? 0;

  // FIX: days_left can now be negative (overdue)
  int get _daysLeft =>
      int.tryParse(inv['days_left']?.toString() ?? '0') ?? 0;

  // FIX: tenure_days comes from API (invoice_date → payment_date, never shrinks)
  int get _tenure =>
      int.tryParse(inv['tenure_days']?.toString() ?? '0') ?? 30;

  // FIX: expected_profit computed by API using original tenure
  double get _expectedProfit =>
      double.tryParse(inv['expected_profit']?.toString() ?? '0') ?? 0;

  // FIX: maturity_value computed by API using original tenure
  double get _expectedPayout =>
      double.tryParse(inv['maturity_value']?.toString() ?? '0') ?? 0;

  // FIX: actual_returns from InvoiceSettlement (settled invoices only)
  double get _actualReturns =>
      double.tryParse(inv['actual_returns']?.toString() ?? '0') ?? 0;

  double get _progress {
    if (_tenure <= 0) return isRepaid ? 1.0 : 0.5;
    return ((_tenure - _daysLeft) / _tenure).clamp(0.0, 1.0);
  }

  bool get _isOverdue => !isRepaid && _daysLeft < 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = isRepaid
        ? AppColors.emerald(context)
        : _isOverdue
        ? AppColors.rose(context)
        : colorScheme.primary;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 60),
        children: [
          // ── Header ────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inv['company']?.toString() ?? 'Investment',
                      style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5),
                    ),
                    if (inv['particular'] != null) ...[
                      const SizedBox(height: 4),
                      Text(inv['particular'].toString(),
                          style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13)),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.3))),
                child: Text(
                  isRepaid
                      ? '✓  Repaid'
                      : _isOverdue
                      ? '⚠  Overdue'
                      : '●  Active',
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Investment Summary ─────────────────────────────────────
          _SheetSection('Investment Summary'),
          _DetailCard(rows: [
            _Row('Amount Invested', '₹${_fmtFull(_amount)}',
                valueColor: colorScheme.primary, bold: true),
            _Row('Investment Date',
                inv['created_at']?.toString() ?? '--'),
            _Row('Invoice Date',
                inv['invoice_date']?.toString() ?? '--'),
            _Row('Reference / Funding ID',
                inv['id']?.toString() ?? '--',
                onCopy: () => _copy(
                    context, inv['id']?.toString() ?? '',
                    'Reference ID copied')),
            _Row('Invoice No.',
                inv['invoice_number']?.toString() ?? '--'),
            _Row('Platform', 'Finworks360'),
          ]),
          const SizedBox(height: 20),

          // ── Parties ────────────────────────────────────────────────
          _SheetSection('Invoice Parties'),
          _DetailCard(rows: [
            _Row('Seller (SME)', inv['company']?.toString() ?? '--'),
            // FIX: renamed from "Buyer" → "Debtor" (matches your platform terminology)
            _Row('Debtor (Payer)', inv['debtor']?.toString() ?? '--'),
            _Row('Category', inv['particular']?.toString() ?? '--'),
          ]),
          const SizedBox(height: 20),

          // ── Returns ────────────────────────────────────────────────
          _SheetSection(isRepaid ? 'Settlement Details' : 'Expected Returns'),
          _DetailCard(rows: [
            // FIX: show investor_rate (net to investor), not gross roi
            _Row('Investor Rate (p.a.)',
                '${_investorRate.toStringAsFixed(2)}% p.a.',
                valueColor: AppColors.emerald(context),
                bold: true),
            if (!isRepaid) ...[
              _Row('Expected Interest', '₹${_fmtFull(_expectedProfit)}',
                  valueColor: AppColors.emerald(context)),
              // FIX: renamed from "Maturity Amount" → "Expected Payout"
              _Row('Expected Payout', '₹${_fmtFull(_expectedPayout)}',
                  bold: true),
              _Row('Payment Due Date',
                  inv['payment_date']?.toString() ?? '--'),
              _Row(
                'Days Remaining',
                _isOverdue
                    ? 'Overdue by ${_daysLeft.abs()} days'
                    : '$_daysLeft days',
                valueColor: _isOverdue
                    ? AppColors.rose(context)
                    : _daysLeft < 7
                    ? AppColors.amber(context)
                    : colorScheme.onSurface,
              ),
            ] else ...[
              _Row('Principal Returned', '₹${_fmtFull(_amount)}'),
              _Row(
                'Interest Received',
                // FIX: use actual_returns from InvoiceSettlement
                '₹${_fmtFull(_actualReturns > 0 ? _actualReturns : _expectedProfit)}',
                valueColor: AppColors.emerald(context),
                bold: true,
              ),
              _Row(
                'Total Amount Received',
                '₹${_fmtFull(_amount + (_actualReturns > 0 ? _actualReturns : _expectedProfit))}',
                bold: true,
              ),
              _Row('Settlement Date',
                  inv['payment_date']?.toString() ?? '--'),
            ],
          ]),
          const SizedBox(height: 20),

          // ── Tenure Timeline (active only) ──────────────────────────
          if (!isRepaid) ...[
            _SheetSection('Tenure Timeline'),
            _DetailCard(rows: [
              _TimelineRow(
                progress: _progress,
                daysLeft: _daysLeft,
                tenure: _tenure,
                startDate: inv['invoice_date']?.toString() ?? '--',
                dueDate: inv['payment_date']?.toString() ?? '--',
              ),
              _Row('Total Tenure',
                  _tenure > 0 ? '$_tenure days' : '--'),
              _Row('Days Elapsed',
                  _tenure > 0
                      ? '${(_tenure - _daysLeft).clamp(0, _tenure)} days'
                      : '--'),
              _Row(
                'Days Remaining',
                _isOverdue
                    ? 'Overdue by ${_daysLeft.abs()} days'
                    : '$_daysLeft days',
                valueColor: _isOverdue
                    ? AppColors.rose(context)
                    : _daysLeft < 7
                    ? AppColors.amber(context)
                    : colorScheme.onSurface,
              ),
            ]),
            const SizedBox(height: 20),
          ],

          // ── Tax Note ──────────────────────────────────────────────
          // Item #33: regulatory banners (uncommented for compliance)
          _Banner(
            icon: Icons.receipt_long_outlined,
            title: 'Tax Information',
            body:
            'Returns from invoice discounting are taxable as Interest Income '
                'per your applicable IT slab (Indian Income Tax Act). TDS may '
                'apply. Download your investment statement from the Analytics '
                'screen for your records. Consult a CA for tax advice.',
            color: AppColors.amber(context),
          ),
          const SizedBox(height: 10),

          _Banner(
            icon: Icons.shield_outlined,
            title: 'Risk Disclosure',
            body:
            'Invoice discounting involves credit risk. Repayment depends on '
                'the debtor honouring the invoice. In case of debtor default, '
                'principal recovery may be delayed or partial. '
                'This platform is not a bank or NBFC; funds are not covered by '
                "RBI's Deposit Insurance & Credit Guarantee Scheme (DICGC). "
                'Past performance does not guarantee future returns. '
                'Invest only funds you can afford to lock in for the tenure.',
            color: AppColors.rose(context),
          ),
          const SizedBox(height: 10),

          _Banner(
            icon: Icons.support_agent_outlined,
            title: 'Grievance Redressal',
            body:
            'For disputes or concerns regarding this investment, contact '
                'support at lakhiwal43@gmail.com. We aim to resolve all '
                'grievances within 7 working days as per our investor charter.',
            color: AppColors.blue(context),
          ),
          const SizedBox(height: 28),

          // ── Copy summary button ────────────────────────────────────
          OutlinedButton.icon(
            onPressed: () => _copy(context, _buildSummaryText(),
                'Investment summary copied to clipboard'),
            icon: const Icon(Icons.copy_outlined, size: 16),
            label: const Text('Copy Investment Summary'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color:
                  colorScheme.outlineVariant.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(
                  vertical: 14, horizontal: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _copy(BuildContext context, String text, String msg) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), duration: const Duration(seconds: 2)));
  }

  String _buildSummaryText() => [
    'Finworks360 — Investment Summary',
    '─────────────────────────────',
    'Company    : ${inv['company'] ?? '--'}',
    'Debtor     : ${inv['debtor'] ?? '--'}',
    'Amount     : ₹${_fmtFull(_amount)}',
    'Rate       : ${_investorRate.toStringAsFixed(2)}% p.a.',
    'Tenure     : $_tenure days',
    'Status     : ${isRepaid ? 'Repaid' : _isOverdue ? 'Overdue' : 'Active'}',
    'Due Date   : ${inv['payment_date'] ?? '--'}',
    if (!isRepaid) 'Exp. Payout: ₹${_fmtFull(_expectedPayout)}',
    if (isRepaid)
      'Received   : ₹${_fmtFull(_actualReturns > 0 ? _actualReturns : _expectedProfit)}',
    '─────────────────────────────',
    'Ref ID     : ${inv['id'] ?? '--'}',
    'Invoice No : ${inv['invoice_number'] ?? '--'}',
  ].join('\n');
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail sheet sub-widgets (unchanged from original)
// ─────────────────────────────────────────────────────────────────────────────

class _SheetSection extends StatelessWidget {
  final String title;
  const _SheetSection(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(title.toUpperCase(),
        style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8)),
  );
}

class _Row {
  final String label, value;
  final Color? valueColor;
  final bool bold;
  final VoidCallback? onCopy;

  const _Row(this.label, this.value,
      {this.valueColor, this.bold = false, this.onCopy});
}

class _TimelineRow extends _Row {
  final double progress;
  final int daysLeft, tenure;
  final String startDate, dueDate;

  const _TimelineRow({
    required this.progress,
    required this.daysLeft,
    required this.tenure,
    required this.startDate,
    required this.dueDate,
  }) : super('', '');
}

class _DetailCard extends StatelessWidget {
  final List<_Row> rows;
  const _DetailCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final widgets = <Widget>[];

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is _TimelineRow) {
        widgets.add(_buildTimeline(context, row));
      } else {
        widgets.add(_buildRow(context, row));
      }
      if (i < rows.length - 1) {
        widgets.add(Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.15),
            indent: 16,
            endIndent: 16));
      }
    }

    return Container(
      decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.15))),
      child: Column(children: widgets),
    );
  }

  Widget _buildRow(BuildContext context, _Row row) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(row.label,
              style: TextStyle(
                  color: colorScheme.onSurfaceVariant, fontSize: 13)),
          Row(children: [
            Text(row.value,
                style: TextStyle(
                    color: row.valueColor ?? colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight:
                    row.bold ? FontWeight.w700 : FontWeight.w500)),
            if (row.onCopy != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: row.onCopy,
                child: Icon(Icons.copy_outlined,
                    size: 14,
                    color: colorScheme.primary.withValues(alpha: 0.6)),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, _TimelineRow r) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOverdue = r.daysLeft < 0;
    final progressColor = isOverdue
        ? AppColors.rose(context)
        : r.progress > 0.85
        ? AppColors.amber(context)
        : AppColors.emerald(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Progress',
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13)),
                Text(
                  r.tenure > 0
                      ? '${(r.progress * 100).toStringAsFixed(0)}% of ${r.tenure}d'
                      : '--',
                  style: TextStyle(
                      color:
                      isOverdue ? AppColors.rose(context) : colorScheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: r.progress,
              minHeight: 8,
              backgroundColor:
              colorScheme.outlineVariant.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation(progressColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(r.startDate,
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11)),
                Text(r.dueDate,
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11)),
              ]),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String title, body;
  final Color color;

  const _Banner(
      {required this.icon,
        required this.title,
        required this.body,
        required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2))),
    child:
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(body,
                style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 11,
                    height: 1.55)),
          ],
        ),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _Metric  (card preview)
// ─────────────────────────────────────────────────────────────────────────────

class _Metric extends StatelessWidget {
  final String label, value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11)),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 14)),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab delegate
// ─────────────────────────────────────────────────────────────────────────────

class _TabDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _TabDelegate({required this.child});

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  Widget build(
      BuildContext ctx, double shrinkOffset, bool overlapsContent) =>
      child;

  @override
  // FIX #31: was always returning true, causing the tab bar to rebuild on
  // every scroll frame. Now only rebuilds when the child widget changes.
  bool shouldRebuild(_TabDelegate old) => old.child != child;
}