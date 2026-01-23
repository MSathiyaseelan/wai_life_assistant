import 'package:flutter/material.dart';
import 'package:wai_life_assistant/shared/bottom_sheets/app_bottom_sheet.dart';
import 'PlanItBottomSheetContent.dart';

void showPlanItBottomSheet(BuildContext context) {
  showAppBottomSheet(context: context, child: const PlanItBottomSheetContent());
}
