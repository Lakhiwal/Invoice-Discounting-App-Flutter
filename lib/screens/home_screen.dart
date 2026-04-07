import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:invoice_discounting_app/screens/payment_status_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import '../services/cashfree_service.dart';
import '../services/portfolio_cache.dart';
import '../utils/app_haptics.dart';
import '../utils/formatters.dart';
import '../utils/smooth_page_route.dart';
import '../theme/theme_provider.dart';
import '../widgets/vibe_state_wrapper.dart';
import '../widgets/app_bar_action.dart';
import '../widgets/app_logo_header.dart';
import '../widgets/liquidity_refresh_indicator.dart';
import 'marketplace_screen.dart';
import 'transaction_history_screen.dart';
import '../widgets/home/portfolio_hero.dart';
import '../widgets/home/quick_actions.dart';
import '../widgets/home/active_investment_card.dart';
import '../widgets/home/transaction_activity.dart';
import '../widgets/skeleton.dart';
import '../theme/ui_constants.dart';

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


  double get _walletBalance =>
      double.tryParse(_wallet?['balance']?.toString() ?? '0') ?? 0;
  double get _totalInvested =>
      double.tryParse(
          _portfolio?['summary']?['total_invested']?.toString() ?? '0') ??
      0;
  double get _totalReturns =>
      double.tryParse(
          _portfolio?['summary']?['total_returns']?.toString() ?? '0') ??
      0;
  List get _activeInvestments => _portfolio?['active'] as List? ?? [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _cashfree = CashfreeService();
    _loadData();
  }

  @override
  void dispose() {
    _cashfree.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> _waitForWalletUpdate({int maxRetries = 10}) async {
    final initialBalance = _walletBalance;
    for (int i = 0; i < maxRetries; i++) {
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
      ]);

      // Ensure the "Syncing" state is visible for a premium feel
      if (forceRefresh) {
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        if (elapsed < 800) {
          await Future.delayed(Duration(milliseconds: 800 - elapsed));
        }
      }

      if (mounted) {
        setState(() {
          _portfolio = results[0];
          _wallet = results[1];
          _isLoading = false;
        });
        AppHaptics.numberReveal();
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
    bool isLoading = false;
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(UI.lg, 8, UI.lg, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add Funds',
                    style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text('Instant credit to your investing wallet',
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant, fontSize: 14)),
                const SizedBox(height: 28),
                TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                  ],
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w800),
                    hintText: '0.00',
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(UI.radiusLg),
                        borderSide: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.3))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(UI.radiusLg),
                        borderSide: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.3))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(UI.radiusLg),
                        borderSide:
                            BorderSide(color: colorScheme.primary, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['1000', '5000', '10000', '25000', '50000']
                        .map((amt) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                  label: Text('₹$amt'),
                                  onPressed: () {
                                    AppHaptics.selection();
                                    controller.text = amt;
                                  },
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  backgroundColor:
                                      colorScheme.surfaceContainerHigh,
                                  side: BorderSide.none),
                            ))
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
                                        'Maximum ₹50,000 allowed per transaction')));
                            return;
                          }

                          final result = await ApiService.createCashfreeOrder(amt);

                          if (!mounted) return;
                          final messenger = ScaffoldMessenger.of(context);

                          if (result['error'] != null && result['success'] == false) {
                            setModal(() => isLoading = false);
                            messenger.showSnackBar(
                                SnackBar(content: Text(result['error'])));
                            return;
                          }

                          final orderId = result['order_id'] as String;
                          final sessionId = result['payment_session_id'] as String;
                          final env = result['environment'] as String? ?? 'SANDBOX';

                          final homeNavigator = Navigator.of(context);

                          _cashfree.onSuccess = (cfOrderId) async {
                            if (!mounted) return;
                            homeNavigator.pop(); // close bottom sheet
                            homeNavigator.push(
                              MaterialPageRoute(
                                builder: (_) => const PaymentStatusScreen(
                                  status: PaymentStatus.processing,
                                ),
                              ),
                            );

                            final verifyResult = await ApiService.verifyCashfreePayment(
                              orderId: orderId,
                            );

                            if (!mounted) return;

                            final paymentStatus = verifyResult['status'];

                            if (paymentStatus == 'completed') {
                              homeNavigator.pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => PaymentStatusScreen(
                                    status: PaymentStatus.success,
                                    onDismiss: () => _loadData(),
                                  ),
                                ),
                              );
                            } else if (paymentStatus == 'pending') {
                              final walletUpdated = await _waitForWalletUpdate(maxRetries: 8);
                              if (!mounted) return;
                              homeNavigator.pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => PaymentStatusScreen(
                                    status: walletUpdated
                                        ? PaymentStatus.success
                                        : PaymentStatus.success,
                                    onDismiss: () => _loadData(),
                                  ),
                                ),
                              );
                            } else {
                              homeNavigator.pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => PaymentStatusScreen(
                                    status: PaymentStatus.failed,
                                    onDismiss: () => _loadData(),
                                  ),
                                ),
                              );
                            }
                          };

                          _cashfree.onError = (error) {
                            if (!mounted) return;
                            try { homeNavigator.pop(); } catch (_) {}
                            homeNavigator.push(
                              MaterialPageRoute(
                                builder: (_) => PaymentStatusScreen(
                                  status: PaymentStatus.failed,
                                  onDismiss: () => _loadData(),
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
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 3, color: Colors.white))
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
    bool isLoading = false;
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Withdraw',
                    style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text('Available: ₹${fmtAmount(_walletBalance)}',
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant, fontSize: 14)),
                const SizedBox(height: 28),
                TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                  ],
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(
                        color: colorScheme.error, fontWeight: FontWeight.w800),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.3))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.3))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: colorScheme.error, width: 1.5)),
                  ),
                ),
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: () {
                          AppHaptics.selection();
                          controller.text = _walletBalance.toStringAsFixed(2);
                        },
                        child: const Text('Withdraw All'))),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final amt = double.tryParse(controller.text);
                          if (amt == null || amt <= 0 || amt > _walletBalance) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Invalid amount or insufficient balance')));
                            return;
                          }
                          setModal(() => isLoading = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final successColor = AppColors.success(context);
                          final errorColor = colorScheme.error;
                          try {
                            await ApiService.withdrawFunds(amt);
                            if (!mounted) return;
                            await AppHaptics.success();
                            Navigator.pop(context);
                            _loadData();
                            messenger.showSnackBar(SnackBar(
                                content: Text(
                                    '₹${fmtAmount(amt)} withdrawn successfully'),
                                backgroundColor: successColor));
                          } catch (e) {
                            if (!mounted) return;
                            setModal(() => isLoading = false);
                            await AppHaptics.error();
                            messenger.showSnackBar(SnackBar(
                                content: Text('Failed: $e'),
                                backgroundColor: errorColor));
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 3, color: Colors.white))
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
              gradient: LinearGradient(colors: [
                colorScheme.surface,
                colorScheme.surfaceContainerLow,
                colorScheme.surface
              ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
      child: Scaffold(
        backgroundColor: isBlack ? colorScheme.surface : Colors.transparent,
        body: LiquidityRefreshIndicator(
          onRefresh: () => _loadData(forceRefresh: true),
          color: colorScheme.primary,
          child: VibeStateWrapper(
            state: _isLoading
                ? VibeState.loading
                : (_hasError ? VibeState.error : VibeState.success),
            loadingSkeleton: const SkeletonHomeContent(),
            onRetry: () => _loadData(forceRefresh: true),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              slivers: [
                const AppLogoHeader(
                  title: 'Home',
                  actions: [
                    AppBarActions(),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: AnimatedBuilder(
                      animation: _scrollController,
                      builder: (context, child) {
                        final double offset = _scrollController.hasClients
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
                        child: PortfolioHero(
                          totalInvested: _totalInvested,
                          wallet: _walletBalance,
                          returns: _totalReturns,
                          activeCount: summary?['active_count'] ?? 0,
                          repaidCount: summary?['repaid_count'] ?? 0,
                          isBlackMode: isBlack,
                          onAdd: _showAddFundsSheet,
                          onWithdraw: _showWithdrawSheet,
                          onToggleHide: () {
                            AppHaptics.selection();
                            final p = ref.read(themeProvider);
                            p.setHideBalance(!p.hideBalance);
                          },
                        ),
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
                                    builder: (_) => const MarketplaceScreen()));
                          })),
                ),
                if (_activeInvestments.isNotEmpty) ...[
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Active Investments',
                                    style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3)),
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: AppColors.success(context)
                                            .withValues(
                                                alpha: isBlack ? 0.08 : 0.1),
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    child: Text(
                                        '${_activeInvestments.length} active',
                                        style: TextStyle(
                                            color: AppColors.success(context),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700))),
                              ]))),
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
                                investment: _activeInvestments[i],
                                index: i,
                                isBlackMode: isBlack),
                          ),
                        ))),
                  ),
                ],
                SliverToBoxAdapter(
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Recent Activity',
                                  style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3)),
                              TextButton(
                                onPressed: () async {
                                  AppHaptics.selection();
                                  final result = await Navigator.push(
                                    context,
                                    SmoothPageRoute(
                                      builder: (_) =>
                                          const TransactionHistoryScreen(),
                                    ),
                                  );
                                  if (result is RetryPaymentRequest &&
                                      mounted) {
                                    _showAddFundsSheet(
                                        prefillAmount: result.amount);
                                  }
                                },
                                child: const Text('View All'),
                              ),
                            ]))),
                // ── Transaction list with dividers ──────────────────
                if (transactions.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final int itemIndex = i ~/ 2;
                          if (i >= transactions.length * 2 - 1) return null;

                          if (i.isOdd) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 54),
                              child: Divider(
                                color: dividerColor,
                                height: 0.5,
                                thickness: 0.5,
                              ),
                            );
                          }

                          return TransactionActivityTile(tx: transactions[itemIndex]);
                        },
                        childCount: transactions.isEmpty ? 0 : transactions.length * 2 - 1,
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: EmptyActivityPlaceholder(
                      isBlackMode: isBlack,
                      onExplore: () {
                        AppHaptics.selection();
                        Navigator.push(
                          context,
                          SmoothPageRoute(builder: (_) => const MarketplaceScreen()),
                        );
                      },
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ),
      ),
    );
  }


}