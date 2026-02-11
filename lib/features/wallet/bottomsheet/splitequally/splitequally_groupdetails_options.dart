import 'package:flutter/material.dart';
import 'package:wai_life_assistant/shared/bottom_sheets/app_bottom_sheet.dart';
import 'group_options_bottomsheet_content.dart';
import 'package:wai_life_assistant/data/models/wallet/SplitGroup.dart';

void showGroupOptionsBottomSheet({
  required BuildContext context,
  required SplitGroup group,
}) {
  showAppBottomSheet(
    context: context,
    child: GroupOptionsBottomSheetContent(group: group),
  );
}
