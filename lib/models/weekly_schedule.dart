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

  const ScheduleSlot({
    required this.id,
    required this.day,
    required this.fromMinutes,
    required this.toMinutes,
    required this.subject,
    required this.kind,
    this.location,
    this.term = 1,
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

  /// Припокрива ли се този слот с [other] по време в ЕДИН и същ ден И срок.
  /// Долепени слотове (край == начало на другия) НЕ се смятат за припокриване.
  /// Различни срокове/семестри никога не се припокриват.
  bool overlaps(ScheduleSlot other) {
    if (other.day != day || other.term != term) return false;
    return fromMinutes < other.toMinutes && other.fromMinutes < toMinutes;
  }

  ScheduleSlot copyWith({
    int? day,
    int? fromMinutes,
    int? toMinutes,
    String? subject,
    SlotKind? kind,
    String? location,
    int? term,
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
        if (location != null && location!.isNotEmpty) 'location': location,
      };

  static ScheduleSlot? fromJson(Map<String, dynamic> j) {
    final id = (j['id'] as String?)?.trim() ?? '';
    final day = j['day'] is int ? j['day'] as int : int.tryParse('${j['day']}');
    final from = j['from'] is int ? j['from'] as int : int.tryParse('${j['from']}');
    final to = j['to'] is int ? j['to'] as int : int.tryParse('${j['to']}');
    if (id.isEmpty || day == null || from == null || to == null) return null;
    if (day < 1 || day > 7) return null;
    final termRaw = j['term'] is int ? j['term'] as int : int.tryParse('${j['term']}');
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
    );
  }
}
