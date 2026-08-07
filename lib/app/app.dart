import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/shortcuts/app_shortcuts.dart';
import '../core/theme/app_theme.dart';
import 'app_routes.dart';
import 'appearance.dart';
import 'router.dart';

/// Root application widget: wires theme, router, and global shortcuts.
class PosApp extends ConsumerStatefulWidget {
  const PosApp({super.key});

  @override
  ConsumerState<PosApp> createState() => _PosAppState();
}

class _PosAppState extends ConsumerState<PosApp> {
  late final GoRouter _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceControllerProvider);
    return MaterialApp.router(
      title: 'POS 294',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: appearance.isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: _router,
      builder: (context, child) {
        final scaled = MediaQuery.of(context).textScaler.clamp(
              minScaleFactor: appearance.fontScale,
              maxScaleFactor: appearance.fontScale,
            );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaled),
          child: _GlobalShortcuts(
            router: _router,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

/// Registers app-wide navigation shortcuts. Feature screens can layer their
/// own [Actions]/[Shortcuts] for context-specific behavior.
class _GlobalShortcuts extends StatelessWidget {
  const _GlobalShortcuts({required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: AppShortcuts.global(
        billingRoute: AppRoutes.billing.path,
        itemsRoute: AppRoutes.items.path,
        reportsRoute: AppRoutes.reports.path,
        settingsRoute: AppRoutes.settings.path,
      ),
      child: Actions(
        actions: <Type, Action<Intent>>{
          NavigateModuleIntent: CallbackAction<NavigateModuleIntent>(
            onInvoke: (intent) {
              router.go(intent.route);
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}
