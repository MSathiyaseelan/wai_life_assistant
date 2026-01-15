import 'package:flutter/material.dart';
import 'package:wai_life_assistant/shared/bottom_sheets/app_bottom_sheet.dart';
import 'lend_bottomsheet_content.dart';

void showAddLendBottomSheet({required BuildContext context}) {
  showAppBottomSheet(context: context, child: const LendFormContent());
}
