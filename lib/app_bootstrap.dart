import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/env/environment_config.dart';
import 'core/services/error_logger.dart';
import 'core/supabase/supabase_config.dart';
import 'core/services/notification_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/network_service.dart';
import 'core/services/realtime_sync_service.dart';
// import 'features/wallet/services/sms_parser_service.dart'; // re-enable with auto-scan
import 'firebase_options.dart';
import 'main.dart';
import 'core/env/env.dart';
import 'package:provider/provider.dart';
import 'features/planit/ToDo/todoController.dart';
import 'features/pantry/groceries/grocerycontroller.dart';
import 'features/planit/specialDay/specialDaysController.dart';
import 'package:wai_life_assistant/features/lifestyle/widgets/lifestyle_controller.dart';

Future<void> bootstrapApp(String env) async {
  WidgetsFlutterBinding.ensureInitialized();

  envConfig = EnvironmentConfig.fromEnv(env);

  // Phase 1 — Firebase and Supabase are independent; run in parallel.
  bool firebaseReady = false;
  await Future.wait([
    // Firebase + FCM
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .then((_) { firebaseReady = true; })
        .catchError((Object e) {
          debugPrint('[Bootstrap] Firebase not configured — FCM disabled: $e');
        }),
    // Supabase
    Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    ),
  ]);

  // Phase 2 — ErrorLogger, Notifications, Network, and SharedPreferences are
  // independent of each other (all depend only on Phase 1 having completed).
  // Pre-warming SharedPreferences avoids a cold disk read later in BottomNavScreen.
  await Future.wait([
    ErrorLogger.initialize(),
    NotificationService.instance.init(),
    NetworkService.instance.init(),
    SharedPreferences.getInstance(),
  ]);
  // Must run after NetworkService.init() so the isOnline listener is ready.
  RealtimeSyncService.instance.init();

  // FCM + Crashlytics require Firebase to be ready — run after Phase 1.
  if (firebaseReady) {
    try {
      await FcmService.initialize();
    } catch (e) {
      debugPrint('[Bootstrap] FCM init failed — push notifications disabled: $e');
    }
    try {
      // Disable Crashlytics in debug so local runs don't pollute the dashboard.
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);
    } catch (e) {
      debugPrint('[Bootstrap] Crashlytics init failed: $e');
    }
  }

  // SMS auto-scan disabled — READ_SMS permission removed until Play Store approval.
  // Re-enable these two lines and restore the manifest permission when ready:
  // try { await SMSParserService.initialize(); } catch (e) { debugPrint('[Bootstrap] SMS init failed: $e'); }
  // await SMSParserService.checkPending();

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
