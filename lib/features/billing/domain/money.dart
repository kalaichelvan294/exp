/// Money + numeric helpers ported from the Electron `utils.js`.
///
/// The whole billing pipeline works in **paise** (integer) to keep arithmetic
/// exact, matching the current app. Only presentation converts to rupees.
class Money {
  Money._();

  /// `formatMoney` — "₹" + rupees with 2 decimals.
  static String format(num paise) {
    final rupees = (paise) / 100.0;
    return '₹${rupees.toStringAsFixed(2)}';
  }

  /// `toRupeesFromPaise`
  static String toRupees(num paise) => (paise / 100.0).toStringAsFixed(2);

  /// `parsePositiveNumber` — finite and >= 0, else 0.
  static num parsePositive(Object? value) {
    final parsed = _toNum(value);
    if (parsed != null && parsed.isFinite && parsed >= 0) {
      return parsed;
    }
    return 0;
  }

  /// `parseInrToPaise` — round(rupees * 100).
  static int parseInrToPaise(Object? value) {
    return (parsePositive(value) * 100).round();
  }

  static num? _toNum(Object? value) {
    if (value is num) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;

      final normalized = trimmed
          .replaceAll(RegExp(r'[^0-9.\-+]'), '')
          .replaceAll(RegExp(r'(?<=\d),(?=\d)'), '');

      if (normalized.isEmpty ||
          normalized == '.' ||
          normalized == '-' ||
          normalized == '+') {
        return null;
      }

      return num.tryParse(normalized);
    }
    return null;
  }
}
