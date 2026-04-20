import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/services/pdf_service.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/formatters.dart';
import 'package:invoice_discounting_app/widgets/animated_amount_text.dart';
import 'package:invoice_discounting_app/widgets/app_logo_header.dart';
import 'package:invoice_discounting_app/widgets/glass_card.dart';
import 'package:invoice_discounting_app/widgets/liquidity_refresh_indicator.dart';
import 'package:invoice_discounting_app/widgets/pressable.dart';
import 'package:invoice_discounting_app/widgets/skeleton.dart';
import 'package:invoice_discounting_app/widgets/stagger_list.dart';

// ── Masked amount constant ────────────────────────────────────────────────────
const String _kMaskedShort = '● ● ●';

/// Result object returned when user taps "Retry Payment" on a failed transaction.
/// The home screen receives this via Navigator.pop() and auto-opens add funds.
class RetryPaymentRequest {
  const RetryPaymentRequest({required this.amount});
  final double amount;
}

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _all = [];
  List<dynamic> _filtered = [];
  bool _isLoading = true;
  bool _hasError = false;

  final _searchCtrl = TextEditingController();
  String _typeFilter = 'All';
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _activePreset;

  late AnimationController _summaryCtrl;
  late Animation<double> _summaryFade;

  @override
  void initState() {
    super.initState();
    _summaryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _summaryFade = CurvedAnimation(parent: _summaryCtrl, curve: Curves.easeOut);
    _loadTransactions();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _summaryCtrl.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadTransactions({
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    if (!mounted) return;
    final startTime = DateTime.now();

    if (!silent) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    // Defer heavy data assembly until route transition completes
    if (!forceRefresh) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    try {
      final data =
          await ApiService.getWalletHistory(forceRefresh: forceRefresh);

      // Ensure the "Syncing" state is visible for a premium feel
      if (forceRefresh) {
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        if (elapsed < 800) {
          await Future<void>.delayed(Duration(milliseconds: 800 - elapsed));
        }
      }

      if (mounted) {
        setState(() {
          _all = (data['transactions'] as List?)
                  ?.map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [];
          _isLoading = false;
          _applyFilters();
        });
        _summaryCtrl.forward();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _applyFilters() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = _all.where((tx) {
        final t = tx as Map<String, dynamic>;
        final desc = (t['description'] ?? '').toString().toLowerCase();
        if (query.isNotEmpty && !desc.contains(query)) return false;
        if (_typeFilter == 'Credit' && t['type'] != 'credit') return false;
        if (_typeFilter == 'Debit' && t['type'] != 'debit') return false;
        if (_typeFilter == 'Failed') {
          final s = t['status']?.toString() ?? '';
          if (s != 'failed' && s != 'expired') return false;
        }
        if (_fromDate != null || _toDate != null) {
          final txDate = DateTime.tryParse(t['date']?.toString() ?? '');
          if (txDate == null) return false;
          if (_fromDate != null &&
              txDate.isBefore(
                DateTime(
                  _fromDate!.year,
                  _fromDate!.month,
                  _fromDate!.day,
                ),
              )) {
            return false;
          }
          if (_toDate != null &&
              txDate.isAfter(
                DateTime(
                  _toDate!.year,
                  _toDate!.month,
                  _toDate!.day,
                  23,
                  59,
                ),
              )) {
            return false;
          }
        }
        return true;
      }).toList();
    });
  }

  // ── Summary calculations ──────────────────────────────────────────────────

  double get _totalCredits => _filtered
      .where((tx) => (tx as Map<String, dynamic>)['type'] == 'credit')
      .fold<double>(
        0,
        (sum, tx) =>
            sum +
            (double.tryParse(
                    (tx as Map<String, dynamic>)['amount']?.toString() ??
                        '0',) ??
                0),
      );

  double get _totalDebits => _filtered.where(
        (tx) {
          final t = tx as Map<String, dynamic>;
          return t['type'] == 'debit' &&
              t['status'] != 'failed' &&
              t['status'] != 'expired';
        },
      ).fold<double>(
        0,
        (sum, tx) =>
            sum +
            (double.tryParse(
                    (tx as Map<String, dynamic>)['amount']?.toString() ??
                        '0',) ??
                0),
      );

  int get _failedCount => _filtered.where((tx) {
        final s = (tx as Map<String, dynamic>)['status']?.toString() ?? '';
        return s == 'failed' || s == 'expired';
      }).length;

  // ── Date helpers ──────────────────────────────────────────────────────────

  void _applyPreset(String preset) {
    final now = DateTime.now();
    DateTime from;
    switch (preset) {
      case 'today':
        from = DateTime(now.year, now.month, now.day);
      case 'week':
        from = now.subtract(const Duration(days: 7));
      case 'month':
        from = DateTime(now.year, now.month);
      default:
        return;
    }
    setState(() {
      _activePreset = preset;
      _fromDate = from;
      _toDate = now;
    });
    _applyFilters();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _activePreset = null;
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _applyFilters();
    }
  }

  void _clearAllFilters() {
    _searchCtrl.clear();
    setState(() {
      _typeFilter = 'All';
      _activePreset = null;
      _fromDate = null;
      _toDate = null;
    });
    _applyFilters();
  }

  bool get _hasCustomRange => _fromDate != null && _activePreset == null;

  bool get _hasAnyDateFilter => _fromDate != null;

  bool get _hasAnyFilter =>
      _hasAnyDateFilter || _typeFilter != 'All' || _searchCtrl.text.isNotEmpty;

  String _customDateLabel() {
    if (_fromDate == null) return 'Custom';
    if (_toDate == null) return _fmtDate(_fromDate!);
    if (_fromDate!.year == _toDate!.year &&
        _fromDate!.month == _toDate!.month &&
        _fromDate!.day == _toDate!.day) {
      return _fmtDate(_fromDate!);
    }
    return '${_fmtDate(_fromDate!)} – ${_fmtDate(_toDate!)}';
  }

  String _fmtDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year.toString().substring(2)}';

  // ── Retry payment ─────────────────────────────────────────────────────────

  void _retryPayment(Map<String, dynamic> tx) {
    final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
    if (amount <= 0) return;

    AppHaptics.selection();

    Navigator.of(context).pop(RetryPaymentRequest(amount: amount));
  }

  // ── Export ────────────────────────────────────────────────────────────────

  Future<void> _handleExport() async {
    unawaited(AppHaptics.selection());
    if (_isLoading || _all.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No transactions to export')),
        );
      }
      return;
    }

    final dateLabel = _hasAnyDateFilter ? _customDateLabel() : 'All Time';

    await PdfService.generateAndShareTaxStatement(
      name: 'Investor',
      transactions: _all.cast<Map<String, dynamic>>(),
      dateRange: dateLabel,
    );
  }

  // ── Transaction detail sheet ──────────────────────────────────────────────

  void _showTransactionDetail(Map<String, dynamic> tx) {
    AppHaptics.selection();
    final colorScheme = Theme.of(context).colorScheme;
    final isDebit = tx['type'] == 'debit';
    final status = tx['status']?.toString() ?? 'completed';
    final isFailed = status == 'failed' || status == 'expired';
    final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
    final accentColor = isFailed
        ? colorScheme.error
        : isDebit
            ? colorScheme.error
            : AppColors.success(context);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFailed
                    ? AppIcons.error
                    : isDebit
                        ? AppIcons.arrowUp
                        : AppIcons.arrowDown,
                color: accentColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),

            // Amount
            Text(
              '${isDebit ? '-' : '+'}₹${fmtAmount(amount)}',
              style: TextStyle(
                color: accentColor,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                decoration: isFailed ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              (tx['description'] as String?) ?? 'Transaction',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),

            // Date + status
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  (tx['date'] as String?) ?? '',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                if (isFailed) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(UI.radiusSm),
                    ),
                    child: Text(
                      status == 'failed' ? 'Failed' : 'Expired',
                      style: TextStyle(
                        color: colorScheme.error,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Details
            _DetailRow(
              label: 'Type',
              value: tx['type'] == 'credit' ? 'Credit' : 'Debit',
            ),
            _DetailRow(label: 'Status', value: _statusLabel(status)),
            if (tx['id'] != null)
              _DetailRow(label: 'Reference', value: tx['id'].toString()),

            // ── Withdrawal Stepper ──────────────────────────────────────
            if (tx['description'] != null &&
                tx['description']
                    .toString()
                    .toLowerCase()
                    .contains('withdraw')) ...[
              const SizedBox(height: 24),
              _WithdrawalStepper(status: status),
            ],

            // ── Retry button for failed payments ────────────────────────
            if (isFailed) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Close the bottom sheet first, then retry
                    Navigator.of(sheetContext).pop();
                    _retryPayment(tx);
                  },
                  icon: Icon(AppIcons.refresh, size: 18),
                  label: Text('Retry ₹${fmtAmount(amount)}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(UI.radiusMd),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'completed' => 'Completed',
        'failed' => 'Failed',
        'expired' => 'Expired',
        'pending' => 'Pending',
        _ => status,
      };

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: LiquidityRefreshIndicator(
        onRefresh: () => _loadTransactions(forceRefresh: true, silent: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── App bar ─────────────────────────────────────────────────
            AppLogoHeader(
              title: 'Transactions',
              actions: [
                IconButton(
                  icon: Icon(
                    AppIcons.export,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: _handleExport,
                  tooltip: 'Export Tax Statement',
                ),
                if (_hasAnyFilter)
                  IconButton(
                    icon: Badge(
                      smallSize: 6,
                      backgroundColor: colorScheme.error,
                      child: Icon(
                        AppIcons.filterOff,
                        color: colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                    onPressed: () {
                      AppHaptics.selection();
                      _clearAllFilters();
                    },
                    tooltip: 'Clear all filters',
                  ),
                const SizedBox(width: 8),
              ],
            ),

            // ── Summary card ────────────────────────────────────────────
            if (!_isLoading && !_hasError && _all.isNotEmpty)
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _summaryFade,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _PremiumSummary(
                      credits: _totalCredits,
                      debits: _totalDebits,
                      failedCount: _failedCount,
                    ),
                  ),
                ),
              ),

            // ── Search ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search transactions…',
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    prefixIcon: Icon(
                      AppIcons.search,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              AppIcons.close,
                              color: colorScheme.onSurfaceVariant,
                              size: 18,
                            ),
                            onPressed: _searchCtrl.clear,
                          )
                        : null,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(UI.radiusMd),
                      borderSide: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(UI.radiusMd),
                      borderSide: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(UI.radiusMd),
                      borderSide:
                          BorderSide(color: colorScheme.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),

            // ── Date presets ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Today',
                        active: _activePreset == 'today',
                        onTap: () => _applyPreset('today'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'This Week',
                        active: _activePreset == 'week',
                        onTap: () => _applyPreset('week'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'This Month',
                        active: _activePreset == 'month',
                        onTap: () => _applyPreset('month'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: _hasCustomRange ? _customDateLabel() : 'Custom',
                        active: _hasCustomRange,
                        icon: AppIcons.calendar,
                        onTap: _pickDateRange,
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        child: _hasAnyDateFilter
                            ? Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _FilterChip(
                                  label: 'Clear dates',
                                  active: false,
                                  isDestructive: true,
                                  onTap: () {
                                    setState(() {
                                      _activePreset = null;
                                      _fromDate = null;
                                      _toDate = null;
                                    });
                                    _applyFilters();
                                  },
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Type filter chips ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Credit', 'Debit', 'Failed'].map((type) {
                      final active = _typeFilter == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: type == 'Failed' && _failedCount > 0
                              ? 'Failed ($_failedCount)'
                              : type,
                          active: active,
                          isDestructive: type == 'Failed',
                          onTap: () {
                            setState(() => _typeFilter = type);
                            _applyFilters();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // ── Content area with smooth loading ───────────────────
            if (_isLoading)
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                sliver: SkeletonTheme(
                  child: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => const SkeletonListTile(
                        margin: EdgeInsets.only(bottom: 10),
                      ),
                      childCount: 8,
                    ),
                  ),
                ),
              )
            else if (_hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        AppIcons.wifiOff,
                        size: 48,
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Couldn't load transactions",
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _loadTransactions,
                        icon: Icon(AppIcons.refresh, size: 16),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        AppIcons.receipt,
                        size: 48,
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _all.isEmpty
                            ? 'No transactions yet'
                            : 'No transactions match filters',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_hasAnyFilter) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _clearAllFilters,
                          child: const Text('Clear all filters'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final tx = _filtered[i] as Map<String, dynamic>;
                      return StaggerItem(
                        index: i,
                        child: RepaintBoundary(
                          child: _TxTile(
                            tx: tx,
                            onTap: () => _showTransactionDetail(tx),
                          ),
                        ),
                      );
                    },
                    childCount: _filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _PremiumSummary extends ConsumerWidget {
  const _PremiumSummary({
    required this.credits,
    required this.debits,
    required this.failedCount,
  });
  final double credits;
  final double debits;
  final int failedCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      blur: 20,
      opacity: isDark ? 0.08 : 0.85,
      padding: const EdgeInsets.all(20),
      borderRadius: UI.radiusLg,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SumItem(
                  label: 'Total Inflow',
                  value: credits,
                  color: AppColors.success(context),
                  icon: AppIcons.addCircle,
                ),
              ),
              Container(
                width: 1,
                height: 48,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _SumItem(
                  label: 'Total Outflow',
                  value: debits,
                  color: colorScheme.error,
                  icon: AppIcons.remove,
                ),
              ),
            ],
          ),
          if (failedCount > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(UI.radiusMd),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    AppIcons.warning,
                    color: colorScheme.error,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$failedCount failed transaction${failedCount > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: colorScheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SumItem extends ConsumerWidget {
  const _SumItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final hideBalance = ref.watch(themeProvider.select((p) => p.hideBalance));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (hideBalance)
          Text(
            '₹$_kMaskedShort',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          )
        else
          AnimatedAmountText(
            value: value,
            prefix: '₹',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
      ],
    );
  }
}

class _FilterChip extends ConsumerWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.isDestructive = false,
    this.icon,
  });
  final String label;
  final bool active;
  final bool isDestructive;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isDestructive ? colorScheme.error : colorScheme.primary;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.12)
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(UI.radiusLg),
          border: Border.all(
            color: active
                ? color
                : colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: active ? color : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: active ? color : colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TxTile extends ConsumerWidget {
  const _TxTile({
    required this.tx,
    this.onTap,
  });
  final Map<String, dynamic> tx;
  final VoidCallback? onTap;

  static final Map<String, IconData> _iconMap = {
    'invest': AppIcons.analytics,
    'investment': AppIcons.analytics,
    'return': AppIcons.receipt,
    'repay': AppIcons.receipt,
    'settlement': AppIcons.receipt,
    'withdraw': AppIcons.export,
    'add': AppIcons.addCircle,
    'deposit': AppIcons.addCircle,
    'credit': AppIcons.addCircle,
    'top-up': AppIcons.addCircle,
  };

  IconData _resolveIcon(String desc, String status, bool isCredit) {
    if (status == 'failed') return AppIcons.error;
    if (status == 'expired') return AppIcons.timer;
    final lower = desc.toLowerCase();
    for (final entry in _iconMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return isCredit ? AppIcons.arrowDown : AppIcons.arrowUp;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final hideBalance = ref.watch(themeProvider.select((p) => p.hideBalance));
    final isDebit = tx['type'] == 'debit';
    final desc = tx['description']?.toString() ?? 'Transaction';
    final txStatus = tx['status']?.toString() ?? 'completed';
    final isFailed = txStatus == 'failed' || txStatus == 'expired';
    final icon = _resolveIcon(desc, txStatus, !isDebit);
    final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;

    final Color accentColor;
    if (isFailed) {
      accentColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
    } else {
      accentColor = isDebit ? colorScheme.error : AppColors.success(context);
    }

    return Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ElevationOverlay.applySurfaceTint(
            colorScheme.surfaceContainerHigh,
            colorScheme.primary,
            2,
          ),
          borderRadius: BorderRadius.circular(UI.radiusLg),
          border:
              Border.all(color: colorScheme.outline.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(UI.radiusMd),
              ),
              child: Icon(icon, color: accentColor, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isFailed
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      decoration: isFailed ? TextDecoration.lineThrough : null,
                      decorationColor:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        (tx['date'] as String?) ?? '',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
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
                                : AppColors.warning(context)
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(UI.radiusSm),
                          ),
                          child: Text(
                            txStatus == 'failed' ? 'Failed' : 'Expired',
                            style: TextStyle(
                              color: txStatus == 'failed'
                                  ? colorScheme.error
                                  : AppColors.warning(context),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
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
                    decoration: isFailed ? TextDecoration.lineThrough : null,
                    decorationColor:
                        colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Withdrawal Stepper ──────────────────────────────────────────────────────

class _WithdrawalStepper extends StatelessWidget {
  const _WithdrawalStepper({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = status.toLowerCase();

    // Determine current index based on status
    final currentStep = switch (s) {
      'pending' => 0,
      'verified' => 1,
      'processing' => 2,
      'completed' => 3,
      'failed' => 0,
      _ => 3,
    };

    final steps = [
      (
        'Requested',
        'User initiated withdrawal',
        'System detected request',
        Icon(AppIcons.document, size: 10)
      ),
      (
        'Risk Verified',
        'FinOps automated check',
        'System audit successful',
        Icon(AppIcons.shield, size: 10)
      ),
      (
        'Banking Node',
        'HDFC/ICICI Settlement',
        'Batched for transfer',
        Icon(AppIcons.bank, size: 10)
      ),
      (
        'Completed',
        'Funds credited',
        'Reference ID: WIN-${(DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}',
        Icon(AppIcons.check, size: 10)
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'WITHDRAWAL TRACKING',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(UI.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(AppIcons.shieldBold, color: cs.primary, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'SECURE TRANSFER',
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...List.generate(steps.length, (i) {
          final isCompleted = i < currentStep || s == 'completed';
          final isCurrent = i == currentStep && s != 'completed';
          final isLast = i == steps.length - 1;

          final color = isCompleted
              ? AppColors.success(context)
              : isCurrent
                  ? cs.primary
                  : cs.outlineVariant;

          final item = steps[i];

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted || isCurrent
                            ? color.withValues(alpha: 0.1)
                            : Colors.transparent,
                        border: Border.all(
                          color: color,
                          width: isCurrent ? 2 : 1.5,
                        ),
                      ),
                      child: isCompleted
                          ? Icon(AppIcons.check, size: 12, color: color)
                          : isCurrent
                              ? Center(
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 1.5,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                color,
                                if (i + 1 < currentStep || s == 'completed') AppColors.success(context) else cs.outlineVariant.withValues(alpha: 0.3),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.$1,
                            style: TextStyle(
                              color: isCompleted || isCurrent
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                              fontSize: 14,
                              fontWeight:
                                  isCurrent ? FontWeight.w800 : FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          if (isCompleted || isCurrent)
                            Text(
                              isCompleted ? 'Done' : 'Processing',
                              style: TextStyle(
                                color: color.withValues(alpha: 0.8),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$2,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      if (isCompleted || isCurrent) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(UI.radiusSm),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Opacity(
                                opacity: 0.7,
                                child: item.$4,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.$3,
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _DetailRow extends ConsumerWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
