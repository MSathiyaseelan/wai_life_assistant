import 'package:flutter/material.dart';
import '../../data/models/wallet/featurelist.dart';

final Map<int, List<FeatureItem>> featuresByTab = {
  1: [
    // Wallet
    FeatureItem(title: 'Lend / Borrow', icon: Icons.add),
    FeatureItem(title: 'Request', icon: Icons.qr_code),
    FeatureItem(title: 'Split Equally', icon: Icons.equalizer),
    FeatureItem(title: 'Gift Tracker', icon: Icons.card_giftcard),
    FeatureItem(title: 'Subscriptions', icon: Icons.subscriptions),
    FeatureItem(title: 'Set Budget', icon: Icons.brunch_dining_outlined),
  ],

  2: [
    // Pantry
    FeatureItem(title: 'Diet', icon: Icons.shopping_cart),
    FeatureItem(title: 'Recipies', icon: Icons.restaurant),
    FeatureItem(title: 'Family Profile', icon: Icons.family_restroom),
  ],

  3: [
    // PlanIt
    FeatureItem(title: 'Event Planner', icon: Icons.event),
    FeatureItem(title: 'Trip Planner', icon: Icons.trip_origin),
    FeatureItem(title: 'Item Locator', icon: Icons.insert_emoticon_sharp),
    FeatureItem(title: 'To-Buy List', icon: Icons.battery_unknown_sharp),
  ],

  4: [
    // Lifestyle
    FeatureItem(title: 'Home Appliances', icon: Icons.directions_car),
    FeatureItem(title: 'Collections', icon: Icons.devices),
  ],
};
