import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/supabase/notification_service.dart';
import 'package:wai_life_assistant/data/models/notification/notification_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION SHEET
// Shows family transaction notifications for the current user.
// ─────────────────────────────────────────────────────────────────────────────

class NotificationSheet extends StatefulWidget {
  final bool isDark;

  const NotificationSheet({super.key, required this.isDark});

  @override
  State<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<NotificationSheet> {
  List<AppNotification> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await NotificationService.instance.fetchAll();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
    // Mark all as read once the sheet is open
    if (items.any((n) => !n.isRead)) {
      await NotificationService.instance.markAllRead();
      if (mounted) {
        setState(() {
          _items = _items.map((n) => n.copyWith(isRead: true)).toList();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg  = isDark ? AppColors.cardDark  : AppColors.cardLight;
    final tc  = isDark ? AppColors.textDark  : AppColors.textLight;
    final sub = isDark ? AppColors.subDark   : AppColors.subLight;
    final surf = isDark ? AppColors.surfDark : AppColors.bgLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: sub.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 17,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    color: tc,
                  ),
                ),
                const Spacer(),
                if (_items.any((n) => !n.isRead))
                  GestureDetector(
                    onTap: () async {
                      await NotificationService.instance.markAllRead();
                      if (mounted) {
                        setState(() {
                          _items = _items.map((n) => n.copyWith(isRead: true)).toList();
                        });
                      }
                    },
                    child: Text(
                      'Mark all read',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // List
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _items.isEmpty
                    ? _buildEmpty(tc, sub)
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 32),
                        shrinkWrap: true,
                        itemCount: _items.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: sub.withAlpha(40)),
                        itemBuilder: (_, i) =>
                            _NotifTile(n: _items[i], isDark: isDark, surf: surf, tc: tc, sub: sub),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(Color tc, Color sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 52),
      child: Column(
        children: [
          Icon(Icons.notifications_none_rounded, size: 48, color: sub.withAlpha(120)),
          const SizedBox(height: 12),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 15,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              color: tc,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Family transactions will appear here',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Nunito',
              color: sub,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single notification tile
// ─────────────────────────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final AppNotification n;
  final bool isDark;
  final Color surf;
  final Color tc;
  final Color sub;

  const _NotifTile({
    required this.n,
    required this.isDark,
    required this.surf,
    required this.tc,
    required this.sub,
  });

  Color _typeColor(String type) {
    switch (type) {
      case 'income':   return AppColors.income;
      case 'expense':  return AppColors.expense;
      case 'split':    return AppColors.split;
      case 'lend':     return AppColors.lend;
      case 'borrow':   return AppColors.borrow;
      case 'request':  return AppColors.request;
      case 'returned': return AppColors.returned;
      default:         return AppColors.primary;
    }
  }

  String _amountPrefix(String type) {
    return (type == 'income' || type == 'borrow') ? '+' : '-';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays < 7)     return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(n.txType);
    final prefix = _amountPrefix(n.txType);
    final label = n.txTitle?.isNotEmpty == true ? n.txTitle! : n.txCategory;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                n.actorEmoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        n.actorName.isNotEmpty ? n.actorName : 'Family member',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          color: tc,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Amount chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withAlpha(24),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$prefix₹${n.txAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Added ${n.txType} · $label',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Nunito',
                    color: sub,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _timeAgo(n.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Nunito',
                    color: sub.withAlpha(160),
                  ),
                ),
              ],
            ),
          ),

          // Unread dot
          if (!n.isRead)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
