import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wai_life_assistant/features/wallet/models/sms_transaction.dart';
import 'package:wai_life_assistant/features/wallet/services/sms_regex_parser.dart';
import 'package:wai_life_assistant/core/services/ai_parser.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SmsHistoryItem — one result from a historical SMS scan
// ─────────────────────────────────────────────────────────────────────────────

class SmsHistoryItem {
  final SMSTransaction tx;
  final String sender;
  final DateTime? messageDate;
  const SmsHistoryItem({
    required this.tx,
    required this.sender,
    this.messageDate,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SMSParserService
//
// Approach 1 (automatic): scan-on-open — reads inbox on each app open,
//   detects new bank SMS since the last scan, and surfaces them via
//   pendingSmsBody for the UI to confirm.  No background receiver needed,
//   no Google Play policy issues.
//
// Approach 2 (manual): parseSMSText() — called directly by SparkBottomSheet
//   when the user pastes a bank SMS.
// ─────────────────────────────────────────────────────────────────────────────

class SMSParserService {
  SMSParserService._();

  static const _kLastScannedKey = 'sms_last_scanned_ms';
  static const _kSeenIdsKey     = 'sms_seen_ids';
  static const kPendingKey       = 'pending_sms_body';
  static const kSmsPayloadPrefix = 'sms:';

  // Minimum gap between scans (5 minutes) to avoid hammering on every hot-restart.
  static const _kScanCooldownMs = 5 * 60 * 1000;

  /// Listened to in AppShell — set when a bank SMS needs user confirmation.
  static final pendingSmsBody = ValueNotifier<String?>(null);

  // ── Approach 1: initialise + scan ────────────────────────────────────────

  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    final granted = await _requestPermission();
    if (!granted) {
      debugPrint('[SMS] READ_SMS permission denied');
      return;
    }

    await _createSmsChannel();
    await scanNewMessages();
  }

  /// Scans the SMS inbox for bank messages newer than the last scan.
  /// Safe to call on every app-open — enforces a 5-minute cooldown.
  static Future<void> scanNewMessages() async {
    if (!Platform.isAndroid) return;

    final status = await Permission.sms.status;
    if (!status.isGranted) return;

    final prefs      = await SharedPreferences.getInstance();
    final lastMs     = prefs.getInt(_kLastScannedKey) ?? 0;
    final nowMs      = DateTime.now().millisecondsSinceEpoch;

    if (nowMs - lastMs < _kScanCooldownMs) return; // too soon

    // Read inbox — limit to last 48 h to keep it fast
    final sinceMs    = lastMs > 0 ? lastMs : nowMs - (48 * 3600 * 1000);
    final since      = DateTime.fromMillisecondsSinceEpoch(sinceMs);

    List<SmsMessage> messages;
    try {
      final query = SmsQuery();
      messages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
      );
    } catch (e) {
      debugPrint('[SMS] inbox read error: $e');
      return;
    }

    // Save scan timestamp before processing so a crash doesn't re-scan old SMS.
    await prefs.setInt(_kLastScannedKey, nowMs);

    // Filter: newer than last scan AND looks like a bank SMS
    final seenRaw  = prefs.getStringList(_kSeenIdsKey) ?? [];
    final seenIds  = seenRaw.toSet();

    final candidates = messages.where((m) {
      final msgMs = m.date?.millisecondsSinceEpoch ?? 0;
      if (msgMs < since.millisecondsSinceEpoch) return false;
      if (seenIds.contains(m.id?.toString())) return false;
      return isBankSMS(m.sender ?? '', m.body ?? '');
    }).toList()
      ..sort((a, b) =>
          (b.date?.millisecondsSinceEpoch ?? 0)
              .compareTo(a.date?.millisecondsSinceEpoch ?? 0));

    if (candidates.isEmpty) return;

    // Mark all as seen
    final newIds = candidates.map((m) => m.id?.toString() ?? '').toSet();
    await prefs.setStringList(
        _kSeenIdsKey, {...seenIds, ...newIds}.take(200).toList());

    // Surface only the most recent one — user can handle one at a time
    final latest = candidates.first;
    final body   = latest.body ?? '';
    if (body.isEmpty) return;

    debugPrint('[SMS] new bank SMS found from ${latest.sender}');

    // Show a local notification so the user knows even if the app is in BG
    await _showSmsNotification(body);

    // Also set ValueNotifier so foreground confirm sheet fires immediately
    pendingSmsBody.value = body;
  }

  // ── Check for SMS pending from a cold-start notification tap ─────────────

  static Future<void> checkPending() async {
    final prefs   = await SharedPreferences.getInstance();
    final pending = prefs.getString(kPendingKey);
    if (pending != null) {
      await prefs.remove(kPendingKey);
      pendingSmsBody.value = pending;
      debugPrint('[SMS] loaded pending SMS from cold-start tap');
    }
  }

  /// Called from notification_service.dart when a wai_sms_channel tap fires.
  static void handleNotificationPayload(String payload) {
    if (!payload.startsWith(kSmsPayloadPrefix)) return;
    pendingSmsBody.value = payload.substring(kSmsPayloadPrefix.length);
  }

  // ── Approach 2: parse a raw SMS string ───────────────────────────────────

  static Future<SMSTransaction?> parseSMSText(String text) async {
    // Layer 1: regex (free, instant)
    final regexResult = SMSRegexParser.tryParse(text);
    if (regexResult != null && regexResult.isHighConfidence) {
      debugPrint('[SMS] regex parsed: ${regexResult.merchant} ${regexResult.amount}');
      return regexResult;
    }

    // Layer 2: AI via Supabase edge function; fall back to regex if AI fails
    final aiResult = await _parseWithAI(text, '');
    return aiResult ?? regexResult;
  }

  /// Scans the SMS inbox for bank messages in [from]..[to] and parses them
  /// using regex only (no AI — keeps bulk scanning free and fast).
  /// Returns newest-first list of [SmsHistoryItem].
  static Future<List<SmsHistoryItem>> scanHistory({
    required DateTime from,
    required DateTime to,
  }) async {
    if (!Platform.isAndroid) return [];

    final status = await Permission.sms.status;
    if (!status.isGranted) return [];

    List<SmsMessage> messages;
    try {
      final query = SmsQuery();
      messages = await query.querySms(kinds: [SmsQueryKind.inbox]);
    } catch (e) {
      debugPrint('[SMS] history scan error: $e');
      return [];
    }

    final fromMs = from.millisecondsSinceEpoch;
    final toMs   = to.millisecondsSinceEpoch;
    final results = <SmsHistoryItem>[];

    for (final m in messages) {
      final msgMs = m.date?.millisecondsSinceEpoch ?? 0;
      if (msgMs < fromMs || msgMs > toMs) continue;
      final body   = m.body ?? '';
      final sender = m.sender ?? '';
      if (!isBankSMS(sender, body)) continue;

      final tx = SMSRegexParser.tryParse(body, fallbackDate: m.date);
      if (tx != null && tx.isTransaction) {
        results.add(SmsHistoryItem(tx: tx, sender: sender, messageDate: m.date));
      }
    }

    results.sort((a, b) => b.tx.transactionDate.compareTo(a.tx.transactionDate));
    return results;
  }

  // ── Bank SMS detector (public — used by scanner) ─────────────────────────

  static bool isBankSMS(String sender, String body) {
    final s = sender.toLowerCase();
    final b = body.toLowerCase();

    const bankSenders = [
      'hdfcbk', 'icicib', 'sbiinb', 'axisbk', 'kotakb', 'boiind',
      'pnbsms', 'canbnk', 'indbnk', 'yesbnk', 'rblbnk', 'iobsms',
      'scbank', 'federa', 'idbibk', 'paytmb',
      'gpay', 'phonepe', 'paytm', 'bhimupi',
    ];
    if (bankSenders.any((k) => s.contains(k))) return true;

    return ['debited', 'credited', 'debit', 'credit', 'withdrawn',
            'inr ', 'rs.', '₹'].any((k) => b.contains(k));
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static Future<SMSTransaction?> _parseWithAI(
      String body, String sender) async {
    try {
      final result = await AIParser.parseText(
        feature:    'wallet',
        subFeature: 'sms_parse',
        text:       body,
        context: {
          'sender': sender,
          'today':  DateTime.now().toIso8601String().split('T')[0],
        },
      );
      if (!result.success || result.data == null) return null;
      if (result.data!['is_transaction'] != true) return null;
      return SMSTransaction.fromJson(result.data!);
    } catch (e) {
      debugPrint('[SMS] AI parse error: $e');
      return null;
    }
  }

  static Future<bool> _requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  static Future<void> _createSmsChannel() async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'wai_sms_channel',
          'Bank SMS Alerts',
          description: 'Detected bank transactions from SMS',
          importance: Importance.high,
        ));
  }

  static Future<void> _showSmsNotification(String body) async {
    // Quick regex parse just for the notification title
    final parsed = SMSRegexParser.tryParse(body);
    final title  = parsed != null
        ? (parsed.isExpense
            ? '🏦 ₹${parsed.amount.toStringAsFixed(0)} spent at ${parsed.title}'
            : '🏦 ₹${parsed.amount.toStringAsFixed(0)} received')
        : '🏦 Bank transaction detected';

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.show(
      body.hashCode.abs() % 100000,
      title,
      'Tap to add to WAI Wallet',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'wai_sms_channel',
          'Bank SMS Alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: '$kSmsPayloadPrefix$body',
    );
  }
}
