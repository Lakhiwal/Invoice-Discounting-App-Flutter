import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../theme/theme_provider.dart';
import '../utils/app_haptics.dart';
import '../utils/bank_resolver.dart';
import '../widgets/app_logo_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddBankAccountScreen extends ConsumerStatefulWidget {
  final int existingCount;

  const AddBankAccountScreen({super.key, required this.existingCount});

  @override
  ConsumerState<AddBankAccountScreen> createState() => _AddBankAccountScreenState();
}

class _AddBankAccountScreenState extends ConsumerState<AddBankAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _confirmAccountCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _beneficiaryCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  bool _isPrimary = false;
  bool _saving = false;
  BankInfo? _resolvedBank;

  @override
  void initState() {
    super.initState();
    if (widget.existingCount == 0) _isPrimary = true;
    _ifscCtrl.addListener(_onIfscChange);
  }

  @override
  void dispose() {
    _ifscCtrl.removeListener(_onIfscChange);
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _confirmAccountCtrl.dispose();
    _ifscCtrl.dispose();
    _beneficiaryCtrl.dispose();
    _branchCtrl.dispose();
    super.dispose();
  }

  void _onIfscChange() {
    final code = _ifscCtrl.text.trim();
    if (code.length >= 4) {
      final info = BankResolver.resolve(code);
      if (mounted) {
        setState(() {
          _resolvedBank = info;
          // Auto-fill bank name if empty or just started typing
          if (_bankNameCtrl.text.isEmpty ||
              _bankNameCtrl.text.startsWith('Bank ')) {
            _bankNameCtrl.text = info.name;
          }
        });
      }
    } else if (_resolvedBank != null) {
      setState(() => _resolvedBank = null);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final result = await ApiService.addBankAccount(
        bankName: _bankNameCtrl.text.trim(),
        accountNumber: _accountNumberCtrl.text.trim(),
        ifscCode: _ifscCtrl.text.trim().toUpperCase(),
        beneficiaryName: _beneficiaryCtrl.text.trim(),
        branchAddress: _branchCtrl.text.trim(),
        isPrimary: _isPrimary,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        await AppHaptics.success();
        if (!mounted) return;
        navigator.pop(true);
      } else {
        await AppHaptics.error();
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(
          content: Text(result['error'] ?? 'Failed to add account'),
          backgroundColor: AppColors.danger(context),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('Connection error'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          AppLogoHeader(title: 'Add Bank'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bank Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Provide your bank information for fast and reliable payouts.',
                      style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 32),

                    // IFSC Resolver Visual
                    if (_resolvedBank != null)
                      _BankPreviewCard(info: _resolvedBank!),

                    const SizedBox(height: 24),

                    _field(
                      _ifscCtrl,
                      'IFSC Code',
                      Icons.qr_code_rounded,
                      capitalization: TextCapitalization.characters,
                      maxLength: 11,
                      hint: 'e.g. HDFC0001234',
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (v.trim().length != 11) return 'Must be 11 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _field(
                      _bankNameCtrl,
                      'Bank Name',
                      Icons.account_balance_rounded,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    _field(
                      _accountNumberCtrl,
                      'Account Number',
                      Icons.numbers_rounded,
                      keyboard: TextInputType.number,
                      formatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (v.trim().length < 8) return 'Too short';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _field(
                      _confirmAccountCtrl,
                      'Confirm Account Number',
                      Icons.verified_user_rounded,
                      keyboard: TextInputType.number,
                      formatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (v.trim() != _accountNumberCtrl.text.trim()) {
                          return 'Account numbers do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _field(
                      _beneficiaryCtrl,
                      'Beneficiary Name',
                      Icons.person_rounded,
                      capitalization: TextCapitalization.words,
                      hint: 'Name as in bank records',
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    _field(
                      _branchCtrl,
                      'Branch Address',
                      Icons.location_on_rounded,
                      capitalization: TextCapitalization.sentences,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),

                    if (widget.existingCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.1)),
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Primary Account',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface)),
                          subtitle: Text('Used for all withdrawals',
                              style: TextStyle(
                                  fontSize: 12, color: cs.onSurfaceVariant)),
                          value: _isPrimary,
                          onChanged: (v) => setState(() => _isPrimary = v),
                          activeThumbColor: cs.primary,
                        ),
                      ),

                    const SizedBox(height: 48),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Confirm & Add',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
    int? maxLength,
    String? hint,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      textCapitalization: capitalization,
      maxLength: maxLength,
      inputFormatters: formatters,
      validator: validator,
      style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: cs.primary, size: 20),
        counterText: '',
      ),
    );
  }
}

class _BankPreviewCard extends ConsumerWidget {
  final BankInfo info;

  const _BankPreviewCard({required this.info});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            info.brandColor.withValues(alpha: 0.15),
            info.brandColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: info.brandColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: info.logoUrl != null
                ? SvgPicture.network(
                    info.logoUrl!,
                    placeholderBuilder: (_) => Icon(
                      Icons.account_balance_rounded,
                      color: info.brandColor,
                      size: 24,
                    ),
                  )
                : Icon(Icons.account_balance_rounded, color: info.brandColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Verified Network Bank',
                  style: TextStyle(
                    color: info.brandColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.verified_rounded, color: info.brandColor, size: 24),
        ],
      ),
    );
  }
}
