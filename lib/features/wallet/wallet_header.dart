import 'package:flutter/material.dart';
import 'package:wai_life_assistant/features/wallet/userlist.dart';
import 'package:wai_life_assistant/shared/calendar/customcalendar.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';

class WalletHeader extends StatelessWidget {
  const WalletHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(flex: 2, child: UsersList()),
        SizedBox(width: AppSpacing.gapS),
        Expanded(flex: 3, child: DayNavigator()),
      ],
    );
  }
}
