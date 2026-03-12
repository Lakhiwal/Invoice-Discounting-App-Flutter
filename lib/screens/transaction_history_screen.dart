import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/theme_provider.dart';
import '../utils/formatters.dart';
import '../utils/app_haptics.dart'; // Item #8

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends State<TransactionHistoryScreen> {
  List<dynamic> _all = [];
  List<dynamic> _filtered = [];
  bool _isLoading = true;

  final _searchCtrl = TextEditingController();
  String _typeFilter = 'All'; // All | Credit | Debit
  DateTime? _fromDate;
  DateTime? _toDate;

  // FIX: _activePreset tracks which preset chip is highlighted.
  // Previously, setting a preset and then tapping "Custom" left _activePreset
  // set, making the "Custom" button appear inactive even though a date range
  // was active. Now _activePreset is always null when a custom range is used,
  // and preset chips are only highlighted when they set the current filter.
  String? _activePreset;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getWallet();
    if (mounted) {
      setState(() {
        _all = (data?['transactions'] as List?) ?? [];
        _isLoading = false;
        _applyFilters();
      });
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

        if (_fromDate != null || _toDate != null) {
          final txDate =
          DateTime.tryParse(tx['date']?.toString() ?? '');
          if (txDate == null) return false;
          if (_fromDate != null &&
              txDate.isBefore(DateTime(
                  _fromDate!.year, _fromDate!.month, _fromDate!.day))) {
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

  void _applyPreset(String preset) {
    final now = DateTime.now();
    DateTime from;
    final DateTime to = now;

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
      _toDate = to;
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
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: AppColors.primary(ctx),
            surface: AppColors.navyCard(ctx),
            onSurface: AppColors.textPrimary(ctx),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        // FIX: always clear _activePreset when user sets a custom range.
        // Previously a custom pick after a preset left the preset chip
        // appearing active, misleading users about which filter was applied.
        _activePreset = null;
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _applyFilters();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _activePreset = null;
      _fromDate = null;
      _toDate = null;
    });
    _applyFilters();
  }

  // FIX: computed label for the active date range shown on the Custom button.
  // Makes it immediately obvious what date range is filtering results.
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

  // Derived: is a custom (non-preset) date range active?
  bool get _hasCustomRange => _fromDate != null && _activePreset == null;

  // Derived: is any date filter active?
  bool get _hasAnyDateFilter => _fromDate != null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.scaffold(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary(context), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Transaction History',
            style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary(context)),
            onPressed: () async {
              await AppHaptics.selection(); // Item #8
              _loadTransactions();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(
                  color: AppColors.textPrimary(context), fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search transactions…',
                prefixIcon: Icon(Icons.search_rounded,
                    color: AppColors.textSecondary(context), size: 20),
                filled: true,
                fillColor: AppColors.navyCard(context),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                    BorderSide(color: AppColors.divider(context))),
              ),
            ),
          ),

          // ── Date preset chips ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _PresetChip(
                    label: 'Today',
                    active: _activePreset == 'today',
                    onTap: () => _applyPreset('today')),
                const SizedBox(width: 8),
                _PresetChip(
                    label: 'This Week',
                    active: _activePreset == 'week',
                    onTap: () => _applyPreset('week')),
                const SizedBox(width: 8),
                _PresetChip(
                    label: 'This Month',
                    active: _activePreset == 'month',
                    onTap: () => _applyPreset('month')),
                // FIX: "Clear" only appears when a date filter is active.
                // Previously it could appear/disappear mid-animation causing jank.
                // AnimatedSize wraps it to animate the chip in/out smoothly.
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: _hasAnyDateFilter
                      ? Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _PresetChip(
                        label: 'Clear',
                        active: false,
                        isDestructive: true,
                        onTap: _clearDateFilter),
                  )
                      : const SizedBox.shrink(),
                ),
              ]),
            ),
          ),

          // ── Type filter + custom date picker ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(children: [
              ...['All', 'Credit', 'Debit'].map((type) {
                final active = _typeFilter == type;
                return GestureDetector(
                  onTap: () {
                    setState(() => _typeFilter = type);
                    _applyFilters();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: active
                          ? colorScheme.primary.withValues(alpha: 0.15)
                          : AppColors.navyCard(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active
                              ? colorScheme.primary
                              : AppColors.divider(context)),
                    ),
                    child: Text(type,
                        style: TextStyle(
                            color: active
                                ? colorScheme.primary
                                : AppColors.textSecondary(context),
                            fontSize: 12,
                            fontWeight: active
                                ? FontWeight.w600
                                : FontWeight.w400)),
                  ),
                );
              }),
              const Spacer(),
              // FIX: Custom date button now shows the active range as its label
              // so users always know which range is filtering their results.
              // It is highlighted in amber when a custom range is active,
              // and in a neutral state when a preset is active or no date filter.
              GestureDetector(
                onTap: _pickDateRange,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                      color: _hasCustomRange
                          ? AppColors.amber(context).withValues(alpha: 0.1)
                          : AppColors.navyCard(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _hasCustomRange
                              ? AppColors.amber(context)
                              : AppColors.divider(context))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.calendar_today_outlined,
                        color: _hasCustomRange
                            ? AppColors.amber(context)
                            : AppColors.textSecondary(context),
                        size: 14),
                    const SizedBox(width: 6),
                    // FIX: show active date range label instead of always "Custom"
                    Text(
                      _hasCustomRange ? _customDateLabel() : 'Custom',
                      style: TextStyle(
                          color: _hasCustomRange
                              ? AppColors.amber(context)
                              : AppColors.textSecondary(context),
                          fontSize: 12,
                          fontWeight: _hasCustomRange
                              ? FontWeight.w600
                              : FontWeight.w400),
                    ),
                  ]),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 10),

          // ── Results ───────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
            // FIX: added proper empty state instead of blank screen
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    _all.isEmpty
                        ? 'No transactions yet'
                        : 'No transactions match your filters',
                    style: TextStyle(
                        color: AppColors.textSecondary(context)),
                  ),
                  if (_hasAnyDateFilter ||
                      _typeFilter != 'All' ||
                      _searchCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    TextButton.icon(
                      icon: const Icon(Icons.filter_alt_off_rounded,
                          size: 16),
                      label: const Text('Clear filters'),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _typeFilter = 'All');
                        _clearDateFilter();
                      },
                    ),
                  ],
                ],
              ),
            )
                : ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (ctx, i) =>
                    _TransactionTile(tx: _filtered[i])),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool active, isDestructive;
  final VoidCallback onTap;

  const _PresetChip(
      {required this.label,
        required this.active,
        required this.onTap,
        this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    final color =
    isDestructive ? AppColors.rose(context) : AppColors.primary(context);
    return GestureDetector(
        onTap: () async {
          await AppHaptics.selection(); // Item #8
          onTap();
        },
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: active
                    ? color.withValues(alpha: 0.15)
                    : AppColors.navyCard(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: active ? color : AppColors.divider(context))),
            child: Text(label,
                style: TextStyle(
                    color: active
                        ? color
                        : AppColors.textSecondary(context),
                    fontSize: 12,
                    fontWeight:
                    active ? FontWeight.w600 : FontWeight.w400))));
  }
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> tx;

  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isDebit = tx['type'] == 'debit';
    final accentColor =
    isDebit ? AppColors.rose(context) : AppColors.emerald(context);
    return ListTile(
        leading: Icon(
            isDebit
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: accentColor),
        title: Text(tx['description'] ?? '',
            style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        subtitle: Text(tx['date'] ?? '',
            style: TextStyle(
                color: AppColors.textSecondary(context), fontSize: 12)),
        trailing: Text('${isDebit ? '-' : '+'}₹${fmtAmount(tx['amount'])}',
            style: TextStyle(
                color: accentColor, fontWeight: FontWeight.w600)));
  }
}