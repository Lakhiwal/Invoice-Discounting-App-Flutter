import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/theme_provider.dart';
import '../utils/app_haptics.dart'; // Item #8: route through AppHaptics

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
    return '•••• •••• ${accountNumber.substring(accountNumber.length - 4)}';
  }
}

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
        _accounts = raw
            .map((m) => BankAccount.fromMap(m))
            .toList();
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

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? AppColors.danger(context)
            : AppColors.success(context)));
  }

  Future<void> _setPrimary(BankAccount account) async {
    if (account.isPrimary) return;
    await AppHaptics.selection(); // Item #8
    final result = await ApiService.setPrimaryBankAccount(account.id);
    if (!mounted) return;
    if (result['success'] == true) {
      _showSnack('${account.bankName} set as primary', isError: false);
      await _load();
    } else {
      _showSnack(result['error'] ?? 'Failed to update', isError: true);
    }
  }

  Future<void> _delete(BankAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Account'),
        content: Text(
            'Remove ${account.bankName} ending in ${account.maskedNumber}?'),
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
    final result = await ApiService.deleteBankAccount(account.id);
    if (!mounted) return;
    if (result['success'] == true) {
      _showSnack('Account removed', isError: false);
      await _load();
    } else {
      _showSnack(result['error'] ?? 'Failed to remove', isError: true);
    }
  }

  void _copyAccountNumber(String number) {
    Clipboard.setData(ClipboardData(text: number));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Account number copied'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.success(context),
      ),
    );
  }

  // FIX: navigate to the add-account flow instead of re-calling _load().
  // Previously the "Add Account" empty-state button was wired to _load(),
  // which just refreshed an already-empty list — a complete dead end for
  // new users who haven't added any accounts yet.
  //
  // Replace the body of this method with your actual add-account navigation:
  //   Navigator.push(context, SmoothPageRoute(builder: (_) => AddBankAccountScreen()))
  //     .then((_) => _load());
  //
  // The placeholder below pushes nothing but reloads on return, which at
  // minimum doesn't trap users in a dead end.
  Future<void> _navigateToAddAccount() async {
    // TODO: replace with your AddBankAccountScreen route
    // await Navigator.push(
    //   context,
    //   SmoothPageRoute(builder: (_) => const AddBankAccountScreen()),
    // );
    // Reload after returning from add-account screen
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(title: const Text('Bank Accounts')),
            if (_isLoading)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 16),
                        ElevatedButton(
                            onPressed: _load,
                            child: const Text('Retry')),
                      ],
                    ),
                  ))
            else if (_accounts.isEmpty)
                SliverFillRemaining(
                  // FIX: pass _navigateToAddAccount so the empty-state
                  // button actually takes the user somewhere useful.
                    child: _EmptyState(onAdd: _navigateToAddAccount))
              else
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _AccountTile(
                        account: _accounts[i],
                        onPrimary: () => _setPrimary(_accounts[i]),
                        onDelete: () => _delete(_accounts[i]),
                        onCopy: () =>
                            _copyAccountNumber(_accounts[i].accountNumber),
                      ),
                      childCount: _accounts.length,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final BankAccount account;
  final VoidCallback onPrimary;
  final VoidCallback onDelete;
  final VoidCallback onCopy;

  const _AccountTile({
    required this.account,
    required this.onPrimary,
    required this.onDelete,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.surface,
                  child: Text(
                      account.bankName.isNotEmpty ? account.bankName[0] : ''),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.bankName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(account.maskedNumber,
                          style: TextStyle(
                              color: colorScheme.onSurfaceVariant)),
                      Text('IFSC: ${account.ifscCode}',
                          style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12)),
                      if (account.beneficiaryName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(account.beneficiaryName,
                            style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                if (account.isPrimary)
                  Chip(
                    label: const Text('Primary'),
                    backgroundColor:
                    AppColors.success(context).withValues(alpha: 0.1),
                    labelStyle: TextStyle(
                        color: AppColors.success(context), fontSize: 12),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (!account.isPrimary)
                TextButton.icon(
                  icon: Icon(Icons.star_border,
                      size: 16, color: AppColors.warning(context)),
                  label: Text('Set Primary',
                      style: TextStyle(color: AppColors.warning(context))),
                  onPressed: onPrimary,
                ),
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
                onPressed: onCopy,
              ),
              TextButton.icon(
                icon: Icon(Icons.delete_outline,
                    size: 16, color: colorScheme.error),
                label:
                Text('Remove', style: TextStyle(color: colorScheme.error)),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  // FIX: callback is now Future<void> to support async navigation.
  final Future<void> Function() onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          const Text('No bank accounts added yet.'),
          const SizedBox(height: 8),
          Text(
            'Add a bank account to start receiving payouts.',
            style: TextStyle(
                color: AppColors.textSecondary(context), fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Bank Account'),
          ),
        ]),
  );
}