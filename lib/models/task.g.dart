// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Task(
      title: fields[0] as String,
      dueDate: fields[1] as DateTime,
      categoryId: fields[2] as String,
      priority: fields[3] as int,
      isCompleted: fields[4] as bool,
      recurrence: fields[5] as String?,
      reminder: fields[6] as String?,
      notificationId: fields[7] as int?,
      subtasks: (fields[8] as List?)?.cast<String>(),
      reminders: (fields[9] as List?)?.cast<String>(),
      notificationIds: (fields[10] as List?)?.cast<int>(),
      notes: fields[11] as String?,
      completedAt: fields[12] as DateTime?,
      isArchived: fields[13] == null ? false : fields[13] as bool,
      archivedAt: fields[14] as DateTime?,
      googleCalendarEventId: fields[15] as String?,
      durationMinutes: fields[16] as int?,
      template: fields[17] as String?,
      importedFromCalendar: fields[18] as bool?,
      id: fields[19] as String?,
      updatedAt: fields[20] as DateTime?,
      deleted: fields[21] == null ? false : fields[21] as bool,
      deletedAt: fields[22] as DateTime?,
      appleEventId: fields[23] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(24)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.dueDate)
      ..writeByte(2)
      ..write(obj.categoryId)
      ..writeByte(3)
      ..write(obj.priority)
      ..writeByte(4)
      ..write(obj.isCompleted)
      ..writeByte(5)
      ..write(obj.recurrence)
      ..writeByte(6)
      ..write(obj.reminder)
      ..writeByte(7)
      ..write(obj.notificationId)
      ..writeByte(8)
      ..write(obj.subtasks)
      ..writeByte(9)
      ..write(obj.reminders)
      ..writeByte(10)
      ..write(obj.notificationIds)
      ..writeByte(11)
      ..write(obj.notes)
      ..writeByte(12)
      ..write(obj.completedAt)
      ..writeByte(13)
      ..write(obj.isArchived)
      ..writeByte(14)
      ..write(obj.archivedAt)
      ..writeByte(16)
      ..write(obj.durationMinutes)
      ..writeByte(17)
      ..write(obj.template)
      ..writeByte(15)
      ..write(obj.googleCalendarEventId)
      ..writeByte(18)
      ..write(obj.importedFromCalendar)
      ..writeByte(19)
      ..write(obj.id)
      ..writeByte(20)
      ..write(obj.updatedAt)
      ..writeByte(21)
      ..write(obj.deleted)
      ..writeByte(22)
      ..write(obj.deletedAt)
      ..writeByte(23)
      ..write(obj.appleEventId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
