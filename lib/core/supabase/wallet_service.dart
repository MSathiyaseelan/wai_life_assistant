import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin service layer between the wallet UI and Supabase.
/// All methods throw [PostgrestException] on failure — callers should catch.
class WalletService {
  WalletService._();
  static final WalletService instance = WalletService._();

  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

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
    String? note,
    String? person,
    List<String>? persons,
    String? status,
    String? dueDate,
    DateTime? date,
  }) async {
    final row = await _db.from('transactions').insert({
      'wallet_id': walletId,
      'user_id': _uid,
      'type': type,
      'pay_mode': payMode,
      'amount': amount,
      'category': category,
      'note': note,
      'person': person,
      'persons': persons,
      'status': status,
      'due_date': dueDate,
      'date': (date ?? DateTime.now()).toIso8601String(),
    }).select().single();
    return row;
  }

  /// Delete a transaction (balance trigger rolls back the wallet amounts).
  Future<void> deleteTransaction(String txId) async {
    await _db.from('transactions').delete().eq('id', txId);
  }

  /// Update mutable fields on a transaction (category, note, status, etc.).
  Future<void> updateTransaction(
    String txId,
    Map<String, dynamic> updates,
  ) async {
    await _db.from('transactions').update(updates).eq('id', txId);
  }

  // ── Split Groups ─────────────────────────────────────────────────────────

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
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Create a split group with an initial set of participants.
  Future<Map<String, dynamic>> createSplitGroup({
    required String walletId,
    required String name,
    required String emoji,
    required List<({String name, String emoji, String? phone, bool isMe})> participants,
  }) async {
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

  /// Update a share's settlement status.
  Future<void> updateShareStatus({
    required String shareId,
    required String status,
    String? proofNote,
    String? proofImagePath,
    DateTime? proofDate,
    DateTime? extensionDate,
    String? extensionReason,
  }) async {
    await _db.from('split_shares').update({
      'status': status,
      if (proofNote != null)       'proof_note': proofNote,
      if (proofImagePath != null)  'proof_image_path': proofImagePath,
      if (proofDate != null)       'proof_date': proofDate.toIso8601String(),
      if (extensionDate != null)   'extension_date': extensionDate.toIso8601String(),
      if (extensionReason != null) 'extension_reason': extensionReason,
    }).eq('id', shareId);
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

  /// Delete a bill.
  Future<void> deleteBill(String billId) async {
    await _db.from('bills').delete().eq('id', billId);
  }
}
