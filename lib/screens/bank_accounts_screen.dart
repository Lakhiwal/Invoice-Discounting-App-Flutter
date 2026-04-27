import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:invoice_discounting_app/models/bank_account.dart';
import 'package:invoice_discounting_app/screens/account_details_screen.dart';
import 'package:invoice_discounting_app/screens/add_bank_account_screen.dart';
import 'package:invoice_discounting_app/screens/profile/widgets/app_bar_widgets.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';
import 'package:invoice_discounting_app/widgets/liquidity_refresh_indicator.dart';
import 'package:invoice_discounting_app/widgets/skeleton.dart';

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
        _accounts = raw.map(BankAccount.fromMap).toList();
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

  void _copyAccountNumber(BankAccount account) {
    AppHaptics.selection();
    Clipboard.setData(ClipboardData(text: account.accountNumber));
    _snack('Account number copied', isError: false);
  }

  void _snack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? AppColors.danger(context) : AppColors.success(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _goToAdd() async {
    unawaited(AppHaptics.selection());
    if (_accounts.length >= 5) {
      _snack('Maximum 5 accounts allowed', isError: true);
      return;
    }

    if (!mounted) return;
    final success = await Navigator.of(context).push<bool>(
      SmoothPageRoute<bool>(
        builder: (_) => AddBankAccountScreen(existingCount: _accounts.length),
      ),
    );

    if (success == true && mounted) {
      _snack('Bank account added', isError: false);
      _load();
    }
  }

  Future<void> _goToDetail(BankAccount account) async {
    unawaited(AppHaptics.selection());
    if (!mounted) return;
    final success = await Navigator.of(context).push<bool>(
      SmoothPageRoute<bool>(
        builder: (_) => AccountDetailsScreen(
          account: account,
          onRefresh: _load,
        ),
      ),
    );

    if (success == true && mounted) {
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
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // App bar
            SliverAppBar(
              pinned: true,
              toolbarHeight: 72,
              leadingWidth: 64,
              scrolledUnderElevation: 0,
              backgroundColor: cs.surface,
              surfaceTintColor: Colors.transparent,
              leading: const ProfileBackButton(),
              centerTitle: true,
              title: Text(
                'Bank Accounts',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
              ),
            ),

            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: Padding(
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
                      Icon(
                        AppIcons.wifiOff,
                        size: 48,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
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
                      borderRadius: BorderRadius.circular(UI.radiusMd),
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
                      borderRadius: BorderRadius.circular(UI.radiusMd - 2),
                      child: InkWell(
                        onTap: _goToAdd,
                        borderRadius: BorderRadius.circular(UI.radiusMd - 2),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 20,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                AppIcons.addCircle,
                                color: cs.primary,
                                size: 20,
                              ),
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
                                onLongPress: () => _copyAccountNumber(account),
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
  const _BankListItem({
    required this.account,
    required this.onTap,
    this.onLongPress,
  });
  final BankAccount account;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final info = account.bankInfo;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(UI.radiusMd),
        border: Border.all(
          color: account.isPrimary
              ? cs.primary.withValues(alpha: 0.3)
              : cs.outlineVariant.withValues(alpha: 0.1),
          width: account.isPrimary ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: account.isPrimary ? 0.06 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(UI.radiusMd),
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
                    borderRadius: BorderRadius.circular(UI.radiusSm + 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: account.logoUrl != null
                      ? SvgPicture.network(
                          account.logoUrl!,
                          placeholderBuilder: (_) => Icon(
                            AppIcons.bank,
                            color: info.brandColor,
                          ),
                        )
                      : Icon(
                          AppIcons.bank,
                          color: info.brandColor,
                        ),
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
                              shape: BoxShape.circle,
                            ),
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
                      borderRadius: BorderRadius.circular(UI.radiusSm),
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
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(UI.radiusLg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(UI.radiusMd),
            ),
            child: Icon(
              AppIcons.bank,
              color: cs.primary.withValues(alpha: 0.4),
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Bank Accounts Yet',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
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
            child: const Text(
              'Add your first bank',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
