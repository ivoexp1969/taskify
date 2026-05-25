import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../models/task.dart';
import '../../models/category.dart';
import '../../utils/localization.dart';
import '../../services/notification_service.dart';
import '../../services/widget_service.dart';

class TravelDialog {
  static Future<void> show(BuildContext context, {Task? existing}) async {
    final taskBox = Hive.box<Task>('tasks');
    final categoryBox = Hive.box<Category>('categories');

    String defaultCategoryId = 'travel';
    if (!categoryBox.containsKey('travel') && categoryBox.isNotEmpty) {
      defaultCategoryId = categoryBox.values.first.id;
    }

    String initialDest = '';
    DateTime? initialReturn;
    if (existing?.notes != null) {
      for (final line in existing!.notes!.split('\n')) {
        if (line.startsWith('dest:')) initialDest = line.replaceFirst('dest:', '');
        if (line.startsWith('return:')) {
          final ts = int.tryParse(line.replaceFirst('return:', ''));
          if (ts != null) initialReturn = DateTime.fromMillisecondsSinceEpoch(ts);
        }
      }
    }

    final destCtrl = TextEditingController(text: initialDest);
    DateTime selectedDeparture = existing?.dueDate ?? DateTime.now();
    DateTime? selectedReturn = initialReturn;
    List<String> reminders = List.from(existing?.remindersList ?? ['minus_1d']);
    String selectedRecurrence = existing?.recurrence ?? 'none';

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
            const accent = Color(0xFFA78BFF);

            final months = [t.january, t.february, t.march, t.april, t.may, t.june,
              t.july, t.august, t.september, t.october, t.november, t.december];
            final depLabel = '${selectedDeparture.day} ${months[selectedDeparture.month - 1]}';
            final retLabel = selectedReturn != null
                ? '${selectedReturn!.day} ${months[selectedReturn!.month - 1]}'
                : t.optional;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(color: bgColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                padding: EdgeInsets.only(top: 12, left: 20, right: 20,
                  bottom: MediaQuery.of(ctx).padding.bottom + 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 40, height: 4,
                        decoration: BoxDecoration(color: theme.colorScheme.outline.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 16),
                      Row(children: [
                        Container(width: 36, height: 36,
                          decoration: BoxDecoration(color: const Color(0xFFEEEDFE),
                            borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.flight_outlined, color: accent, size: 20)),
                        const SizedBox(width: 12),
                        Text(existing != null ? t.editTravel : t.typeTravel,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                        const Spacer(),
                        IconButton(icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                          onPressed: () => Navigator.pop(ctx)),
                      ]),
                      const SizedBox(height: 20),
                      _Label(t.travelDestination, theme),
                      const SizedBox(height: 6),
                      _Field(controller: destCtrl, hint: t.travelDestHint, theme: theme, isDark: isDark),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t.travelDeparture, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(context: ctx,
                                initialDate: selectedDeparture, firstDate: DateTime(2000),
                                lastDate: DateTime(2100), locale: Locale(langCode));
                              if (picked != null && ctx.mounted) setState(() => selectedDeparture = picked);
                            },
                            child: _DateChip(label: depLabel, accent: accent, isDark: isDark, theme: theme)),
                        ])),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(t.travelReturn, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                            Text('  (${t.optional})', style: TextStyle(fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.35))),
                          ]),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(context: ctx,
                                initialDate: selectedReturn ?? selectedDeparture.add(const Duration(days: 1)),
                                firstDate: selectedDeparture, lastDate: DateTime(2100), locale: Locale(langCode));
                              if (picked != null && ctx.mounted) setState(() => selectedReturn = picked);
                            },
                            child: _DateChip(label: retLabel, accent: accent, isDark: isDark, theme: theme,
                              muted: selectedReturn == null)),
                        ])),
                      ]),
                      const SizedBox(height: 16),
                      Text(t.repeat, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        _RecurrenceChip(label: t.none2,   value: 'none',    selected: selectedRecurrence == 'none',    accent: accent, onTap: () => setState(() => selectedRecurrence = 'none')),
                        _RecurrenceChip(label: t.daily,   value: 'daily',   selected: selectedRecurrence == 'daily',   accent: accent, onTap: () => setState(() => selectedRecurrence = 'daily')),
                        _RecurrenceChip(label: t.weekly,  value: 'weekly',  selected: selectedRecurrence == 'weekly',  accent: accent, onTap: () => setState(() => selectedRecurrence = 'weekly')),
                        _RecurrenceChip(label: t.monthly, value: 'monthly', selected: selectedRecurrence == 'monthly', accent: accent, onTap: () => setState(() => selectedRecurrence = 'monthly')),
                        _RecurrenceChip(label: t.yearly,  value: 'yearly',  selected: selectedRecurrence == 'yearly',  accent: accent, onTap: () => setState(() => selectedRecurrence = 'yearly')),
                      ]),
                      const SizedBox(height: 16),
                      Text(t.reminders, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _ReminderChip(label: t.oneDayBefore, value: 'minus_1d', selected: reminders.contains('minus_1d'), accent: accent,
                          onTap: () => setState(() => reminders.contains('minus_1d') ? reminders.remove('minus_1d') : reminders.add('minus_1d'))),
                        _ReminderChip(label: t.sameDayMorning, value: 'same_day_8', selected: reminders.contains('same_day_8'), accent: accent,
                          onTap: () => setState(() => reminders.contains('same_day_8') ? reminders.remove('same_day_8') : reminders.add('same_day_8'))),
                      ]),
                      const SizedBox(height: 24),
                      SizedBox(width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          onPressed: () async {
                            final dest = destCtrl.text.trim();
                            if (dest.isEmpty) return;
                            final notesStr = [
                              'dest:$dest',
                              if (selectedReturn != null) 'return:${selectedReturn!.millisecondsSinceEpoch}',
                            ].join('\n');
                            if (existing != null) {
                              existing..title = dest..dueDate = selectedDeparture..template = 'travel'..notes = notesStr
                                ..recurrence = selectedRecurrence == 'none' ? null : selectedRecurrence;
                              existing.setReminders(reminders);
                              await existing.save();
                              await NotificationService().scheduleForTask(existing);
                            } else {
                              final task = Task(title: dest, dueDate: selectedDeparture, categoryId: defaultCategoryId,
                                priority: 1, template: 'travel', notes: notesStr,
                                recurrence: selectedRecurrence == 'none' ? null : selectedRecurrence,
                                reminders: reminders.isEmpty ? null : reminders);
                              await taskBox.add(task);
                              await NotificationService().scheduleForTask(task);
                            }
                            await WidgetService.updateWidget();
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          },
                          child: Text(existing != null ? t.saveChanges : t.addTravel,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        )),
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
  final String text; final ThemeData theme;
  const _Label(this.text, this.theme);
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(fontSize: 13,
    fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)));
}

class _Field extends StatelessWidget {
  final TextEditingController controller; final String hint;
  final ThemeData theme; final bool isDark;
  const _Field({required this.controller, required this.hint, required this.theme, required this.isDark});
  @override
  Widget build(BuildContext context) => TextField(controller: controller,
    style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
    decoration: InputDecoration(hintText: hint,
      hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
      filled: true, fillColor: isDark ? const Color(0xFF1e1e2e) : theme.colorScheme.surfaceVariant.withValues(alpha: 0.4),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)));
}

class _DateChip extends StatelessWidget {
  final String label; final Color accent; final bool isDark; final ThemeData theme; final bool muted;
  const _DateChip({required this.label, required this.accent, required this.isDark, required this.theme, this.muted = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: isDark ? const Color(0xFF1e1e2e) : theme.colorScheme.surfaceVariant.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12)),
    child: Row(children: [Icon(Icons.calendar_today_outlined, size: 16, color: muted ? Colors.grey : accent),
      const SizedBox(width: 6),
      Expanded(child: Text(label, style: TextStyle(fontSize: 13,
        color: muted ? theme.colorScheme.onSurface.withValues(alpha: 0.35) : theme.colorScheme.onSurface),
        overflow: TextOverflow.ellipsis))]));
}

class _ReminderChip extends StatelessWidget {
  final String label, value; final bool selected; final Color accent; final VoidCallback onTap;
  const _ReminderChip({required this.label, required this.value, required this.selected, required this.accent, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: selected ? accent.withValues(alpha: 0.15) : Colors.transparent,
        border: Border.all(color: selected ? accent : Colors.grey.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
        color: selected ? accent : Colors.grey))));
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
