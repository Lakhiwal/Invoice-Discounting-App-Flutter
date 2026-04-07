import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/theme_provider.dart';
import '../../utils/app_haptics.dart';
import '../../utils/formatters.dart';
import '../animated_amount_text.dart';
import '../glass_card.dart';
import '../gradient_text.dart';

const String _kMaskedShort = '● ● ●';

class PortfolioHero extends ConsumerStatefulWidget {
  final double totalInvested, wallet, returns;
  final dynamic activeCount, repaidCount;
  final bool isBlackMode;
  final VoidCallback onAdd, onWithdraw, onToggleHide;

  const PortfolioHero({
    super.key,
    required this.totalInvested,
    required this.wallet,
    required this.returns,
    required this.activeCount,
    required this.repaidCount,
    required this.isBlackMode,
    required this.onAdd,
    required this.onWithdraw,
    required this.onToggleHide,
  });

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
        vsync: this, duration: const Duration(milliseconds: 320));
    _scale = Tween<double>(begin: 1.0, end: 1.025).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOutBack));
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

    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: isBlack
          ? _buildBlackHero(colorScheme, hide)
          : _buildDarkHero(colorScheme, hide),
    );
  }

  Widget _buildBlackHero(ColorScheme colorScheme, bool hide) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6)),
              child: Text('PORTFOLIO VALUE',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0)),
            ),
            GestureDetector(
              onTap: widget.onToggleHide,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle),
                child: Icon(
                    hide
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 16),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          AnimatedAmountText(
            key: const ValueKey('home_total_invested'),
            value: widget.totalInvested.toDouble(),
            prefix: '₹',
            hideValue: hide,
            onCompleted: pulse,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
                height: 1.1),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: BlackStatCard(
                label: 'Returns',
                amountValue: widget.returns.toDouble(),
                prefix: '₹',
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
          ]),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(children: [
              Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.white.withValues(alpha: 0.35), size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Wallet Balance',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 11)),
                    AnimatedAmountText(
                        key: const ValueKey('home_wallet_balance'),
                        value: widget.wallet.toDouble(),
                        prefix: '₹',
                        hideValue: hide,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                  ])),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildDarkHero(ColorScheme colorScheme, bool hide) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colorScheme.primaryFixedDim, colorScheme.primaryFixed]),
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(child: HeroTexture()),
        Positioned(
            right: -60,
            top: -60,
            child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06)))),
        Positioned(
            left: -40,
            bottom: -70,
            child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04)))),
        Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('PORTFOLIO VALUE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0)),
              ),
              GestureDetector(
                onTap: widget.onToggleHide,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle),
                  child: Icon(
                      hide
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.white70,
                      size: 16),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => GradientText.blue.createShader(
                  Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
              child: AnimatedAmountText(
                value: widget.totalInvested.toDouble(),
                prefix: '₹',
                hideValue: hide,
                onCompleted: pulse,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                    height: 1.1),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: GlassStatCard(
                  label: 'Returns',
                  value: hide
                      ? '₹$_kMaskedShort'
                      : '₹${fmtAmount(widget.returns)}',
                  customValue: AnimatedAmountText(
                    value: widget.returns.toDouble(),
                    prefix: '₹',
                    hideValue: hide,
                    style: const TextStyle(
                      color: Color(0xFF22C55E),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  valueColor: const Color(0xFF22C55E),
                  icon: Icons.trending_up_rounded,
                  staggerIndex: 0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: GlassStatCard(
                      label: 'Active',
                      value: '${(widget.activeCount as num).toInt()}',
                      staggerIndex: 1,
                      icon: Icons.pending_outlined)),
              const SizedBox(width: 8),
              Expanded(
                  child: GlassStatCard(
                      label: 'Repaid',
                      value: '${(widget.repaidCount as num).toInt()}',
                      staggerIndex: 2,
                      icon: Icons.check_circle_outline_rounded)),
            ]),
            const SizedBox(height: 20),
            GlassCard(
              blur: 12,
              opacity: 0.1,
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              boxShadow: const [],
              child: Row(children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Wallet Balance',
                          style:
                              TextStyle(color: Colors.white60, fontSize: 11)),
                      AnimatedAmountText(
                          value: widget.wallet.toDouble(),
                          prefix: '₹',
                          hideValue: hide,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                    ])),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class BlackStatCard extends ConsumerWidget {
  final String label;
  final double? amountValue;
  final String prefix;
  final bool hideValue;
  final Color? valueColor;

  const BlackStatCard({
    super.key,
    required this.label,
    this.amountValue,
    this.prefix = '',
    this.hideValue = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(children: [
        if (amountValue != null)
          AnimatedAmountText(
            value: amountValue!,
            prefix: prefix,
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
      ]),
    );
  }
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
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotGridPainter old) => false;
}
