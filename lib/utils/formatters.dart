// Formats a numeric value into a compact Indian currency string.
/// 10,000,000 → '1.00Cr' | 100,000 → '1.00L' | 1,000 → '1,000' | else '500.00'
library;

String fmtAmount(dynamic v) {
  try {
    final d = double.parse(v.toString());

    // FIX: handle negatives gracefully — format the absolute value and
    // re-attach the sign.
    if (d < 0) return '-${fmtAmount(-d)}';

    if (d >= 10000000) return '${(d / 10000000).toStringAsFixed(2)}Cr';
    if (d >= 100000) return '${(d / 100000).toStringAsFixed(2)}L';

    // India Standard: Show full numbers for anything below 1 Lakh,
    // formatted with commas for readability (e.g. 65,000).
    final intPart = d.truncate().toString();
    if (intPart.length > 3) {
      final lastThree = intPart.substring(intPart.length - 3);
      final remaining = intPart.substring(0, intPart.length - 3);
      final formatted = '${_commaSeparate(remaining)},$lastThree';
      if (d == d.truncateToDouble()) return formatted;
      return '$formatted.${d.toStringAsFixed(2).split('.')[1]}';
    }

    if (d == d.truncateToDouble()) return d.toInt().toString();
    return d.toStringAsFixed(2);
  } catch (_) {
    return '0';
  }
}

String _commaSeparate(String s) {
  if (s.length <= 2) return s;
  final lastTwo = s.substring(s.length - 2);
  final remaining = s.substring(0, s.length - 2);
  return '${_commaSeparate(remaining)},$lastTwo';
}

class Formatters {
  Formatters._();

  static String currency(dynamic v) => fmtAmountFull(v);

  /// Compact Indian currency string (e.g. 1.00Cr, 1.00L).
  static String amount(dynamic v) => fmtAmount(v);

  /// Full precision Indian currency string (e.g. ₹10,00,000.00).
  static String amountFull(dynamic v) => fmtAmountFull(v);
}

/// Full precision Indian currency string (no abbreviation).
/// Use for PDF statements or detail screens where exact value matters.
String fmtAmountFull(dynamic v) {
  try {
    final d = double.parse(v.toString());
    return '₹${d.toStringAsFixed(2)}';
  } catch (_) {
    return '₹0.00';
  }
}
