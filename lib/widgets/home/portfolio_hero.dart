import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/widgets/animated_amount_text.dart';
import 'package:invoice_discounting_app/widgets/glass_card.dart';
import 'package:invoice_discounting_app/widgets/gradient_text.dart';
import 'package:invoice_discounting_app/widgets/pressable.dart';

const String _kMaskedShort = '● ● ●';

class PortfolioHero extends ConsumerStatefulWidget {
  const PortfolioHero({
    required this.totalInvested,
    required this.wallet,
    required this.irr,
    required this.activeCount,
    required this.repaidCount,
    required this.isBlackMode,
    required this.onAdd,
    required this.onWithdraw,
    required this.onToggleHide,
    super.key,
  });
  final double totalInvested;
  final double wallet;
  final double irr;
  final dynamic activeCount;
  final dynamic repaidCount;
  final bool isBlackMode;
  final VoidCallback onAdd;
  final VoidCallback onWithdraw;
  final VoidCallback onToggleHide;

  @override
  ConsumerState<PortfolioHero> createState() => _PortfolioHeroState();
}

class _PortfolioHeroState extends ConsumerState<PortfolioHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scale = Tween<double>(begin: 1, end: 1.025).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOutBack),
    );
  }

  Future<void> pulse() async {
    AppHaptics.selection();
    await _pulseCtrl.forward();
    await _pulseCtrl.reverse();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hide = ref.watch(themeProvider.select((p) => p.hideBalance));
    final isBlack = widget.isBlackMode;

    return Pressable(
      scale: 0.98,
      onTap: pulse,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: isBlack
            ? _buildBlackHero(colorScheme, hide)
            : _buildDarkHero(colorScheme, hide),
      ),
    );
  }

  Widget _buildBlackHero(ColorScheme colorScheme, bool hide) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(UI.radiusLg),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(UI.radiusSm),
                    ),
                    child: Text(
                      'E-Collect Balance',
                      style: TextStyle(
                        color: (widget.isBlackMode
                                ? colorScheme.onSurface
                                : Colors.white)
                            .withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onToggleHide,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(UI.radiusSm),
                      ),
                      child: Icon(
                        hide ? AppIcons.eyeSlash : AppIcons.eye,
                        color: Colors.white.withValues(alpha: 0.4),
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedAmountText(
                key: const ValueKey('home_total_invested'),
                value: widget.totalInvested,
                prefix: '₹',
                hideValue: hide,
                onCompleted: pulse,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: BlackStatCard(
                      label: 'IRR',
                      amountValue: widget.irr,
                      suffix: '%',
                      hideValue: hide,
                      valueColor: const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: BlackStatCard(
                      label: 'Active',
                      amountValue: (widget.activeCount as num).toDouble(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: BlackStatCard(
                      label: 'Repaid',
                      amountValue: (widget.repaidCount as num).toDouble(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(UI.radiusMd),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.bank,
                      color: Colors.white.withValues(alpha: 0.35),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'E-Collect Balance',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 11,
                            ),
                          ),
                          AnimatedAmountText(
                            key: const ValueKey('home_ecollect_balance'),
                            value: widget.wallet,
                            prefix: '₹',
                            hideValue: hide,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildDarkHero(ColorScheme colorScheme, bool hide) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colorScheme.primaryFixedDim, colorScheme.primaryFixed],
          ),
          borderRadius: BorderRadius.circular(UI.radiusLg),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const Positioned.fill(child: HeroTexture()),
            Positioned(
              right: -60,
              top: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              left: -40,
              bottom: -70,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(UI.radiusSm),
                        ),
                        child: const Text(
                          'PORTFOLIO VALUE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onToggleHide,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(UI.radiusSm),
                          ),
                          child: Icon(
                            hide ? AppIcons.eyeSlash : AppIcons.eye,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => GradientText.blue.createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                    ),
                    child: AnimatedAmountText(
                      value: widget.totalInvested,
                      prefix: '₹',
                      hideValue: hide,
                      onCompleted: pulse,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GlassStatCard(
                          label: 'IRR',
                          value: hide
                              ? '$_kMaskedShort%'
                              : '${widget.irr.toStringAsFixed(2)}%',
                          customValue: AnimatedAmountText(
                            value: widget.irr,
                            suffix: '%',
                            hideValue: hide,
                            style: const TextStyle(
                              color: Color(0xFF22C55E),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          valueColor: const Color(0xFF22C55E),
                          icon: AppIcons.trendingUp,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GlassStatCard(
                          label: 'Active',
                          value: '${(widget.activeCount as num).toInt()}',
                          staggerIndex: 1,
                          icon: AppIcons.pending,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GlassStatCard(
                          label: 'Repaid',
                          value: '${(widget.repaidCount as num).toInt()}',
                          staggerIndex: 2,
                          icon: AppIcons.check,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GlassCard(
                    blur: 12,
                    opacity: 0.1,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    boxShadow: const [],
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.bank,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'E-Collect Balance',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                ),
                              ),
                              AnimatedAmountText(
                                value: widget.wallet,
                                prefix: '₹',
                                hideValue: hide,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
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

class BlackStatCard extends ConsumerWidget {
  const BlackStatCard({
    required this.label,
    super.key,
    this.amountValue,
    this.prefix = '',
    this.suffix = '',
    this.hideValue = false,
    this.valueColor,
  });
  final String label;
  final double? amountValue;
  final String prefix;
  final String suffix;
  final bool hideValue;
  final Color? valueColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(UI.radiusMd),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            if (amountValue != null)
              AnimatedAmountText(
                value: amountValue!,
                prefix: prefix,
                suffix: suffix,
                hideValue: hideValue,
                style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              const SizedBox.shrink(),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
}

class HeroTexture extends ConsumerWidget {
  const HeroTexture({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      CustomPaint(painter: DotGridPainter());
}

class DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..style = PaintingStyle.fill;
    const spacing = 22.0;
    const radius = 1.2;
    for (var x = spacing; x < size.width; x += spacing) {
      for (var y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotGridPainter old) => false;
}
