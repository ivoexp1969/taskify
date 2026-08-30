/// Модели за „Режим Студент" — български висши училища + профил на студента.
///
/// Данните за ВУЗ идват от вградения asset `assets/data/universities_bg.json`
/// (регистър НАЦИД/МОН). Имената на ВУЗ/специалности остават на български
/// независимо от езика на интерфейса (Ф6). Тук няма зависимост от Flutter →
/// чисто и тествамо.
///
/// ВАЖНО (Ограничение #2): НЕ измисляме ВУЗ и специалности. Списъкът с
/// факултети НЕ е наличен в регистъра на ниво asset → факултетът се въвежда
/// свободно от потребителя (free-text), а не се избира от подсказан списък,
/// за да не гадаем. Специалностите се предлагат само където asset-ът ги дава
/// изрично; иначе потребителят въвежда своята ръчно.
library;

/// Един ВУЗ от регистъра.
class University {
  final String id;
  final String name; // оригинално име (BG) — не се превежда
  final String short; // абревиатура (СУ, ТУ–София…)
  final List<String> programs; // примерни специалности (може да е празен)

  const University({
    required this.id,
    required this.name,
    required this.short,
    this.programs = const [],
  });

  /// „Друг университет" ли е (позволява ръчно въведено име по-нататък).
  bool get isOther => id == 'other';

  static University? fromJson(Map<String, dynamic> j) {
    final id = (j['id'] as String?)?.trim() ?? '';
    final name = (j['name'] as String?)?.trim() ?? '';
    if (id.isEmpty || name.isEmpty) return null;
    final rawPrograms = j['programs'];
    final programs = <String>[];
    if (rawPrograms is List) {
      for (final p in rawPrograms) {
        final s = p?.toString().trim() ?? '';
        if (s.isNotEmpty) programs.add(s);
      }
    }
    return University(
      id: id,
      name: name,
      short: (j['short'] as String?)?.trim() ?? name,
      programs: programs,
    );
  }
}

/// Форма на обучение.
enum StudyForm { regular, partTime, distance }

extension StudyFormKey on StudyForm {
  String get key {
    switch (this) {
      case StudyForm.regular:
        return 'redovno';
      case StudyForm.partTime:
        return 'zadochno';
      case StudyForm.distance:
        return 'distancionno';
    }
  }

  static StudyForm fromKey(String? k) {
    switch ((k ?? '').trim()) {
      case 'zadochno':
        return StudyForm.partTime;
      case 'distancionno':
        return StudyForm.distance;
      case 'redovno':
      default:
        return StudyForm.regular;
    }
  }
}

/// Профил на студента (пази се в SharedPreferences като JSON обект).
/// Форма: `{ uni_id, uni_name?, faculty, program, year, form }`.
///
/// `uniName` се пази само за id == 'other' (ръчно въведен ВУЗ). `faculty` е
/// свободен текст (може да е празен). `program` е избрана/въведена специалност.
class UniversityProfile {
  final String uniId;
  final String? uniName; // само за „Друг университет"
  final String faculty; // free-text (може празно)
  final String program; // специалност (избрана или ръчна)
  final int year; // курс 1–6
  final StudyForm form;

  /// Студентска група (free-text: „1", „12А", „III-B"…). Всяка група в един курс
  /// има различна програма. Незадължителна — може да се въведе после. Празно =
  /// не е зададена.
  final String groupNumber;

  /// Кога последно е синхронизирано автоматично разписанието (v3 hook). `null`
  /// за изцяло ръчно въведено разписание. Не се ползва в UI засега.
  final DateTime? lastScheduleSync;

  const UniversityProfile({
    required this.uniId,
    this.uniName,
    this.faculty = '',
    this.program = '',
    this.year = 1,
    this.form = StudyForm.regular,
    this.groupNumber = '',
    this.lastScheduleSync,
  });

  bool get isComplete => uniId.isNotEmpty && year >= 1 && year <= 6;

  UniversityProfile copyWith({
    String? uniId,
    String? uniName,
    String? faculty,
    String? program,
    int? year,
    StudyForm? form,
    String? groupNumber,
    DateTime? lastScheduleSync,
  }) {
    return UniversityProfile(
      uniId: uniId ?? this.uniId,
      uniName: uniName ?? this.uniName,
      faculty: faculty ?? this.faculty,
      program: program ?? this.program,
      year: year ?? this.year,
      form: form ?? this.form,
      groupNumber: groupNumber ?? this.groupNumber,
      lastScheduleSync: lastScheduleSync ?? this.lastScheduleSync,
    );
  }

  Map<String, dynamic> toJson() => {
        'uni_id': uniId,
        if (uniName != null && uniName!.isNotEmpty) 'uni_name': uniName,
        'faculty': faculty,
        'program': program,
        'year': year,
        'form': form.key,
        if (groupNumber.isNotEmpty) 'group': groupNumber,
        if (lastScheduleSync != null)
          'last_sync': lastScheduleSync!.toIso8601String(),
      };

  static UniversityProfile? fromJson(Map<String, dynamic> j) {
    final uniId = (j['uni_id'] as String?)?.trim() ?? '';
    if (uniId.isEmpty) return null;
    final rawYear = j['year'];
    final year = rawYear is int
        ? rawYear
        : int.tryParse(rawYear?.toString() ?? '') ?? 1;
    final rawSync = j['last_sync'];
    return UniversityProfile(
      uniId: uniId,
      uniName: (j['uni_name'] as String?)?.trim(),
      faculty: (j['faculty'] as String?)?.trim() ?? '',
      program: (j['program'] as String?)?.trim() ?? '',
      year: year.clamp(1, 6),
      form: StudyFormKey.fromKey(j['form'] as String?),
      groupNumber: (j['group'] as String?)?.trim() ?? '',
      lastScheduleSync: rawSync is String ? DateTime.tryParse(rawSync) : null,
    );
  }
}

/// Тип на ключова дата (за обратното броене). Общи за Ученик и Студент:
/// `schoolYearStart`/`termStart`/`vacation` са предимно ученически, а
/// `semester*`/`sessionStart` — студентски; `exam`/`other` важат за двамата.
enum StudentDateKind {
  schoolYearStart,
  termStart,
  vacation,
  semesterStart,
  semesterEnd,
  sessionStart,
  exam,
  other,
}

extension StudentDateKindKey on StudentDateKind {
  String get key {
    switch (this) {
      case StudentDateKind.schoolYearStart:
        return 'school_year_start';
      case StudentDateKind.termStart:
        return 'term_start';
      case StudentDateKind.vacation:
        return 'vacation';
      case StudentDateKind.semesterStart:
        return 'semester_start';
      case StudentDateKind.semesterEnd:
        return 'semester_end';
      case StudentDateKind.sessionStart:
        return 'session_start';
      case StudentDateKind.exam:
        return 'exam';
      case StudentDateKind.other:
        return 'other';
    }
  }

  static StudentDateKind fromKey(String? k) {
    switch ((k ?? '').trim()) {
      case 'school_year_start':
        return StudentDateKind.schoolYearStart;
      case 'term_start':
        return StudentDateKind.termStart;
      case 'vacation':
        return StudentDateKind.vacation;
      case 'semester_start':
        return StudentDateKind.semesterStart;
      case 'semester_end':
        return StudentDateKind.semesterEnd;
      case 'session_start':
        return StudentDateKind.sessionStart;
      case 'exam':
        return StudentDateKind.exam;
      default:
        return StudentDateKind.other;
    }
  }
}

/// Ръчно въведена ключова дата на студента (семестър/сесия/изпит).
class StudentKeyDate {
  final String id;
  final String title; // как я е нарекъл потребителят
  final DateTime date;
  final StudentDateKind kind;

  const StudentKeyDate({
    required this.id,
    required this.title,
    required this.date,
    required this.kind,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': DateTime(date.year, date.month, date.day).toIso8601String(),
        'kind': kind.key,
      };

  static StudentKeyDate? fromJson(Map<String, dynamic> j) {
    final id = (j['id'] as String?)?.trim() ?? '';
    final raw = j['date'];
    DateTime? d;
    if (raw is String) d = DateTime.tryParse(raw);
    if (raw is int) d = DateTime.fromMillisecondsSinceEpoch(raw);
    if (id.isEmpty || d == null) return null;
    return StudentKeyDate(
      id: id,
      title: (j['title'] as String?)?.trim() ?? '',
      date: DateTime(d.year, d.month, d.day),
      kind: StudentDateKindKey.fromKey(j['kind'] as String?),
    );
  }
}
