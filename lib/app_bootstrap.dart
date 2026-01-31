import 'package:flutter/material.dart';
import 'core/env/environment_config.dart';
import 'main.dart';
import 'core/env/env.dart';
import 'package:provider/provider.dart';
import 'features/planit/ToDo/todoController.dart';
import 'features/pantry/groceries/grocerycontroller.dart';

void bootstrapApp(String env) {
  envConfig = EnvironmentConfig.fromEnv(env);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TodoController()),
        ChangeNotifierProvider(create: (_) => GroceryController()),
        // add more controllers when needed
      ],
      child: LifeAssistanceApp(config: envConfig),
    ),
  );
}

// void bootstrapApp(String env) {
//   envConfig = EnvironmentConfig.fromEnv(env);
//   runApp(LifeAssistanceApp(config: envConfig));
// }
