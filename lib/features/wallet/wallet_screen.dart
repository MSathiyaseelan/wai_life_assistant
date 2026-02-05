import 'package:flutter/material.dart';
import 'package:wai_life_assistant/features/wallet/walletsummarycard.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/core/theme/app_text.dart';
import 'package:wai_life_assistant/core/widgets/screen_padding.dart';
import 'wallet_header.dart';
import 'bottomsheet/settings_bottomsheet.dart';
import 'FloatingRail/walletFloatingRail.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppText.walletTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showSettingsBottomSheet(context);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          ScreenPadding(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WalletHeader(),
                const SizedBox(height: AppSpacing.gapS),
                Row(children: const [Expanded(child: WalletSummaryCard())]),
              ],
            ),
          ),
          const WalletFloatingRail(),
        ],
      ),
    );
  }
}
