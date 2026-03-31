import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';

class TxTile extends StatelessWidget {
  final TxModel tx;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Accept/reject callbacks — only used for pending request transactions.
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const TxTile({
    super.key,
    required this.tx,
    this.onTap,
    this.onLongPress,
    this.onAccept,
    this.onReject,
  });

  String _fmt(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : v.toStringAsFixed(0);

  bool get _isPendingRequest =>
      tx.type == TxType.request &&
      (tx.status == null ||
          tx.status!.toLowerCase() == 'pending' ||
          tx.status!.toLowerCase() == 'requested');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1A1A2E) : Colors.white;

    Color amtColor;
    String prefix;
    if (tx.type.isPositive) {
      amtColor = const Color(0xFF00C897);
      prefix = '+ ';
    } else if (tx.type.isPending) {
      final resolvedStatus = tx.status?.toLowerCase();
      if (resolvedStatus == 'accepted') {
        amtColor = const Color(0xFF00C897);
        prefix = '✅ ';
      } else if (resolvedStatus == 'rejected') {
        amtColor = const Color(0xFF8E8EA0);
        prefix = '❌ ';
      } else {
        amtColor = const Color(0xFFFF7043);
        prefix = '⏳ ';
      }
    } else {
      amtColor = const Color(0xFFFF5C7A);
      prefix = '- ';
    }

    final showActions =
        _isPendingRequest && (onAccept != null || onReject != null);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border(left: BorderSide(color: tx.type.color, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon bubble
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: tx.type.bgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(tx.type.emoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Title (or category) + type badge
                          Flexible(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.title?.isNotEmpty == true
                                            ? tx.title!
                                            : tx.category,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          fontFamily: 'Nunito',
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1A1A2E),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (tx.title?.isNotEmpty == true)
                                        Text(
                                          tx.category,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF8E8EA0),
                                            fontFamily: 'Nunito',
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _TypeBadge(tx: tx),
                              ],
                            ),
                          ),
                          // Amount
                          Text(
                            '$prefix₹${_fmt(tx.amount)}',
                            style: TextStyle(
                              color: amtColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Sub-row
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (tx.payMode != null) _PayModeChip(mode: tx.payMode!),
                          if (tx.note != null)
                            Text(
                              tx.note!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8E8EA0),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (tx.person != null)
                            Text(
                              '· ${tx.person!}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4A9EFF),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (tx.persons != null)
                            Text(
                              tx.persons!.join(', '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4A9EFF),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (tx.status != null)
                            _StatusBadge(status: tx.status!, type: tx.type),
                          if (tx.dueDate != null)
                            Text(
                              'Due ${tx.dueDate!}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFFFAA2C),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Accept / Reject action buttons (pending requests only) ────────
            if (showActions) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (onAccept != null)
                    Expanded(
                      child: _RequestActionButton(
                        label: 'Accept',
                        emoji: '✅',
                        color: const Color(0xFF00C897),
                        onTap: onAccept!,
                      ),
                    ),
                  if (onAccept != null && onReject != null)
                    const SizedBox(width: 8),
                  if (onReject != null)
                    Expanded(
                      child: _RequestActionButton(
                        label: 'Reject',
                        emoji: '❌',
                        color: const Color(0xFFFF5C7A),
                        onTap: onReject!,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final TxModel tx;
  const _TypeBadge({required this.tx});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: tx.type.bgColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      tx.type.label.toUpperCase(),
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: tx.type.color,
        letterSpacing: 0.5,
      ),
    ),
  );
}

class _PayModeChip extends StatelessWidget {
  final PayMode mode;
  const _PayModeChip({required this.mode});
  @override
  Widget build(BuildContext context) {
    final isCash = mode == PayMode.cash;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isCash ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isCash ? '💵 Cash' : '📱 Online',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isCash ? const Color(0xFF43A047) : const Color(0xFF1E88E5),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final TxType type;
  const _StatusBadge({required this.status, required this.type});
  @override
  Widget build(BuildContext context) {
    final Color bg, fg;
    switch (status.toLowerCase()) {
      case 'accepted':
        bg = const Color(0xFFE6FAF5);
        fg = const Color(0xFF00C897);
      case 'rejected':
        bg = const Color(0xFFFFECEF);
        fg = const Color(0xFFFF5C7A);
      default:
        bg = type == TxType.request ? const Color(0xFFFFF0EB) : const Color(0xFFE6FAF5);
        fg = type == TxType.request ? const Color(0xFFFF7043) : const Color(0xFF00C897);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _RequestActionButton extends StatelessWidget {
  final String label;
  final String emoji;
  final Color color;
  final VoidCallback onTap;

  const _RequestActionButton({
    required this.label,
    required this.emoji,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
