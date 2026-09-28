import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets/common.dart';

/// app_config key/values. Existing keys can be edited here; new keys are
/// added by migrations so the app code that reads them ships alongside.
class ConfigPage extends StatefulWidget {
  final bool canWrite;
  const ConfigPage({super.key, required this.canWrite});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = AdminApi.instance.config();
  void _reload() => setState(_load);

  Future<void> _edit(Map<String, dynamic> row) async {
    final ctrl = TextEditingController(text: '${row['value'] ?? ''}');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: SelectableText('${row['key']}'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (row['description'] != null) ...[
                Text('${row['description']}'),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: null,
                decoration: const InputDecoration(labelText: 'Value', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Text('Apps pick up the new value the next time they start.',
                  style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (value == null || value == row['value']) return;
    try {
      await AdminApi.instance.setConfig(row['key'] as String, value);
      if (!mounted) return;
      showSnack(context, 'Updated ${row['key']}');
      _reload();
    } catch (e) {
      if (mounted) showSnack(context, 'Update failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'App config',
      subtitle: widget.canWrite
          ? 'Live settings read by the app (app_config). Click a row to edit.'
          : 'Live settings read by the app (app_config). Read-only for viewers.',
      actions: [IconButton(tooltip: 'Refresh', onPressed: _reload, icon: const Icon(Icons.refresh))],
      child: Loader(
        future: _future,
        onRetry: _reload,
        builder: (rows) {
          if (rows.isEmpty) return const EmptyState('No config keys.');
          return TableCard(
            table: DataTable(
              showCheckboxColumn: false,
              dataRowMaxHeight: 72,
              columns: const [
                DataColumn(label: Text('Key')),
                DataColumn(label: Text('Value')),
                DataColumn(label: Text('Description')),
              ],
              rows: [
                for (final r in rows)
                  DataRow(
                    onSelectChanged: widget.canWrite ? (_) => _edit(r) : null,
                    cells: [
                      DataCell(Text('${r['key']}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                      DataCell(ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Text('${r['value'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis),
                      )),
                      DataCell(ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Text('${r['description'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis),
                      )),
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
