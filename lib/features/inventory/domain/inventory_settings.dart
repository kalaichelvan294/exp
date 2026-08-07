/// Inventory settings (parity with `system:load-inventory-settings`).
class InventorySettings {
  const InventorySettings({
    this.invControlEnabled = false,
    this.invLowStockQty = 10,
    this.invLowStockWeight = 5.0,
  });

  final bool invControlEnabled;
  final num invLowStockQty;
  final num invLowStockWeight;

  static const disabled = InventorySettings();

  factory InventorySettings.fromJson(Map<String, dynamic> json) {
    num asNum(Object? v, num fallback) =>
        v is num ? v : num.tryParse('${v ?? ''}') ?? fallback;
    return InventorySettings(
      invControlEnabled: json['invControlEnabled'] == true,
      invLowStockQty: asNum(json['invLowStockQty'], 10),
      invLowStockWeight: asNum(json['invLowStockWeight'], 5.0),
    );
  }
}
