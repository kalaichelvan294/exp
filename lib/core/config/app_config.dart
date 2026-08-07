import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'environment.dart';

/// Immutable bootstrap configuration for the app.
///
/// Values can be overridden at launch time via `--dart-define`:
///   flutter run -d windows --dart-define=POS_ENV=staging \
///     --dart-define=POS_API_BASE_URL=http://10.0.0.5:8787 \
///     --dart-define=POS_DB_CLIENT=postgres \
///     --dart-define=POS_DATABASE_URL=postgres://user:pass@host:5432/pos294
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.appVersion,
    this.dbClient = DbClient.postgres,
    this.databaseUrl = '',
    this.sqliteDbPath = '',
    this.apiTimeout = const Duration(seconds: 20),
  });

  final AppEnvironment environment;
  final String apiBaseUrl;
  final String appVersion;

  /// Database backend the bridge connects to (default Postgres).
  final DbClient dbClient;

  /// Postgres connection string, used when [dbClient] is Postgres.
  final String databaseUrl;

  /// SQLite file path, used when [dbClient] is SQLite.
  final String sqliteDbPath;

  final Duration apiTimeout;

  bool get isProduction => environment == AppEnvironment.production;

  static const _defaultDatabaseUrl =
      'postgres://postgres:postgres@localhost:5432/pos294';
  static const _defaultSqlitePath = 'data/pos-294.sqlite';

  factory AppConfig.fromEnvironment() {
    final env = AppEnvironmentX.fromName(
      const String.fromEnvironment('POS_ENV', defaultValue: 'development'),
    );
    const overrideUrl = String.fromEnvironment('POS_API_BASE_URL');
    final dbClient = DbClientX.fromName(
      const String.fromEnvironment('POS_DB_CLIENT', defaultValue: 'postgres'),
    );
    const databaseUrl = String.fromEnvironment('POS_DATABASE_URL');
    const sqlitePath = String.fromEnvironment('POS_SQLITE_DB_PATH');
    return AppConfig(
      environment: env,
      apiBaseUrl: overrideUrl.isNotEmpty ? overrideUrl : env.defaultBaseUrl,
      appVersion: const String.fromEnvironment(
        'POS_APP_VERSION',
        defaultValue: '0.1.0',
      ),
      dbClient: dbClient,
      databaseUrl: databaseUrl.isNotEmpty ? databaseUrl : _defaultDatabaseUrl,
      sqliteDbPath: sqlitePath.isNotEmpty ? sqlitePath : _defaultSqlitePath,
    );
  }
}

/// Overridden in `main()` once the concrete config is resolved.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider must be overridden'),
);
