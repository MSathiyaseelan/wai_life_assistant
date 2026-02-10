import 'package:flutter/material.dart';
import 'package:wai_life_assistant/features/wallet/walletsummarycard.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/core/theme/app_text.dart';
import 'package:wai_life_assistant/core/widgets/screen_padding.dart';
import 'FloatingRail/walletFloatingRail.dart';
import 'package:wai_life_assistant/data/enum/wallet_enums.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/wallet_transaction_bottom_sheet.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/wallet_features_bottomsheet.dart';
import 'featurelistdata.dart';
import 'package:flutter/services.dart';
import 'AI/showSparkBottomSheet.dart';
import 'package:wai_life_assistant/data/models/wallet/WalletTransaction.dart';
import 'WalletTransactionCard.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool showCash = false;
  bool showUpi = false;

  final List<WalletTransaction> _transactions = [];

  void _toggleCash() {
    HapticFeedback.lightImpact();
    setState(() {
      showCash = !showCash;
      showUpi = false;
    });
  }

  void _toggleUpi() {
    HapticFeedback.lightImpact();
    setState(() {
      showUpi = !showUpi;
      showCash = false;
    });
  }

  void _collapseRail() {
    if (showCash || showUpi) {
      setState(() {
        showCash = false;
        showUpi = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppText.walletTitle)),
      body: Stack(
        children: [
          ScreenPadding(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Expanded(child: WalletSummaryCard())]),

                const SizedBox(height: AppSpacing.gapL),

                Expanded(
                  child: ListView.builder(
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      return WalletTransactionCard(
                        transaction: _transactions[index],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 👇 THIS is where outside tap handling lives
          if (showCash || showUpi)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _collapseRail,
                child: const SizedBox.expand(),
              ),
            ),

          // Floating rail always on top
          WalletFloatingRail(
            showCash: showCash,
            showUpi: showUpi,
            onCashTap: _toggleCash,
            onUpiTap: _toggleUpi,
            onCollapse: _collapseRail,
            onSparkTap: () async {
              final intent = await showSparkBottomSheet(context);

              if (intent == null) return;

              final transaction = WalletTransaction(
                walletType: WalletType.cash, // intent.walletType, // cash / upi
                action: WalletAction
                    .decrement, // intent.action, // increment / decrement
                amount: intent.amount,
                purpose: intent.purpose.toString(),
                category: intent.category.toString(),
                //notes: intent.notes,
              );

              setState(() {
                _transactions.insert(0, transaction);
              });
            },

            //onSparkTap: () => showSparkBottomSheet(context),
            // onCashAdd: () => showWalletTransactionBottomSheet(
            //   context: context,
            //   walletType: WalletType.cash,
            //   action: WalletAction.increment,
            // ),
            onCashAdd: () async {
              final result = await showWalletTransactionBottomSheet(
                context: context,
                walletType: WalletType.cash,
                action: WalletAction.increment,
              );

              if (result != null) {
                setState(() {
                  _transactions.insert(0, result);
                });
              }
            },
            onCashRemove: () async {
              final result = await showWalletTransactionBottomSheet(
                context: context,
                walletType: WalletType.cash,
                action: WalletAction.decrement,
              );

              if (result != null) {
                setState(() {
                  _transactions.insert(0, result);
                });
              }
            },
            onUpiAdd: () async {
              final result = await showWalletTransactionBottomSheet(
                context: context,
                walletType: WalletType.upi,
                action: WalletAction.increment,
              );

              if (result != null) {
                setState(() {
                  _transactions.insert(0, result);
                });
              }
            },
            onUpiRemove: () async {
              final result = await showWalletTransactionBottomSheet(
                context: context,
                walletType: WalletType.upi,
                action: WalletAction.decrement,
              );

              if (result != null) {
                setState(() {
                  _transactions.insert(0, result);
                });
              }
            },
            onMoreTap: () => showFeaturesBottomSheet(
              context: context,
              features: featuresByTab[1] ?? [],
            ),
          ),
        ],
      ),
    );
  }
}
