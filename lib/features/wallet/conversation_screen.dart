import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/data/models/wallet/flow_models.dart';
import 'conversation_flow.dart';

/// Full-screen page that wraps [ConversationFlow].
/// Push this with Navigator.push from the wallet screen.
class ConversationScreen extends StatelessWidget {
  final FlowType flowType;
  final String walletId;
  final void Function(TxModel tx) onComplete;

  const ConversationScreen({
    super.key,
    required this.flowType,
    required this.walletId,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(flowType.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flowType.label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                  ),
                ),
                Text(
                  'Conversation Flow',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Nunito',
                    color: isDark ? AppColors.subDark : AppColors.subLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: ConversationFlow(
        flowType: flowType,
        walletId: walletId,
        onComplete: (tx) {
          onComplete(tx);
          // Pop back after a short delay so user sees the success card
          Future.delayed(const Duration(milliseconds: 1800), () {
            if (context.mounted) Navigator.pop(context);
          });
        },
      ),
    );
  }
}
