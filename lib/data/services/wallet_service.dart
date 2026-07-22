import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/core/constants/api_endpoints.dart';
import 'package:wai_life_assistant/core/services/app_prefs.dart';
import 'package:wai_life_assistant/data/models/wallet/split_group_models.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';

/// Thrown by [WalletService.addTransaction] when the caller's monthly
/// wallet-transaction quota (personal or shared family pool) is exhausted.
class TransactionLimitExceededException implements Exception {
  const TransactionLimitExceededException();
  @override
  String toString() =>
      "You've reached this month's transaction limit on your current plan. Upgrade to add more.";
}

/// Thrown by [WalletService.createSplitGroup] when the caller's monthly
/// split-group quota (personal or shared family pool) is exhausted.
class SplitGroupLimitExceededException implements Exception {
  const SplitGroupLimitExceededException();
  @override
  String toString() =>
      "You've reached this month's split group limit on your current plan. Upgrade to create more.";
}

/// Thin service layer between the wallet UI and Supabase.
/// All methods throw [PostgrestException] on failure — callers should catch.
class WalletService {
  WalletService._();
  static final WalletService instance = WalletService._();

  /// Fires whenever a transaction is added, updated, or deleted.
  /// Listeners (e.g. DashboardScreen) can reload their transaction list.
  static final txChangeSignal = ValueNotifier<int>(0);

  SupabaseClient get _db => Supabase.instance.client;
  String get _uid {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('Not authenticated');
    return uid;
  }

  // ── Categories ──────────────────────────────────────────────────────────────

  static const defaultExpenseCategories = [
    'Food', 'Groceries', 'Transport', 'Shopping', 'Bills',
    'Health', 'Entertainment', 'Education', 'Fuel', 'Housing',
    'Clothing', 'Gifts', 'Subscription', 'Investment', 'Fitness',
    'Vacation', 'Other',
  ];
  static const defaultIncomeCategories = [
    'Salary', 'Freelance', 'Business', 'Rent', 'Investment',
    'Refund', 'Gift', 'Bonus', 'Other',
  ];
  static const defaultTransferCategories = [
    'Personal Loan', 'Shared Expense', 'Emergency', 'Other',
  ];

  List<String> _customExpense = [];
  List<String> _customIncome = [];
  List<String> _customTransfer = [];
  bool _categoriesLoaded = false;

  /// Strip emoji/punctuation, collapse whitespace, lowercase. Mirrors the
  /// SQL backfill in 088_normalize_tx_categories.sql — used to match
  /// category names case/emoji-insensitively.
  static String _normalize(String s) => s
      .replaceAll(RegExp(r'[^\w\s]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();

  List<String> _merge(List<String> defaults, List<String> custom) {
    final seen = <String>{};
    final out = <String>[];
    for (final c in [...defaults, ...custom]) {
      if (seen.add(_normalize(c))) out.add(c);
    }
    return out;
  }

  /// Returns the full category list (defaults + user-saved) for the given tx type string.
  /// [txType] is 'expense', 'income', or 'transfer' (covers lend/borrow/request).
  /// Case/emoji-insensitively deduplicated — if legacy data has both "Food"
  /// and "food", only the first-seen form is shown here.
  List<String> categoriesFor(String txType) {
    if (txType == 'income') return _merge(defaultIncomeCategories, _customIncome);
    if (txType == 'transfer') return _merge(defaultTransferCategories, _customTransfer);
    return _merge(defaultExpenseCategories, _customExpense);
  }

  /// Resolves a raw category string (possibly emoji-prefixed, mis-cased, or
  /// brand new) to the canonical name that should actually be stored.
  /// - Strips embedded emoji/punctuation from a genuinely new category.
  /// - If a case/emoji-insensitive match already exists (default or
  ///   user-saved), returns that exact existing string instead of creating
  ///   a near-duplicate.
  /// - Otherwise persists the cleaned name as a new category (fire-and-forget)
  ///   and returns it.
  String resolveCategoryName(String raw, String txTypeName) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    final catType = txCategoryType(txTypeName);
    final key = _normalize(trimmed);
    if (key.isEmpty) return trimmed;

    final existing = categoriesFor(catType).firstWhere(
      (c) => _normalize(c) == key,
      orElse: () => '',
    );
    if (existing.isNotEmpty) return existing;

    // Genuinely new category: strip emoji/punctuation, title-case it.
    final cleaned = trimmed
        .replaceAll(RegExp(r'[^\w\s]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final canonical = cleaned.isEmpty
        ? trimmed
        : cleaned
            .split(' ')
            .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
            .join(' ');
    ensureCategory(canonical, txTypeName);
    return canonical;
  }

  /// Maps a TxType name to the simpler category type string.
  static String txCategoryType(String txTypeName) {
    if (txTypeName == 'income') return 'income';
    if (txTypeName == 'expense') return 'expense';
    return 'transfer'; // lend, borrow, request, split, returned
  }

  /// Load user-saved categories from DB into cache.
  /// On first use (empty table for this user), seeds all defaults so the DB
  /// becomes the source of truth immediately.
  /// Categories rarely change mid-session, so subsequent calls are a no-op
  /// unless [forceReload] is set — pass true after switching accounts.
  Future<void> loadCategories({bool forceReload = false}) async {
    if (_categoriesLoaded && !forceReload) return;
    try {
      final rows = await _db
          .from('user_tx_categories')
          .select()
          .eq('user_id', _uid)
          .order('created_at');

      if (rows.isEmpty) {
        // First time — seed all defaults into DB
        final seeds = [
          ...defaultExpenseCategories.map((n) => {'user_id': _uid, 'name': n, 'tx_type': 'expense', 'normalized_name': _normalize(n)}),
          ...defaultIncomeCategories.map((n) => {'user_id': _uid, 'name': n, 'tx_type': 'income', 'normalized_name': _normalize(n)}),
          ...defaultTransferCategories.map((n) => {'user_id': _uid, 'name': n, 'tx_type': 'transfer', 'normalized_name': _normalize(n)}),
        ];
        await _db.from('user_tx_categories').upsert(seeds, onConflict: 'user_id,name,tx_type');
        _customExpense = List.from(defaultExpenseCategories);
        _customIncome = List.from(defaultIncomeCategories);
        _customTransfer = List.from(defaultTransferCategories);
        _categoriesLoaded = true;
        return;
      }

      _customExpense = rows
          .where((r) => r['tx_type'] == 'expense')
          .map((r) => r['name'] as String)
          .toList();
      _customIncome = rows
          .where((r) => r['tx_type'] == 'income')
          .map((r) => r['name'] as String)
          .toList();
      _customTransfer = rows
          .where((r) => r['tx_type'] == 'transfer')
          .map((r) => r['name'] as String)
          .toList();
      _categoriesLoaded = true;
    } catch (e, stack) {
      debugPrint('[WalletService] loadCategories error: $e');
      ErrorLogger.log(e, stackTrace: stack, action: 'load_tx_categories');
    }
  }

  /// Persist a category to DB whenever it is used (default or custom).
  /// Safe to call fire-and-forget; errors are swallowed. No-ops if a
  /// case/emoji-insensitive match already exists, so this never creates a
  /// near-duplicate row (e.g. "food" when "Food" is already saved).
  Future<void> ensureCategory(String name, String txTypeName) async {
    final cat = name.trim();
    if (cat.isEmpty) return;
    final catType = txCategoryType(txTypeName);
    final key = _normalize(cat);
    if (categoriesFor(catType).any((c) => _normalize(c) == key)) return;
    try {
      // Standing count cap (plan_limits.wallet_custom_categories_max), not a
      // monthly usage counter — the transaction itself still saves fine with
      // this category as free text either way; being at the cap only means
      // it won't be remembered as a reusable chip for next time.
      final limit = await _db.rpc(AppRpc.getEffectiveFeatureLimit, params: {
        'p_user_id': _uid,
        'p_feature': 'custom_category',
      }) as int? ?? 10;
      if (limit != -1) {
        final existing = await _db
            .from('user_tx_categories')
            .select('id')
            .eq('user_id', _uid);
        if ((existing as List).length >= limit) return;
      }

      await _db.from('user_tx_categories').upsert(
        {'user_id': _uid, 'name': cat, 'tx_type': catType, 'normalized_name': key},
        onConflict: 'user_id,name,tx_type',
      );
      // Update local cache so it's immediately available
      final cache = catType == 'income'
          ? _customIncome
          : catType == 'transfer'
              ? _customTransfer
              : _customExpense;
      if (!cache.contains(cat)) cache.add(cat);
    } catch (e, stack) {
      debugPrint('[WalletService] ensureCategory error: $e');
      ErrorLogger.log(e, stackTrace: stack, action: 'ensure_tx_category', extra: {'name': name});
    }
  }

  // ── Wallets ─────────────────────────────────────────────────────────────

  /// Fetch all wallets visible to the current user (personal + family).
  Future<List<Map<String, dynamic>>> fetchWallets() async {
    final rows = await _db
        .from('wallets')
        .select()
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Create the personal wallet for the current user (call once on sign-up).
  Future<Map<String, dynamic>> createPersonalWallet({
    String name = 'Personal',
    String emoji = '👤',
  }) async {
    final row = await _db.from('wallets').insert({
      'owner_id': _uid,
      'name': name,
      'emoji': emoji,
      'is_personal': true,
    }).select().single();
    return row;
  }

  /// Create a family wallet linked to a [familyId].
  Future<Map<String, dynamic>> createFamilyWallet({
    required String familyId,
    required String name,
    required String emoji,
    int gradientIndex = 0,
  }) async {
    final row = await _db.from('wallets').insert({
      'family_id': familyId,
      'name': name,
      'emoji': emoji,
      'is_personal': false,
      'gradient_index': gradientIndex,
    }).select().single();
    return row;
  }

  // ── Families ─────────────────────────────────────────────────────────────

  /// Fetch all families the current user belongs to.
  Future<List<Map<String, dynamic>>> fetchFamilies() async {
    final rows = await _db
        .from('families')
        .select('*, family_members(*)')
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Create a new family/group and add the creator as admin.
  Future<Map<String, dynamic>> createFamily({
    required String name,
    required String emoji,
    int colorIndex = 0,
  }) async {
    // 1. Insert family
    final family = await _db.from('families').insert({
      'name': name,
      'emoji': emoji,
      'color_index': colorIndex,
      'created_by': _uid,
    }).select().single();

    // 2. Add creator as admin member
    final profile = await _db
        .from('profiles')
        .select('name, emoji')
        .eq('id', _uid)
        .single();
    await _db.from('family_members').insert({
      'family_id': family['id'],
      'user_id': _uid,
      'name': profile['name'] ?? 'Me',
      'emoji': profile['emoji'] ?? '👤',
      'role': 'admin',
      'relation': 'Self',
    });

    return family;
  }

  /// Add a member to a family.
  Future<void> addFamilyMember({
    required String familyId,
    required String name,
    required String emoji,
    String role = 'member',
    String? relation,
    String? phone,
    String? userId,
  }) async {
    await _db.from('family_members').insert({
      'family_id': familyId,
      'user_id': userId,
      'name': name,
      'emoji': emoji,
      'role': role,
      'relation': relation,
      'phone': phone,
    });
  }

  // ── Transactions ─────────────────────────────────────────────────────────

  /// Fetch all transactions for a given wallet, newest first.
  Future<List<Map<String, dynamic>>> fetchTransactions(String walletId) async {
    final rows = await _db
        .from('transactions')
        .select()
        .eq('wallet_id', walletId)
        .filter('deleted_at', 'is', null)
        .order('date', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Add a new transaction. The balance trigger updates the wallet automatically.
  Future<Map<String, dynamic>> addTransaction({
    required String walletId,
    required String type,       // TxType.name
    required double amount,
    required String category,
    String? payMode,            // PayMode.name, null for split/lend/borrow/request
    String? title,
    String? note,
    String? person,
    List<String>? persons,
    String? status,
    String? dueDate,
    DateTime? date,
    String? groupId,
  }) async {
    final allowed = await _db.rpc(AppRpc.checkFeatureLimit, params: {
      'p_user_id': _uid,
      'p_feature': 'wallet_transaction',
    }) as bool? ?? true;
    if (!allowed) throw const TransactionLimitExceededException();

    final row = await _db.from('transactions').insert({
      'wallet_id': walletId,
      'user_id': _uid,
      'type': type,
      'pay_mode': payMode,
      'amount': amount,
      'category': resolveCategoryName(category, type),
      'title': title,
      'note': note,
      'person': person,
      'persons': persons,
      'status': status,
      'due_date': dueDate,
      'date': (date ?? DateTime.now()).toIso8601String(),
      if (groupId != null) 'group_id': groupId,
    }).select().single();
    return row;
  }

  /// Soft-delete a transaction (balance trigger rolls back the wallet amounts).
  Future<void> deleteTransaction(String txId) async {
    await _db.from('transactions').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', txId);
  }

  /// Update mutable fields on a transaction (category, note, status, etc.).
  /// If [updates] renames the category, it's resolved through the same
  /// [resolveCategoryName] normalization used on insert.
  Future<void> updateTransaction(
    String txId,
    Map<String, dynamic> updates,
  ) async {
    final newCategory = updates['category'] as String?;
    final resolved = newCategory == null
        ? updates
        : {
            ...updates,
            'category': resolveCategoryName(newCategory, updates['type'] as String? ?? 'expense'),
          };
    await _db.from('transactions').update(resolved).eq('id', txId);
  }

  // ── Transaction Groups ────────────────────────────────────────────────────

  /// Fetch all tx_groups for a wallet.
  Future<List<Map<String, dynamic>>> fetchTxGroups(String walletId) async {
    final rows = await _db
        .from('tx_groups')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Create a new transaction group.
  Future<Map<String, dynamic>> createTxGroup({
    required String walletId,
    required String name,
    String emoji = '📦',
  }) async {
    final row = await _db.from('tx_groups').insert({
      'wallet_id': walletId,
      'user_id': _uid,
      'name': name,
      'emoji': emoji,
    }).select().single();
    return row;
  }

  /// Rename / re-emoji a group.
  Future<void> updateTxGroup(String groupId, {String? name, String? emoji}) async {
    final fields = <String, dynamic>{};
    if (name != null) fields['name'] = name;
    if (emoji != null) fields['emoji'] = emoji;
    if (fields.isNotEmpty) {
      await _db.from('tx_groups').update(fields).eq('id', groupId);
    }
  }

  /// Delete a group (soft). Member transactions stay but their group_id is set to NULL.
  Future<void> deleteTxGroup(String groupId) async {
    await _db.from('tx_groups').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', groupId);
  }

  /// Assign or remove a transaction from a group (groupId = null to ungroup).
  Future<void> setTxGroup(String txId, String? groupId) async {
    await _db.from('transactions').update({'group_id': groupId}).eq('id', txId);
  }

  // ── Split Groups ─────────────────────────────────────────────────────────

  /// Fetch all split groups pinned to the dashboard for the current user.
  Future<List<SplitGroup>> fetchPinnedSplitGroups() async {
    final rows = await _db
        .from('split_groups')
        .select('''
          *,
          split_participants(*),
          split_group_transactions(
            *,
            split_shares(*)
          )
        ''')
        .eq('pinned_to_dashboard', true)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => splitGroupFromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Toggle the dashboard pin for a split group.
  Future<void> updateSplitGroupPin(String groupId, {required bool pinned}) async {
    await _db
        .from('split_groups')
        .update({'pinned_to_dashboard': pinned})
        .eq('id', groupId);
  }

  /// Update a split group's name and emoji (photo URL).
  Future<void> updateSplitGroup(
    String groupId, {
    required String name,
    required String emoji,
    required bool pinned,
  }) async {
    await _db.from('split_groups').update({
      'name': name,
      'emoji': emoji,
      'pinned_to_dashboard': pinned,
    }).eq('id', groupId);
  }

  /// Fetch all split groups for a wallet, including participants & transactions.
  Future<List<Map<String, dynamic>>> fetchSplitGroups(String walletId) async {
    final rows = await _db
        .from('split_groups')
        .select('''
          *,
          split_participants(*),
          split_group_transactions(
            *,
            split_shares(*)
          )
        ''')
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Soft-delete a split group; participants/transactions/shares are left
  /// intact until the 30-day purge issues a real (cascading) DELETE.
  Future<void> deleteSplitGroup(String groupId) async {
    await _db.from('split_groups').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', groupId);
  }

  /// Create a split group with an initial set of participants.
  Future<Map<String, dynamic>> createSplitGroup({
    required String walletId,
    required String name,
    required String emoji,
    required List<({String name, String emoji, String? phone, bool isMe})> participants,
  }) async {
    final allowed = await _db.rpc(AppRpc.checkFeatureLimit, params: {
      'p_user_id': _uid,
      'p_feature': 'split_group',
    }) as bool? ?? true;
    if (!allowed) throw const SplitGroupLimitExceededException();

    // 1. Insert group
    final group = await _db.from('split_groups').insert({
      'wallet_id': walletId,
      'created_by': _uid,
      'name': name,
      'emoji': emoji,
    }).select().single();

    // 2. Insert participants and return them with real DB ids
    final rows = participants.map((p) => {
      'group_id': group['id'],
      'user_id': p.isMe ? _uid : null,
      'name': p.name,
      'emoji': p.emoji,
      'phone': p.phone,
      'is_me': p.isMe,
    }).toList();
    final insertedParticipants = await _db
        .from('split_participants')
        .insert(rows)
        .select();

    return {
      ...group,
      'split_participants': insertedParticipants,
    };
  }

  /// Add a split transaction with per-participant shares.
  Future<Map<String, dynamic>> addSplitTransaction({
    required String groupId,
    required String addedByParticipantId,
    required String title,
    required double totalAmount,
    required String splitType,  // 'equal' | 'unequal' | 'percentage' | 'custom'
    required List<({String participantId, double amount, double? percentage})> shares,
    String? note,
    DateTime? date,
    String? paymentMode,
  }) async {
    // 1. Insert transaction
    final tx = await _db.from('split_group_transactions').insert({
      'group_id': groupId,
      'added_by_id': addedByParticipantId,
      'title': title,
      'total_amount': totalAmount,
      'split_type': splitType,
      'note': note,
      'date': (date ?? DateTime.now()).toIso8601String(),
      if (paymentMode != null && paymentMode.isNotEmpty) 'payment_mode': paymentMode,
    }).select().single();

    // 2. Insert shares — payer's own share is auto-settled
    final shareRows = shares.map((s) => {
      'transaction_id': tx['id'],
      'participant_id': s.participantId,
      'amount': s.amount,
      'percentage': s.percentage,
      'status': s.participantId == addedByParticipantId ? 'settled' : 'pending',
    }).toList();
    await _db.from('split_shares').insert(shareRows);

    return tx;
  }

  /// Update an existing split transaction and its share amounts.
  Future<void> updateSplitTransaction({
    required String txId,
    required String title,
    required double totalAmount,
    required String splitType,
    required List<({String shareId, double amount, double? percentage})> shares,
    String? note,
    DateTime? date,
    String? paymentMode,
  }) async {
    await _db.from('split_group_transactions').update({
      'title': title,
      'total_amount': totalAmount,
      'split_type': splitType,
      'note': note,
      'date': (date ?? DateTime.now()).toIso8601String(),
      'payment_mode': (paymentMode != null && paymentMode.isNotEmpty) ? paymentMode : null,
    }).eq('id', txId);

    for (final s in shares) {
      if (s.shareId.isEmpty) continue;
      await _db.from('split_shares').update({
        'amount': s.amount,
        'percentage': s.percentage,
      }).eq('id', s.shareId);
    }
  }

  /// Update a share's settlement status.
  Future<void> updateShareStatus({
    required String shareId,
    required String status,
    String? proofNote,
    String? proofImagePath,
    DateTime? proofDate,
    DateTime? extensionDate,
    String? extensionReason,
    String? extensionResponseMsg,
    // Fallback when shareId is not yet populated (use tx+participant)
    String? transactionId,
    String? participantId,
  }) async {
    final data = {
      'status': status,
      if (proofNote != null)              'proof_note': proofNote,
      if (proofImagePath != null)         'proof_image_path': proofImagePath,
      if (proofDate != null)              'proof_date': proofDate.toIso8601String(),
      if (extensionDate != null)          'extension_date': extensionDate.toIso8601String(),
      if (extensionReason != null)        'extension_reason': extensionReason,
      if (extensionResponseMsg != null)   'extension_response_msg': extensionResponseMsg,
    };
    if (shareId.isNotEmpty) {
      await _db.from('split_shares').update(data).eq('id', shareId);
    } else if (transactionId != null && participantId != null) {
      await _db.from('split_shares').update(data)
          .eq('transaction_id', transactionId)
          .eq('participant_id', participantId);
    }
  }

  /// Upload a payment proof image to Supabase Storage and return a signed URL
  /// valid for 10 years (proof images are long-lived).
  Future<String> uploadProofImage({
    required String groupId,
    required List<int> imageBytes,
    String extension = 'jpg',
  }) async {
    final path =
        'proofs/$groupId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _db.storage
        .from('split-proof')
        .uploadBinary(path, Uint8List.fromList(imageBytes));
    return _db.storage.from('split-proof').getPublicUrl(path);
  }

  /// Atomically increment the reminder count for a share.
  Future<void> recordReminderSent({
    required String transactionId,
    required String participantId,
    required String sentBy,
  }) async {
    await _db.rpc(AppRpc.incrementSplitReminder, params: {
      'p_transaction_id': transactionId,
      'p_participant_id': participantId,
      'p_sent_by': sentBy,
    });
  }

  // ── Split Group Chat ──────────────────────────────────────────────────────

  /// Fetch messages for a split group, oldest first.
  Future<List<Map<String, dynamic>>> fetchMessages(String groupId) async {
    final rows = await _db
        .from('split_group_messages')
        .select()
        .eq('group_id', groupId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Post a message to a split group.
  Future<Map<String, dynamic>> postMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String senderEmoji,
    required String text,
    String type = 'text',
  }) async {
    final row = await _db.from('split_group_messages').insert({
      'group_id': groupId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_emoji': senderEmoji,
      'text': text,
      'type': type,
    }).select().single();
    return row;
  }

  // ── Realtime ──────────────────────────────────────────────────────────────

  /// Subscribe to live transaction updates for a wallet.
  RealtimeChannel subscribeToTransactions(
    String walletId,
    void Function(Map<String, dynamic> payload) onEvent,
  ) {
    return _db
        .channel('transactions:$walletId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'wallet_id',
            value: walletId,
          ),
          callback: (payload) => onEvent(payload.newRecord),
        )
        .subscribe();
  }

  /// Subscribe to live chat messages in a split group.
  RealtimeChannel subscribeToMessages(
    String groupId,
    void Function(Map<String, dynamic> msg) onMessage,
  ) {
    return _db
        .channel('messages:$groupId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'split_group_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'group_id',
            value: groupId,
          ),
          callback: (payload) => onMessage(payload.newRecord),
        )
        .subscribe();
  }

  // ── Bills (schema matches planit BillModel) ────────────────────────────────

  /// Fetch all bills for a wallet, ordered by due date.
  Future<List<Map<String, dynamic>>> fetchBills(String walletId) async {
    final rows = await _db
        .from('bills')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
        .order('due_date');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Create a new bill.
  Future<Map<String, dynamic>> addBill({
    required String walletId,
    required String name,
    required String category,
    required double amount,
    required DateTime dueDate,
    required String repeat,
    String? provider,
    String? accountNumber,
    String? note,
  }) async {
    final row = await _db.from('bills').insert({
      'wallet_id': walletId,
      'name': name,
      'category': category,
      'amount': amount,
      'due_date': dueDate.toIso8601String().split('T').first,
      'repeat': repeat,
      if (provider != null) 'provider': provider,
      if (accountNumber != null) 'account_number': accountNumber,
      if (note != null) 'note': note,
    }).select().single();
    return row;
  }

  /// Update mutable bill fields.
  Future<void> updateBill(String billId, Map<String, dynamic> updates) async {
    await _db.from('bills').update(updates).eq('id', billId);
  }

  /// Delete a bill (soft).
  Future<void> deleteBill(String billId) async {
    await _db.from('bills').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', billId);
  }

  // ── Budgets ───────────────────────────────────────────────────────────────

  /// Fetch all budget limits for [walletId].
  Future<List<BudgetModel>> fetchBudgets(String walletId) async {
    final rows = await _db
        .from('wallet_budgets')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
        .order('category');
    return (rows as List).map((r) => BudgetModel.fromRow(r as Map<String, dynamic>)).toList();
  }

  /// Upsert a budget limit. Pass [budgetId] to update, omit to insert.
  /// Category is resolved through the same normalization as transactions
  /// so budget-vs-spend matching (computeMonthlySpent/checkAndAlertBudgets)
  /// never silently misses due to a casing/emoji mismatch.
  Future<BudgetModel> setBudget({
    required String walletId,
    required String category,
    required double limitAmount,
  }) async {
    final row = await _db.from('wallet_budgets').upsert(
      {
        'wallet_id': walletId,
        'category': resolveCategoryName(category, 'expense'),
        'limit_amount': limitAmount,
      },
      onConflict: 'wallet_id,category',
      ignoreDuplicates: false,
    ).select().single();
    return BudgetModel.fromRow(row);
  }

  /// Remove a budget limit by its id (soft delete).
  Future<void> deleteBudget(String budgetId) async {
    await _db.from('wallet_budgets').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', budgetId);
  }

  Future<void> restore(String table, String id) async {
    await _db.from(table).update({'deleted_at': null}).eq('id', id);
  }

  /// Add a new expense category to the shared user_tx_categories table.
  /// Returns the canonical name actually stored — either [name] as-typed
  /// (cleaned up), or an existing case/emoji-insensitive match if one
  /// already exists, so the caller doesn't end up displaying a near-duplicate.
  Future<String> addExpenseCategory(String name) async {
    final cat = name.trim();
    if (cat.isEmpty) return cat;
    final key = _normalize(cat);
    final existing = categoriesFor('expense').firstWhere(
      (c) => _normalize(c) == key,
      orElse: () => '',
    );
    if (existing.isNotEmpty) return existing;
    await _db.from('user_tx_categories').upsert(
      {'user_id': _uid, 'name': cat, 'tx_type': 'expense', 'normalized_name': key},
      onConflict: 'user_id,name,tx_type',
    );
    if (!_customExpense.contains(cat)) _customExpense.add(cat);
    return cat;
  }

  /// Delete an expense category from user_tx_categories.
  /// Does NOT delete transactions that used it — just removes the category entry.
  Future<void> deleteExpenseCategory(String name) async {
    await _db
        .from('user_tx_categories')
        .delete()
        .eq('user_id', _uid)
        .eq('name', name)
        .eq('tx_type', 'expense');
    _customExpense.remove(name);
  }

  /// Compute current-month spending per expense category from a loaded
  /// transaction list. Returns {category: totalSpent}.
  static Map<String, double> computeMonthlySpent(List<TxModel> transactions) {
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final map = <String, double>{};
    for (final tx in transactions) {
      if (tx.type != TxType.expense) continue;
      final txMonth =
          '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}';
      if (txMonth != month) continue;
      map[tx.category] = (map[tx.category] ?? 0) + tx.amount;
    }
    return map;
  }

  /// Check budget thresholds and send in-app notifications to all wallet
  /// members when 80% or 100% limits are first crossed this month.
  /// Updates [last_80_alert_month] / [last_100_alert_month] to avoid repeats.
  Future<void> checkAndAlertBudgets({
    required String walletId,
    required List<BudgetModel> budgets,
    required Map<String, double> spentMap,
  }) async {
    final currentMonth =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';

    // Resolve family_id — needed for notifications table.
    // Personal wallets have no family, so no in-app notifications.
    final walletRow = await _db
        .from('wallets')
        .select('family_id')
        .eq('id', walletId)
        .maybeSingle();
    final familyId = walletRow?['family_id'] as String?;

    // Fetch all linked member user_ids (family wallet only).
    List<String> memberUserIds = [];
    if (familyId != null) {
      final members = await _db
          .from('family_members')
          .select('user_id')
          .eq('family_id', familyId)
          .not('user_id', 'is', null);
      memberUserIds = (members as List)
          .map((m) => m['user_id'] as String)
          .toList();
    }

    for (final budget in budgets) {
      final spent = spentMap[budget.category] ?? 0;
      final pct = budget.limitAmount > 0 ? spent / budget.limitAmount : 0;

      bool shouldAlert80  = pct >= 0.8  && pct < 1.0 && budget.last80AlertMonth  != currentMonth;
      bool shouldAlert100 = pct >= 1.0               && budget.last100AlertMonth != currentMonth;

      if (!shouldAlert80 && !shouldAlert100) continue;

      final threshold = shouldAlert100 ? 100 : 80;
      final column = shouldAlert100 ? 'last_100_alert_month' : 'last_80_alert_month';
      final alertMsg = threshold == 100
          ? '${budget.category} budget exceeded! Spent ${AppPrefs.cs}${spent.toStringAsFixed(0)} of ${AppPrefs.cs}${budget.limitAmount.toStringAsFixed(0)}'
          : '${budget.category} budget at ${(pct * 100).toStringAsFixed(0)}%. Spent ${AppPrefs.cs}${spent.toStringAsFixed(0)} of ${AppPrefs.cs}${budget.limitAmount.toStringAsFixed(0)}';

      // Atomically claim this threshold BEFORE sending anything: the update
      // only affects a row if the column still isn't `currentMonth`, so two
      // overlapping calls for the same budget (e.g. two expenses added in
      // quick succession) can't both pass — the loser's update touches 0
      // rows and it skips sending. This closes the race where the in-memory
      // `budget` object's alert-month flag hadn't been updated yet when a
      // second call read it.
      List<dynamic> claimed;
      try {
        claimed = await _db
            .from('wallet_budgets')
            .update({column: currentMonth})
            .eq('id', budget.id)
            .or('$column.is.null,$column.neq.$currentMonth')
            .select('id');
      } catch (e, stack) {
        ErrorLogger.log(e, stackTrace: stack, action: 'budget_alert_claim');
        continue;
      }
      if (claimed.isEmpty) continue; // another concurrent call already claimed it

      if (shouldAlert80)  budget.last80AlertMonth  = currentMonth;
      if (shouldAlert100) budget.last100AlertMonth = currentMonth;

      // Send in-app notifications to family members
      if (familyId != null && memberUserIds.isNotEmpty) {
        var anySucceeded = false;
        for (final userId in memberUserIds) {
          try {
            await _db.from('notifications').insert({
              'user_id':     userId,
              'family_id':   familyId,
              'actor_emoji': threshold == 100 ? '🔴' : '🟠',
              'actor_name':  'Budget Alert',
              'tx_type':     'budget_alert',
              'tx_category': budget.category,
              'tx_amount':   spent,
              'tx_title':    alertMsg,
              'is_read':     false,
            });
            anySucceeded = true;
          } catch (e, stack) {
            ErrorLogger.log(e, stackTrace: stack, action: 'budget_alert_notify');
          }
        }
        // Every member's insert failed — release the claim so a future
        // expense in this category retries the alert instead of it being
        // permanently silenced for the month. A partial success keeps the
        // claim (re-sending to the members who already got it would spam
        // them for no benefit to the ones who didn't).
        if (!anySucceeded) {
          try {
            await _db.from('wallet_budgets').update({column: null}).eq('id', budget.id);
            if (shouldAlert80)  budget.last80AlertMonth  = null;
            if (shouldAlert100) budget.last100AlertMonth = null;
          } catch (e, stack) {
            ErrorLogger.log(e, stackTrace: stack, action: 'budget_alert_release_claim');
          }
        }
      }
    }
  }
}
