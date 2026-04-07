import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/bank_account.dart';
import '../services/api_service.dart';
import '../theme/theme_provider.dart';
import '../utils/app_haptics.dart';
import '../utils/smooth_page_route.dart';
import '../widgets/app_logo_header.dart';
import '../widgets/liquidity_refresh_indicator.dart';
import '../widgets/skeleton.dart';
import 'add_bank_account_screen.dart';
import 'account_details_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Screen ───────────────────────────────────────────────────────────────────

class BankAccountsScreen extends ConsumerStatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  ConsumerState<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends ConsumerState<BankAccountsScreen> {
  List<BankAccount> _accounts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false, bool silent = false}) async {
    final startTime = DateTime.now();

    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final raw = await ApiService.getBankAccounts(forceRefresh: forceRefresh);
      
      // Ensure the "Syncing" state is visible for a premium feel
      if (forceRefresh) {
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        if (elapsed < 800) {
          await Future.delayed(Duration(milliseconds: 800 - elapsed));
        }
      }

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

  Future<void> _goToAdd() async {
    await AppHaptics.selection();
    if (_accounts.length >= 5) {
      _snack('Maximum 5 accounts allowed', isError: true);
      return;
    }
    
    if (!mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddBankAccountScreen(existingCount: _accounts.length),
      ),
    );

    if (result == true && mounted) {
      _snack('Bank account added', isError: false);
      _load();
    }
  }

  Future<void> _goToDetail(BankAccount account) async {
    await AppHaptics.selection();
    if (!mounted) return;
    final result = await Navigator.push<bool>(
      context,
      ParallaxSlidePageRoute(
        builder: (_) => AccountDetailsScreen(
          account: account,
          onRefresh: _load,
        ),
      ),
    );

    if (result == true && mounted) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: LiquidityRefreshIndicator(
        onRefresh: () => _load(forceRefresh: true, silent: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            // App bar
            AppLogoHeader(
              title: 'Bank Accounts',
            ),

            if (_isLoading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: const Padding(
                    key: ValueKey('loading'),
                    padding: EdgeInsets.all(24),
                    child: SkeletonBankAccountList(),
                  ),
                ),
              ),

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
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                ),
              ),

            if (!_isLoading && _error == null) ...[
              // Sticky "Add New" button for quick access
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cs.primary, cs.primaryContainer],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _goToAdd,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline_rounded,
                                  color: cs.primary, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Add New Bank Account',
                                style: TextStyle(
                                  color: cs.primary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Section Label
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Text(
                    'Your Verified Banks (${_accounts.length})',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              // Bank List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: _accounts.isEmpty
                    ? SliverToBoxAdapter(child: _EmptyState(onAdd: _goToAdd))
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final account = _accounts[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _BankListItem(
                                account: account,
                                onTap: () => _goToDetail(account),
                              ),
                            );
                          },
                          childCount: _accounts.length,
                        ),
                      ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// UI COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════════

class _BankListItem extends ConsumerWidget {
  final BankAccount account;
  final VoidCallback onTap;

  const _BankListItem({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final info = account.bankInfo;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: account.isPrimary
              ? cs.primary.withValues(alpha: 0.3)
              : cs.outlineVariant.withValues(alpha: 0.1),
          width: account.isPrimary ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (account.isPrimary)
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Bank Icon Container
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: account.logoUrl != null
                      ? SvgPicture.network(
                          account.logoUrl!,
                          placeholderBuilder: (_) => Icon(
                              Icons.account_balance_rounded,
                              color: info.brandColor),
                        )
                      : Icon(Icons.account_balance_rounded,
                          color: info.brandColor),
                ),
                const SizedBox(width: 16),

                // Details Area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.bankName,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            account.maskedNumber,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                                color: cs.onSurfaceVariant,
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            account.ifscCode,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Primary Badge or Arrow
                if (account.isPrimary)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'PRIMARY',
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                else
                  Icon(Icons.chevron_right_rounded,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.account_balance_rounded,
                color: cs.primary.withValues(alpha: 0.4), size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            'No Bank Accounts Yet',
            style: TextStyle(
                color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your bank account to receive withdrawals and investment payouts safely.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: onAdd,
            child: const Text('Add your first bank',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}