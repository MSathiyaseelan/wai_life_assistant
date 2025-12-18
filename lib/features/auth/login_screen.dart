import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(decoration: InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, AppRoutes.bottomNav);
              },
              child: const Text("Login"),
            ),
          ],
        ),
      ),
    );
  }
}


// Example of how to use AuthRepository in a login function
// try {
//   await authRepo.login(email, password);
// } on ApiException catch (e) {
//   ScaffoldMessenger.of(context).showSnackBar(
//     SnackBar(content: Text(e.message)),
//   );
// }

