import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/bank_account.dart';
import '../services/api_service.dart';
import '../theme/theme_provider.dart';
import '../utils/app_haptics.dart';
import '../widgets/app_logo_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BankAccountDetailScreen extends ConsumerStatefulWidget {
  final BankAccount account;

  const BankAccountDetailScreen({super.key, required this.account});

  @override
  ConsumerState<BankAccountDetailScreen> createState() => _BankAccountDetailScreenState();
}

class _BankAccountDetailScreenState extends ConsumerState<BankAccountDetailScreen> {
  late BankAccount _account;
  bool _isSettingPrimary = false;

  @override
  void initState() {
    super.initState();
    _account = widget.account;
  }

  Future<void> _setPrimary() async {
    if (_account.isPrimary) return;
    setState(() => _isSettingPrimary = true);
    await AppHaptics.selection();
    final result = await ApiService.setPrimaryBankAccount(_account.id);
    if (!mounted) return;
    if (result['success'] == true) {
      _snack('${_account.bankName} set as primary', isError: false);
      Navigator.pop(context, true); // true indicates refresh needed
    } else {
      _snack(result['error'] ?? 'Failed to update', isError: true);
    }
    if (mounted) setState(() => _isSettingPrimary = false);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove account?'),
        content: Text(
            'Remove ${_account.bankName} ending in ${_account.maskedNumber}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Remove',
                  style: TextStyle(color: AppColors.danger(context)))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await ApiService.deleteBankAccount(_account.id);
    if (!mounted) return;
    if (result['success'] == true) {
      _snack('Account removed', isError: false);
      Navigator.pop(context, true);
    } else {
      _snack(result['error'] ?? 'Failed to remove', isError: true);
    }
  }

  void _snack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? AppColors.danger(context) : AppColors.success(context),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _snack('$label copied to clipboard', isError: false);
    AppHaptics.selection();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          AppLogoHeader(title: 'Account Detail'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Card visualization
                  _BankCardVisual(account: _account),
                  const SizedBox(height: 32),

                  // Details list
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        _DetailTile(
                          icon: Icons.account_balance_rounded,
                          label: 'Full Bank Name',
                          value: _account.officialName,
                          onCopy: () => _copy(_account.officialName, 'Bank name'),
                        ),
                        _divider(cs),
                        _DetailTile(
                          icon: Icons.numbers_rounded,
                          label: 'Account Number',
                          value: _account.accountNumber,
                          onCopy: () => _copy(_account.accountNumber, 'Account number'),
                        ),
                        _divider(cs),
                        _DetailTile(
                          icon: Icons.qr_code_rounded,
                          label: 'IFSC Code',
                          value: _account.ifscCode,
                          onCopy: () => _copy(_account.ifscCode, 'IFSC'),
                        ),
                        _divider(cs),
                        _DetailTile(
                          icon: Icons.person_rounded,
                          label: 'Beneficiary Name',
                          value: _account.beneficiaryName,
                          onCopy: () => _copy(_account.beneficiaryName, 'Beneficiary'),
                        ),
                        _divider(cs),
                        _DetailTile(
                          icon: Icons.location_on_rounded,
                          label: 'Branch Address',
                          value: _account.branchAddress,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Actions
                  if (!_account.isPrimary)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _isSettingPrimary ? null : _setPrimary,
                        icon: _isSettingPrimary
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.star_rounded, size: 20),
                        label: const Text('Set as Primary Bank',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: _delete,
                      icon: Icon(Icons.delete_outline_rounded,
                          color: cs.error, size: 20),
                      label: Text('Remove This Bank',
                          style: TextStyle(
                              color: cs.error, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cs.error.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme cs) => Padding(
        padding: const EdgeInsets.only(left: 60),
        child: Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.1)),
      );
}

class _BankCardVisual extends ConsumerWidget {
  final BankAccount account;

  const _BankCardVisual({required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final info = account.bankInfo;

    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: info.brandColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: info.brandColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        gradient: LinearGradient(
          colors: [
            info.brandColor,
            info.brandColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Background shapes for premium look
          Positioned(
            right: -20,
            top: -20,
            child: CircleAvatar(
              radius: 80,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -40,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: Colors.white.withValues(alpha: 0.03),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: account.logoUrl != null
                          ? SvgPicture.network(
                              account.logoUrl!,
                              placeholderBuilder: (_) => Icon(
                                Icons.account_balance_rounded,
                                color: info.brandColor,
                                size: 24,
                              ),
                            )
                          : Icon(Icons.account_balance_rounded,
                              color: info.brandColor),
                    ),
                    if (account.isPrimary)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.star_rounded,
                                color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('PRIMARY',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1)),
                          ],
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  account.accountNumber.replaceAllMapped(
                      RegExp(r".{4}"), (match) => "${match.group(0)} "),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BENEFICIARY',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5)),
                        Text(account.beneficiaryName.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('IFSC CODE',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5)),
                        Text(account.ifscCode,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTile extends ConsumerWidget {
  final IconData icon;
  final String label, value;
  final VoidCallback? onCopy;

  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onCopy,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: cs.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ),
            if (onCopy != null)
              Icon(Icons.copy_rounded,
                  size: 16, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}
