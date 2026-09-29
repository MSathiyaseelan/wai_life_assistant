import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/data/services/pantry_service.dart';
import 'network_service.dart';

class RealtimeSyncService {
  RealtimeSyncService._();
  static final RealtimeSyncService instance = RealtimeSyncService._();

  /// Bumped with the wallet id of any meal_entries insert/update (incl.
  /// soft delete) in one of the user's wallets — lets Meal Map pick up
  /// other family members' changes live.
  final mealEntriesChanged = ValueNotifier<({String walletId, int seq})?>(null);
  int _mealSeq = 0;

  final List<RealtimeChannel> _channels = [];
  String? _lastUserId;
  List<String> _lastMealWalletIds = const [];

  SupabaseClient get _db => Supabase.instance.client;

  void init() {
    NetworkService.instance.isOnline.addListener(_onNetworkChange);
  }

  void _onNetworkChange() {
    if (NetworkService.instance.isOnline.value && _lastUserId != null) {
      debugPrint('[Realtime] reconnected — resubscribing for $_lastUserId');
      subscribeAll(_lastUserId!, mealWalletIds: _lastMealWalletIds);
    }
  }

  void subscribeAll(String userId, {List<String> mealWalletIds = const []}) {
    unsubscribeAll();
    _lastUserId = userId;
    _lastMealWalletIds = mealWalletIds;

    // meal_entries is wallet-scoped (it has created_by, no user_id), so
    // it's watched per wallet — personal and every family wallet.
    //
    // This used to also open a user_id-filtered channel for each of notes,
    // reminders, wishes, health_medications, health_appointments,
    // wardrobe_items and item_locator_items. Those never delivered anything
    // (the caller passes the personal wallet id, not the user id, and
    // notes/reminders/wishes have no user_id column at all) and nothing
    // listened to what they bumped — so they were removed rather than
    // spending 7 Realtime channels per open app. To add live sync for one
    // of those tables, subscribe per wallet like meal_entries below and
    // expose a notifier its screen actually listens to.
    //
    // grocery_items (Pantry Basket + Dashboard Shopping List) rides on the
    // same per-wallet channel, so another family member's add / tick / move
    // shows up live. Needs migration 202 (publication + REPLICA IDENTITY
    // FULL, without which filtered DELETEs — ticked items — never arrive).
    for (final walletId in mealWalletIds) {
      final channel = _db
          .channel('wallet:$walletId:meal_entries')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'meal_entries',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'wallet_id',
              value: walletId,
            ),
            callback: (_) {
              mealEntriesChanged.value = (walletId: walletId, seq: ++_mealSeq);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'grocery_items',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'wallet_id',
              value: walletId,
            ),
            callback: (_) => _scheduleGroceryRefresh(),
          )
          .subscribe();
      _channels.add(channel);
    }
  }

  /// One "Mark bought" or "Create list" touches several grocery rows at
  /// once, so events are coalesced into a single refresh of the Basket and
  /// Shopping List instead of one refetch per row.
  Timer? _groceryDebounce;
  void _scheduleGroceryRefresh() {
    _groceryDebounce?.cancel();
    _groceryDebounce = Timer(const Duration(milliseconds: 400), () {
      PantryService.listChangeSignal.value++;
    });
  }

  /// Live-refresh family details (name/emoji/photo/permissions) for every
  /// family the user belongs to, so an admin's edit (e.g. the group photo)
  /// reaches other members immediately instead of waiting for their next
  /// natural refetch (app restart / manual pull-to-refresh).
  void subscribeFamilies(List<String> familyIds, VoidCallback onChange) {
    for (final familyId in familyIds) {
      final channel = _db
          .channel('family:$familyId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'families',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: familyId,
            ),
            callback: (_) => onChange(),
          )
          // family_members has no row for a not-yet-accepted invitee, so this
          // only fires once accept_family_invite actually inserts/removes a
          // row — that's exactly the "member joined/left" event the admin
          // and other members need to see reflected live.
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'family_members',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'family_id',
              value: familyId,
            ),
            callback: (_) => onChange(),
          )
          .subscribe();
      _channels.add(channel);
    }
  }

  void unsubscribeAll() {
    _groceryDebounce?.cancel();
    for (final channel in _channels) {
      _db.removeChannel(channel);
    }
    _channels.clear();
  }

  void dispose() {
    NetworkService.instance.isOnline.removeListener(_onNetworkChange);
    unsubscribeAll();
  }
}
