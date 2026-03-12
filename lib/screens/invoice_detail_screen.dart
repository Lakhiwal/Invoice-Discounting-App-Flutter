import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../services/api_service.dart';
import '../services/portfolio_cache.dart';
import '../theme/theme_provider.dart';
import '../theme/ui_constants.dart';
import '../utils/app_haptics.dart';
import '../utils/formatters.dart';
import '../widgets/pressable.dart';
import 'investment_calculator.dart';
import 'marketplace_screen.dart' show InvoiceItem;

class InvoiceDetailScreen extends StatefulWidget {
  final InvoiceItem item;

  const InvoiceDetailScreen({super.key, required this.item});

  factory InvoiceDetailScreen.fromMap(Map<String, dynamic> invoice) =>
      InvoiceDetailScreen(item: InvoiceItem.fromMap(invoice));

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _isInvesting = false;
  bool _isSuccess = false;
  String? _message;
  double? _walletBalance;
  // Item #20: changed from static to instance to prevent stale cache across screens
  // TODO: migrate to a shared WalletService/provider for app-wide caching
  double? _cachedWalletBalance;

  // FIX (UX): success state uses a dedicated animation so the CTA
  // morphs into a checkmark rather than just disabling with grey text.
  late final AnimationController _successCtrl;
  late final Animation<double> _successScale;

  InvoiceItem get _item => widget.item;

  @override
  void initState() {
    super.initState();
    _loadWallet();

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _successScale = CurvedAnimation(
      parent: _successCtrl,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _successCtrl.dispose();
    super.dispose();
  }

  void _openCalculator() async {
    await AppHaptics.selection();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      // FIX: useSafeArea ensures the sheet doesn't clip under notch/chin
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => InvestmentCalculator(
        invoiceId: int.tryParse(_item.id) ?? 0,
        maxAmount: _item.remainingAmount,
        walletBalance: _walletBalance,
        roi: _item.roi,
        days: _item.daysLeft,
        onInvest: _investWithBiometric,
      ),
    );
  }

  Future<void> _loadWallet() async {
    if (_cachedWalletBalance != null) {
      setState(() => _walletBalance = _cachedWalletBalance);
    }
    try {
      final wallet = await ApiService.getWallet();
      if (mounted) {
        final balance =
            double.tryParse(wallet?['balance']?.toString() ?? '0') ?? 0;
        _cachedWalletBalance = balance;
        setState(() => _walletBalance = balance);
      }
    } catch (_) {}
  }

  Future<void> _investWithBiometric(double amount) async {
    if (amount <= 0) return;

    // Close the calculator sheet first so the biometric prompt appears
    // over a clean screen, not over the bottom sheet.
    if (mounted) Navigator.of(context).pop();

    final localAuth = LocalAuthentication();
    bool authenticated = true;
    try {
      if (await localAuth.canCheckBiometrics ||
          await localAuth.isDeviceSupported()) {
        authenticated = await localAuth.authenticate(
            localizedReason:
            'Confirm investment of ₹${amount.toStringAsFixed(0)}');
      }
    } catch (_) {}

    if (!authenticated && mounted) {
      await AppHaptics.error();
      setState(() {
        _message = 'Authentication failed';
        _isSuccess = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isInvesting = true;
      _message = null;
    });

    try {
      final invoiceId = int.tryParse(_item.id) ?? 0;
      final result = await ApiService.invest(invoiceId, amount);
      PortfolioCache.invalidate();
      if (result['success'] == true) _cachedWalletBalance = null;

      if (mounted) {
        final success = result['success'] == true;
        setState(() {
          _isInvesting = false;
          _isSuccess = success;
          _message = success ? 'Investment successful!' : result['error'];
        });
        if (success) {
          await AppHaptics.success();
          // Item #18: tie pop to animation completion instead of magic 1600ms
          _successCtrl.forward();
          _successCtrl.addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              Future.delayed(const Duration(milliseconds: 400), () {
                if (mounted) Navigator.pop(context);
              });
            }
          });
        } else {
          await AppHaptics.error();
        }
      }
    } catch (e) {
      if (mounted) {
        await AppHaptics.error();
        setState(() {
          _isInvesting = false;
          _isSuccess = false;
          _message = 'Something went wrong. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor =
    _item.isAvailable ? AppColors.emerald(context) : AppColors.amber(context);
    final urgencyColor = _item.daysLeft <= 7
        ? AppColors.rose(context)
        : _item.daysLeft <= 30
        ? AppColors.amber(context)
        : AppColors.textSecondary(context);

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      // FIX (UX): sticky CTA at the bottom so the Invest button is always
      // reachable without scrolling to the end of a long detail page.
      bottomNavigationBar: _BottomCTA(
        isInvesting: _isInvesting,
        isSuccess: _isSuccess,
        successCtrl: _successCtrl,
        successScale: _successScale,
        message: _message,
        onTap: _isInvesting || _isSuccess ? null : _openCalculator,
      ),
      body: CustomScrollView(
        slivers: [
          // ── App bar ─────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.scaffold(context),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: AppColors.textPrimary(context)),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _item.company,
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 18),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              centerTitle: false,
              titlePadding:
              const EdgeInsets.symmetric(horizontal: 56, vertical: 16),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Status + days urgency row ──────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.25)),
                        ),
                        child: Text(_item.statusDisplay,
                            style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: urgencyColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: urgencyColor.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule_rounded,
                                size: 12, color: urgencyColor),
                            const SizedBox(width: 4),
                            Text(_item.daysLeftDisplay,
                                style: TextStyle(
                                    color: urgencyColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: UI.md),

                  // ── Description ────────────────────────────────────────
                  if (_item.particular.isNotEmpty)
                    Text(_item.particular,
                        style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 13)),

                  if (_item.debtor.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.business_outlined,
                            size: 13,
                            color: AppColors.textSecondary(context)),
                        const SizedBox(width: 5),
                        Text('Debtor: ${_item.debtor}',
                            style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 12)),
                      ],
                    ),
                  ],

                  const SizedBox(height: UI.lg),

                  // ── Key metrics row ────────────────────────────────────
                  Row(
                    children: [
                      _DetailMetric(
                        label: 'Investor ROI',
                        value: _item.roiDisplay,
                        color: AppColors.emerald(context),
                        icon: Icons.trending_up_rounded,
                      ),
                      const SizedBox(width: 12),
                      _DetailMetric(
                        label: 'Tenure',
                        value: _item.tenureDisplay,
                        color: AppColors.primary(context),
                        icon: Icons.calendar_today_outlined,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Funding progress card ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.navyCard(context),
                      borderRadius: BorderRadius.circular(20),
                      border:
                      Border.all(color: AppColors.divider(context)),
                    ),
                    child: Column(
                      children: [
                        _RowInfo(
                            label: 'Remaining Amount',
                            value: _item.remainingDisplay),
                        const SizedBox(height: 10),
                        _RowInfo(
                            label: 'Funding Progress',
                            value: _item.fundingDisplay),
                        const SizedBox(height: 10),
                        // FIX (UX): animated progress bar — value animates
                        // from 0 to fundingPct on first build so the bar
                        // "fills up" as the screen loads. Feels alive.
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: _item.fundingPct / 100),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, __) => ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: v,
                              minHeight: 8,
                              backgroundColor: AppColors.divider(context),
                              valueColor: AlwaysStoppedAnimation(
                                  AppColors.primary(context)),
                            ),
                          ),
                        ),

                        // Urgency message when almost fully funded
                        if (_item.fundingPct >= 80) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.local_fire_department_rounded,
                                  size: 13,
                                  color: AppColors.amber(context)),
                              const SizedBox(width: 4),
                              Text(
                                _item.fundingPct >= 95
                                    ? 'Almost gone — invest now!'
                                    : 'Filling up fast',
                                style: TextStyle(
                                    color: AppColors.amber(context),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Wallet balance hint ────────────────────────────────
                  if (_walletBalance != null) ...[
                    const SizedBox(height: UI.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.navyLight(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 14,
                              color: AppColors.textSecondary(context)),
                          const SizedBox(width: 8),
                          Text(
                            'Available wallet: ₹${fmtAmount(_walletBalance!)}',
                            style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          // FIX (UX): show a warning if wallet is below
                          // min investment amount (heuristic: ₹1000)
                          if (_walletBalance! < 1000)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    size: 13,
                                    color: AppColors.amber(context)),
                                const SizedBox(width: 4),
                                Text('Low balance',
                                    style: TextStyle(
                                        color: AppColors.amber(context),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: UI.lg),

                  // ── How it works — quick edu block ─────────────────────
                  _HowItWorks(roi: _item.roi, days: _item.daysLeft),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sticky bottom CTA ─────────────────────────────────────────────────────────

class _BottomCTA extends StatelessWidget {
  final bool isInvesting;
  final bool isSuccess;
  final AnimationController successCtrl;
  final Animation<double> successScale;
  final String? message;
  final VoidCallback? onTap;

  const _BottomCTA({
    required this.isInvesting,
    required this.isSuccess,
    required this.successCtrl,
    required this.successScale,
    required this.message,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.scaffold(context),
        border: Border(
          top: BorderSide(
              color: AppColors.divider(context).withValues(alpha: 0.4)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Error / success message above button
          if (message != null) ...[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Container(
                key: ValueKey(message),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isSuccess
                      ? AppColors.emerald(context).withValues(alpha: 0.1)
                      : colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isSuccess
                          ? AppColors.emerald(context).withValues(alpha: 0.3)
                          : colorScheme.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSuccess
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                      size: 16,
                      color: isSuccess
                          ? AppColors.emerald(context)
                          : colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(message!,
                          style: TextStyle(
                              color: isSuccess
                                  ? AppColors.emerald(context)
                                  : colorScheme.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // CTA button
          Pressable(
            onTap: onTap, // Item #5: pass null to disable Pressable feedback
            enabled: onTap != null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: isSuccess
                    ? LinearGradient(colors: [
                  AppColors.emerald(context),
                  AppColors.emerald(context)
                      .withValues(alpha: 0.8),
                ])
                    : LinearGradient(colors: [
                  colorScheme.primary,
                  Color.lerp(
                      colorScheme.primary, colorScheme.tertiary, 0.4)!,
                ]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: onTap == null
                    ? []
                    : [
                  BoxShadow(
                    color: (isSuccess
                        ? AppColors.emerald(context)
                        : colorScheme.primary)
                        .withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isInvesting
                      ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                      : isSuccess
                      ? ScaleTransition(
                    key: const ValueKey('success'),
                    scale: successScale,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded,
                            color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Invested Successfully',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )
                      : const Row(
                    key: ValueKey('invest'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Invest Now',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── How It Works mini block ───────────────────────────────────────────────────

class _HowItWorks extends StatelessWidget {
  final double roi;
  final int days;

  const _HowItWorks({required this.roi, required this.days});

  @override
  Widget build(BuildContext context) {
    // Compute example return on ₹10,000
    final examplePrincipal = 10000.0;
    final profit = examplePrincipal * (roi / 100) * (days / 365);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary(context).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.primary(context).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 15, color: AppColors.primary(context)),
              const SizedBox(width: 7),
              Text('How it works',
                  style: TextStyle(
                      color: AppColors.primary(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          _HowItWorksStep(
            number: '1',
            text:
            'You lend ₹${fmtAmount(examplePrincipal)} to this business via invoice financing.',
          ),
          const SizedBox(height: 8),
          _HowItWorksStep(
            number: '2',
            text:
            'The debtor repays in $days days. You earn ₹${fmtAmount(profit)} on ₹${fmtAmount(examplePrincipal)} — that\'s ${roi.toStringAsFixed(1)}% p.a.',
          ),
          const SizedBox(height: 8),
          _HowItWorksStep(
            number: '3',
            text:
            'Principal + returns credited to your wallet automatically.',
          ),
        ],
      ),
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  final String number;
  final String text;

  const _HowItWorksStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.primary(context).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(number,
                style: TextStyle(
                    color: AppColors.primary(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 12,
                  height: 1.5)),
        ),
      ],
    );
  }
}

// ── Detail metric tile ────────────────────────────────────────────────────────

class _DetailMetric extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;

  const _DetailMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.15))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: color.withValues(alpha: 0.7)),
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 11)),
              ],
            ),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5)),
          ],
        ),
      ),
    );
  }
}

class _RowInfo extends StatelessWidget {
  final String label, value;

  const _RowInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: AppColors.textSecondary(context), fontSize: 13)),
        Text(value,
            style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── TrustSignalsCard and related widgets (unchanged) ─────────────────────────
// (Keep the existing TrustSignalsCard, _Body, _SectionLabel, _TierBadge,
//  _RepaymentBar, _SignalRow, _TrustScore, TrustSignalsSkeleton, _ShimmerBox
//  exactly as they are in your current file — they're well-built.)