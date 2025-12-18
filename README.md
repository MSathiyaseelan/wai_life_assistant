# wai_life_assistant

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## To find emulators
flutter emulators
flutter emulators --launch <emulator_id>

## From Terminal to run the app
flutter run
D:\Personal\ToDo\Projects\Repos\wai_life_assistant\lib> flutter run

For Environment change
Dev --> flutter run -t lib/main_dev.dart
Prod --> flutter run -t lib/main_prod.dart

Release build:
flutter build apk -t lib/main_prod.dart
flutter build appbundle -t lib/main_prod.dart

## API Usage Example
final apiUrl = '${envConfig.baseUrl}/auth/login';

## Logging
Button Click
onTap: () {
  AppLogger.d("Health feature tapped");
}

API Logging Example
try {
  AppLogger.i("Calling login API");
  // API call
} catch (e, s) {
  AppLogger.e(
    "Login failed",
    error: e,
    stackTrace: s,
  );
}


Network Logging (Optional but Powerful)
If using Dio, add interceptor:
dio.interceptors.add(
  InterceptorsWrapper(
    onRequest: (options, handler) {
      AppLogger.d("REQUEST → ${options.method} ${options.path}");
      handler.next(options);
    },
    onResponse: (response, handler) {
      AppLogger.i("RESPONSE → ${response.statusCode}");
      handler.next(response);
    },
    onError: (e, handler) {
      AppLogger.e(
        "API ERROR",
        error: e,
        stackTrace: e.stackTrace,
      );
      handler.next(e);
    },
  ),
);


## Dio
Example: Calling API from UI
final authRepo = AuthRepository();

onPressed: () async {
  try {
    await authRepo.login(email, password);
  } catch (e) {
    // show snackbar / dialog
  }
};
