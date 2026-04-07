import 'dart:ui' show ImageFilter, FontFeature;

import 'package:flutter/material.dart';

import '../theme/theme_provider.dart';
import '../theme/ui_constants.dart';
import '../utils/app_haptics.dart';
import 'pressable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ─────────────────────────────────────────────────────────
/// GlassCard
/// ─────────────────────────────────────────────────────────

class GlassCard extends ConsumerWidget {
  final Widget child;
  final double blur;
  final double? opacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final Color? color;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 14,
    this.opacity,
    this.borderRadius = UI.radiusMd,
    this.padding,
    this.border,
    this.boxShadow,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final effectiveOpacity = opacity ?? (isDark ? 0.10 : 0.90);

    final effectiveColor =
        color ?? colorScheme.surface.withValues(alpha: effectiveOpacity);

    final effectiveBorder = border ??
        Border.all(
          color: colorScheme.outline.withValues(alpha: isDark ? 0.25 : 0.18),
          width: 1,
        );

    final effectiveShadow = boxShadow ??
        (isDark
            ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 6),
          )
        ]
            : [
          BoxShadow(
            color:
            AppColors.primary(context).withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 4),
          )
        ]);

    final radius = BorderRadius.circular(borderRadius);

    if (blur <= 0) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: effectiveColor,
          borderRadius: radius,
          border: effectiveBorder,
          boxShadow: effectiveShadow,
        ),
        child: child,
      );
    }

    final card = RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.95 + (0.05 * value),
              child: child,
            ),
          );
        },
        child: ClipRRect(
          borderRadius: radius,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  color: effectiveColor,
                  borderRadius: radius,
                  border: effectiveBorder,
                  boxShadow: effectiveShadow,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );

    if (onTap != null) {
      return Pressable(
        onTap: () {
          AppHaptics.selection();
          onTap?.call();
        },
        child: card,
      );
    }

    return card;
  }
}

/// ─────────────────────────────────────────────────────────
/// GlassStatCard
/// ─────────────────────────────────────────────────────────

class GlassStatCard extends ConsumerWidget {
  final String label;
  final String value;
  final Widget? customValue;
  final Color? valueColor;
  final IconData? icon;
  final int staggerIndex;

  const GlassStatCard({
    super.key,
    required this.label,
    required this.value,
    this.customValue,
    this.valueColor,
    this.icon,
    this.staggerIndex = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        final double delay = staggerIndex * 0.1;
        final double animValue = (val - delay).clamp(0.0, 1.0);
        
        return Opacity(
          opacity: animValue,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - animValue)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: valueColor ?? AppColors.primary(context),
              ),
              const SizedBox(height: 4),
            ],
            if (customValue != null)
              customValue!
            else
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 11,
              ),
            ),

          ],
        ),
      ),
    );
  }
}
