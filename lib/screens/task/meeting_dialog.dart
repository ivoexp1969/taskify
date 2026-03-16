import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../models/task.dart';
import '../../models/category.dart';
import '../../utils/localization.dart';
import '../../services/notification_service.dart';
import '../../services/widget_service.dart';

class MeetingDialog {
  static Future<void> show(BuildContext context, {Task? existing}) async {
    final taskBox = Hive.box<Task>('tasks');
    final categoryBox = Hive.box<Category>('categories');

    String defaultCategoryId = 'meeting';
    if (!categoryBox.containsKey('meeting') && categoryBox.isNotEmpty) {
      defaultCategoryId = categoryBox.values.first.id;
    }

    // Парсираме meetingWith и place от notes: "with:Иван\nplace:Офиса"
    String initialWith = '';
    String initialPlace = '';
    if (existing?.notes != null) {
      for (final line in existing!.notes!.split('\n')) {
        if (line.startsWith('with:')) initialWith = line.replaceFirst('with:', '');
        if (line.startsWith('place:')) initialPlace = line.replaceFirst('place:', '');
      }
    }

    final withCtrl = TextEditingController(text: initialWith);
    final placeCtrl = TextEditingController(text: initialPlace);
    DateTime selectedDate = existing?.dueDate ?? DateTime.now();
    TimeOfDay selectedTime = existing != null
        ? TimeOfDay.fromDateTime(existing.dueDate)
        : TimeOfDay.now();
    List<String> reminders = List.from(existing?.remindersList ?? ['minus_15m']);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final t = AppText.of(ctx);
            final langCode = LanguageScope.of(ctx).locale.languageCode;
            final theme = Theme.of(ctx);
            final isDark = theme.brightness == Brightness.dark;
            final bgColor = isDark ? const Color(0xFF13131f) : theme.colorScheme.surface;
            const accent = Color(0xFF378ADD);

            final months = [
              t.january, t.february, t.march, t.april, t.may, t.june,
              t.july, t.august, t.september, t.october, t.november, t.december,
            ];
            final dateLabel = '${selectedDate.day} ${months[selectedDate.month - 1]}';
            final timeLabel = selectedTime.format(ctx);

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: EdgeInsets.only(
                  top: 12, left: 20, right: 20,
                  bottom: MediaQuery.of(ctx).padding.bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outline.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Header
                      Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F1FB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.phone_outlined, color: accent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            existing != null ? t.editMeeting : t.typeMeeting,
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // С кого
                      _Label(t.meetingWith, theme),
                      const SizedBox(height: 6),
                      _Field(controller: withCtrl, hint: t.meetingWithHint, theme: theme, isDark: isDark),
                      const SizedBox(height: 16),

                      // Дата и час
                      _Label(t.dateAndTime, theme),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: selectedDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                  lastDate: DateTime(2100),
                                  locale: Locale(langCode),
                                );
                                if (picked != null && ctx.mounted) setState(() => selectedDate = picked);
                              },
                              child: _DateChip(label: dateLabel, icon: Icons.calendar_today_outlined, accent: accent, isDark: isDark, theme: theme),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await showTimePicker(context: ctx, initialTime: selectedTime);
                                if (picked != null && ctx.mounted) setState(() => selectedTime = picked);
                              },
                              child: _DateChip(label: timeLabel, icon: Icons.access_time_outlined, accent: accent, isDark: isDark, theme: theme),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Място (незадължително)
                      Row(
                        children: [
                          Text(t.meetingPlace, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                          Text('  (${t.optional})', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.35))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _Field(controller: placeCtrl, hint: t.meetingPlaceHint, theme: theme, isDark: isDark),
                      const SizedBox(height: 16),

                      // Напомняне
                      Text(t.reminders, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                          _ReminderChip(label: t.atTime, value: 'at_time', selected: reminders.contains('at_time'), accent: accent, onTap: () => setState(() => reminders.contains('at_time') ? reminders.remove('at_time') : reminders.add('at_time'))),
                          _ReminderChip(label: t.minus15m, value: 'minus_15m', selected: reminders.contains('minus_15m'), accent: accent, onTap: () => setState(() => reminders.contains('minus_15m') ? reminders.remove('minus_15m') : reminders.add('minus_15m'))),
                          _ReminderChip(label: t.minus1h, value: 'minus_1h', selected: reminders.contains('minus_1h'), accent: accent, onTap: () => setState(() => reminders.contains('minus_1h') ? reminders.remove('minus_1h') : reminders.add('minus_1h'))),
                          _ReminderChip(label: t.oneDayBefore, value: 'minus_1d', selected: reminders.contains('minus_1d'), accent: accent, onTap: () => setState(() => reminders.contains('minus_1d') ? reminders.remove('minus_1d') : reminders.add('minus_1d'))),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Бутон Запази
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            final withPerson = withCtrl.text.trim();
                            if (withPerson.isEmpty) return;
                            final dueDate = DateTime(
                              selectedDate.year, selectedDate.month, selectedDate.day,
                              selectedTime.hour, selectedTime.minute,
                            );
                            final notesStr = [
                              'with:$withPerson',
                              if (placeCtrl.text.trim().isNotEmpty) 'place:${placeCtrl.text.trim()}',
                            ].join('\n');

                            if (existing != null) {
                              existing
                                ..title = withPerson
                                ..dueDate = dueDate
                                ..template = 'meeting'
                                ..notes = notesStr;
                              existing.setReminders(reminders);
                              await existing.save();
                              await NotificationService().scheduleForTask(existing);
                            } else {
                              final task = Task(
                                title: withPerson,
                                dueDate: dueDate,
                                categoryId: defaultCategoryId,
                                priority: 1,
                                template: 'meeting',
                                notes: notesStr,
                                reminders: reminders.isEmpty ? null : reminders,
                              );
                              await taskBox.add(task);
                              await NotificationService().scheduleForTask(task);
                            }
                            await WidgetService.updateWidget();
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          },
                          child: Text(
                            existing != null ? t.saveChanges : t.addMeeting,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

  }
}

class _Label extends StatelessWidget {
  final String text;
  final ThemeData theme;
  const _Label(this.text, this.theme);
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface.withOpacity(0.6)));
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ThemeData theme;
  final bool isDark;
  const _Field({required this.controller, required this.hint, required this.theme, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.35)),
        filled: true,
        fillColor: isDark ? const Color(0xFF1e1e2e) : theme.colorScheme.surfaceVariant.withOpacity(0.4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final bool isDark;
  final ThemeData theme;
  const _DateChip({required this.label, required this.icon, required this.accent, required this.isDark, required this.theme});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1e1e2e) : theme.colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _ReminderChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  const _ReminderChip({required this.label, required this.value, required this.selected, required this.accent, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.15) : Colors.transparent,
          border: Border.all(color: selected ? accent : Colors.grey.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: selected ? accent : Colors.grey)),
      ),
    );
  }
}
