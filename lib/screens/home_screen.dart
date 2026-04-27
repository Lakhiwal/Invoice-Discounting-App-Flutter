import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/models/invoice_item.dart';
import 'package:invoice_discounting_app/screens/marketplace_screen.dart';
import 'package:invoice_discounting_app/screens/payment_status_screen.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/services/cashfree_service.dart';
import 'package:invoice_discounting_app/services/portfolio_cache.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/formatters.dart';
import 'package:invoice_discounting_app/utils/momentum_haptics.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';
import 'package:invoice_discounting_app/widgets/app_bar_action.dart';
import 'package:invoice_discounting_app/widgets/app_logo_header.dart';
import 'package:invoice_discounting_app/widgets/home/active_investment_card.dart';
import 'package:invoice_discounting_app/widgets/home/portfolio_hero.dart';
import 'package:invoice_discounting_app/widgets/home/quick_actions.dart';
import 'package:invoice_discounting_app/widgets/liquidity_refresh_indicator.dart';
import 'package:invoice_discounting_app/widgets/marketplace/invoice_card.dart';
import 'package:invoice_discounting_app/widgets/skeleton.dart';
import 'package:invoice_discounting_app/widgets/vibe_state_wrapper.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

const String _kMaskedShort = '● ● ●';

// ── Screen ────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Map<String, dynamic>? _portfolio;
  Map<String, dynamic>? _wallet;
  bool _isLoading = true;
  bool _hasError = false;
  late CashfreeService _cashfree;
  late final ScrollController _scrollController;
  final MomentumHaptics _momentumHaptics = MomentumHaptics();

  List<InvoiceItem> _unfundedInvoices = [];
  double _irr = 0.0;

  // Pagination State
  int _invoicePage = 1;
  bool _isMoreInvoicesLoading = false;
  bool _hasMoreInvoices = true;

  double get _walletBalance =>
      double.tryParse(_wallet?['balance']?.toString() ?? '0') ?? 0;
  double get _totalInvested {
    final summary = _portfolio?['summary'] as Map<String, dynamic>?;
    return double.tryParse(summary?['total_invested']?.toString() ?? '0') ?? 0;
  }

  double get _totalReturns {
    final summary = _portfolio?['summary'] as Map<String, dynamic>?;
    return double.tryParse(summary?['total_returns']?.toString() ?? '0') ?? 0;
  }

  List get _activeInvestments => _portfolio?['active'] as List? ?? [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _cashfree = CashfreeService();

    // MANDATORY SYNC: Always force a fresh fetch on first mount of this session
    // to prevent observing stale data from previous users or APK installs.
    unawaited(_loadData(forceRefresh: true));
  }

  @override
  void dispose() {
    _cashfree.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> _waitForWalletUpdate({int maxRetries = 10}) async {
    final initialBalance = _walletBalance;
    for (var i = 0; i < maxRetries; i++) {
      await Future.delayed(const Duration(seconds: 1));
      try {
        final wallet = await ApiService.getWallet();
        final balance =
            double.tryParse(wallet?['balance']?.toString() ?? '0') ?? 0;
        if (balance > initialBalance) return true;
      } catch (_) {}
    }
    return false;
  }

  void _onScroll() {
    _momentumHaptics.onScroll(_scrollController.position.pixels);

    // Pagination trigger: 20 per query, load another when reached 15 or 16
    // We check if we are near the bottom of the list
    if (_scrollController.position.pixels >
            _scrollController.position.maxScrollExtent - 800 &&
        !_isMoreInvoicesLoading &&
        _hasMoreInvoices) {
      _loadMoreInvoices();
    }
  }

  Future<void> _loadMoreInvoices() async {
    if (_isMoreInvoicesLoading || !_hasMoreInvoices) return;

    setState(() => _isMoreInvoicesLoading = true);
    try {
      final nextPage = _invoicePage + 1;
      final results = await ApiService.getInvoices(
        page: nextPage,
        limit: 20,
        status: 'approved',
        unfundedOnly: true,
      );

      if (mounted) {
        final newInvoices = results
            .map((e) => InvoiceItem.fromMap(e as Map<String, dynamic>))
            .where(
              (i) => i.status.toLowerCase() == 'available' && i.fundingPct == 0,
            )
            .toList();

        setState(() {
          _unfundedInvoices.addAll(newInvoices);
          _invoicePage = nextPage;
          _isMoreInvoicesLoading = false;
          if (newInvoices.isEmpty) {
            _hasMoreInvoices = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isMoreInvoicesLoading = false);
      }
    }
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    final startTime = DateTime.now();

    // Only set _isLoading to true if we don't have data yet.
    // For pull-to-refresh (forceRefresh), we want a "silent" update
    // so the LiquidityRefreshIndicator's "Syncing" state is the star.
    if (!forceRefresh) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final results = await Future.wait([
        PortfolioCache.getPortfolio(forceRefresh: forceRefresh),
        ApiService.getWallet(forceRefresh: forceRefresh),
        ApiService.getCachedUser(),
        ApiService.getProfile(),
        ApiService.getInvoices(
          limit: 20,
          forceRefresh: forceRefresh,
          unfundedOnly: true,
        ),
      ]);

      // Ensure the "Syncing" state is visible for a premium feel
      if (forceRefresh) {
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        if (elapsed < 800) {
          await Future.delayed(Duration(milliseconds: 800 - elapsed));
        }
      }

      if (mounted) {
        final portfolio = results[0] as Map<String, dynamic>?;
        final rawInvoices = results[4] as List? ?? [];

        // 1. Categorize Invoices
        final invoices = rawInvoices
            .map((e) => InvoiceItem.fromMap(e as Map<String, dynamic>))
            .toList();

        _unfundedInvoices = invoices
            .where(
              (i) => i.status.toLowerCase() == 'available' && i.fundingPct == 0,
            )
            .toList();
        _invoicePage = 1;
        _hasMoreInvoices = _unfundedInvoices.length >= 20;

        // 2. Calculate Portfolio IRR (Weighted Avg Yield)
        final active = portfolio?['active'] as List? ?? [];
        final totalInvested = double.tryParse(
              portfolio?['summary']?['total_invested']?.toString() ?? '0',
            ) ??
            0;

        var irr = 0.0;
        if (active.isNotEmpty && totalInvested > 0) {
          var weightedSum = 0.0;
          for (final inv in active) {
            final amt = double.tryParse(inv['amount']?.toString() ?? '0') ?? 0;
            final rate =
                double.tryParse(inv['investor_rate']?.toString() ?? '0') ?? 0;
            weightedSum += amt * rate;
          }
          irr = weightedSum / totalInvested;
        }

        setState(() {
          _portfolio = portfolio;
          _wallet = results[1] as Map<String, dynamic>?;
          _irr = irr;
          _isLoading = false;
        });
        unawaited(AppHaptics.numberReveal());
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

  // ── Bottom sheets (unchanged) ───────────────────────────────────────────

  void _showAddFundsSheet({double? prefillAmount}) {
    final controller = TextEditingController();
    if (prefillAmount != null) {
      controller.text = prefillAmount.toStringAsFixed(0);
    }
    var isLoading = false;
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              UI.lg,
              8,
              UI.lg,
              MediaQuery.paddingOf(context).bottom + 40,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Funds',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Instant credit to your E-Collect Account',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}'),
                    ),
                  ],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                    hintText: '0.00',
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(UI.radiusLg),
                      borderSide: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(UI.radiusLg),
                      borderSide: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(UI.radiusLg),
                      borderSide:
                          BorderSide(color: colorScheme.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['1000', '5000', '10000', '25000', '50000']
                        .map(
                          (amt) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              label: Text('₹$amt'),
                              onPressed: () {
                                unawaited(AppHaptics.selection());
                                controller.text = amt;
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(UI.radiusSm),
                              ),
                              backgroundColor: colorScheme.surfaceContainerHigh,
                              side: BorderSide.none,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final amt = double.tryParse(controller.text);
                          if (amt == null || amt <= 0 || amt > 50000) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Maximum ₹50,000 allowed per transaction',
                                ),
                              ),
                            );
                            return;
                          }

                          final result =
                              await ApiService.createCashfreeOrder(amt);

                          if (!mounted) return;
                          final messenger = ScaffoldMessenger.of(context);

                          if (result['error'] != null &&
                              result['success'] == false) {
                            setModal(() => isLoading = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(result['error'] as String),
                              ),
                            );
                            return;
                          }

                          final orderId = result['order_id'] as String;
                          final sessionId =
                              result['payment_session_id'] as String;
                          final env =
                              result['environment'] as String? ?? 'SANDBOX';

                          final homeNavigator = Navigator.of(context);

                          _cashfree.onSuccess = (cfOrderId) async {
                            if (!mounted) return;
                            homeNavigator.pop(); // close bottom sheet
                            unawaited(
                              homeNavigator.push(
                                SmoothPageRoute<void>(
                                  builder: (_) => const PaymentStatusScreen(
                                    status: PaymentStatus.processing,
                                  ),
                                ),
                              ),
                            );

                            final verifyResult =
                                await ApiService.verifyCashfreePayment(
                              orderId: orderId,
                            );

                            if (!mounted) return;

                            final paymentStatus = verifyResult['status'];

                            if (paymentStatus == 'completed') {
                              unawaited(
                                homeNavigator.pushReplacement(
                                  SmoothPageRoute<void>(
                                    builder: (_) => PaymentStatusScreen(
                                      status: PaymentStatus.success,
                                      onDismiss: _loadData,
                                    ),
                                  ),
                                ),
                              );
                            } else if (paymentStatus == 'pending') {
                              final walletUpdated =
                                  await _waitForWalletUpdate(maxRetries: 8);
                              if (!mounted) return;
                              unawaited(
                                homeNavigator.pushReplacement(
                                  SmoothPageRoute<void>(
                                    builder: (_) => PaymentStatusScreen(
                                      status: walletUpdated
                                          ? PaymentStatus.success
                                          : PaymentStatus.success,
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              unawaited(
                                homeNavigator.pushReplacement(
                                  SmoothPageRoute<void>(
                                    builder: (_) => PaymentStatusScreen(
                                      status: PaymentStatus.failed,
                                      onDismiss: _loadData,
                                    ),
                                  ),
                                ),
                              );
                            }
                          };

                          _cashfree.onError = (error) {
                            if (!mounted) return;
                            try {
                              homeNavigator.pop();
                            } catch (_) {}
                            unawaited(
                              homeNavigator.push(
                                SmoothPageRoute<void>(
                                  builder: (_) => PaymentStatusScreen(
                                    status: PaymentStatus.failed,
                                    onDismiss: _loadData,
                                  ),
                                ),
                              ),
                            );
                          };

                          // Open Cashfree checkout
                          _cashfree.openCheckout(
                            orderId: orderId,
                            paymentSessionId: sessionId,
                            environment: env,
                          );
                        },
                  child: isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: LoadingAnimationWidget.staggeredDotsWave(
                            color: Colors.white,
                            size: 24,
                          ),
                        )
                      : const Text('Confirm Deposit'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showWithdrawSheet() {
    final controller = TextEditingController();
    var isLoading = false;
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              MediaQuery.paddingOf(context).bottom + 40,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Withdraw',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Available: ₹${fmtAmount(_walletBalance)}',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}'),
                    ),
                  ],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w800,
                    ),
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
                        color: colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(UI.radiusMd),
                      borderSide:
                          BorderSide(color: colorScheme.error, width: 1.5),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      AppHaptics.selection();
                      controller.text = _walletBalance.toStringAsFixed(2);
                    },
                    child: const Text('Withdraw All'),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.error,
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final amt = double.tryParse(controller.text);
                          if (amt == null || amt <= 0 || amt > _walletBalance) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Invalid amount or insufficient balance',
                                ),
                              ),
                            );
                            return;
                          }
                          setModal(() => isLoading = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final successColor = AppColors.success(context);
                          final errorColor = colorScheme.error;
                          try {
                            await ApiService.withdrawFunds(amt);
                            if (!mounted) return;
                            unawaited(AppHaptics.success());
                            Navigator.pop(context);
                            _loadData();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  '₹${fmtAmount(amt)} withdrawn successfully',
                                ),
                                backgroundColor: successColor,
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            setModal(() => isLoading = false);
                            unawaited(AppHaptics.error());
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Failed: $e'),
                                backgroundColor: errorColor,
                              ),
                            );
                          }
                        },
                  child: isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: LoadingAnimationWidget.staggeredDotsWave(
                            color: Colors.white,
                            size: 24,
                          ),
                        )
                      : const Text('Withdraw Funds'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final summary = _portfolio?['summary'];
    final transactions = _wallet?['transactions'] as List? ?? [];
    final isBlack = ref.watch(themeProvider.select((p) => p.isBlackMode));

    final dividerColor = colorScheme.outlineVariant.withValues(
      alpha: isBlack ? 0.12 : 0.15,
    );

    return Container(
      decoration: isBlack
          ? null
          : BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.surface,
                  colorScheme.surfaceContainerLow,
                  colorScheme.surface,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
      child: Scaffold(
        backgroundColor: isBlack ? colorScheme.surface : Colors.transparent,
        body: LiquidityRefreshIndicator(
          onRefresh: () => _loadData(forceRefresh: true),
          color: colorScheme.primary,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              const AppLogoHeader(
                title: 'Home',
                actions: [
                  AppBarActions(),
                ],
              ),
              if (_isLoading || _hasError)
                SliverToBoxAdapter(
                  child: VibeStateWrapper(
                    state: _isLoading
                        ? VibeState.loading
                        : (_hasError ? VibeState.error : VibeState.success),
                    loadingSkeleton: const SkeletonHomeContent(),
                    onRetry: () => _loadData(forceRefresh: true),
                    child: const SizedBox.shrink(),
                  ),
                ),
              if (!_isLoading && !_hasError) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: AnimatedBuilder(
                      animation: _scrollController,
                      builder: (context, child) {
                        final offset = _scrollController.hasClients
                            ? _scrollController.positions.first.pixels
                            : 0;
                        return Transform.translate(
                          offset: Offset(0, offset * 0.45),
                          child: Opacity(
                            opacity: (1 - (offset / 300)).clamp(0.0, 1.0),
                            child: child,
                          ),
                        );
                      },
                      child: RepaintBoundary(
                        child: (() {
                          final summary =
                              _portfolio?['summary'] as Map<String, dynamic>?;
                          return PortfolioHero(
                            totalInvested: _totalInvested,
                            wallet: _walletBalance,
                            irr: _irr,
                            activeCount:
                                (summary?['active_count'] as int?) ?? 0,
                            repaidCount:
                                (summary?['repaid_count'] as int?) ?? 0,
                            isBlackMode: isBlack,
                            onAdd: _showAddFundsSheet,
                            onWithdraw: _showWithdrawSheet,
                            onToggleHide: () {
                              AppHaptics.selection();
                              final p = ref.read(themeProvider);
                              p.setHideBalance(hide: !p.hideBalance);
                            },
                          );
                        })(),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: QuickActions(
                      isBlackMode: isBlack,
                      onAdd: _showAddFundsSheet,
                      onWithdraw: _showWithdrawSheet,
                      onMarketplace: () {
                        AppHaptics.selection();
                        Navigator.push(
                          context,
                          SmoothPageRoute(
                            builder: (_) => const MarketplaceScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (_activeInvestments.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Active Investments',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success(context).withValues(
                                alpha: isBlack ? 0.08 : 0.1,
                              ),
                              borderRadius: BorderRadius.circular(UI.radiusSm),
                            ),
                            child: Text(
                              '${_activeInvestments.length} active',
                              style: TextStyle(
                                color: AppColors.success(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 130,
                      child: ClipRect(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _activeInvestments.length,
                          itemBuilder: (ctx, i) => RepaintBoundary(
                            child: ActiveInvestmentCard(
                              investment:
                                  _activeInvestments[i] as Map<String, dynamic>,
                              index: i,
                              isBlackMode: isBlack,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                // ── Invoice Sections ──────────────────────────────────────────
                if (_unfundedInvoices.isNotEmpty) ...[
                  _buildSectionHeader(
                    context,
                    title: 'Unfunded Invoices',
                    onViewAll: () =>
                        Navigator.of(context, rootNavigator: true).push(
                      SmoothPageRoute(
                        builder: (_) => const MarketplaceScreen(),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => InvoiceCard(item: _unfundedInvoices[i]),
                        childCount: _unfundedInvoices.length,
                      ),
                    ),
                  ),
                  if (_isMoreInvoicesLoading)
                    SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: LoadingAnimationWidget.staggeredDotsWave(
                            color: colorScheme.primary,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    VoidCallback? onViewAll,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            if (onViewAll != null)
              TextButton(
                onPressed: () {
                  AppHaptics.selection();
                  onViewAll();
                },
                child: const Text('View All'),
              ),
          ],
        ),
      ),
    );
  }
}
