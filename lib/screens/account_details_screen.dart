import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:invoice_discounting_app/models/bank_account.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';

class AccountDetailsScreen extends ConsumerStatefulWidget {
  const AccountDetailsScreen({
    required this.account,
    required this.onRefresh,
    super.key,
  });
  final BankAccount account;
  final VoidCallback onRefresh;

  @override
  ConsumerState<AccountDetailsScreen> createState() =>
      _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends ConsumerState<AccountDetailsScreen> {
  bool _isSettingPrimary = false;
  bool _isDeleting = false;

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? AppColors.danger(context) : AppColors.success(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UI.radiusSm)),
      ),
    );
  }

  Future<void> _setPrimary() async {
    if (widget.account.isPrimary || _isSettingPrimary) return;
    setState(() => _isSettingPrimary = true);
    unawaited(AppHaptics.selection());

    final result = await ApiService.setPrimaryBankAccount(widget.account.id);
    if (!mounted) return;

    if (result['success'] == true) {
      _snack('${widget.account.bankName} set as primary');
      widget.onRefresh();
      if (mounted) Navigator.pop(context);
    } else {
      _snack((result['error'] as String?) ?? 'Failed to update', isError: true);
    }
    setState(() => _isSettingPrimary = false);
  }

  Future<void> _delete() async {
    if (_isDeleting) return;
    final cs = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UI.radiusLg)),
        title: const Text('Remove account?'),
        content: Text(
          'Remove ${widget.account.bankName} ending in ${widget.account.maskedNumber}?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              AppHaptics.selection();
              Navigator.pop(context, false);
            },
            child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () {
              AppHaptics.selection();
              Navigator.pop(context, true);
            },
            child: Text(
              'Remove',
              style: TextStyle(color: AppColors.danger(context)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    final result = await ApiService.deleteBankAccount(widget.account.id);
    if (!mounted) return;

    if (result['success'] == true) {
      _snack('Account removed');
      widget.onRefresh();
      if (mounted) Navigator.pop(context);
    } else {
      _snack((result['error'] as String?) ?? 'Failed to remove', isError: true);
      setState(() => _isDeleting = false);
    }
  }

  void _copy() {
    _copyValue(widget.account.accountNumber, 'Account number');
  }

  void _copyValue(String value, String label) {
    unawaited(AppHaptics.selection());
    unawaited(Clipboard.setData(ClipboardData(text: value)));
    _snack('$label copied');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final account = widget.account;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            AppHaptics.selection();
            Navigator.pop(context);
          },
          icon: Icon(
            AppIcons.back,
            color: cs.onSurface,
            size: 20,
          ),
        ),
        title: Text(
          'Account Details',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            // Hero section with Bank Icon
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: account.logoUrl != null
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: SvgPicture.network(
                              account.logoUrl!,
                              width: 80,
                              height: 80,
                              placeholderBuilder: (_) => Icon(
                                AppIcons.bank,
                                color: account.brandColor,
                                size: 32,
                              ),
                            ),
                          )
                        : Icon(
                            AppIcons.bank,
                            color: account.brandColor,
                            size: 32,
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    account.officialName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (account.isPrimary)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(UI.radiusSm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppIcons.check,
                            color: cs.primary,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Primary bank account',
                            style: TextStyle(
                              color: cs.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Details card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(UI.radiusLg),
                border:
                    Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    label: 'Account number',
                    value: account.accountNumber,
                    onTap: () =>
                        _copyValue(account.accountNumber, 'Account number'),
                  ),
                  _dottedDivider(cs),
                  _DetailRow(
                    label: 'IFSC Code',
                    value: account.ifscCode,
                    onTap: () => _copyValue(account.ifscCode, 'IFSC Code'),
                  ),
                  _dottedDivider(cs),
                  if (account.branchAddress.isNotEmpty) ...[
                    _DetailRow(
                      label: 'Bank branch',
                      value: account.branchAddress,
                      onTap: () =>
                          _copyValue(account.branchAddress, 'Branch address'),
                    ),
                    _dottedDivider(cs),
                  ],
                  if (account.beneficiaryName.isNotEmpty)
                    _DetailRow(
                      label: 'Beneficiary',
                      value: account.beneficiaryName,
                      onTap: () =>
                          _copyValue(account.beneficiaryName, 'Beneficiary'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Main Primary actions
            if (!account.isPrimary)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSettingPrimary ? null : _setPrimary,
                  icon: _isSettingPrimary
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          AppIcons.star,
                          size: 20,
                          color: account.brandColor,
                        ),
                  label: Text(
                    'Set as Primary',
                    style: TextStyle(
                      color: account.brandColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: account.brandColor.withValues(alpha: 0.1),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(UI.radiusLg),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Secondary actions
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    onPressed: _copy,
                    icon: AppIcons.copy,
                    label: 'Copy Number',
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    onPressed: _isDeleting ? null : _delete,
                    icon: AppIcons.delete,
                    label: 'Remove',
                    color: AppColors.danger(context),
                    isLoading: _isDeleting,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dottedDivider(ColorScheme cs) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: List.generate(
            30,
            (index) => Expanded(
              child: Container(
                color: index % 2 == 0
                    ? Colors.transparent
                    : cs.outlineVariant.withValues(alpha: 0.3),
                height: 1,
              ),
            ),
          ),
        ),
      );
}

class _DetailRow extends ConsumerWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(UI.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                AppIcons.copy,
                size: 16,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends ConsumerWidget {
  const _ActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
    this.isLoading = false,
  });
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final Color color;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.2)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(UI.radiusLg)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      );
}
