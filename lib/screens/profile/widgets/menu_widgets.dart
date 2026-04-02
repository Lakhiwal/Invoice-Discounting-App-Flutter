import 'package:flutter/material.dart';
import '../../../utils/app_haptics.dart';
import '../../../widgets/pressable.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Profile menu widgets — divider-based, no card borders
// ═══════════════════════════════════════════════════════════════════════════════

// ── Section header ──────────────────────────────────────────────────────────

class ProfileSectionHeader extends StatelessWidget {
  final String label;
  const ProfileSectionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
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

// ── Card group — subtle dividers, no border/card ────────────────────────────

class ProfileCardGroup extends StatelessWidget {
  final List<Widget> children;
  const ProfileCardGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: children.asMap().entries.map((entry) {
        return Column(
          children: [
            entry.value,
            if (entry.key < children.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 50),
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

// ── Menu item ───────────────────────────────────────────────────────────────

class ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ProfileMenuItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.showChevron = true,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 15),
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
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtitleColor ?? cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              trailing!,
            ],
            if (showChevron) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Toggle item (tappable, not a switch — opens picker) ─────────────────────

class ProfileToggleItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const ProfileToggleItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileMenuItem(
      icon: icon,
      iconColor: iconColor,
      iconBg: iconBg,
      label: label,
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}

// ── Switch item ─────────────────────────────────────────────────────────────

class ProfileSwitchItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const ProfileSwitchItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Pressable(
      onTap: () async {
        await AppHaptics.selection();
        onChanged(!value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 15),
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
              onChanged: (v) async {
                await AppHaptics.selection();
                onChanged(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}