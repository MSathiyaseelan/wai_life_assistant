import 'app_environment.dart';

class EnvironmentConfig {
  final AppEnvironment environment;
  final String appName;
  final String baseUrl;
  final bool enableLogs;

  EnvironmentConfig({
    required this.environment,
    required this.appName,
    required this.baseUrl,
    required this.enableLogs,
  });

  static EnvironmentConfig fromEnv(String env) {
    switch (env) {
      case 'qa':
        return EnvironmentConfig(
          environment: AppEnvironment.qa,
          appName: 'RiyasHome QA',
          baseUrl: 'https://qa.api.yourdomain.com',
          enableLogs: true,
        );
      case 'uat':
        return EnvironmentConfig(
          environment: AppEnvironment.uat,
          appName: 'RiyasHome UAT',
          baseUrl: 'https://uat.api.yourdomain.com',
          enableLogs: true,
        );
      case 'prod':
        return EnvironmentConfig(
          environment: AppEnvironment.prod,
          appName: 'RiyasHome',
          baseUrl: 'https://api.yourdomain.com',
          enableLogs: false,
        );
      case 'dev':
      default:
        return EnvironmentConfig(
          environment: AppEnvironment.dev,
          appName: 'RiyasHome DEV',
          baseUrl: 'https://dev.api.yourdomain.com',
          enableLogs: true,
        );
    }
  }
}
