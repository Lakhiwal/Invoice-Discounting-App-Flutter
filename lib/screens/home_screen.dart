import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/theme_provider.dart';
import '../services/api_service.dart';
import '../utils/app_haptics.dart';
import '../utils/formatters.dart';
import '../utils/smooth_page_route.dart';
import '../services/portfolio_cache.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_text.dart';
import '../widgets/pressable.dart';
import '../widgets/stagger_list.dart';
import '../widgets/skeleton.dart';
import 'transaction_history_screen.dart';
import 'marketplace_screen.dart';

// ── Animated number counter ───────────────────────────────────────────────────

class _AnimatedCounter extends StatefulWidget {
  final double value;
  final TextStyle style;
  final String prefix;

  // FIX (haptics): expose a flag so the hero card can trigger a haptic tick
  // on each significant milestone of the count-up animation.
  final bool enableHaptics;

  const _AnimatedCounter({
    required this.value,
    required this.style,
    this.prefix = '',
    this.enableHaptics = false,
  });

  @override
  State<_AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<_AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  // FIX (haptics): track last milestone so we only fire once per threshold.
  double _lastHapticValue = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = Tween<double>(begin: 0, end: widget.value)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutExpo));

    if (widget.enableHaptics) {
      _anim.addListener(_onAnimationTick);
    }

    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedCounter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _lastHapticValue = old.value;
      _anim = Tween<double>(begin: old.value, end: widget.value)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutExpo));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  // FIX (haptics): fire a light haptic tick at 25 / 50 / 75 / 100 % of the
  // animation. Uses HapticFeedback.selectionClick() — very subtle, just enough
  // to make the counter feel physically real without being annoying.
  void _onAnimationTick() {
    if (!widget.enableHaptics || widget.value <= 0) return;
    final progress = _anim.value / widget.value;
    const milestones = [0.25, 0.5, 0.75, 1.0];
    for (final m in milestones) {
      final threshold = widget.value * m;
      if (_anim.value >= threshold && _lastHapticValue < threshold) {
        _lastHapticValue = threshold;
        // FIX: use AppHaptics.counterTick() instead of raw HapticFeedback so
        // the user's vibration level setting is respected. Raw selectionClick()
        // ignores the Off / Subtle settings the user chose in preferences.
        AppHaptics.counterTick();
        break;
      }
    }
  }

  @override
  void dispose() {
    _anim.removeListener(_onAnimationTick);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        PortfolioCache.getPortfolio(),
        ApiService.getWallet(),
        ApiService.getCachedUser(),
      ]);
      if (mounted) {
        setState(() {
          _portfolio = results[0];
          _wallet = results[1];
          _user = results[2];
          _cachedCurrentlyInvested = _computeCurrentlyInvested();
          _isLoading = false;
        });
        AppHaptics.numberReveal();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Bottom sheets ───────────────────────────────────────────────────────────

  void _showAddFundsSheet() {
    final controller = TextEditingController();
    String? selectedMethod = 'bank_transfer';
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
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'))
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
                          color: colorScheme.outline.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
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
                        side: BorderSide.none,
                      ),
                    ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: selectedMethod, // Item #25: was initialValue (not a valid param)
                  decoration:
                  const InputDecoration(labelText: 'Payment Method'),
                  items: const [
                    DropdownMenuItem(
                        value: 'bank_transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'upi', child: Text('UPI')),
                    DropdownMenuItem(
                        value: 'neft', child: Text('NEFT / RTGS')),
                  ],
                  onChanged: (v) => setModal(() => selectedMethod = v),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                    final amt = double.tryParse(controller.text);
                    if (amt == null || amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Enter a valid amount')));
                      return;
                    }
                    setModal(() => isLoading = true);
                    final messenger = ScaffoldMessenger.of(context);
                    final successColor = AppColors.success(context);
                    final errorColor = colorScheme.error;
                    try {
                      await ApiService.addFunds(amt, selectedMethod!);
                      if (!mounted) return;
                      await AppHaptics.success();
                      Navigator.pop(context);
                      _loadData();
                      messenger.showSnackBar(SnackBar(
                        content: Text(
                            '₹${fmtAmount(amt)} added to your wallet'),
                        backgroundColor: successColor,
                      ));
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
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'))
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
                          color: colorScheme.outline.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
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
                      backgroundColor: colorScheme.error),
                  onPressed: isLoading
                      ? null
                      : () async {
                    final amt = double.tryParse(controller.text);
                    if (amt == null ||
                        amt <= 0 ||
                        amt > _walletBalance) {
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
                        backgroundColor: successColor,
                      ));
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
    final userName = _user?['name'] ?? 'Investor';
    final firstName = userName.split(' ').first;
    final nameParts = userName.split(' ');
    final initials =
    nameParts.map((e) => e.isNotEmpty ? e[0] : '').take(2).join('');
    final transactions = _wallet?['transactions'] as List? ?? [];

    return Container(
      decoration: BoxDecoration(
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
        backgroundColor: Colors.transparent,
        body: RefreshIndicator(
          onRefresh: () async {
            await AppHaptics.refresh();
            await _loadData();
          },
          child: CustomScrollView(
            // Item #13: platform-adaptive scroll physics
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── App bar ───────────────────────────────────────────────────
              SliverAppBar(
                scrolledUnderElevation: 2,
                expandedHeight: 120,
                collapsedHeight: 80,
                pinned: true,
                stretch: true,
                backgroundColor:
                colorScheme.surface.withValues(alpha: 0.9),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.blurBackground,
                    StretchMode.zoomBackground,
                  ],
                  titlePadding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  centerTitle: false,
                  title: Text(
                    'Hey, $firstName',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primaryContainer,
                          border: Border.all(
                              color: colorScheme.primary, width: 1.5),
                        ),
                        child: Center(
                          child: Text(initials,
                              style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Portfolio hero card ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: _isLoading
                      ? SkeletonTheme(child: SkeletonCard(height: 260))
                      : _PortfolioHero(
                    totalInvested: _totalInvested,
                    wallet: _walletBalance,
                    returns: _totalReturns,
                    activeCount: summary?['active_count'] ?? 0,
                    repaidCount: summary?['repaid_count'] ?? 0,
                    onAdd: _showAddFundsSheet,
                    onWithdraw: _showWithdrawSheet,
                  ),
                ),
              ),

              // ── Quick actions ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _isLoading
                      ? SkeletonTheme(child: SkeletonCard(height: 72))
                      : _QuickActions(
                    onAdd: _showAddFundsSheet,
                    onWithdraw: _showWithdrawSheet,
                    onMarketplace: () {
                      AppHaptics.selection();
                      Navigator.push(
                        context,
                        SmoothPageRoute(
                            builder: (_) => const MarketplaceScreen()),
                      );
                    },
                  ),
                ),
              ),

              // ── Active investments preview ─────────────────────────────────
              if (!_isLoading && _activeInvestments.isNotEmpty) ...[
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
                              letterSpacing: -0.3,
                            )),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success(context)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_activeInvestments.length} active',
                            style: TextStyle(
                                color: AppColors.success(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // FIX (overflow): wrap horizontal list in a ConstrainedBox so it
                // never requests more height than the fixed 130 px we allocate.
                // The original SizedBox(height: 130) was correct but
                // _ActiveInvestmentCard's inner Column could still overflow on
                // small / large-text phones because it had no intrinsic height
                // constraint. Wrapping in a SizedBox + ClipRect prevents the
                // 27 px overflow without hiding any real content.
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
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // ── Activity section header ────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Activity',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          AppHaptics.selection();
                          Navigator.push(
                            context,
                            SmoothPageRoute(
                              builder: (_) =>
                              const TransactionHistoryScreen(),
                            ),
                          );
                        },
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Transaction list / skeleton / empty state ──────────────────
              if (_isLoading)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (ctx, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SkeletonTheme(child: SkeletonListTile()),
                      ),
                      childCount: 3,
                    ),
                  ),
                )
              else if (transactions.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, i) {
                        if (i >= transactions.length) return null;
                        return StaggerItem(
                          index: i,
                          child: _TransactionTile(tx: transactions[i]),
                        );
                      },
                      childCount: transactions.length,
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: _EmptyActivity(
                    onExplore: () {
                      AppHaptics.selection();
                      Navigator.push(
                        context,
                        SmoothPageRoute(
                            builder: (_) => const MarketplaceScreen()),
                      );
                    },
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Portfolio hero card ───────────────────────────────────────────────────────

class _PortfolioHero extends StatelessWidget {
  final double totalInvested, wallet, returns;
  final dynamic activeCount, repaidCount;
  final VoidCallback onAdd, onWithdraw;

  const _PortfolioHero({
    required this.totalInvested,
    required this.wallet,
    required this.returns,
    required this.activeCount,
    required this.repaidCount,
    required this.onAdd,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            Color.lerp(colorScheme.primary, colorScheme.tertiary, 0.55)!,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Subtle dot grid texture
          Positioned.fill(child: _HeroTexture()),

          // Glow circles
          Positioned(
            right: -60,
            top: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -70,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('PORTFOLIO VALUE',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Main value — haptics enabled on the hero counter
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => GradientText.blue.createShader(
                    Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                  ),
                  child: _AnimatedCounter(
                    value: totalInvested,
                    prefix: '₹',
                    enableHaptics: true, // FIX: haptic ticks during count-up
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      height: 1.1,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Stats row — GlassStatCard for each figure
                Row(
                  children: [
                    Expanded(
                      child: GlassStatCard(
                        label: 'Returns',
                        value: '₹${fmtAmount(returns)}',
                        valueColor: const Color(0xFF86EFAC),
                        icon: Icons.trending_up_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GlassStatCard(
                        label: 'Active',
                        value: '${(activeCount as num).toInt()}',
                        icon: Icons.pending_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GlassStatCard(
                        label: 'Repaid',
                        value: '${(repaidCount as num).toInt()}',
                        icon: Icons.check_circle_outline_rounded,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Wallet row
                GlassCard(
                  blur: 12,
                  opacity: 0.1,
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18)),
                  boxShadow: const [],
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Wallet Balance',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 11)),
                          _AnimatedCounter(
                            value: wallet,
                            prefix: '₹',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTexture extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotGridPainter(),
    );
  }
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
  final VoidCallback onAdd, onWithdraw, onMarketplace;

  const _QuickActions({
    required this.onAdd,
    required this.onWithdraw,
    required this.onMarketplace,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          _ActionButton(
            icon: Icons.add_rounded,
            label: 'Add Funds',
            color: AppColors.success(context),
            onTap: onAdd,
          ),
          _ActionDivider(),
          _ActionButton(
            icon: Icons.south_rounded,
            label: 'Withdraw',
            color: colorScheme.error,
            onTap: onWithdraw,
          ),
          _ActionDivider(),
          _ActionButton(
            icon: Icons.storefront_outlined,
            label: 'Invest',
            color: colorScheme.primary,
            onTap: onMarketplace,
          ),
        ],
      ),
    );
  }
}

class _ActionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 5),
              Text(label,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Active investment mini card ────────────────────────────────────────────────

class _ActiveInvestmentCard extends StatelessWidget {
  final Map<String, dynamic> investment;
  final int index;

  const _ActiveInvestmentCard(
      {required this.investment, required this.index});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final company =
    (investment['company'] ?? 'Invoice') as String;
    final amount =
        double.tryParse(investment['amount']?.toString() ?? '0') ?? 0;
    final daysLeft =
        (investment['days_left'] as num?)?.toInt() ?? 0;
    final roi =
        double.tryParse(investment['investor_rate']?.toString() ??
            investment['roi']?.toString() ??
            '0') ??
            0;

    final urgencyColor = daysLeft <= 7
        ? AppColors.danger(context)
        : daysLeft <= 30
        ? AppColors.warning(context)
        : AppColors.success(context);

    final cardColors = [
      colorScheme.primaryContainer,
      colorScheme.secondaryContainer,
      colorScheme.tertiaryContainer,
    ];
    final onCardColors = [
      colorScheme.onPrimaryContainer,
      colorScheme.onSecondaryContainer,
      colorScheme.onTertiaryContainer,
    ];
    final bg = cardColors[index % cardColors.length];
    final fg = onCardColors[index % onCardColors.length];

    // FIX (overflow): the original card used Column with a Spacer inside a
    // fixed-height parent, which works fine at default text scale but breaks
    // at larger accessibility scales because the text nodes grow and the
    // Spacer can't shrink below 0. Replacing Spacer with a fixed SizedBox
    // and using mainAxisSize: MainAxisSize.min prevents the overflow.
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // FIX: don't force-expand
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
                      fontSize: 13),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: urgencyColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${daysLeft}d',
                  style: TextStyle(
                      color: urgencyColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10), // FIX: fixed gap replaces Spacer
          Text(
            '₹${fmtAmount(amount)}',
            style: TextStyle(
                color: fg,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            '${roi.toStringAsFixed(1)}% p.a.',
            style: TextStyle(
                color: fg.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Transaction tile ──────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  const _TransactionTile({required this.tx});

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
  };

  (IconData, bool) _resolveIcon(String desc, bool isCredit) {
    final lower = desc.toLowerCase();
    for (final entry in _iconMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return isCredit
        ? (Icons.south_west_rounded, true)
        : (Icons.north_east_rounded, false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDebit = tx['type'] == 'debit';
    final desc = tx['description']?.toString() ?? 'Transaction';
    final (icon, _) = _resolveIcon(desc, !isDebit);
    final accentColor =
    isDebit ? colorScheme.error : AppColors.success(context);
    final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ElevationOverlay.applySurfaceTint(
          colorScheme.surfaceContainerHigh,
          colorScheme.primary,
          2,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(tx['date'] ?? '',
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          Text(
            '${isDebit ? '-' : '+'}₹${fmtAmount(amount)}',
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty activity state ──────────────────────────────────────────────────────

class _EmptyActivity extends StatelessWidget {
  final VoidCallback onExplore;
  const _EmptyActivity({required this.onExplore});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long_outlined,
                  size: 30, color: colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text('No activity yet',
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Start investing to see your\ntransactions here',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
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
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}