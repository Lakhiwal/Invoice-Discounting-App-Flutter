import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/widgets/skeleton.dart';

// ── Error state ─────────────────────────────────────────────────────────────

class ProfileErrorState extends ConsumerWidget {
  const ProfileErrorState({required this.onRetry, super.key});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.wifiOff,
              size: 48,
              color: colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              "Couldn't load your profile",
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onRetry,
              icon: Icon(AppIcons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton ────────────────────────────────────────────────────────────────

class ProfileSkeleton extends ConsumerWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const SkeletonTheme(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20),
                Row(
                  children: [
                    SkeletonBox(
                      width: 64,
                      height: 64,
                      borderRadius: BorderRadius.all(Radius.circular(32)),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 140, height: 16),
                          SizedBox(height: 6),
                          SkeletonBox(width: 180, height: 12),
                          SizedBox(height: 8),
                          SkeletonBox(width: 120, height: 14),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                SkeletonCard(height: 80),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: SkeletonCard(height: 60)),
                    SizedBox(width: 8),
                    Expanded(child: SkeletonCard(height: 60)),
                    SizedBox(width: 8),
                    Expanded(child: SkeletonCard(height: 60)),
                  ],
                ),
                SizedBox(height: 24),
                SkeletonListTile(),
                SizedBox(height: UI.sm),
                SkeletonListTile(),
                SizedBox(height: UI.sm),
                SkeletonListTile(),
                SizedBox(height: UI.sm),
                SkeletonListTile(),
              ],
            ),
          ),
        ),
      );
}
