/// Payment and discount modes (parity with `state.js` / `PAYMENT_MODES`).
enum PaymentMode {
  cash('CASH'),
  gpay('GPAY'),
  card('CARD');

  const PaymentMode(this.wire);
  final String wire;

  static PaymentMode fromWire(Object? value) {
    final v = value?.toString().toUpperCase();
    return PaymentMode.values.firstWhere(
      (m) => m.wire == v,
      orElse: () => PaymentMode.cash,
    );
  }
}

enum DiscountMode {
  percent('PERCENT'),
  amount('AMOUNT');

  const DiscountMode(this.wire);
  final String wire;

  static DiscountMode fromWire(Object? value) {
    return value?.toString().toUpperCase() == 'AMOUNT'
        ? DiscountMode.amount
        : DiscountMode.percent;
  }
}

enum PricingType {
  unit('UNIT'),
  weight('WEIGHT');

  const PricingType(this.wire);
  final String wire;

  static PricingType fromWire(Object? value) {
    return value?.toString().toUpperCase() == 'WEIGHT'
        ? PricingType.weight
        : PricingType.unit;
  }
}

enum PriceTier {
  retail('RETAIL'),
  wholesale('WHOLESALE');

  const PriceTier(this.wire);
  final String wire;

  static PriceTier fromWire(Object? value) {
    return value?.toString().toUpperCase() == 'WHOLESALE'
        ? PriceTier.wholesale
        : PriceTier.retail;
  }
}
