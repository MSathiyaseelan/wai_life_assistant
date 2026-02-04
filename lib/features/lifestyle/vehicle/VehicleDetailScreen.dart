import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyleItem.dart';
import 'package:wai_life_assistant/features/lifestyle/vehicle/VehicleBasicDetailsScreen.dart';
import 'package:wai_life_assistant/features/lifestyle/vehicle/VehicleIdentityDetailsScreen.dart';
import 'package:wai_life_assistant/features/lifestyle/vehicle/VehiclePolicyDetailsScreen.dart';

class VehicleDetailScreen extends StatelessWidget {
  final LifestyleItem vehicle;

  const VehicleDetailScreen({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(vehicle.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            _VehicleOptionCard(
              title: 'Basic Details',
              icon: Icons.info_outline,
              vehicle: vehicle,
            ),
            _VehicleOptionCard(
              title: 'Identity Details',
              icon: Icons.badge_outlined,
              vehicle: vehicle,
            ),
            _VehicleOptionCard(
              title: 'Policy Details',
              icon: Icons.policy_outlined,
              vehicle: vehicle,
            ),
            _VehicleOptionCard(
              title: 'Service & Maintenance',
              icon: Icons.build_outlined,
              vehicle: vehicle,
            ),
            _VehicleOptionCard(
              title: 'Repair / Planned Work',
              icon: Icons.handyman_outlined,
              vehicle: vehicle,
            ),
            _VehicleOptionCard(
              title: 'Expense Tracking',
              icon: Icons.payments_outlined,
              vehicle: vehicle,
            ),
            _VehicleOptionCard(
              title: 'Reminders',
              icon: Icons.notifications_outlined,
              vehicle: vehicle,
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleOptionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final LifestyleItem vehicle; // 👈 ADD THIS

  const _VehicleOptionCard({
    required this.title,
    required this.icon,
    required this.vehicle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        _handleTap(context);
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 28,
                color: Theme.of(context).colorScheme.primary,
              ),
              const Spacer(),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    if (title == 'Basic Details') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VehicleBasicDetailsScreen(vehicle: vehicle),
        ),
      );
    } else if (title == 'Identity Details') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VehicleIdentityDetailsScreen(vehicle: vehicle),
        ),
      );
    }
    //else if (title == 'Policy Details') {
    //   Navigator.push(
    //     context,
    //     MaterialPageRoute(
    //       builder: (_) => VehiclePolicyDetailsScreen(vehicle: vehicle),
    //     ),
    //   );
    // }
  }
}
