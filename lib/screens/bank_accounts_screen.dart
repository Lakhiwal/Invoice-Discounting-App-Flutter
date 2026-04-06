import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/theme_provider.dart';
import '../utils/app_haptics.dart';
import '../widgets/app_logo_header.dart';
import '../widgets/liquidity_refresh_indicator.dart';

// ── Model ────────────────────────────────────────────────────────────────────

class BankAccount {
  final int id;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String beneficiaryName;
  final String branchAddress;
  final bool isPrimary;

  const BankAccount({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    required this.beneficiaryName,
    required this.branchAddress,
    required this.isPrimary,
  });

  factory BankAccount.fromMap(Map<String, dynamic> m) => BankAccount(
    id: m['id'] as int,
    bankName: (m['bank_name'] ?? '') as String,
    accountNumber: (m['account_number'] ?? '') as String,
    ifscCode: (m['ifsc_code'] ?? '') as String,
    beneficiaryName: (m['beneficiary_name'] ?? '') as String,
    branchAddress: (m['branch_address'] ?? '') as String,
    isPrimary: (m['is_primary'] ?? false) as bool,
  );

  String get maskedNumber {
    if (accountNumber.length <= 4) return accountNumber;
    return '···· ${accountNumber.substring(accountNumber.length - 4)}';
  }

  /// Get a color for the bank icon based on bank name hash
  Color get brandColor {
    final colors = [
      const Color(0xFF1A73E8), // Blue (SBI, etc)
      const Color(0xFF00897B), // Teal
      const Color(0xFFE53935), // Red (HDFC vibe)
      const Color(0xFF6D4C41), // Brown (PNB vibe)
      const Color(0xFF5E35B1), // Purple
      const Color(0xFFFF6F00), // Orange (ICICI vibe)
      const Color(0xFF2E7D32), // Green
      const Color(0xFF0277BD), // Light blue
    ];
    return colors[bankName.hashCode.abs() % colors.length];
  }
}

// ── Screen ───────────────────────────────────────────────────────────────────

class BankAccountsScreen extends StatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  List<BankAccount> _accounts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final raw = await ApiService.getBankAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = raw.map((m) => BankAccount.fromMap(m)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to load accounts';
      });
    }
  }

  void _snack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
      isError ? AppColors.danger(context) : AppColors.success(context),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _setPrimary(BankAccount account) async {
    if (account.isPrimary) return;
    await AppHaptics.selection();
    final result = await ApiService.setPrimaryBankAccount(account.id);
    if (!mounted) return;
    if (result['success'] == true) {
      _snack('${account.bankName} set as primary', isError: false);
      await _load();
    } else {
      _snack(result['error'] ?? 'Failed to update', isError: true);
    }
  }

  Future<void> _delete(BankAccount account) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove account?'),
        content: Text(
            'Remove ${account.bankName} ending in ${account.maskedNumber}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: TextStyle(color: cs.onSurfaceVariant))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Remove',
                  style: TextStyle(color: AppColors.danger(context)))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await ApiService.deleteBankAccount(account.id);
    if (!mounted) return;
    if (result['success'] == true) {
      _snack('Account removed', isError: false);
      await _load();
    } else {
      _snack(result['error'] ?? 'Failed to remove', isError: true);
    }
  }

  void _showDetail(BankAccount account) {
    AppHaptics.selection();
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AccountDetailSheet(
        account: account,
        onSetPrimary: () {
          Navigator.pop(context);
          _setPrimary(account);
        },
        onDelete: () {
          Navigator.pop(context);
          _delete(account);
        },
        onCopy: () {
          Clipboard.setData(ClipboardData(text: account.accountNumber));
          _snack('Account number copied', isError: false);
        },
      ),
    );
  }

  Future<void> _showAddSheet() async {
    await AppHaptics.selection();
    if (!mounted) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBankAccountSheet(existingCount: _accounts.length),
    );

    if (result == true && mounted) {
      _snack('Bank account added', isError: false);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: LiquidityRefreshIndicator(
        onRefresh: () async { await AppHaptics.selection(); await _load(); },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            // App bar
            AppLogoHeader(
              title: 'Bank Accounts',
            ),

            if (_isLoading)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator())),

            if (_error != null && !_isLoading)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          size: 48,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text(_error!,
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 15)),
                      const SizedBox(height: 12),
                      TextButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                ),
              ),

            if (!_isLoading && _error == null) ...[
              // Section: All banks
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: Text(
                    'All banks (${_accounts.length})',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Bank card grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.05,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      // Last card = "Add new bank"
                      if (index == _accounts.length) {
                        return _AddBankCard(
                          enabled: _accounts.length < 5,
                          onTap: _accounts.length < 5
                              ? _showAddSheet
                              : () => _snack(
                              'Maximum 5 accounts allowed',
                              isError: true),
                        );
                      }
                      final account = _accounts[index];
                      return _BankCard(
                        account: account,
                        onTap: () => _showDetail(account),
                      );
                    },
                    childCount: _accounts.length + 1,
                  ),
                ),
              ),

              // Empty state hint
              if (_accounts.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline_rounded,
                            color: cs.primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Add a bank account to receive withdrawals and investment payouts.',
                            style: TextStyle(
                                color: cs.onSurface, fontSize: 12),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BANK CARD — Groww-style grid card
// ═══════════════════════════════════════════════════════════════════════════════

class _BankCard extends StatelessWidget {
  final BankAccount account;
  final VoidCallback onTap;

  const _BankCard({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: account.isPrimary
                ? cs.primary.withValues(alpha: 0.3)
                : cs.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Primary badge + icon row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (account.isPrimary)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Primary',
                        style: TextStyle(
                            color: cs.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  )
                else
                  const SizedBox.shrink(),
                Icon(Icons.chevron_right_rounded,
                    size: 16,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
              ],
            ),

            const Spacer(),

            // Bank icon
            Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: account.brandColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.account_balance_rounded,
                    color: account.brandColor, size: 22),
              ),
            ),

            const Spacer(),

            // Bank name
            Center(
              child: Text(
                account.bankName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Masked number
            Center(
              child: Text(
                account.maskedNumber,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
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
}

// ═══════════════════════════════════════════════════════════════════════════════
// ADD BANK CARD — dashed border + icon
// ═══════════════════════════════════════════════════════════════════════════════

class _AddBankCard extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _AddBankCard({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.3),
            // Dashed effect via a thin border — Flutter doesn't support
            // dashed borders natively, so we use a subtle outline
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              'Add new bank',
              style: TextStyle(
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACCOUNT DETAIL SHEET — shows full details on tap
// ═══════════════════════════════════════════════════════════════════════════════

class _AccountDetailSheet extends StatelessWidget {
  final BankAccount account;
  final VoidCallback onSetPrimary;
  final VoidCallback onDelete;
  final VoidCallback onCopy;

  const _AccountDetailSheet({
    required this.account,
    required this.onSetPrimary,
    required this.onDelete,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bank icon + name
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: account.brandColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.account_balance_rounded,
                color: account.brandColor, size: 26),
          ),
          const SizedBox(height: 12),
          Text(account.bankName.toUpperCase(),
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
          const SizedBox(height: 4),
          if (account.isPrimary)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Primary bank',
                    style: TextStyle(
                        color: cs.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(Icons.info_outline_rounded,
                    color: cs.primary, size: 12),
              ]),
            ),
          const SizedBox(height: 20),

          // Details card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.15)),
            ),
            child: Column(children: [
              _DetailRow(
                  label: 'Account number', value: account.maskedNumber),
              _dottedDivider(cs),
              _DetailRow(label: 'IFSC Code', value: account.ifscCode),
              _dottedDivider(cs),
              if (account.branchAddress.isNotEmpty) ...[
                _DetailRow(
                    label: 'Bank branch', value: account.branchAddress),
                _dottedDivider(cs),
              ],
              if (account.beneficiaryName.isNotEmpty)
                _DetailRow(
                    label: 'Beneficiary', value: account.beneficiaryName),
            ]),
          ),
          const SizedBox(height: 20),

          // Actions
          Row(children: [
            if (!account.isPrimary)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSetPrimary,
                  icon: Icon(Icons.star_rounded,
                      size: 16, color: AppColors.warning(context)),
                  label: Text('Set Primary',
                      style: TextStyle(color: AppColors.warning(context))),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color:
                        AppColors.warning(context).withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            if (!account.isPrimary) const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCopy,
                icon: Icon(Icons.copy_rounded, size: 16, color: cs.primary),
                label: Text('Copy', style: TextStyle(color: cs.primary)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: cs.primary.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline_rounded,
                  size: 16, color: cs.error),
              label: Text('Remove account',
                  style: TextStyle(color: cs.error, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dottedDivider(ColorScheme cs) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: List.generate(
        40,
            (_) => Expanded(
          child: Container(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.2),
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
          ),
        ),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(
              color: cs.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ADD BANK ACCOUNT SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _AddBankAccountSheet extends StatefulWidget {
  final int existingCount;
  const _AddBankAccountSheet({required this.existingCount});

  @override
  State<_AddBankAccountSheet> createState() => _AddBankAccountSheetState();
}

class _AddBankAccountSheetState extends State<_AddBankAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _confirmAccountCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _beneficiaryCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  bool _isPrimary = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingCount == 0) _isPrimary = true;
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _confirmAccountCtrl.dispose();
    _ifscCtrl.dispose();
    _beneficiaryCtrl.dispose();
    _branchCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

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
        if (mounted) Navigator.pop(context, true);
      } else {
        await AppHaptics.error();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result['error'] ?? 'Failed to add account'),
            backgroundColor: AppColors.danger(context)));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Connection error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Add Bank Account',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text('Enter your bank details for payouts',
                  style:
                  TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
              const SizedBox(height: 24),
              _field(_bankNameCtrl, 'Bank Name',
                  Icons.account_balance_rounded,
                  validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 14),
              _field(_accountNumberCtrl, 'Account Number',
                  Icons.numbers_rounded,
                  keyboard: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (v.trim().length < 8) return 'Too short';
                    return null;
                  }),
              const SizedBox(height: 14),
              _field(_confirmAccountCtrl, 'Confirm Account Number',
                  Icons.numbers_rounded,
                  keyboard: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (v.trim() != _accountNumberCtrl.text.trim()) {
                      return 'Account numbers do not match';
                    }
                    return null;
                  }),
              const SizedBox(height: 14),
              _field(_ifscCtrl, 'IFSC Code', Icons.code_rounded,
                  capitalization: TextCapitalization.characters,
                  maxLength: 11,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (v.trim().length != 11) return 'Must be 11 characters';
                    return null;
                  }),
              const SizedBox(height: 14),
              _field(_beneficiaryCtrl, 'Beneficiary Name',
                  Icons.person_outline_rounded,
                  capitalization: TextCapitalization.words,
                  validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 14),
              _field(_branchCtrl, 'Branch Address',
                  Icons.location_on_outlined,
                  capitalization: TextCapitalization.sentences,
                  validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 16),
              if (widget.existingCount > 0)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Set as primary account',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface)),
                  subtitle: Text('Used for withdrawals and payouts',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                  value: _isPrimary,
                  onChanged: (v) => setState(() => _isPrimary = v),
                  activeThumbColor: cs.primary,
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    disabledBackgroundColor:
                    cs.primary.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                      : const Text('Add Account',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
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
        List<TextInputFormatter>? formatters,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      textCapitalization: capitalization,
      maxLength: maxLength,
      inputFormatters: formatters,
      validator: validator,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon,
            color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
        counterText: '',
      ),
    );
  }
}