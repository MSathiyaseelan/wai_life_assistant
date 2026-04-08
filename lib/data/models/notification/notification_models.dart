// ─────────────────────────────────────────────────────────────────────────────
// Notification Models
// ─────────────────────────────────────────────────────────────────────────────

class AppNotification {
  final String id;
  final String userId;
  final String familyId;
  final String? txId;
  final String? actorId;
  final String actorName;
  final String actorEmoji;
  final String txType;
  final String txCategory;
  final double txAmount;
  final String? txTitle;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.familyId,
    this.txId,
    this.actorId,
    required this.actorName,
    required this.actorEmoji,
    required this.txType,
    required this.txCategory,
    required this.txAmount,
    this.txTitle,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromRow(Map<String, dynamic> row) {
    return AppNotification(
      id:          row['id']           as String,
      userId:      row['user_id']      as String,
      familyId:    row['family_id']    as String,
      txId:        row['tx_id']        as String?,
      actorId:     row['actor_id']     as String?,
      actorName:   row['actor_name']   as String? ?? '',
      actorEmoji:  row['actor_emoji']  as String? ?? '👤',
      txType:      row['tx_type']      as String? ?? '',
      txCategory:  row['tx_category']  as String? ?? '',
      txAmount:    (row['tx_amount'] as num?)?.toDouble() ?? 0,
      txTitle:     row['tx_title']     as String?,
      isRead:      row['is_read']      as bool? ?? false,
      createdAt:   DateTime.parse(row['created_at'] as String),
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id:          id,
    userId:      userId,
    familyId:    familyId,
    txId:        txId,
    actorId:     actorId,
    actorName:   actorName,
    actorEmoji:  actorEmoji,
    txType:      txType,
    txCategory:  txCategory,
    txAmount:    txAmount,
    txTitle:     txTitle,
    isRead:      isRead ?? this.isRead,
    createdAt:   createdAt,
  );

  /// Human-readable body text shown in the notification tile.
  String get body {
    final label = txTitle?.isNotEmpty == true ? txTitle! : txCategory;
    final sign   = (txType == 'income' || txType == 'borrow') ? '+' : '-';
    return '$actorEmoji $actorName added $txType · $label · $sign₹${txAmount.toStringAsFixed(0)}';
  }
}
