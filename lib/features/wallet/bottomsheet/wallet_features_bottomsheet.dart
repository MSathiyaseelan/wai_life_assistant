import 'package:flutter/material.dart';
import 'package:wai_life_assistant/shared/bottom_sheets/app_bottom_sheet.dart';
import 'wallet_features_content.dart';
import '../../../data/models/wallet/featurelist.dart';

void showFeaturesBottomSheet({
  required BuildContext context,
  required List<FeatureItem> features,
}) {
  showAppBottomSheet(
    context: context,
    child: FeaturesBottomSheetContent(features: features),
  );
}
