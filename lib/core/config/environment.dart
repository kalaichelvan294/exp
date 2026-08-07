/// Environment variants for the API bridge configuration.
///
/// The Flutter client talks to the API bridge over HTTP; the bridge connects
/// directly to the configured database (Postgres or SQLite — see [DbClient]).
enum AppEnvironment {
  development,
  staging,
  production,
}

extension AppEnvironmentX on AppEnvironment {
  String get label {
    switch (this) {
      case AppEnvironment.development:
        return 'development';
      case AppEnvironment.staging:
        return 'staging';
      case AppEnvironment.production:
        return 'production';
    }
  }

  /// Default API bridge base URL for the environment.
  String get defaultBaseUrl {
    switch (this) {
      case AppEnvironment.development:
        return 'http://127.0.0.1:8787';
      case AppEnvironment.staging:
        return 'http://127.0.0.1:8788';
      case AppEnvironment.production:
        return 'http://127.0.0.1:8789';
    }
  }

  static AppEnvironment fromName(String? name) {
    switch (name) {
      case 'production':
        return AppEnvironment.production;
      case 'staging':
        return AppEnvironment.staging;
      case 'development':
      default:
        return AppEnvironment.development;
    }
  }
}

/// Database backend the API bridge connects to.
///
/// Mirrors the Electron `DB_CLIENT` env var (default `postgres`, alternative
/// `sqlite`). Selected through configuration; the bridge owns the actual
/// connection (Postgres via `DATABASE_URL`, SQLite via `SQLITE_DB_PATH`).
enum DbClient {
  postgres,
  sqlite,
}

extension DbClientX on DbClient {
  String get label => this == DbClient.sqlite ? 'sqlite' : 'postgres';

  static DbClient fromName(String? name) {
    return name?.trim().toLowerCase() == 'sqlite'
        ? DbClient.sqlite
        : DbClient.postgres;
  }
}

