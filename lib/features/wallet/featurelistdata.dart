import 'package:flutter/material.dart';
import '../../data/models/wallet/featurelist.dart';

final Map<int, List<FeatureItem>> featuresByTab = {
  1: [
    // Wallet
    FeatureItem(title: 'Lend / Borrow', icon: Icons.add),
    FeatureItem(title: 'Request', icon: Icons.qr_code),
    FeatureItem(title: 'Split Equally', icon: Icons.qr_code),
    FeatureItem(title: 'Gift Tracker', icon: Icons.qr_code),
    FeatureItem(title: 'Subscriptions', icon: Icons.qr_code),
    FeatureItem(title: 'Set Budget', icon: Icons.qr_code),
  ],

  2: [
    // Pantry
    FeatureItem(title: 'Diet', icon: Icons.shopping_cart),
    FeatureItem(title: 'Recipies', icon: Icons.restaurant),
    FeatureItem(title: 'Family Profile', icon: Icons.restaurant),
  ],

  3: [
    // PlanIt
    FeatureItem(title: 'Event Planner', icon: Icons.alarm),
    FeatureItem(title: 'Trip Planner', icon: Icons.check_circle),
    FeatureItem(title: 'Item Locator', icon: Icons.check_circle),
    FeatureItem(title: 'To-Buy List', icon: Icons.check_circle),
  ],

  4: [
    // Lifestyle
    FeatureItem(title: 'Home Appliances', icon: Icons.directions_car),
    FeatureItem(title: 'Collections', icon: Icons.devices),
  ],
};
