import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/main.dart';
import 'package:invoice_discounting_app/models/nominee.dart';
import 'package:invoice_discounting_app/screens/add_nominee_screen.dart';
import 'package:invoice_discounting_app/screens/bank_accounts_screen.dart';
import 'package:invoice_discounting_app/screens/change_password_screen.dart';
import 'package:invoice_discounting_app/screens/login_screen.dart';
import 'package:invoice_discounting_app/screens/personal_details_screen.dart';
import 'package:invoice_discounting_app/screens/profile/widgets/app_bar_widgets.dart';
import 'package:invoice_discounting_app/screens/profile/widgets/hero_section.dart';
import 'package:invoice_discounting_app/screens/profile/widgets/menu_widgets.dart';
import 'package:invoice_discounting_app/screens/profile/widgets/sign_out_button.dart';
import 'package:invoice_discounting_app/screens/profile/widgets/stats_row.dart';
import 'package:invoice_discounting_app/screens/profile/widgets/status_widgets.dart';
import 'package:invoice_discounting_app/screens/profile_webview_screen.dart';
import 'package:invoice_discounting_app/screens/settings_screen.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/services/portfolio_cache.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';
import 'package:invoice_discounting_app/widgets/liquidity_refresh_indicator.dart';
import 'package:invoice_discounting_app/widgets/pressable.dart';
import 'package:invoice_discounting_app/widgets/skeleton.dart';
import 'package:invoice_discounting_app/widgets/stagger_list.dart';
import 'package:invoice_discounting_app/widgets/vibe_state_wrapper.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with RouteAware, TickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _portfolio;
  Map<String, dynamic>? _nominee;
  List<Map<String, dynamic>> _bankAccounts = [];
  bool _isLoading = true;
  bool _hasError = false;

  double _totalInvested = 0;
  double _totalReturns = 0;
  int _activeCount = 0;
  double _avgReturn = 0;

  static const String _supportEmail = 'lakhiwal43@gmail.com';
  static const String _appVersion = '1.0.0';

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();
    _loadAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() => _loadAll(forceRefresh: false);

  Future<void> _loadAll({bool forceRefresh = true, bool silent = false}) async {
    if (!mounted) return;
    final startTime = DateTime.now();

    if (!silent) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final results = await Future.wait([
        ApiService.getProfile(forceRefresh: forceRefresh),
        PortfolioCache.getPortfolio(forceRefresh: forceRefresh),
        ApiService.getBankAccounts(forceRefresh: forceRefresh),
        ApiService.getNominee(forceRefresh: forceRefresh),
      ]);

      if (!mounted) return;

      // Ensure the "Syncing" state is visible for a premium feel
      if (forceRefresh) {
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        if (elapsed < 800) {
          await Future.delayed(Duration(milliseconds: 800 - elapsed));
        }
      }

      final profile = results[0] as Map<String, dynamic>?;
      final portfolio = results[1] as Map<String, dynamic>?;
      final bankAccounts = results[2]! as List<Map<String, dynamic>>;
      final nominee = results[3] as Map<String, dynamic>?;

      final summary = portfolio?['summary'];
      final totalInvested =
          double.tryParse(summary?['total_invested']?.toString() ?? '0') ?? 0;
      final totalReturns =
          double.tryParse(summary?['total_returns']?.toString() ?? '0') ?? 0;
      final activeCount = (summary?['active_count'] as num?)?.toInt() ?? 0;
      final avgReturn =
          totalInvested > 0 ? (totalReturns / totalInvested) * 100 : 0.0;

      setState(() {
        _profile = profile;
        _portfolio = portfolio;
        _bankAccounts = bankAccounts;
        _nominee = nominee;
        _totalInvested = totalInvested;
        _totalReturns = totalReturns;
        _activeCount = activeCount;
        _avgReturn = avgReturn;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _refreshProfile() async {
    await _loadAll(silent: true);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatKycStatus(String? status) => switch (status) {
        'draft' => 'Not Submitted',
        'submitted' => 'Under Review',
        'approved' => 'Verified',
        'rejected' => 'Rejected',
        _ => 'Unknown',
      };

  bool get _isKycVerified => _profile?['profile_status'] == 'approved';

  List<(String label, bool done)> get _journeySteps {
    final status = _profile?['profile_status'] ?? '';
    final hasPan = (_profile?['pan_number'] as String?)?.isNotEmpty ?? false;
    final hasBank = _bankAccounts.isNotEmpty;
    final hasInvested = _activeCount > 0 || _totalInvested > 0;

    return [
      ('Email', true),
      ('KYC', status == 'approved' || status == 'submitted'),
      ('PAN', hasPan),
      ('Bank', hasBank),
      ('Invested', hasInvested),
    ];
  }

  double get _journeyProgress {
    final steps = _journeySteps;
    final done = steps.where((s) => s.$2).length;
    return steps.isEmpty ? 0 : done / steps.length;
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    unawaited(AppHaptics.selection());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.success(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UI.radiusSm),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    unawaited(AppHaptics.selection());
    if (!mounted) return;

    final colorScheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UI.radiusMd),
        ),
        icon: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.danger(context).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            AppIcons.logout,
            color: AppColors.danger(context),
            size: 24,
          ),
        ),
        title: Text(
          'Sign out?',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          "You'll need to sign in again to access your account.",
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () async {
              unawaited(AppHaptics.buttonPress());
              Navigator.pop(ctx, true);
            },
            child: Text(
              'Sign Out',
              style: TextStyle(
                color: AppColors.danger(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) _performLogout();
  }

  Future<void> _performLogout() async {
    unawaited(AppHaptics.error());
    PortfolioCache.clear();

    unawaited(
      navigatorKey.currentState!.pushAndRemoveUntil(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, animation, __) =>
              FadeTransition(opacity: animation, child: const LoginScreen()),
        ),
        (route) => false,
      ),
    );

    unawaited(
      ApiService.logout().catchError((e) => debugPrint('Logout cleanup: $e')),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: LiquidityRefreshIndicator(
        onRefresh: () => _loadAll(silent: true),
        color: colorScheme.primary,
        child: VibeStateWrapper(
          state: _isLoading
              ? VibeState.loading
              : (_hasError ? VibeState.error : VibeState.success),
          onRetry: _loadAll,
          loadingSkeleton: CustomScrollView(
            physics: const NeverScrollableScrollPhysics(),
            slivers: [
              _buildAppBar(colorScheme),
              const SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: SkeletonProfileContent(),
                ),
              ),
            ],
          ),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              _buildAppBar(colorScheme),
              SliverToBoxAdapter(
                child: StaggerItem(
                  index: 0,
                  child: ProfileHeroSection(
                    profile: _profile,
                    isKycVerified: _isKycVerified,
                    journeySteps: _journeySteps,
                    journeyProgress: _journeyProgress,
                    onProfileUpdated: _refreshProfile,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: StaggerItem(
                  index: 1,
                  child: RepaintBoundary(
                    child: ProfileStatsRow(
                      totalInvested: _totalInvested,
                      avgReturn: _avgReturn,
                      activeCount: _activeCount,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(top: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    _buildSections(context)
                        .asMap()
                        .entries
                        .map(
                          (e) => StaggerItem(
                            index: e.key + 2,
                            child: RepaintBoundary(child: e.value),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(ColorScheme colorScheme) => SliverAppBar(
        pinned: true,
        toolbarHeight: 72,
        leadingWidth: 64,
        scrolledUnderElevation: 0.5,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        leading: const ProfileBackButton(),
        centerTitle: true,
        title: Text(
          'Profile',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          // ── Settings gear icon ──
          IconButton(
            onPressed: () async {
              unawaited(AppHaptics.selection());
              if (!mounted) return;
              unawaited(
                Navigator.push<void>(
                  context,
                  SmoothPageRoute<void>(builder: (_) => const SettingsScreen()),
                ),
              );
            },
            icon: Icon(
              AppIcons.settings,
              color: colorScheme.onSurfaceVariant,
              size: 22,
            ),
            tooltip: 'Settings',
          ),
          const SizedBox(width: 4),
        ],
      );

  List<Widget> _buildSections(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    String bankSubtitle;
    final primaryBank =
        _bankAccounts.where((b) => b['is_primary'] == true).toList();
    if (primaryBank.isNotEmpty) {
      final bankName = primaryBank.first['bank_name'] ?? '';
      final accNum = primaryBank.first['account_number']?.toString() ?? '';
      final masked = accNum.length > 4
          ? '····${accNum.substring(accNum.length - 4)}'
          : accNum;
      bankSubtitle = '$bankName $masked';
    } else if (_bankAccounts.isNotEmpty) {
      bankSubtitle =
          '${_bankAccounts.length} account${_bankAccounts.length > 1 ? 's' : ''} linked';
    } else {
      bankSubtitle = 'No accounts linked';
    }

    final nomineeName = _nominee?['name'] as String?;
    final nomineeRel = _nominee?['relationship'] as String?;
    final nomineeSubtitle = (nomineeName != null && nomineeName.isNotEmpty)
        ? '$nomineeName · ${nomineeRel ?? ''}'.trimRight()
        : 'Add or update nominee';

    return [
      if (!_isKycVerified)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(UI.radiusMd),
              border: Border.all(color: AppColors.warning(context).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(AppIcons.info, color: AppColors.warning(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile Approval Pending',
                        style: TextStyle(
                          color: AppColors.warning(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your profile is under review. Financial operations are restricted until approval is granted.',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      // ── Account ─────────────────────────────────────────────────
      const ProfileSectionHeader(label: 'Account'),
      ProfileCardGroup(
        children: [
          ProfileMenuItem(
            icon: AppIcons.user,
            iconColor: colorScheme.primary,
            iconBg: colorScheme.primary.withValues(alpha: 0.1),
            label: 'Personal details',
            subtitle: (_profile?['name'] as String?) ?? 'View your info',
            onTap: () async {
              unawaited(AppHaptics.selection());
              if (!mounted) return;
              unawaited(
                Navigator.of(context).push(
                  SmoothPageRoute<void>(
                    builder: (_) => PersonalDetailsScreen(
                      profile: _profile,
                      onProfileUpdated: _refreshProfile,
                    ),
                  ),
                ),
              );
            },
          ),
          ProfileMenuItem(
            icon: AppIcons.verifiedUser,
            iconColor: colorScheme.primary,
            iconBg: colorScheme.primary.withValues(alpha: 0.1),
            label: 'KYC & identity',
            trailing: ProfileStatusPill(
              label: _formatKycStatus(_profile?['profile_status'] as String?),
              color: _isKycVerified
                  ? AppColors.success(context)
                  : AppColors.warning(context),
            ),
            onTap: () async {
              unawaited(AppHaptics.selection());
              if (!mounted) return;
              try {
                final tokenResult = await ApiService.createWebviewToken();
                final token = tokenResult['token'] as String?;
                if (!mounted) return;
                if (token != null) {
                  unawaited(
                    Navigator.of(context).push(
                      SmoothPageRoute<void>(
                        builder: (_) => ProfileWebViewScreen(
                          token: token,
                          name: (_profile?['name'] as String?) ?? '',
                        ),
                      ),
                    ),
                  );
                }
              } catch (_) {}
            },
            onLongPress: (_profile?['pan_number'] as String?) != null
                ? () =>
                    _copyToClipboard(_profile!['pan_number'] as String, 'PAN')
                : null,
          ),
          ProfileMenuItem(
            icon: AppIcons.bank,
            iconColor: _bankAccounts.isEmpty
                ? AppColors.warning(context)
                : colorScheme.primary,
            iconBg: _bankAccounts.isEmpty
                ? AppColors.warning(context).withValues(alpha: 0.1)
                : colorScheme.primary.withValues(alpha: 0.1),
            label: 'Bank accounts',
            subtitle: bankSubtitle,
            trailing: _bankAccounts.isEmpty
                ? ProfileStatusPill(
                    label: 'Required',
                    color: AppColors.warning(context),
                  )
                : null,
            onTap: () async {
              unawaited(AppHaptics.selection());
              if (!mounted) return;
              unawaited(
                Navigator.of(context).push(
                  SmoothPageRoute<void>(
                    builder: (_) => const BankAccountsScreen(),
                  ),
                ),
              );
            },
          ),
          ProfileMenuItem(
            icon: AppIcons.userBold, // Nominee/People variant
            iconColor: _nominee == null
                ? AppColors.warning(context)
                : colorScheme.primary,
            iconBg: _nominee == null
                ? AppColors.warning(context).withValues(alpha: 0.1)
                : colorScheme.primary.withValues(alpha: 0.1),
            label: 'Nominee',
            subtitle: nomineeSubtitle,
            trailing: _nominee == null
                ? ProfileStatusPill(
                    label: 'Add',
                    color: AppColors.warning(context),
                  )
                : null,
            onTap: () async {
              unawaited(AppHaptics.selection());
              if (!mounted) return;
              final nominee =
                  _nominee != null ? Nominee.fromMap(_nominee!) : null;
              final navigator = Navigator.of(context);
              final updated = await navigator.push<bool>(
                SmoothPageRoute<bool>(
                  builder: (_) => AddNomineeScreen(nominee: nominee),
                ),
              );
              if (updated == true) {
                await _loadAll(silent: true);
              }
            },
          ),
          ProfileMenuItem(
            icon: AppIcons.password,
            iconColor: AppColors.warning(context),
            iconBg: AppColors.warning(context).withValues(alpha: 0.1),
            label: 'Change password',
            onTap: () async {
              unawaited(AppHaptics.selection());
              if (!mounted) return;
              unawaited(
                Navigator.of(context).push(
                  SmoothPageRoute<void>(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      const SizedBox(height: UI.lg),

      // ── Footer: support / terms / version ─────────────────────
      const _FooterLinks(
        supportEmail: _supportEmail,
        appVersion: _appVersion,
      ),
      const SizedBox(height: UI.md),

      // ── Sign out ──────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ProfileSignOutButton(onTap: _confirmLogout),
      ),
      const SizedBox(height: 100),
    ];
  }
}

// ── Footer links row ────────────────────────────────────────────────────────

class _FooterLinks extends ConsumerWidget {
  const _FooterLinks({
    required this.supportEmail,
    required this.appVersion,
  });
  final String supportEmail;
  final String appVersion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _FooterButton(
            icon: AppIcons.mail,
            label: 'Support',
            onTap: () {
              unawaited(AppHaptics.selection());
              unawaited(
                launchUrl(
                  Uri.parse('mailto:$supportEmail?subject=Finworks360 Support'),
                ),
              );
            },
          ),
          Container(
            width: 0.5,
            height: 16,
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
          _FooterButton(
            icon: AppIcons.description,
            label: 'Terms',
            onTap: () {
              unawaited(AppHaptics.selection());
              unawaited(
                launchUrl(
                  Uri.parse('https://finworks360.com/terms-and-conditions/'),
                  mode: LaunchMode.externalApplication,
                ),
              );
            },
          ),
          Container(
            width: 0.5,
            height: 16,
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
          _FooterButton(
            icon: AppIcons.info,
            label: 'v$appVersion',
            onTap: () {
              unawaited(AppHaptics.selection());
            },
          ),
        ],
      ),
    );
  }
}

class _FooterButton extends ConsumerWidget {
  const _FooterButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
