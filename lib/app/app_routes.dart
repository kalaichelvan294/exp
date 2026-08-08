import 'package:flutter/widgets.dart';

/// Central registry of module routes for the app shell.
class AppRoute {
  const AppRoute({
    required this.path,
    required this.label,
    required this.icon,
    this.adminOnly = false,
  });

  final String path;
  final String label;
  final IconData icon;

  /// Admin-only modules are hidden from the sales nav and guarded at the route
  /// (parity with the electron `adminKeys`).
  final bool adminOnly;
}

class AppRoutes {
  AppRoutes._();

  static const billing = AppRoute(
    path: '/billing',
    label: 'Sales Desk',
    icon: IconData(0xe59c, fontFamily: 'MaterialIcons'), // point_of_sale
  );
  static const bills = AppRoute(
    path: '/bills',
    label: 'Bills',
    icon: IconData(0xe0b0, fontFamily: 'MaterialIcons'), // receipt_long
  );
  static const items = AppRoute(
    path: '/items',
    label: 'Items',
    icon: IconData(0xe1db, fontFamily: 'MaterialIcons'), // inventory_2
    adminOnly: true,
  );
  static const inventory = AppRoute(
    path: '/inventory',
    label: 'Inventory',
    icon: IconData(0xe1a1, fontFamily: 'MaterialIcons'), // warehouse
    adminOnly: true,
  );
  static const bulk = AppRoute(
    path: '/bulk',
    label: 'Bulk Ops',
    icon: IconData(0xe2c6, fontFamily: 'MaterialIcons'), // upload_file
    adminOnly: true,
  );
  static const settings = AppRoute(
    path: '/settings',
    label: 'Settings',
    icon: IconData(0xe8b8, fontFamily: 'MaterialIcons'), // settings
    adminOnly: true,
  );

  /// Ordered list shown in the top navigation tabs.
  static const List<AppRoute> all = [billing, bills, items, inventory, bulk];

  static const String initial = '/billing';
}
