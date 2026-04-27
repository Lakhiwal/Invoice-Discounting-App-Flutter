import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/widgets/animated_empty_state.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lottie/lottie.dart';

enum VibeState { loading, error, empty, success }

class VibeStateWrapper extends ConsumerWidget {
  const VibeStateWrapper({
    required this.state,
    required this.child,
    super.key,
    this.loadingSkeleton,
    this.errorMessage,
    this.emptyTitle,
    this.emptySubtitle,
    this.emptyIcon,
    this.onRetry,
    this.retryLabel,
  });
  final VibeState state;
  final Widget child;
  final Widget? loadingSkeleton;
  final String? errorMessage;
  final String? emptyTitle;
  final String? emptySubtitle;
  final IconData? emptyIcon;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _buildState(context),
      );

  Widget _buildState(BuildContext context) {
    switch (state) {
      case VibeState.loading:
        return loadingSkeleton ??
            Center(
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: Theme.of(context).colorScheme.primary,
                size: 40,
              ),
            );
      case VibeState.error:
        return _ErrorState(
          message: errorMessage ?? 'Something went wrong',
          onRetry: onRetry,
          retryLabel: retryLabel,
        );
      case VibeState.empty:
        return AnimatedEmptyState(
          icon: emptyIcon ?? AppIcons.empty,
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
  const _ErrorState({
    required this.message,
    this.onRetry,
    this.retryLabel,
  });
  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                onPressed: onRetry != null
                    ? () {
                        AppHaptics.buttonPress();
                        onRetry!();
                      }
                    : null,
                icon: Icon(AppIcons.refresh),
                label: Text(retryLabel ?? 'Try Again'),
                style: TextButton.styleFrom(
                  foregroundColor: cs.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UI.radiusMd),
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
