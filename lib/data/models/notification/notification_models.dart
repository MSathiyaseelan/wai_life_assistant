// ─────────────────────────────────────────────────────────────────────────────
// Notification Models
// ─────────────────────────────────────────────────────────────────────────────
import 'package:wai_life_assistant/core/services/app_prefs.dart';

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
  /// How many transactions this notification represents — bumped instead of
  /// inserting a new row when several land in quick succession (e.g. a
  /// scanned bill's line items, or a group being moved between wallets), so
  /// family members get one digest notification instead of one per item.
  final int itemCount;
  /// Split group this notification deep-links to (reminder, extension
  /// request, or "added you") — null for non-split notification types.
  final String? relatedGroupId;

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
    this.itemCount = 1,
    this.relatedGroupId,
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
      itemCount:   (row['item_count'] as num?)?.toInt() ?? 1,
      relatedGroupId: row['related_group_id'] as String?,
    );
  }

  /// True when this notification is a family invite (not a transaction).
  bool get isInvite => txType == 'invite';

  /// True when this notification is a budget threshold alert.
  bool get isBudgetAlert => txType == 'budget_alert';

  /// True when this notification is a split-group payment reminder.
  bool get isSplitReminder => txType == 'split_reminder';

  /// True when this notification is a split-group extension request.
  bool get isSplitExtension => txType == 'split_extension';

  /// True when this notification is for being added to a split group.
  bool get isSplitAddedYou => txType == 'split_added_you';

  /// True for any split-group notification that should deep-link to the
  /// group when tapped.
  bool get isSplitLink =>
      relatedGroupId != null &&
      (isSplitReminder || isSplitExtension || isSplitAddedYou);

  /// The invite_id is stored in txId for invite-type notifications.
  String? get inviteId => isInvite ? txId : null;

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
    itemCount:   itemCount,
    relatedGroupId: relatedGroupId,
  );

  /// Human-readable body text shown in the notification tile.
  String get body {
    final label = itemCount > 1
        ? '$itemCount items'
        : (txTitle?.isNotEmpty == true ? txTitle! : txCategory);
    final sign   = (txType == 'income' || txType == 'borrow') ? '+' : '-';
    return '$actorEmoji $actorName added $txType · $label · $sign${AppPrefs.cs}${txAmount.toStringAsFixed(0)}';
  }
}
