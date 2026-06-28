import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/bg_translit.dart';

/// Локален индекс „кои контакти празнуват имен ден".
///
/// PRIVACY: четенето на контакти е 100% on-device. Нищо не се качва в облак/
/// Firestore. Изграждаме ЕДНОКРАТНО индекс (нормализирано име → display names)
/// и го кешираме в Hive, за да не сканираме целия адресник при всяко отваряне.
/// Функцията е по подразбиране ИЗКЛЮЧЕНА и работи само след изричното ѝ
/// включване от потребителя (тогава се иска и системното разрешение).
///
/// При изключване кешът се трие. Уеб няма контакти → всичко тук е no-op там.
class ContactNameIndex {
  ContactNameIndex._internal();
  static final ContactNameIndex _instance = ContactNameIndex._internal();
  factory ContactNameIndex() => _instance;

  static const String _prefEnabled = 'name_day_contacts_enabled';
  static const String _boxName = 'bg_contact_index';
  static const String _kIndex = 'index'; // Map<String, List<String>>
  static const String _kBuiltAt = 'builtAt'; // int millis

  /// Реактивен флаг за UI (банерът в календара слуша този notifier).
  final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(false);

  /// In-memory индекс: ключ (`c:`/`l:`) → множество display names.
  Map<String, Set<String>>? _index;
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
      final raw = b.get(_kIndex);
      _builtAt = (b.get(_kBuiltAt) as int?) ?? 0;
      if (raw is Map) {
        final idx = <String, Set<String>>{};
        raw.forEach((k, v) {
          if (v is List) {
            idx[k.toString()] = v.map((e) => e.toString()).toSet();
          }
        });
        _index = idx;
      } else {
        _index = <String, Set<String>>{};
      }
    } catch (_) {
      _index = <String, Set<String>>{};
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
      // Без properties/снимки — нужни са само имената; минимум данни.
      final contacts = await FlutterContacts.getContacts(
        withProperties: false,
        withPhoto: false,
      );
      final idx = <String, Set<String>>{};
      for (final c in contacts) {
        final display = c.displayName.trim();
        if (display.isEmpty) continue;
        for (final word in _words(display)) {
          for (final key in BgTranslit.keysFor(word)) {
            (idx[key] ??= <String>{}).add(display);
          }
        }
      }
      _index = idx;
      _builtAt = DateTime.now().millisecondsSinceEpoch;
      await _persist(idx);
    } catch (_) {
      // тих fail
    } finally {
      _building = false;
    }
  }

  Future<void> _persist(Map<String, Set<String>> idx) async {
    if (kIsWeb) return;
    try {
      final b = await _box();
      final flat = idx.map((k, v) => MapEntry(k, v.toList()));
      await b.put(_kIndex, flat);
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

  /// Връща сортиран списък с display names на контактите, които празнуват
  /// (сред подадените имена за деня). Синхронно — ползва вече заредения индекс.
  List<String> contactsForNames(List<String> names) {
    if (!isEnabled || kIsWeb) return const [];
    final idx = _index;
    if (idx == null || idx.isEmpty) return const [];
    final out = <String>{};
    for (final name in names) {
      for (final key in BgTranslit.keysFor(name)) {
        final hit = idx[key];
        if (hit != null) out.addAll(hit);
      }
    }
    final list = out.toList()..sort();
    return list;
  }
}
