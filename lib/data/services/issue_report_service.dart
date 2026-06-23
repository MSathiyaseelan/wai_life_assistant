import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IssueReport model
// ─────────────────────────────────────────────────────────────────────────────

class IssueReport {
  final String id;
  final String category;
  final String title;
  final String description;
  final List<String> screenshots;
  final String priority;
  final String status;
  final String? adminNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IssueReport({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.screenshots,
    required this.priority,
    required this.status,
    this.adminNote,
    required this.createdAt,
    required this.updatedAt,
  });

  factory IssueReport.fromMap(Map<String, dynamic> m) => IssueReport(
        id: m['id'] as String,
        category: m['category'] as String? ?? 'bug',
        title: m['title'] as String? ?? '',
        description: m['description'] as String? ?? '',
        screenshots: List<String>.from(m['screenshots'] as List? ?? []),
        priority: m['priority'] as String? ?? 'medium',
        status: m['status'] as String? ?? 'open',
        adminNote: m['admin_note'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  String get categoryLabel => switch (category) {
        'bug' => 'Bug',
        'crash' => 'Crash',
        'feature_request' => 'Feature Request',
        'performance' => 'Performance',
        'ui' => 'UI / UX',
        _ => 'Other',
      };

  String get categoryEmoji => switch (category) {
        'bug' => '🐛',
        'crash' => '💥',
        'feature_request' => '💡',
        'performance' => '⚡',
        'ui' => '🎨',
        _ => '💬',
      };

  String get statusLabel => switch (status) {
        'open' => 'Open',
        'in_progress' => 'In Progress',
        'resolved' => 'Resolved',
        'closed' => 'Closed',
        _ => status,
      };

  String get priorityLabel => switch (priority) {
        'low' => 'Low',
        'high' => 'High',
        _ => 'Medium',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// IssueReportService
// ─────────────────────────────────────────────────────────────────────────────

class IssueReportService {
  IssueReportService._();
  static final IssueReportService instance = IssueReportService._();

  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  static const _bucket = 'issue-screenshots';
  static const _table  = 'issue_reports';

  // ── Upload one screenshot → public URL ───────────────────────────────────

  Future<String?> uploadScreenshot(String localPath) async {
    try {
      final bytes = await File(localPath).readAsBytes();
      final ext = localPath.contains('.') ? localPath.split('.').last.toLowerCase() : 'jpg';
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      final path = '$_uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _db.storage.from(_bucket).uploadBinary(
        path, bytes,
        fileOptions: FileOptions(contentType: mime, upsert: false),
      );
      return _db.storage.from(_bucket).getPublicUrl(path);
    } catch (e, s) {
      debugPrint('[IssueReport] upload error: $e');
      ErrorLogger.log(e, stackTrace: s, action: 'upload_issue_screenshot');
      return null;
    }
  }

  // ── Submit a new report ──────────────────────────────────────────────────

  Future<IssueReport> submit({
    required String category,
    required String title,
    required String description,
    required String priority,
    List<String> localScreenshotPaths = const [],
    Map<String, dynamic> deviceInfo = const {},
  }) async {
    // Upload screenshots in parallel
    final urls = <String>[];
    if (localScreenshotPaths.isNotEmpty) {
      final results = await Future.wait(
        localScreenshotPaths.map(uploadScreenshot),
      );
      urls.addAll(results.whereType<String>());
    }

    final row = await _db.from(_table).insert({
      'user_id':     _uid,
      'category':    category,
      'title':       title.trim(),
      'description': description.trim(),
      'screenshots': urls,
      'priority':    priority,
      'device_info': deviceInfo,
    }).select().single();

    return IssueReport.fromMap(row);
  }

  // ── Fetch all reports for current user ──────────────────────────────────

  Future<List<IssueReport>> fetchMyReports() async {
    final rows = await _db
        .from(_table)
        .select()
        .eq('user_id', _uid)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => IssueReport.fromMap(r as Map<String, dynamic>)).toList();
  }

  // ── Delete an open report ────────────────────────────────────────────────

  Future<void> deleteReport(String id) async {
    await _db.from(_table).delete().eq('id', id).eq('user_id', _uid);
  }
}
