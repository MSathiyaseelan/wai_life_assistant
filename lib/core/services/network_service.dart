import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Listens to connectivity changes and exposes [isOnline].
/// Screens subscribe to [isOnline] to reload data when connection is restored.
class NetworkService {
  NetworkService._();
  static final NetworkService instance = NetworkService._();

  final ValueNotifier<bool> isOnline = ValueNotifier(true);
  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> init() async {
    final results = await Connectivity().checkConnectivity();
    isOnline.value = _hasConnection(results);

    _sub = Connectivity().onConnectivityChanged.listen((results) {
      isOnline.value = _hasConnection(results);
      debugPrint('[Network] online=${isOnline.value} ($results)');
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  void dispose() {
    _sub?.cancel();
    isOnline.dispose();
  }
}
