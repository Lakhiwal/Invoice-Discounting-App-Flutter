import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_provider.dart';
import '../theme/ui_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Skeleton loading system — Finworks360
// ─────────────────────────────────────────────────────────────────────────────

// ─── Theme (shared shimmer controller) ───────────────────────────────────────

// InheritedWidget carries the controller down the tree in O(1).
class _SkeletonScope extends InheritedWidget {
  final AnimationController ctrl;

  const _SkeletonScope({required this.ctrl, required super.child});

  static _SkeletonScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SkeletonScope>();

  @override
  bool updateShouldNotify(_SkeletonScope old) => old.ctrl != ctrl;
}

class SkeletonTheme extends ConsumerStatefulWidget {
  final Widget child;

  const SkeletonTheme({super.key, required this.child});

  @override
  ConsumerState<SkeletonTheme> createState() => _SkeletonThemeState();

  /// O(1) lookup via InheritedWidget (replaces findAncestorStateOfType).
  static AnimationController? ctrlOf(BuildContext context) =>
      _SkeletonScope.maybeOf(context)?.ctrl;
}

class _SkeletonThemeState extends ConsumerState<SkeletonTheme>
    with SingleTickerProviderStateMixin {
  late final AnimationController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _SkeletonScope(ctrl: ctrl, child: widget.child);
}

// ─── Bone ────────────────────────────────────────────────────────────────────

class SkeletonBox extends ConsumerWidget {
  final double? width;
  final double height;
  final BorderRadiusGeometry borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final baseColor = cs.onSurface.withValues(alpha: 0.06);
    final highlight = cs.onSurface.withValues(alpha: 0.14);
    final ctrl = SkeletonTheme.ctrlOf(context);

    if (ctrl == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: baseColor, borderRadius: borderRadius),
      );
    }

    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = ctrl.value;
        final center = -0.3 + t * 1.6;
        const halfWidth = 0.35; // slightly wider for a softer feel
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-1.0, -0.3), // tilted
              end: const Alignment(1.0, 0.3),
              colors: [baseColor, baseColor, highlight, baseColor, baseColor],
              stops: [
                0.0,
                (center - halfWidth).clamp(0.0, 1.0),
                center.clamp(0.0, 1.0),
                (center + halfWidth).clamp(0.0, 1.0),
                1.0,
              ],
            ),
            borderRadius: borderRadius,
          ),
        );
      },
    );
  }
}

// ─── Hero bone (for primaryFixed gradient cards) ─────────────────────────────

class _HeroBoneTheme extends InheritedWidget {
  final Color boneColor, boneHighlight;

  const _HeroBoneTheme(
      {required this.boneColor,
      required this.boneHighlight,
      required super.child});

  static _HeroBoneTheme of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_HeroBoneTheme>()!;

  @override
  bool updateShouldNotify(_HeroBoneTheme old) =>
      old.boneColor != boneColor || old.boneHighlight != boneHighlight;
}

class _HeroBone extends ConsumerWidget {
  final double? width;
  final double height;
  final BorderRadiusGeometry borderRadius;

  const _HeroBone(
      {this.width,
      required this.height,
      this.borderRadius = const BorderRadius.all(Radius.circular(6))});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = _HeroBoneTheme.of(context);
    final ctrl = SkeletonTheme.ctrlOf(context);
    if (ctrl == null) {
      return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
              color: theme.boneColor, borderRadius: borderRadius));
    }
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = ctrl.value;
        final center = -0.3 + t * 1.6;
        const halfWidth = 0.35;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-1.0, -0.2), // tilted
              end: const Alignment(1.0, 0.2),
              colors: [
                theme.boneColor,
                theme.boneColor,
                theme.boneHighlight,
                theme.boneColor,
                theme.boneColor
              ],
              stops: [
                0.0,
                (center - halfWidth).clamp(0.0, 1.0),
                center.clamp(0.0, 1.0),
                (center + halfWidth).clamp(0.0, 1.0),
                1.0,
              ],
            ),
            borderRadius: borderRadius,
          ),
        );
      },
    );
  }
}

// ─── Reusable building blocks ────────────────────────────────────────────────

class SkeletonCard extends ConsumerWidget {
  final double height;
  final EdgeInsetsGeometry? margin;

  const SkeletonCard({super.key, this.height = 148, this.margin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: Container(
        margin: margin,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FractionallySizedBox(
                  widthFactor: 0.6, child: SkeletonBox(height: 9)),
              const SizedBox(height: 4),
              FractionallySizedBox(
                  widthFactor: 0.8, child: SkeletonBox(height: 14)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    flex: 4,
                    child: FractionallySizedBox(
                        widthFactor: 0.7,
                        alignment: Alignment.centerLeft,
                        child: SkeletonBox(height: 10))),
                const SizedBox(width: 6),
                Expanded(
                    flex: 3,
                    child: Align(
                        alignment: Alignment.centerRight,
                        child: FractionallySizedBox(
                            widthFactor: 0.8, child: SkeletonBox(height: 14)))),
              ]),
              const SizedBox(height: 14),
              SkeletonBox(
                  width: double.infinity,
                  height: 6,
                  borderRadius: BorderRadius.circular(3)),
            ]),
          ],
        ),
      ),
    );
  }
}

class SkeletonQuickActions extends ConsumerWidget {
  const SkeletonQuickActions({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isBlack = ref.watch(themeProvider.select((p) => p.isBlackMode));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: isBlack ? Colors.transparent : cs.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isBlack ? 0.06 : 0.3)),
      ),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
              3,
              (_) => Column(mainAxisSize: MainAxisSize.min, children: [
                    SkeletonBox(
                        width: 36,
                        height: 36,
                        borderRadius: BorderRadius.circular(12)),
                    const SizedBox(height: 8),
                    SkeletonBox(width: 50, height: 10),
                  ]))),
    );
  }
}

class SkeletonHeroCard extends ConsumerWidget {
  final double height;

  const SkeletonHeroCard({super.key, this.height = 300});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isBlack = ref.watch(themeProvider.select((p) => p.isBlackMode));

    return Container(
      height: height,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isBlack ? const Color(0xFF0A0A0A) : null,
        gradient: isBlack
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cs.primaryFixedDim, cs.primaryFixed]),
        borderRadius: BorderRadius.circular(22),
        border: isBlack
            ? Border.all(color: Colors.white.withValues(alpha: 0.06))
            : null,
      ),
      child: _HeroBoneTheme(
        boneColor: isBlack
            ? Colors.white.withValues(alpha: 0.06)
            : cs.onPrimaryFixed.withValues(alpha: 0.25),
        boneHighlight: isBlack
            ? Colors.white.withValues(alpha: 0.14)
            : cs.onPrimaryFixed.withValues(alpha: 0.08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _HeroBone(
                width: 110, height: 20, borderRadius: BorderRadius.circular(6)),
            _HeroBone(
                width: 200, height: 42, borderRadius: BorderRadius.circular(8)),
            Row(
                children: List.generate(3, (i) => i)
                    .expand((i) => [
                          Expanded(
                              child: _HeroBone(
                                  height: 56,
                                  borderRadius: BorderRadius.circular(14))),
                          if (i < 2) const SizedBox(width: 8),
                        ])
                    .toList()),
            _HeroBone(
                width: double.infinity,
                height: 52,
                borderRadius: BorderRadius.circular(14)),
          ],
        ),
      ),
    );
  }
}

class SkeletonStatChips extends ConsumerWidget {
  final int count;

  const SkeletonStatChips({super.key, this.count = 4});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
      children: List.generate(count, (i) => i)
          .expand((i) => [
                Expanded(
                    child: SkeletonBox(
                        height: 72, borderRadius: BorderRadius.circular(20))),
                if (i < count - 1) const SizedBox(width: 12),
              ])
          .toList());
}

class SkeletonDonutChart extends ConsumerWidget {
  final double size;

  const SkeletonDonutChart({super.key, this.size = 160});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.onSurface.withValues(alpha: 0.06);
    final hi = cs.onSurface.withValues(alpha: 0.14);
    final hole = cs.surface;
    final ctrl = SkeletonTheme.ctrlOf(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      SizedBox(
        width: size,
        height: size,
        child: AnimatedBuilder(
          animation: ctrl ?? const AlwaysStoppedAnimation(0.0),
          builder: (_, __) {
            final t = ctrl?.value ?? 0.0;
            final dist = ((-0.3 + t * 1.6) - 0.5).abs();
            final shimmer =
                Color.lerp(base, hi, (1.0 - (dist / 0.5)).clamp(0.0, 1.0))!;
            return CustomPaint(
                painter: _DonutPainter(ringColor: shimmer, holeColor: hole));
          },
        ),
      ),
      const SizedBox(width: 20),
      Expanded(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                  5,
                  (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        SkeletonBox(
                            width: 10,
                            height: 10,
                            borderRadius: BorderRadius.circular(5)),
                        const SizedBox(width: 8),
                        SkeletonBox(width: 60 + (i % 3) * 16.0, height: 10),
                      ]))))),
    ]);
  }
}

class _DonutPainter extends CustomPainter {
  final Color ringColor, holeColor;

  const _DonutPainter({required this.ringColor, required this.holeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, size.width / 2, Paint()..color = ringColor);
    canvas.drawCircle(c, size.width / 2 * 0.52, Paint()..color = holeColor);
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.ringColor != ringColor || old.holeColor != holeColor;
}

class SkeletonInvoiceDetail extends ConsumerWidget {
  const SkeletonInvoiceDetail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return SkeletonTheme(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header app bar placeholder (matches AppLogoHeader height)
          Container(
            height: MediaQuery.of(context).padding.top + 72,
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top, 20, 0),
            child: Row(
              children: [
                SkeletonBox(
                    width: 38,
                    height: 38,
                    borderRadius: BorderRadius.circular(19)),
                const SizedBox(width: 14),
                SkeletonBox(width: 140, height: 22),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status chips
                Row(
                  children: [
                    SkeletonBox(
                        width: 80,
                        height: 24,
                        borderRadius: BorderRadius.circular(10)),
                    const SizedBox(width: 8),
                    SkeletonBox(
                        width: 100,
                        height: 24,
                        borderRadius: BorderRadius.circular(10)),
                  ],
                ),
                const SizedBox(height: 24),

                // Description line
                SkeletonBox(width: double.infinity, height: 14),
                const SizedBox(height: 8),
                SkeletonBox(width: 250, height: 14),

                const SizedBox(height: 32),

                // Metrics row
                Row(
                  children: [
                    Expanded(
                        child: SkeletonBox(
                            height: 80,
                            borderRadius: BorderRadius.circular(16))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: SkeletonBox(
                            height: 80,
                            borderRadius: BorderRadius.circular(16))),
                  ],
                ),

                const SizedBox(height: 24),

                // Progress card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SkeletonBox(width: 100, height: 12),
                          SkeletonBox(width: 80, height: 12),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SkeletonBox(
                          width: double.infinity,
                          height: 8,
                          borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Wallet hint
                SkeletonBox(
                    width: double.infinity,
                    height: 44,
                    borderRadius: BorderRadius.circular(12)),

                const SizedBox(height: 32),

                // How it works block
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: cs.primary.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 120, height: 16),
                      const SizedBox(height: 16),
                      SkeletonBox(width: double.infinity, height: 12),
                      const SizedBox(height: 8),
                      SkeletonBox(width: double.infinity, height: 12),
                      const SizedBox(height: 8),
                      SkeletonBox(width: 150, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonBarRow extends ConsumerWidget {
  final double barWidthFraction;

  const SkeletonBarRow({super.key, this.barWidthFraction = 0.7});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        SkeletonBox(width: 80, height: 11),
        const SizedBox(width: 12),
        Expanded(
            child: LayoutBuilder(
                builder: (_, c) => SkeletonBox(
                    width: c.maxWidth * barWidthFraction,
                    height: 8,
                    borderRadius: BorderRadius.circular(4)))),
        const SizedBox(width: 10),
        SkeletonBox(
            width: 38, height: 20, borderRadius: BorderRadius.circular(10)),
      ]));
}

class SkeletonStatTile extends ConsumerWidget {
  const SkeletonStatTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        SkeletonBox(
            width: 20, height: 20, borderRadius: BorderRadius.circular(4)),
        const SizedBox(width: 16),
        Expanded(child: SkeletonBox(width: 120, height: 12)),
        SkeletonBox(width: 44, height: 14),
      ]),
    );
  }
}

class SkeletonSectionHeader extends ConsumerWidget {
  const SkeletonSectionHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        SkeletonBox(width: 160, height: 16),
        SkeletonBox(
            width: 72, height: 26, borderRadius: BorderRadius.circular(20)),
      ]));
}

class SkeletonActiveStrip extends ConsumerWidget {
  final int count;

  const SkeletonActiveStrip({super.key, this.count = 3});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isBlack = ref.watch(themeProvider.select((p) => p.isBlackMode));
    return SizedBox(
      height: 130,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
            children: List.generate(
                count,
                (i) => Container(
                      width: 200,
                      margin: EdgeInsets.only(
                          left: i == 0 ? 20 : 0,
                          right: i < count - 1 ? 12 : 20),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isBlack
                            ? const Color(0xFF0A0A0A)
                            : cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                        border: isBlack
                            ? null
                            : Border.all(
                                color:
                                    cs.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SkeletonBox(width: 110, height: 12),
                                SkeletonBox(
                                    width: 30,
                                    height: 20,
                                    borderRadius: BorderRadius.circular(8)),
                              ]),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkeletonBox(width: 90, height: 20),
                                const SizedBox(height: 6),
                                SkeletonBox(width: 60, height: 10),
                              ]),
                        ],
                      ),
                    ))),
      ),
    );
  }
}

class SkeletonTabBar extends ConsumerWidget {
  const SkeletonTabBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        Expanded(
            child: SkeletonBox(
                height: double.infinity,
                borderRadius: BorderRadius.circular(10))),
        const SizedBox(width: 4),
        Expanded(
            child: SkeletonBox(
                height: double.infinity,
                borderRadius: BorderRadius.circular(10))),
      ]),
    );
  }
}

class SkeletonListTile extends ConsumerWidget {
  final EdgeInsetsGeometry? margin;
  const SkeletonListTile({super.key, this.margin});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 68,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        SkeletonBox(
            width: 40, height: 40, borderRadius: BorderRadius.circular(10)),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              SkeletonBox(width: double.infinity, height: 12),
              const SizedBox(height: 8),
              SkeletonBox(width: 100, height: 10),
            ])),
        const SizedBox(width: 12),
        SkeletonBox(width: 56, height: 12),
      ]),
    );
  }
}

class SkeletonCardList extends ConsumerWidget {
  final int count;
  final double cardHeight;

  const SkeletonCardList({super.key, this.count = 4, this.cardHeight = 148});
  @override
  Widget build(BuildContext context, WidgetRef ref) => SkeletonTheme(
          child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => SkeletonCard(height: cardHeight),
      ));
}

// ─────────────────────────────────────────────────────────────────────────────
//  MARKETPLACE
// ─────────────────────────────────────────────────────────────────────────────

class SkeletonInvoiceCard extends ConsumerWidget {
  const SkeletonInvoiceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.navyCard(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider(context)),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                SkeletonBox(width: 140, height: 14),
                const SizedBox(height: 6),
                SkeletonBox(width: 90, height: 10),
              ])),
          SkeletonBox(
              width: 72, height: 28, borderRadius: BorderRadius.circular(12)),
        ]),
        const SizedBox(height: 20),
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
                3,
                (i) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 36, height: 9),
                          const SizedBox(height: 6),
                          SkeletonBox(width: 54 + i * 12.0, height: 14),
                        ]))),
        const SizedBox(height: 12),
        Row(children: [
          SkeletonBox(
              width: 13, height: 13, borderRadius: BorderRadius.circular(7)),
          const SizedBox(width: 6),
          SkeletonBox(width: 140, height: 10),
        ]),
        const SizedBox(height: 16),
        SkeletonBox(
            width: double.infinity,
            height: 8,
            borderRadius: BorderRadius.circular(4)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          SkeletonBox(width: 90, height: 9),
          SkeletonBox(width: 36, height: 9),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PORTFOLIO
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonInvestmentCard extends ConsumerWidget {
  const _SkeletonInvestmentCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: SkeletonBox(width: 140, height: 14)),
          const SizedBox(width: 12),
          SkeletonBox(
              width: 56, height: 24, borderRadius: BorderRadius.circular(10)),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkeletonBox(width: 50, height: 9),
            const SizedBox(height: 4),
            SkeletonBox(width: 70, height: 13),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkeletonBox(width: 65, height: 9),
            const SizedBox(height: 4),
            SkeletonBox(width: 55, height: 13),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkeletonBox(width: 50, height: 9),
            const SizedBox(height: 4),
            SkeletonBox(width: 70, height: 13),
          ]),
        ]),
        const SizedBox(height: 16),
        SkeletonBox(
            width: double.infinity,
            height: 6,
            borderRadius: BorderRadius.circular(3)),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          SkeletonBox(width: 100, height: 9),
          SkeletonBox(width: 60, height: 9),
        ]),
        const SizedBox(height: 10),
        Align(
            alignment: Alignment.centerRight,
            child: SkeletonBox(width: 80, height: 9)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PROFILE
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonMenuSection extends ConsumerWidget {
  final int itemCount;

  const _SkeletonMenuSection({required this.itemCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(UI.radiusMd),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: List.generate(
            itemCount,
            (i) => Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    child: Row(children: [
                      SkeletonBox(
                          width: 34,
                          height: 34,
                          borderRadius: BorderRadius.circular(10)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            SkeletonBox(
                                width: 100 + (i % 3) * 20.0, height: 12),
                            const SizedBox(height: 5),
                            SkeletonBox(width: 140 + (i % 2) * 30.0, height: 9),
                          ])),
                      SkeletonBox(
                          width: 18,
                          height: 18,
                          borderRadius: BorderRadius.circular(4)),
                    ]),
                  ),
                  if (i < itemCount - 1)
                    Divider(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                      indent: 58,
                    ),
                ])),
      ),
    );
  }
}

// ─── Portfolio Helpers ────────────────────────────────────────────────────────

class SkeletonPortfolioHeader extends ConsumerWidget {
  const SkeletonPortfolioHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return SkeletonTheme(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Expanded(
              child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkeletonBox(
                  width: 20,
                  height: 20,
                  borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 12),
              SkeletonBox(width: 90, height: 16),
              const SizedBox(height: 4),
              SkeletonBox(width: 55, height: 10),
            ]),
          )),
          const SizedBox(width: 12),
          Expanded(
              child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.emerald(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkeletonBox(
                  width: 20,
                  height: 20,
                  borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 12),
              SkeletonBox(width: 90, height: 16),
              const SizedBox(height: 4),
              SkeletonBox(width: 55, height: 10),
            ]),
          )),
        ]),
      ),
    );
  }
}

class SkeletonPortfolioContent extends ConsumerWidget {
  const SkeletonPortfolioContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SkeletonTheme(
          child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(4, (_) => const _SkeletonInvestmentCard()),
      ));
}

class SkeletonAnalyticsContent extends ConsumerWidget {
  const SkeletonAnalyticsContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return SkeletonTheme(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        child: ConstrainedBox(
          constraints:
              BoxConstraints(minHeight: MediaQuery.of(context).size.height),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: const SkeletonStatChips(count: 2)),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.1)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 140, height: 16),
                      const SizedBox(height: 24),
                      SkeletonDonutChart(size: 160),
                    ]),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 140, height: 16),
                    const SizedBox(height: 16),
                    const SkeletonStatTile(),
                    const SkeletonStatTile(),
                    const SkeletonStatTile(),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class SkeletonHomeContent extends ConsumerWidget {
  const SkeletonHomeContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SkeletonTheme(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ConstrainedBox(
          constraints:
              BoxConstraints(minHeight: MediaQuery.of(context).size.height),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Portfolio Hero
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SkeletonHeroCard(),
              ),
              const SizedBox(height: 16),

              // Quick Actions
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SkeletonQuickActions(),
              ),
              const SizedBox(height: 28),

              // Section Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: SkeletonBox(width: 160, height: 18),
              ),
              const SizedBox(height: 12),

              // Active Investments Horizontal
              SizedBox(
                height: 130,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: 3,
                  itemBuilder: (_, __) => Container(
                    width: 240,
                    margin: const EdgeInsets.only(right: 12),
                    child: SkeletonBox(
                        borderRadius: BorderRadius.circular(20), height: 130),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Recent Activity Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: SkeletonBox(width: 140, height: 18),
              ),
              const SizedBox(height: 12),

              // Activity List
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: List.generate(4, (_) => const SkeletonStatTile()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SkeletonMarketplaceContent extends ConsumerWidget {
  const SkeletonMarketplaceContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SkeletonTheme(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(top: 20),
        child: ConstrainedBox(
          constraints:
              BoxConstraints(minHeight: MediaQuery.of(context).size.height),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar placeholder
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SkeletonBox(
                    width: double.infinity,
                    height: 54,
                    borderRadius: BorderRadius.circular(16)),
              ),
              const SizedBox(height: 20),

              // Filters chips
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SkeletonStatChips(count: 3),
              ),
              const SizedBox(height: 20),

              // List items
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: List.generate(
                      5,
                      (_) => const SkeletonCard(
                          margin: EdgeInsets.only(bottom: 16))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Profile ──────────────────────────────────────────────────────────────────

class SkeletonProfileContent extends ConsumerWidget {
  const SkeletonProfileContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return SkeletonTheme(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(children: [
            Hero(
              tag: 'profile-avatar',
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primaryContainer,
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SkeletonBox(width: 180, height: 18),
            const SizedBox(height: 4),
            SkeletonBox(width: 200, height: 12),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SkeletonBox(
                  width: 80,
                  height: 22,
                  borderRadius: BorderRadius.circular(20)),
              const SizedBox(width: 6),
              SkeletonBox(
                  width: 56,
                  height: 22,
                  borderRadius: BorderRadius.circular(20)),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(UI.radiusMd),
                border:
                    Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBox(width: 110, height: 10),
                      SkeletonBox(
                          width: 70,
                          height: 18,
                          borderRadius: BorderRadius.circular(20)),
                    ]),
                const SizedBox(height: 10),
                SkeletonBox(
                    width: double.infinity,
                    height: 4,
                    borderRadius: BorderRadius.circular(2)),
                const SizedBox(height: 8),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                        5, (_) => SkeletonBox(width: 34, height: 9))),
              ]),
            ),
            const SizedBox(height: 16),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              bottom:
                  BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
            ),
          ),
          child: Row(
              children: List.generate(3, (i) => i)
                  .expand((i) => [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(UI.radiusSm),
                              border: Border.all(
                                  color:
                                      cs.outlineVariant.withValues(alpha: 0.3)),
                            ),
                            child: Column(children: [
                              SkeletonBox(width: 60, height: 16),
                              const SizedBox(height: 4),
                              SkeletonBox(width: 50, height: 9),
                            ]),
                          ),
                        ),
                        if (i < 2) const SizedBox(width: 8),
                      ])
                  .toList()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionLabel(),
            const _SkeletonMenuSection(itemCount: 4),
            const SizedBox(height: UI.md),
            _sectionLabel(),
            const _SkeletonMenuSection(itemCount: 4),
            const SizedBox(height: UI.md),
            _sectionLabel(),
            const _SkeletonMenuSection(itemCount: 1),
            const SizedBox(height: UI.md),
            _sectionLabel(),
            const _SkeletonMenuSection(itemCount: 3),
            const SizedBox(height: UI.lg),
            SkeletonBox(
                width: double.infinity,
                height: 48,
                borderRadius: BorderRadius.circular(UI.radiusMd)),
            const SizedBox(height: 100),
          ]),
        ),
      ]),
    );
  }

  static Widget _sectionLabel() => Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: SkeletonBox(width: 80, height: 10));
}

class SkeletonPersonalDetails extends ConsumerWidget {
  const SkeletonPersonalDetails({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return SkeletonTheme(
      child: Column(
        children: [
          // Hero Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                SkeletonBox(
                    width: 80,
                    height: 80,
                    borderRadius: BorderRadius.circular(40)),
                const SizedBox(height: 16),
                SkeletonBox(width: 180, height: 20),
                const SizedBox(height: 8),
                SkeletonBox(width: 220, height: 14),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Details Card
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: List.generate(
                  6,
                  (i) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          SkeletonBox(
                              width: 24,
                              height: 24,
                              borderRadius: BorderRadius.circular(6)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkeletonBox(width: 80, height: 10),
                                const SizedBox(height: 6),
                                SkeletonBox(width: 160, height: 14),
                              ],
                            ),
                          ),
                        ]),
                      )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonNomineeList extends ConsumerWidget {
  const SkeletonNomineeList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return SkeletonTheme(
      child: Column(
        children: List.generate(
            3,
            (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        SkeletonBox(
                            width: 52,
                            height: 52,
                            borderRadius: BorderRadius.circular(16)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBox(width: 140, height: 16),
                              const SizedBox(height: 8),
                              SkeletonBox(width: 80, height: 12),
                            ],
                          ),
                        ),
                        SkeletonBox(
                            width: 48,
                            height: 24,
                            borderRadius: BorderRadius.circular(12)),
                      ],
                    ),
                  ),
                )),
      ),
    );
  }
}

class SkeletonBankAccountList extends ConsumerWidget {
  const SkeletonBankAccountList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return SkeletonTheme(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 140, height: 14),
          const SizedBox(height: 16),
          ...List.generate(
              3,
              (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          SkeletonBox(
                              width: 48,
                              height: 48,
                              borderRadius: BorderRadius.circular(14)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkeletonBox(width: 120, height: 14),
                                const SizedBox(height: 8),
                                SkeletonBox(width: 180, height: 12),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
        ],
      ),
    );
  }
}

class SkeletonNotificationContent extends ConsumerWidget {
  const SkeletonNotificationContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SkeletonTheme(
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: 8,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const SkeletonNotificationTile(),
      ),
    );
  }
}

class SkeletonNotificationTile extends ConsumerWidget {
  const SkeletonNotificationTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(
              width: 44, height: 44, borderRadius: BorderRadius.circular(14)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBox(width: 120, height: 14),
                    SkeletonBox(width: 40, height: 10),
                  ],
                ),
                const SizedBox(height: 8),
                SkeletonBox(width: double.infinity, height: 12),
                const SizedBox(height: 4),
                SkeletonBox(width: 200, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonOtpContent extends ConsumerWidget {
  const SkeletonOtpContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SkeletonTheme(
      child: Column(
        children: [
          const SizedBox(height: 40),
          SkeletonBox(width: 200, height: 28),
          const SizedBox(height: 12),
          SkeletonBox(width: 280, height: 16),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                6,
                (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: SkeletonBox(
                          width: 44,
                          height: 56,
                          borderRadius: BorderRadius.circular(12)),
                    )),
          ),
          const SizedBox(height: 40),
          SkeletonBox(width: 180, height: 14),
          const SizedBox(height: 60),
          SkeletonBox(
              width: double.infinity,
              height: 56,
              borderRadius: BorderRadius.circular(16)),
        ],
      ),
    );
  }
}

class SkeletonShieldContent extends ConsumerWidget {
  const SkeletonShieldContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SkeletonTheme(
      child: Column(
        children: [
          const SizedBox(height: 20),
          SkeletonBox(
              width: 48, height: 48, borderRadius: BorderRadius.circular(24)),
          const SizedBox(height: 16),
          SkeletonBox(width: 220, height: 24),
          const SizedBox(height: 8),
          SkeletonBox(width: 280, height: 14),
          const SizedBox(height: 40),
          SkeletonBox(
              width: 160, height: 160, borderRadius: BorderRadius.circular(24)),
          const SizedBox(height: 24),
          SkeletonBox(width: 140, height: 12),
          const SizedBox(height: 8),
          SkeletonBox(
              width: 180, height: 32, borderRadius: BorderRadius.circular(8)),
          const SizedBox(height: 40),
          SkeletonBox(
              width: double.infinity,
              height: 56,
              borderRadius: BorderRadius.circular(16)),
        ],
      ),
    );
  }
}
