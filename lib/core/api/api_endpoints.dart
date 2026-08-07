/// Frozen API bridge endpoint map (Phase 0 contract).
///
/// Each constant corresponds to an operation the Electron preload previously
/// exposed over IPC. Paths are relative to [AppConfig.apiBaseUrl].
class ApiEndpoints {
  ApiEndpoints._();

  // System / app
  static const systemHealth = '/system/health';
  static const appExit = '/app/exit';
  static const loadSettings = '/system/settings';
  static const saveSettings = '/system/settings';
  static const loadInventorySettings = '/system/inventory-settings';
  static const saveInventorySettings = '/system/inventory-settings';
  static const generateUpiQr = '/system/upi-qr';
  static const propagateBrands = '/system/propagate-brands';

  // Products
  static const productsSearch = '/products/search';
  static const productsFindExact = '/products/find-exact';

  // Billing
  static const billingSave = '/billing';
  static const billingList = '/billing';
  static String billingGet(String id) => '/billing/$id';
  static String billingUpdate(String id) => '/billing/$id';
  static String billingDelete(String id) => '/billing/$id';

  // Held bills
  static const billingHold = '/billing/holds';
  static const billingListHolds = '/billing/holds';
  static String billingResumeHold(String id) => '/billing/holds/$id/resume';
  static String billingDeleteHold(String id) => '/billing/holds/$id';

  // Items
  static const itemsList = '/items';
  static const itemsCreate = '/items';
  static const itemsValidateSku = '/items/validate-sku';
  static String itemsUpdate(String id) => '/items/$id';
  static String itemsDelete(String id) => '/items/$id';

  // Inventory
  static String inventoryAdjust(String itemId) => '/inventory/$itemId/adjust';
  static const inventoryListAudit = '/inventory/audit';

  // Reports
  static const reportsMonthlyAnalytics = '/reports/monthly-analytics';
  static const reportsAnalytics = '/reports/analytics';

  // Bulk
  static const bulkItemTemplate = '/bulk/items/template';
  static const bulkDownloadAllItems = '/bulk/items/export';
  static const bulkDownloadFilteredItems = '/bulk/items/export/filtered';
  static const bulkInventoryTemplate = '/bulk/inventory/template';
  static const bulkCurrentInventory = '/bulk/inventory/export';
  static const bulkPreviewItems = '/bulk/items/preview';
  static const bulkPreviewInventory = '/bulk/inventory/preview';
  static const bulkApplyItems = '/bulk/items/apply';
  static const bulkApplyInventory = '/bulk/inventory/apply';
  static String bulkLastBatch(String type) => '/bulk/$type/last-batch';
  static String bulkRevert(String batchId) => '/bulk/batches/$batchId/revert';
  static String bulkErrorReport(String batchId) =>
      '/bulk/batches/$batchId/error-report';
}
