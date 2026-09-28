import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets/common.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  static const _pageSize = 50;
  final _search = TextEditingController();
  Timer? _debounce;
  int _page = 0;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _load() => _future = AdminApi.instance.users(
      search: _search.text, limit: _pageSize, offset: _page * _pageSize);
  void _reload() => setState(_load);

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => setState(() {
          _page = 0;
          _load();
        }));
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Users',
      subtitle: 'App users, newest first (dashboard admins excluded)',
      actions: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: _search,
            onChanged: _onSearch,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 20),
              hintText: 'Name or phone',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        IconButton(tooltip: 'Refresh', onPressed: _reload, icon: const Icon(Icons.refresh)),
      ],
      child: Loader(
        future: _future,
        onRetry: _reload,
        builder: (rows) {
          if (rows.isEmpty) return const EmptyState('No users found.');
          final total = (rows.first['total_count'] as num?)?.toInt() ?? rows.length;
          final pages = (total / _pageSize).ceil();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TableCard(
                table: DataTable(
                  columns: const [
                    DataColumn(label: Text('User')),
                    DataColumn(label: Text('Phone')),
                    DataColumn(label: Text('Plan')),
                    DataColumn(label: Text('Onboarded')),
                    DataColumn(label: Text('Joined')),
                    DataColumn(label: Text('Families'), numeric: true),
                    DataColumn(label: Text('Issues'), numeric: true),
                    DataColumn(label: Text('Errors · 7d'), numeric: true),
                    DataColumn(label: Text('AI · 30d'), numeric: true),
                  ],
                  rows: [
                    for (final u in rows)
                      DataRow(cells: [
                        DataCell(Text('${u['emoji'] ?? ''} ${u['name'] ?? '—'}'.trim())),
                        DataCell(SelectableText('${u['phone'] ?? '—'}')),
                        DataCell(Text('${u['plan'] ?? '—'}')),
                        DataCell(Text(u['onboarded'] == true ? 'Yes' : 'No')),
                        DataCell(Text(fmtDate(u['created_at']))),
                        DataCell(Text(fmtNum(u['families']))),
                        DataCell(Text(fmtNum(u['issues']))),
                        DataCell(Text(fmtNum(u['errors_7d']))),
                        DataCell(Text(fmtNum(u['ai_calls_30d']))),
                      ]),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${fmtNum(total)} users · page ${_page + 1} of $pages'),
                  IconButton(
                    onPressed: _page == 0 ? null : () => setState(() {
                      _page--;
                      _load();
                    }),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    onPressed: _page + 1 >= pages ? null : () => setState(() {
                      _page++;
                      _load();
                    }),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
