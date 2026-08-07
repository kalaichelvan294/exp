import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_294_flutter/app/app.dart';
import 'package:pos_294_flutter/core/config/app_config.dart';
import 'package:pos_294_flutter/core/config/environment.dart';

void main() {
  testWidgets('App boots into the Sales Desk with module navigation',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: AppEnvironment.development,
              apiBaseUrl: 'http://127.0.0.1:8787',
              appVersion: 'test',
            ),
          ),
        ],
        child: const PosApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Top navigation renders module tabs (Bills/Reports/Settings are unique).
    expect(find.text('Bills'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Initial route is the Sales Desk page (nav tab + page header).
    expect(find.text('Sales Desk'), findsWidgets);

    // Navigate to the Reports module via the nav tab.
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(
      find.text('Daily, weekly, monthly, and custom sales analytics.'),
      findsOneWidget,
    );

    // Navigate to Items module.
    await tester.tap(find.text('Items'));
    await tester.pumpAndSettle();
    expect(find.text('Manage products, SKUs, categories, and brands.'),
        findsOneWidget);
  });
}
