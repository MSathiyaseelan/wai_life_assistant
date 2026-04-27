import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin Supabase layer for PlanIt special days.
class SpecialDayService {
  SpecialDayService._();
  static final SpecialDayService instance = SpecialDayService._();

  SupabaseClient get _db => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchDays(String walletId) async {
    final rows = await _db
        .from('special_days')
        .select()
        .eq('wallet_id', walletId)
        .order('date');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addDay(Map<String, dynamic> data) async {
    final row = await _db.from('special_days').insert(data).select().single();
    return row;
  }

  Future<void> updateDay(String id, Map<String, dynamic> updates) async {
    await _db.from('special_days').update(updates).eq('id', id);
  }

  Future<void> deleteDay(String id) async {
    await _db.from('special_days').delete().eq('id', id);
  }
}
