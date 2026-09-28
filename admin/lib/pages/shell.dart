import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import 'ai_page.dart';
import 'config_page.dart';
import 'errors_page.dart';
import 'issues_page.dart';
import 'overview_page.dart';
import 'subscriptions_page.dart';
import 'users_page.dart';

class _Section {
  final String label;
  final IconData icon;
  final Widget Function(bool canWrite) page;
  const _Section(this.label, this.icon, this.page);
}

final _sections = <_Section>[
  _Section('Overview', Icons.dashboard_outlined, (_) => const OverviewPage()),
  _Section('Reported issues', Icons.bug_report_outlined, (w) => IssuesPage(canWrite: w)),
  _Section('Errors', Icons.error_outline, (w) => ErrorsPage(canWrite: w)),
  _Section('Users', Icons.people_outline, (_) => const UsersPage()),
  _Section('Subscriptions', Icons.workspace_premium_outlined, (_) => const SubscriptionsPage()),
  _Section('AI usage', Icons.auto_awesome_outlined, (_) => const AiPage()),
  _Section('App config', Icons.tune, (w) => ConfigPage(canWrite: w)),
];

/// Consoles that already have their own dashboards — linked, not duplicated.
const _projectRefs = {'dev': 'oeclczbamrnouuzooitx', 'prod': 'vighieysievrkawrvxek'};
Map<String, String> _externalLinks(String env) => {
      'Supabase': 'https://supabase.com/dashboard/project/${_projectRefs[env] ?? _projectRefs['dev']}',
      'Crashlytics': 'https://console.firebase.google.com/project/riyashome-863ea/crashlytics',
      'RevenueCat': 'https://app.revenuecat.com',
      'Play Console': 'https://play.google.com/console',
    };

class AdminShell extends StatefulWidget {
  final String env;
  final String role;
  final String email;
  final void Function(Brightness) onToggleTheme;
  const AdminShell({
    super.key,
    required this.env,
    required this.role,
    required this.email,
    required this.onToggleTheme,
  });

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  bool get _canWrite => widget.role == 'admin';

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final page = KeyedSubtree(key: ValueKey(_index), child: _sections[_index].page(_canWrite));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('RiyasHome Admin', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            _EnvBadge(env: widget.env),
          ],
        ),
        actions: [
          if (wide)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: Text('${widget.email} · ${widget.role}', style: Theme.of(context).textTheme.bodySmall)),
            ),
          IconButton(
            tooltip: 'Toggle theme',
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: () => widget.onToggleTheme(Theme.of(context).brightness),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: wide ? null : Drawer(child: _Menu(env: widget.env, index: _index, onSelect: (i) {
        Navigator.pop(context);
        _select(i);
      })),
      body: wide
          ? Row(
              children: [
                SizedBox(width: 230, child: _Menu(env: widget.env, index: _index, onSelect: _select)),
                const VerticalDivider(width: 1),
                Expanded(child: page),
              ],
            )
          : page,
    );
  }
}

class _Menu extends StatelessWidget {
  final String env;
  final int index;
  final ValueChanged<int> onSelect;
  const _Menu({required this.env, required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      children: [
        for (var i = 0; i < _sections.length; i++)
          ListTile(
            dense: true,
            selected: i == index,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            leading: Icon(_sections[i].icon, size: 20),
            title: Text(_sections[i].label),
            onTap: () => onSelect(i),
          ),
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: Text('EXTERNAL', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: muted)),
        ),
        for (final e in _externalLinks(env).entries)
          ListTile(
            dense: true,
            leading: const Icon(Icons.open_in_new, size: 18),
            title: Text(e.key),
            onTap: () => launchUrl(Uri.parse(e.value), webOnlyWindowName: '_blank'),
          ),
      ],
    );
  }
}

class _EnvBadge extends StatelessWidget {
  final String env;
  const _EnvBadge({required this.env});

  @override
  Widget build(BuildContext context) {
    final prod = env == 'prod';
    final c = (prod ? StatusTone.critical : StatusTone.good).color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: c)),
      child: Text(env.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c)),
    );
  }
}
