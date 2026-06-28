import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/bg_translit.dart';

/// Един съвпаднал контакт: стабилен id (за теглене на телефон при нужда) + име.
class ContactMatch {
  final String id;
  final String name;
  const ContactMatch(this.id, this.name);
}

/// Локален индекс „кои контакти празнуват имен ден".
///
/// PRIVACY: четенето на контакти е 100% on-device. Нищо не се качва в облак/
/// Firestore. Изграждаме ЕДНОКРАТНО индекс (нормализирано име → contact id) и
/// го кешираме в Hive, за да не сканираме целия адресник при всяко отваряне.
/// Телефонните номера НЕ се кешират — теглят се при нужда (`phonesForContact`),
/// когато потребителят натисне „Обаждане/WhatsApp/…". Функцията е по
/// подразбиране ИЗКЛЮЧЕНА и работи само след изричното ѝ включване (тогава се
/// иска и системното разрешение). При изключване кешът се трие. Уеб = no-op.
class ContactNameIndex {
  ContactNameIndex._internal();
  static final ContactNameIndex _instance = ContactNameIndex._internal();
  factory ContactNameIndex() => _instance;

  static const String _prefEnabled = 'name_day_contacts_enabled';
  static const String _boxName = 'bg_contact_index';
  static const String _kIndex = 'index_v2'; // Map<String, List<String ids>>
  static const String _kNames = 'names_v2'; // Map<String id, String display>
  static const String _kBuiltAt = 'builtAt'; // int millis

  /// Реактивен флаг за UI (банерът в календара слуша този notifier).
  final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(false);

  /// In-memory индекс: ключ (`c:`/`l:`) → множество contact id-та.
  Map<String, Set<String>>? _index;
  // id → display name (за показване).
  Map<String, String> _names = {};
  bool _building = false;
  int _builtAt = 0;

  bool get isEnabled => enabledNotifier.value;
  int get builtAtMillis => _builtAt;
  bool get isBuilding => _building;

  // --- Настройка ---

  Future<bool> loadEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getBool(_prefEnabled) ?? false;
    enabledNotifier.value = v;
    return v;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, value);
    enabledNotifier.value = value;
    if (!value) {
      // Privacy: при изключване не задържаме нищо от адресника.
      _index = null;
      _names = {};
      _builtAt = 0;
      await _clearCache();
    }
  }

  /// Иска системното разрешение за четене на контакти (read-only).
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      return await FlutterContacts.requestPermission(readonly: true);
    } catch (_) {
      return false;
    }
  }

  // --- Индекс ---

  Future<Box> _box() async => Hive.isBoxOpen(_boxName)
      ? Hive.box(_boxName)
      : await Hive.openBox(_boxName);

  Future<void> _clearCache() async {
    if (kIsWeb) return;
    try {
      final b = await _box();
      await b.clear();
    } catch (_) {}
  }

  /// Зарежда кешираните данни в паметта (без сканиране на контакти).
  Future<void> ensureLoaded() async {
    if (_index != null || kIsWeb) return;
    try {
      final b = await _box();
      _builtAt = (b.get(_kBuiltAt) as int?) ?? 0;
      final rawIdx = b.get(_kIndex);
      final rawNames = b.get(_kNames);
      final idx = <String, Set<String>>{};
      if (rawIdx is Map) {
        rawIdx.forEach((k, v) {
          if (v is List) {
            idx[k.toString()] = v.map((e) => e.toString()).toSet();
          }
        });
      }
      final names = <String, String>{};
      if (rawNames is Map) {
        rawNames.forEach((k, v) => names[k.toString()] = v.toString());
      }
      _index = idx;
      _names = names;
    } catch (_) {
      _index = <String, Set<String>>{};
      _names = {};
    }
  }

  /// Сканира контактите ЕДНОКРАТНО и преизгражда индекса. Иска разрешение
  /// при нужда. Тих fail при отказ/грешка (UI просто няма съвпадения).
  Future<void> rebuild() async {
    if (kIsWeb || _building) return;
    _building = true;
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) return;
      // Без properties/снимки — за индекса трябват само имената; минимум данни.
      final contacts = await FlutterContacts.getContacts(
        withProperties: false,
        withPhoto: false,
      );
      final idx = <String, Set<String>>{};
      final names = <String, String>{};
      for (final c in contacts) {
        final display = c.displayName.trim();
        if (display.isEmpty) continue;
        names[c.id] = display;
        for (final word in _words(display)) {
          for (final key in BgTranslit.keysFor(word)) {
            (idx[key] ??= <String>{}).add(c.id);
          }
        }
      }
      _index = idx;
      _names = names;
      _builtAt = DateTime.now().millisecondsSinceEpoch;
      await _persist(idx, names);
    } catch (_) {
      // тих fail
    } finally {
      _building = false;
    }
  }

  Future<void> _persist(
      Map<String, Set<String>> idx, Map<String, String> names) async {
    if (kIsWeb) return;
    try {
      final b = await _box();
      final flat = idx.map((k, v) => MapEntry(k, v.toList()));
      await b.put(_kIndex, flat);
      await b.put(_kNames, names);
      await b.put(_kBuiltAt, _builtAt);
    } catch (_) {}
  }

  /// Думите от името на контакт: разделя по интервал/точка, маха инициали
  /// (една буква) и числа. Така „Иван Петров", „Петров Иван", „Иван и Мария",
  /// „Ivan P." дават правилните думи за съвпадане.
  Iterable<String> _words(String name) {
    return name
        .split(RegExp(r'[\s.]+'))
        .map((w) => w.trim())
        .where((w) => w.length > 1 && !RegExp(r'^\d+$').hasMatch(w));
  }

  // --- Заявка ---

  /// Връща сортирани съвпаднали контакти (id + display name) сред подадените
  /// имена за деня. Синхронно — ползва вече заредения индекс.
  List<ContactMatch> contactsForNames(List<String> names) {
    if (!isEnabled || kIsWeb) return const [];
    final idx = _index;
    if (idx == null || idx.isEmpty) return const [];
    final ids = <String>{};
    for (final name in names) {
      for (final key in BgTranslit.keysFor(name)) {
        final hit = idx[key];
        if (hit != null) ids.addAll(hit);
      }
    }
    final list = ids
        .map((id) => ContactMatch(id, _names[id] ?? id))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Тегли телефонните номера на контакт ПРИ НУЖДА (не се кешират).
  /// Връща празно при липса/грешка/уеб.
  Future<List<String>> phonesForContact(String id) async {
    if (kIsWeb) return const [];
    try {
      final c = await FlutterContacts.getContact(
        id,
        withProperties: true,
        withPhoto: false,
      );
      if (c == null) return const [];
      return c.phones
          .map((p) => p.number.trim())
          .where((n) => n.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
