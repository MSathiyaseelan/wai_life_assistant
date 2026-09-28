import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _severities = {'critical': 'Critical', 'error': 'Error', 'warning': 'Warning'};
const _statuses = {'new': 'New', 'acknowledged': 'Acknowledged', 'resolved': 'Resolved', 'ignored': 'Ignored'};

StatusTone _severityTone(String? s) => switch (s) {
      'critical' => StatusTone.critical,
      'error' => StatusTone.serious,
      'warning' => StatusTone.warning,
      _ => StatusTone.neutral,
    };

/// error_logs grouped by (type, message, screen, action), so a crash that
/// happened 500 times is one row. Marking a status applies to the group.
class ErrorsPage extends StatefulWidget {
  final bool canWrite;
  const ErrorsPage({super.key, required this.canWrite});

  @override
  State<ErrorsPage> createState() => _ErrorsPageState();
}

class _ErrorsPageState extends State<ErrorsPage> {
  int _days = 7;
  String? _severity;
  String? _status;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = AdminApi.instance.errorGroups(days: _days, severity: _severity, status: _status);
  void _reload() => setState(_load);

  Future<void> _open(Map<String, dynamic> g) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ErrorGroupDialog(group: g, canWrite: widget.canWrite),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Errors',
      subtitle: 'Logged by the app\'s ErrorLogger, grouped by message + screen',
      actions: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('24h')),
            ButtonSegment(value: 7, label: Text('7d')),
            ButtonSegment(value: 30, label: Text('30d')),
          ],
          selected: {_days},
          onSelectionChanged: (s) => setState(() {
            _days = s.first;
            _load();
          }),
        ),
        FilterDropdown(label: 'Severity', value: _severity, options: _severities, onChanged: (v) => setState(() {
              _severity = v;
              _load();
            })),
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
          if (rows.isEmpty) return const EmptyState('No errors in this period.');
          return TableCard(
            table: DataTable(
              showCheckboxColumn: false,
              columns: const [
                DataColumn(label: Text('Last seen')),
                DataColumn(label: Text('Severity')),
                DataColumn(label: Text('Error')),
                DataColumn(label: Text('Screen / action')),
                DataColumn(label: Text('Count'), numeric: true),
                DataColumn(label: Text('Users'), numeric: true),
                DataColumn(label: Text('New'), numeric: true),
                DataColumn(label: Text('Version')),
              ],
              rows: [
                for (final g in rows)
                  DataRow(
                    onSelectChanged: (_) => _open(g),
                    cells: [
                      DataCell(Text(fmtAgo(g['last_seen']))),
                      DataCell(StatusChip(_severities[g['severity']] ?? '${g['severity'] ?? '—'}', _severityTone(g['severity']))),
                      DataCell(ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Text(
                          '${g['error_type'] ?? ''}${g['error_type'] != null ? ': ' : ''}${g['error_message'] ?? ''}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      )),
                      DataCell(Text([g['screen_name'], g['action']].whereType<String>().join(' · '))),
                      DataCell(Text(fmtNum(g['occurrences']))),
                      DataCell(Text(fmtNum(g['users']))),
                      DataCell(Text(fmtNum(g['new_count']))),
                      DataCell(Text('${g['latest_version'] ?? '—'}')),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ErrorGroupDialog extends StatefulWidget {
  final Map<String, dynamic> group;
  final bool canWrite;
  const _ErrorGroupDialog({required this.group, required this.canWrite});

  @override
  State<_ErrorGroupDialog> createState() => _ErrorGroupDialogState();
}

class _ErrorGroupDialogState extends State<_ErrorGroupDialog> {
  late final Future<List<Map<String, dynamic>>> _future = AdminApi.instance.errorOccurrences(widget.group);
  bool _busy = false;

  Future<void> _mark(String status) async {
    setState(() => _busy = true);
    try {
      final n = await AdminApi.instance.setErrorStatus(widget.group, status);
      if (!mounted) return;
      showSnack(context, 'Marked $n occurrence${n == 1 ? '' : 's'} as ${_statuses[status]}');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, 'Update failed: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return AlertDialog(
      title: Text('${g['error_type'] ?? 'Error'}'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText('${g['error_message'] ?? ''}', style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                '${[g['screen_name'], g['action']].whereType<String>().join(' · ')}  ·  '
                '${fmtNum(g['occurrences'])} times · ${fmtNum(g['users'])} users · '
                'first ${fmtDateTime(g['first_seen'])} · last ${fmtDateTime(g['last_seen'])}',
                style: t.bodySmall?.copyWith(color: muted),
              ),
              const SizedBox(height: 16),
              Loader(
                future: _future,
                onRetry: () {},
                builder: (rows) {
                  final latest = rows.isNotEmpty ? rows.first : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (latest?['stack_trace'] != null) ...[
                        Text('Latest stack trace', style: t.labelMedium?.copyWith(color: muted)),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 220),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText('${latest!['stack_trace']}',
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text('Recent occurrences', style: t.labelMedium?.copyWith(color: muted)),
                      const SizedBox(height: 4),
                      TableCard(
                        table: DataTable(
                          columns: const [
                            DataColumn(label: Text('When')),
                            DataColumn(label: Text('User')),
                            DataColumn(label: Text('Device')),
                            DataColumn(label: Text('Version')),
                            DataColumn(label: Text('Online')),
                            DataColumn(label: Text('Status')),
                          ],
                          rows: [
                            for (final r in rows)
                              DataRow(cells: [
                                DataCell(Text(fmtDateTime(r['created_at']))),
                                DataCell(Text('${r['user_name'] ?? '—'}')),
                                DataCell(Text([r['device_model'], r['device_os'], r['os_version']].whereType<String>().join(' '))),
                                DataCell(Text('${r['app_version'] ?? ''}${r['build_number'] != null ? '+${r['build_number']}' : ''}')),
                                DataCell(Text(r['was_online'] == false ? 'No' : 'Yes')),
                                DataCell(Text(_statuses[r['status']] ?? '${r['status']}')),
                              ]),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        if (widget.canWrite) ...[
          OutlinedButton(onPressed: _busy ? null : () => _mark('ignored'), child: const Text('Ignore')),
          OutlinedButton(onPressed: _busy ? null : () => _mark('acknowledged'), child: const Text('Acknowledge')),
          FilledButton(onPressed: _busy ? null : () => _mark('resolved'), child: const Text('Mark resolved')),
        ],
      ],
    );
  }
}
