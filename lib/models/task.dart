import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'task.g.dart';

@HiveType(typeId: 0)
class Task extends HiveObject with EquatableMixin {
  /// Заглавие на задачата
  @HiveField(0)
  String title;

  /// Срок на задачата (дата + евентуално час)
  @HiveField(1)
  DateTime dueDate;

  /// Id на категорията (връзка към Category.id)
  @HiveField(2)
  String categoryId;

  /// Приоритет: 0 = low, 1 = medium, 2 = high
  @HiveField(3)
  int priority;

  /// Завършена ли е задачата
  @HiveField(4)
  bool isCompleted;

  /// Повтаряемост: 'daily', 'weekly', 'monthly', 'yearly' или null (без повторение)
  @HiveField(5)
  String? recurrence;

  /// DEPRECATED - използвай reminders
  /// Напомняне (единично) - запазено за съвместимост със стари данни
  @HiveField(6)
  String? reminder;

  /// ID на планираната нотификация (локален notification id),
  /// за да можем да я отменим при изтриване/редакция.
  /// DEPRECATED - използвай notificationIds
  @HiveField(7)
  int? notificationId;

  /// Подзадачи - списък от strings във формат "0:текст" или "1:текст"
  /// където 0 = незавършена, 1 = завършена
  @HiveField(8)
  List<String>? subtasks;

  /// Множество напомняния:
  /// 'at_time'    = в точното време
  /// 'minus_5m'   = 5 минути преди
  /// 'minus_15m'  = 15 минути преди
  /// 'minus_30m'  = 30 минути преди
  /// 'minus_1h'   = 1 час преди
  /// 'minus_2h'   = 2 часа преди
  /// 'minus_1d'   = 1 ден преди
  /// 'same_day_8' = в същия ден в 08:00
  @HiveField(9)
  List<String>? reminders;

  /// Списък с ID-та на планирани нотификации
  @HiveField(10)
  List<int>? notificationIds;

  /// Бележки / допълнителна информация към задачата
  @HiveField(11)
  String? notes;

  /// Дата и час на завършване
  @HiveField(12)
  DateTime? completedAt;

  /// Дали задачата е архивирана
  @HiveField(13, defaultValue: false)
  bool isArchived;

  /// Дата и час на архивиране
  @HiveField(14)
  DateTime? archivedAt;

  Task({
    required this.title,
    required this.dueDate,
    required this.categoryId,
    required this.priority,
    this.isCompleted = false,
    this.recurrence,
    this.reminder,
    this.notificationId,
    this.subtasks,
    this.reminders,
    this.notificationIds,
    this.notes,
    this.completedAt,
    this.isArchived = false,
    this.archivedAt,
  });

  /// Помощен getter - връща reminders или мигрира от старото reminder
  List<String> get remindersList {
    if (reminders != null && reminders!.isNotEmpty) {
      return reminders!;
    }
    // Миграция от старото поле
    if (reminder != null && reminder != 'none') {
      return [reminder!];
    }
    return [];
  }

  /// Помощен setter
  void setReminders(List<String> list) {
    reminders = list.isEmpty ? null : list;
    // Изчистваме старото поле
    reminder = null;
  }

  /// Проверка дали има напомняния
  bool get hasReminders => remindersList.isNotEmpty;

  /// Проверка дали има бележки
  bool get hasNotes => notes != null && notes!.trim().isNotEmpty;

  /// Помощни методи за подзадачи
  List<Map<String, dynamic>> get subtasksList {
    if (subtasks == null || subtasks!.isEmpty) return [];
    return subtasks!.map((s) {
      final parts = s.split(':');
      final done = parts[0] == '1';
      final text = parts.length > 1 ? parts.sublist(1).join(':') : '';
      return {'done': done, 'text': text};
    }).toList();
  }

  void setSubtasks(List<Map<String, dynamic>> list) {
    subtasks = list.map((item) {
      final done = item['done'] == true ? '1' : '0';
      final text = item['text'] ?? '';
      return '$done:$text';
    }).toList();
  }

  int get completedSubtasksCount {
    if (subtasks == null) return 0;
    return subtasks!.where((s) => s.startsWith('1:')).length;
  }

  int get totalSubtasksCount => subtasks?.length ?? 0;

  @override
  List<Object?> get props => [
        key,
        title,
        dueDate,
        categoryId,
        priority,
        isCompleted,
        recurrence,
        reminder,
        notificationId,
        subtasks,
        reminders,
        notificationIds,
        notes,
        completedAt,
        isArchived,
        archivedAt,
      ];
}