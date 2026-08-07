import 'package:flutter/widgets.dart';

/// Central registry of module routes for the app shell.
class AppRoute {
  const AppRoute({
    required this.path,
    required this.label,
    required this.icon,
  });

  final String path;
  final String label;
  final IconData icon;
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
  );
  static const inventory = AppRoute(
    path: '/inventory',
    label: 'Inventory',
    icon: IconData(0xe1a1, fontFamily: 'MaterialIcons'), // warehouse
  );
  static const reports = AppRoute(
    path: '/reports',
    label: 'Reports',
    icon: IconData(0xe4fb, fontFamily: 'MaterialIcons'), // bar_chart
  );
  static const bulk = AppRoute(
    path: '/bulk',
    label: 'Bulk Ops',
    icon: IconData(0xe2c6, fontFamily: 'MaterialIcons'), // upload_file
  );
  static const settings = AppRoute(
    path: '/settings',
    label: 'Settings',
    icon: IconData(0xe8b8, fontFamily: 'MaterialIcons'), // settings
  );

  /// Ordered list shown in the top navigation.
  static const List<AppRoute> all = [
    billing,
    bills,
    items,
    inventory,
    reports,
    bulk,
    settings,
  ];

  static const String initial = '/billing';
}
