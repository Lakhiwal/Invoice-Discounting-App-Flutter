import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/formatters.dart';
import 'package:invoice_discounting_app/widgets/app_logo_header.dart';
import 'package:invoice_discounting_app/widgets/liquidity_refresh_indicator.dart';
import 'package:invoice_discounting_app/widgets/skeleton.dart';
import 'package:invoice_discounting_app/screens/withdraw_request_screen.dart';

class ECollectScreen extends StatefulWidget {
  const ECollectScreen({super.key});

  @override
  State<ECollectScreen> createState() => _ECollectScreenState();
}

class _ECollectScreenState extends State<ECollectScreen> {
  Map<String, dynamic>? _walletData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _hasError = false;
        });
      }
    }
    try {
      final wallet = await ApiService.getWallet(forceRefresh: true);
      if (mounted) {
        setState(() {
          _walletData = wallet;
          _isLoading = false;
        });
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

  double get _balance =>
      double.tryParse(_walletData?['balance']?.toString() ?? '0') ?? 0;

  Map<String, dynamic>? get _ecollect =>
      _walletData?['ecollect'] as Map<String, dynamic>?;

  bool get _hasECollect => _ecollect != null;

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    unawaited(AppHaptics.success());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
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
        onRefresh: () => _loadData(silent: true),
        color: cs.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            const AppLogoHeader(title: 'E-Collect'),

            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: SkeletonECollect(),
              )
            else if (_hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.error, size: 40, color: cs.error),
                      const SizedBox(height: 16),
                      const Text('Could not load E-Collect data'),
                      TextButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // ── Balance Card ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: UI.lg, vertical: UI.sm),
                  child: _buildBalanceCard(cs, tt),
                ),
              ),

              // ── E-Collect Account Section ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: UI.lg),
                  child: _hasECollect
                      ? _buildVirtualAccountCard(cs, tt)
                      : _buildNoBeneficiaryCard(cs, tt),
                ),
              ),

              // ── Withdraw Button ──
              if (_hasECollect)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(UI.lg),
                    child: _buildWithdrawButton(cs),
                  ),
                ),

              // ── How It Works (shown when no account) ──
              if (!_hasECollect)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(UI.lg),
                    child: _buildHowItWorks(cs, tt),
                  ),
                ),

              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BALANCE CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBalanceCard(ColorScheme cs, TextTheme tt) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary,
            cs.primary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(UI.radiusXl),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    AppIcons.bank,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'E-Collect Balance',
                  style: tt.titleSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              Formatters.currency(_balance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _hasECollect ? '● Account Active' : '○ No Account Linked',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATE A: NO BENEFICIARY — Prompt to add one
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildNoBeneficiaryCard(ColorScheme cs, TextTheme tt) {
    return Container(
      margin: const EdgeInsets.only(top: UI.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(UI.radiusXl),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(AppIcons.bank, size: 36, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'Link Your Bank Account',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a beneficiary bank account to receive your assigned virtual E-Collect account for fund transfers.',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UI.radiusMd),
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  unawaited(AppHaptics.buttonPress());
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _AddBeneficiaryScreen(),
                    ),
                  );
                  if (result == true && mounted) {
                    await _loadData();
                  }
                },
                icon: Icon(AppIcons.addCircle, size: 20),
                label: const Text(
                  'Add Beneficiary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATE C: ACCOUNT ASSIGNED — Show Virtual Account Details
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildVirtualAccountCard(ColorScheme cs, TextTheme tt) {
    final ec = _ecollect!;
    return Container(
      margin: const EdgeInsets.only(top: UI.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(UI.radiusXl),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(UI.radiusXl),
              ),
            ),
            child: Row(
              children: [
                Icon(AppIcons.bank, size: 20, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your Virtual Account',
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              children: [
                _accountDetailRow(
                  cs,
                  tt,
                  label: 'Bank',
                  value: ec['bank_name']?.toString() ?? '—',
                  icon: AppIcons.bank,
                ),
                const SizedBox(height: 14),
                _accountDetailRow(
                  cs,
                  tt,
                  label: 'Account Number',
                  value: ec['account_number']?.toString() ?? '—',
                  icon: AppIcons.hashtag,
                  copyable: true,
                ),
                const SizedBox(height: 14),
                _accountDetailRow(
                  cs,
                  tt,
                  label: 'IFSC Code',
                  value: ec['ifsc_code']?.toString() ?? '—',
                  icon: AppIcons.barcode,
                  copyable: true,
                ),
                const SizedBox(height: 14),
                _accountDetailRow(
                  cs,
                  tt,
                  label: 'Branch',
                  value: ec['branch_address']?.toString() ?? '—',
                  icon: AppIcons.location,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(UI.radiusMd),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(AppIcons.info, size: 16, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Transfer funds via NEFT/IMPS to this account to add money to your E-Collect balance.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.primary,
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
        ],
      ),
    );
  }

  Widget _accountDetailRow(
    ColorScheme cs,
    TextTheme tt, {
    required String label,
    required String value,
    required IconData icon,
    bool copyable = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: label == 'Account Number' ? 1.2 : 0,
                ),
              ),
            ],
          ),
        ),
        if (copyable)
          GestureDetector(
            onTap: () => _copyToClipboard(value, label),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(AppIcons.copy, size: 18, color: cs.primary),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WITHDRAW BUTTON
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildWithdrawButton(ColorScheme cs) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primaryContainer,
          foregroundColor: cs.onPrimaryContainer,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UI.radiusMd),
          ),
          elevation: 0,
        ),
        onPressed: () async {
          unawaited(AppHaptics.buttonPress());
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WithdrawRequestScreen(
                ecollectData: _ecollect,
                balance: _balance,
              ),
            ),
          );
          if (result == true) {
            unawaited(_loadData(silent: true));
          }
        },
        icon: Icon(AppIcons.withdraw, size: 20),
        label: const Text(
          'Withdraw Funds',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HOW IT WORKS — Shown when no account is linked
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHowItWorks(ColorScheme cs, TextTheme tt) {
    final steps = [
      (AppIcons.addCircle, 'Add Beneficiary', 'Register your bank account'),
      (AppIcons.bank, 'Get Virtual Account', 'Receive your assigned account'),
      (AppIcons.moneySend, 'Transfer Funds', 'Send via NEFT/IMPS/UPI'),
      (AppIcons.wallet, 'Start Investing', 'Balance reflects instantly'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How It Works',
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...steps.asMap().entries.map((entry) {
          final i = entry.key;
          final (icon, title, subtitle) = entry.value;
          final isLast = i == steps.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline
                SizedBox(
                  width: 40,
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 16, color: cs.primary),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: cs.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: tt.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ADD BENEFICIARY SCREEN — Form to register a bank account
// ═══════════════════════════════════════════════════════════════════════════════

class _AddBeneficiaryScreen extends StatefulWidget {
  const _AddBeneficiaryScreen();

  @override
  State<_AddBeneficiaryScreen> createState() => _AddBeneficiaryScreenState();
}

class _AddBeneficiaryScreenState extends State<_AddBeneficiaryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _beneficiaryCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _accountCtrl.dispose();
    _ifscCtrl.dispose();
    _beneficiaryCtrl.dispose();
    _branchCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      unawaited(AppHaptics.error());
      return;
    }

    setState(() => _isSubmitting = true);
    unawaited(AppHaptics.buttonPress());

    try {
      final result = await ApiService.addBankAccount(
        bankName: _bankNameCtrl.text.trim(),
        accountNumber: _accountCtrl.text.trim(),
        ifscCode: _ifscCtrl.text.trim().toUpperCase(),
        beneficiaryName: _beneficiaryCtrl.text.trim(),
        branchAddress: _branchCtrl.text.trim(),
        isPrimary: true,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        unawaited(AppHaptics.success());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Beneficiary added! Your virtual account has been assigned.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else {
        unawaited(AppHaptics.error());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] as String? ?? 'Something went wrong'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        unawaited(AppHaptics.error());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Add Beneficiary',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(AppIcons.back),
          onPressed: () {
            unawaited(AppHaptics.navTap());
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(UI.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(UI.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.info, size: 18, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Add your personal bank account to get a virtual E-Collect account assigned for fund transfers.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onPrimaryContainer,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              _buildField(
                cs,
                controller: _beneficiaryCtrl,
                label: 'Account Holder Name',
                hint: 'As per bank records',
                icon: AppIcons.user,
                validator: (v) => (v?.isEmpty ?? true)
                    ? 'Account holder name is required'
                    : null,
              ),
              const SizedBox(height: 20),

              _buildField(
                cs,
                controller: _bankNameCtrl,
                label: 'Bank Name',
                hint: 'e.g. HDFC Bank, SBI',
                icon: AppIcons.bank,
                validator: (v) =>
                    (v?.isEmpty ?? true) ? 'Bank name is required' : null,
              ),
              const SizedBox(height: 20),

              _buildField(
                cs,
                controller: _accountCtrl,
                label: 'Account Number',
                hint: 'Enter account number',
                icon: AppIcons.hashtag,
                keyboardType: TextInputType.number,
                validator: (v) =>
                    (v?.isEmpty ?? true) ? 'Account number is required' : null,
              ),
              const SizedBox(height: 20),

              _buildField(
                cs,
                controller: _ifscCtrl,
                label: 'IFSC Code',
                hint: 'e.g. HDFC0001234',
                icon: AppIcons.barcode,
                textCapitalization: TextCapitalization.characters,
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'IFSC code is required';
                  if (v!.length != 11) return 'IFSC must be 11 characters';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              _buildField(
                cs,
                controller: _branchCtrl,
                label: 'Branch Address',
                hint: 'Branch location',
                icon: AppIcons.location,
                validator: (_) => null, // Optional
              ),
              const SizedBox(height: 36),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(UI.radiusMd),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : const Text(
                          'Register & Get Virtual Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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

  Widget _buildField(
    ColorScheme cs, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UI.radiusMd),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UI.radiusMd),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UI.radiusMd),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        filled: true,
        fillColor: cs.surfaceContainerLow,
      ),
    );
  }
}
