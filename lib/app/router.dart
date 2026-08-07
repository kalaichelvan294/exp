import 'package:go_router/go_router.dart';

import '../features/billing/presentation/billing_page.dart';
import '../features/bills/presentation/bills_page.dart';
import '../features/bulk/presentation/bulk_page.dart';
import '../features/inventory/presentation/inventory_page.dart';
import '../features/items/presentation/items_page.dart';
import '../features/reports/presentation/reports_page.dart';
import '../features/settings/presentation/settings_page.dart';
import 'app_routes.dart';
import 'app_shell.dart';
import 'navigation.dart';

/// Builds the app router with a persistent [AppShell] wrapping all modules.
GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.initial,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.billing.path,
            builder: (_, state) =>
                BillingPage(editBillId: state.uri.queryParameters['billId']),
          ),
          GoRoute(
            path: AppRoutes.bills.path,
            builder: (_, _) => const BillsPage(),
          ),
          GoRoute(
            path: AppRoutes.items.path,
            builder: (_, _) => const ItemsPage(),
          ),
          GoRoute(
            path: AppRoutes.inventory.path,
            builder: (_, _) => const InventoryPage(),
          ),
          GoRoute(
            path: AppRoutes.reports.path,
            builder: (_, _) => const ReportsPage(),
          ),
          GoRoute(
            path: AppRoutes.bulk.path,
            builder: (_, _) => const BulkPage(),
          ),
          GoRoute(
            path: AppRoutes.settings.path,
            builder: (_, _) => const SettingsPage(),
          ),
        ],
      ),
    ],
  );
}

