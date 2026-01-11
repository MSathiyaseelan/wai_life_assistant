import 'package:flutter/material.dart';
import '../../data/models/wallet/featurelist.dart';
import 'features/lend.dart';
import 'features/borrow.dart';

final Map<int, List<FeatureItem>> featuresByTab = {
  1: [
    // Wallet
    FeatureItem(
      title: 'Borrow',
      icon: Icons.add,
      pageBuilder: (_) => const BorrowPage(title: 'Borrow'),
    ),
    FeatureItem(
      title: 'Lend',
      icon: Icons.add,
      pageBuilder: (_) => const LendPage(title: 'Lend'),
    ),
    FeatureItem(
      title: 'Request',
      icon: Icons.qr_code,
      pageBuilder: (_) => const LendPage(title: 'Request'), //RequestPage(),
    ),
    FeatureItem(
      title: 'Split Equally',
      icon: Icons.equalizer,
      pageBuilder: (_) =>
          const LendPage(title: 'Split Equally'), //SplitEquallyPage(),
    ),
    FeatureItem(
      title: 'Gift Tracker',
      icon: Icons.card_giftcard,
      pageBuilder: (_) =>
          const LendPage(title: 'Gift Tracker'), //GiftTrackerPage(),
    ),
    FeatureItem(
      title: 'Subscriptions',
      icon: Icons.subscriptions,
      pageBuilder: (_) =>
          const LendPage(title: 'Subscriptions'), //SubscriptionsPage(),
    ),
    FeatureItem(
      title: 'Set Budget',
      icon: Icons.brunch_dining_outlined,
      pageBuilder: (_) =>
          const LendPage(title: 'Set Budget'), //SetBudgetPage(),
    ),
  ],

  2: [
    // Pantry
    FeatureItem(
      title: 'Diet',
      icon: Icons.shopping_cart,
      pageBuilder: (_) => const LendPage(title: 'Diet'),
    ),
    FeatureItem(
      title: 'Recipies',
      icon: Icons.restaurant,
      pageBuilder: (_) => const LendPage(title: 'Recipies'),
    ),
    FeatureItem(
      title: 'Family Profile',
      icon: Icons.family_restroom,
      pageBuilder: (_) => const LendPage(title: 'Family Profile'),
    ),
  ],

  3: [
    // PlanIt
    FeatureItem(
      title: 'Event Planner',
      icon: Icons.event,
      pageBuilder: (_) => const LendPage(title: 'Event Planner'),
    ),
    FeatureItem(
      title: 'Trip Planner',
      icon: Icons.trip_origin,
      pageBuilder: (_) => const LendPage(title: 'Trip Planner'),
    ),
    FeatureItem(
      title: 'Item Locator',
      icon: Icons.insert_emoticon_sharp,
      pageBuilder: (_) => const LendPage(title: 'Item Locator'),
    ),
    FeatureItem(
      title: 'To-Buy List',
      icon: Icons.battery_unknown_sharp,
      pageBuilder: (_) => const LendPage(title: 'To-Buy List'),
    ),
  ],

  4: [
    // Lifestyle
    FeatureItem(
      title: 'Home Appliances',
      icon: Icons.directions_car,
      pageBuilder: (_) => const LendPage(title: 'Home Appliances'),
    ),
    FeatureItem(
      title: 'Collections',
      icon: Icons.devices,
      pageBuilder: (_) => const LendPage(title: 'Collections'),
    ),
  ],
};
