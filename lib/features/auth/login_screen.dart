import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login', style: AppTextStyles.subtitle)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Welcome Back', style: AppTextStyles.title),

            const SizedBox(height: AppSpacing.sm),

            Text('Please login to continue', style: AppTextStyles.body),

            const SizedBox(height: AppSpacing.lg),

            // Email
            TextField(decoration: const InputDecoration(labelText: 'Email')),

            const SizedBox(height: AppSpacing.md),

            // Password
            TextField(
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),

            const SizedBox(height: AppSpacing.xl),

            // Login Button
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, AppRoutes.bottomNav);
              },
              child: const Text('Login'),
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

