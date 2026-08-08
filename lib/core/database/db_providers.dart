import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../logging/app_logger.dart';
import 'db_connection.dart';

/// Single shared [DbConnection] instance for the app.
final dbConnectionProvider = Provider<DbConnection>((ref) {
  final connection = DbConnection(
    config: ref.watch(appConfigProvider),
    logger: ref.watch(loggerProvider),
  );
  ref.onDispose(connection.close);
  return connection;
});
