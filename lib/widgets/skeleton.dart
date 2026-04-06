import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

class SkeletonTheme extends StatefulWidget {
  final Widget child;

  const SkeletonTheme({super.key, required this.child});

  @override
  State<SkeletonTheme> createState() => _SkeletonThemeState();

  /// O(1) lookup via InheritedWidget (replaces findAncestorStateOfType).
  static AnimationController? ctrlOf(BuildContext context) =>
      _SkeletonScope.maybeOf(context)?.ctrl;
}

class _SkeletonThemeState extends State<SkeletonTheme>
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

class SkeletonBox extends StatelessWidget {
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
  Widget build(BuildContext context) {
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

class _HeroBone extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadiusGeometry borderRadius;

  const _HeroBone(
      {this.width,
        required this.height,
        this.borderRadius = const BorderRadius.all(Radius.circular(6))});

  @override
  Widget build(BuildContext context) {
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

class SkeletonCard extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry? margin;

  const SkeletonCard({super.key, this.height = 148, this.margin});

  @override
  Widget build(BuildContext context) {
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

class SkeletonQuickActions extends StatelessWidget {
  const SkeletonQuickActions({super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isBlack = context.select<ThemeProvider, bool>((p) => p.isBlackMode);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: isBlack ? Colors.transparent : cs.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: cs.outlineVariant
                .withValues(alpha: isBlack ? 0.06 : 0.3)),
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

class SkeletonHeroCard extends StatelessWidget {
  final double height;

  const SkeletonHeroCard({super.key, this.height = 300});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isBlack = context.select<ThemeProvider, bool>((p) => p.isBlackMode);

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

class SkeletonStatChips extends StatelessWidget {
  final int count;

  const SkeletonStatChips({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) => Row(
      children: List.generate(count, (i) => i)
          .expand((i) => [
        Expanded(
            child: SkeletonBox(
                height: 72, borderRadius: BorderRadius.circular(20))),
        if (i < count - 1) const SizedBox(width: 12),
      ])
          .toList());
}

class SkeletonDonutChart extends StatelessWidget {
  final double size;

  const SkeletonDonutChart({super.key, this.size = 160});

  @override
  Widget build(BuildContext context) {
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

class SkeletonBarRow extends StatelessWidget {
  final double barWidthFraction;

  const SkeletonBarRow({super.key, this.barWidthFraction = 0.7});

  @override
  Widget build(BuildContext context) => Padding(
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

class SkeletonStatTile extends StatelessWidget {
  const SkeletonStatTile({super.key});

  @override
  Widget build(BuildContext context) {
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

class SkeletonSectionHeader extends StatelessWidget {
  const SkeletonSectionHeader({super.key});

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        SkeletonBox(width: 160, height: 16),
        SkeletonBox(
            width: 72, height: 26, borderRadius: BorderRadius.circular(20)),
      ]));
}

class SkeletonActiveStrip extends StatelessWidget {
  final int count;

  const SkeletonActiveStrip({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isBlack = context.select<ThemeProvider, bool>((p) => p.isBlackMode);
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

class SkeletonTabBar extends StatelessWidget {
  const SkeletonTabBar({super.key});

  @override
  Widget build(BuildContext context) {
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

class SkeletonListTile extends StatelessWidget {
  final EdgeInsetsGeometry? margin;
  const SkeletonListTile({super.key, this.margin});
  @override
  Widget build(BuildContext context) {
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

class SkeletonCardList extends StatelessWidget {
  final int count;
  final double cardHeight;

  const SkeletonCardList({super.key, this.count = 4, this.cardHeight = 148});
  @override
  Widget build(BuildContext context) => SkeletonTheme(
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

class SkeletonInvoiceCard extends StatelessWidget {
  const SkeletonInvoiceCard({super.key});

  @override
  Widget build(BuildContext context) {
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

class _SkeletonInvestmentCard extends StatelessWidget {
  const _SkeletonInvestmentCard();

  @override
  Widget build(BuildContext context) {
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

class _SkeletonMenuSection extends StatelessWidget {
  final int itemCount;

  const _SkeletonMenuSection({required this.itemCount});

  @override
  Widget build(BuildContext context) {
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
                            SkeletonBox(
                                width: 140 + (i % 2) * 30.0, height: 9),
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

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN-LEVEL COMPOSITIONS
// ─────────────────────────────────────────────────────────────────────────────

class SkeletonHomeContent extends StatelessWidget {
  const SkeletonHomeContent({super.key});

  @override
  Widget build(BuildContext context) => SkeletonTheme(
      child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: SkeletonHeroCard(height: 300)),
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: const SkeletonQuickActions()),
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
            child: const SkeletonSectionHeader()),
        const SkeletonActiveStrip(count: 3),
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
            child: const SkeletonSectionHeader()),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
                children: List.generate(
                    3,
                        (_) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: const SkeletonListTile())))),
      ]));
}

class SkeletonMarketplaceContent extends StatelessWidget {
  final int cardCount;

  const SkeletonMarketplaceContent({super.key, this.cardCount = 3});

  @override
  Widget build(BuildContext context) => SkeletonTheme(
      child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
              children: List.generate(
                  cardCount, (_) => const SkeletonInvoiceCard()))));
}

class SkeletonPortfolioHeader extends StatelessWidget {
  const SkeletonPortfolioHeader({super.key});

  @override
  Widget build(BuildContext context) {
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

class SkeletonPortfolioContent extends StatelessWidget {
  const SkeletonPortfolioContent({super.key});

  @override
  Widget build(BuildContext context) => SkeletonTheme(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(4, (_) => const _SkeletonInvestmentCard()),
      ));
}

class SkeletonAnalyticsContent extends StatelessWidget {
  const SkeletonAnalyticsContent({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SkeletonTheme(
      child: SingleChildScrollView(
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

// ─── Profile ──────────────────────────────────────────────────────────────────

class SkeletonProfileContent extends StatelessWidget {
  const SkeletonProfileContent({super.key});

  @override
  Widget build(BuildContext context) {
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