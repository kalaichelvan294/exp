import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'environment.dart';

/// Immutable bootstrap configuration for the app.
///
/// Values can be overridden at launch time via `--dart-define`:
///   flutter run -d windows --dart-define=POS_ENV=staging \
///     --dart-define=POS_DATABASE_URL=mysql://root:MysqlRoot@localhost:3306/pos294
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.appVersion,
    required this.databaseUrl,
    required this.databaseHost,
    required this.databasePort,
    required this.databaseName,
    required this.databaseUser,
    required this.databasePassword,
  });

  final AppEnvironment environment;
  final String appVersion;
  final String databaseUrl;
  final String databaseHost;
  final int databasePort;
  final String databaseName;
  final String databaseUser;
  final String databasePassword;

  bool get isProduction => environment == AppEnvironment.production;

  static const _defaultDatabaseUrl =
      'mysql://root:MysqlRoot@localhost:3306/pos294';

  factory AppConfig.fromEnvironment() {
    final env = AppEnvironmentX.fromName(
      const String.fromEnvironment('POS_ENV', defaultValue: 'development'),
    );
    const databaseUrl =
    String.fromEnvironment('POS_DATABASE_URL', defaultValue: _defaultDatabaseUrl);

    final uri = Uri.parse(databaseUrl);
    return AppConfig(
      environment: env,
      appVersion: const String.fromEnvironment(
        'POS_APP_VERSION',
        defaultValue: '0.1.0',
      ),
      databaseUrl: databaseUrl,
      databaseHost: uri.host.isEmpty ? 'localhost' : uri.host,
      databasePort: uri.port == 0 ? 3306 : uri.port,
      databaseName: uri.path.replaceFirst('/', ''),
      databaseUser: uri.userInfo.isEmpty ? 'root' : uri.userInfo.split(':')[0],
      databasePassword: uri.userInfo.isEmpty
          ? 'MysqlRoot'
          : uri.userInfo.split(':').length > 1
          ? uri.userInfo.split(':')[1]
          : 'MysqlRoot',
    );
  }
}

/// Overridden in `main()` once the concrete config is resolved.
final appConfigProvider = Provider<AppConfig>(
      (ref) => throw UnimplementedError('appConfigProvider must be overridden'),
);
