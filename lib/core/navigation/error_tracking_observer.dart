import 'package:flutter/material.dart';
import '../services/error_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ERROR TRACKING OBSERVER
// Keeps ErrorLogger in sync with the active screen so every logged error
// carries the correct screen_name + feature context.
// Register in MaterialApp.navigatorObservers.
// ─────────────────────────────────────────────────────────────────────────────

class ErrorTrackingObserver extends NavigatorObserver {

  static const _routeFeature = {
    '/':          'auth',
    '/login':     'auth',
    '/otp':       'auth',
    '/bottomNav': 'home',
    '/dashboard': 'dashboard',
    '/wallet':    'wallet',
    '/pantry':    'pantry',
    '/planit':    'planit',
    '/settings':  'settings',
    '/functions': 'functions',
  };

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    _sync(route);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) _sync(previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _sync(newRoute);
  }

  void _sync(Route route) {
    final name    = route.settings.name ?? 'unknown';
    final feature = _routeFeature[name] ?? _featureFromName(name);
    ErrorLogger.setScreen(name, feature: feature);
  }

  // Derive feature from route name when not in the map (e.g. modal sheets).
  static String _featureFromName(String name) {
    for (final entry in _routeFeature.entries) {
      if (name.startsWith(entry.key) && entry.key != '/') return entry.value;
    }
    return 'unknown';
  }
}
