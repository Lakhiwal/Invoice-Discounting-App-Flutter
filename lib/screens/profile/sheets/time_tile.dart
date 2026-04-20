import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';

// ── Time tile (used in quiet hours picker) ──────────────────────────────────

class ProfileTimeTile extends ConsumerWidget {
  const ProfileTimeTile({
    required this.label,
    required this.time,
    required this.onTap,
    super.key,
  });
  final String label;
  final TimeOfDay? time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: UI.md, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(UI.radiusSm),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.timer,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Text(
              time?.format(context) ?? 'Tap to set',
              style: TextStyle(
                color: time != null
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
