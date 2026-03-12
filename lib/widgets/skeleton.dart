import 'package:flutter/material.dart';

import '../theme/theme_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Skeleton loading system
//
//  A single shared AnimationController (via SkeletonTheme) drives all
//  skeleton bones on screen simultaneously — one GPU raster pass, not N.
//
//  Usage:
//    SkeletonTheme(
//      child: Column(children: [
//        SkeletonCard(),
//        SkeletonCard(),
//        SkeletonListTile(),
//      ]),
//    )
//
//    // Standalone bone anywhere:
//    SkeletonBox(width: 120, height: 14)
// ─────────────────────────────────────────────────────────────────────────────

// ─── Theme (shared controller) ───────────────────────────────────────────────

class SkeletonTheme extends StatefulWidget {
  final Widget child;

  const SkeletonTheme({super.key, required this.child});

  @override
  State<SkeletonTheme> createState() => _SkeletonThemeState();

  static _SkeletonThemeState? _of(BuildContext context) =>
      context.findAncestorStateOfType<_SkeletonThemeState>();
}

class _SkeletonThemeState extends State<SkeletonTheme>
    with SingleTickerProviderStateMixin {
  late final AnimationController ctrl;
  late final Animation<double> pulse;

  @override
  void initState() {
    super.initState();
    ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    pulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ─── Bone (base building block) ──────────────────────────────────────────────

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadiusGeometry borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
    isDark ? const Color(0xFF1A2540) : const Color(0xFFE8EDF8);
    final highlight =
    isDark ? const Color(0xFF243050) : const Color(0xFFF4F7FF);

    final state = SkeletonTheme._of(context);

    // Item #27: warn in debug mode when SkeletonTheme ancestor is missing
    assert(() {
      if (state == null) {
        debugPrint('⚠ SkeletonBox: no SkeletonTheme ancestor found — shimmer disabled');
      }
      return true;
    }());

    if (state == null) {
      return Container(
        width: width,
        height: height,
        decoration:
        BoxDecoration(color: baseColor, borderRadius: borderRadius),
      );
    }

    return AnimatedBuilder(
      animation: state.pulse,
      builder: (_, __) {
        final t = state.pulse.value;

        // FIX (shimmer): instead of a flat lerp between two solid colors,
        // paint a left-to-right gradient shimmer that sweeps across the bone.
        // This matches the shimmer effect used in Revolut, Groww, Zerodha —
        // it reads as "content loading" rather than "pulsing blob".
        // The gradient shift is driven by the shared pulse animation so all
        // bones sweep in lockstep (one GPU pass).
        final shimmerColor = Color.lerp(baseColor, highlight, t)!;
        final shimmerEdge = Color.lerp(highlight, baseColor, t)!;

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, shimmerColor, shimmerEdge, baseColor],
              stops: [0.0, (t * 0.5).clamp(0.1, 0.45), (t * 0.5 + 0.3).clamp(0.45, 0.9), 1.0],
            ),
            borderRadius: borderRadius,
          ),
        );
      },
    );
  }
}

// ─── Card skeleton ────────────────────────────────────────────────────────────

class SkeletonCard extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry? margin;

  const SkeletonCard({
    super.key,
    this.height = 148,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: margin,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.navyCard(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(context)),
      ),
      // FIX: replaced Column + Spacer with Column + mainAxisAlignment spacing.
      // Spacer inside a fixed-height Container is fine at default text scale,
      // but if the container is ever used without a height constraint (e.g.
      // inside a Column with no bounded height parent) it throws unbounded
      // height. Using mainAxisAlignment: spaceBetween removes the Spacer
      // dependency entirely.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 160, height: 13),
              const SizedBox(height: 8),
              SkeletonBox(width: 100, height: 10),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SkeletonBox(width: 52, height: 10),
                  const SizedBox(width: 20),
                  SkeletonBox(width: 52, height: 10),
                  const SizedBox(width: 20),
                  SkeletonBox(width: 64, height: 10),
                ],
              ),
              const SizedBox(height: 14),
              SkeletonBox(width: double.infinity, height: 6),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── List-tile skeleton ───────────────────────────────────────────────────────

class SkeletonListTile extends StatelessWidget {
  final EdgeInsetsGeometry? margin;

  const SkeletonListTile({super.key, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.navyCard(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(context)),
      ),
      child: Row(
        children: [
          SkeletonBox(
            width: 40,
            height: 40,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SkeletonBox(width: double.infinity, height: 12),
                const SizedBox(height: 8),
                SkeletonBox(width: 100, height: 10),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SkeletonBox(width: 56, height: 12),
        ],
      ),
    );
  }
}

// ─── Convenience: a column of N SkeletonCards ────────────────────────────────

class SkeletonCardList extends StatelessWidget {
  final int count;
  final double cardHeight;

  const SkeletonCardList({
    super.key,
    this.count = 4,
    this.cardHeight = 148,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonTheme(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => SkeletonCard(height: cardHeight),
      ),
    );
  }
}