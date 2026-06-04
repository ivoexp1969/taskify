/// Документ/задължение с дата на изтичане (винетка, ГО, тех. преглед, лична
/// карта, паспорт, шофьорска книжка, друго). Данните са изцяло локални —
/// потребителят въвежда своите дати, няма външен dataset.
///
/// Съхранява се като JSON в Hive box (без TypeAdapter / build_runner).
class ExpiringDocument {
  /// Уникален идентификатор.
  String id;

  /// Тип: 'vignette', 'insurance', 'inspection', 'id_card', 'passport',
  /// 'license', 'other'.
  String type;

  /// Свободно име (за тип 'other' или за разграничаване на няколко от един тип).
  String? label;

  /// Дата на изтичане (нормализирана към полунощ).
  DateTime expiryDate;

  /// Колко дни преди изтичането да напомни (по подразбиране 30/7/1).
  List<int> reminderDays;

  /// ID-та на планираните нотификации (за отмяна при редакция/изтриване).
  List<int> notificationIds;

  ExpiringDocument({
    required this.id,
    required this.type,
    this.label,
    required this.expiryDate,
    List<int>? reminderDays,
    List<int>? notificationIds,
  })  : reminderDays = reminderDays ?? const [30, 7, 1],
        notificationIds = notificationIds ?? [];

  /// Дни до изтичането (може да е отрицателно, ако е изтекъл).
  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return exp.difference(today).inDays;
  }

  bool get isExpired => daysLeft < 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'label': label,
        'expiryDate': expiryDate.toIso8601String(),
        'reminderDays': reminderDays,
        'notificationIds': notificationIds,
      };

  factory ExpiringDocument.fromJson(Map<String, dynamic> json) {
    return ExpiringDocument(
      id: json['id'] as String,
      type: (json['type'] as String?) ?? 'other',
      label: json['label'] as String?,
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      reminderDays: (json['reminderDays'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [30, 7, 1],
      notificationIds: (json['notificationIds'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
    );
  }
}
