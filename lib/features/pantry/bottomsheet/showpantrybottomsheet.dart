import 'package:flutter/material.dart';
import 'package:wai_life_assistant/shared/bottom_sheets/app_bottom_sheet.dart';
import 'pantrybottomsheetcontent.dart';

void showPantryBottomSheet(BuildContext context) {
  showAppBottomSheet(context: context, child: const PantryBottomSheetContent());
}
