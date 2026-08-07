import 'package:flutter/widgets.dart';

/// Root navigator key for the app. Used by services that need to present
/// full-screen surfaces (e.g. the receipt print preview) without a
/// [BuildContext], and wired into the [GoRouter] as the root navigator.
final rootNavigatorKey = GlobalKey<NavigatorState>();
