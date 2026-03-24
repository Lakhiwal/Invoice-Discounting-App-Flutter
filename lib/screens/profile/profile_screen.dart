import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../services/portfolio_cache.dart';
import '../../theme/theme_provider.dart';
import '../../theme/ui_constants.dart';
import '../../utils/app_haptics.dart';
import '../../utils/formatters.dart';
import '../../utils/vibration_helper.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/stagger_list.dart';
import '../bank_accounts_screen.dart';
import '../change_password_screen.dart';
import '../login_screen.dart';
import '../nominee_screen.dart';
import '../personal_details_screen.dart';
import '../profile_webview_screen.dart';
import '../transaction_history_screen.dart';

// ── Profile sub-widgets ─────────────────────────────────────────────────────
import 'widgets/hero_section.dart';
import 'widgets/stats_row.dart';
import 'widgets/menu_widgets.dart';
import 'widgets/status_widgets.dart';
import 'widgets/app_bar_widgets.dart';
import 'widgets/sign_out_button.dart';
import 'widgets/profile_skeleton.dart';
import 'sheets/selection_tile.dart';
import 'sheets/time_tile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with RouteAware, TickerProviderStateMixin {
  // ── State ─────────────────────────────────────────────────────────────────

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _portfolio;
  Map<String, dynamic>? _nominee;
  List<Map<String, dynamic>> _bankAccounts = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _pushEnabled = false;
  TimeOfDay? _quietStart;
  TimeOfDay? _quietEnd;
  VibrationLevel _vibrationLevel = VibrationLevel.normal;

  // Stats derived from portfolio
  double _totalInvested = 0;
  double _totalReturns = 0;
  int _activeCount = 0;
  double _avgReturn = 0;

  static const String _supportEmail = 'lakhiwal43@gmail.com';
  static const String _appVersion = '1.0.0';

  // Crossfade: skeleton fades out, loaded content fades in
  late final AnimationController _crossfadeCtrl;
  late final Animation<double> _skeletonOpacity;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _contentSlide;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _crossfadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    // Skeleton fades out during first 40%
    _skeletonOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _crossfadeCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Content fades in from 20%–100% (overlaps skeleton fade-out)
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _crossfadeCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    // Content slides up slightly as it appears
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

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    _crossfadeCtrl.reset();

    try {
      final results = await Future.wait([
        ApiService.getProfile(),
        PortfolioCache.getPortfolio(),
        ApiService.getBankAccounts(),
        ApiService.getNominee(),
        _loadPrefs(),
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

      // Crossfade: skeleton out → content in
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

  Future<void> _loadPrefs() async {
    final push = await NotificationService.isPushEnabled();
    final (start, end) = await NotificationService.getQuietHours();
    final vibLevel = await VibrationHelper.getLevel();
    await AppHaptics.refreshLevel();

    if (!mounted) return;
    setState(() {
      _pushEnabled = push;
      _quietStart = start;
      _quietEnd = end;
      _vibrationLevel = vibLevel;
    });
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

  // ── KYC helpers ───────────────────────────────────────────────────────────

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

  // ── Quiet hours helpers ───────────────────────────────────────────────────

  bool get _isOvernightRange {
    if (_quietStart == null || _quietEnd == null) return false;
    final s = _quietStart!.hour * 60 + _quietStart!.minute;
    final e = _quietEnd!.hour * 60 + _quietEnd!.minute;
    return s > e;
  }

  bool get _quietActiveNow {
    if (_quietStart == null || _quietEnd == null) return false;
    final now = TimeOfDay.now();
    final nowM = now.hour * 60 + now.minute;
    final s = _quietStart!.hour * 60 + _quietStart!.minute;
    final e = _quietEnd!.hour * 60 + _quietEnd!.minute;
    if (s <= e) return nowM >= s && nowM < e;
    return nowM >= s || nowM < e;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

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
            'You\'ll need to sign in again to access your account and investments.',
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

  Future<void> _handlePushToggle(bool v) async {
    await AppHaptics.selection();
    setState(() => _pushEnabled = v);

    if (v) {
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        setState(() => _pushEnabled = false);
        if (!mounted) return;
        await _showPermissionDialog();
        return;
      }
      await NotificationService.setPushEnabled(true);
    } else {
      NotificationService.revokePermission();
      await NotificationService.setPushEnabled(false);
    }
  }

  Future<void> _showPermissionDialog() async {
    final colorScheme = Theme.of(context).colorScheme;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UI.radiusMd)),
        title: const Text('Permission Required'),
        content: const Text(
            'Please enable notification permission from device settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(color: colorScheme.onSurfaceVariant))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await launchUrl(Uri.parse('app-settings:'));
            },
            child: Text('Open Settings',
                style: TextStyle(color: colorScheme.primary)),
          ),
        ],
      ),
    );
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

  // ── Bottom sheet helpers ──────────────────────────────────────────────────

  void _showSheet({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: UI.sheetRadius),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: UI.xs),
            Text(subtitle,
                style: TextStyle(
                    color: colorScheme.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  void _showThemePicker() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _showSheet(
      title: 'Appearance',
      subtitle: 'Choose your preferred theme',
      child: Column(children: [
        ProfileSelectionTile(
            icon: Icons.smartphone_rounded,
            label: 'System Default',
            subtitle: 'Follows your device setting',
            selected: themeProvider.mode == AppThemeMode.system,
            onTap: () async {
              await AppHaptics.selection();
              themeProvider.setMode(AppThemeMode.system);
              Navigator.pop(context);
            }),
        const SizedBox(height: 10),
        ProfileSelectionTile(
            icon: Icons.light_mode_rounded,
            label: 'Light Mode',
            subtitle: 'Clean white interface',
            selected: themeProvider.mode == AppThemeMode.light,
            onTap: () async {
              await AppHaptics.selection();
              themeProvider.setMode(AppThemeMode.light);
              Navigator.pop(context);
            }),
        const SizedBox(height: 10),
        ProfileSelectionTile(
            icon: Icons.dark_mode_rounded,
            label: 'Dark Mode',
            subtitle: 'Easy on the eyes at night',
            selected: themeProvider.mode == AppThemeMode.dark,
            onTap: () async {
              await AppHaptics.selection();
              themeProvider.setMode(AppThemeMode.dark);
              Navigator.pop(context);
            }),
      ]),
    );
  }

  void _showQuietHoursPicker() {
    _showSheet(
      title: 'Quiet Hours',
      subtitle: 'Notifications are silenced during this window',
      child: StatefulBuilder(
        builder: (ctx, setModal) {
          final hasQuiet = _quietStart != null && _quietEnd != null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileTimeTile(
                  label: 'From',
                  time: _quietStart,
                  onTap: () async {
                    await AppHaptics.selection();
                    final t = await showTimePicker(
                        context: context,
                        initialTime:
                            _quietStart ?? const TimeOfDay(hour: 22, minute: 0),
                        helpText: 'QUIET FROM');
                    if (t != null) {
                      setModal(() => _quietStart = t);
                      setState(() => _quietStart = t);
                    }
                  }),
              const SizedBox(height: 10),
              ProfileTimeTile(
                  label: 'Until',
                  time: _quietEnd,
                  onTap: () async {
                    await AppHaptics.selection();
                    final t = await showTimePicker(
                        context: context,
                        initialTime:
                            _quietEnd ?? const TimeOfDay(hour: 8, minute: 0),
                        helpText: 'QUIET UNTIL');
                    if (t != null) {
                      setModal(() => _quietEnd = t);
                      setState(() => _quietEnd = t);
                    }
                  }),
              if (hasQuiet) ...[
                const SizedBox(height: 14),
                if (_isOvernightRange)
                  ProfileInfoBanner(
                      icon: Icons.nightlight_round,
                      text: 'Spans overnight — ends the following morning',
                      color: AppColors.warning(context)),
                const SizedBox(height: UI.sm),
                ProfileInfoBanner(
                  icon: _quietActiveNow
                      ? Icons.notifications_off_rounded
                      : Icons.notifications_active_rounded,
                  text: _quietActiveNow
                      ? 'Quiet hours active right now'
                      : 'Quiet hours not active right now',
                  color: _quietActiveNow
                      ? AppColors.danger(context)
                      : AppColors.success(context),
                ),
              ],
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: hasQuiet
                        ? () async {
                            await AppHaptics.selection();
                            await NotificationService.setQuietHours(null, null);
                            setState(() {
                              _quietStart = null;
                              _quietEnd = null;
                            });
                            setModal(() {});
                            if (mounted) Navigator.pop(context);
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: AppColors.danger(context)
                                .withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(UI.radiusSm))),
                    child: Text('Clear',
                        style: TextStyle(color: AppColors.danger(context))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _quietStart != null && _quietEnd != null
                        ? () async {
                            await AppHaptics.selection();
                            await NotificationService.setQuietHours(
                                _quietStart, _quietEnd);
                            if (mounted) Navigator.pop(context);
                          }
                        : null,
                    child: const Text('Save'),
                  ),
                ),
              ]),
            ],
          );
        },
      ),
    );
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

    // Both skeleton and loaded content share the same app bar so there's
    // no jump. The Hero avatar exists in both branches so the fly animation
    // from home → profile works during route transition, and the crossfade
    // from skeleton → loaded is seamless.
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: AnimatedBuilder(
        animation: _crossfadeCtrl,
        builder: (context, _) {
          return Stack(
            children: [
              // ── Loaded content (fades in + slides up) ─────────────
              if (!_isLoading)
                RefreshIndicator(
                  onRefresh: _loadAll,
                  color: colorScheme.primary,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    slivers: [
                      _buildAppBar(colorScheme, showEdit: true),
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
                          child: ProfileStatsRow(
                            totalInvested: _totalInvested,
                            avgReturn: _avgReturn,
                            activeCount: _activeCount,
                            hideBalance:
                                Provider.of<ThemeProvider>(context).hideBalance,
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
                                      child: e.value,
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Skeleton (fades out when data loads) ──────────────
              if (_isLoading || _crossfadeCtrl.isAnimating)
                IgnorePointer(
                  ignoring: !_isLoading,
                  child: Opacity(
                    opacity: _isLoading ? 1.0 : _skeletonOpacity.value,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        _buildAppBar(colorScheme, showEdit: false),
                        SliverToBoxAdapter(
                          child: SkeletonProfileContent(),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Shared app bar for both skeleton and loaded branches —
  /// identical styling so there's no visual jump during crossfade.
  SliverAppBar _buildAppBar(ColorScheme colorScheme, {required bool showEdit}) {
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
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        if (showEdit)
          ProfileEditButton(onTap: () async {
            await AppHaptics.selection();
            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Opening profile…'),
                  duration: Duration(seconds: 2)),
            );

            try {
              final tokenResult = await ApiService.createWebviewToken();
              final token = tokenResult['token'] as String?;

              if (!mounted) return;

              if (token != null) {
                Navigator.of(context, rootNavigator: false).push(
                  SmoothPageRoute(
                      builder: (_) => ProfileWebViewScreen(
                          token: token, name: _profile?['name'] ?? '')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Could not open profile. Try again.')));
              }
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Connection error. Check your network.')));
            }
          }),
        const SizedBox(width: 8),
      ],
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);

    final themeLabel = switch (themeProvider.mode) {
      AppThemeMode.system => 'System default',
      AppThemeMode.light => 'Light mode',
      AppThemeMode.dark => 'Dark mode',
    };

    final String quietLabel;
    if (_quietStart != null && _quietEnd != null) {
      final range =
          '${_quietStart!.format(context)} – ${_quietEnd!.format(context)}';
      final active = _quietActiveNow ? ' · active now' : '';
      quietLabel = '$range$active';
    } else {
      quietLabel = 'Off';
    }

    String bankSubtitle;
    final primaryBank =
        _bankAccounts.where((b) => b['is_primary'] == true).toList();
    if (primaryBank.isNotEmpty) {
      final bankName = primaryBank.first['bank_name'] ?? '';
      final accNum = primaryBank.first['account_number']?.toString() ?? '';
      final masked = accNum.length > 4
          ? '····${accNum.substring(accNum.length - 4)}'
          : accNum;
      bankSubtitle = '$bankName $masked (primary)';
    } else if (_bankAccounts.isNotEmpty) {
      bankSubtitle =
          '${_bankAccounts.length} account${_bankAccounts.length > 1 ? 's' : ''} linked';
    } else {
      bankSubtitle = 'No accounts linked yet';
    }

    final nomineeName = _nominee?['name'] as String?;
    final nomineeRel = _nominee?['relationship'] as String?;
    final String nomineeSubtitle =
        (nomineeName != null && nomineeName.isNotEmpty)
            ? '$nomineeName · ${nomineeRel ?? ''}'.trimRight()
            : 'Add or update nominee';

    return [
      const ProfileSectionHeader(label: 'Account'),
      ProfileCardGroup(children: [
        ProfileMenuItem(
          icon: Icons.person_outline_rounded,
          iconColor: colorScheme.primary,
          iconBg: colorScheme.primaryContainer,
          label: 'Personal Details',
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
          iconBg: colorScheme.primaryContainer,
          label: 'KYC & Identity',
          subtitle: _formatKycStatus(_profile?['profile_status']),
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
                            token: token, name: _profile?['name'] ?? '')));
              }
            } catch (_) {}
          },
          onLongPress: _profile?['pan_number'] != null
              ? () => _copyToClipboard(_profile!['pan_number'], 'PAN number')
              : null,
        ),
        ProfileMenuItem(
          icon: Icons.account_balance_outlined,
          iconColor: _bankAccounts.isEmpty
              ? AppColors.warning(context)
              : colorScheme.primary,
          iconBg: _bankAccounts.isEmpty
              ? AppColors.warning(context).withValues(alpha: 0.12)
              : colorScheme.primaryContainer,
          label: 'Bank Accounts',
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
              ? AppColors.warning(context).withValues(alpha: 0.12)
              : colorScheme.primaryContainer,
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
        if (_profile?['mobile'] != null)
          ProfileMenuItem(
            icon: Icons.phone_outlined,
            iconColor: colorScheme.primary,
            iconBg: colorScheme.primaryContainer,
            label: 'Mobile',
            subtitle: _profile?['mobile'] ?? '',
            showChevron: false,
            onTap: () {},
            onLongPress: () =>
                _copyToClipboard(_profile!['mobile'], 'Mobile number'),
          ),
      ]),
      const SizedBox(height: UI.md),
      const ProfileSectionHeader(label: 'Preferences'),
      ProfileCardGroup(children: [
        ProfileToggleItem(
            icon: Icons.dark_mode_outlined,
            iconColor: colorScheme.onSurfaceVariant,
            iconBg: colorScheme.surfaceContainerHigh,
            label: 'Appearance',
            subtitle: themeLabel,
            onTap: () async {
              await AppHaptics.selection();
              _showThemePicker();
            }),
        ProfileSwitchItem(
            icon: Icons.notifications_outlined,
            iconColor: colorScheme.onSurfaceVariant,
            iconBg: colorScheme.surfaceContainerHigh,
            label: 'Push Notifications',
            subtitle: _pushEnabled ? 'New invoices · repayments' : 'Disabled',
            value: _pushEnabled,
            onChanged: _handlePushToggle),
        ProfileSwitchItem(
            icon: Icons.visibility_off_outlined,
            iconColor: colorScheme.onSurfaceVariant,
            iconBg: colorScheme.surfaceContainerHigh,
            label: 'Hide Balances',
            subtitle: themeProvider.hideBalance
                ? 'Amounts hidden across all screens'
                : 'Show all amounts',
            value: themeProvider.hideBalance,
            onChanged: (v) async {
              await AppHaptics.selection();
              themeProvider.setHideBalance(v);
            }),
        ProfileMenuItem(
            icon: Icons.do_not_disturb_on_outlined,
            iconColor: colorScheme.onSurfaceVariant,
            iconBg: colorScheme.surfaceContainerHigh,
            label: 'Quiet Hours',
            subtitle: quietLabel,
            subtitleColor: _quietActiveNow ? AppColors.warning(context) : null,
            onTap: () async {
              await AppHaptics.selection();
              _showQuietHoursPicker();
            }),
      ]),
      const SizedBox(height: UI.md),
      const ProfileSectionHeader(label: 'Security'),
      ProfileCardGroup(children: [
        ProfileMenuItem(
            icon: Icons.lock_outline_rounded,
            iconColor: AppColors.warning(context),
            iconBg: AppColors.warning(context).withValues(alpha: 0.12),
            label: 'Change Password',
            subtitle: 'Update your login credentials',
            onTap: () async {
              await AppHaptics.selection();
              Navigator.of(context, rootNavigator: false).push(SmoothPageRoute(
                  builder: (_) => const ChangePasswordScreen()));
            }),
      ]),
      const SizedBox(height: UI.md),
      const ProfileSectionHeader(label: 'Support'),
      ProfileCardGroup(children: [
        ProfileMenuItem(
            icon: Icons.mail_outline_rounded,
            iconColor: colorScheme.primary,
            iconBg: colorScheme.primaryContainer,
            label: 'Contact Support',
            subtitle: _supportEmail,
            onTap: () async {
              await AppHaptics.selection();
              launchUrl(Uri.parse(
                  'mailto:$_supportEmail?subject=Finworks360 Support'));
            }),
        ProfileMenuItem(
            icon: Icons.description_outlined,
            iconColor: colorScheme.onSurfaceVariant,
            iconBg: colorScheme.surfaceContainerHigh,
            label: 'Terms & Privacy',
            subtitle: 'finworks360.com',
            onTap: () async {
              await AppHaptics.selection();
              launchUrl(
                  Uri.parse('https://finworks360.com/terms-and-conditions/'),
                  mode: LaunchMode.externalApplication);
            }),
        ProfileMenuItem(
            icon: Icons.info_outline_rounded,
            iconColor: colorScheme.onSurfaceVariant,
            iconBg: colorScheme.surfaceContainerHigh,
            label: 'App Version',
            subtitle: 'v$_appVersion',
            showChevron: false,
            onTap: () {}),
      ]),
      const SizedBox(height: UI.lg),
      ProfileSignOutButton(onTap: _confirmLogout),
      const SizedBox(height: 100),
    ];
  }
}
