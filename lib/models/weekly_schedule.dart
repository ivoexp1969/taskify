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

  const ScheduleSlot({
    required this.id,
    required this.day,
    required this.fromMinutes,
    required this.toMinutes,
    required this.subject,
    required this.kind,
    this.location,
  });

  String _hhmm(int minutes) {
    final h = (minutes ~/ 60).clamp(0, 23);
    final m = (minutes % 60).clamp(0, 59);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String get fromLabel => _hhmm(fromMinutes);
  String get toLabel => _hhmm(toMinutes);

  ScheduleSlot copyWith({
    int? day,
    int? fromMinutes,
    int? toMinutes,
    String? subject,
    SlotKind? kind,
    String? location,
  }) {
    return ScheduleSlot(
      id: id,
      day: day ?? this.day,
      fromMinutes: fromMinutes ?? this.fromMinutes,
      toMinutes: toMinutes ?? this.toMinutes,
      subject: subject ?? this.subject,
      kind: kind ?? this.kind,
      location: location ?? this.location,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'day': day,
        'from': fromMinutes,
        'to': toMinutes,
        'subject': subject,
        'kind': kind.key,
        if (location != null && location!.isNotEmpty) 'location': location,
      };

  static ScheduleSlot? fromJson(Map<String, dynamic> j) {
    final id = (j['id'] as String?)?.trim() ?? '';
    final day = j['day'] is int ? j['day'] as int : int.tryParse('${j['day']}');
    final from = j['from'] is int ? j['from'] as int : int.tryParse('${j['from']}');
    final to = j['to'] is int ? j['to'] as int : int.tryParse('${j['to']}');
    if (id.isEmpty || day == null || from == null || to == null) return null;
    if (day < 1 || day > 7) return null;
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
    );
  }
}
