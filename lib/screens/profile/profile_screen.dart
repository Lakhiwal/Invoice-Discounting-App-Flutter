import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/portfolio_cache.dart';
import '../../theme/theme_provider.dart';
import '../../theme/ui_constants.dart';
import '../../utils/app_haptics.dart';
import '../../widgets/liquidity_refresh_indicator.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/stagger_list.dart';
import '../bank_accounts_screen.dart';
import '../change_password_screen.dart';
import '../login_screen.dart';
import '../nominee_screen.dart';
import '../personal_details_screen.dart';
import '../profile_webview_screen.dart';
import '../settings_screen.dart';
import '../../widgets/pressable.dart';

import 'widgets/hero_section.dart';
import 'widgets/stats_row.dart';
import 'widgets/menu_widgets.dart';
import 'widgets/status_widgets.dart';
import 'widgets/app_bar_widgets.dart';
import 'widgets/sign_out_button.dart';
import 'widgets/profile_skeleton.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
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

  late final AnimationController _crossfadeCtrl;
  late final Animation<double> _skeletonOpacity;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();

    _crossfadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _skeletonOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _crossfadeCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _crossfadeCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _crossfadeCtrl,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

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
    _crossfadeCtrl.dispose();
    super.dispose();
  }

  @override
  void didPopNext() => _refreshProfile();

  Future<void> _loadAll() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    _crossfadeCtrl.reset();

    // Let the route transition finish smoothly before parsing
    await Future.delayed(const Duration(milliseconds: 250));

    try {
      final results = await Future.wait([
        ApiService.getProfile(),
        PortfolioCache.getPortfolio(),
        ApiService.getBankAccounts(),
        ApiService.getNominee(),
      ]);

      if (!mounted) return;

      final profile = results[0] as Map<String, dynamic>?;
      final portfolio = results[1] as Map<String, dynamic>?;
      final bankAccounts = results[2] as List<Map<String, dynamic>>;
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

      _crossfadeCtrl.forward();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  bool _refreshing = false;

  Future<void> _refreshProfile() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final results = await Future.wait([
        ApiService.getProfile(),
        ApiService.getBankAccounts(),
        ApiService.getNominee(),
      ]);

      if (!mounted) return;
      setState(() {
        _profile = results[0] as Map<String, dynamic>?;
        _bankAccounts = results[1] as List<Map<String, dynamic>>;
        _nominee = results[2] as Map<String, dynamic>?;
      });
    } catch (e) {
      debugPrint('Profile refresh error: $e');
    }
    _refreshing = false;
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
    AppHaptics.selection();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$label copied'),
      duration: const Duration(seconds: 2),
      backgroundColor: AppColors.success(context),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UI.radiusSm)),
    ));
  }

  Future<void> _confirmLogout() async {
    await AppHaptics.selection();
    if (!mounted) return;

    final colorScheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UI.radiusMd)),
        icon: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.danger(context).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.logout_rounded,
              color: AppColors.danger(context), size: 24),
        ),
        title: Text('Sign out?',
            style: TextStyle(
                color: colorScheme.onSurface, fontWeight: FontWeight.w700)),
        content: Text(
            'You\'ll need to sign in again to access your account.',
            style:
            TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: colorScheme.onSurfaceVariant))),
          TextButton(
            onPressed: () async {
              await AppHaptics.buttonPress();
              Navigator.pop(ctx, true);
            },
            child: Text('Sign Out',
                style: TextStyle(
                    color: AppColors.danger(context),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) _performLogout();
  }

  Future<void> _performLogout() async {
    await AppHaptics.error();
    PortfolioCache.clear();

    navigatorKey.currentState!.pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, animation, __) =>
            FadeTransition(opacity: animation, child: const LoginScreen()),
      ),
          (route) => false,
    );

    ApiService.logout().catchError((e) => debugPrint('Logout cleanup: $e'));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_hasError && !_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: ProfileErrorState(onRetry: _loadAll),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          if (!_isLoading)
            LiquidityRefreshIndicator(
              onRefresh: _loadAll,
              color: colorScheme.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
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
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate(
                            _buildSections(context)
                                .asMap()
                                .entries
                                .map((e) => StaggerItem(
                              index: e.key + 2,
                              child: RepaintBoundary(child: e.value),
                            ))
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            if (_isLoading || _crossfadeCtrl.isAnimating)
              IgnorePointer(
                ignoring: !_isLoading,
                child: _isLoading 
                    ? _buildSkeletonUi(colorScheme) 
                    : FadeTransition(
                        opacity: _skeletonOpacity,
                        child: _buildSkeletonUi(colorScheme),
                      ),
              ),
          ],
        ),
      );
  }

  Widget _buildSkeletonUi(ColorScheme colorScheme) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        _buildAppBar(colorScheme),
        SliverToBoxAdapter(
          child: RepaintBoundary(
            child: SkeletonProfileContent(),
          ),
        ),
      ],
    );
  }

  SliverAppBar _buildAppBar(ColorScheme colorScheme) {
    return SliverAppBar(
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
            await AppHaptics.selection();
            if (!mounted) return;
            Navigator.push(
              context,
              SmoothPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          icon: Icon(
            Icons.settings_outlined,
            color: colorScheme.onSurfaceVariant,
            size: 22,
          ),
          tooltip: 'Settings',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

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
    final String nomineeSubtitle =
    (nomineeName != null && nomineeName.isNotEmpty)
        ? '$nomineeName · ${nomineeRel ?? ''}'.trimRight()
        : 'Add or update nominee';

    return [
      // ── Account ─────────────────────────────────────────────────
      const ProfileSectionHeader(label: 'Account'),
      ProfileCardGroup(children: [
        ProfileMenuItem(
          icon: Icons.person_outline_rounded,
          iconColor: colorScheme.primary,
          iconBg: colorScheme.primary.withValues(alpha: 0.1),
          label: 'Personal details',
          subtitle: _profile?['name'] ?? 'View your info',
          onTap: () async {
            await AppHaptics.selection();
            Navigator.of(context, rootNavigator: false).push(
              SmoothPageRoute(
                builder: (_) => PersonalDetailsScreen(
                  profile: _profile,
                  onProfileUpdated: _refreshProfile,
                ),
              ),
            );
          },
        ),
        ProfileMenuItem(
          icon: Icons.verified_user_outlined,
          iconColor: colorScheme.primary,
          iconBg: colorScheme.primary.withValues(alpha: 0.1),
          label: 'KYC & identity',
          trailing: ProfileStatusPill(
              label: _formatKycStatus(_profile?['profile_status']),
              color: _isKycVerified
                  ? AppColors.success(context)
                  : AppColors.warning(context)),
          onTap: () async {
            await AppHaptics.selection();
            if (!mounted) return;
            try {
              final tokenResult = await ApiService.createWebviewToken();
              final token = tokenResult['token'] as String?;
              if (!mounted) return;
              if (token != null) {
                Navigator.of(context, rootNavigator: false).push(
                    SmoothPageRoute(
                        builder: (_) => ProfileWebViewScreen(
                            token: token,
                            name: _profile?['name'] ?? '')));
              }
            } catch (_) {}
          },
          onLongPress: _profile?['pan_number'] != null
              ? () => _copyToClipboard(_profile!['pan_number'], 'PAN')
              : null,
        ),
        ProfileMenuItem(
          icon: Icons.account_balance_outlined,
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
              label: 'Required', color: AppColors.warning(context))
              : null,
          onTap: () async {
            await AppHaptics.selection();
            Navigator.of(context, rootNavigator: false).push(
                SmoothPageRoute(builder: (_) => const BankAccountsScreen()));
          },
        ),
        ProfileMenuItem(
          icon: Icons.people_outline_rounded,
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
              label: 'Add', color: AppColors.warning(context))
              : null,
          onTap: () async {
            await AppHaptics.selection();
            Navigator.of(context, rootNavigator: false)
                .push(SmoothPageRoute(builder: (_) => const NomineeScreen()));
          },
        ),
        ProfileMenuItem(
          icon: Icons.lock_outline_rounded,
          iconColor: AppColors.warning(context),
          iconBg: AppColors.warning(context).withValues(alpha: 0.1),
          label: 'Change password',
          onTap: () async {
            await AppHaptics.selection();
            Navigator.of(context, rootNavigator: false).push(
                SmoothPageRoute(builder: (_) => const ChangePasswordScreen()));
          },
        ),
      ]),
      const SizedBox(height: UI.lg),

      // ── Footer: support / terms / version ─────────────────────
      _FooterLinks(
        supportEmail: _supportEmail,
        appVersion: _appVersion,
      ),
      const SizedBox(height: UI.md),

      // ── Sign out ──────────────────────────────────────────────
      ProfileSignOutButton(onTap: _confirmLogout),
      const SizedBox(height: 100),
    ];
  }
}

// ── Footer links row ────────────────────────────────────────────────────────

class _FooterLinks extends StatelessWidget {
  final String supportEmail;
  final String appVersion;

  const _FooterLinks({
    required this.supportEmail,
    required this.appVersion,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _FooterButton(
          icon: Icons.mail_outline_rounded,
          label: 'Support',
          onTap: () {
            AppHaptics.selection();
            launchUrl(Uri.parse(
                'mailto:$supportEmail?subject=Finworks360 Support'));
          },
        ),
        Container(
          width: 0.5,
          height: 16,
          color: cs.outlineVariant.withValues(alpha: 0.3),
        ),
        _FooterButton(
          icon: Icons.description_outlined,
          label: 'Terms',
          onTap: () {
            AppHaptics.selection();
            launchUrl(
                Uri.parse('https://finworks360.com/terms-and-conditions/'),
                mode: LaunchMode.externalApplication);
          },
        ),
        Container(
          width: 0.5,
          height: 16,
          color: cs.outlineVariant.withValues(alpha: 0.3),
        ),
        _FooterButton(
          icon: Icons.info_outline_rounded,
          label: 'v$appVersion',
          onTap: () {},
        ),
      ],
    );
  }
}

class _FooterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FooterButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  size: 14),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}