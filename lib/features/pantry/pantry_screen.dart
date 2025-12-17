import 'package:flutter/material.dart';

class PantryScreen extends StatelessWidget {
  const PantryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pantry")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
            const SizedBox(height: 12),
            const Text(
              "Sathiya",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _profileItem(Icons.settings, "Settings"),
            _profileItem(Icons.lock, "Privacy"),
            _profileItem(Icons.help, "Help & Support"),
            _profileItem(Icons.logout, "Logout"),
          ],
        ),
      ),
    );
  }

  Widget _profileItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }
}
