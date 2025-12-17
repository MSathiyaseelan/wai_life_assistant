import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Life Assistant")),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: const [
          FeatureCard(title: "Health"),
          FeatureCard(title: "Finance"),
          FeatureCard(title: "Tasks"),
          FeatureCard(title: "Emergency"),
        ],
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final String title;
  const FeatureCard({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Center(child: Text(title, style: const TextStyle(fontSize: 18))),
    );
  }
}
