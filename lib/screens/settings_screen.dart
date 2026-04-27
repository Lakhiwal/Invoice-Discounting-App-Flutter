import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/screens/profile/sheets/time_tile.dart';
import 'package:invoice_discounting_app/screens/profile/shield_screen.dart';
import 'package:invoice_discounting_app/screens/profile/widgets/app_bar_widgets.dart';
import 'package:invoice_discounting_app/screens/profile/widgets/menu_widgets.dart';
import 'package:invoice_discounting_app/screens/profile/widgets/status_widgets.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/services/notification_service.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/deep_link_test_util.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';
import 'package:invoice_discounting_app/widgets/common/app_switch.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pushEnabled = false;
  TimeOfDay? _quietStart;
  TimeOfDay? _quietEnd;
  bool _hapticsEnabled = true;

  bool _is2FAEnabled = false;
  bool _isLoading2FA = false;

  @override
  void initState() {
    super.initState();
    _load2FAStatus();
    _loadPrefs();
  }

  Future<void> _load2FAStatus() async {
    if (!mounted) return;
    setState(() => _isLoading2FA = true);
    try {
      final res = await ApiService.get2FAStatus();
      if (mounted) {
        setState(() {
          // Check for multiple possible key formats from backend
          _is2FAEnabled = (res['is_2fa_enabled'] as bool?) ??
              (res['enabled'] as bool?) ??
              (res['isEnabled'] as bool?) ??
              false;
          _isLoading2FA = false;
        });
      }
    } catch (e) {
      debugPrint('Settings: Error loading 2FA status: $e');
      if (mounted) {
        setState(() => _isLoading2FA = false);
      }
    }
  }

  Future<void> _handle2FAToggle(bool value) async {
    unawaited(AppHaptics.buttonPress());
    _showShieldManagement();
  }

  Future<void> _showShieldManagement() async {
    unawaited(AppHaptics.selection());
    await Navigator.push<void>(
      context,
      SmoothPageRoute<void>(
        builder: (_) => ShieldScreen(
          isEnabled: _is2FAEnabled,
          onChanged: (v) {
            setState(() => _is2FAEnabled = v);
          },
        ),
      ),
    );
    // Refresh status when returning to ensure state is synchronized
    await _load2FAStatus();
  }

  Future<void> _loadPrefs() async {
    final push = await NotificationService.isPushEnabled();
    final (start, end) = await NotificationService.getQuietHours();
    if (!mounted) return;
    setState(() {
      _pushEnabled = push;
      _quietStart = start;
      _quietEnd = end;
      _hapticsEnabled = AppHaptics.enabled;
    });
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

  Future<void> _handlePushToggle(bool v) async {
    unawaited(AppHaptics.selection());
    setState(() => _pushEnabled = v);

    if (v) {
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        setState(() => _pushEnabled = false);
        return;
      }
      await NotificationService.setPushEnabled(true);
    } else {
      NotificationService.revokePermission();
      await NotificationService.setPushEnabled(false);
    }
  }

  void _showQuietHoursPicker() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: UI.sheetRadius),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          MediaQuery.of(context).viewInsets.bottom + 40,
        ),
        child: StatefulBuilder(
          builder: (ctx, setModal) {
            final hasQuiet = _quietStart != null && _quietEnd != null;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quiet hours',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: UI.xs),
                Text(
                  'Notifications are silenced during this window',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ProfileTimeTile(
                  label: 'From',
                  time: _quietStart,
                  onTap: () async {
                    unawaited(AppHaptics.selection());
                    if (!mounted) return;
                    final t = await showTimePicker(
                      context: context,
                      initialTime:
                          _quietStart ?? const TimeOfDay(hour: 22, minute: 0),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          timePickerTheme: TimePickerThemeData(
                            backgroundColor: cs.surface,
                            dialBackgroundColor:
                                cs.primary.withValues(alpha: 0.05),
                            hourMinuteColor:
                                WidgetStateColor.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return cs.primaryContainer;
                              }
                              return cs.surfaceContainerHigh;
                            }),
                            hourMinuteTextColor:
                                WidgetStateColor.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return cs.primary;
                              }
                              return cs.onSurface;
                            }),
                            dayPeriodColor: cs.primaryContainer,
                            dayPeriodTextColor: cs.primary,
                            dayPeriodBorderSide:
                                BorderSide(color: cs.primary, width: 0.5),
                            dialTextStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                            dialHandColor: cs.primary,
                            hourMinuteShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(UI.radiusMd),
                            ),
                          ),
                        ),
                        child: MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            alwaysUse24HourFormat: false,
                          ),
                          child: child!,
                        ),
                      ),
                    );
                    if (t != null) {
                      setModal(() => _quietStart = t);
                      setState(() => _quietStart = t);
                    }
                  },
                ),
                const SizedBox(height: 10),
                ProfileTimeTile(
                  label: 'Until',
                  time: _quietEnd,
                  onTap: () async {
                    unawaited(AppHaptics.selection());
                    if (!mounted) return;
                    final t = await showTimePicker(
                      context: context,
                      initialTime:
                          _quietEnd ?? const TimeOfDay(hour: 8, minute: 0),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          timePickerTheme: TimePickerThemeData(
                            backgroundColor: cs.surface,
                            dialBackgroundColor:
                                cs.primary.withValues(alpha: 0.05),
                            hourMinuteColor:
                                WidgetStateColor.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return cs.primaryContainer;
                              }
                              return cs.surfaceContainerHigh;
                            }),
                            hourMinuteTextColor:
                                WidgetStateColor.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return cs.primary;
                              }
                              return cs.onSurface;
                            }),
                            dayPeriodColor: cs.primaryContainer,
                            dayPeriodTextColor: cs.primary,
                            dayPeriodBorderSide:
                                BorderSide(color: cs.primary, width: 0.5),
                            dialTextStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                            dialHandColor: cs.primary.withValues(alpha: 0.7),
                            hourMinuteShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(UI.radiusMd),
                            ),
                          ),
                        ),
                        child: MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            alwaysUse24HourFormat: false,
                          ),
                          child: child!,
                        ),
                      ),
                    );
                    if (t != null) {
                      setModal(() => _quietEnd = t);
                      setState(() => _quietEnd = t);
                    }
                  },
                ),
                if (hasQuiet) ...[
                  const SizedBox(height: 14),
                  if (_isOvernightRange)
                    ProfileInfoBanner(
                      icon: AppIcons.darkMode,
                      text: 'Spans overnight — ends the following morning',
                      color: AppColors.warning(context),
                    ),
                  const SizedBox(height: UI.sm),
                  ProfileInfoBanner(
                    icon: _quietActiveNow
                        ? AppIcons.notification
                        : AppIcons.notification, // Or different if needed
                    text: _quietActiveNow
                        ? 'Quiet hours active right now'
                        : 'Quiet hours not active right now',
                    color: _quietActiveNow
                        ? AppColors.danger(context)
                        : AppColors.success(context),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: hasQuiet
                            ? () async {
                                unawaited(AppHaptics.selection());
                                await NotificationService.setQuietHours(
                                  null,
                                  null,
                                );
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
                                .withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(UI.radiusMd),
                          ),
                        ),
                        child: Text(
                          'Clear',
                          style: TextStyle(color: AppColors.danger(context)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _quietStart != null && _quietEnd != null
                            ? () async {
                                unawaited(AppHaptics.selection());
                                await NotificationService.setQuietHours(
                                  _quietStart,
                                  _quietEnd,
                                );
                                if (mounted) Navigator.pop(context);
                              }
                            : null,
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mode = ref.watch(themeProvider.select((p) => p.mode));
    final hideBalance = ref.watch(themeProvider.select((p) => p.hideBalance));
    final isFullscreen = ref.watch(themeProvider.select((p) => p.isFullscreen));

    final String quietLabel;
    if (_quietStart != null && _quietEnd != null) {
      final range =
          '${_quietStart!.format(context)} – ${_quietEnd!.format(context)}';
      final active = _quietActiveNow ? ' · active now' : '';
      quietLabel = '$range$active';
    } else {
      quietLabel = 'Off';
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
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
              'Settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 8),

              // ── Appearance ──────────────────────────────────────────
              const _SectionLabel(label: 'Appearance'),
              const SizedBox(height: 10),
              _AppearancePicker(
                current: mode,
                onChanged: (newMode) async {
                  unawaited(AppHaptics.selection());
                  ref.read(themeProvider).setMode(newMode);
                },
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const _SectionLabel(label: 'Notifications'),
              const SizedBox(height: 10),
              _SettingsGroup(
                children: [
                  ProfileCardGroup(
                    children: [
                      _SwitchRow(
                        icon: AppIcons.notification,
                        label: 'Push notifications',
                        subtitle: _pushEnabled
                            ? 'New invoices, repayments'
                            : 'Disabled',
                        value: _pushEnabled,
                        onChanged: _handlePushToggle,
                      ),
                      _MenuRow(
                        icon: AppIcons.quiet,
                        label: 'Quiet hours',
                        subtitle: quietLabel,
                        subtitleColor:
                            _quietActiveNow ? AppColors.warning(context) : null,
                        onTap: () async {
                          unawaited(AppHaptics.selection());
                          _showQuietHoursPicker();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Security ───────────────────────────────────────────
              const Divider(height: 1),
              const _SectionLabel(label: 'Security'),
              const SizedBox(height: 10),
              _SettingsGroup(
                children: [
                  ProfileCardGroup(
                    children: [
                      if (_isLoading2FA)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: LoadingAnimationWidget.staggeredDotsWave(
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24,),
                            ),
                          ),
                        )
                      else
                        _SwitchRow(
                          icon: AppIcons.shield,
                          label: 'Two-Factor Authentication',
                          subtitle: _is2FAEnabled
                              ? 'Authenticator app active'
                              : 'Protect your account with 2FA',
                          value: _is2FAEnabled,
                          onChanged: _handle2FAToggle,
                        ),
                      _SwitchRow(
                        icon: AppIcons
                            .timer, // Using timer icon for lock logic or AppIcons.shield if preferred
                        label: 'Biometric Lock',
                        subtitle: ref.watch(
                                themeProvider.select((p) => p.useBiometrics),)
                            ? 'Authenticated on startup/resume'
                            : 'Security login only',
                        value: ref.watch(
                            themeProvider.select((p) => p.useBiometrics),),
                        onChanged: (v) async {
                          unawaited(AppHaptics.selection());
                          ref.read(themeProvider).setUseBiometrics(useOrNot: v);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Display ─────────────────────────────────────────────
              const Divider(height: 1),
              const _SectionLabel(label: 'Display'),
              const SizedBox(height: 10),
              _SettingsGroup(
                children: [
                  ProfileCardGroup(
                    children: [
                      _SwitchRow(
                        icon: AppIcons.eyeSlash,
                        label: 'Hide balances',
                        subtitle: hideBalance
                            ? 'Amounts hidden everywhere'
                            : 'All amounts visible',
                        value: hideBalance,
                        onChanged: (v) async {
                          unawaited(AppHaptics.selection());
                          ref.read(themeProvider).setHideBalance(hide: v);
                        },
                      ),
                      _SwitchRow(
                        icon: AppIcons.fullscreen,
                        label: 'Fullscreen',
                        subtitle:
                            isFullscreen ? 'Immersive mode active' : 'Default',
                        value: isFullscreen,
                        onChanged: (v) async {
                          unawaited(AppHaptics.selection());
                          ref.read(themeProvider).setFullscreen(enabled: v);
                        },
                      ),
                      _SwitchRow(
                        icon: AppIcons.vibration,
                        label: 'Haptics',
                        subtitle:
                            _hapticsEnabled ? 'Premium touch feedback' : 'Off',
                        value: _hapticsEnabled,
                        onChanged: (v) async {
                          unawaited(AppHaptics.setEnabled(enabled: v));
                          setState(() => _hapticsEnabled = v);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Performance ──────────────────────────────────────────
              const Divider(height: 1),
              const _SectionLabel(label: 'Performance'),
              const SizedBox(height: 10),
              _SettingsGroup(
                children: [
                  ProfileCardGroup(
                    children: [
                      _MenuRow(
                        icon: AppIcons.battery,
                        label: 'Disable battery optimization',
                        subtitle: 'Reduces app closes and delays',
                        showTrailing: false,
                        onTap: () async {
                          unawaited(AppHaptics.selection());
                          try {
                            const MethodChannel('app/settings')
                                .invokeMethod('openBatteryOptimization');
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Could not open system settings'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Debug & Testing ─────────────────────────────────────
              const Divider(height: 1),
              const _SectionLabel(label: 'Debug & Testing'),
              const SizedBox(height: 10),
              _SettingsGroup(
                children: [
                  ProfileCardGroup(
                    children: [
                      _MenuRow(
                        icon: AppIcons.bug,
                        label: 'Simulate Deep Link',
                        subtitle: 'Tests Skeleton Transition for Invoice',
                        onTap: () async {
                          unawaited(AppHaptics.navTap());
                          // We use a sample invoice ID (e.g. 1)
                          DeepLinkTestUtil.simulateNewInvoice(1);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ]),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 40),
          ),
        ],
      ),
    );
  }
}

// ── Section label ───────────────────────────────────────────────────────────

class _SectionLabel extends ConsumerWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(left: 24, top: 24, bottom: 8),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      );
}

// ── Appearance picker — 3 visual cards + system toggle ──────────────────────

class _AppearancePicker extends ConsumerWidget {
  const _AppearancePicker({required this.current, required this.onChanged});

  final AppThemeMode current;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSystem = current == AppThemeMode.system;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ThemeCard(
                  label: 'Light',
                  preview: const Color(0xFFF4F7FF),
                  icon: AppIcons.lightMode,
                  iconColor: const Color(0xFFF59E0B),
                  selected: current == AppThemeMode.light,
                  onTap: () => onChanged(AppThemeMode.light),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ThemeCard(
                  label: 'Dark',
                  preview: const Color(0xFF050508),
                  icon: AppIcons.darkMode,
                  iconColor: const Color(0xFF8888CC),
                  selected: current == AppThemeMode.dark,
                  onTap: () => onChanged(AppThemeMode.dark),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ThemeCard(
                  label: 'Black',
                  preview: const Color(0xFF000000),
                  icon: AppIcons.darkMode, // Black uses dark mode icon
                  iconColor: Colors.white,
                  selected: current == AppThemeMode.black,
                  onTap: () => onChanged(AppThemeMode.black),
                  showBorder: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsGroup(
            children: [
              ProfileCardGroup(
                children: [
                  _SwitchRow(
                    icon: AppIcons.smartphone,
                    label: 'Match system',
                    subtitle: 'Follow device theme',
                    value: isSystem,
                    onChanged: (v) {
                      if (v) {
                        onChanged(AppThemeMode.system);
                      } else {
                        // When turning off system, default to dark
                        onChanged(AppThemeMode.dark);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends ConsumerWidget {
  const _ThemeCard({
    required this.label,
    required this.preview,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.onTap,
    this.showBorder = false,
  });

  final String label;
  final Color preview;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;
  final bool showBorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(UI.radiusMd),
          border: Border.all(
            color: selected
                ? cs.primary
                : cs.outlineVariant.withValues(alpha: 0.2),
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: preview,
                borderRadius: BorderRadius.circular(UI.radiusMd),
                border: showBorder
                    ? Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.3),
                      )
                    : null,
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? cs.primary : cs.onSurfaceVariant,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Settings group (divider-based, no card border) ──────────────────────────

class _SettingsGroup extends ConsumerWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: children
          .asMap()
          .entries
          .map(
            (entry) => Column(
              children: [
                entry.value,
                if (entry.key < children.length - 1)
                  Divider(
                    color: cs.outlineVariant.withValues(alpha: 0.1),
                    height: 1,
                    thickness: 0.5,
                  ),
              ],
            ),
          )
          .toList(),
    );
  }
}

// ── Switch row ──────────────────────────────────────────────────────────────

class _SwitchRow extends ConsumerWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(UI.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(UI.radiusSm),
              ),
              child: Icon(icon, color: cs.onSurfaceVariant, size: 15),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                  ),
                ],
              ),
            ),
            AppSwitch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Menu row (tappable, shows chevron) ──────────────────────────────────────

class _MenuRow extends ConsumerWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.subtitleColor,
    this.showTrailing = true,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color? subtitleColor;
  final VoidCallback onTap;
  final bool showTrailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(UI.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(UI.radiusSm),
              ),
              child: Icon(icon, color: cs.onSurfaceVariant, size: 15),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: subtitleColor ?? cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
