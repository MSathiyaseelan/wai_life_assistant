import 'package:flutter/material.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/gifttracker/giftedbottomsheetcontent.dart';
import 'package:wai_life_assistant/shared/bottom_sheets/app_bottom_sheet.dart';

void showAddGiftedBottomSheet({required BuildContext context}) {
  showAppBottomSheet(context: context, child: const AddGiftedFormContent());
}
