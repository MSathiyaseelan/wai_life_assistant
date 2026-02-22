import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';

class TxTile extends StatelessWidget {
  final TxModel tx;
  final VoidCallback? onTap;

  const TxTile({super.key, required this.tx, this.onTap});

  String _fmt(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : v.toStringAsFixed(0);

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
      amtColor = const Color(0xFFFF7043);
      prefix = '⏳ ';
    } else {
      amtColor = const Color(0xFFFF5C7A);
      prefix = '- ';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border(left: BorderSide(color: tx.type.color, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.18 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
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
                      // Category + type badge
                      Flexible(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                tx.category,
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
                      // Pay mode chip
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
    final isPending = type == TxType.request;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isPending ? const Color(0xFFFFF0EB) : const Color(0xFFE6FAF5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isPending ? const Color(0xFFFF7043) : const Color(0xFF00C897),
        ),
      ),
    );
  }
}
