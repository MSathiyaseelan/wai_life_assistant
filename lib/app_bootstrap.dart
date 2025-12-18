import 'package:flutter/material.dart';
import 'core/env/environment_config.dart';
import 'main.dart';
import 'core/env/env.dart';

void bootstrapApp(String env) {
  envConfig = EnvironmentConfig.fromEnv(env);
  runApp(LifeAssistanceApp(config: envConfig));
}
