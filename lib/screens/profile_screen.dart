import 'dart:async';

import 'package:flutter/material.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Item #31: removed shimmer package import — use custom SkeletonTheme system instead
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme/theme_provider.dart';
import '../theme/ui_constants.dart';
import '../utils/app_haptics.dart'; // Item #8
import '../utils/vibration_helper.dart'; // kept for VibrationLevel enum + getLevel()
import '../widgets/animated_page.dart';
import '../widgets/skeleton.dart';
import 'bank_accounts_screen.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';
import 'nominee_screen.dart';
import 'profile_webview_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with RouteAware {
  bool _pushEnabled = false;
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  int _currentRefreshRate = -1;
  TimeOfDay? _quietStart;
  TimeOfDay? _quietEnd;
  VibrationLevel _vibrationLevel = VibrationLevel.normal;

  static const String _appVersion = '1.0.0';

  // ── KYC helpers ──────────────────────────────────────────────────────────

  String formatKycStatus(String? status) {
    switch (status) {
      case 'draft':
        return 'Not Submitted';
      case 'submitted':
        return 'Under Review';
      case 'approved':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  Color kycColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'submitted':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
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

  // ── Init ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _refreshProfile();
    _loadAllPrefs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    _refreshProfile();
  }

  @override
  void didPopNext() => _refreshProfile();

  Future<void> _loadAllPrefs() async {
    final push = await NotificationService.isPushEnabled();
    final hz = await getSavedRefreshRate();
    final (start, end) = await NotificationService.getQuietHours();
    final vibLevel = await VibrationHelper.getLevel();
    await AppHaptics.refreshLevel(); // Item #7: sync cached level
    if (!mounted) return;
    setState(() {
      _pushEnabled = push;
      _currentRefreshRate = hz;
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
      final data = await ApiService.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Profile refresh error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
    _refreshing = false;
  }

  Future<void> _logout() async {
    await AppHaptics.error(); // Item #8
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, animation, __) =>
            FadeTransition(opacity: animation, child: const LoginScreen()),
      ),
          (route) => false,
    );
    ApiService.logout().catchError((e) => debugPrint('Logout cleanup: $e'));
  }

  // ── Push notification toggle ──────────────────────────────────────────────

  Future<void> _handlePushToggle(bool v) async {
    await AppHaptics.selection(); // Item #8
    setState(() => _pushEnabled = v);

    if (v) {
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        setState(() => _pushEnabled = false);
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            title: const Text('Permission Required'),
            content: const Text(
              'Please enable notification permission from device settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel',
                    style:
                    TextStyle(color: AppColors.textSecondary(context))),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await launchUrl(Uri.parse('app-settings:'));
                },
                child: Text('Open Settings',
                    style: TextStyle(color: AppColors.primary(context))),
              ),
            ],
          ),
        );
        return;
      }
      await NotificationService.setPushEnabled(true);
    } else {
      NotificationService.revokePermission();
      await NotificationService.setPushEnabled(false);
    }
  }

  // ── Pickers ───────────────────────────────────────────────────────────────

  void _showThemePicker() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _showSheet(
      title: 'Appearance',
      subtitle: 'Choose your preferred theme',
      child: Column(children: [
        _ThemeOption(
            icon: Icons.smartphone_rounded,
            label: 'System Default',
            subtitle: 'Follows your device setting',
            mode: AppThemeMode.system,
            current: themeProvider.mode,
            onTap: () async {
              await AppHaptics.selection(); // Item #8
              themeProvider.setMode(AppThemeMode.system);
              Navigator.pop(context);
            }),
        const SizedBox(height: 10),
        _ThemeOption(
            icon: Icons.light_mode_rounded,
            label: 'Light Mode',
            subtitle: 'Clean white interface',
            mode: AppThemeMode.light,
            current: themeProvider.mode,
            onTap: () async {
              await AppHaptics.selection(); // Item #8
              themeProvider.setMode(AppThemeMode.light);
              Navigator.pop(context);
            }),
        const SizedBox(height: 10),
        _ThemeOption(
            icon: Icons.dark_mode_rounded,
            label: 'Dark Mode',
            subtitle: 'Easy on the eyes at night',
            mode: AppThemeMode.dark,
            current: themeProvider.mode,
            onTap: () async {
              await AppHaptics.selection(); // Item #8
              themeProvider.setMode(AppThemeMode.dark);
              Navigator.pop(context);
            }),
      ]),
    );
  }

  void _showRefreshRatePicker() {
    const options = [
      (
      hz: -1,
      label: 'Smooth',
      subtitle: 'Runs at highest refresh rate available'
      ),
      (
      hz: 60,
      label: 'Battery Saver',
      subtitle: 'Limits refresh rate to 60Hz to save battery'
      ),
    ];

    _showSheet(
      title: 'Display Performance',
      subtitle: 'Higher refresh rate looks smoother but uses more battery',
      child: Column(
        children: options.map((o) {
          final selected = _currentRefreshRate == o.hz ||
              (_currentRefreshRate != 60 && o.hz == -1);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SelectionTile(
              icon:
              o.hz == -1 ? Icons.bolt_rounded : Icons.battery_saver_rounded,
              label: o.label,
              subtitle: o.subtitle,
              selected: selected,
              onTap: () async {
                await AppHaptics.selection(); // Item #8
                setState(() => _currentRefreshRate = o.hz);
                await saveRefreshRate(o.hz);
                await applyRefreshRate(o.hz);
                if (mounted) Navigator.pop(context);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showVibrationPicker() {
    _showSheet(
      title: 'Vibration Intensity',
      subtitle:
      'In-app haptic feedback strength (system setting still applies)',
      child: Column(
        children: VibrationHelper.levels.map((level) {
          final selected = _vibrationLevel == level;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SelectionTile(
              icon: level == VibrationLevel.off
                  ? Icons.vibration_rounded
                  : level == VibrationLevel.subtle
                  ? Icons.sensors_rounded
                  : level == VibrationLevel.strong
                  ? Icons.offline_bolt_rounded
                  : Icons.touch_app_rounded,
              label: VibrationHelper.levelLabel(level),
              subtitle: VibrationHelper.levelSubtitle(level),
              selected: selected,
              onTap: () async {
                await VibrationHelper.setLevel(level);
                setState(() => _vibrationLevel = level);
                AppHaptics.refreshLevel(); // Item #7: sync cached level
                if (level != VibrationLevel.off) {
                  await AppHaptics.buttonPress(); // Item #8: demo vibration
                }
                if (mounted) Navigator.pop(context);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Quiet hours picker ────────────────────────────────────────────────────

  void _showQuietHoursPicker() {
    _showSheet(
      title: 'Quiet Hours',
      subtitle: 'Notifications are silenced during this window',
      child: StatefulBuilder(
        builder: (ctx, setModal) {
          final hasQuiet = _quietStart != null && _quietEnd != null;

          final isOvernight = () {
            if (_quietStart == null || _quietEnd == null) return false;
            final s = _quietStart!.hour * 60 + _quietStart!.minute;
            final e = _quietEnd!.hour * 60 + _quietEnd!.minute;
            return s > e;
          }();

          final isActive = () {
            if (_quietStart == null || _quietEnd == null) return false;
            final now = TimeOfDay.now();
            final nowM = now.hour * 60 + now.minute;
            final s = _quietStart!.hour * 60 + _quietStart!.minute;
            final e = _quietEnd!.hour * 60 + _quietEnd!.minute;
            if (s <= e) return nowM >= s && nowM < e;
            return nowM >= s || nowM < e;
          }();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TimeTile(
                label: 'From',
                time: _quietStart,
                onTap: () async {
                  await AppHaptics.selection(); // Item #8
                  final t = await showTimePicker(
                    context: context,
                    initialTime:
                    _quietStart ?? const TimeOfDay(hour: 22, minute: 0),
                    helpText: 'QUIET FROM',
                  );
                  if (t != null) {
                    setModal(() => _quietStart = t);
                    setState(() => _quietStart = t);
                  }
                },
              ),
              const SizedBox(height: 10),
              _TimeTile(
                label: 'Until',
                time: _quietEnd,
                onTap: () async {
                  await AppHaptics.selection(); // Item #8
                  final t = await showTimePicker(
                    context: context,
                    initialTime:
                    _quietEnd ?? const TimeOfDay(hour: 8, minute: 0),
                    helpText: 'QUIET UNTIL',
                  );
                  if (t != null) {
                    setModal(() => _quietEnd = t);
                    setState(() => _quietEnd = t);
                  }
                },
              ),
              const SizedBox(height: 14),
              if (hasQuiet && isOvernight)
                _InfoBanner(
                  icon: Icons.nightlight_round,
                  text: 'Spans overnight — ends the following morning',
                  color: AppColors.amber(context),
                ),
              if (hasQuiet) ...[
                const SizedBox(height: UI.sm),
                _InfoBanner(
                  icon: isActive
                      ? Icons.notifications_off_rounded
                      : Icons.notifications_active_rounded,
                  text: isActive
                      ? 'Quiet hours active right now — notifications paused'
                      : 'Quiet hours not active right now',
                  color: isActive
                      ? AppColors.rose(context)
                      : AppColors.emerald(context),
                ),
              ],
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: hasQuiet
                        ? () async {
                      await AppHaptics.selection(); // Item #8
                      await NotificationService.setQuietHours(
                          null, null);
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
                          color:
                          AppColors.rose(context).withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Clear',
                        style: TextStyle(color: AppColors.rose(context))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _quietStart != null && _quietEnd != null
                        ? () async {
                      await AppHaptics.selection(); // Item #8
                      await NotificationService.setQuietHours(
                          _quietStart, _quietEnd);
                      if (mounted) Navigator.pop(context);
                    }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary(context),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
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

  // ── Sheet helper ──────────────────────────────────────────────────────────

  void _showSheet({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.navyCard(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider(context),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: UI.xs),
            Text(subtitle,
                style: TextStyle(
                    color: AppColors.textSecondary(context), fontSize: 13)),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final name = _profile?['name'] ?? '';
    final initials = name.isNotEmpty
        ? name.split(' ').map((e) => e[0]).take(2).join('')
        : '?';

    final themeLabel = switch (themeProvider.mode) {
      AppThemeMode.system => 'System Default',
      AppThemeMode.light => 'Light Mode',
      AppThemeMode.dark => 'Dark Mode',
    };

    final refreshLabel =
    _currentRefreshRate == 60 ? 'Battery Saver' : 'Smooth (recommended)';

    final String quietLabel;
    if (_quietStart != null && _quietEnd != null) {
      final range =
          '${_quietStart!.format(context)} – ${_quietEnd!.format(context)}';
      final overnight = _isOvernightRange ? ' · overnight' : '';
      final active = _quietActiveNow ? ' · active now' : '';
      quietLabel = '$range$overnight$active';
    } else {
      quietLabel = 'Off';
    }

    final balanceText = themeProvider.hideBalance
        ? '₹ ••••••'
        : '₹ ${_profile?['wallet_balance'] ?? '0.00'}';

    final vibrationLabel = VibrationHelper.levelLabel(_vibrationLevel);

    return AnimatedPage(
      child: Scaffold(
        backgroundColor: AppColors.scaffold(context),
        body: _isLoading
            ? const _ProfileSkeleton()
            : RefreshIndicator(
          onRefresh: () async {
            await AppHaptics.selection(); // Item #8
            await _refreshProfile();
          },
          color: AppColors.primary(context),
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Profile',
                          style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontSize: 26,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 20),

                      // ── Profile card ────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.navyCard(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.divider(context)),
                          boxShadow: AppColors.cardShadow(context),
                        ),
                        child: Row(children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [
                                Color(0xFF1D4ED8),
                                Color(0xFF3B82F6),
                              ]),
                            ),
                            child: Center(
                              child: Text(initials,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(_profile?['name'] ?? '',
                                    style: TextStyle(
                                        color:
                                        AppColors.textPrimary(context),
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700)),
                                Text(_profile?['email'] ?? '',
                                    style: TextStyle(
                                        color: AppColors.textSecondary(
                                            context),
                                        fontSize: 12)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: AppColors.blue(context)
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                      BorderRadius.circular(20)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified_rounded,
                                          color:
                                          AppColors.primary(context),
                                          size: 12),
                                      const SizedBox(width: UI.xs),
                                      Text('Investor',
                                          style: TextStyle(
                                              color: AppColors.primary(
                                                  context),
                                              fontSize: 11,
                                              fontWeight:
                                              FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 14),

                      // ── Wallet balance ──────────────────────────
                      Container(
                        padding: const EdgeInsets.all(UI.md),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            AppColors.primary(context)
                                .withValues(alpha: 0.08),
                            AppColors.primary(context)
                                .withValues(alpha: 0.04),
                          ]),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.primary(context)
                                  .withValues(alpha: 0.2)),
                          boxShadow: AppColors.cardShadow(context),
                        ),
                        child: Row(children: [
                          Icon(Icons.account_balance_wallet_rounded,
                              color: AppColors.primary(context)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text('Wallet Balance',
                                    style: TextStyle(
                                        color: AppColors.textSecondary(
                                            context),
                                        fontSize: 12)),
                                Text(balanceText,
                                    style: TextStyle(
                                        color:
                                        AppColors.primary(context),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              await AppHaptics.selection(); // Item #8
                              themeProvider.setHideBalance(
                                  !themeProvider.hideBalance);
                            },
                            child: Icon(
                              themeProvider.hideBalance
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AppColors.textSecondary(context),
                              size: 20,
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: UI.lg),

                      // ── Account ─────────────────────────────────
                      _SectionLabel(label: 'Account', context: context),
                      _MenuCard(context: context, items: [
                        _MenuItem(
                          icon: Icons.badge_outlined,
                          label: 'PAN Number',
                          subtitle: _profile?['pan_number'] ?? '',
                          onTap: () {},
                          context: context,
                          showChevron: false,
                        ),
                        _MenuItem(
                          icon: Icons.phone_outlined,
                          label: 'Mobile',
                          subtitle: _profile?['mobile'] ?? '',
                          onTap: () {},
                          context: context,
                          showChevron: false,
                        ),
                        _MenuItem(
                          icon: Icons.verified_user_outlined,
                          label: 'KYC Status',
                          subtitle: formatKycStatus(
                              _profile?['profile_status']),
                          onTap: () async {
                            await AppHaptics.selection(); // Item #8
                            // Navigate to KYC webview so user can
                            // complete / check their KYC status
                            final email = _profile?['email'] ?? '';
                            final name  = _profile?['name']  ?? '';
                            final prefs = await SharedPreferences.getInstance();
                            final password = prefs.getString('saved_password') ?? '';
                            if (!mounted) return;
                            Navigator.of(context, rootNavigator: false).push(
                              SmoothPageRoute(
                                builder: (_) => ProfileWebViewScreen(
                                  email: email,
                                  name: name,
                                  password: password,
                                  baseUrl: ApiService.baseUrl,
                                ),
                              ),
                            );
                          },
                          context: context,
                        ),
                        _MenuItem(
                          icon: Icons.account_balance_outlined,
                          label: 'Bank Accounts',
                          subtitle: 'Manage your bank accounts',
                          onTap: () async {
                            await AppHaptics.selection(); // Item #8
                            Navigator.of(context, rootNavigator: false)
                                .push(SmoothPageRoute(
                                builder: (_) =>
                                const BankAccountsScreen()));
                          },
                          context: context,
                        ),
                        _MenuItem(
                          icon: Icons.person_outline_rounded,
                          label: 'Nominee',
                          subtitle: 'Add or update nominee',
                          onTap: () async {
                            await AppHaptics.selection(); // Item #8
                            Navigator.of(context, rootNavigator: false)
                                .push(SmoothPageRoute(
                                builder: (_) =>
                                const NomineeScreen()));
                          },
                          context: context,
                        ),
                      ]),
                      const SizedBox(height: UI.md),

                      // ── Display ─────────────────────────────────
                      _SectionLabel(label: 'Display', context: context),
                      _MenuCard(context: context, items: [
                        _MenuItem(
                            icon: Icons.palette_outlined,
                            label: 'Appearance',
                            subtitle: themeLabel,
                            onTap: () async {
                              await AppHaptics.selection(); // Item #8
                              _showThemePicker();
                            },
                            context: context),
                        _MenuItem(
                            icon: Icons.speed_rounded,
                            label: 'Display Performance',
                            subtitle: refreshLabel,
                            onTap: () async {
                              await AppHaptics.selection(); // Item #8
                              _showRefreshRatePicker();
                            },
                            context: context),
                        _ToggleItem(
                          icon: Icons.visibility_off_outlined,
                          label: 'Hide Balance',
                          subtitle: 'Blur wallet amounts by default',
                          value: themeProvider.hideBalance,
                          onChanged: (v) =>
                              themeProvider.setHideBalance(v),
                        ),

                        _MenuItem(
                            icon: Icons.vibration_rounded,
                            label: 'Vibration',
                            subtitle: vibrationLabel,
                            onTap: () async {
                              await AppHaptics.selection(); // Item #8
                              _showVibrationPicker();
                            },
                            context: context),
                      ]),
                      const SizedBox(height: UI.md),

                      // ── Notifications ────────────────────────────
                      _SectionLabel(
                          label: 'Notifications', context: context),
                      _MenuCard(context: context, items: [
                        _ToggleItem(
                          icon: Icons.notifications_outlined,
                          label: 'Push Notifications',
                          subtitle: _pushEnabled
                              ? 'Enabled for new invoices'
                              : 'Notifications disabled',
                          value: _pushEnabled,
                          onChanged: _handlePushToggle,
                        ),
                        _MenuItem(
                          icon: Icons.do_not_disturb_on_outlined,
                          label: 'Quiet Hours',
                          subtitle: quietLabel,
                          subtitleColor: _quietActiveNow
                              ? AppColors.amber(context)
                              : null,
                          onTap: () async {
                            await AppHaptics.selection(); // Item #8
                            _showQuietHoursPicker();
                          },
                          context: context,
                        ),
                      ]),
                      const SizedBox(height: UI.md),

                      // ── Security ─────────────────────────────────
                      _SectionLabel(
                          label: 'Security', context: context),
                      _MenuCard(context: context, items: [
                        _MenuItem(
                          icon: Icons.lock_outline_rounded,
                          label: 'Change Password',
                          onTap: () async {
                            await AppHaptics.selection(); // Item #8
                            Navigator.of(context, rootNavigator: false)
                                .push(
                              SmoothPageRoute(
                                  builder: (_) =>
                                  const ChangePasswordScreen()),
                            );
                          },
                          context: context,
                        ),
                      ]),
                      const SizedBox(height: UI.md),

                      // ── Support ──────────────────────────────────
                      _SectionLabel(
                          label: 'Support', context: context),
                      _MenuCard(context: context, items: [
                        _MenuItem(
                          icon: Icons.mail_outline_rounded,
                          label: 'Contact Support',
                          subtitle: 'lakhiwal43@gmail.com',
                          onTap: () async {
                            await AppHaptics.selection(); // Item #8
                            launchUrl(Uri.parse(
                                'mailto:lakhiwal43@gmail.com?subject=Finworks360 Support'));
                          },
                          context: context,
                        ),
                        _MenuItem(
                          icon: Icons.description_outlined,
                          label: 'Terms & Conditions',
                          onTap: () async {
                            await AppHaptics.selection(); // Item #8
                            launchUrl(
                                Uri.parse(
                                    'https://finworks360.com/terms-and-conditions/'),
                                mode: LaunchMode.externalApplication);
                          },
                          context: context,
                        ),
                        _MenuItem(
                          icon: Icons.privacy_tip_outlined,
                          label: 'Privacy Policy',
                          onTap: () async {
                            await AppHaptics.selection(); // Item #8
                            launchUrl(
                                Uri.parse(
                                    'https://finworks360.com/policies/'),
                                mode: LaunchMode.externalApplication);
                          },
                          context: context,
                        ),
                        _MenuItem(
                          icon: Icons.info_outline_rounded,
                          label: 'App Version',
                          subtitle: 'v$_appVersion',
                          onTap: () {},
                          context: context,
                          showChevron: false,
                        ),
                      ]),
                      const SizedBox(height: UI.lg),

                      // ── Sign out ─────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _logout,
                          icon: Icon(Icons.logout_rounded,
                              color: AppColors.rose(context), size: 18),
                          label: Text('Sign Out',
                              style: TextStyle(
                                  color: AppColors.rose(context),
                                  fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: AppColors.rose(context)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Info banner ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoBanner(
      {required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: UI.sm),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonTheme(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 40),

            Row(
              children: const [
                SkeletonBox(
                  width: 56,
                  height: 56,
                  borderRadius: BorderRadius.all(Radius.circular(28)),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 140, height: 14),
                      SizedBox(height: UI.sm),
                      SkeletonBox(width: 200, height: 12),
                    ],
                  ),
                )
              ],
            ),

            SizedBox(height: 30),

            SkeletonCard(height: 70),

            SizedBox(height: 30),

            SkeletonListTile(),
            SizedBox(height: UI.md),
            SkeletonListTile(),
            SizedBox(height: UI.md),
            SkeletonListTile(),
          ],
        ),
      ),
    );
  }
}
// ── Reusable widgets ──────────────────────────────────────────────────────────

class _SelectionTile extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SelectionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: UI.md, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary(context).withValues(alpha: 0.08)
              : AppColors.navyLight(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected
                  ? AppColors.primary(context)
                  : AppColors.divider(context),
              width: selected ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(icon,
              color: selected
                  ? AppColors.primary(context)
                  : AppColors.textSecondary(context),
              size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 14,
                        fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400)),
                Text(subtitle,
                    style: TextStyle(
                        color: AppColors.textSecondary(context), fontSize: 11)),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded,
                color: AppColors.primary(context), size: 20),
        ]),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final VoidCallback onTap;

  const _TimeTile(
      {required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: UI.md, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.navyLight(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider(context)),
        ),
        child: Row(children: [
          Icon(Icons.access_time_rounded,
              color: AppColors.textSecondary(context), size: 20),
          const SizedBox(width: 14),
          Text(label,
              style: TextStyle(
                  color: AppColors.textSecondary(context), fontSize: 13)),
          const Spacer(),
          Text(
            time?.format(context) ?? 'Tap to set',
            style: TextStyle(
                color: time != null
                    ? AppColors.textPrimary(context)
                    : AppColors.textSecondary(context),
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.textSecondary(context), size: 16),
        ]),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final AppThemeMode mode, current;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.mode,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => _SelectionTile(
      icon: icon,
      label: label,
      subtitle: subtitle,
      selected: mode == current,
      onTap: onTap);
}

class _SectionLabel extends StatelessWidget {
  final String label;

  // context param kept for call-site compatibility but ignored — widget uses
  // its own BuildContext so theme changes always rebuild correctly.
  const _SectionLabel({required this.label, Object? context});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8)),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<Widget> items;

  // context param kept for call-site compatibility but ignored.
  const _MenuCard({required this.items, Object? context});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navyCard(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider(context)),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        children: items
            .asMap()
            .entries
            .map((entry) => Column(children: [
          entry.value,
          if (entry.key < items.length - 1)
            Divider(
                color: AppColors.divider(context),
                height: 1,
                indent: 52),
        ]))
            .toList(),
      ),
    );
  }
}

class _MenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? subtitleColor;
  final VoidCallback onTap;
  final bool showChevron;

  // context param kept for call-site compatibility but ignored.
  const _MenuItem({
    required this.icon,
    required this.label,
    this.subtitle,
    this.subtitleColor,
    required this.onTap,
    Object? context,
    this.showChevron = true,
  });

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.97 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _pressed
              ? AppColors.primary(context).withValues(alpha: 0.05)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: UI.md, vertical: 14),
          child: Row(children: [
            Icon(widget.icon,
                color: AppColors.textSecondary(context), size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label,
                      style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 14)),
                  if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                    Text(widget.subtitle!,
                        style: TextStyle(
                            color: widget.subtitleColor ??
                                AppColors.textSecondary(context),
                            fontSize: 11)),
                ],
              ),
            ),
            if (widget.showChevron)
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary(context), size: 18),
          ]),
        ),
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        await AppHaptics.selection(); // Item #8
        onChanged(!value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: UI.md, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary(context), size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: AppColors.textPrimary(context), fontSize: 14)),
                  Text(subtitle,
                      style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 11)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: (v) async {
                await AppHaptics.selection(); // Item #8
                onChanged(v);
              },
              activeThumbColor: AppColors.primary(context),
              activeTrackColor: AppColors.primary(context).withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}