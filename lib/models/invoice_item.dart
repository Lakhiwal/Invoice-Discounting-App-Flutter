import 'package:freezed_annotation/freezed_annotation.dart';
import '../utils/formatters.dart';

part 'invoice_item.freezed.dart';
part 'invoice_item.g.dart';

@freezed
class InvoiceItem with _$InvoiceItem {
  const factory InvoiceItem({
    required String id,
    required String company,
    required String particular,
    required String debtor,
    required String status,
    required String statusDisplay,
    required double roi,
    required int daysLeft,
    required int tenureDays,
    required double remainingAmount,
    required double fundingPct,
    required String roiDisplay,
    required String daysLeftDisplay,
    required String tenureDisplay,
    required String remainingDisplay,
    required String fundingDisplay,
  }) = _InvoiceItem;

  const InvoiceItem._();

  bool get isAvailable => fundingPct < 100;

  factory InvoiceItem.fromJson(Map<String, dynamic> json) => _$InvoiceItemFromJson(json);

  factory InvoiceItem.fromMap(Map<String, dynamic> m) {
    final rawRoi = double.tryParse(
            (m['investor_rate'] ?? m['roi_value'] ?? m['roi'] ?? '0')
                .toString()) ?? 0;

    final rawDaysLeft = (m['days_until_payment'] as num?)?.toInt() ?? 0;

    int rawTenure = 0;
    try {
      final invoiceDateStr = m['invoice_date']?.toString() ?? '';
      final paymentDateStr = m['payment_date']?.toString() ?? '';
      if (invoiceDateStr.isNotEmpty && paymentDateStr.isNotEmpty) {
        final invoiceDate = DateTime.parse(invoiceDateStr);
        final paymentDate = DateTime.parse(paymentDateStr);
        rawTenure = paymentDate.difference(invoiceDate).inDays;
        if (rawTenure < 0) rawTenure = 0;
      }
    } catch (_) {
      rawTenure = rawDaysLeft;
    }
    final approved = double.tryParse((m['approved_amount'] ?? '0').toString()) ?? 0;
    final funded = double.tryParse((m['funded_amount'] ?? m['total_funded'] ?? '0').toString()) ?? 0;
    final remaining = approved > funded ? (approved - funded) : 0.0;
    final safeFunded = funded > approved ? approved : funded;

    final double calcFunding = approved > 0 ? ((safeFunded / approved) * 100).clamp(0.0, 100.0) : 0.0;
    final double apiFunding = m['funding_percentage'] != null
        ? (double.tryParse(m['funding_percentage'].toString()) ?? 0.0).clamp(0.0, 100.0)
        : 0.0;

    final rawFunding = (calcFunding > 0 && apiFunding == 0) ? calcFunding : (m['funding_percentage'] != null ? apiFunding : calcFunding);

    return InvoiceItem(
      id: (m['id'] ?? '').toString(),
      company: (m['company'] ?? '').toString(),
      particular: (m['particular'] ?? '').toString(),
      debtor: (m['debtor'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      statusDisplay: (m['status_display'] ?? '').toString(),
      roi: rawRoi,
      daysLeft: rawDaysLeft,
      tenureDays: rawTenure,
      remainingAmount: remaining,
      fundingPct: rawFunding,
      roiDisplay: '${rawRoi.toStringAsFixed(2)}%',
      daysLeftDisplay: '${rawDaysLeft}D left',
      tenureDisplay: '${rawTenure}D',
      remainingDisplay: '₹${fmtAmount(remaining)}',
      fundingDisplay: '${rawFunding.toStringAsFixed(1)}%',
    );
  }
}
