import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/models/invoice_item.dart';
import 'package:invoice_discounting_app/screens/invoice_detail_screen.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/formatters.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';
import 'package:invoice_discounting_app/widgets/animated_amount_text.dart';
import 'package:invoice_discounting_app/widgets/pressable.dart';

class ActiveInvestmentCard extends ConsumerWidget {
  const ActiveInvestmentCard({
    required this.investment,
    required this.index,
    super.key,
    this.isBlackMode = false,
  });
  final Map<String, dynamic> investment;
  final int index;
  final bool isBlackMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final hideBalance = ref.watch(themeProvider.select((p) => p.hideBalance));
    final company = (investment['company'] ?? 'Invoice') as String;
    final amount =
        double.tryParse(investment['amount']?.toString() ?? '0') ?? 0;
    final daysLeft = (investment['days_left'] as num?)?.toInt() ?? 0;
    final roi = double.tryParse(
          investment['investor_rate']?.toString() ??
              investment['roi']?.toString() ??
              '0',
        ) ??
        0;
    final invoiceId = investment['invoice_id']?.toString() ?? '0';

    final remainingAmount = amount;
    const fundingPct = 100.0;
    final tenureDays = daysLeft;

    final urgencyColor = daysLeft <= 7
        ? const Color(0xFFEF4444) // Error color
        : daysLeft <= 30
            ? const Color(0xFFF59E0B) // Warning color
            : const Color(0xFF10B981); // Success color

    final bg = isBlackMode
        ? const Color(0xFF0A0A0A)
        : colorScheme.surfaceContainerHigh;
    final fg = colorScheme.onSurface;

    final invoiceItem = InvoiceItem(
      id: invoiceId,
      company: company,
      particular: '',
      debtor: '',
      status: 'active',
      statusDisplay: 'Active',
      roi: roi,
      daysLeft: daysLeft,
      tenureDays: tenureDays,
      remainingAmount: remainingAmount,
      fundingPct: fundingPct,
      roiDisplay: '${roi.toStringAsFixed(1)}%',
      daysLeftDisplay: '${daysLeft}d left',
      tenureDisplay: '${tenureDays}d',
      remainingDisplay: '₹${fmtAmount(remainingAmount)}',
      fundingDisplay: '${fundingPct.toStringAsFixed(1)}%',
    );

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      child: Pressable(
        onTap: () async {
          await AppHaptics.selection();
          if (!context.mounted) return;
          Navigator.of(context, rootNavigator: true).push(
            SmoothPageRoute<void>(
              builder: (_) => InvoiceDetailScreen(item: invoiceItem),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(UI.radiusMd),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(UI.radiusMd),
            border: Border(
              left: BorderSide(
                color: colorScheme.primary
                    .withValues(alpha: isBlackMode ? 0.5 : 0.7),
                width: 2.5,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: urgencyColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(UI.radiusSm),
                    ),
                    child: Text(
                      '${daysLeft}d',
                      style: TextStyle(
                        color: urgencyColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedAmountText(
                value: amount,
                prefix: '₹',
                hideValue: hideBalance,
                style: TextStyle(
                  color: fg,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${roi.toStringAsFixed(1)}% p.a.',
                style: TextStyle(
                  color: fg.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
