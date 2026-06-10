import 'package:flutter/foundation.dart';

/// Signal bus for dashboard deep-navigation.
/// The dashboard writes a route string; the target screen listens and pushes
/// its sub-screen on the next frame.
///
/// PlanIt signals : 'alerts' | 'tasks' | 'special_days' | 'wishes'
/// MyHub signals  : 'health:meds' | 'health:appointments' | 'health:vaccines' | 'functions'
class DashNavService {
  DashNavService._();
  static final planIt = ValueNotifier<String?>(null);
  static final myHub  = ValueNotifier<String?>(null);
}
