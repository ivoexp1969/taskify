import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../../models/task.dart';
import '../../services/analytics_service.dart';
import '../../models/category.dart';
import '../../utils/localization.dart';
import '../../services/notification_service.dart';
import '../../services/widget_service.dart';
import '../../widgets/reminder_selector.dart';

class BirthdayDialog {
  static Future<void> show(BuildContext context, {Task? existing}) async {
    final taskBox = Hive.box<Task>('tasks');
    final categoryBox = Hive.box<Category>('categories');

    // Fallback categoryId - 'birthday' ако съществува, иначе първата категория
    String defaultCategoryId = 'birthday';
    if (!categoryBox.containsKey('birthday') && categoryBox.isNotEmpty) {
      defaultCategoryId = (categoryBox.values.first as dynamic).id as String;
    }

    final nameCtrl = TextEditingController(text: existing?.title ?? '');
    final yearCtrl = TextEditingController();

    DateTime selectedDate = existing?.dueDate ?? DateTime.now();
    int? birthYear;
    // Запазваме евентуални други бележки (напр. ако задачата е създадена като
    // обикновена в категория „Рождени дни"), за да не ги изтрием при запис.
    String extraNotes = '';

    // Парсираме birthYear от notes ако редактираме; останалото пазим в extraNotes
    if (existing?.notes != null) {
      final kept = <String>[];
      for (final line in existing!.notes!.split('\n')) {
        if (line.startsWith('birthYear:')) {
          birthYear = int.tryParse(line.replaceFirst('birthYear:', '').trim());
        } else {
          kept.add(line);
        }
      }
      extraNotes = kept.join('\n').trim();
      yearCtrl.text = birthYear?.toString() ?? '';
    }

    List<String> reminders = List.from(existing?.remindersList ?? ['minus_1d']);
    // Рожденият ден по подразбиране е ежегоден (авто-попълване според категорията)
    String selectedRecurrence = existing?.recurrence ?? 'yearly';
    int selectedPriority = existing?.priority ?? 1;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final t = AppText.of(ctx);
            final langCode = LanguageScope.of(ctx).locale.languageCode;
            final theme = Theme.of(ctx);
            final isDark = theme.brightness == Brightness.dark;
            final bgColor = isDark ? const Color(0xFF13131f) : theme.colorScheme.surface;
            const accent = Color(0xFFD4537E);

            // На колко навършва на ДАТАТА на събитието (за да се обновява
            // правилно при ежегодното превъртане на повтарящата се задача).
            int? age;
            if (birthYear != null) {
              age = selectedDate.year - birthYear!;
              if (age < 0 || age > 130) age = null;
            }

            final months = [
              t.january, t.february, t.march, t.april, t.may, t.june,
              t.july, t.august, t.september, t.october, t.november, t.december,
            ];
            final dateLabel = '${selectedDate.day} ${months[selectedDate.month - 1]}';

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
                            color: theme.colorScheme.outline.withValues(alpha: 0.3),
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
                              color: const Color(0xFFFBEAF0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.cake_outlined, color: accent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            existing != null ? t.editBirthday : t.typeBirthday,
                            style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Поле: Име
                      _Label(t.name, theme),
                      const SizedBox(height: 6),
                      _Field(
                        controller: nameCtrl,
                        hint: t.birthdayNameHint,
                        theme: theme,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),

                      // Поле: Дата
                      _Label(t.birthdayDate, theme),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime(1900),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null && ctx.mounted) {
                            setState(() => selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1e1e2e) : theme.colorScheme.surfaceVariant.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 18, color: accent),
                              const SizedBox(width: 10),
                              Text(dateLabel, style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Поле: Година на раждане (незадължително)
                      Row(
                        children: [
                          Text(t.birthYear, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                          Text('  (${t.optional})', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.35))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              controller: yearCtrl,
                              hint: t.birthYearHint,
                              theme: theme,
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (v) => setState(() => birthYear = int.tryParse(v)),
                            ),
                          ),
                          if (age != null) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFBEAF0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                t.turnsAge(age!),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: accent),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Приоритет
                      Text(t.priority, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        _RecurrenceChip(label: t.low,    value: '0', selected: selectedPriority == 0, accent: accent, onTap: () => setState(() => selectedPriority = 0)),
                        _RecurrenceChip(label: t.medium, value: '1', selected: selectedPriority == 1, accent: accent, onTap: () => setState(() => selectedPriority = 1)),
                        _RecurrenceChip(label: t.high,   value: '2', selected: selectedPriority == 2, accent: accent, onTap: () => setState(() => selectedPriority = 2)),
                      ]),
                      const SizedBox(height: 16),

                      // Повторение
                      Text(t.repeat, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        _RecurrenceChip(label: t.none2,   value: 'none',    selected: selectedRecurrence == 'none',    accent: accent, onTap: () => setState(() => selectedRecurrence = 'none')),
                        _RecurrenceChip(label: t.daily,   value: 'daily',   selected: selectedRecurrence == 'daily',   accent: accent, onTap: () => setState(() => selectedRecurrence = 'daily')),
                        _RecurrenceChip(label: t.weekly,  value: 'weekly',  selected: selectedRecurrence == 'weekly',  accent: accent, onTap: () => setState(() => selectedRecurrence = 'weekly')),
                        _RecurrenceChip(label: t.monthly, value: 'monthly', selected: selectedRecurrence == 'monthly', accent: accent, onTap: () => setState(() => selectedRecurrence = 'monthly')),
                        _RecurrenceChip(label: t.yearly,  value: 'yearly',  selected: selectedRecurrence == 'yearly',  accent: accent, onTap: () => setState(() => selectedRecurrence = 'yearly')),
                      ]),
                      const SizedBox(height: 16),

                      // Напомняне
                      Text(t.reminders, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                      const SizedBox(height: 8),
                      ReminderSelector(
                        selectedReminders: reminders,
                        onChanged: (l) => setState(() => reminders = l),
                        langCode: langCode,
                        theme: theme,
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
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            final noteParts = <String>[
                              if (birthYear != null) 'birthYear:$birthYear',
                              if (extraNotes.isNotEmpty) extraNotes,
                            ];
                            final notesStr = noteParts.isEmpty ? null : noteParts.join('\n');

                            if (existing != null) {
                              existing
                                ..title = name
                                ..dueDate = selectedDate
                                ..priority = selectedPriority
                                ..recurrence = selectedRecurrence == 'none' ? null : selectedRecurrence
                                ..template = 'birthday'
                                ..notes = notesStr;
                              existing.setReminders(reminders);
                              await existing.save();
                              await NotificationService().scheduleForTask(existing);
                            } else {
                              final task = Task(
                                title: name,
                                dueDate: selectedDate,
                                categoryId: defaultCategoryId,
                                priority: selectedPriority,
                                recurrence: selectedRecurrence == 'none' ? null : selectedRecurrence,
                                template: 'birthday',
                                notes: notesStr,
                                reminders: reminders.isEmpty ? null : reminders,
                              );
                              await taskBox.add(task);
                              AnalyticsService().logTaskCreated(task);
                              await NotificationService().scheduleForTask(task);
                            }
                            await WidgetService.updateWidget();
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          },
                          child: Text(
                            existing != null ? t.saveChanges : t.addBirthday,
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

    // Controllers are local variables - GC handles cleanup
  }
}

class _Label extends StatelessWidget {
  final String text;
  final ThemeData theme;
  const _Label(this.text, this.theme);
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)));
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ThemeData theme;
  final bool isDark;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  const _Field({required this.controller, required this.hint, required this.theme, required this.isDark, this.keyboardType, this.inputFormatters, this.onChanged});
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
        filled: true,
        fillColor: isDark ? const Color(0xFF1e1e2e) : theme.colorScheme.surfaceVariant.withValues(alpha: 0.4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          color: selected ? accent.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(color: selected ? accent : Colors.grey.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: selected ? accent : Colors.grey)),
      ),
    );
  }
}

class _RecurrenceChip extends StatelessWidget {
  final String label, value; final bool selected; final Color accent; final VoidCallback onTap;
  const _RecurrenceChip({required this.label, required this.value, required this.selected, required this.accent, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: selected ? accent.withValues(alpha: 0.15) : Colors.transparent,
        border: Border.all(color: selected ? accent : Colors.grey.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
        color: selected ? accent : Colors.grey))));
}
