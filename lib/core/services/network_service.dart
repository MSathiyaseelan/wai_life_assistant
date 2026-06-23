import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Listens to connectivity changes and exposes [isOnline].
/// Screens subscribe to [isOnline] to reload data when connection is restored.
///
/// Going offline is signalled immediately.
/// Going online is debounced by 2 s so DNS/routing is stable before screens
/// fire their refresh — avoids ECONNABORTED bursts on network transitions.
class NetworkService {
  NetworkService._();
  static final NetworkService instance = NetworkService._();

  final ValueNotifier<bool> isOnline = ValueNotifier(true);
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _onlineDebounce;

  Future<void> init() async {
    final results = await Connectivity().checkConnectivity();
    isOnline.value = _hasConnection(results);

    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final connected = _hasConnection(results);
      debugPrint('[Network] online=$connected ($results)');
      if (!connected) {
        _onlineDebounce?.cancel();
        isOnline.value = false;
      } else {
        // Wait for the network stack (DHCP + DNS) to stabilise before
        // notifying screens, so their refresh requests don't hit a half-ready
        // connection and fail with ECONNABORTED.
        _onlineDebounce?.cancel();
        _onlineDebounce = Timer(const Duration(seconds: 2), () {
          isOnline.value = true;
        });
      }
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  void dispose() {
    _onlineDebounce?.cancel();
    _sub?.cancel();
    isOnline.dispose();
  }
}
