import 'package:flutter/material.dart';
import '../../../theme/theme_provider.dart';
import '../../../theme/ui_constants.dart';

// ── Sign out button ─────────────────────────────────────────────────────────

class ProfileSignOutButton extends StatelessWidget {
  final VoidCallback onTap;
  const ProfileSignOutButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dangerColor = AppColors.danger(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(UI.radiusMd),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: dangerColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(UI.radiusMd),
            border: Border.all(color: dangerColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: dangerColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Sign Out',
                style: TextStyle(
                  color: dangerColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}