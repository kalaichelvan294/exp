import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/logging/exception_file_logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const exceptionLogger = ExceptionFileLogger();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      exceptionLogger.logException(
        source: 'flutter',
        error: details.exception,
        stackTrace: details.stack,
        fatal: true,
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      exceptionLogger.logException(
        source: 'platform_dispatcher',
        error: error,
        stackTrace: stack,
        fatal: true,
      ),
    );
    return true;
  };

  final config = AppConfig.fromEnvironment();

  runZonedGuarded(
    () {
      runApp(
        ProviderScope(
          overrides: [appConfigProvider.overrideWithValue(config)],
          child: const PosApp(),
        ),
      );
    },
    (error, stack) {
      unawaited(
        exceptionLogger.logException(
          source: 'zoned_guarded',
          error: error,
          stackTrace: stack,
          fatal: true,
        ),
      );
    },
  );
}
