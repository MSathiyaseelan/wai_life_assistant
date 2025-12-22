import 'package:flutter/material.dart';
import '../../data/models/wallet/featurelist.dart';

final Map<int, List<FeatureItem>> featuresByTab = {
  1: [
    // Wallet
    FeatureItem(title: 'Add Transaction', icon: Icons.add),
    FeatureItem(title: 'Scan Receipt', icon: Icons.qr_code),
  ],

  2: [
    // Pantry
    FeatureItem(title: 'Add Grocery', icon: Icons.shopping_cart),
    FeatureItem(title: 'Meal Planner', icon: Icons.restaurant),
  ],

  3: [
    // PlanIt
    FeatureItem(title: 'Create Reminder', icon: Icons.alarm),
    FeatureItem(title: 'New Todo', icon: Icons.check_circle),
  ],

  4: [
    // Lifestyle
    FeatureItem(title: 'Add Vehicle', icon: Icons.directions_car),
    FeatureItem(title: 'Track Gadgets', icon: Icons.devices),
  ],
};
