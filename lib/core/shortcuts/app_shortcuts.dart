import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

/// App-wide keyboard shortcut infrastructure.
///
/// Billing is keyboard-first; these intents give features a shared, stable
/// vocabulary so shortcuts stay consistent across modules.
class NavigateModuleIntent extends Intent {
  const NavigateModuleIntent(this.route);
  final String route;
}

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

class SubmitIntent extends Intent {
  const SubmitIntent();
}

class CancelIntent extends Intent {
  const CancelIntent();
}

class CheckoutIntent extends Intent {
  const CheckoutIntent();
}

class HoldBillIntent extends Intent {
  const HoldBillIntent();
}

/// Global shortcut map. Feature screens supply the matching [Action]s via an
/// [Actions] widget so the same key can do the contextually correct thing.
class AppShortcuts {
  AppShortcuts._();

  static Map<ShortcutActivator, Intent> global({
    required String billingRoute,
    required String itemsRoute,
    required String reportsRoute,
    required String settingsRoute,
  }) {
    return <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.f2):
          NavigateModuleIntent(billingRoute),
      const SingleActivator(LogicalKeyboardKey.f3):
          NavigateModuleIntent(itemsRoute),
      const SingleActivator(LogicalKeyboardKey.f4):
          NavigateModuleIntent(reportsRoute),
      const SingleActivator(LogicalKeyboardKey.f10):
          NavigateModuleIntent(settingsRoute),
      const SingleActivator(LogicalKeyboardKey.slash, control: true):
          const FocusSearchIntent(),
      const SingleActivator(LogicalKeyboardKey.enter, control: true):
          const CheckoutIntent(),
      const SingleActivator(LogicalKeyboardKey.keyH, control: true):
          const HoldBillIntent(),
      const SingleActivator(LogicalKeyboardKey.escape): const CancelIntent(),
    };
  }
}
