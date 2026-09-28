import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api.dart';
import 'pages/login_page.dart';
import 'pages/shell.dart';
import 'theme.dart';

// Same env files as the mobile app:
//   flutter run -d chrome --dart-define-from-file=../env/dev.json
const _env = String.fromEnvironment('ENV', defaultValue: 'dev');
const _url = String.fromEnvironment('SUPABASE_URL');
const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_url.isEmpty || _anonKey.isEmpty) {
    runApp(const _MissingConfigApp());
    return;
  }
  await Supabase.initialize(url: _url, publishableKey: _anonKey);
  runApp(const AdminApp());
}

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  ThemeMode _mode = ThemeMode.system;

  void _toggleTheme(Brightness current) => setState(() =>
      _mode = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RiyasHome Admin',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.light(),
      darkTheme: AdminTheme.dark(),
      themeMode: _mode,
      home: _AuthGate(env: _env, onToggleTheme: _toggleTheme),
    );
  }
}

/// Signed out → login. Signed in → checks dashboard_admins via
/// admin_whoami(); a signed-in account that isn't an admin is shown a
/// "no access" screen rather than the dashboard.
class _AuthGate extends StatelessWidget {
  final String env;
  final void Function(Brightness) onToggleTheme;
  const _AuthGate({required this.env, required this.onToggleTheme});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) {
        final user = auth.currentUser;
        if (user == null) return LoginPage(env: env);
        return FutureBuilder<String?>(
          key: ValueKey(user.id),
          future: AdminApi.instance.whoami(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final role = snap.data;
            if (snap.hasError || role == null) {
              return _NoAccess(email: user.email, error: snap.error);
            }
            return AdminShell(
              env: env,
              role: role,
              email: user.email ?? '',
              onToggleTheme: onToggleTheme,
            );
          },
        );
      },
    );
  }
}

class _NoAccess extends StatelessWidget {
  final String? email;
  final Object? error;
  const _NoAccess({this.email, this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 40),
                const SizedBox(height: 12),
                Text('No dashboard access',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  error != null
                      ? 'Could not check access: $error'
                      : '${email ?? 'This account'} is not in dashboard_admins.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: SelectableText(
              'Missing SUPABASE_URL / SUPABASE_ANON_KEY.\n\n'
              'Run with: flutter run -d chrome --dart-define-from-file=../env/dev.json',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
