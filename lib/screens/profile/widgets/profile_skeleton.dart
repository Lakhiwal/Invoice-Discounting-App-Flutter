import 'package:flutter/material.dart';
import '../../../theme/ui_constants.dart';
import '../../../widgets/skeleton.dart';

// ── Error state ─────────────────────────────────────────────────────────────

class ProfileErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const ProfileErrorState({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 48,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('Couldn\'t load your profile',
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: colorScheme.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton ────────────────────────────────────────────────────────────────

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonTheme(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Row(
                children: const [
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
              const SizedBox(height: 20),
              const SkeletonCard(height: 80),
              const SizedBox(height: 16),
              Row(
                children: const [
                  Expanded(child: SkeletonCard(height: 60)),
                  SizedBox(width: 8),
                  Expanded(child: SkeletonCard(height: 60)),
                  SizedBox(width: 8),
                  Expanded(child: SkeletonCard(height: 60)),
                ],
              ),
              const SizedBox(height: 24),
              const SkeletonListTile(),
              const SizedBox(height: UI.sm),
              const SkeletonListTile(),
              const SizedBox(height: UI.sm),
              const SkeletonListTile(),
              const SizedBox(height: UI.sm),
              const SkeletonListTile(),
            ],
          ),
        ),
      ),
    );
  }
}