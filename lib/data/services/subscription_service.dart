import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:wai_life_assistant/core/subscription/revenuecat_config.dart';

/// Thin wrapper around the RevenueCat SDK. Every method no-ops safely when
/// RevenueCatConfig.isConfigured is false (no API key set yet for this
/// environment) so the app keeps working normally before the console-side
/// RevenueCat/Play Console setup is done.
class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  bool _configured = false;

  /// Call once at app startup, before or after login — RevenueCat starts
  /// with an anonymous subscriber id; call [login] once the Supabase user
  /// id is known to link purchases to the real account.
  Future<void> init() async {
    if (!RevenueCatConfig.isConfigured || _configured) return;
    try {
      if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(
        PurchasesConfiguration(RevenueCatConfig.androidApiKey),
      );
      _configured = true;
    } catch (_) {
      // Never let a RevenueCat setup failure block app startup.
    }
  }

  /// Links the RevenueCat subscriber to [supabaseUserId] — call once right
  /// after a successful login so purchases follow the real account instead
  /// of an anonymous RevenueCat-generated id.
  Future<void> login(String supabaseUserId) async {
    if (!_configured) return;
    try {
      await Purchases.logIn(supabaseUserId);
    } catch (_) {
      // Non-fatal — worst case this device's purchases stay tied to an
      // anonymous id until the next successful login call.
    }
  }

  Future<void> logout() async {
    if (!_configured) return;
    try {
      await Purchases.logOut();
    } catch (_) {}
  }

  /// Fetches configured Offerings (plans) from the RevenueCat dashboard.
  /// Returns null if not configured or the fetch fails.
  Future<Offerings?> getOfferings() async {
    if (!_configured) return null;
    try {
      return await Purchases.getOfferings();
    } catch (_) {
      return null;
    }
  }

  /// Starts a purchase for [package]. Returns the updated CustomerInfo on
  /// success, null if the user cancelled the purchase flow, and rethrows
  /// any other error so the caller can show a real error message.
  Future<CustomerInfo?> purchasePackage(Package package) async {
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return result.customerInfo;
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return null;
      }
      rethrow;
    }
  }

  /// Restores previous purchases onto the current account (e.g. after a
  /// reinstall or new device). Returns null if not configured.
  Future<CustomerInfo?> restorePurchases() async {
    if (!_configured) return null;
    return Purchases.restorePurchases();
  }

  /// Whether the current subscriber has an active [entitlementId]
  /// (the identifier configured in the RevenueCat dashboard, e.g.
  /// 'family_plus' / 'family_pro').
  Future<bool> isEntitledTo(String entitlementId) async {
    if (!_configured) return false;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(entitlementId);
    } catch (_) {
      return false;
    }
  }
}
