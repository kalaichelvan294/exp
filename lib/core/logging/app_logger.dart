import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LogLevel { debug, info, warning, error }

/// Lightweight logging/diagnostics facade.
///
/// Kept dependency-free so it can be swapped for a file/remote sink later
/// without touching call sites.
class AppLogger {
  const AppLogger({this.minLevel = LogLevel.debug});

  final LogLevel minLevel;

  void debug(String message, {String? scope}) =>
      _log(LogLevel.debug, message, scope: scope);

  void info(String message, {String? scope}) =>
      _log(LogLevel.info, message, scope: scope);

  void warning(String message, {String? scope}) =>
      _log(LogLevel.warning, message, scope: scope);

  void error(
    String message, {
    String? scope,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(
        LogLevel.error,
        message,
        scope: scope,
        error: error,
        stackTrace: stackTrace,
      );

  void _log(
    LogLevel level,
    String message, {
    String? scope,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) return;
    final tag = scope == null ? 'pos' : 'pos.$scope';
    developer.log(
      message,
      name: '$tag[${level.name}]',
      level: _levelValue(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  int _levelValue(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }
}

final loggerProvider = Provider<AppLogger>(
  (ref) => AppLogger(minLevel: kReleaseMode ? LogLevel.info : LogLevel.debug),
);
