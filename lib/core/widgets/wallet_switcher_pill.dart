import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/core/widgets/emoji_or_image.dart';

/// Consistent wallet switcher pill used in Wallet, Pantry, PlanIt and MyLife
/// AppBar actions. Tapping opens the family switcher sheet.
class WalletSwitcherPill extends StatelessWidget {
  final WalletModel wallet;
  final VoidCallback onTap;

  const WalletSwitcherPill({
    super.key,
    required this.wallet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: wallet.gradient),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmojiOrImage(value: wallet.emoji, size: 18, borderRadius: 4),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 90),
              child: Text(
                wallet.name,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  fontFamily: 'Nunito',
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}
