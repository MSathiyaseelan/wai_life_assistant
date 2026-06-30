import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/health/health_models.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';

class HealthService {
  HealthService._();
  static final HealthService instance = HealthService._();

  static final changeSignal = ValueNotifier<int>(0);

  SupabaseClient get _db => Supabase.instance.client;
  String get _uid {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('Not authenticated');
    return uid;
  }

  static const _bucket = 'health-docs';

  // ── Document Storage ─────────────────────────────────────────────────────────

  Future<String> uploadDoc(String localPath, {String memberId = 'me'}) async {
    final bytes = await File(localPath).readAsBytes();
    final ext = localPath.contains('.') ? localPath.split('.').last.toLowerCase() : 'jpg';
    final storagePath = '$_uid/$memberId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final mime = ext == 'pdf' ? 'application/pdf' : 'image/jpeg';
    await _db.storage.from(_bucket).uploadBinary(storagePath, bytes,
        fileOptions: FileOptions(contentType: mime, upsert: false));
    return _db.storage.from(_bucket).getPublicUrl(storagePath);
  }

  Future<void> deleteDoc(String? fileUrl) async {
    if (fileUrl == null || !fileUrl.contains(_bucket)) return;
    try {
      final uri = Uri.parse(fileUrl);
      final segs = uri.pathSegments;
      final idx = segs.indexOf(_bucket);
      if (idx >= 0 && idx < segs.length - 1) {
        await _db.storage.from(_bucket).remove([segs.sublist(idx + 1).join('/')]);
      }
    } catch (e, stack) {
      debugPrint('[Health] deleteDoc error: $e');
      ErrorLogger.log(e, stackTrace: stack, action: 'delete_health_doc');
    }
  }

  // ── Health Profile ────────────────────────────────────────────────────────────

  Future<HealthProfile?> fetchProfile(String walletId, String memberId) async {
    final rows = await _db
        .from('health_profiles')
        .select()
        .eq('wallet_id', walletId)
        .eq('member_id', memberId)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return HealthProfile.fromJson(rows.first);
  }

  Future<HealthProfile> upsertProfile(HealthProfile p) async {
    final data = {...p.toJson(), 'user_id': _uid};
    if (p.id.isEmpty) {
      final row = await _db.from('health_profiles').insert(data).select().single();
      return HealthProfile.fromJson(row);
    } else {
      final row = await _db
          .from('health_profiles')
          .update(p.toJson())
          .eq('id', p.id)
          .select()
          .single();
      return HealthProfile.fromJson(row);
    }
  }

  // ── Medications ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchMedications(String walletId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _db
        .from('health_medications')
        .update({'is_active': false})
        .eq('wallet_id', walletId)
        .eq('is_active', true)
        .not('end_date', 'is', null)
        .lt('end_date', today);

    final rows = await _db
        .from('health_medications')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
        .order('is_active', ascending: false)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> addMedication(Map<String, dynamic> data) async {
    final row = await _db
        .from('health_medications')
        .insert({...data, 'user_id': _uid})
        .select()
        .single();
    changeSignal.value++;
    return row;
  }

  Future<void> updateMedication(String id, Map<String, dynamic> updates) async {
    await _db.from('health_medications').update(updates).eq('id', id);
    changeSignal.value++;
  }

  Future<void> deleteMedication(String id) async {
    await _db.from('health_medications').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
    changeSignal.value++;
  }

  // ── Doctors ───────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchDoctors(String walletId) async {
    final rows = await _db
        .from('health_doctors')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
        .order('name');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> addDoctor(Map<String, dynamic> data) async {
    final row = await _db
        .from('health_doctors')
        .insert({...data, 'user_id': _uid})
        .select()
        .single();
    return row;
  }

  Future<void> updateDoctor(String id, Map<String, dynamic> updates) async {
    await _db.from('health_doctors').update(updates).eq('id', id);
  }

  Future<void> deleteDoctor(String id) async {
    await _db.from('health_doctors').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  // ── Documents ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchDocuments(String walletId) async {
    final rows = await _db
        .from('health_documents')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
        .order('doc_date', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> addDocument(Map<String, dynamic> data) async {
    final row = await _db
        .from('health_documents')
        .insert({...data, 'user_id': _uid})
        .select()
        .single();
    return row;
  }

  Future<void> updateDocument(String id, Map<String, dynamic> updates) async {
    await _db.from('health_documents').update(updates).eq('id', id);
  }

  Future<List<String>> uploadDocs(List<String> localPaths, {String memberId = 'me'}) async {
    final urls = await Future.wait(localPaths.map((p) => uploadDoc(p, memberId: memberId)));
    return urls;
  }

  Future<void> deleteDocument(String id, List<String> fileUrls) async {
    await _db.from('health_documents').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
    await Future.wait(fileUrls.map(deleteDoc));
  }

  // ── Appointments ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchAppointments(String walletId) async {
    final rows = await _db
        .from('health_appointments')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
        .order('appt_date', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> addAppointment(Map<String, dynamic> data) async {
    final row = await _db
        .from('health_appointments')
        .insert({...data, 'user_id': _uid})
        .select()
        .single();
    return row;
  }

  Future<void> updateAppointment(String id, Map<String, dynamic> updates) async {
    await _db.from('health_appointments').update(updates).eq('id', id);
  }

  Future<void> deleteAppointment(String id) async {
    await _db.from('health_appointments').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  // ── Vitals ────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchVitals(String walletId) async {
    final rows = await _db
        .from('health_vitals')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
        .order('recorded_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> addVital(Map<String, dynamic> data) async {
    final row = await _db
        .from('health_vitals')
        .insert({...data, 'user_id': _uid})
        .select()
        .single();
    return row;
  }

  Future<void> updateVital(String id, Map<String, dynamic> updates) async {
    await _db.from('health_vitals').update(updates).eq('id', id);
  }

  Future<void> deleteVital(String id) async {
    await _db.from('health_vitals').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  // ── Vaccinations ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchVaccinations(String walletId) async {
    final rows = await _db
        .from('health_vaccinations')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
        .order('date_given', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> addVaccination(Map<String, dynamic> data) async {
    final row = await _db
        .from('health_vaccinations')
        .insert({...data, 'user_id': _uid})
        .select()
        .single();
    return row;
  }

  Future<void> updateVaccination(String id, Map<String, dynamic> updates) async {
    await _db.from('health_vaccinations').update(updates).eq('id', id);
  }

  Future<void> deleteVaccination(String id) async {
    await _db.from('health_vaccinations').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  // ── Insurance ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchInsurance(String walletId) async {
    final rows = await _db
        .from('health_insurance')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> addInsurance(Map<String, dynamic> data) async {
    final row = await _db
        .from('health_insurance')
        .insert({...data, 'user_id': _uid})
        .select()
        .single();
    return row;
  }

  Future<void> updateInsurance(String id, Map<String, dynamic> updates) async {
    await _db.from('health_insurance').update(updates).eq('id', id);
  }

  Future<void> deleteInsurance(String id) async {
    await _db.from('health_insurance').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  Future<void> restore(String table, String id) async {
    await _db.from(table).update({'deleted_at': null}).eq('id', id);
  }

  // ── Summary (for MyHub card) ──────────────────────────────────────────────────

  Future<Map<String, int>> fetchSummary(String walletId) async {
    try {
      final results = await Future.wait([
        _db.from('health_medications').select('id').eq('wallet_id', walletId).eq('is_active', true).isFilter('deleted_at', null),
        _db.from('health_appointments').select('appt_date').eq('wallet_id', walletId)
            .gte('appt_date', DateTime.now().toIso8601String().substring(0, 10))
            .isFilter('deleted_at', null),
      ]);
      return {
        'medications': (results[0] as List).length,
        'appointments': (results[1] as List).length,
      };
    } catch (_) {
      return {'medications': 0, 'appointments': 0};
    }
  }
}
