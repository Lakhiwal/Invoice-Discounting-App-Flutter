import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../theme/theme_provider.dart';
import '../theme/ui_constants.dart';
import '../utils/app_haptics.dart';
import '../utils/formatters.dart';
import '../widgets/animated_empty_state.dart';
import '../widgets/pressable.dart';
import '../widgets/stagger_list.dart';

// ── Masked amount constant ────────────────────────────────────────────────────
const String _kMaskedShort = '● ● ●';

/// Result object returned when user taps "Retry Payment" on a failed transaction.
/// The home screen receives this via Navigator.pop() and auto-opens add funds.
class RetryPaymentRequest {
  final double amount;

  const RetryPaymentRequest({required this.amount});
}

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>
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

  Future<void> _loadTransactions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    // Defer heavy data assembly until route transition completes
    await Future.delayed(const Duration(milliseconds: 250));

    try {
      final data = await ApiService.getWallet();
      if (mounted) {
        setState(() {
          _all = (data?['transactions'] as List?) ?? [];
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
        final desc = (tx['description'] ?? '').toString().toLowerCase();
        if (query.isNotEmpty && !desc.contains(query)) return false;
        if (_typeFilter == 'Credit' && tx['type'] != 'credit') return false;
        if (_typeFilter == 'Debit' && tx['type'] != 'debit') return false;
        if (_typeFilter == 'Failed') {
          final s = tx['status']?.toString() ?? '';
          if (s != 'failed' && s != 'expired') return false;
        }
        if (_fromDate != null || _toDate != null) {
          final txDate = DateTime.tryParse(tx['date']?.toString() ?? '');
          if (txDate == null) return false;
          if (_fromDate != null &&
              txDate.isBefore(
                  DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day))) {
            return false;
          }
          if (_toDate != null &&
              txDate.isAfter(DateTime(
                  _toDate!.year, _toDate!.month, _toDate!.day, 23, 59))) {
            return false;
          }
        }
        return true;
      }).toList();
    });
  }

  // ── Summary calculations ──────────────────────────────────────────────────

  double get _totalCredits =>
      _filtered.where((tx) => tx['type'] == 'credit').fold(
          0.0,
          (sum, tx) =>
              sum + (double.tryParse(tx['amount']?.toString() ?? '0') ?? 0));

  double get _totalDebits => _filtered
      .where((tx) =>
          tx['type'] == 'debit' &&
          tx['status'] != 'failed' &&
          tx['status'] != 'expired')
      .fold(
          0.0,
          (sum, tx) =>
              sum + (double.tryParse(tx['amount']?.toString() ?? '0') ?? 0));

  int get _failedCount => _filtered.where((tx) {
        final s = tx['status']?.toString() ?? '';
        return s == 'failed' || s == 'expired';
      }).length;

  // ── Date helpers ──────────────────────────────────────────────────────────

  void _applyPreset(String preset) {
    final now = DateTime.now();
    DateTime from;
    switch (preset) {
      case 'today':
        from = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        from = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        from = DateTime(now.year, now.month, 1);
        break;
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

    // Pop back to home screen with the retry request.
    // Home screen catches this and auto-opens the add funds sheet.
    Navigator.of(context).pop(RetryPaymentRequest(amount: amount));
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

    showModalBottomSheet(
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
                    ? Icons.error_outline_rounded
                    : isDebit
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
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
              tx['description'] ?? 'Transaction',
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
                  tx['date'] ?? '',
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
                      borderRadius: BorderRadius.circular(6),
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
                value: tx['type'] == 'credit' ? 'Credit' : 'Debit'),
            _DetailRow(label: 'Status', value: _statusLabel(status)),
            if (tx['id'] != null)
              _DetailRow(label: 'Reference', value: tx['id'].toString()),

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
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text('Retry ₹${fmtAmount(amount)}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
    );
  }

  String _statusLabel(String status) =>
      switch (status) {
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
      body: RefreshIndicator(
        onRefresh: () async { await AppHaptics.selection(); await _loadTransactions(); },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            // ── App bar ─────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: colorScheme.onSurface, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text('Transactions',
                  style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3)),
              actions: [
                if (_hasAnyFilter)
                  IconButton(
                    icon: Badge(
                      smallSize: 6,
                      backgroundColor: colorScheme.error,
                      child: Icon(Icons.filter_alt_off_rounded,
                          color: colorScheme.onSurfaceVariant, size: 20),
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
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: _SummaryCard(
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
                    prefixIcon: Icon(Icons.search_rounded,
                        color: colorScheme.onSurfaceVariant, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded,
                                color: colorScheme.onSurfaceVariant, size: 18),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.3))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.2))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: colorScheme.primary, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
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
                  child: Row(children: [
                    _FilterChip(
                        label: 'Today',
                        active: _activePreset == 'today',
                        onTap: () => _applyPreset('today')),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: 'This Week',
                        active: _activePreset == 'week',
                        onTap: () => _applyPreset('week')),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: 'This Month',
                        active: _activePreset == 'month',
                        onTap: () => _applyPreset('month')),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: _hasCustomRange ? _customDateLabel() : 'Custom',
                      active: _hasCustomRange,
                      icon: Icons.calendar_today_outlined,
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
                  ]),
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

            // ── Content ─────────────────────────────────────────────────
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),

            if (_hasError && !_isLoading)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          size: 48,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text('Couldn\'t load transactions',
                          style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: _loadTransactions,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),

            if (!_isLoading && !_hasError && _filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 56,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text(
                        _all.isEmpty
                            ? 'No transactions yet'
                            : 'No transactions match your filters',
                        style: TextStyle(
                            color: colorScheme.onSurfaceVariant, fontSize: 14),
                      ),
                      if (_hasAnyFilter) ...[
                        const SizedBox(height: 16),
                        TextButton.icon(
                          icon: const Icon(Icons.filter_alt_off_rounded,
                              size: 16),
                          label: const Text('Clear filters'),
                          onPressed: _clearAllFilters,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            if (!_isLoading && !_hasError && _filtered.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final tx = _filtered[i];
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

class _SummaryCard extends StatelessWidget {
  final double credits, debits;
  final int failedCount;

  const _SummaryCard({
    required this.credits,
    required this.debits,
    required this.failedCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hideBalance = context.select<ThemeProvider, bool>((p) => p.hideBalance);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
              child: _SumColumn(
            label: 'Money In',
            value: hideBalance ? '₹$_kMaskedShort' : '₹${fmtAmount(credits)}',
            color: AppColors.success(context),
            icon: Icons.south_west_rounded,
          )),
          Container(
            width: 1,
            height: 40,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          Expanded(
              child: _SumColumn(
            label: 'Money Out',
            value: hideBalance ? '₹$_kMaskedShort' : '₹${fmtAmount(debits)}',
            color: colorScheme.error,
            icon: Icons.north_east_rounded,
          )),
          if (failedCount > 0) ...[
            Container(
              width: 1,
              height: 40,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            Expanded(
                child: _SumColumn(
              label: 'Failed',
              value: '$failedCount',
              color: colorScheme.error.withValues(alpha: 0.6),
              icon: Icons.error_outline_rounded,
            )),
          ],
        ],
      ),
    );
  }
}

class _SumColumn extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;

  const _SumColumn({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style:
                TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11)),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool isDestructive;
  final IconData? icon;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.isDestructive = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
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
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active
                  ? color
                  : colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon,
                size: 13, color: active ? color : colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: TextStyle(
                  color: active ? color : colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
        ]),
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  final VoidCallback? onTap;

  const _TxTile({
    required this.tx,
    this.onTap,
  });

  static const _iconMap = {
    'invest': Icons.trending_up_rounded,
    'investment': Icons.trending_up_rounded,
    'return': Icons.receipt_long_outlined,
    'repay': Icons.receipt_long_outlined,
    'settlement': Icons.receipt_long_outlined,
    'withdraw': Icons.south_rounded,
    'add': Icons.north_rounded,
    'deposit': Icons.north_rounded,
    'credit': Icons.north_rounded,
    'top-up': Icons.north_rounded,
  };

  IconData _resolveIcon(String desc, String status, bool isCredit) {
    if (status == 'failed') return Icons.error_outline_rounded;
    if (status == 'expired') return Icons.timer_off_rounded;
    final lower = desc.toLowerCase();
    for (final entry in _iconMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return isCredit ? Icons.south_west_rounded : Icons.north_east_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hideBalance = context.select<ThemeProvider, bool>((p) => p.hideBalance);
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
              colorScheme.surfaceContainerHigh, colorScheme.primary, 2),
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: colorScheme.outline.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: accentColor, size: 19)),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(desc,
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
                  )),
              const SizedBox(height: 3),
              Row(children: [
                Text(tx['date'] ?? '',
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant, fontSize: 12)),
                if (isFailed) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: txStatus == 'failed'
                          ? colorScheme.error.withValues(alpha: 0.1)
                          : AppColors.warning(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
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
              ]),
            ]),
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
              Icon(Icons.chevron_right_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
            ],
          ),
        ]),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}