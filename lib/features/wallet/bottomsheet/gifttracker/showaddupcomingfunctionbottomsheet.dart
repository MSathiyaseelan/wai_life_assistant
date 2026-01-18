import 'package:flutter/material.dart';
import 'package:wai_life_assistant/shared/bottom_sheets/app_bottom_sheet.dart';
import 'addupcomingfunctioncontent.dart';

void showAddUpcomingFunctionBottomSheet({required BuildContext context}) {
  showAppBottomSheet(
    context: context,
    child: const AddUpcomingFunctionContent(),
  );
}
