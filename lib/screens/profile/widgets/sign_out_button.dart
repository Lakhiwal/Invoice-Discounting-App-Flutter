import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';

// ── Sign out button ─────────────────────────────────────────────────────────

class ProfileSignOutButton extends ConsumerWidget {
  const ProfileSignOutButton({required this.onTap, super.key});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dangerColor = AppColors.danger(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          unawaited(AppHaptics.navTap());
          onTap();
        },
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
              Icon(AppIcons.logout, color: dangerColor, size: 18),
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
