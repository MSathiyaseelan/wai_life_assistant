import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/daily_bar_chart.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  int _days = 30;
  bool _asTable = false;
  late Future<(Map<String, dynamic>, List<Map<String, dynamic>>)> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = () async {
        final r = await Future.wait([AdminApi.instance.overview(), AdminApi.instance.dailySeries(_days)]);
        return (r[0] as Map<String, dynamic>, r[1] as List<Map<String, dynamic>>);
      }();

  void _reload() => setState(_load);

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Overview',
      subtitle: 'Key numbers across the app',
      actions: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7d')),
            ButtonSegment(value: 30, label: Text('30d')),
            ButtonSegment(value: 90, label: Text('90d')),
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
        builder: (data) => _body(context, data.$1, data.$2),
      ),
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> o, List<Map<String, dynamic>> series) {
    Map<String, dynamic> m(String k) => Map<String, dynamic>.from(o[k] as Map? ?? {});
    final users = m('users'), subs = m('subscriptions'), issues = m('issues'), errors = m('errors'), ai = m('ai');
    final plans = m('plans');
    final subsByStatus = Map<String, dynamic>.from(subs['by_status'] as Map? ?? {});
    int n(dynamic v) => (v as num?)?.toInt() ?? 0;

    final openIssues = n(issues['open']) + n(issues['in_progress']);
    final aiCalls = n(ai['calls_24h']);
    final aiErrRate = aiCalls == 0 ? 0 : n(ai['errors_24h']) / aiCalls;

    List<(DateTime, num)> pts(String key) => [
          for (final r in series) (DateTime.parse(r['day'] as String), (r[key] as num?) ?? 0),
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Users'),
        Wrap(spacing: 12, runSpacing: 12, children: [
          StatTile(label: 'Total users', value: fmtNum(users['total']), caption: '${fmtNum(users['onboarded'])} onboarded'),
          StatTile(label: 'New · 7 days', value: fmtNum(users['new_7d'])),
          StatTile(label: 'New · 30 days', value: fmtNum(users['new_30d'])),
        ]),
        const SectionTitle('Subscriptions'),
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final e in plans.entries) StatTile(label: 'Active · ${e.key}', value: fmtNum(e.value)),
          if (plans.isEmpty) const StatTile(label: 'Active paid plans', value: '0'),
          StatTile(label: 'Trialing', value: fmtNum(subsByStatus['trialing'] ?? 0)),
          StatTile(
            label: 'Lapsing in 7 days',
            value: fmtNum(subs['lapsing_7d']),
            caption: 'Auto-renew off',
            tone: n(subs['lapsing_7d']) > 0 ? StatusTone.warning : null,
          ),
          StatTile(label: 'Trials ending · 7d', value: fmtNum(subs['trials_ending_7d'])),
        ]),
        const SectionTitle('Health'),
        Wrap(spacing: 12, runSpacing: 12, children: [
          StatTile(
            label: 'Open reported issues',
            value: fmtNum(openIssues),
            caption: '${fmtNum(issues['in_progress'] ?? 0)} in progress',
            tone: openIssues > 0 ? StatusTone.warning : StatusTone.good,
          ),
          StatTile(label: 'Errors · 24h', value: fmtNum(errors['last_24h']), caption: '${fmtNum(errors['last_7d'])} in 7 days'),
          StatTile(
            label: 'Critical errors · 7d',
            value: fmtNum(errors['critical_7d']),
            tone: n(errors['critical_7d']) > 0 ? StatusTone.critical : StatusTone.good,
          ),
          StatTile(label: 'Users hit errors · 7d', value: fmtNum(errors['users_7d'])),
          StatTile(
            label: 'AI calls · 24h',
            value: fmtNum(aiCalls),
            caption: '${(aiErrRate * 100).toStringAsFixed(1)}% failed · ${fmtNum(ai['avg_latency_ms_7d'])} ms avg',
            tone: aiErrRate > 0.1 ? StatusTone.serious : null,
          ),
          StatTile(label: 'AI tokens · 7d', value: fmtNum(ai['tokens_7d'])),
        ]),
        Row(
          children: [
            const Expanded(child: SectionTitle('Daily activity')),
            TextButton.icon(
              onPressed: () => setState(() => _asTable = !_asTable),
              icon: Icon(_asTable ? Icons.bar_chart : Icons.table_rows_outlined, size: 18),
              label: Text(_asTable ? 'Show charts' : 'Show table'),
            ),
          ],
        ),
        if (_asTable)
          _SeriesTable(series: series)
        else
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 1100 ? 2 : 1;
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(width: w, child: DailyBarChart(title: 'New users', points: pts('signups'))),
              SizedBox(width: w, child: DailyBarChart(title: 'Errors logged', points: pts('errors'))),
              SizedBox(width: w, child: DailyBarChart(title: 'AI calls', points: pts('ai_calls'))),
              SizedBox(width: w, child: DailyBarChart(title: 'Issues reported', points: pts('issues'))),
            ]);
          }),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text('Updated ${fmtDateTime(o['generated_at'])}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}

class _SeriesTable extends StatelessWidget {
  final List<Map<String, dynamic>> series;
  const _SeriesTable({required this.series});

  @override
  Widget build(BuildContext context) {
    DataCell num(dynamic v) => DataCell(Text(fmtNum(v)));
    return TableCard(
      table: DataTable(
        columns: const [
          DataColumn(label: Text('Day')),
          DataColumn(label: Text('New users'), numeric: true),
          DataColumn(label: Text('Errors'), numeric: true),
          DataColumn(label: Text('AI calls'), numeric: true),
          DataColumn(label: Text('AI failures'), numeric: true),
          DataColumn(label: Text('Issues'), numeric: true),
        ],
        rows: [
          for (final r in series.reversed)
            DataRow(cells: [
              DataCell(Text(fmtDate(r['day']))),
              num(r['signups']),
              num(r['errors']),
              num(r['ai_calls']),
              num(r['ai_errors']),
              num(r['issues']),
            ]),
        ],
      ),
    );
  }
}
