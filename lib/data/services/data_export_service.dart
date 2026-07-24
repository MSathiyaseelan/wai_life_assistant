import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:wai_life_assistant/data/services/profile_service.dart';
import 'package:wai_life_assistant/data/services/wallet_service.dart';
import 'package:wai_life_assistant/data/services/pantry_service.dart';
import 'package:wai_life_assistant/data/services/task_service.dart';
import 'package:wai_life_assistant/data/services/reminder_service.dart';
import 'package:wai_life_assistant/data/services/note_service.dart';
import 'package:wai_life_assistant/data/services/wish_service.dart';
import 'package:wai_life_assistant/data/services/special_day_service.dart';
import 'package:wai_life_assistant/data/services/functions_service.dart';
import 'package:wai_life_assistant/data/services/item_locator_service.dart';
import 'package:wai_life_assistant/data/services/wardrobe_service.dart';
import 'package:wai_life_assistant/data/services/health_service.dart';

/// Builds a JSON export of everything in the user's own personal wallet —
/// this is the DPDP/data-portability "Export My Data" feature. Scoped to the
/// personal wallet only (not shared family wallets): a family-shared wallet
/// contains other members' contributions too, which aren't solely "your"
/// data to export unilaterally.
class DataExportService {
  DataExportService._();
  static final DataExportService instance = DataExportService._();

  /// Fetches everything and returns a pretty-printed JSON string.
  Future<String> buildExportJson() async {
    final switcherData = await ProfileService.instance.fetchSwitcherData();
    final walletId = switcherData?['personal_wallet_id'] as String?;
    if (walletId == null) {
      throw StateError('No personal wallet found for this account.');
    }

    final results = await Future.wait([
      WalletService.instance.fetchTransactions(walletId),
      WalletService.instance.fetchBills(walletId),
      PantryService.instance.fetchRecipes(walletId),
      PantryService.instance.fetchMealEntries(walletId),
      PantryService.instance.fetchGroceryItems(walletId),
      TaskService.instance.fetchTasks(walletId),
      ReminderService.instance.fetchReminders(walletId),
      NoteService.instance.fetchNotes(walletId),
      WishService.instance.fetchWishes(walletId),
      SpecialDayService.instance.fetchDays(walletId),
      FunctionsService.instance.fetchMyFunctions(walletId),
      FunctionsService.instance.fetchUpcoming(walletId),
      FunctionsService.instance.fetchAttended(walletId),
      ItemLocatorService.instance.fetchContainers(walletId),
      ItemLocatorService.instance.fetchItems(walletId),
      WardrobeService.instance.fetchItems(walletId),
      HealthService.instance.fetchMedications(walletId),
      HealthService.instance.fetchDoctors(walletId),
      HealthService.instance.fetchDocuments(walletId),
      HealthService.instance.fetchAppointments(walletId),
      HealthService.instance.fetchVitals(walletId),
      HealthService.instance.fetchVaccinations(walletId),
      HealthService.instance.fetchInsurance(walletId),
    ]);

    final healthProfile = await HealthService.instance.fetchProfile(walletId, 'me');

    final export = {
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'profile': {
        'name':  switcherData?['name'],
        'phone': switcherData?['phone'],
        'emoji': switcherData?['emoji'],
      },
      'wallet': {
        'transactions': results[0],
        'bills':        results[1],
      },
      'pantry': {
        'recipes':        results[2],
        'meal_entries':   results[3],
        'grocery_items':  results[4],
      },
      'planit': {
        'tasks':        results[5],
        'reminders':    results[6],
        'notes':        results[7],
        'wishes':       results[8],
        'special_days': results[9],
      },
      'functions': {
        'my_functions':   results[10],
        'upcoming':       results[11],
        'attended':       results[12],
      },
      'item_locator': {
        'containers': results[13],
        'items':      results[14],
      },
      'wardrobe': {
        'items': results[15],
      },
      'health': {
        'profile':       healthProfile?.toJson(),
        'medications':   results[16],
        'doctors':       results[17],
        'documents':     results[18],
        'appointments':  results[19],
        'vitals':        results[20],
        'vaccinations':  results[21],
        'insurance':     results[22],
      },
    };

    return const JsonEncoder.withIndent('  ').convert(export);
  }

  /// Writes the export to a temp file and returns its path, ready to hand
  /// to Share.shareXFiles.
  Future<File> writeExportFile() async {
    final json = await buildExportJson();
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File('${dir.path}/wai_data_export_$stamp.json');
    return file.writeAsString(json);
  }
}
