import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Profile menu widgets — divider-based, no card borders
// ═══════════════════════════════════════════════════════════════════════════════

// ── Section header ──────────────────────────────────────────────────────────

class ProfileSectionHeader extends ConsumerWidget {
  const ProfileSectionHeader({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
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

// ── Card group — Rounded glassmorphism-style container ─────────────────────

class ProfileCardGroup extends ConsumerWidget {
  const ProfileCardGroup({required this.children, super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(UI.radiusMd), // Sharp aesthetic
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.2),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
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
                      indent: 60,
                      endIndent: 20,
                    ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

// ── Menu item ───────────────────────────────────────────────────────────────

class ProfileMenuItem extends ConsumerStatefulWidget {
  const ProfileMenuItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.onTap,
    super.key,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.onLongPress,
  });
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? trailing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  ConsumerState<ProfileMenuItem> createState() => _ProfileMenuItemState();
}

class _ProfileMenuItemState extends ConsumerState<ProfileMenuItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          color: Colors.transparent, // Ensure full hit area
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.iconBg,
                      widget.iconBg.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(UI.radiusSm), // Sharp icon box
                  boxShadow: [
                    BoxShadow(
                      color: widget.iconColor.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 16),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (widget.subtitle != null &&
                        widget.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.subtitleColor ?? cs.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                widget.trailing!,
              ] else
                Icon(
                  AppIcons.chevronRight,
                  size: 18,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Toggle item (tappable, not a switch — opens picker) ─────────────────────

class ProfileToggleItem extends ConsumerWidget {
  const ProfileToggleItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ProfileMenuItem(
        icon: icon,
        iconColor: iconColor,
        iconBg: iconBg,
        label: label,
        subtitle: subtitle,
        onTap: onTap,
      );
}

// ── Quiet Hours Tile (Time display) ─────────────────────────────────────────

class QuietHoursTile extends ConsumerWidget {
  const QuietHoursTile({
    required this.startTime,
    required this.endTime,
    required this.onTap,
    super.key,
  });
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startStr = startTime.format(context);
    final endStr = endTime.format(context);

    return ProfileMenuItem(
      icon: AppIcons.quiet,
      iconColor: AppColors.warning(context),
      iconBg: AppColors.warning(context).withValues(alpha: 0.1),
      label: 'Quiet hours',
      subtitle: '$startStr – $endStr',
      onTap: onTap,
    );
  }
}
