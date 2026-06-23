import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

typedef ContactEntry = ({String name, String phone});

// Singleton that loads device contacts once and caches them.
// Call preload() early (e.g. in initState of any screen that uses @-mention)
// so the list is ready before the user types '@'.
class ContactService {
  ContactService._();
  static final ContactService instance = ContactService._();

  List<ContactEntry>? _cache;
  Future<List<ContactEntry>>? _pending;

  void preload() {
    if (_cache != null || _pending != null) return;
    _pending = _load();
  }

  Future<List<ContactEntry>> getContacts() {
    if (_cache != null) return Future.value(_cache!);
    _pending ??= _load();
    return _pending!;
  }

  Future<List<ContactEntry>> _load() async {
    try {
      final status = await FlutterContacts.permissions.request(PermissionType.read);
      final granted = status == PermissionStatus.granted || status == PermissionStatus.limited;
      if (!granted) {
        _pending = null;
        return [];
      }
      final raw = await FlutterContacts.getAll(
        properties: {ContactProperty.name, ContactProperty.phone},
      );
      final list = <ContactEntry>[];
      for (final c in raw) {
        final name = (c.displayName ?? '').trim();
        if (name.isEmpty) continue;
        final phone = c.phones.isNotEmpty
            ? c.phones.first.number.replaceAll(RegExp(r'\D'), '')
            : '';
        list.add((name: name, phone: phone));
      }
      list.sort((a, b) => a.name.compareTo(b.name));
      _cache = list;
      return list;
    } catch (e) {
      debugPrint('[ContactService] load error: $e');
      _pending = null;
      return [];
    }
  }
}
