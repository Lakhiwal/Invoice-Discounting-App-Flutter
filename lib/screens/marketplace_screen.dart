import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';

import '../services/api_service.dart';
import '../theme/theme_provider.dart';
import '../utils/app_haptics.dart';
import '../utils/formatters.dart'; // FIX: use shared fmtAmount, removed duplicate _fmt
import '../widgets/pressable.dart';
import '../widgets/skeleton.dart';
import '../widgets/stagger_list.dart';
import 'invoice_detail_screen.dart';

// ── Models ───────────────────────────────────────────────────────────────────

class InvoiceItem {
  final String id;
  final String company;
  final String particular;
  final String debtor;
  final String status;
  final String statusDisplay;
  final double roi;
  final int daysLeft;
  final int tenureDays;
  final double remainingAmount;
  final double fundingPct;

  final String roiDisplay;
  final String daysLeftDisplay;
  final String tenureDisplay;
  final String remainingDisplay;
  final String fundingDisplay;

  const InvoiceItem({
    required this.id,
    required this.company,
    required this.particular,
    required this.debtor,
    required this.status,
    required this.statusDisplay,
    required this.roi,
    required this.daysLeft,
    required this.tenureDays,
    required this.remainingAmount,
    required this.fundingPct,
    required this.roiDisplay,
    required this.daysLeftDisplay,
    required this.tenureDisplay,
    required this.remainingDisplay,
    required this.fundingDisplay,
  });

  bool get isAvailable => status == 'available';

  @override
  bool operator ==(Object other) => other is InvoiceItem && other.id == id;

  @override
  int get hashCode => id.hashCode;

  factory InvoiceItem.fromMap(Map<String, dynamic> m) {
    final rawRoi = double.tryParse(
        (m['investor_rate'] ?? m['roi_value'] ?? m['roi'] ?? '0')
            .toString()) ??
        0;

    final rawDaysLeft = (m['days_until_payment'] as num?)?.toInt() ?? 0;

    int rawTenure = 0;
    try {
      final invoiceDateStr = m['invoice_date']?.toString() ?? '';
      final paymentDateStr = m['payment_date']?.toString() ?? '';
      if (invoiceDateStr.isNotEmpty && paymentDateStr.isNotEmpty) {
        final invoiceDate = DateTime.parse(invoiceDateStr);
        final paymentDate = DateTime.parse(paymentDateStr);
        rawTenure = paymentDate.difference(invoiceDate).inDays;
        if (rawTenure < 0) rawTenure = 0;
      }
    } catch (_) {
      rawTenure = rawDaysLeft;
    }

    final rawRemain =
        double.tryParse((m['remaining_amount'] ?? '0').toString()) ?? 0;
    final rawFunding =
    (double.tryParse((m['funding_percentage'] ?? '0').toString()) ?? 0)
        .clamp(0.0, 100.0);

    return InvoiceItem(
      id: (m['id'] ?? '').toString(),
      company: (m['company'] ?? '').toString(),
      particular: (m['particular'] ?? '').toString(),
      debtor: (m['debtor'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      statusDisplay: (m['status_display'] ?? '').toString(),
      roi: rawRoi,
      daysLeft: rawDaysLeft,
      tenureDays: rawTenure,
      remainingAmount: rawRemain,
      fundingPct: rawFunding,
      roiDisplay: '${rawRoi.toStringAsFixed(2)}%',
      daysLeftDisplay: '${rawDaysLeft}D left',
      tenureDisplay: '${rawTenure}D',
      // FIX: use shared fmtAmount — was using private _fmt which is identical
      remainingDisplay: '₹${fmtAmount(rawRemain)}',
      fundingDisplay: '${rawFunding.toStringAsFixed(1)}%',
    );
  }
}

// ── Isolate Logic ─────────────────────────────────────────────────────────────

const int _isolateThreshold = 150;

List<Map<String, dynamic>> _filterInvoicesIsolate(
    Map<String, dynamic> params) {
  final raw = List<Map<String, dynamic>>.from(params['invoices'] as List);
  final selectedStatus = params['status'] as String;
  final minRoi = params['minRoi'] as double;
  final maxRoi = params['maxRoi'] as double;
  final minDays = params['minDays'] as double;
  final maxDays = params['maxDays'] as double;
  final minAmount = params['minAmount'] as double;
  final maxAmount = params['maxAmount'] as double;
  final sortBy = params['sortBy'] as String;
  final query = (params['query'] as String).toLowerCase();
  final minFunding = params['minFunding'] as double;
  final maxFunding = params['maxFunding'] as double;

  var result = raw;
  if (selectedStatus == 'Available') {
    result = result.where((i) => i['status'] == 'available').toList();
  } else if (selectedStatus == 'Partially Funded') {
    result = result.where((i) {
      final status = (i['status'] ?? '').toString().toLowerCase();
      final display = (i['statusDisplay'] ?? '').toString().toLowerCase();
      return status.contains('partial') || display.contains('partial');
    }).toList();
  }

  result = result.where((i) {
    final roi = (i['roi'] as num?)?.toDouble() ?? 0;
    final tenure = (i['tenureDays'] as num?)?.toDouble() ?? 0;
    final amt = (i['remainingAmount'] as num?)?.toDouble() ?? 0;
    final funding = (i['fundingPct'] as num?)?.toDouble() ?? 0;

    return roi >= minRoi &&
        roi <= maxRoi &&
        tenure >= minDays &&
        tenure <= maxDays &&
        amt >= minAmount &&
        amt <= maxAmount &&
        funding >= minFunding &&
        funding <= maxFunding;
  }).toList();

  if (query.isNotEmpty) {
    result = result
        .where((i) =>
    (i['company'] as String).toLowerCase().contains(query) ||
        (i['status'] as String).toLowerCase().contains(query))
        .toList();
  }

  switch (sortBy) {
    case 'roi_high':
      result.sort((a, b) =>
          ((b['roi'] as num?) ?? 0).compareTo((a['roi'] as num?) ?? 0));
      break;
    case 'days_low':
      result.sort((a, b) => ((a['daysLeft'] as num?) ?? 0)
          .compareTo((b['daysLeft'] as num?) ?? 0));
      break;
    case 'amount_low':
      result.sort((a, b) => ((a['remainingAmount'] as num?) ?? 0)
          .compareTo((b['remainingAmount'] as num?) ?? 0));
      break;
    case 'amount_high':
      result.sort((a, b) => ((b['remainingAmount'] as num?) ?? 0)
          .compareTo((a['remainingAmount'] as num?) ?? 0));
      break;
  }
  return result;
}

Map<String, dynamic> _itemToMap(InvoiceItem i) => {
  'id': i.id,
  'company': i.company,
  'status': i.status,
  'statusDisplay': i.statusDisplay,
  'roi': i.roi,
  'daysLeft': i.daysLeft,
  'tenureDays': i.tenureDays,
  'remainingAmount': i.remainingAmount,
  'fundingPct': i.fundingPct,
};

// ── Marketplace Screen ────────────────────────────────────────────────────────

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  static const int _limit = 40;
  int _page = 1;
  bool _animateList = true;
  bool _hasMore = true;
  bool _loadingMore = false;

  final List<InvoiceItem> _invoices = [];
  List<InvoiceItem> _filtered = [];
  bool _isLoading = true;
  String? _loadError;
  int _filterGeneration = 0;

  final GlobalKey<_FastScrollbarState> _fastScrollbarKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  bool _searchVisible = false;
  String _searchQuery = '';
  Timer? _searchDebounce;

  String _selectedStatus = 'All';
  final _statusFilters = ['All', 'Available', 'Partially Funded'];
  final _quickFilters = ['High ROI', 'Short Tenure', 'Almost Funded'];

  double _minRoi = 0, _maxRoi = 30;
  double _minDays = 0, _maxDays = 365;
  double _minAmount = 0, _maxAmount = 10000000;
  double _minFunding = 0;
  double _maxFunding = 100;
  String _sortBy = 'default';
  String? _activeQuickFilter; // Item #16: track active quick filter

  int get _activeFilterCount {
    int c = 0;
    if (_minRoi > 0 || _maxRoi < 30) c++;
    if (_minDays > 0 || _maxDays < 365) c++;
    if (_minAmount > 0 || _maxAmount < 10000000) c++;
    if (_sortBy != 'default') c++;
    if (_minFunding > 0 || _maxFunding < 100) c++;
    return c;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _animateList = false);
      }
    });
    _scrollController.addListener(_onScroll);
    _loadInvoices();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore || _isLoading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadInvoices();
    }
  }

  Future<void> _loadInvoices({bool refresh = false}) async {
    if (!refresh && (_loadingMore || !_hasMore)) return;
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _invoices.clear();
      _filterGeneration++;
    }

    if (mounted) {
      setState(() {
        _loadError = null;
        if (_page == 1) {
          _isLoading = true;
        } else {
          _loadingMore = true;
        }
      });
    }

    try {
      final data = await ApiService.getInvoices(page: _page, limit: _limit);
      if (!mounted) return;

      final incoming = (data)
          .cast<Map<String, dynamic>>()
          .map(InvoiceItem.fromMap)
          .toList();
      final existingIds = _invoices.map((i) => i.id).toSet();
      _invoices.addAll(incoming.where((i) => !existingIds.contains(i.id)));

      if (data.length < _limit) {
        _hasMore = false;
      } else {
        _page++;
      }

      setState(() {
        _isLoading = false;
        _loadingMore = false;
      });
      _applyFilters();

      if (_page == 2 && _invoices.isNotEmpty) {
        unawaited(_updateMarketplaceWidget(_invoices.take(10).toList()));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadingMore = false;
        _loadError = 'Failed to load invoices';
      });
    }
  }

  Future<void> _updateMarketplaceWidget(List<InvoiceItem> data) async {
    if (data.isEmpty) return;
    try {
      final top = data.reduce((a, b) => b.roi > a.roi ? b : a);
      await HomeWidget.saveWidgetData('company', top.company);
      await HomeWidget.saveWidgetData('roi', top.roi.toStringAsFixed(2));
      await HomeWidget.saveWidgetData('days', top.daysLeft.toString());
      await HomeWidget.saveWidgetData(
          'remaining', top.remainingAmount.toStringAsFixed(0));
      await HomeWidget.saveWidgetData('funding', top.fundingPct.toInt());
      await HomeWidget.updateWidget(
          androidName: 'MarketplaceWidgetProvider');
    } catch (_) {}
  }

  Future<void> _applyFilters() async {
    final generation = ++_filterGeneration;
    final params = {
      'invoices': _invoices.map(_itemToMap).toList(),
      'status': _selectedStatus,
      'minRoi': _minRoi,
      'maxRoi': _maxRoi,
      'minDays': _minDays,
      'maxDays': _maxDays,
      'minAmount': _minAmount,
      'maxAmount': _maxAmount,
      'minFunding': _minFunding,
      'maxFunding': _maxFunding,
      'sortBy': _sortBy,
      'query': _searchQuery,
    };

    final rawResult = _invoices.length < _isolateThreshold
        ? _filterInvoicesIsolate(params)
        : await compute(_filterInvoicesIsolate, params);

    if (generation != _filterGeneration || !mounted) return;

    final idMap = {for (final item in _invoices) item.id: item};
    setState(() => _filtered = rawResult
        .map((m) => idMap[m['id']])
        .whereType<InvoiceItem>()
        .toList());
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (_searchQuery != value) {
        _searchQuery = value;
        _applyFilters();
      }
    });
  }

  void _toggleSearch() async {
    await AppHaptics.selection();
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _searchCtrl.clear();
        if (_searchQuery.isNotEmpty) {
          _searchQuery = '';
          _applyFilters();
        }
      }
    });
  }

  void _showFilterSheet() {
    // FIX: copy current filter values into local variables BEFORE opening
    // the sheet. The sheet mutates these local copies via setSheet().
    // The parent state is only updated when the user explicitly taps
    // "Apply Filters". If the user swipes the sheet down to dismiss,
    // the parent state is untouched — no stale filter badge, no ghost filters.
    //
    // Previously, the sheet called setSheet(() { _minRoi = ...; }) which
    // mutated parent state directly, so dismiss-without-apply still changed
    // the filter values (and showed the badge dot) without actually filtering.
    double localMinRoi = _minRoi;
    double localMaxRoi = _maxRoi;
    double localMinDays = _minDays;
    double localMaxDays = _maxDays;
    double localMinAmount = _minAmount;
    double localMaxAmount = _maxAmount;
    double localMinFunding = _minFunding;
    double localMaxFunding = _maxFunding;
    String localSortBy = _sortBy;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.scaffold(context),
      builder: (context) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filters',
                      style: TextStyle(
                          color: AppColors.textPrimary(ctx),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                  TextButton(
                    onPressed: () => setSheet(() {
                      localMinRoi = 0;
                      localMaxRoi = 30;
                      localMinDays = 0;
                      localMaxDays = 365;
                      localMinAmount = 0;
                      localMaxAmount = 10000000;
                      localMinFunding = 0;
                      localMaxFunding = 100;
                      localSortBy = 'default';
                    }),
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Sort By',
                  style: TextStyle(
                      color: AppColors.textPrimary(ctx),
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _FilterChip(
                      label: 'ROI',
                      selected: localSortBy == 'roi_high',
                      onSelected: (s) => setSheet(
                              () => localSortBy = s ? 'roi_high' : 'default')),
                  _FilterChip(
                      label: 'Days Left',
                      selected: localSortBy == 'days_low',
                      onSelected: (s) => setSheet(
                              () => localSortBy = s ? 'days_low' : 'default')),
                  _FilterChip(
                      label: 'Amount',
                      selected: localSortBy == 'amount_high',
                      onSelected: (s) => setSheet(
                              () => localSortBy =
                          s ? 'amount_high' : 'default')),
                ],
              ),
              const SizedBox(height: 24),
              _RangeSection(
                  title: 'ROI Range (%)',
                  values: RangeValues(localMinRoi, localMaxRoi),
                  min: 0,
                  max: 30,
                  onChanged: (v) => setSheet(() {
                    localMinRoi = v.start;
                    localMaxRoi = v.end;
                  })),
              const SizedBox(height: 24),
              _RangeSection(
                  title: 'Total Tenure (Days)',
                  values: RangeValues(localMinDays, localMaxDays),
                  min: 0,
                  max: 365,
                  onChanged: (v) => setSheet(() {
                    localMinDays = v.start;
                    localMaxDays = v.end;
                  })),
              const SizedBox(height: 24),
              _RangeSection(
                title: 'Funding Progress (%)',
                values: RangeValues(localMinFunding, localMaxFunding),
                min: 0,
                max: 100,
                onChanged: (v) => setSheet(() {
                  localMinFunding = v.start;
                  localMaxFunding = v.end;
                }),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // FIX: only now commit local values to parent state
                  setState(() {
                    _minRoi = localMinRoi;
                    _maxRoi = localMaxRoi;
                    _minDays = localMinDays;
                    _maxDays = localMaxDays;
                    _minAmount = localMinAmount;
                    _maxAmount = localMaxAmount;
                    _minFunding = localMinFunding;
                    _maxFunding = localMaxFunding;
                    _sortBy = localSortBy;
                  });
                  _applyFilters();
                  Navigator.pop(context);
                },
                child: const Text('Apply Filters'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: RefreshIndicator(
        onRefresh: () => _loadInvoices(refresh: true),
        child: Listener(
          onPointerDown: (_) {
            _fastScrollbarKey.currentState?.show();
          },
          child: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              // Item #13: platform-adaptive scroll physics
              physics: const AlwaysScrollableScrollPhysics(),
              cacheExtent: 180 * 8,
              slivers: [
                SliverAppBar(
                  expandedHeight: _searchVisible ? 180 : 120,
                  pinned: true,
                  stretch: true,
                  backgroundColor: AppColors.scaffold(context),
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text('Marketplace',
                        style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            letterSpacing: -0.5)),
                    centerTitle: false,
                    titlePadding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    background: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_searchVisible)
                          Padding(
                            padding:
                            const EdgeInsets.fromLTRB(24, 0, 24, 60),
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: _onSearchChanged,
                              style: TextStyle(
                                  color: AppColors.textPrimary(context)),
                              decoration: InputDecoration(
                                hintText: 'Search companies...',
                                prefixIcon:
                                const Icon(Icons.search_rounded),
                                filled: true,
                                fillColor: AppColors.navyCard(context),
                                border: OutlineInputBorder(
                                    borderRadius:
                                    BorderRadius.circular(16),
                                    borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    IconButton(
                        icon: Icon(_searchVisible
                            ? Icons.search_off_rounded
                            : Icons.search_rounded),
                        onPressed: _toggleSearch),
                    Stack(
                      children: [
                        IconButton(
                            icon: const Icon(Icons.tune_rounded),
                            onPressed: _showFilterSheet),
                        if (_activeFilterCount > 0)
                          Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      shape: BoxShape.circle))),
                      ],
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Status Filters ─────────────────────────
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _statusFilters.map((f) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(f),
                                  selected: _selectedStatus == f,
                                  onSelected: (s) {
                                    if (s) {
                                      setState(
                                              () => _selectedStatus = f);
                                      _applyFilters();
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ── Quick Filters ─────────────────────────
                        // ── Quick Filters ─────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: _quickFilters.map((f) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(f),
                                        avatar: const Icon(Icons.flash_on, size: 16),
                                        selected: _activeQuickFilter == f,
                                        onSelected: (_) {
                                          setState(() {
                                            _minRoi = 0;
                                            _maxRoi = 30;
                                            _minDays = 0;
                                            _maxDays = 365;
                                            _minFunding = 0;
                                            _maxFunding = 100;

                                            if (_activeQuickFilter == f) {
                                              _activeQuickFilter = null;
                                            } else {
                                              _activeQuickFilter = f;

                                              if (f == 'High ROI') {
                                                _minRoi = 13;
                                              }
                                              if (f == 'Short Tenure') {
                                                _maxDays = 30;
                                              }
                                              if (f == 'Almost Funded') {
                                                _minFunding = 75;
                                              }
                                            }
                                          });

                                          _applyFilters();
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            ActionChip(
                              label: const Text('Clear'),
                              avatar: const Icon(Icons.close_rounded, size: 16),
                              onPressed: () {
                                setState(() {
                                  _activeQuickFilter = null;
                                  _minRoi = 0;
                                  _maxRoi = 30;
                                  _minDays = 0;
                                  _maxDays = 365;
                                  _minFunding = 0;
                                  _maxFunding = 100;
                                });

                                _applyFilters();
                              },
                            ),
                          ],
                        ),

                              const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                if (_isLoading)
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                                (ctx, i) => const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: SkeletonCard(height: 160)),
                            childCount: 3)),
                  )
                else if (_filtered.isEmpty)
                  SliverFillRemaining(
                      child: Center(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded,
                                    size: 64, color: colorScheme.outline),
                                const SizedBox(height: 16),
                                Text(_loadError ?? 'No invoices found',
                                    style: TextStyle(
                                        color:
                                        AppColors.textSecondary(context))),
                                if (_loadError != null) ...[
                                  const SizedBox(height: 16),
                                  TextButton.icon(
                                    icon: const Icon(Icons.refresh_rounded,
                                        size: 16),
                                    label: const Text('Retry'),
                                    onPressed: () =>
                                        _loadInvoices(refresh: true),
                                  ),
                                ],
                              ])))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    sliver: SliverPrototypeExtentList(
                      prototypeItem: const _InvoiceCard(
                        item: InvoiceItem(
                          id: '',
                          company: '',
                          particular: '',
                          debtor: '',
                          status: '',
                          statusDisplay: '',
                          roi: 0,
                          daysLeft: 0,
                          tenureDays: 0,
                          remainingAmount: 0,
                          fundingPct: 0,
                          roiDisplay: '',
                          daysLeftDisplay: '',
                          tenureDisplay: '',
                          remainingDisplay: '',
                          fundingDisplay: '',
                        ),
                      ),
                      delegate: SliverChildBuilderDelegate(
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                            (ctx, i) => RepaintBoundary(
                          child: _animateList
                              ? StaggerItem(
                            index: i,
                            child: _InvoiceCard(item: _filtered[i]),
                          )
                              : _InvoiceCard(item: _filtered[i]),
                        ),
                        childCount: _filtered.length,
                      ),
                    ),
                  ),
              ],
            ),

            // ── Fast scrollbar overlay ─────────────────────────────
            if (!_isLoading && _filtered.length > 6)
              Positioned(
                right: 4,
                top: MediaQuery.of(context).padding.top + 120,
                bottom: 80,
                child: _FastScrollbar(
                  key: _fastScrollbarKey,
                  controller: _scrollController,
                  itemCount: _filtered.length,
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

// ── Fast Scrollbar ────────────────────────────────────────────────────────────

class _FastScrollbar extends StatefulWidget {
  final ScrollController controller;
  final int itemCount;


  const _FastScrollbar({
    super.key,
    required this.controller,
    required this.itemCount,
  });

  @override
  State<_FastScrollbar> createState() => _FastScrollbarState();
}

class _FastScrollbarState extends State<_FastScrollbar>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  bool _dragging = false;
  double _lastDragY = 0;
  DateTime? _lastDragTime;
  double _thumbFraction = 0;
  int _currentIndex = 0;
  int _lastHapticIndex = -1;
  Timer? _hideTimer;
  DateTime? _lastScrollUpdate;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  static const double _thumbH = 46;
  static const double _thumbHDrag = 56;
  static const double _hitWidth = 32;

  void show() {
    if (!mounted) return;

    setState(() => _visible = true);
    _fadeCtrl.forward();
    _scheduleHide();
  }

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_onScroll);
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_dragging) return;
    if (!widget.controller.hasClients) return;
    final maxScroll = widget.controller.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final frac =
    (widget.controller.offset / maxScroll).clamp(0.0, 1.0);
    final newIndex =
    ((frac * (widget.itemCount - 1)).round())
        .clamp(0, widget.itemCount - 1);

    if ((_thumbFraction - frac).abs() > 0.002 || _currentIndex != newIndex) {
      setState(() {
        _thumbFraction = frac;
        _currentIndex = newIndex;
        _visible = true;
      });
    }
    _fadeCtrl.forward();
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 900), () {
      if (!_dragging && mounted) {
        _fadeCtrl.reverse().then((_) {
          if (mounted) setState(() => _visible = false);
        });
      }
    });
  }

  void _startDrag() {
    _hideTimer?.cancel();
    setState(() => _dragging = true);
    _fadeCtrl.forward();
    AppHaptics.scrollTick();

    _lastDragTime = DateTime.now();
  }

  void _updateDrag(double localY, double trackHeight) {
    final thumbH = _dragging ? _thumbHDrag : _thumbH;
    final usableTrack = trackHeight - thumbH;

    final now = DateTime.now();
    if (_lastScrollUpdate != null &&
        now.difference(_lastScrollUpdate!).inMilliseconds < 16) {
      return;
    }
    _lastScrollUpdate = now;
    final dt = _lastDragTime == null
        ? 16
        : now.difference(_lastDragTime!).inMilliseconds;

    final dy = localY - _lastDragY;

    // pixels per ms
    final velocity = dt > 0 ? (dy.abs() / dt) : 0;

    double acceleration = 1.0;

    if (velocity > 1.2) acceleration = 3.0;
    else if (velocity > 0.6) acceleration = 2.0;
    else if (velocity > 0.3) acceleration = 1.4;

    final frac =
    ((localY - thumbH / 2) / usableTrack).clamp(0.0, 1.0);

    final maxScroll = widget.controller.position.maxScrollExtent;

    widget.controller.animateTo(
      (frac * maxScroll * acceleration)
          .clamp(0.0, maxScroll),
      duration: const Duration(milliseconds: 10),
      curve: Curves.linear,
    );

    final index =
    ((frac * (widget.itemCount - 1)).round())
        .clamp(0, widget.itemCount - 1);

    if (index != _lastHapticIndex) {
      _lastHapticIndex = index;
      AppHaptics.selection();
    }

    if ((_thumbFraction - frac).abs() > 0.002 || _currentIndex != index) {
      setState(() {
        _thumbFraction = frac;
        _currentIndex = index;
        _visible = true;
      });
    }

    _lastDragY = localY;
    _lastDragTime = now;
  }

  void _endDrag() {
    setState(() => _dragging = false);
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox(width: _hitWidth);

    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SizedBox(
        width: _hitWidth,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final trackHeight = constraints.maxHeight;
            final thumbH = _dragging ? _thumbHDrag : _thumbH;
            final thumbTop =
            (_thumbFraction * (trackHeight - thumbH))
                .clamp(0.0, trackHeight - thumbH);

            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragStart: (_) => _startDrag(),
              onVerticalDragUpdate: (d) =>
                  _updateDrag(d.localPosition.dy, trackHeight),
              onVerticalDragEnd: (_) => _endDrag(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: (_hitWidth - 2) / 2,
                    top: 20,
                    bottom: 20,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                      duration: _dragging
                          ? Duration.zero
                          : const Duration(milliseconds: 80),
                      right: 2,
                      top: thumbTop,
                      child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: _dragging ? 10 : 6,
            height: _dragging ? 48 : 36,
            decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _dragging
            ? primary
                : primary.withValues(alpha: 0.7),

                          boxShadow: [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.35),
                              blurRadius: 10,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                      )
                  ),
                  if (_dragging)
                    AnimatedPositioned(
                      duration: Duration.zero,
                      top: thumbTop + thumbH / 2 - 18,
                      right: _hitWidth + 6,
                      child: _LabelBubble(
                        label:
                        '${_currentIndex + 1} / ${widget.itemCount}',
                        color: primary,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LabelBubble extends StatelessWidget {
  final String label;
  final Color color;

  const _LabelBubble({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(2),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Function(bool) onSelected;

  const _FilterChip(
      {required this.label,
        required this.selected,
        required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
        showCheckmark: false,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)));
  }
}

class _RangeSection extends StatelessWidget {
  final String title;
  final RangeValues values;
  final double min, max;
  final Function(RangeValues) onChanged;

  const _RangeSection(
      {required this.title,
        required this.values,
        required this.min,
        required this.max,
        required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title,
              style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.w700)),
          Text('${values.start.toInt()} - ${values.end.toInt()}',
              style: TextStyle(
                  color: AppColors.primary(context),
                  fontWeight: FontWeight.w600))
        ]),
        RangeSlider(
          values: values,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: AppColors.primary(context),
        ),
      ],
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final InvoiceItem item;

  const _InvoiceCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final statusColor = item.isAvailable
        ? AppColors.emerald(context)
        : AppColors.amber(context);

    final daysColor = item.daysLeft <= 7
        ? AppColors.rose(context)
        : item.daysLeft <= 30
        ? AppColors.amber(context)
        : AppColors.primary(context);

    return Pressable(
      onTap: () async {
        await AppHaptics.selection();
        if (context.mounted) {
          Navigator.push(
              context,
              SmoothPageRoute(
                  builder: (_) => InvoiceDetailScreen(item: item)));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.navyCard(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.divider(context)),
          boxShadow: AppColors.cardShadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.company,
                              style: TextStyle(
                                  color: AppColors.textPrimary(context),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16)),
                          Text(item.particular,
                              style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontSize: 12))
                        ])),
                Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.2))),
                    child: Text(item.statusDisplay,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800))),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatCell(
                    label: 'ROI',
                    value: item.roiDisplay,
                    color: AppColors.emerald(context)),
                _StatCell(
                    label: 'Tenure',
                    value: item.tenureDisplay,
                    color: AppColors.primary(context)),
                _StatCell(
                    label: 'Remaining',
                    value: item.remainingDisplay,
                    color: AppColors.textPrimary(context)),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 13, color: daysColor),
                const SizedBox(width: 4),
                Text(
                  '${item.daysLeft}D left to payment',
                  style: TextStyle(
                      color: daysColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                if (item.debtor.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text('·',
                      style: TextStyle(
                          color: AppColors.textSecondary(context))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.debtor,
                      style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            LinearProgressIndicator(
              value: item.fundingPct / 100,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: AppColors.navyLight(context),
              valueColor:
              AlwaysStoppedAnimation(AppColors.primary(context)),
            ),
            const SizedBox(height: 8),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Funding Progress',
                      style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                  Text(item.fundingDisplay,
                      style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w800))
                ]),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label, value;
  final Color color;

  const _StatCell(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: AppColors.textSecondary(context), fontSize: 11)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()]))
        ]);
  }
}