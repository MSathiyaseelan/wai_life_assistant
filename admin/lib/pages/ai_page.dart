import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets/common.dart';

class AiPage extends StatefulWidget {
  const AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  int _days = 7;
  late Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = () async {
        final r = await Future.wait([AdminApi.instance.aiStats(_days), AdminApi.instance.aiRecentErrors()]);
        return (r[0], r[1]);
      }();
  void _reload() => setState(_load);

  String _pct(dynamic part, dynamic whole) {
    final w = (whole as num?) ?? 0;
    if (w == 0) return '—';
    return '${(((part as num?) ?? 0) / w * 100).toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'AI usage',
      subtitle: 'From ai_parse_logs — every AI parse the app makes',
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
        IconButton(tooltip: 'Refresh', onPressed: _reload, icon: const Icon(Icons.refresh)),
      ],
      child: Loader(
        future: _future,
        onRetry: _reload,
        builder: (data) {
          final (stats, errors) = data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stats.isEmpty)
                const EmptyState('No AI calls in this period.')
              else
                TableCard(
                  table: DataTable(
                    columns: const [
                      DataColumn(label: Text('Feature')),
                      DataColumn(label: Text('Calls'), numeric: true),
                      DataColumn(label: Text('Failed'), numeric: true),
                      DataColumn(label: Text('Corrected by user'), numeric: true),
                      DataColumn(label: Text('Users'), numeric: true),
                      DataColumn(label: Text('Avg latency'), numeric: true),
                      DataColumn(label: Text('Avg confidence'), numeric: true),
                      DataColumn(label: Text('Tokens'), numeric: true),
                    ],
                    rows: [
                      for (final s in stats)
                        DataRow(cells: [
                          DataCell(Text([s['feature'], s['sub_feature']].whereType<String>().join(' · '))),
                          DataCell(Text(fmtNum(s['calls']))),
                          DataCell(Text('${fmtNum(s['errors'])} (${_pct(s['errors'], s['calls'])})')),
                          DataCell(Text('${fmtNum(s['corrected'])} (${_pct(s['corrected'], s['calls'])})')),
                          DataCell(Text(fmtNum(s['users']))),
                          DataCell(Text(s['avg_latency_ms'] == null ? '—' : '${fmtNum(s['avg_latency_ms'])} ms')),
                          DataCell(Text('${s['avg_confidence'] ?? '—'}')),
                          DataCell(Text(fmtNum(s['tokens']))),
                        ]),
                    ],
                  ),
                ),
              const SectionTitle('Recent failures'),
              if (errors.isEmpty)
                const EmptyState('No failed AI calls.')
              else
                TableCard(
                  table: DataTable(
                    dataRowMaxHeight: 72,
                    columns: const [
                      DataColumn(label: Text('When')),
                      DataColumn(label: Text('Feature')),
                      DataColumn(label: Text('User')),
                      DataColumn(label: Text('Input')),
                      DataColumn(label: Text('Error')),
                    ],
                    rows: [
                      for (final e in errors)
                        DataRow(cells: [
                          DataCell(Text(fmtAgo(e['created_at']))),
                          DataCell(Text([e['feature'], e['sub_feature']].whereType<String>().join(' · '))),
                          DataCell(Text('${e['user_name'] ?? '—'}')),
                          DataCell(ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: Tooltip(
                              message: '${e['raw_input'] ?? ''}',
                              child: Text('${e['raw_input'] ?? '—'}', maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          )),
                          DataCell(ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Tooltip(
                              message: '${e['error'] ?? ''}',
                              child: Text('${e['error']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          )),
                        ]),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
