// Formats a numeric value into a compact Indian currency string.
/// 10,000,000 → '1.00Cr' | 100,000 → '1.00L' | 1,000 → '1.00K' | else '500.00'
library;

String fmtAmount(dynamic v) {
  try {
    final d = double.parse(v.toString());

    // FIX: handle negatives gracefully — format the absolute value and
    // re-attach the sign. Without this, a negative wallet balance (e.g.
    // after a failed withdraw) would produce '-1.-20K' or similar garbage.
    if (d < 0) return '-${fmtAmount(-d)}';

    if (d >= 10000000) return '${(d / 10000000).toStringAsFixed(2)}Cr';
    if (d >= 100000) return '${(d / 100000).toStringAsFixed(2)}L';
    if (d >= 1000) return '${(d / 1000).toStringAsFixed(2)}K';

    // FIX: sub-1000 amounts now show zero decimal places when the value is
    // a whole number (e.g. ₹500 not ₹500.00), but keep 2dp for fractional
    // amounts (₹49.50). Looks much cleaner in the hero card and wallet row.
    if (d == d.truncateToDouble()) return d.toInt().toString();
    return d.toStringAsFixed(2);
  } catch (_) {
    return '0';
  }
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