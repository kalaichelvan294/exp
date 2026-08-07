// Bulk operations shared enums. Parity with Electron operationType strings
// ("item_import" / "inventory_update").

/// The two bulk operation flows.
enum BulkOperationType {
  itemImport('item_import'),
  inventoryUpdate('inventory_update');

  const BulkOperationType(this.wire);

  /// The wire value used by the API and last-batch route segment.
  final String wire;

  static BulkOperationType fromWire(String? value) {
    switch ((value ?? '').trim()) {
      case 'inventory_update':
        return BulkOperationType.inventoryUpdate;
      case 'item_import':
      default:
        return BulkOperationType.itemImport;
    }
  }
}

/// Per-row preview status. Parity with previewItemImport/previewInventoryUpdate
/// status values.
enum BulkRowStatus {
  ok,
  warning,
  error,
  skipped;

  static BulkRowStatus fromWire(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'warning':
        return BulkRowStatus.warning;
      case 'error':
        return BulkRowStatus.error;
      case 'skipped':
        return BulkRowStatus.skipped;
      case 'ok':
      default:
        return BulkRowStatus.ok;
    }
  }
}

/// Per-row apply outcome. Parity with apply result `outcome` values.
enum BulkRowOutcome {
  applied,
  failed,
  skipped;

  static BulkRowOutcome fromWire(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'failed':
        return BulkRowOutcome.failed;
      case 'skipped':
        return BulkRowOutcome.skipped;
      case 'applied':
      default:
        return BulkRowOutcome.applied;
    }
  }
}
