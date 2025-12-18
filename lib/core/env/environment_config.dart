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
          appName: 'Life Assistant QA',
          baseUrl: 'https://qa.api.yourdomain.com',
          enableLogs: true,
        );
      case 'uat':
        return EnvironmentConfig(
          environment: AppEnvironment.uat,
          appName: 'Life Assistant UAT',
          baseUrl: 'https://uat.api.yourdomain.com',
          enableLogs: true,
        );
      case 'prod':
        return EnvironmentConfig(
          environment: AppEnvironment.prod,
          appName: 'Life Assistant',
          baseUrl: 'https://api.yourdomain.com',
          enableLogs: false,
        );
      case 'dev':
      default:
        return EnvironmentConfig(
          environment: AppEnvironment.dev,
          appName: 'Life Assistant DEV',
          baseUrl: 'https://dev.api.yourdomain.com',
          enableLogs: true,
        );
    }
  }
}
