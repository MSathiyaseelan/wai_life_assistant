import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RECYCLE BIN SHEET
// ─────────────────────────────────────────────────────────────────────────────

class RecycleBinSheet extends StatefulWidget {
  final bool isDark;
  const RecycleBinSheet({super.key, required this.isDark});

  @override
  State<RecycleBinSheet> createState() => _RecycleBinSheetState();
}

class _RecycleBinItem {
  final String table;
  final String id;
  final String category;
  final String name;
  final DateTime deletedAt;

  const _RecycleBinItem({
    required this.table,
    required this.id,
    required this.category,
    required this.name,
    required this.deletedAt,
  });

  int get daysUntilPurge {
    final expiry = deletedAt.add(const Duration(days: 30));
    return expiry.difference(DateTime.now().toUtc()).inDays.clamp(0, 30);
  }
}

// Table definitions: (table, category label, name columns to try in order)
const _kTables = [
  ('wishes',                   'PlanIt',    ['title', 'category']),
  ('reminders',                'PlanIt',    ['title']),
  ('notes',                    'Notes',     ['title', 'content']),
  ('wardrobe_items',           'Wardrobe',  ['name', 'category']),
  ('health_medications',       'Health',    ['name', 'dosage']),
  ('health_doctors',           'Health',    ['name', 'specialty']),
  ('health_documents',         'Health',    ['title', 'doc_type']),
  ('health_appointments',      'Health',    ['doctor_name', 'location']),
  ('health_vitals',            'Health',    ['vital_type']),
  ('health_vaccinations',      'Health',    ['vaccine_name']),
  ('health_insurance',         'Health',    ['policy_name', 'provider']),
  ('family_members',           'Family',    ['name', 'relation']),
  ('functions_my',             'Functions', ['title', 'who_function']),
  ('functions_upcoming',       'Functions', ['function_title', 'person_name']),
  ('functions_attended',       'Functions', ['function_name']),
  ('function_participants',    'Functions', ['name', 'relation']),
  ('function_moi_entries',     'Functions', ['person_name', 'family_name']),
  ('function_clothing_families','Functions',['family_name']),
  ('function_bridal_essentials','Functions',['item', 'category']),
  ('function_return_gifts',    'Functions', ['gift_name']),
  ('attended_function_groups', 'Functions', ['name']),
  ('item_locator_containers',  'Locator',   ['name', 'location']),
  ('item_locator_items',       'Locator',   ['name', 'description']),
  ('transactions',             'Wallet',    ['title', 'category']),
  ('tx_groups',                'Wallet',    ['name']),
  ('bills',                    'Wallet',    ['name', 'category']),
  ('wallet_budgets',           'Wallet',    ['category']),
  ('split_groups',             'Wallet',    ['name']),
  ('recipes',                  'Pantry',    ['name', 'cuisine']),
  ('meal_entries',             'Pantry',    ['name', 'meal_time']),
  ('meal_reactions',           'Pantry',    ['member_name', 'comment']),
  ('member_food_prefs',        'Pantry',    ['member_name']),
  ('tasks',                    'PlanIt',    ['title', 'project']),
  ('special_days',             'PlanIt',    ['title', 'type']),
];

class _RecycleBinSheetState extends State<RecycleBinSheet> {
  bool _loading = true;
  List<_RecycleBinItem> _items = [];
  final Set<String> _restoring = {};

  SupabaseClient get _db => Supabase.instance.client;

  Color get _bg   => widget.isDark ? AppColors.cardDark  : AppColors.cardLight;
  Color get _surf => widget.isDark ? AppColors.surfDark  : const Color(0xFFEDEEF5);
  Color get _tc   => widget.isDark ? AppColors.textDark  : AppColors.textLight;
  Color get _sub  => widget.isDark ? AppColors.subDark   : AppColors.subLight;
  Color get _div  => widget.isDark
      ? Colors.white.withAlpha(18)
      : Colors.black.withAlpha(18);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 30)).toIso8601String();
    final all = <_RecycleBinItem>[];

    await Future.wait(_kTables.map((entry) async {
      final (table, category, nameCols) = entry;
      try {
        final cols = {'id', 'deleted_at', ...nameCols}.join(',');
        final rows = await _db
            .from(table)
            .select(cols)
            .not('deleted_at', 'is', null)
            .gt('deleted_at', cutoff)
            .order('deleted_at', ascending: false)
            .limit(50);
        for (final row in (rows as List)) {
          final r = row as Map<String, dynamic>;
          final rawDate = r['deleted_at'] as String?;
          if (rawDate == null) continue;
          final deletedAt = DateTime.tryParse(rawDate)?.toUtc();
          if (deletedAt == null) continue;
          String name = '';
          for (final col in nameCols) {
            final v = r[col];
            if (v is String && v.isNotEmpty) { name = v; break; }
          }
          if (name.isEmpty) name = table.replaceAll('_', ' ');
          all.add(_RecycleBinItem(
            table: table,
            id: r['id'] as String,
            category: category,
            name: name,
            deletedAt: deletedAt,
          ));
        }
      } catch (e, stack) {
        ErrorLogger.log(e, stackTrace: stack, action: 'recycle_bin_fetch_$table');
      }
    }));

    all.sort((a, b) => a.deletedAt.compareTo(b.deletedAt));

    if (mounted) setState(() { _items = all; _loading = false; });
  }

  Future<void> _restore(_RecycleBinItem item) async {
    final key = '${item.table}:${item.id}';
    setState(() => _restoring.add(key));
    try {
      await _db.from(item.table).update({'deleted_at': null}).eq('id', item.id);
      if (mounted) setState(() { _items.removeWhere((i) => i.table == item.table && i.id == item.id); _restoring.remove(key); });
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'recycle_bin_restore');
      if (!mounted) return;
      setState(() => _restoring.remove(key));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restore failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<_RecycleBinItem>>{};
    for (final item in _items) {
      (grouped[item.category] ??= []).add(item);
    }

    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _handle(),
          _header(),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? _emptyState()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                        children: [
                          for (final entry in grouped.entries) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 16, bottom: 8),
                              child: Text(
                                entry.key.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w800,
                                  color: _sub,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: _surf,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  for (int i = 0; i < entry.value.length; i++) ...[
                                    if (i > 0) Divider(height: 1, color: _div),
                                    _itemTile(entry.value[i]),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _handle() => Center(
    child: Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: _sub.withAlpha(80),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
    child: Row(
      children: [
        const Text('🗑️', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recycle Bin',
                style: TextStyle(fontSize: 18, fontFamily: 'Nunito', fontWeight: FontWeight.w900, color: _tc)),
              Text('Items are permanently deleted after 30 days',
                style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: _sub)),
            ],
          ),
        ),
        if (!_loading)
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _sub, size: 20),
            onPressed: _load,
          ),
      ],
    ),
  );

  Widget _itemTile(_RecycleBinItem item) {
    final key = '${item.table}:${item.id}';
    final restoring = _restoring.contains(key);
    final days = item.daysUntilPurge;
    final urgentColor = days <= 3 ? const Color(0xFFFF5C7A) : days <= 7 ? const Color(0xFFFFAA2C) : _sub;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    color: _tc,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  days == 0 ? 'Deleted today · purged tomorrow' : 'Purged in $days day${days == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: urgentColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          restoring
              ? const SizedBox(width: 36, height: 36, child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))))
              : TextButton(
                  onPressed: () => _restore(item),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 13, fontFamily: 'Nunito', fontWeight: FontWeight.w800),
                  ),
                  child: const Text('Restore'),
                ),
        ],
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🧹', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text('Recycle bin is empty',
          style: TextStyle(fontSize: 16, fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: _tc)),
        const SizedBox(height: 4),
        Text('Deleted items will appear here for 30 days',
          style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: _sub)),
      ],
    ),
  );
}
