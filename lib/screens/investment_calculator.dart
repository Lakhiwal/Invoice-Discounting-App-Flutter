import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/formatters.dart';

class InvestmentCalculator extends ConsumerStatefulWidget {
  const InvestmentCalculator({
    required this.invoiceId,
    super.key,
    this.maxAmount,
    this.roi,
    this.days,
    this.onInvest,
    this.eCollectBalance,
  });
  final double? maxAmount;
  final double? roi;
  final int? days;
  final Function(double)? onInvest;
  final double? eCollectBalance;
  final int invoiceId;

  @override
  ConsumerState<InvestmentCalculator> createState() =>
      _InvestmentCalculatorState();
}

class _InvestmentCalculatorState extends ConsumerState<InvestmentCalculator> {
  final _amountCtrl = TextEditingController();
  Timer? _debounce;

  // FIX: generation counter to cancel stale API responses.
  // Without this, if the user types fast and triggers two debounced calls,
  // whichever API response arrives last wins — even if it's for an older input.
  int _calcGeneration = 0;

  double _amount = 0;
  double _profit = 0;
  double _maturity = 0;
  double _annualReturn = 0;

  bool _exceedsMax = false;
  bool _exceedsECollect = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_calculate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.maxAmount != null && widget.maxAmount! > 0) {
        _amountCtrl.text = widget.maxAmount!.toStringAsFixed(0);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final input = double.tryParse(_amountCtrl.text.trim()) ?? 0;

      final exceedsMax = widget.maxAmount != null && input > widget.maxAmount!;
      final exceedsECollect =
          widget.eCollectBalance != null && input > widget.eCollectBalance!;

      if ((exceedsMax && !_exceedsMax) || (exceedsECollect && !_exceedsECollect)) {
        AppHaptics.error();
      }

      setState(() {
        _exceedsMax = exceedsMax;
        _exceedsECollect = exceedsECollect;
      });

      if (input <= 0) {
        setState(() {
          _amount = 0;
          _profit = 0;
          _maturity = 0;
          _annualReturn = 0;
        });
        return;
      }

      // FIX: capture generation before the async gap. After the API call
      // returns, check if a newer calculation has been triggered while we
      // were waiting. If so, discard this result — it's stale.
      final generation = ++_calcGeneration;

      final result = await ApiService.calculateInvestment(
        widget.invoiceId,
        input,
      );

      // Discard if a newer input has already been submitted
      if (generation != _calcGeneration || !mounted) return;
      if (result == null) return;

      setState(() {
        _amount = input;
        _profit = double.parse(result['expected_profit'] as String);
        _maturity = double.parse(result['maturity_value'] as String);
        _annualReturn = double.parse(result['investor_rate'] as String);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.maxAmount ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.scaffold(context),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(UI.radiusLg)),
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: UI.lg),

            Text(
              'Investment Calculator',
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),

            // ── Amount input ──────────────────────────────────────────────
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: TextStyle(
                color: _exceedsMax
                    ? AppColors.rose(context)
                    : AppColors.textPrimary(context),
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                prefixText: '₹ ',
                filled: true,
                fillColor: AppColors.navyCard(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UI.radiusMd),
                  borderSide: BorderSide(
                    color: _exceedsMax
                        ? AppColors.rose(context)
                        : AppColors.divider(context),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UI.radiusMd),
                  borderSide: BorderSide(
                    color: _exceedsMax
                        ? AppColors.rose(context)
                        : AppColors.divider(context),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UI.radiusMd),
                  borderSide: BorderSide(
                    color: _exceedsMax
                        ? AppColors.rose(context)
                        : AppColors.primary(context),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: UI.md,
                  vertical: 20,
                ),
              ),
            ),

            // ── Max / E-Collect info + warnings ──────────────────────────────
            if (max > 0 || widget.eCollectBalance != null) ...[
              const SizedBox(height: UI.sm),
              if (max > 0)
                Row(
                  children: [
                    Icon(
                      _exceedsMax ? AppIcons.warning : AppIcons.info,
                      size: 13,
                      color: _exceedsMax
                          ? AppColors.rose(context)
                          : AppColors.textSecondary(context),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _exceedsMax
                          ? 'Exceeds max available (₹${fmtAmount(max)})'
                          : 'Max available: ₹${fmtAmount(max)}',
                      style: TextStyle(
                        color: _exceedsMax
                            ? AppColors.rose(context)
                            : AppColors.textSecondary(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              if (widget.eCollectBalance != null) ...[
                const SizedBox(height: UI.xs),
                Row(
                  children: [
                    Icon(
                      _exceedsECollect ? AppIcons.bank : AppIcons.bank,
                      size: 13,
                      color: _exceedsECollect
                          ? AppColors.rose(context)
                          : AppColors.textSecondary(context),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _exceedsECollect
                          ? 'Insufficient E-Collect balance (₹${fmtAmount(widget.eCollectBalance)})'
                          : 'E-Collect balance: ₹${fmtAmount(widget.eCollectBalance)}',
                      style: TextStyle(
                        color: _exceedsECollect
                            ? AppColors.rose(context)
                            : AppColors.textSecondary(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],

            const SizedBox(height: UI.xl),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _resultSection(context),
            ),

            const SizedBox(height: UI.md),

            // ── Risk disclaimer (compliance) ────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    size: 13,
                    color: AppColors.amber(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Returns are not guaranteed. Subject to debtor repayment risk.',
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

            // Item #6: removed Pressable wrapper — was double-firing onInvest
            // (Pressable.onTap + ElevatedButton.onPressed both called onInvest)
            if (widget.onInvest != null)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _amount > 0 &&
                          !_exceedsMax &&
                          !_exceedsECollect &&
                          widget.onInvest != null
                      ? () async {
                          unawaited(AppHaptics.investmentConfirm());
                          widget.onInvest!(_amount);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(context),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary(context).withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(UI.radiusMd),
                    ),
                  ),
                  child: Text(
                    _exceedsMax
                        ? 'Amount exceeds available limit'
                        : _exceedsECollect
                            ? 'Insufficient E-Collect balance'
                            : _amount > 0
                                ? 'Invest ₹${_amount.toStringAsFixed(0)}'
                                : 'Enter amount to invest',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _resultSection(BuildContext context) => Column(
        key: ValueKey(_amount),
        children: [
          _StatRow(
            label: 'Expected Profit',
            value: '₹${_profit.toStringAsFixed(2)}',
            valueColor: AppColors.emerald(context),
          ),
          const SizedBox(height: UI.md),
          _StatRow(
            label: 'Maturity Amount',
            value: '₹${_maturity.toStringAsFixed(2)}',
            valueColor: AppColors.textPrimary(context),
            bold: true,
          ),
          const SizedBox(height: UI.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_annualReturn.toStringAsFixed(1)}% ',
                style: TextStyle(
                  color: AppColors.primary(context),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'est. annualized return',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 15,
                ),
              ),
            ],
          ),
          if (_amount == 0) ...[
            const SizedBox(height: UI.lg),
            Text(
              'Enter amount above to see estimated returns',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ],
        ],
      );
}

class _StatRow extends ConsumerWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 15,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary(context),
              fontSize: 17,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );
}
