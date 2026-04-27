import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:invoice_discounting_app/services/portfolio_api_service.dart';
import 'package:invoice_discounting_app/services/profile_api_service.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/formatters.dart';
import 'package:invoice_discounting_app/widgets/app_logo_header.dart';
import 'package:invoice_discounting_app/widgets/liquidity_refresh_indicator.dart';
import 'package:invoice_discounting_app/widgets/premium_date_sheet.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shimmer/shimmer.dart';

class Receivable {
  Receivable({
    this.invoiceNumber,
    this.dateOfInvoice,
    this.dateOfFunding,
    this.dueDateOfInvoice,
    this.amountOfInvoice,
    this.roiRate,
    this.principalAmount,
    this.roiAmount,
    this.penalCharges,
    this.seller,
    this.debtor,
    this.status,
  });

  factory Receivable.fromJson(Map<String, dynamic> json) => Receivable(
        invoiceNumber: json['invoice_number']?.toString(),
        dateOfInvoice: json['date_of_invoice']?.toString(),
        dateOfFunding: json['date_of_funding']?.toString(),
        dueDateOfInvoice: json['due_date_of_invoice']?.toString(),
        amountOfInvoice: json['amount_of_invoice']?.toString(),
        roiRate: json['roi_rate']?.toString(),
        principalAmount: json['principal_amount']?.toString(),
        roiAmount: json['roi_amount']?.toString(),
        penalCharges: json['penal_charges']?.toString(),
        seller: json['seller']?.toString(),
        debtor: json['debtor']?.toString(),
        status: json['status']?.toString(),
      );

  final String? invoiceNumber;
  final String? dateOfInvoice;
  final String? dateOfFunding;
  final String? dueDateOfInvoice;
  final String? amountOfInvoice;
  final String? roiRate;
  final String? principalAmount;
  final String? roiAmount;
  final String? penalCharges;
  final String? seller;
  final String? debtor;
  final String? status;

  Map<String, dynamic> toJson() => {
        'invoice_number': invoiceNumber,
        'date_of_invoice': dateOfInvoice,
        'date_of_funding': dateOfFunding,
        'due_date_of_invoice': dueDateOfInvoice,
        'amount_of_invoice': amountOfInvoice,
        'roi_rate': roiRate,
        'principal_amount': principalAmount,
        'roi_amount': roiAmount,
        'penal_charges': penalCharges,
        'seller': seller,
        'debtor': debtor,
        'status': status,
      };
}

class ReceivableStatementScreen extends ConsumerStatefulWidget {
  const ReceivableStatementScreen({super.key});

  @override
  ConsumerState<ReceivableStatementScreen> createState() =>
      _ReceivableStatementScreenState();
}

class _ReceivableStatementScreenState
    extends ConsumerState<ReceivableStatementScreen> {
  // Caching for "Instant" feel
  static final Map<String, List<Receivable>> _dataCache = {};
  static final Map<String, String> _totalAmountCache = {};
  static final Map<String, int> _totalCountCache = {};

  bool _isLoading = true;
  String? _totalAmount;
  int _totalCount = 0;
  List<Receivable> _receivables = [];
  DateTime _selectedDate = DateTime.now();
  String _userName = 'User';

  @override
  void initState() {
    super.initState();
    _fetchData();
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    try {
      final profile = await ProfileApiService.getProfile();
      if (profile != null && mounted) {
        setState(() {
          _userName = profile['name']?.toString() ?? 'User';
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchData({bool forceRefresh = false}) async {
    final dateKey = _selectedDate.toIso8601String().split('T')[0];

    // If we have cached data and NOT force refreshing, show it instantly
    if (!forceRefresh && _dataCache.containsKey(dateKey)) {
      setState(() {
        _receivables = _dataCache[dateKey]!;
        _totalAmount = _totalAmountCache[dateKey];
        _totalCount = _totalCountCache[dateKey] ?? 0;
        _isLoading = false;
      });
      // Optionally re-fetch in background to keep it fresh
      _backgroundUpdate(dateKey);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await PortfolioApiService.getReceivableStatement(
        asOnDate: _selectedDate.toIso8601String().split('T')[0],
      );

      if (mounted && response != null) {
        final data = response['data'] as List? ?? [];
        final fetched = data
            .map((e) => Receivable.fromJson(e as Map<String, dynamic>))
            .toList();

        final amt = response['total_amount']?.toString();
        final count =
            int.tryParse(response['total_receivables']?.toString() ?? '0') ?? 0;

        // Update Cache
        _dataCache[dateKey] = fetched;
        _totalAmountCache[dateKey] = amt ?? '0';
        _totalCountCache[dateKey] = count;

        setState(() {
          _receivables = fetched;
          _totalAmount = amt;
          _totalCount = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _backgroundUpdate(String dateKey) async {
    try {
      final response = await PortfolioApiService.getReceivableStatement(
        asOnDate: _selectedDate.toIso8601String().split('T')[0],
      );
      if (mounted && response != null) {
        final data = response['data'] as List? ?? [];
        final fetched = data
            .map((e) => Receivable.fromJson(e as Map<String, dynamic>))
            .toList();

        _dataCache[dateKey] = fetched;
        _totalAmountCache[dateKey] =
            response['total_amount']?.toString() ?? '0';
        _totalCountCache[dateKey] =
            int.tryParse(response['total_receivables']?.toString() ?? '0') ?? 0;

        // Only update UI if we are still on the same date
        final currentKey = _selectedDate.toIso8601String().split('T')[0];
        if (currentKey == dateKey) {
          setState(() {
            _receivables = fetched;
            _totalAmount = _totalAmountCache[dateKey];
            _totalCount = _totalCountCache[dateKey] ?? 0;
          });
        }
      }
    } catch (_) {}
  }

  void _showDatePicker() {
    AppHaptics.selection();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PremiumDateSheet(
        title: 'Select As On Date',
        initialDate: _selectedDate,
        minimumDate: DateTime(2020),
        maximumDate: DateTime.now().add(const Duration(days: 365 * 10)),
        onDateSelected: (date) {
          setState(() => _selectedDate = date);
          _fetchData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: LiquidityRefreshIndicator(
        onRefresh: () => _fetchData(forceRefresh: true),
        color: cs.primary,
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Header
              const AppLogoHeader(title: 'Statement'),

              // Dropdowns
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(UI.lg, UI.sm, UI.lg, UI.md),
                  child: Row(
                    children: [
                      Expanded(child: _buildDateDropdown(cs, tt)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildProfileDropdown(cs, tt)),
                    ],
                  ),
                ),
              ),

              // Summary Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: UI.lg),
                  child: _buildSummaryCard(cs, tt),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: UI.lg)),

              // Table
              if (_isLoading && _receivables.isEmpty)
                SliverFillRemaining(
                  child: _buildShimmerTable(cs, tt),
                )
              else
                _buildSliverTable(cs, tt, cs.primary),

              if (_isLoading && _receivables.isNotEmpty)
                const SliverToBoxAdapter(
                  child: LinearProgressIndicator(minHeight: 2),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateDropdown(ColorScheme cs, TextTheme tt) => GestureDetector(
        onTap: _showDatePicker,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(UI.radiusLg),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(AppIcons.calendar, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'AS ON',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      DateFormat('dd-MM-yyyy').format(_selectedDate),
                      style:
                          tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      );

  Widget _buildProfileDropdown(ColorScheme cs, TextTheme tt) {
    final name = _userName;
    final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(UI.radiusLg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: tt.labelSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PROFILE',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  name,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.keyboard_arrow_down, size: 20, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ColorScheme cs, TextTheme tt) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary,
              cs.primary.withValues(alpha: 0.82),
            ],
          ),
          borderRadius: BorderRadius.circular(UI.radiusXl),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_totalCount RECEIVABLES · TOTAL AMOUNT',
                    style: tt.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_totalAmount == null)
                    LoadingAnimationWidget.staggeredDotsWave(
                      color: Colors.white,
                      size: 24,
                    )
                  else
                    Text(
                      Formatters.currency(_totalAmount ?? '0'),
                      style: tt.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                AppHaptics.selection();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coming Soon')),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(UI.radiusMd),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.download_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Download',
                      style: tt.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildSliverTable(ColorScheme cs, TextTheme tt, Color primaryColor) {
    if (_receivables.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(AppIcons.document, size: 48, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                'No records found',
                style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }
    return SliverToBoxAdapter(
      child: _buildTableSection(cs, tt),
    );
  }

  Widget _buildShimmerTable(ColorScheme cs, TextTheme tt) => Shimmer.fromColors(
        baseColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        highlightColor: cs.surfaceContainerHighest.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: UI.lg),
          child: Column(
            children: List.generate(
              6,
              (index) => Container(
                height: 60,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(UI.radiusMd),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _buildTableSection(ColorScheme cs, TextTheme tt) => Container(
        margin: const EdgeInsets.symmetric(horizontal: UI.lg),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(UI.radiusXl),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Table Title Row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Text(
                    'Receivables',
                    style:
                        tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_receivables.length} entries',
                      style: tt.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Horizontal Scrollable Table
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTableHeaderRow(cs, tt),
                  ...List.generate(
                    _receivables.length,
                    (index) =>
                        _buildTableRow(_receivables[index], index, cs, tt),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      );

  final List<Map<String, Object>> _columns = const [
    {'title': 'INVOICE NUMBER', 'width': 180.0},
    {'title': 'DATE OF INVOICE', 'width': 140.0},
    {'title': 'DATE OF FUNDING', 'width': 140.0},
    {'title': 'DUE DATE OF INVOICE', 'width': 150.0},
    {'title': 'AMOUNT OF INVOICE', 'width': 150.0},
    {'title': 'EST. YIELD RATE', 'width': 120.0},
    {'title': 'PRINCIPAL AMOUNT', 'width': 140.0},
    {'title': 'EST. YIELD AMT', 'width': 130.0},
    {'title': 'PENAL CHARGES', 'width': 120.0},
    {'title': 'SELLER', 'width': 180.0},
    {'title': 'DEBTOR', 'width': 180.0},
  ];

  Widget _buildTableHeaderRow(ColorScheme cs, TextTheme tt) {
    // Derive a darker header tint from the theme primary
    final headerColor = Color.lerp(cs.primary, Colors.black, 0.25)!;

    return ColoredBox(
      color: headerColor,
      child: Row(
        children: _columns
            .map(
              (col) => Container(
                width: col['width']! as double,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  col['title']! as String,
                  style: tt.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTableRow(
    Receivable item,
    int index,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final isEven = index.isEven;

    String fmtDate(String? d) {
      if (d == null || d.isEmpty) return '-';
      try {
        final parsed = DateTime.parse(d);
        return DateFormat('MMM d, yyyy').format(parsed);
      } catch (_) {
        return d;
      }
    }

    String fmtAmt(String? a) {
      final val = double.tryParse(a ?? '0') ?? 0.0;
      return Formatters.currency(val).replaceAll('₹', '');
    }

    return ColoredBox(
      color: isEven
          ? Colors.transparent
          : cs.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Row(
        children: [
          _cell(
            item.invoiceNumber ?? '-',
            _columns[0]['width']! as double,
            tt,
            isBold: true,
          ),
          _cell(
            fmtDate(item.dateOfInvoice),
            _columns[1]['width']! as double,
            tt,
          ),
          _cell(
            fmtDate(item.dateOfFunding),
            _columns[2]['width']! as double,
            tt,
          ),
          _cell(
            fmtDate(item.dueDateOfInvoice),
            _columns[3]['width']! as double,
            tt,
          ),
          _cell(
            fmtAmt(item.amountOfInvoice),
            _columns[4]['width']! as double,
            tt,
          ),
          _cell(
            '${item.roiRate ?? '0.0'}%',
            _columns[5]['width']! as double,
            tt,
          ),
          _cell(
            fmtAmt(item.principalAmount),
            _columns[6]['width']! as double,
            tt,
          ),
          _cell(
            fmtAmt(item.roiAmount),
            _columns[7]['width']! as double,
            tt,
          ),
          _cell(
            fmtAmt(item.penalCharges),
            _columns[8]['width']! as double,
            tt,
          ),
          _cell(
            item.seller ?? '-',
            _columns[9]['width']! as double,
            tt,
          ),
          _cell(
            item.debtor ?? '-',
            _columns[10]['width']! as double,
            tt,
          ),
        ],
      ),
    );
  }

  Widget _cell(
    String text,
    double width,
    TextTheme tt, {
    bool isBold = false,
  }) =>
      Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Text(
          text,
          style: tt.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
}
