/// Environment variants for configuration.
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

