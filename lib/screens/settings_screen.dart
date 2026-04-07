import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_service.dart';
import '../services/api_service.dart';
import '../theme/theme_provider.dart';
import '../theme/ui_constants.dart';
import '../utils/app_haptics.dart';
import '../utils/smooth_page_route.dart';
import 'profile/shield_screen.dart';
import 'profile/sheets/time_tile.dart';
import 'profile/widgets/status_widgets.dart';
import '../utils/deep_link_test_util.dart';

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
    setState(() => _isLoading2FA = true);
    final res = await ApiService.get2FAStatus();
    if (mounted) {
      setState(() {
        _is2FAEnabled = res['is_2fa_enabled'] ?? false;
        _isLoading2FA = false;
      });
    }
  }

  Future<void> _handle2FAToggle(bool value) async {
    await AppHaptics.buttonPress();
    _showShieldManagement();
  }

  void _showShieldManagement() {
    AppHaptics.selection();
    Navigator.push(
      context,
      SmoothPageRoute(
        builder: (_) => ShieldScreen(
          isEnabled: _is2FAEnabled,
          onChanged: (v) {
            setState(() => _is2FAEnabled = v);
          },
        ),
      ),
    );
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
    await AppHaptics.selection();
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: UI.sheetRadius),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 40),
        child: StatefulBuilder(
          builder: (ctx, setModal) {
            final hasQuiet = _quietStart != null && _quietEnd != null;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quiet hours',
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: UI.xs),
                Text('Notifications are silenced during this window',
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 20),
                ProfileTimeTile(
                    label: 'From',
                    time: _quietStart,
                    onTap: () async {
                      await AppHaptics.selection();
                      if (!mounted) return;
                      final t = await showTimePicker(
                          context: context,
                          initialTime: _quietStart ??
                              const TimeOfDay(hour: 22, minute: 0));
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
                      if (!mounted) return;
                      final t = await showTimePicker(
                          context: context,
                          initialTime: _quietEnd ??
                              const TimeOfDay(hour: 8, minute: 0));
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
                              color: AppColors.danger(context)
                                  .withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(UI.radiusSm))),
                      child: Text('Clear',
                          style:
                          TextStyle(color: AppColors.danger(context))),
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
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mode = ref.watch(themeProvider.select((p) => p.mode));
    final hideBalance = ref.watch(themeProvider.select((p) => p.hideBalance));

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
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: cs.onSurface, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text('Settings',
            style: TextStyle(
                color: cs.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 8),

          // ── Appearance ──────────────────────────────────────────
          _SectionLabel(label: 'Appearance'),
          const SizedBox(height: 10),
          _AppearancePicker(
            current: mode,
            onChanged: (newMode) async {
              await AppHaptics.selection();
              ref.read(themeProvider).setMode(newMode);
            },
          ),
          const SizedBox(height: 24),

          // ── Notifications ───────────────────────────────────────
          _SectionLabel(label: 'Notifications'),
          const SizedBox(height: 10),
          _SettingsGroup(children: [
            _SwitchRow(
              icon: Icons.notifications_outlined,
              label: 'Push notifications',
              subtitle: _pushEnabled ? 'New invoices, repayments' : 'Disabled',
              value: _pushEnabled,
              onChanged: _handlePushToggle,
            ),
            _MenuRow(
              icon: Icons.do_not_disturb_on_outlined,
              label: 'Quiet hours',
              subtitle: quietLabel,
              subtitleColor:
              _quietActiveNow ? AppColors.warning(context) : null,
              onTap: () async {
                await AppHaptics.selection();
                _showQuietHoursPicker();
              },
            ),
          ]),
          const SizedBox(height: 24),

          // ── Security ───────────────────────────────────────────
          _SectionLabel(label: 'Security'),
          const SizedBox(height: 10),
          _SettingsGroup(children: [
            _isLoading2FA
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )),
                  )
                : _SwitchRow(
                    icon: Icons.shield_outlined,
                    label: 'Two-Factor Authentication',
                    subtitle: _is2FAEnabled
                        ? 'Authenticator app active'
                        : 'Protect your account with 2FA',
                    value: _is2FAEnabled,
                    onChanged: _handle2FAToggle,
                  ),
          ]),
          const SizedBox(height: 24),

          // ── Display ─────────────────────────────────────────────
          _SectionLabel(label: 'Display'),
          const SizedBox(height: 10),
          _SettingsGroup(children: [
            _SwitchRow(
              icon: Icons.visibility_off_outlined,
              label: 'Hide balances',
              subtitle: hideBalance
                  ? 'Amounts hidden everywhere'
                  : 'All amounts visible',
              value: hideBalance,
              onChanged: (v) async {
                await AppHaptics.selection();
                ref.read(themeProvider).setHideBalance(v);
              },
            ),
            _SwitchRow(
              icon: Icons.vibration_rounded,
              label: 'Haptics',
              subtitle: _hapticsEnabled ? 'Premium touch feedback' : 'Off',
              value: _hapticsEnabled,
              onChanged: (v) async {
                await AppHaptics.setEnabled(v);
                setState(() => _hapticsEnabled = v);
              },
            ),
          ]),
          const SizedBox(height: 24),

          // ── Debug & Testing ─────────────────────────────────────
          _SectionLabel(label: 'Debug & Testing'),
          const SizedBox(height: 10),
          _SettingsGroup(children: [
            _MenuRow(
              icon: Icons.bug_report_outlined,
              label: 'Simulate Deep Link',
              subtitle: 'Tests Skeleton Transition for Invoice',
              onTap: () async {
                await AppHaptics.navTap();
                // We use a sample invoice ID (e.g. 1)
                DeepLinkTestUtil.simulateNewInvoice(1);
              },
            ),
          ]),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

// ── Section label ───────────────────────────────────────────────────────────

class _SectionLabel extends ConsumerWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
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
}

// ── Appearance picker — 3 visual cards + system toggle ──────────────────────

class _AppearancePicker extends ConsumerWidget {
  final AppThemeMode current;
  final ValueChanged<AppThemeMode> onChanged;

  const _AppearancePicker({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSystem = current == AppThemeMode.system;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ThemeCard(
                label: 'Light',
                preview: const Color(0xFFF4F7FF),
                icon: Icons.light_mode_rounded,
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
                icon: Icons.dark_mode_rounded,
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
                icon: Icons.dark_mode_rounded,
                iconColor: Colors.white,
                selected: current == AppThemeMode.black,
                onTap: () => onChanged(AppThemeMode.black),
                showBorder: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsGroup(children: [
          _SwitchRow(
            icon: Icons.smartphone_rounded,
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
        ]),
      ],
    );
  }
}

class _ThemeCard extends ConsumerWidget {
  final String label;
  final Color preview;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;
  final bool showBorder;

  const _ThemeCard({
    required this.label,
    required this.preview,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.onTap,
    this.showBorder = false,
  });

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
            color: selected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.2),
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
                borderRadius: BorderRadius.circular(10),
                border: showBorder
                    ? Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.3))
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
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: children.asMap().entries.map((entry) {
        return Column(
          children: [
            entry.value,
            if (entry.key < children.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 46),
                child: Divider(
                  color: cs.outlineVariant.withValues(alpha: 0.15),
                  height: 0.5,
                  thickness: 0.5,
                ),
              ),
          ],
        );
      }).toList(),
    );
  }
}

// ── Switch row ──────────────────────────────────────────────────────────────

class _SwitchRow extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(UI.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
              Icon(icon, color: cs.onSurfaceVariant, size: 15),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  Text(subtitle,
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 11)),
                ],
              ),
            ),
            Switch.adaptive(
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
  final IconData icon;
  final String label;
  final String subtitle;
  final Color? subtitleColor;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.subtitleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(UI.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
              Icon(icon, color: cs.onSurfaceVariant, size: 15),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  Text(subtitle,
                      style: TextStyle(
                          color: subtitleColor ?? cs.onSurfaceVariant,
                          fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3), size: 18),
          ],
        ),
      ),
    );
  }
}