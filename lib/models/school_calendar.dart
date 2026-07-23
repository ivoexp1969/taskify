/// Модели + чиста логика за „Училищен режим" (българска учебна година).
///
/// Данните идват от Firestore колекция `school_calendar` (документ по учебна
/// година) с вграден JSON fallback — виж [SchoolCalendarService]. Тук няма
/// зависимост от Firestore/Flutter → всичко е чисто и напълно тестваемо.
///
/// ВАЖНО: датите се менят всяка година (МОН издава заповед). Затова НИКОГА не
/// хардкодваме дати в логиката — четем ги от данните и при липса показваме
/// празно състояние ([SchoolPhase.noData]), не гадаем.
library;

/// Помощник: парсва дата от `String` (ISO 'YYYY-MM-DD' или пълен ISO) или от
/// `int` (millisecondsSinceEpoch). Връща само датата (без час), за да е
/// стабилно сравнението. null при невалидна стойност.
DateTime? parseSchoolDate(dynamic v) {
  if (v == null) return null;
  DateTime? d;
  if (v is int) {
    d = DateTime.fromMillisecondsSinceEpoch(v);
  } else if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return null;
    d = DateTime.tryParse(s);
  }
  if (d == null) return null;
  return DateTime(d.year, d.month, d.day);
}

/// Проверява дали клас [grade] попада в спецификация [spec] като „1-3", „7",
/// „1-11", „7,12" или празно/„all" (важи за всички). Толерантна към формата.
bool gradeMatches(int grade, String? spec) {
  final s = (spec ?? '').trim().toLowerCase();
  if (s.isEmpty || s == 'all' || s == '*' || s == '1-12') return true;
  for (final part in s.split(',')) {
    final p = part.trim();
    if (p.isEmpty) continue;
    if (p.contains('-')) {
      final bounds = p.split('-');
      if (bounds.length == 2) {
        final lo = int.tryParse(bounds[0].trim());
        final hi = int.tryParse(bounds[1].trim());
        if (lo != null && hi != null && grade >= lo && grade <= hi) return true;
      }
    } else {
      if (int.tryParse(p) == grade) return true;
    }
  }
  return false;
}

/// Период с име и интервал (ваканция или учебен срок).
class SchoolPeriod {
  final String key; // 'autumn' | 'winter' | 'midterm' | 'spring' | '' (срок)
  final String name; // оригинално име от данните (BG)
  final DateTime start;
  final DateTime end;
  final String? grades; // за кои класове важи (null = всички)

  const SchoolPeriod({
    required this.key,
    required this.name,
    required this.start,
    required this.end,
    this.grades,
  });

  static SchoolPeriod? fromJson(Map<String, dynamic> j) {
    final start = parseSchoolDate(j['start']);
    final end = parseSchoolDate(j['end']);
    if (start == null || end == null) return null;
    return SchoolPeriod(
      key: (j['key'] as String?)?.trim() ?? '',
      name: (j['name'] as String?)?.trim() ?? '',
      start: start,
      end: end,
      grades: (j['grades']?.toString().trim().isEmpty ?? true)
          ? null
          : j['grades'].toString().trim(),
    );
  }
}

/// Изпит (НВО / ДЗИ) с дата и за кои класове важи.
class SchoolExam {
  final String key;
  final String name;
  final DateTime date;
  final String? grades;
  final String? subject; // БЕЛ | Математика | … (по избор)
  final bool mandatory; // за 10. клас чуждият/ИТ са по избор

  const SchoolExam({
    required this.key,
    required this.name,
    required this.date,
    this.grades,
    this.subject,
    this.mandatory = true,
  });

  static SchoolExam? fromJson(Map<String, dynamic> j) {
    // Изключен изпит (напр. НВО отпадне) → не се показва. „Кодът не се пипа" —
    // Иво само маркира enabled:false във Firestore.
    if (j['enabled'] == false) return null;
    final date = parseSchoolDate(j['date']);
    if (date == null) return null;
    final subj = (j['subject'] as String?)?.trim();
    return SchoolExam(
      key: (j['key'] as String?)?.trim() ?? '',
      name: (j['name'] as String?)?.trim() ?? '',
      date: date,
      grades: (j['grades']?.toString().trim().isEmpty ?? true)
          ? null
          : j['grades'].toString().trim(),
      subject: (subj?.isEmpty ?? true) ? null : subj,
      mandatory: j['mandatory'] as bool? ?? true,
    );
  }
}

/// Край на учебната година за група класове (РАЗЛИЧЕН по клас — задължително).
class EndOfYearEntry {
  final String grades;
  final DateTime date;
  const EndOfYearEntry({required this.grades, required this.date});

  static EndOfYearEntry? fromJson(Map<String, dynamic> j) {
    final date = parseSchoolDate(j['date']);
    final grades = (j['grades']?.toString().trim() ?? '');
    if (date == null || grades.isEmpty) return null;
    return EndOfYearEntry(grades: grades, date: date);
  }
}

/// Пълните данни за една учебна година.
class SchoolYear {
  final String year; // "2026/2027"
  final String country; // "bg"
  final bool enabled;
  final bool official; // true само когато е потвърдено по заповед на МОН
  final String sourceNote;
  final DateTime? startOfYear;
  final List<SchoolPeriod> terms;
  final List<SchoolPeriod> vacations;
  final List<EndOfYearEntry> endOfYear;
  final List<SchoolExam> exams;

  const SchoolYear({
    required this.year,
    required this.country,
    required this.enabled,
    required this.official,
    required this.sourceNote,
    required this.startOfYear,
    required this.terms,
    required this.vacations,
    required this.endOfYear,
    required this.exams,
  });

  bool get hasData => enabled && (vacations.isNotEmpty || endOfYear.isNotEmpty);

  static List<T> _list<T>(
      dynamic raw, T? Function(Map<String, dynamic>) f) {
    if (raw is! List) return const [];
    final out = <T>[];
    for (final item in raw) {
      if (item is Map) {
        final parsed = f(Map<String, dynamic>.from(item));
        if (parsed != null) out.add(parsed);
      }
    }
    return out;
  }

  static SchoolYear fromJson(Map<String, dynamic> j) {
    return SchoolYear(
      year: (j['year'] as String?)?.trim() ?? '',
      country: (j['country'] as String?)?.trim().toLowerCase() ?? 'bg',
      enabled: j['enabled'] as bool? ?? false,
      official: j['official'] as bool? ?? false,
      sourceNote: (j['sourceNote'] as String?)?.trim() ?? '',
      startOfYear: parseSchoolDate(j['startOfYear']),
      terms: _list(j['terms'], SchoolPeriod.fromJson),
      vacations: _list(j['vacations'], SchoolPeriod.fromJson),
      endOfYear: _list(j['endOfYear'], EndOfYearEntry.fromJson),
      exams: _list(j['exams'], SchoolExam.fromJson),
    );
  }

  /// Краят на годината за конкретен клас (или null, ако не е дефиниран).
  DateTime? endOfYearFor(int grade) {
    for (final e in endOfYear) {
      if (gradeMatches(grade, e.grades)) return e.date;
    }
    return null;
  }

  /// Ваканциите, приложими за клас [grade], сортирани по начална дата.
  List<SchoolPeriod> vacationsFor(int grade) {
    final list =
        vacations.where((v) => gradeMatches(grade, v.grades)).toList();
    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  /// Предстоящите изпити за клас [grade] (дата >= today), сортирани.
  List<SchoolExam> upcomingExamsFor(int grade, DateTime today) {
    final t = DateTime(today.year, today.month, today.day);
    final list = exams
        .where((e) => gradeMatches(grade, e.grades) && !e.date.isBefore(t))
        .toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }
}

/// Фаза на училищния календар спрямо „днес".
enum SchoolPhase {
  beforeStart, // преди началото на учебната година (лято/подготовка)
  toVacation, // учи се; отброяваме до следваща ваканция
  inVacation, // в момента е ваканция
  toSummer, // учи се; следва краят на годината → лятна ваканция
  summerBreak, // годината приключи за този клас
  noData, // няма данни → празно състояние, НЕ гадаем
}

/// Резултат от изчислението на обратното броене.
class SchoolCountdown {
  final SchoolPhase phase;

  /// Брой ЦЕЛИ дни до целевата дата (за to*), или оставащи дни почивка
  /// (за inVacation). 0 = целта е днес.
  final int days;

  /// Ключ на ваканцията ('autumn'…), ако е приложим (за локализирано име).
  final String? vacationKey;

  /// Оригинално име от данните (fallback, ако ключът е непознат).
  final String? label;

  /// Целевата дата (начало на ваканция / край на година / край на ваканция).
  final DateTime? targetDate;

  const SchoolCountdown({
    required this.phase,
    this.days = 0,
    this.vacationKey,
    this.label,
    this.targetDate,
  });

  static const SchoolCountdown none = SchoolCountdown(phase: SchoolPhase.noData);
}

/// ЦЕЛИ дни между две дати (без час, стабилно при DST — през UTC).
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// ★ЯДРОТО★ — изчислява обратното броене за клас [grade] спрямо [now].
///
/// Гранични случаи (виж тестовете): днес е първи ден на ваканция; днес е
/// последен учебен ден; годината е свършила; няма данни.
SchoolCountdown computeCountdown({
  required DateTime now,
  required SchoolYear? year,
  required int grade,
}) {
  if (year == null || !year.hasData) return SchoolCountdown.none;

  final today = DateTime(now.year, now.month, now.day);
  final vacs = year.vacationsFor(grade);
  final endOfYear = year.endOfYearFor(grade);

  // 1) В момента във ваканция? (интервалите са включващи от двете страни)
  for (final v in vacs) {
    if (!today.isBefore(v.start) && !today.isAfter(v.end)) {
      return SchoolCountdown(
        phase: SchoolPhase.inVacation,
        days: daysBetween(today, v.end), // оставащи дни почивка (0 = последен)
        vacationKey: v.key,
        label: v.name,
        targetDate: v.end,
      );
    }
  }

  // 2) Годината приключила за този клас → лятна ваканция.
  if (endOfYear != null && today.isAfter(endOfYear)) {
    return SchoolCountdown(
      phase: SchoolPhase.summerBreak,
      targetDate: endOfYear,
    );
  }

  // 3) Преди началото на учебната година (лято/подготовка).
  if (year.startOfYear != null && today.isBefore(year.startOfYear!)) {
    return SchoolCountdown(
      phase: SchoolPhase.beforeStart,
      days: daysBetween(today, year.startOfYear!),
      targetDate: year.startOfYear,
    );
  }

  // 4) Учи се → следваща ваканция (start > днес).
  for (final v in vacs) {
    if (v.start.isAfter(today)) {
      return SchoolCountdown(
        phase: SchoolPhase.toVacation,
        days: daysBetween(today, v.start),
        vacationKey: v.key,
        label: v.name,
        targetDate: v.start,
      );
    }
  }

  // 5) Няма повече ваканции → отброяваме до края на годината (лятна ваканция).
  if (endOfYear != null && !today.isAfter(endOfYear)) {
    return SchoolCountdown(
      phase: SchoolPhase.toSummer,
      days: daysBetween(today, endOfYear),
      targetDate: endOfYear,
    );
  }

  // 6) Няма как да определим целта → празно състояние (не гадаем).
  return SchoolCountdown.none;
}
