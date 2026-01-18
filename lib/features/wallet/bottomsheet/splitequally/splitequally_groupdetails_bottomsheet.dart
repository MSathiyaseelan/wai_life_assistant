import 'package:flutter/material.dart';
import 'package:wai_life_assistant/shared/bottom_sheets/app_bottom_sheet.dart';
import 'splitequally_bottomsheet_content.dart';
import 'splitequally_groupdetails_bottomsheet_content.dart';

void splitEquallyGroupDetailsBottomSheet({required BuildContext context}) {
  showAppBottomSheet(context: context, child: const SplitEquallyFormContent());
}

void showAddSpendBottomSheet({
  required BuildContext context,
  required List<String> participants,
}) {
  showAppBottomSheet(
    context: context,
    child: AddSpendFormContent(participants: participants),
  );
}
