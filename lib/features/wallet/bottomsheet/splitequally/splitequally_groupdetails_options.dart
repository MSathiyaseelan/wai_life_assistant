import 'package:flutter/material.dart';
import 'package:wai_life_assistant/shared/bottom_sheets/app_bottom_sheet.dart';
import 'package:wai_life_assistant/features/wallet/features/splitequally.dart';
import 'group_options_bottomsheet_content.dart';

void showGroupOptionsBottomSheet({
  required BuildContext context,
  required SplitGroup group,
}) {
  showAppBottomSheet(
    context: context,
    child: GroupOptionsBottomSheetContent(group: group),
  );
}
