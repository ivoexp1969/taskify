import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weekly_schedule.dart';
import '../utils/uuid.dart';
import 'prefs_sync_service.dart';
import 'school_calendar_service.dart';
import 'university_service.dart';

/// ЕДИНСТВЕНИЯТ източник на истината дали часовете от седмичния разпис трябва да
/// се показват изобщо: само когато е включен режим Ученик (SchoolCalendarService)
/// ИЛИ Студент (UniversityService). Ползва се навсякъде (календар, карти), за да
/// няма дублирана логика — при изключен режим часовете се скриват навсякъде.
/// (Данните НЕ се трият; само се скриват.)
bool get scheduleVisible =>
    SchoolCalendarService().enabled || UniversityService().enabled;

/// Listenable, който се бумва и при промяна на разписа, и при вкл./изкл. на
/// режима — за да се пререндерират реактивно екраните, които показват часове.
final Listenable scheduleVisibilityListenable = Listenable.merge([
  WeeklyScheduleService.revision,
  SchoolCalendarService.enabledNotifier,
  UniversityService.enabledNotifier,
]);

/// Съхранява седмичния разпис (Режими Уча) в SharedPreferences като JSON списък.
/// Чист Dart, реактивен чрез [revision] (календарът/екранът се обновяват без
/// рестарт).
class WeeklyScheduleService {
  WeeklyScheduleService._internal();
  static final WeeklyScheduleService _instance =
      WeeklyScheduleService._internal();
  factory WeeklyScheduleService() => _instance;

  static const String _pref = 'weekly_schedule';
  static const String _prefTerm = 'weekly_schedule_term';
  // Отделен „речник" с всички някога въвеждани предмети. Расте и ОЦЕЛЯВА при
  // триене на слотове → веднъж въведен предмет остава като чип в „Добави час".
  // Чисто локален помощник (не се синхронизира); посява се от слотовете.
  static const String _prefSubjects = 'weekly_schedule_subjects';

  /// Бумва се при всяка промяна на разписа (вкл. смяна на текущия срок).
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  List<ScheduleSlot> _slots = const [];
  // Всички някога въвеждани предмети (display форма), дедупликирани без оглед на
  // регистъра, в реда на първо въвеждане. Триенето на слот НЕ ги маха.
  final List<String> _knownSubjects = [];
  bool _loaded = false;

  /// Текущо избран срок/семестър (1 или 2). Разписанието се въвежда и показва
  /// отделно за всеки срок; календарът показва слотовете на текущия срок.
  int _currentTerm = 1;
  int get currentTerm => _currentTerm;

  Future<void> setCurrentTerm(int term) async {
    final t = term == 2 ? 2 : 1;
    if (t == _currentTerm) return;
    _currentTerm = t;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefTerm, t);
    revision.value++;
    PrefsSyncService.markDirty('weekly_schedule');
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _parse(prefs.getString(_pref));
    _currentTerm = (prefs.getInt(_prefTerm) == 2) ? 2 : 1;
    _loadSubjects(prefs.getString(_prefSubjects));
    // Миграция/посев: вече съществуващите предмети в слотовете влизат в речника
    // (за хора, които вече имат разписание отпреди тази функция).
    if (_rememberSubjects(_slots.map((s) => s.subject))) {
      await _saveSubjects(prefs);
    }
    _loaded = true;
    // Опресни евентуалните слушатели (напр. лентата на календара), заредени
    // преди края на асинхронния load.
    if (_slots.isNotEmpty) revision.value++;
  }

  void _parse(String? raw) {
    if (raw == null) {
      _slots = const [];
      return;
    }
    try {
      final l = json.decode(raw);
      if (l is List) {
        _slots = l
            .whereType<Map>()
            .map((e) => ScheduleSlot.fromJson(Map<String, dynamic>.from(e)))
            .whereType<ScheduleSlot>()
            .toList();
        return;
      }
    } catch (e) {
      debugPrint('WeeklyScheduleService: parse failed → $e');
    }
    _slots = const [];
  }

  void _loadSubjects(String? raw) {
    _knownSubjects.clear();
    if (raw == null) return;
    try {
      final l = json.decode(raw);
      if (l is List) _rememberSubjects(l.whereType<String>());
    } catch (e) {
      debugPrint('WeeklyScheduleService: subjects parse failed → $e');
    }
  }

  /// Добавя име(на) към речника с предмети (trim, без празни, дедупликация без
  /// оглед на регистъра — пази първото изписване). Връща true, ако е добавено
  /// поне едно ново.
  bool _rememberSubjects(Iterable<String> names) {
    final seen = {for (final s in _knownSubjects) s.toLowerCase()};
    var changed = false;
    for (final raw in names) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      if (seen.add(name.toLowerCase())) {
        _knownSubjects.add(name);
        changed = true;
      }
    }
    return changed;
  }

  Future<void> _saveSubjects([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(_prefSubjects, json.encode(_knownSubjects));
  }

  /// Всички слотове (несортирани).
  List<ScheduleSlot> get all => List.unmodifiable(_slots);

  /// Слотовете за конкретен ден (1=пон … 7=нед), сортирани по начален час.
  /// По подразбиране връща само текущия срок; подай [term] за конкретен срок.
  List<ScheduleSlot> forDay(int day, {int? term}) {
    final t = term ?? _currentTerm;
    final list = _slots.where((s) => s.day == day && s.term == t).toList();
    list.sort((a, b) => a.fromMinutes.compareTo(b.fromMinutes));
    return list;
  }

  /// Слотовете за деня, филтрирани по четна/нечетна седмица спрямо началото на
  /// семестъра. Ако [semesterStart] е null → връща всички (без филтър, защото
  /// не можем да определим номера на седмицата). Използва се от днешната карта.
  List<ScheduleSlot> visibleForDay(
    int day,
    DateTime date,
    DateTime? semesterStart, {
    int? term,
  }) {
    final wk = currentWeekNumber(semesterStart, date);
    return forDay(day, term: term).where((s) => s.matchesWeek(wk)).toList();
  }

  /// Празно ли е разписанието за срок (по подразбиране — текущия).
  bool isEmptyForTerm([int? term]) {
    final t = term ?? _currentTerm;
    return !_slots.any((s) => s.term == t);
  }

  /// Съществуващият цвят на предмет със същото име (case-insensitive) в кой да е
  /// слот, или `null`. За авто-предложение на цвят в диалога.
  int? colorForSubject(String subject) {
    final key = subject.trim().toLowerCase();
    if (key.isEmpty) return null;
    for (final s in _slots) {
      if (s.colorValue != null && s.subject.trim().toLowerCase() == key) {
        return s.colorValue;
      }
    }
    return null;
  }

  /// Всички някога въвеждани предмети — за чиповете за бърз избор в „Добави час".
  /// Идва от растящия речник [_knownSubjects], затова предмет ОСТАВА тук дори след
  /// като часът му е изтрит. Подредба: най-ползваните в текущите слотове първи,
  /// после останалите азбучно (дедупликация без оглед на регистъра).
  List<String> get distinctSubjects {
    final counts = <String, int>{};
    for (final s in _slots) {
      final key = s.subject.trim().toLowerCase();
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final list = List<String>.from(_knownSubjects);
    list.sort((a, b) {
      final byFreq = (counts[b.toLowerCase()] ?? 0)
          .compareTo(counts[a.toLowerCase()] ?? 0);
      return byFreq != 0 ? byFreq : a.toLowerCase().compareTo(b.toLowerCase());
    });
    return list;
  }

  bool get isEmpty => _slots.isEmpty;

  /// Връща първия съществуващ слот, който се припокрива по време с [candidate]
  /// в същия ден (пропуска самия него по id), или `null` ако няма конфликт.
  /// Използва се за да НЕ допускаме два часа/събития в едно и също време.
  ScheduleSlot? firstConflict(ScheduleSlot candidate) {
    for (final s in _slots) {
      if (s.id == candidate.id) continue;
      if (candidate.overlaps(s)) return s;
    }
    return null;
  }

  Future<void> upsert(ScheduleSlot slot) async {
    final idx = _slots.indexWhere((s) => s.id == slot.id);
    final next = List<ScheduleSlot>.from(_slots);
    if (idx >= 0) {
      next[idx] = slot;
    } else {
      next.add(slot);
    }
    _slots = next;
    // Запомни предмета завинаги (расте речникът, оцелява при триене на слота).
    if (_rememberSubjects([slot.subject])) {
      await _saveSubjects();
    }
    await _persist();
  }

  /// Създава нов слот (генерира id).
  ScheduleSlot newSlot({
    required int day,
    required int fromMinutes,
    required int toMinutes,
    required String subject,
    required SlotKind kind,
    String? location,
    int? term,
    WeekPattern weekPattern = WeekPattern.every,
    int? colorValue,
    String? source,
  }) {
    return ScheduleSlot(
      id: Uuid.v4(),
      day: day,
      fromMinutes: fromMinutes,
      toMinutes: toMinutes,
      subject: subject,
      kind: kind,
      location: location,
      term: term ?? _currentTerm,
      weekPattern: weekPattern,
      colorValue: colorValue,
      source: source,
    );
  }

  /// Изтрива ВСИЧКИ слотове (напр. при смяна на студентска група). Необратимо.
  Future<void> clearAll() async {
    _slots = const [];
    await _persist();
  }

  Future<void> remove(String id) async {
    _slots = _slots.where((s) => s.id != id).toList();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _pref, json.encode(_slots.map((s) => s.toJson()).toList()));
    revision.value++;
    PrefsSyncService.markDirty('weekly_schedule');
  }

  /// Прилага облачно състояние (cross-device sync) БЕЗ да задейства нов push.
  /// Пише директно в SharedPreferences (не минава през [_persist], за да не
  /// стампне „локална промяна"). Виж [PrefsSyncService].
  Future<void> applyFromSync(List<ScheduleSlot> slots, int term) async {
    _slots = List.unmodifiable(slots);
    _currentTerm = term == 2 ? 2 : 1;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _pref, json.encode(_slots.map((s) => s.toJson()).toList()));
    await prefs.setInt(_prefTerm, _currentTerm);
    // Посей речника и от синкнатите слотове (предметите остават локално, дори
    // ако по-късно съответният слот бъде изтрит на друго устройство).
    if (_rememberSubjects(_slots.map((s) => s.subject))) {
      await _saveSubjects(prefs);
    }
    revision.value++;
  }
}
