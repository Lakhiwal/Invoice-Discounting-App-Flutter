import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';

// ── Status pill ─────────────────────────────────────────────────────────────

class ProfileStatusPill extends ConsumerWidget {
  const ProfileStatusPill({
    required this.label,
    required this.color,
    super.key,
  });
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(UI.radiusSm), // Sharp pill
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

// ── Info banner ─────────────────────────────────────────────────────────────

class ProfileInfoBanner extends ConsumerWidget {
  const ProfileInfoBanner({
    required this.icon,
    required this.text,
    required this.color,
    super.key,
  });
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(UI.radiusSm), // Sharp banner
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: UI.sm),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
}
