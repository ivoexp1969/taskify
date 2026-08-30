/// Модел за седмичния разпис (Режими Уча) — прости слотове уроци/лекции.
///
/// Не е пълно разписание: всеки слот е ден + начало/край + предмет + тип +
/// незадължително място. Пази се в SharedPreferences (виж [WeeklyScheduleService]).
/// Чист Dart → тествамо, без Flutter зависимост.
library;

/// Вид на слота: урок (ученик) или лекция (студент). Пази се като ключ.
enum SlotKind { lesson, lecture }

extension SlotKindKey on SlotKind {
  String get key => this == SlotKind.lecture ? 'lecture' : 'lesson';
  static SlotKind fromKey(String? k) =>
      (k ?? '').trim() == 'lecture' ? SlotKind.lecture : SlotKind.lesson;
}

/// Повторение по седмица (реалност в българските ВУЗ): една лекция може да е
/// всяка седмица, само в четни или само в нечетни седмици от началото на
/// семестъра. Пази се като ключ; старите слотове (без поле) са [every].
enum WeekPattern { every, oddOnly, evenOnly }

extension WeekPatternKey on WeekPattern {
  String get key {
    switch (this) {
      case WeekPattern.oddOnly:
        return 'odd';
      case WeekPattern.evenOnly:
        return 'even';
      case WeekPattern.every:
        return 'every';
    }
  }

  static WeekPattern fromKey(String? k) {
    switch ((k ?? '').trim()) {
      case 'odd':
        return WeekPattern.oddOnly;
      case 'even':
        return WeekPattern.evenOnly;
      default:
        return WeekPattern.every;
    }
  }
}

/// Брой цели дни между две дати (без часове), устойчиво на смяна на лятно/зимно
/// часово време — брои се по календарни дни, не по 24-часови интервали.
int _epochDay(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

/// Номер на текущата седмица (1-базиран) от началото на семестъра.
///
/// Стандарт в българските ВУЗ: първата седмица на семестъра = седмица 1
/// (нечетна). Броят се календарни седмици от [semesterStart], не ISO номерът.
/// Връща 0, ако семестърът още не е започнал ИЛИ датата е неизвестна
/// ([semesterStart] == null) — тогава разписанието се показва без филтър.
int currentWeekNumber(DateTime? semesterStart, DateTime today) {
  if (semesterStart == null) return 0;
  final diff = _epochDay(today) - _epochDay(semesterStart);
  if (diff < 0) return 0;
  return (diff ~/ 7) + 1;
}

/// Един слот от разписа.
class ScheduleSlot {
  final String id;

  /// Ден от седмицата: 1 = понеделник … 7 = неделя (ISO).
  final int day;

  /// Начало/край в минути от полунощ (напр. 8*60 = 480 за 08:00).
  final int fromMinutes;
  final int toMinutes;

  final String subject;
  final SlotKind kind;
  final String? location;

  /// Учебен срок (ученик) / семестър (студент): 1 или 2. Разписанието се
  /// въвежда отделно за всеки срок. Старите слотове (без поле) са срок 1.
  final int term;

  /// Повторение по седмица (четна/нечетна/всяка). Ортогонално на [term]:
  /// [term] = кой семестър, [weekPattern] = кои седмици ВЪТРЕ в семестъра.
  /// Старите слотове (без поле) са [WeekPattern.every].
  final WeekPattern weekPattern;

  /// Цвят на предмета (ARGB), по избор. `null` → използва се темата.
  final int? colorValue;

  /// Произход на слота: `null`/`manual` = ръчно въведен; `mu-sofia`/`su`/… за
  /// бъдещо автоматично извличане (v3). Не се ползва в UI засега.
  final String? source;

  const ScheduleSlot({
    required this.id,
    required this.day,
    required this.fromMinutes,
    required this.toMinutes,
    required this.subject,
    required this.kind,
    this.location,
    this.term = 1,
    this.weekPattern = WeekPattern.every,
    this.colorValue,
    this.source,
  });

  String _hhmm(int minutes) {
    final h = (minutes ~/ 60).clamp(0, 23);
    final m = (minutes % 60).clamp(0, 59);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String get fromLabel => _hhmm(fromMinutes);
  String get toLabel => _hhmm(toMinutes);

  /// Валиден ли е интервалът (краят е строго след началото).
  bool get hasValidRange => toMinutes > fromMinutes;

  /// Съвпадат ли изобщо седмичните шаблони на два слота (могат ли да се случат
  /// в една и съща седмица). „Всяка" съвпада с всичко; четна+нечетна — никога.
  static bool _weeksCanCoincide(WeekPattern a, WeekPattern b) {
    if (a == WeekPattern.every || b == WeekPattern.every) return true;
    return a == b;
  }

  /// Припокрива ли се този слот с [other] по време в ЕДИН и същ ден И срок.
  /// Долепени слотове (край == начало на другия) НЕ се смятат за припокриване.
  /// Различни срокове/семестри никога не се припокриват. Слот „само четна" и
  /// слот „само нечетна" в един час също НЕ се припокриват (различни седмици).
  bool overlaps(ScheduleSlot other) {
    if (other.day != day || other.term != term) return false;
    if (!_weeksCanCoincide(weekPattern, other.weekPattern)) return false;
    return fromMinutes < other.toMinutes && other.fromMinutes < toMinutes;
  }

  /// Показва ли се този слот в седмица номер [weekNumber] (1-базиран от началото
  /// на семестъра). [weekNumber] <= 0 (преди семестъра / неизвестно начало) →
  /// показва всичко, защото не можем да определим четна/нечетна.
  bool matchesWeek(int weekNumber) {
    if (weekPattern == WeekPattern.every || weekNumber <= 0) return true;
    final isEven = weekNumber % 2 == 0;
    return weekPattern == WeekPattern.evenOnly ? isEven : !isEven;
  }

  ScheduleSlot copyWith({
    int? day,
    int? fromMinutes,
    int? toMinutes,
    String? subject,
    SlotKind? kind,
    String? location,
    int? term,
    WeekPattern? weekPattern,
    int? colorValue,
    bool clearColor = false,
    String? source,
  }) {
    return ScheduleSlot(
      id: id,
      day: day ?? this.day,
      fromMinutes: fromMinutes ?? this.fromMinutes,
      toMinutes: toMinutes ?? this.toMinutes,
      subject: subject ?? this.subject,
      kind: kind ?? this.kind,
      location: location ?? this.location,
      term: term ?? this.term,
      weekPattern: weekPattern ?? this.weekPattern,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'day': day,
        'from': fromMinutes,
        'to': toMinutes,
        'subject': subject,
        'kind': kind.key,
        'term': term,
        if (weekPattern != WeekPattern.every) 'week': weekPattern.key,
        if (colorValue != null) 'color': colorValue,
        if (location != null && location!.isNotEmpty) 'location': location,
        if (source != null && source!.isNotEmpty) 'source': source,
      };

  static ScheduleSlot? fromJson(Map<String, dynamic> j) {
    final id = (j['id'] as String?)?.trim() ?? '';
    final day = j['day'] is int ? j['day'] as int : int.tryParse('${j['day']}');
    final from = j['from'] is int ? j['from'] as int : int.tryParse('${j['from']}');
    final to = j['to'] is int ? j['to'] as int : int.tryParse('${j['to']}');
    if (id.isEmpty || day == null || from == null || to == null) return null;
    if (day < 1 || day > 7) return null;
    final termRaw = j['term'] is int ? j['term'] as int : int.tryParse('${j['term']}');
    final colorRaw =
        j['color'] is int ? j['color'] as int : int.tryParse('${j['color']}');
    return ScheduleSlot(
      id: id,
      day: day,
      fromMinutes: from,
      toMinutes: to,
      subject: (j['subject'] as String?)?.trim() ?? '',
      kind: SlotKindKey.fromKey(j['kind'] as String?),
      location: (j['location'] as String?)?.trim().isEmpty ?? true
          ? null
          : (j['location'] as String).trim(),
      term: (termRaw == 2) ? 2 : 1,
      weekPattern: WeekPatternKey.fromKey(j['week'] as String?),
      colorValue: colorRaw,
      source: (j['source'] as String?)?.trim().isEmpty ?? true
          ? null
          : (j['source'] as String).trim(),
    );
  }
}
