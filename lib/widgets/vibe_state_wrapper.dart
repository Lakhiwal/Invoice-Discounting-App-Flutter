import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'animated_empty_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum VibeState { loading, error, empty, success }

class VibeStateWrapper extends ConsumerWidget {
  final VibeState state;
  final Widget child;
  final Widget? loadingSkeleton;
  final String? errorMessage;
  final String? emptyTitle;
  final String? emptySubtitle;
  final IconData? emptyIcon;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const VibeStateWrapper({
    super.key,
    required this.state,
    required this.child,
    this.loadingSkeleton,
    this.errorMessage,
    this.emptyTitle,
    this.emptySubtitle,
    this.emptyIcon,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _buildState(context),
    );
  }

  Widget _buildState(BuildContext context) {
    switch (state) {
      case VibeState.loading:
        return loadingSkeleton ?? const Center(child: CircularProgressIndicator());
      case VibeState.error:
        return _ErrorState(
          message: errorMessage ?? 'Something went wrong',
          onRetry: onRetry,
          retryLabel: retryLabel,
        );
      case VibeState.empty:
        return AnimatedEmptyState(
          icon: emptyIcon ?? Icons.inbox_outlined,
          title: emptyTitle ?? 'No data found',
          subtitle: emptySubtitle,
          actionLabel: retryLabel,
          onAction: onRetry,
        );
      case VibeState.success:
        return child;
    }
  }
}

class _ErrorState extends ConsumerWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const _ErrorState({
    required this.message,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/payment_failed.json',
              width: 180,
              repeat: false,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retryLabel ?? 'Try Again'),
                style: TextButton.styleFrom(
                  foregroundColor: cs.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: cs.primary.withValues(alpha: 0.2)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
