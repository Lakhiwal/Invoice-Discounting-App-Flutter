import 'package:flutter/material.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/formatters.dart';
import 'package:invoice_discounting_app/widgets/app_logo_header.dart';
import 'package:invoice_discounting_app/widgets/liquidity_refresh_indicator.dart';

enum _ReceivableStatus { paid, pending, overdue }

class _ReceivableEntry {
  const _ReceivableEntry({
    required this.invoiceNo,
    required this.counterparty,
    required this.amount,
    required this.dueDate,
    required this.status,
  });

  final String invoiceNo;
  final String counterparty;
  final double amount;
  final DateTime dueDate;
  final _ReceivableStatus status;
}

class ReceivableStatementScreen extends StatefulWidget {
  const ReceivableStatementScreen({super.key});

  @override
  State<ReceivableStatementScreen> createState() =>
      _ReceivableStatementScreenState();
}

class _ReceivableStatementScreenState extends State<ReceivableStatementScreen> {
  int _selectedRangeIndex = 1;
  _ReceivableStatus? _statusFilter;

  static const _ranges = <String>['7D', '30D', '90D', 'YTD', 'All'];

  final List<_ReceivableEntry> _entries = [
    _ReceivableEntry(
      invoiceNo: 'INV-20412',
      counterparty: 'Aarav Textiles Pvt Ltd',
      amount: 285000,
      dueDate: DateTime.now().add(const Duration(days: 6)),
      status: _ReceivableStatus.pending,
    ),
    _ReceivableEntry(
      invoiceNo: 'INV-20398',
      counterparty: 'Sundaram Steel Works',
      amount: 642500,
      dueDate: DateTime.now().subtract(const Duration(days: 4)),
      status: _ReceivableStatus.overdue,
    ),
    _ReceivableEntry(
      invoiceNo: 'INV-20377',
      counterparty: 'Bluewave Logistics',
      amount: 158200,
      dueDate: DateTime.now().subtract(const Duration(days: 11)),
      status: _ReceivableStatus.paid,
    ),
    _ReceivableEntry(
      invoiceNo: 'INV-20365',
      counterparty: 'Nexgen Pharma Ltd',
      amount: 492000,
      dueDate: DateTime.now().add(const Duration(days: 18)),
      status: _ReceivableStatus.pending,
    ),
    _ReceivableEntry(
      invoiceNo: 'INV-20341',
      counterparty: 'Orbit Packaging',
      amount: 84700,
      dueDate: DateTime.now().subtract(const Duration(days: 22)),
      status: _ReceivableStatus.paid,
    ),
    _ReceivableEntry(
      invoiceNo: 'INV-20322',
      counterparty: 'Himalaya Foods',
      amount: 312400,
      dueDate: DateTime.now().subtract(const Duration(days: 9)),
      status: _ReceivableStatus.overdue,
    ),
  ];

  double get _totalReceivable =>
      _entries.fold(0, (sum, e) => sum + e.amount);
  double get _collected => _entries
      .where((e) => e.status == _ReceivableStatus.paid)
      .fold(0, (sum, e) => sum + e.amount);
  double get _pending => _entries
      .where((e) => e.status == _ReceivableStatus.pending)
      .fold(0, (sum, e) => sum + e.amount);
  double get _overdue => _entries
      .where((e) => e.status == _ReceivableStatus.overdue)
      .fold(0, (sum, e) => sum + e.amount);

  List<_ReceivableEntry> get _filtered => _statusFilter == null
      ? _entries
      : _entries.where((e) => e.status == _statusFilter).toList();

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: LiquidityRefreshIndicator(
        onRefresh: _refresh,
        color: cs.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            AppLogoHeader(
              title: 'Receivable Statement',
              actions: [
                IconButton(
                  tooltip: 'Export',
                  icon: Icon(AppIcons.export, color: cs.onSurface),
                  onPressed: () {
                    AppHaptics.selection();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Statement export coming soon'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
              ],
            ),

            // Summary card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(UI.lg, UI.sm, UI.lg, UI.md),
                child: _buildSummaryCard(cs, tt),
              ),
            ),

            // Stat tiles
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: UI.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatTile(
                        cs,
                        tt,
                        label: 'Collected',
                        amount: _collected,
                        color: const Color(0xFF16A34A),
                        icon: AppIcons.check,
                      ),
                    ),
                    const SizedBox(width: UI.sm),
                    Expanded(
                      child: _buildStatTile(
                        cs,
                        tt,
                        label: 'Pending',
                        amount: _pending,
                        color: cs.primary,
                        icon: AppIcons.timer,
                      ),
                    ),
                    const SizedBox(width: UI.sm),
                    Expanded(
                      child: _buildStatTile(
                        cs,
                        tt,
                        label: 'Overdue',
                        amount: _overdue,
                        color: const Color(0xFFDC2626),
                        icon: AppIcons.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: UI.lg)),

            // Range + status filter
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: UI.lg),
                child: _buildRangeSelector(cs, tt),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: UI.md)),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: UI.lg),
                child: _buildStatusFilter(cs, tt),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: UI.md)),

            // Section heading
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  UI.lg,
                  UI.sm,
                  UI.lg,
                  UI.sm,
                ),
                child: Row(
                  children: [
                    Text(
                      'Transactions',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_filtered.length} entries',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(cs, tt),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(UI.lg, 0, UI.lg, 40),
                sliver: SliverList.separated(
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: UI.sm),
                  itemBuilder: (context, i) =>
                      _buildEntryTile(_filtered[i], cs, tt),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Summary Card ─────────────────────────

  Widget _buildSummaryCard(ColorScheme cs, TextTheme tt) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cs.primary, cs.primary.withValues(alpha: 0.82)],
          ),
          borderRadius: BorderRadius.circular(UI.radiusXl),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AppIcons.moneyReceive,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Total Receivable',
                    style: tt.titleSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                Formatters.currency(_totalReceivable),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.3,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_entries.length} invoices',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    AppIcons.calendar,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _ranges[_selectedRangeIndex],
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  // ───────────────────────── Stat tiles ─────────────────────────

  Widget _buildStatTile(
    ColorScheme cs,
    TextTheme tt, {
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) =>
      Container(
        padding: const EdgeInsets.all(UI.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(UI.radiusLg),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 12, color: color),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              Formatters.currency(amount),
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );

  // ───────────────────────── Range selector ─────────────────────────

  Widget _buildRangeSelector(ColorScheme cs, TextTheme tt) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(UI.radiusLg),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: List.generate(_ranges.length, (i) {
            final active = i == _selectedRangeIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  AppHaptics.selection();
                  setState(() => _selectedRangeIndex = i);
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: UI.fast,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? cs.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(UI.radiusMd),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _ranges[i],
                    style: tt.labelMedium?.copyWith(
                      color: active ? cs.onPrimary : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      );

  // ───────────────────────── Status filter chips ─────────────────────────

  Widget _buildStatusFilter(ColorScheme cs, TextTheme tt) {
    Widget chip(String label, _ReceivableStatus? value) {
      final active = _statusFilter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () {
            AppHaptics.selection();
            setState(() => _statusFilter = value);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? cs.primary.withValues(alpha: 0.12)
                  : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active
                    ? cs.primary.withValues(alpha: 0.4)
                    : cs.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: active ? cs.primary : cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          chip('All', null),
          chip('Paid', _ReceivableStatus.paid),
          chip('Pending', _ReceivableStatus.pending),
          chip('Overdue', _ReceivableStatus.overdue),
        ],
      ),
    );
  }

  // ───────────────────────── Entry tile ─────────────────────────

  Widget _buildEntryTile(
    _ReceivableEntry e,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final (statusColor, statusLabel) = switch (e.status) {
      _ReceivableStatus.paid => (const Color(0xFF16A34A), 'Paid'),
      _ReceivableStatus.pending => (cs.primary, 'Pending'),
      _ReceivableStatus.overdue => (const Color(0xFFDC2626), 'Overdue'),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(UI.radiusLg),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(AppIcons.receipt, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.counterparty,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      e.invoiceNo,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '  •  Due ${_fmtDate(e.dueDate)}',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.currency(e.amount),
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusLabel,
                  style: tt.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs, TextTheme tt) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.empty, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'No receivables in this filter',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );

  static const _months = [
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

  String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';
}
