import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _statuses = {'active': 'Active', 'trialing': 'Trialing', 'expired': 'Expired', 'cancelled': 'Cancelled'};

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  String? _status;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = AdminApi.instance.subscriptions(status: _status);
  void _reload() => setState(_load);

  /// Lapsing = active, auto-renew off, expiring within 7 days.
  (String, StatusTone) _state(Map<String, dynamic> s) {
    final status = s['status'] as String?;
    final expires = DateTime.tryParse('${s['expires_at']}');
    final days = expires?.difference(DateTime.now()).inDays;
    if (status == 'active' && s['auto_renew'] == false && days != null && days <= 7) {
      return ('Lapsing · ${days < 0 ? 0 : days}d', StatusTone.warning);
    }
    return switch (status) {
      'active' => ('Active', StatusTone.good),
      'trialing' => ('Trialing', StatusTone.good),
      'expired' => ('Expired', StatusTone.neutral),
      _ => (status ?? '—', StatusTone.neutral),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Subscriptions',
      subtitle: 'wallet_subscriptions, soonest expiry first. Billing detail lives in RevenueCat.',
      actions: [
        FilterDropdown(label: 'Status', value: _status, options: _statuses, onChanged: (v) => setState(() {
              _status = v;
              _load();
            })),
        IconButton(tooltip: 'Refresh', onPressed: _reload, icon: const Icon(Icons.refresh)),
      ],
      child: Loader(
        future: _future,
        onRetry: _reload,
        builder: (rows) {
          if (rows.isEmpty) return const EmptyState('No subscriptions match.');
          return TableCard(
            table: DataTable(
              columns: const [
                DataColumn(label: Text('Owner')),
                DataColumn(label: Text('Wallet')),
                DataColumn(label: Text('Plan')),
                DataColumn(label: Text('State')),
                DataColumn(label: Text('Auto-renew')),
                DataColumn(label: Text('Started')),
                DataColumn(label: Text('Expires')),
                DataColumn(label: Text('Trial ends')),
                DataColumn(label: Text('Payment ref')),
              ],
              rows: [
                for (final s in rows)
                  DataRow(cells: [
                    DataCell(Text('${s['owner_name'] ?? '—'}${s['owner_phone'] != null ? '\n${s['owner_phone']}' : ''}')),
                    DataCell(Text('${s['wallet_name'] ?? '—'}${s['is_personal'] == true ? ' (personal)' : ''}')),
                    DataCell(Text('${s['plan_name'] ?? s['plan_key'] ?? '—'}')),
                    DataCell(Builder(builder: (_) {
                      final st = _state(s);
                      return StatusChip(st.$1, st.$2);
                    })),
                    DataCell(Text(s['auto_renew'] == true ? 'On' : 'Off')),
                    DataCell(Text(fmtDate(s['started_at']))),
                    DataCell(Text(fmtDate(s['expires_at']))),
                    DataCell(Text(fmtDate(s['trial_ends_at']))),
                    DataCell(SelectableText('${s['payment_reference'] ?? '—'}')),
                  ]),
              ],
            ),
          );
        },
      ),
    );
  }
}
