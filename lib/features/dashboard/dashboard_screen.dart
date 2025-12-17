import 'package:flutter/material.dart';
import 'widgets/greeting_header.dart';
import 'widgets/search_bar.dart';
import 'widgets/feature_card.dart';
import 'widgets/quick_stats.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GreetingHeader(),
              const SizedBox(height: 20),
              const HomeSearchBar(),
              const SizedBox(height: 20),
              const QuickStats(),
              const SizedBox(height: 24),
              const Text(
                "Services",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    FeatureCard(
                      title: "Health",
                      icon: Icons.favorite,
                      color: Colors.red,
                      onTap: () {},
                    ),
                    FeatureCard(
                      title: "Finance",
                      icon: Icons.account_balance,
                      color: Colors.green,
                      onTap: () {},
                    ),
                    FeatureCard(
                      title: "Tasks",
                      icon: Icons.check_circle,
                      color: Colors.blue,
                      onTap: () {},
                    ),
                    FeatureCard(
                      title: "Emergency",
                      icon: Icons.warning,
                      color: Colors.orange,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
