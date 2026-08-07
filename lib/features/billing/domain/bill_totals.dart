import 'billing_enums.dart';
import 'cart_line.dart';
import 'money.dart';

/// Computed bill totals in paise.
class BillTotals {
  const BillTotals({
    required this.subtotalPaise,
    required this.discountPaise,
    required this.grandTotalPaise,
  });

  final int subtotalPaise;
  final int discountPaise;
  final int grandTotalPaise;

  static const zero =
      BillTotals(subtotalPaise: 0, discountPaise: 0, grandTotalPaise: 0);
}

/// Ports `totals.js`.
class Totals {
  Totals._();

  /// `computeDiscountPaise` — PERCENT caps at 100 %, AMOUNT parsed to paise,
  /// discount never exceeds the subtotal.
  static int computeDiscountPaise(
    int subtotalPaise,
    DiscountMode mode,
    Object? discountInputValue,
  ) {
    int discountPaise;
    if (mode == DiscountMode.percent) {
      final pct = Money.parsePositive(discountInputValue);
      final capped = pct < 100 ? pct : 100;
      discountPaise = ((subtotalPaise * capped) / 100).round();
    } else {
      discountPaise = Money.parseInrToPaise(discountInputValue);
    }
    if (discountPaise > subtotalPaise) {
      discountPaise = subtotalPaise;
    }
    return discountPaise;
  }

  /// `computeBillTotals` — subtotal = Σ round(qty * rate).
  static BillTotals compute(
    List<CartLine> cart,
    DiscountMode mode,
    Object? discountInputValue,
  ) {
    var subtotal = 0;
    for (final line in cart) {
      subtotal += (line.qty * line.ratePaise).round();
    }
    final discount = computeDiscountPaise(subtotal, mode, discountInputValue);
    return BillTotals(
      subtotalPaise: subtotal,
      discountPaise: discount,
      grandTotalPaise: subtotal - discount,
    );
  }
}
