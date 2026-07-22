import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/data/services/pantry_service.dart';
import 'package:wai_life_assistant/data/services/task_service.dart';
import 'package:wai_life_assistant/data/services/reminder_service.dart';
import 'package:wai_life_assistant/data/services/wallet_service.dart';
import 'package:wai_life_assistant/data/services/functions_service.dart';
import 'package:wai_life_assistant/data/services/health_service.dart';
import 'package:wai_life_assistant/data/services/special_day_service.dart';
import 'package:wai_life_assistant/data/services/wardrobe_service.dart';
import 'assistant_response.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ActionExecutor — routes AI action payloads to the right service
// ─────────────────────────────────────────────────────────────────────────────

class ActionExecutor {
  ActionExecutor._();
  static final ActionExecutor instance = ActionExecutor._();

  SupabaseClient get _db => Supabase.instance.client;
  String get _uid {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('Not authenticated');
    return uid;
  }

  /// Returns the saved [TxModel] for transaction actions (expense/income/lend/borrow),
  /// null for all other action types.
  Future<TxModel?> execute(ActionPayload action, String walletId) async {
    final d = action.data;
    try {
    switch (action.actionType) {
      case ActionType.addGrocery:
        await PantryService.instance.addGroceryItem(
          walletId: walletId,
          name: _str(d, 'name'),
          category: _str(d, 'category', fallback: 'other'),
          quantity: _num(d, 'qty', fallback: 1.0),
          unit: _str(d, 'unit', fallback: 'pcs'),
          inStock: false,
          toBuy: true,
          isGrocery: d['is_grocery'] as bool? ?? true,
        );

      case ActionType.addTask:
        await TaskService.instance.addTask({
          'wallet_id': walletId,
          'title': _str(d, 'title'),
          'is_done': false,
          if (d['due_date'] != null) 'due_date': d['due_date'],
        });

      case ActionType.addReminder:
        final dueDate = _parseDate(d['due_date'] as String?) ??
            DateTime.now().add(const Duration(days: 1));
        // DB CHECK: repeat IN ('none','daily','weekly','monthly','yearly')
        final rawRepeat = _str(d, 'repeat', fallback: 'none');
        const validRepeats = {'none', 'daily', 'weekly', 'monthly', 'yearly'};
        final repeat = validRepeats.contains(rawRepeat) ? rawRepeat : 'none';
        final assignedTo = _str(d, 'assigned_to');
        await ReminderService.instance.addReminder(
          walletId: walletId,
          title: _str(d, 'title'),
          emoji: _str(d, 'emoji', fallback: '🔔'),
          dueDate: dueDate,
          dueTime: _str(d, 'due_time', fallback: '09:00'),
          repeat: repeat,
          priority: _str(d, 'priority', fallback: 'medium'),
          assignedTo: assignedTo.isEmpty ? 'me' : assignedTo,
          note: d['note'] as String?,
        );

      case ActionType.addExpense:
        final row = await WalletService.instance.addTransaction(
          walletId: walletId,
          type: 'expense',
          amount: _num(d, 'amount'),
          category: _str(d, 'category', fallback: 'other'),
          title: d['title'] as String?,
          note: d['note'] as String?,
          payMode: _payMode(d, fallback: 'cash'),
          date: _parseDate(d['date'] as String?),
        );
        return TxModel.fromRow(row);

      case ActionType.addIncome:
        final row = await WalletService.instance.addTransaction(
          walletId: walletId,
          type: 'income',
          amount: _num(d, 'amount'),
          category: _str(d, 'category', fallback: 'salary'),
          title: d['title'] as String?,
          note: d['note'] as String?,
          payMode: _payMode(d, fallback: 'online'),
          date: _parseDate(d['date'] as String?),
        );
        return TxModel.fromRow(row);

      case ActionType.addLend:
        final row = await WalletService.instance.addTransaction(
          walletId: walletId,
          type: 'lend',
          amount: _num(d, 'amount'),
          category: _str(d, 'category', fallback: 'lend'),
          title: d['title'] as String?,
          note: d['note'] as String?,
          person: _str(d, 'person').isEmpty ? null : _str(d, 'person'),
          date: _parseDate(d['date'] as String?),
        );
        return TxModel.fromRow(row);

      case ActionType.addBorrow:
        final row = await WalletService.instance.addTransaction(
          walletId: walletId,
          type: 'borrow',
          amount: _num(d, 'amount'),
          category: _str(d, 'category', fallback: 'borrow'),
          title: d['title'] as String?,
          note: d['note'] as String?,
          person: _str(d, 'person').isEmpty ? null : _str(d, 'person'),
          date: _parseDate(d['date'] as String?),
        );
        return TxModel.fromRow(row);

      case ActionType.addFunctionUpcoming:
        await FunctionsService.instance.addUpcoming({
          'wallet_id':      walletId,
          'user_id':        _uid,
          'function_title': _str(d, 'function_title'),
          'person_name':    _str(d, 'person_name'),
          'type':           _str(d, 'type', fallback: 'other'),
          if (d['date'] != null)  'date':  d['date'],
          if (d['venue'] != null) 'venue': d['venue'],
          if (d['notes'] != null) 'notes': d['notes'],
        });

      case ActionType.addFunctionMy:
        await FunctionsService.instance.addMyFunction({
          'wallet_id':    walletId,
          'user_id':      _uid,
          'title':        _str(d, 'title'),
          'type':         _str(d, 'type', fallback: 'other'),
          'who_function': _str(d, 'who_function'),
          if (d['function_date'] != null) 'function_date': d['function_date'],
          if (d['venue'] != null)         'venue':         d['venue'],
        });

      case ActionType.addMeal:
        final date = _parseDate(d['date'] as String?) ?? DateTime.now();
        await PantryService.instance.addMealEntry(
          walletId: walletId,
          name: _str(d, 'meal_name'),
          emoji: _str(d, 'emoji', fallback: '🍽️'),
          mealTime: _str(d, 'meal_time', fallback: 'lunch'),
          date: date,
          note: d['note'] as String?,
        );

      case ActionType.addSpecialDay:
        await SpecialDayService.instance.addDay({
          'wallet_id': walletId,
          'title':     _str(d, 'title'),
          'date':      _str(d, 'date', fallback: _today()),
          if (d['type'] != null)  'type':  d['type'],
          if (d['emoji'] != null) 'emoji': d['emoji'],
          if (d['note'] != null)  'note':  d['note'],
        });

      case ActionType.addWardrobeItem:
        await WardrobeService.instance.addItem({
          'wallet_id':      walletId,
          'name':           _str(d, 'name'),
          'type':           _str(d, 'type', fallback: 'other'),
          if (d['color'] != null)    'color':    d['color'],
          if (d['occasion'] != null) 'occasion': d['occasion'],
          if (d['brand'] != null)    'brand':    d['brand'],
        });

      case ActionType.addMedication:
        await HealthService.instance.addMedication({
          'wallet_id': walletId,
          'name':      _str(d, 'name'),
          'is_active': true,
          if (d['dosage'] != null)    'dosage':    d['dosage'],
          if (d['frequency'] != null) 'frequency': d['frequency'],
        });

      case ActionType.addAppointment:
        await HealthService.instance.addAppointment({
          'wallet_id':   walletId,
          'doctor_name': _str(d, 'doctor_name'),
          if (d['appt_date'] != null)  'appt_date':  d['appt_date'],
          if (d['notes'] != null)      'notes':       d['notes'],
        });

      case ActionType.addVital:
        await HealthService.instance.addVital({
          'wallet_id':  walletId,
          'vital_type': _str(d, 'vital_type'),
          'value':      _num(d, 'value'),
          'member_id':  _str(d, 'member_id', fallback: 'me'),
          if (d['value2'] != null)   'value2':   d['value2'],
          if (d['sub_type'] != null) 'sub_type': d['sub_type'],
          if (d['notes'] != null)    'notes':    d['notes'],
        });

      case ActionType.addVaccination:
        await HealthService.instance.addVaccination({
          'wallet_id':    walletId,
          'vaccine_name': _str(d, 'vaccine_name'),
          'date_given':   _str(d, 'date_given', fallback: _today()),
          'member_id':    _str(d, 'member_id', fallback: 'me'),
          if (d['next_due'] != null)    'next_due':    d['next_due'],
          if (d['dose_number'] != null) 'dose_number': d['dose_number'],
          if (d['notes'] != null)       'notes':       d['notes'],
        });

      case ActionType.addDoctor:
        await HealthService.instance.addDoctor({
          'wallet_id': walletId,
          'name':      _str(d, 'name'),
          if (d['specialty'] != null)  'specialty':  d['specialty'],
          if (d['phone'] != null)      'phone':      d['phone'],
          if (d['hospital'] != null)   'hospital':   d['hospital'],
          if (d['notes'] != null)      'notes':      d['notes'],
        });

      case ActionType.addInsurance:
        await HealthService.instance.addInsurance({
          'wallet_id':   walletId,
          'policy_name': _str(d, 'policy_name'),
          'member_id':   _str(d, 'member_id', fallback: 'me'),
          if (d['provider'] != null)        'provider':        d['provider'],
          if (d['policy_number'] != null)   'policy_number':   d['policy_number'],
          if (d['coverage_amount'] != null) 'coverage_amount': d['coverage_amount'],
          if (d['expiry_date'] != null)     'expiry_date':     d['expiry_date'],
          if (d['notes'] != null)           'notes':           d['notes'],
        });
    }

    if (kDebugMode) debugPrint('[ActionExecutor] ${action.actionType.name} executed');
    return null;
    } catch (e, stack) {
      if (e is! TransactionLimitExceededException) {
        ErrorLogger.log(e,
            stackTrace: stack,
            severity: ErrorSeverity.error,
            action: 'ai_action_${action.actionType.name}');
      }
      rethrow;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _str(Map<String, dynamic> d, String key, {String fallback = ''}) =>
      (d[key] as String? ?? fallback).trim();

  // DB only accepts 'cash' or 'online' — normalize any AI value (upi/card/bank/other → online).
  String _payMode(Map<String, dynamic> d, {String fallback = 'cash'}) {
    final raw = _str(d, 'pay_mode', fallback: fallback).toLowerCase();
    return raw == 'cash' ? 'cash' : 'online';
  }

  double _num(Map<String, dynamic> d, String key, {double fallback = 0}) =>
      (d[key] as num?)?.toDouble() ?? fallback;

  DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  String _today() => DateTime.now().toIso8601String().split('T').first;
}
