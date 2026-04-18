import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/env/environment_config.dart';
import 'core/supabase/supabase_config.dart';
import 'core/services/notification_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/network_service.dart';
import 'firebase_options.dart';
import 'main.dart';
import 'core/env/env.dart';
import 'package:provider/provider.dart';
import 'features/planit/ToDo/todoController.dart';
import 'features/pantry/groceries/grocerycontroller.dart';
import 'features/planit/specialDay/specialDaysController.dart';
import 'features/lifestyle/lifestyleController.dart';

Future<void> bootstrapApp(String env) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase + FCM — skipped if firebase_options.dart is still the placeholder.
  // Run `flutterfire configure` to generate real options and enable push notifications.
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (e) {
    debugPrint('[Bootstrap] Firebase not configured — FCM disabled: $e');
  }

  envConfig = EnvironmentConfig.fromEnv(env);

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  await NotificationService.instance.init();
  if (firebaseReady) {
    try {
      await FcmService.initialize();
    } catch (e) {
      debugPrint('[Bootstrap] FCM init failed — push notifications disabled: $e');
    }
  }
  await NetworkService.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TodoController()),
        ChangeNotifierProvider(create: (_) => GroceryController()),
        ChangeNotifierProvider(create: (_) => SpecialDaysController()),
        ChangeNotifierProvider(create: (_) => LifestyleController()),
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
