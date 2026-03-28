import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:invoice_discounting_app/screens/payment_status_screen.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/cashfree_service.dart';
import '../services/portfolio_cache.dart';
import '../services/razorpay_service.dart';
import '../theme/theme_provider.dart';
import '../utils/app_haptics.dart';
import '../utils/formatters.dart';
import '../utils/smooth_page_route.dart';
import '../widgets/app_bar_action.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_text.dart';
import '../widgets/pressable.dart';
import '../widgets/skeleton.dart';
import '../widgets/stagger_list.dart';
import 'invoice_detail_screen.dart';
import 'marketplace_screen.dart';
import 'transaction_history_screen.dart';

const String _kMasked = '● ● ● ● ●';
const String _kMaskedShort = '● ● ●';

// ── Animated number counter ───────────────────────────────────────────────────

class _AnimatedCounter extends StatefulWidget {
  final double value;
  final TextStyle style;
  final String prefix;
  final bool enableHaptics;
  final bool hideValue;
  final VoidCallback? onCompleted;

  const _AnimatedCounter({
    required this.value,
    required this.style,
    this.prefix = '',
    this.enableHaptics = false,
    this.hideValue = false,
    this.onCompleted,
  });

  @override
  State<_AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<_AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _anim = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutExpo),
    );
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (widget.enableHaptics) AppHaptics.counterTick();
        widget.onCompleted?.call();
      }
    });
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedCounter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _anim = Tween<double>(begin: old.value, end: widget.value).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutExpo),
      );
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hideValue) {
      return Text(
        '${widget.prefix}$_kMasked',
        style: widget.style.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Text(
        '${widget.prefix}${fmtAmount(_anim.value)}',
        style: widget.style.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _portfolio;
  Map<String, dynamic>? _wallet;
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _hasError = false;
  late RazorpayService _razorpay;
  late CashfreeService _cashfree;
  double _cachedCurrentlyInvested = 0;

  double _computeCurrentlyInvested() {
    final active = _portfolio?['active'] as List? ?? [];
    double total = 0;
    for (final inv in active) {
      total += double.tryParse(inv['amount'].toString()) ?? 0;
    }
    return total;
  }

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
    // _razorpay = RazorpayService();
    _cashfree = CashfreeService();
    _loadData();
  }

  @override
  void dispose() {
    // _razorpay.dispose();
    _cashfree.dispose();
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

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final results = await Future.wait([
        PortfolioCache.getPortfolio(),
        ApiService.getWallet(),
        ApiService.getCachedUser(),
        ApiService.getProfile(),
      ]);

      if (mounted) {
        setState(() {
          _portfolio = results[0];
          _wallet = results[1];
          _user = (results[3] ?? results[2]);
          _cachedCurrentlyInvested = _computeCurrentlyInvested();
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
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
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

                          if (result['error'] != null && result['success'] == false) {
                            setModal(() => isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(result['error'])));
                            return;
                          }

                          final orderId = result['order_id'] as String;
                          final sessionId = result['payment_session_id'] as String;
                          final env = result['environment'] as String? ?? 'SANDBOX';

                          final homeNavigator = Navigator.of(this.context);

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
    final themeProvider = context.watch<ThemeProvider>();
    final hideBalance = themeProvider.hideBalance;
    final isBlack = themeProvider.isBlackMode;

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
        body: RefreshIndicator(
          onRefresh: () async {
            await AppHaptics.selection();
            await _loadData();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              SliverAppBar(
                scrolledUnderElevation: 0,
                toolbarHeight: 72,
                pinned: true,
                backgroundColor: colorScheme.surface,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                titleSpacing: 20,
                title: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset('assets/icon/app_icon.png'),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Home',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                actions: const [
                  AppBarActions(),
                ],
              ),
              if (_hasError && !_isLoading)
                SliverFillRemaining(
                  child: Center(
                      child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 48),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.wifi_off_rounded,
                                    size: 48,
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.4)),
                                const SizedBox(height: 16),
                                Text('Couldn\'t load your data',
                                    style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                Text('Check your connection and try again.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 13)),
                                const SizedBox(height: 20),
                                TextButton.icon(
                                    onPressed: _loadData,
                                    icon: const Icon(Icons.refresh_rounded,
                                        size: 16),
                                    label: const Text('Retry')),
                              ]))),
                ),
              if (_isLoading)
                SliverToBoxAdapter(child: const SkeletonHomeContent()),
              if (!_isLoading && !_hasError) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Semantics(
                      label:
                          'Portfolio value: ${fmtAmount(_totalInvested)} rupees. ${fmtAmount(_totalReturns)} in returns. ${summary?['active_count'] ?? 0} active investments.',
                      child: _PortfolioHero(
                        totalInvested: _totalInvested,
                        wallet: _walletBalance,
                        returns: _totalReturns,
                        activeCount: summary?['active_count'] ?? 0,
                        repaidCount: summary?['repaid_count'] ?? 0,
                        hideBalance: hideBalance,
                        isBlackMode: isBlack,
                        onAdd: _showAddFundsSheet,
                        onWithdraw: _showWithdrawSheet,
                        onToggleHide: () {
                          AppHaptics.selection();
                          themeProvider.setHideBalance(!hideBalance);
                        },
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _QuickActions(
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
                          itemBuilder: (ctx, i) => _ActiveInvestmentCard(
                              investment: _activeInvestments[i],
                              index: i,
                              hideBalance: hideBalance,
                              isBlackMode: isBlack),
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
                        if (i >= transactions.length * 2 - 1) return null;

                        // Even indices = tiles, odd indices = dividers
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

                        final txIndex = i ~/ 2;
                        return RepaintBoundary(
                            child: StaggerItem(
                                index: txIndex,
                                child: _TransactionTile(
                                    tx: transactions[txIndex],
                                    hideBalance: hideBalance)));
                      },
                      childCount: transactions.length * 2 - 1,
                    )),
                  )
                else
                  SliverToBoxAdapter(
                      child: _EmptyActivity(
                          isBlackMode: isBlack,
                          onExplore: () {
                            AppHaptics.selection();
                            Navigator.push(
                                context,
                                SmoothPageRoute(
                                    builder: (_) => const MarketplaceScreen()));
                          })),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Portfolio hero card ───────────────────────────────────────────────────────

class _PortfolioHero extends StatefulWidget {
  final double totalInvested, wallet, returns;
  final dynamic activeCount, repaidCount;
  final bool hideBalance;
  final bool isBlackMode;
  final VoidCallback onAdd, onWithdraw, onToggleHide;

  const _PortfolioHero({
    required this.totalInvested,
    required this.wallet,
    required this.returns,
    required this.activeCount,
    required this.repaidCount,
    required this.hideBalance,
    required this.isBlackMode,
    required this.onAdd,
    required this.onWithdraw,
    required this.onToggleHide,
  });

  @override
  State<_PortfolioHero> createState() => _PortfolioHeroState();
}

class _PortfolioHeroState extends State<_PortfolioHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _scale = Tween<double>(begin: 1.0, end: 1.025).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOutBack));
  }

  Future<void> pulse() async {
    AppHaptics.selection();
    await _pulseCtrl.forward();
    await _pulseCtrl.reverse();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hide = widget.hideBalance;
    final isBlack = widget.isBlackMode;

    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: isBlack
          ? _buildBlackHero(colorScheme, hide)
          : _buildDarkHero(colorScheme, hide),
    );
  }

  Widget _buildBlackHero(ColorScheme colorScheme, bool hide) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6)),
              child: Text('PORTFOLIO VALUE',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0)),
            ),
            GestureDetector(
              onTap: widget.onToggleHide,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle),
                child: Icon(
                    hide
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 16),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          _AnimatedCounter(
            value: widget.totalInvested,
            prefix: '₹',
            enableHaptics: true,
            hideValue: hide,
            onCompleted: pulse,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
                height: 1.1),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: _BlackStatCard(
                    label: 'Returns',
                    value: hide
                        ? '₹$_kMaskedShort'
                        : '₹${fmtAmount(widget.returns)}',
                    valueColor: const Color(0xFF10B981))),
            const SizedBox(width: 6),
            Expanded(
                child: _BlackStatCard(
                    label: 'Active',
                    value: '${(widget.activeCount as num).toInt()}')),
            const SizedBox(width: 6),
            Expanded(
                child: _BlackStatCard(
                    label: 'Repaid',
                    value: '${(widget.repaidCount as num).toInt()}')),
          ]),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(children: [
              Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.white.withValues(alpha: 0.35), size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Wallet Balance',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 11)),
                    _AnimatedCounter(
                        value: widget.wallet,
                        prefix: '₹',
                        hideValue: hide,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                  ])),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildDarkHero(ColorScheme colorScheme, bool hide) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colorScheme.primaryFixedDim, colorScheme.primaryFixed]),
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(child: _HeroTexture()),
        Positioned(
            right: -60,
            top: -60,
            child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06)))),
        Positioned(
            left: -40,
            bottom: -70,
            child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04)))),
        Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('PORTFOLIO VALUE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0)),
              ),
              GestureDetector(
                onTap: widget.onToggleHide,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle),
                  child: Icon(
                      hide
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.white70,
                      size: 16),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => GradientText.blue.createShader(
                  Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
              child: _AnimatedCounter(
                value: widget.totalInvested,
                prefix: '₹',
                enableHaptics: true,
                hideValue: hide,
                onCompleted: pulse,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                    height: 1.1),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                  child: GlassStatCard(
                      label: 'Returns',
                      value: hide
                          ? '₹$_kMaskedShort'
                          : '₹${fmtAmount(widget.returns)}',
                      valueColor: const Color(0xFF22C55E),
                      icon: Icons.trending_up_rounded)),
              const SizedBox(width: 8),
              Expanded(
                  child: GlassStatCard(
                      label: 'Active',
                      value: '${(widget.activeCount as num).toInt()}',
                      icon: Icons.pending_outlined)),
              const SizedBox(width: 8),
              Expanded(
                  child: GlassStatCard(
                      label: 'Repaid',
                      value: '${(widget.repaidCount as num).toInt()}',
                      icon: Icons.check_circle_outline_rounded)),
            ]),
            const SizedBox(height: 20),
            GlassCard(
              blur: 12,
              opacity: 0.1,
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              boxShadow: const [],
              child: Row(children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Wallet Balance',
                          style:
                              TextStyle(color: Colors.white60, fontSize: 11)),
                      _AnimatedCounter(
                          value: widget.wallet,
                          prefix: '₹',
                          hideValue: hide,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                    ])),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _BlackStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _BlackStatCard(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
      ]),
    );
  }
}

class _HeroTexture extends StatelessWidget {
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DotGridPainter());
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..style = PaintingStyle.fill;
    const spacing = 22.0;
    const radius = 1.2;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => false;
}

// ── Quick actions row ─────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final bool isBlackMode;
  final VoidCallback onAdd, onWithdraw, onMarketplace;

  const _QuickActions(
      {required this.isBlackMode,
      required this.onAdd,
      required this.onWithdraw,
      required this.onMarketplace});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
          color:
              isBlackMode ? Colors.transparent : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: colorScheme.outlineVariant
                  .withValues(alpha: isBlackMode ? 0.06 : 0.3))),
      child: Row(children: [
        _ActionButton(
            icon: Icons.add_rounded,
            label: 'Add Funds',
            color: AppColors.success(context),
            onTap: onAdd),
        _ActionDivider(),
        _ActionButton(
            icon: Icons.south_rounded,
            label: 'Withdraw',
            color: colorScheme.error,
            onTap: onWithdraw),
        _ActionDivider(),
        _ActionButton(
            icon: Icons.storefront_outlined,
            label: 'Invest',
            color: colorScheme.primary,
            onTap: onMarketplace),
      ]),
    );
  }
}

class _ActionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 1,
      height: 36,
      color:
          Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4));
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: Pressable(
            onTap: onTap,
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(icon, color: color, size: 18)),
                  const SizedBox(height: 5),
                  Text(label,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ]))));
  }
}

// ── Active investment mini card ────────────────────────────────────────────────

class _ActiveInvestmentCard extends StatelessWidget {
  final Map<String, dynamic> investment;
  final int index;
  final bool hideBalance;
  final bool isBlackMode;

  const _ActiveInvestmentCard({
    required this.investment,
    required this.index,
    this.hideBalance = false,
    this.isBlackMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final company = (investment['company'] ?? 'Invoice') as String;
    final amount =
        double.tryParse(investment['amount']?.toString() ?? '0') ?? 0;
    final daysLeft = (investment['days_left'] as num?)?.toInt() ?? 0;
    final roi = double.tryParse(investment['investor_rate']?.toString() ??
            investment['roi']?.toString() ??
            '0') ??
        0;
    final invoiceId = investment['invoice_id']?.toString() ?? '0';

    final remainingAmount = amount;
    final fundingPct = 100.0;
    final tenureDays = daysLeft;

    final urgencyColor = daysLeft <= 7
        ? AppColors.danger(context)
        : daysLeft <= 30
            ? AppColors.warning(context)
            : AppColors.success(context);

    // Consistent card color — no alternating
    final bg = isBlackMode
        ? const Color(0xFF0A0A0A)
        : colorScheme.surfaceContainerHigh;
    final fg = colorScheme.onSurface;

    final invoiceItem = InvoiceItem(
      id: invoiceId,
      company: company,
      particular: '',
      debtor: '',
      status: 'active',
      statusDisplay: 'Active',
      roi: roi,
      daysLeft: daysLeft,
      tenureDays: tenureDays,
      remainingAmount: remainingAmount,
      fundingPct: fundingPct,
      roiDisplay: '${roi.toStringAsFixed(1)}%',
      daysLeftDisplay: '${daysLeft}d left',
      tenureDisplay: '${tenureDays}d',
      remainingDisplay: '₹${fmtAmount(remainingAmount)}',
      fundingDisplay: '${fundingPct.toStringAsFixed(1)}%',
    );

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      child: Pressable(
        onTap: () async {
          await AppHaptics.selection();
          if (!context.mounted) return;
          Navigator.push(
            context,
            SmoothPageRoute(
              builder: (_) => InvoiceDetailScreen(item: invoiceItem),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(
                color: colorScheme.primary
                    .withValues(alpha: isBlackMode ? 0.5 : 0.7),
                width: 2.5,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: urgencyColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${daysLeft}d',
                      style: TextStyle(
                        color: urgencyColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                hideBalance ? '₹$_kMasked' : '₹${fmtAmount(amount)}',
                style: TextStyle(
                  color: fg,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${roi.toStringAsFixed(1)}% p.a.',
                style: TextStyle(
                  color: fg.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Transaction tile — flat, no card border ──────────────────────────────────

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  final bool hideBalance;

  const _TransactionTile({
    required this.tx,
    this.hideBalance = false,
  });

  static const _iconMap = {
    'invest': (Icons.trending_up_rounded, false),
    'investment': (Icons.trending_up_rounded, false),
    'return': (Icons.receipt_long_outlined, true),
    'repay': (Icons.receipt_long_outlined, true),
    'settlement': (Icons.receipt_long_outlined, true),
    'withdraw': (Icons.south_rounded, false),
    'add': (Icons.north_rounded, true),
    'deposit': (Icons.north_rounded, true),
    'credit': (Icons.north_rounded, true),
    'top-up': (Icons.north_rounded, true),
    'failed': (Icons.error_outline_rounded, false),
    'expired': (Icons.timer_off_rounded, false),
  };

  (IconData, bool) _resolveIcon(String desc, String status, bool isCredit) {
    if (status == 'failed') return (Icons.error_outline_rounded, false);
    if (status == 'expired') return (Icons.timer_off_rounded, false);

    final lower = desc.toLowerCase();
    for (final entry in _iconMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return isCredit
        ? (Icons.south_west_rounded, true)
        : (Icons.north_east_rounded, false);
  }

  /// Parse settlement description to extract interest amount.
  /// Backend format: "Settlement — INV-001 | Principal ₹50000.00 + Interest ₹1200.00"
  static ({String title, String? interestLabel}) _parseSettlement(String desc) {
    if (!desc.toLowerCase().startsWith('settlement')) {
      return (title: desc, interestLabel: null);
    }
    // Clean title: show just "Settlement — INV-001"
    final pipeIdx = desc.indexOf('|');
    final title = pipeIdx > 0 ? desc.substring(0, pipeIdx).trim() : desc;
    // Extract interest value after "Interest ₹"
    final match = RegExp(r'Interest\s*₹?([\d,.]+)').firstMatch(desc);
    if (match != null) {
      final val = double.tryParse(match.group(1)!.replaceAll(',', ''));
      if (val != null && val > 0) {
        return (title: title, interestLabel: '+₹${fmtAmount(val)} earned');
      }
    }
    return (title: title, interestLabel: null);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDebit = tx['type'] == 'debit';
    final desc = tx['description']?.toString() ?? 'Transaction';
    final txStatus = tx['status']?.toString() ?? 'completed';
    final isFailed = txStatus == 'failed' || txStatus == 'expired';
    final (icon, _) = _resolveIcon(desc, txStatus, !isDebit);
    final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;

    // Parse settlement for cleaner display
    final parsed = _parseSettlement(desc);

    final Color accentColor;
    if (isFailed) {
      accentColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
    } else {
      accentColor = isDebit ? colorScheme.error : AppColors.success(context);
    }

    return GestureDetector(
      onTap: null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: accentColor, size: 18)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(parsed.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: isFailed
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        decoration: isFailed
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.4))),
                const SizedBox(height: 2),
                Row(children: [
                  Text(tx['date'] ?? '',
                      style: TextStyle(
                          color: colorScheme.onSurfaceVariant, fontSize: 12)),
                  // Interest earned badge for settlements
                  if (parsed.interestLabel != null &&
                      !isFailed &&
                      !hideBalance) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color:
                            AppColors.success(context).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(parsed.interestLabel!,
                          style: TextStyle(
                              color: AppColors.success(context),
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                  if (isFailed) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
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
              ])),
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
                decoration:
                    isFailed ? TextDecoration.lineThrough : TextDecoration.none,
                decorationColor:
                    colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ]),
      ),
    );
  }
}

// ── Empty activity state ──────────────────────────────────────────────────────

class _EmptyActivity extends StatelessWidget {
  final bool isBlackMode;
  final VoidCallback onExplore;
  const _EmptyActivity({this.isBlackMode = false, required this.onExplore});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
            color: isBlackMode
                ? const Color(0xFF0A0A0A)
                : colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: colorScheme.outlineVariant
                    .withValues(alpha: isBlackMode ? 0.06 : 0.3))),
        child: Column(children: [
          Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle),
              child: Icon(Icons.receipt_long_outlined,
                  size: 30, color: colorScheme.primary)),
          const SizedBox(height: 16),
          Text('No activity yet',
              style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Start investing to see your\ntransactions here',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 20),
          SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onExplore,
                icon: const Icon(Icons.storefront_outlined, size: 16),
                label: const Text('Explore Marketplace'),
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colorScheme.primary),
                    foregroundColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              )),
        ]),
      ),
    );
  }
}