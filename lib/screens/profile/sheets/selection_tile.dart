import 'package:flutter/material.dart';
import '../../../theme/ui_constants.dart';
import '../../../utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Selection tile (used in bottom sheet pickers) ───────────────────────────

class ProfileSelectionTile extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const ProfileSelectionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: UI.md, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.5)
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(UI.radiusSm),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400)),
                  Text(subtitle,
                      style: TextStyle(
                          color: colorScheme.onSurfaceVariant, fontSize: 11)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded,
                  color: colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}