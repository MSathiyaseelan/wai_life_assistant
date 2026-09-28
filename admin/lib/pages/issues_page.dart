import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _statuses = {'open': 'Open', 'in_progress': 'In progress', 'resolved': 'Resolved', 'closed': 'Closed'};
const _categories = {
  'bug': 'Bug',
  'crash': 'Crash',
  'feature_request': 'Feature request',
  'performance': 'Performance',
  'ui': 'UI / UX',
  'other': 'Other',
};
const _priorities = {'low': 'Low', 'medium': 'Medium', 'high': 'High'};

StatusTone _statusTone(String? s) => switch (s) {
      'open' => StatusTone.warning,
      'in_progress' => StatusTone.serious,
      'resolved' => StatusTone.good,
      _ => StatusTone.neutral,
    };

StatusTone _priorityTone(String? p) => switch (p) {
      'high' => StatusTone.critical,
      'medium' => StatusTone.warning,
      _ => StatusTone.neutral,
    };

class IssuesPage extends StatefulWidget {
  final bool canWrite;
  const IssuesPage({super.key, required this.canWrite});

  @override
  State<IssuesPage> createState() => _IssuesPageState();
}

class _IssuesPageState extends State<IssuesPage> {
  String? _status = 'open';
  String? _category;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = AdminApi.instance.issues(status: _status, category: _category, limit: 200);
  void _reload() => setState(_load);

  Future<void> _open(Map<String, dynamic> issue) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _IssueDialog(issue: issue, canWrite: widget.canWrite),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Reported issues',
      subtitle: 'Sent from the app\'s Report Issue screen. Status and reply are shown to the user under "My reports".',
      actions: [
        FilterDropdown(label: 'Status', value: _status, options: _statuses, onChanged: (v) => setState(() {
              _status = v;
              _load();
            })),
        FilterDropdown(label: 'Category', value: _category, options: _categories, onChanged: (v) => setState(() {
              _category = v;
              _load();
            })),
        IconButton(tooltip: 'Refresh', onPressed: _reload, icon: const Icon(Icons.refresh)),
      ],
      child: Loader(
        future: _future,
        onRetry: _reload,
        builder: (rows) {
          if (rows.isEmpty) return const EmptyState('No issues match these filters.');
          return TableCard(
            table: DataTable(
              showCheckboxColumn: false,
              columns: const [
                DataColumn(label: Text('Reported')),
                DataColumn(label: Text('Title')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Priority')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Reporter')),
                DataColumn(label: Text('Shots'), numeric: true),
              ],
              rows: [
                for (final r in rows)
                  DataRow(
                    onSelectChanged: (_) => _open(r),
                    cells: [
                      DataCell(Text(fmtAgo(r['created_at']))),
                      DataCell(ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 340),
                        child: Text('${r['title']}', overflow: TextOverflow.ellipsis),
                      )),
                      DataCell(Text(_categories[r['category']] ?? '${r['category']}')),
                      DataCell(StatusChip(_priorities[r['priority']] ?? '${r['priority']}', _priorityTone(r['priority']))),
                      DataCell(StatusChip(_statuses[r['status']] ?? '${r['status']}', _statusTone(r['status']))),
                      DataCell(Text('${r['reporter_name'] ?? '—'}')),
                      DataCell(Text('${(r['screenshots'] as List?)?.length ?? 0}')),
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

class _IssueDialog extends StatefulWidget {
  final Map<String, dynamic> issue;
  final bool canWrite;
  const _IssueDialog({required this.issue, required this.canWrite});

  @override
  State<_IssueDialog> createState() => _IssueDialogState();
}

class _IssueDialogState extends State<_IssueDialog> {
  late String _status = widget.issue['status'] as String? ?? 'open';
  late String _priority = widget.issue['priority'] as String? ?? 'medium';
  late final _note = TextEditingController(text: widget.issue['admin_note'] as String? ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AdminApi.instance.updateIssue(widget.issue['id'] as String,
          status: _status, priority: _priority, note: _note.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, 'Save failed: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.issue;
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final shots = List<String>.from(i['screenshots'] as List? ?? []);
    final device = Map<String, dynamic>.from(i['device_info'] as Map? ?? {});

    return AlertDialog(
      title: Text('${i['title']}'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                StatusChip(_categories[i['category']] ?? '${i['category']}', StatusTone.neutral),
                Text('by ${i['reporter_name'] ?? 'unknown'}${i['reporter_phone'] != null ? ' · ${i['reporter_phone']}' : ''}',
                    style: t.bodySmall?.copyWith(color: muted)),
                Text(fmtDateTime(i['created_at']), style: t.bodySmall?.copyWith(color: muted)),
              ]),
              const SizedBox(height: 16),
              SelectableText('${i['description']}'),
              if (shots.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final s in shots)
                    InkWell(
                      onTap: () => launchUrl(Uri.parse(s), webOnlyWindowName: '_blank'),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(s, height: 180, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(
                                width: 100, height: 180, child: Center(child: Icon(Icons.broken_image_outlined)))),
                      ),
                    ),
                ]),
              ],
              if (device.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Device', style: t.labelMedium?.copyWith(color: muted)),
                const SizedBox(height: 4),
                SelectableText(device.entries.map((e) => '${e.key}: ${e.value}').join('\n'), style: t.bodySmall),
              ],
              const Divider(height: 32),
              Wrap(spacing: 12, runSpacing: 12, children: [
                FilterDropdown(
                  label: 'Status',
                  value: _status,
                  options: _statuses,
                  allowAll: false,
                  enabled: widget.canWrite,
                  onChanged: (v) => setState(() => _status = v!),
                ),
                FilterDropdown(
                  label: 'Priority',
                  value: _priority,
                  options: _priorities,
                  allowAll: false,
                  enabled: widget.canWrite,
                  onChanged: (v) => setState(() => _priority = v!),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                enabled: widget.canWrite,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reply to user (admin note)',
                  helperText: 'Visible to the user in the app',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        if (widget.canWrite)
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
      ],
    );
  }
}
