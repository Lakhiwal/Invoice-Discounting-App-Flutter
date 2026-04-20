import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/formatters.dart';
import 'package:invoice_discounting_app/widgets/app_logo_header.dart';
import 'package:invoice_discounting_app/widgets/glass_card.dart';
import 'package:invoice_discounting_app/widgets/success_checkmark.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class WithdrawRequestScreen extends StatefulWidget {
  final Map<String, dynamic>? ecollectData;
  final double balance;

  const WithdrawRequestScreen({
    super.key,
    this.ecollectData,
    required this.balance,
  });

  @override
  State<WithdrawRequestScreen> createState() => _WithdrawRequestScreenState();
}

class _WithdrawRequestScreenState extends State<WithdrawRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      unawaited(AppHaptics.error());
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0 || amount > widget.balance) {
      unawaited(AppHaptics.error());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid amount or insufficient balance'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    unawaited(AppHaptics.buttonPress());
    setState(() => _isSubmitting = true);

    try {
      await ApiService.withdrawFunds(amount);
      if (!mounted) return;

      unawaited(AppHaptics.success());
      setState(() {
        _isSubmitting = false;
        _isSuccess = true;
      });

      // Wait a bit then pop back
      await Future.delayed(const Duration(milliseconds: 2500));
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      unawaited(AppHaptics.error());
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_isSuccess) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: UI.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SuccessCheckmark(size: 120, color: cs.primary),
                const SizedBox(height: 40),
                Text(
                  'Withdrawal Requested!',
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your request for withdrawal has been submitted successfully. Funds will be settled into your bank account shortly.',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 200,
                  height: 50,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: cs.primary.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(UI.radiusMd),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      'BACK TO E-COLLECT',
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.primary.withValues(alpha: 0.05),
              cs.surface,
              cs.surface,
            ],
          ),
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            AppLogoHeader(
              title: 'Withdraw Funds',
              actions: [
                IconButton(
                  icon: Icon(AppIcons.close, color: cs.primary),
                  onPressed: () {
                    unawaited(AppHaptics.selection());
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(UI.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Balance Card ---
                      _buildBalanceCard(cs, tt),
                      const SizedBox(height: UI.xl),
  
                      // --- Ecollect Account (Pre-filled/Read-only) ---
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          'WITHDRAW FROM',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildAccountField(cs, tt),
  
                      const SizedBox(height: UI.xl),
  
                      // --- Amount Field ---
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          'AMOUNT TO WITHDRAW',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildAmountField(cs, tt),
  
                      const SizedBox(height: UI.xl * 2),
  
                      // --- Submit Button ---
                      _buildSubmitButton(cs),
  
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(UI.radiusMd),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(AppIcons.info, size: 18, color: cs.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Withdrawals are usually processed within 2-4 business hours into your registered account.',
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(ColorScheme cs, TextTheme tt) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary,
            cs.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(UI.radiusXl),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                  'Available Balance',
                  style: tt.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  Formatters.currency(widget.balance),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountField(ColorScheme cs, TextTheme tt) {
    final account = widget.ecollectData?['account_number'] ?? 'Not Assigned';
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      borderRadius: UI.radiusMd,
      child: Row(
        children: [
          Icon(AppIcons.bank, size: 20, color: cs.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'E-Collect Account',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  account,
                  style: tt.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField(ColorScheme cs, TextTheme tt) {
    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
      onChanged: (_) => unawaited(AppHaptics.selection()),
      decoration: InputDecoration(
        hintText: '0.00',
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '₹',
            style: tt.headlineMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        suffixIcon: TextButton(
          onPressed: () {
            unawaited(AppHaptics.selection());
            setState(() {
              _amountController.text = widget.balance.toStringAsFixed(2);
            });
          },
          child: const Text('MAX'),
        ),
        filled: true,
        fillColor: cs.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UI.radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UI.radiusMd),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter an amount';
        final amount = double.tryParse(value) ?? 0;
        if (amount <= 0) return 'Amount must be greater than zero';
        if (amount > widget.balance) return 'Insufficient balance';
        return null;
      },
    );
  }

  Widget _buildSubmitButton(ColorScheme cs) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UI.radiusMd),
          ),
          elevation: 0,
        ),
        onPressed: _isSubmitting ? null : _handleSubmit,
        child: _isSubmitting
            ? LoadingAnimationWidget.hexagonDots(
                color: cs.onPrimary,
                size: 24,
              )
            : const Text(
                'SUBMIT REQUEST',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
      ),
    );
  }
}
