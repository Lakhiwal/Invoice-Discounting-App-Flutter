import 'dart:ui' show ImageFilter, FontFeature;

import 'package:flutter/material.dart';

import '../theme/theme_provider.dart';
import '../theme/ui_constants.dart';

/// ─────────────────────────────────────────────────────────
/// GlassCard
/// ─────────────────────────────────────────────────────────

class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double? opacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final Color? color;

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
  });

  @override
  Widget build(BuildContext context) {
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

    return RepaintBoundary(
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
    );
  }
}

/// ─────────────────────────────────────────────────────────
/// GlassStatCard
/// ─────────────────────────────────────────────────────────

class GlassStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Widget? customValue;
  final Color? valueColor;
  final IconData? icon;

  const GlassStatCard({
    super.key,
    required this.label,
    required this.value,
    this.customValue,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
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
    );
  }
}
