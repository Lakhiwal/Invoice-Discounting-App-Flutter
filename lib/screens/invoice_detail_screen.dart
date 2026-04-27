import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/models/invoice_item.dart';
import 'package:invoice_discounting_app/screens/investment_calculator.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/services/portfolio_cache.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/formatters.dart';
import 'package:invoice_discounting_app/widgets/animated_amount_text.dart';
import 'package:invoice_discounting_app/widgets/app_logo_header.dart';
import 'package:invoice_discounting_app/widgets/pressable.dart';
import 'package:invoice_discounting_app/widgets/skeleton.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:local_auth/local_auth.dart';

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  const InvoiceDetailScreen({super.key, this.item, this.invoiceId});

  factory InvoiceDetailScreen.fromMap(Map<String, dynamic> invoice) =>
      InvoiceDetailScreen(item: InvoiceItem.fromMap(invoice));
  final InvoiceItem? item;
  final int? invoiceId;

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _isInvesting = false;
  bool _isSuccess = false;
  String? _message;
  double? _walletBalance;
  static double? _cachedWalletBalance;

  InvoiceItem? _loadedItem;

  // FIX (UX): success state uses a dedicated animation so the CTA
  // morphs into a checkmark rather than just disabling with grey text.
  late final AnimationController _successCtrl;
  late final Animation<double> _successScale;

  InvoiceItem? get _item => widget.item ?? _loadedItem;

  @override
  void initState() {
    super.initState();
    _loadWallet();

    if (widget.item == null && widget.invoiceId != null) {
      _fetchItem(widget.invoiceId!);
    }

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

  Future<void> _openCalculator() async {
    unawaited(AppHaptics.selection());
    if (!mounted) return;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        showDragHandle: true,
        // FIX: useSafeArea ensures the sheet doesn't clip under notch/chin
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (context) => InvestmentCalculator(
          invoiceId: int.tryParse(_item!.id) ?? 0,
          maxAmount: _item!.remainingAmount,
          eCollectBalance: _walletBalance,
          roi: _item!.roi,
          days: _item!.daysLeft,
          onInvest: _investWithBiometric,
        ),
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

  Future<void> _fetchItem(int id) async {
    try {
      final data = await ApiService.getInvoiceDetail(id);
      if (data != null && mounted) {
        setState(() {
          _loadedItem = InvoiceItem.fromMap(data);
        });
      } else if (mounted) {
        setState(() {
          _message = 'Failed to load invoice details';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Connection error';
        });
      }
    }
  }

  Future<void> _investWithBiometric(double amount) async {
    if (_isInvesting || _item == null) return;
    if (amount <= 0) return;

    // Close the calculator sheet first so the biometric prompt appears
    // over a clean screen, not over the bottom sheet.
    if (mounted) Navigator.of(context).pop();

    final localAuth = LocalAuthentication();
    var authenticated = false;

    final useBiometrics = ref.read(themeProvider).useBiometrics;
    final isHighValue = amount > 50000;

    try {
      final canAuth = await localAuth.canCheckBiometrics ||
          await localAuth.isDeviceSupported();

      if (canAuth && (useBiometrics || isHighValue)) {
        authenticated = await localAuth.authenticate(
          localizedReason: isHighValue
              ? 'High-value transaction protection: Confirm ₹${fmtAmount(amount)}'
              : 'Confirm investment of ₹${fmtAmount(amount)}',
          biometricOnly: true,
        );
      } else {
        authenticated = true;
      }
    } catch (_) {
      authenticated = false;
    }

    if (!authenticated && mounted) {
      unawaited(AppHaptics.error());
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
      final invoiceId = int.tryParse(_item!.id) ?? 0;
      unawaited(AppHaptics.investmentConfirm());
      final result = await ApiService.invest(invoiceId, amount);
      PortfolioCache.invalidate();
      if (result['success'] == true) _cachedWalletBalance = null;

      if (mounted) {
        final success = result['success'] == true;
        setState(() {
          _isInvesting = false;
          _isSuccess = success;
          _message =
              success ? 'Investment successful!' : (result['error'] as String?);
        });
        if (success) {
          unawaited(AppHaptics.success());
          _successCtrl.forward();
          Future.delayed(const Duration(milliseconds: 1600), () {
            if (mounted) unawaited(Navigator.of(context).maybePop());
          });
        } else {
          unawaited(AppHaptics.error());
        }
      }
    } catch (e) {
      if (mounted) {
        unawaited(AppHaptics.error());
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
    if (_item == null) {
      if (_message != null) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  AppIcons.error,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(_message!, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _message = null;
                    });
                    if (widget.invoiceId != null) _fetchItem(widget.invoiceId!);
                  },
                  child: const Text('Try Again'),
                ),
                TextButton(
                  onPressed: () {
                    AppHaptics.selection();
                    unawaited(Navigator.of(context).maybePop());
                  },
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        );
      }
      return const Scaffold(body: SkeletonInvoiceDetail());
    }

    final statusColor = _item!.isAvailable
        ? AppColors.emerald(context)
        : AppColors.amber(context);
    final urgencyColor = _item!.daysLeft <= 7
        ? AppColors.rose(context)
        : _item!.daysLeft <= 30
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
          AppLogoHeader(
            title: _item!.company,
          ),

          SliverToBoxAdapter(
            child: Hero(
              tag: 'invoice-${_item!.id}',
              child: Material(
                type: MaterialType.transparency,
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
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(UI.radiusSm),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              _item!.statusDisplay,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: urgencyColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(UI.radiusSm),
                              border: Border.all(
                                color: urgencyColor.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  AppIcons.timer,
                                  size: 12,
                                  color: urgencyColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _item!.daysLeftDisplay,
                                  style: TextStyle(
                                    color: urgencyColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: UI.md),

                      // ── Description ────────────────────────────────────────
                      if (_item!.particular.isNotEmpty)
                        Text(
                          _item!.particular,
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 13,
                          ),
                        ),

                      if (_item!.debtor.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              AppIcons.business,
                              size: 13,
                              color: AppColors.textSecondary(context),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Debtor: ${_item!.debtor}',
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: UI.lg),

                      Row(
                        children: [
                          _DetailMetric(
                            label: 'Expected ROI (p.a.)',
                            color: AppColors.emerald(context),
                            icon: AppIcons.trendingUp,
                            value: AnimatedAmountText(
                              value: _item!.roi,
                              suffix: '%',
                              style: TextStyle(
                                color: AppColors.emerald(context),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _DetailMetric(
                            label: 'Tenure',
                            color: AppColors.primary(context),
                            icon: AppIcons.calendar,
                            value: AnimatedAmountText(
                              value: _item!.tenureDays.toDouble(),
                              suffix: 'D',
                              style: TextStyle(
                                color: AppColors.primary(context),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ── Funding progress card ──────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.navyCard(context),
                          borderRadius: BorderRadius.circular(UI.radiusLg),
                          border: Border.all(color: AppColors.divider(context)),
                        ),
                        child: Column(
                          children: [
                            _RowInfo(
                              label: 'Remaining Amount',
                              value: AnimatedAmountText(
                                value: _item!.remainingAmount,
                                prefix: '₹',
                                style: TextStyle(
                                  color: AppColors.textPrimary(context),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _RowInfo(
                              label: 'Funding Progress',
                              value: AnimatedAmountText(
                                value: _item!.fundingPct,
                                suffix: '%',
                                style: TextStyle(
                                  color: AppColors.textPrimary(context),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // FIX (UX): animated progress bar — value animates
                            // from 0 to fundingPct on first build so the bar
                            // "fills up" as the screen loads. Feels alive.
                            TweenAnimationBuilder<double>(
                              tween:
                                  Tween(begin: 0, end: _item!.fundingPct / 100),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, __) => ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(UI.radiusSm),
                                child: LinearProgressIndicator(
                                  value: v,
                                  minHeight: 8,
                                  backgroundColor: AppColors.divider(context),
                                  valueColor: AlwaysStoppedAnimation(
                                    AppColors.primary(context),
                                  ),
                                ),
                              ),
                            ),

                            // Urgency message when almost fully funded
                            if (_item!.fundingPct >= 80) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    AppIcons.flash,
                                    size: 13,
                                    color: AppColors.amber(context),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _item!.fundingPct >= 95
                                        ? 'Almost gone — invest now!'
                                        : 'Filling up fast',
                                    style: TextStyle(
                                      color: AppColors.amber(context),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
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
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.navyLight(context),
                            borderRadius: BorderRadius.circular(UI.radiusMd),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                AppIcons.wallet,
                                size: 14,
                                color: AppColors.textSecondary(context),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                children: [
                                  Text(
                                    'Available wallet: ',
                                    style: TextStyle(
                                      color: AppColors.textSecondary(context),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  AnimatedAmountText(
                                    value: _walletBalance ?? 0,
                                    prefix: '₹',
                                    style: TextStyle(
                                      color: AppColors.textSecondary(context),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              // FIX (UX): show a warning if wallet is below
                              // min investment amount (heuristic: ₹1000)
                              if (_walletBalance! < 1000)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      AppIcons.warning,
                                      size: 13,
                                      color: AppColors.amber(context),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Low balance',
                                      style: TextStyle(
                                        color: AppColors.amber(context),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: UI.md),

                      // ── Risk disclosure — compliance requirement ───────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.amber(context).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(UI.radiusMd),
                          border: Border.all(
                            color: AppColors.amber(context).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              AppIcons.warning,
                              size: 14,
                              color: AppColors.amber(context),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Returns are not guaranteed. Subject to debtor '
                                'repayment risk. Past performance does not '
                                'indicate future results.',
                                style: TextStyle(
                                  color: AppColors.amber(context),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: UI.lg),

                      // ── How it works — quick edu block ─────────────────────
                      _HowItWorks(roi: _item!.roi, days: _item!.daysLeft),
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

// ── Sticky bottom CTA ─────────────────────────────────────────────────────────

class _BottomCTA extends ConsumerWidget {
  const _BottomCTA({
    required this.isInvesting,
    required this.isSuccess,
    required this.successCtrl,
    required this.successScale,
    required this.message,
    required this.onTap,
  });
  final bool isInvesting;
  final bool isSuccess;
  final AnimationController successCtrl;
  final Animation<double> successScale;
  final String? message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.scaffold(context),
        border: Border(
          top: BorderSide(
            color: AppColors.divider(context).withValues(alpha: 0.4),
          ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isSuccess
                      ? AppColors.emerald(context).withValues(alpha: 0.1)
                      : colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(UI.radiusMd),
                  border: Border.all(
                    color: isSuccess
                        ? AppColors.emerald(context).withValues(alpha: 0.3)
                        : colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSuccess ? AppIcons.check : AppIcons.error,
                      size: 16,
                      color: isSuccess
                          ? AppColors.emerald(context)
                          : colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        message!,
                        style: TextStyle(
                          color: isSuccess
                              ? AppColors.emerald(context)
                              : colorScheme.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // CTA button
          Pressable(
            onTap: onTap ?? () {},
            enabled: onTap != null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: isSuccess
                    ? LinearGradient(
                        colors: [
                          AppColors.emerald(context),
                          AppColors.emerald(context).withValues(alpha: 0.8),
                        ],
                      )
                    : LinearGradient(
                        colors: [
                          colorScheme.primary,
                          Color.lerp(
                            colorScheme.primary,
                            colorScheme.tertiary,
                            0.4,
                          )!,
                        ],
                      ),
                borderRadius: BorderRadius.circular(UI.radiusMd),
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
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          width: 22,
                          height: 22,
                          child: LoadingAnimationWidget.staggeredDotsWave(color: Colors.white, size: 24),
                        )
                      : isSuccess
                          ? ScaleTransition(
                              key: const ValueKey('success'),
                              scale: successScale,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    AppIcons.check,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Invested Successfully',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Row(
                              key: const ValueKey('invest'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  AppIcons.flash,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Invest Now',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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

class _HowItWorks extends ConsumerWidget {
  const _HowItWorks({required this.roi, required this.days});
  final double roi;
  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Compute example return on ₹10,000
    const examplePrincipal = 10000.0;
    final profit = examplePrincipal * (roi / 100) * (days / 365);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary(context).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(UI.radiusLg),
        border: Border.all(
          color: AppColors.primary(context).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.insight,
                size: 15,
                color: AppColors.primary(context),
              ),
              const SizedBox(width: 7),
              Text(
                'How it works',
                style: TextStyle(
                  color: AppColors.primary(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
                "The debtor repays in $days days. You could earn an estimated ₹${fmtAmount(profit)} on ₹${fmtAmount(examplePrincipal)} — that's ${roi.toStringAsFixed(1)}% p.a. (expected).",
          ),
          const SizedBox(height: 8),
          const _HowItWorksStep(
            number: '3',
            text: 'Principal + estimated returns credited to your wallet automatically.',
          ),
        ],
      ),
    );
  }
}

class _HowItWorksStep extends ConsumerWidget {
  const _HowItWorksStep({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(UI.radiusSm),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: AppColors.primary(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      );
}

// ── Detail metric tile ────────────────────────────────────────────────────────

class _DetailMetric extends ConsumerWidget {
  const _DetailMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final Widget value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.navyCard(context),
            borderRadius: BorderRadius.circular(UI.radiusLg),
            border: Border.all(color: AppColors.divider(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              value,
            ],
          ),
        ),
      );
}

class _RowInfo extends ConsumerWidget {
  const _RowInfo({required this.label, required this.value});
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 13,
            ),
          ),
          value,
        ],
      );
}

// ── TrustSignalsCard and related widgets (unchanged) ─────────────────────────
// (Keep the existing TrustSignalsCard, _Body, _SectionLabel, _TierBadge,
//  _RepaymentBar, _SignalRow, _TrustScore, TrustSignalsSkeleton, _ShimmerBox
//  exactly as they are in your current file — they're well-built.)
