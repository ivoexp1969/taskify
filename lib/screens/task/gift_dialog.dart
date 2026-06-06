import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../../models/task.dart';
import '../../models/category.dart';
import '../../utils/localization.dart';
import '../../services/notification_service.dart';
import '../../services/widget_service.dart';
import '../../widgets/reminder_selector.dart';

class GiftDialog {
  static Future<void> show(BuildContext context, {Task? existing}) async {
    final taskBox = Hive.box<Task>('tasks');
    final categoryBox = Hive.box<Category>('categories');

    String defaultCategoryId = 'gift';
    if (!categoryBox.containsKey('gift') && categoryBox.isNotEmpty) {
      defaultCategoryId = categoryBox.values.first.id;
    }

    String initialFor = '';
    String initialOccasion = '';
    String initialBudget = '';
    if (existing?.notes != null) {
      for (final line in existing!.notes!.split('\n')) {
        if (line.startsWith('for:')) initialFor = line.replaceFirst('for:', '');
        if (line.startsWith('occasion:')) initialOccasion = line.replaceFirst('occasion:', '');
        if (line.startsWith('budget:')) initialBudget = line.replaceFirst('budget:', '');
      }
    }

    final forCtrl = TextEditingController(text: initialFor);
    final occasionCtrl = TextEditingController(text: initialOccasion);
    final budgetCtrl = TextEditingController(text: initialBudget);
    DateTime selectedDate = existing?.dueDate ?? DateTime.now();
    List<String> reminders = List.from(existing?.remindersList ?? ['minus_1d']);
    String selectedRecurrence = existing?.recurrence ?? 'none';
    int selectedPriority = existing?.priority ?? 1;

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
            const accent = Color(0xFFFF7043);

            final months = [t.january, t.february, t.march, t.april, t.may, t.june,
              t.july, t.august, t.september, t.october, t.november, t.december];
            final dateLabel = '${selectedDate.day} ${months[selectedDate.month - 1].toLowerCase()}';

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
                          decoration: BoxDecoration(color: const Color(0xFFFAECE7),
                            borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.card_giftcard_outlined, color: accent, size: 20)),
                        const SizedBox(width: 12),
                        Text(existing != null ? t.editGift : t.typeGift,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                        const Spacer(),
                        IconButton(icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                          onPressed: () => Navigator.pop(ctx)),
                      ]),
                      const SizedBox(height: 20),
                      _Label(t.giftFor, theme),
                      const SizedBox(height: 6),
                      _Field(controller: forCtrl, hint: t.giftForHint, theme: theme, isDark: isDark),
                      const SizedBox(height: 16),
                      Row(children: [
                        Text(t.giftOccasion, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                        Text('  (${t.optional})', style: TextStyle(fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.35))),
                      ]),
                      const SizedBox(height: 6),
                      _Field(controller: occasionCtrl, hint: t.giftOccasionHint, theme: theme, isDark: isDark),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Wrap(children: [
                            Text(t.giftBudget, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                            Text(' (${t.optional})', style: TextStyle(fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.35))),
                          ]),
                          const SizedBox(height: 6),
                          _Field(controller: budgetCtrl, hint: t.giftBudgetHint, theme: theme, isDark: isDark,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]),
                        ])),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t.giftDeadline, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(context: ctx,
                                initialDate: selectedDate, firstDate: DateTime(2000),
                                lastDate: DateTime(2100), locale: Locale(langCode));
                              if (picked != null && ctx.mounted) setState(() => selectedDate = picked);
                            },
                            child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1e1e2e) : theme.colorScheme.surfaceVariant.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(12)),
                              child: Row(children: [
                                Icon(Icons.calendar_today_outlined, size: 16, color: accent),
                                const SizedBox(width: 6),
                                Expanded(child: Text(dateLabel, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                                  overflow: TextOverflow.ellipsis)),
                              ]))),
                        ])),
                      ]),
                      const SizedBox(height: 16),
                      Text(t.priority, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        _RecurrenceChip(label: t.low,    value: '0', selected: selectedPriority == 0, accent: accent, onTap: () => setState(() => selectedPriority = 0)),
                        _RecurrenceChip(label: t.medium, value: '1', selected: selectedPriority == 1, accent: accent, onTap: () => setState(() => selectedPriority = 1)),
                        _RecurrenceChip(label: t.high,   value: '2', selected: selectedPriority == 2, accent: accent, onTap: () => setState(() => selectedPriority = 2)),
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
                      ReminderSelector(
                        selectedReminders: reminders,
                        onChanged: (l) => setState(() => reminders = l),
                        langCode: langCode,
                        theme: theme,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          onPressed: () async {
                            final forPerson = forCtrl.text.trim();
                            if (forPerson.isEmpty) return;
                            final notesStr = [
                              'for:$forPerson',
                              if (occasionCtrl.text.trim().isNotEmpty) 'occasion:${occasionCtrl.text.trim()}',
                              if (budgetCtrl.text.trim().isNotEmpty) 'budget:${budgetCtrl.text.trim()}',
                            ].join('\n');
                            if (existing != null) {
                              existing..title = forPerson..dueDate = selectedDate..template = 'gift'..notes = notesStr
                                ..priority = selectedPriority
                                ..recurrence = selectedRecurrence == 'none' ? null : selectedRecurrence;
                              existing.setReminders(reminders);
                              await existing.save();
                              await NotificationService().scheduleForTask(existing);
                            } else {
                              final task = Task(title: forPerson, dueDate: selectedDate, categoryId: defaultCategoryId,
                                priority: selectedPriority, template: 'gift', notes: notesStr,
                                recurrence: selectedRecurrence == 'none' ? null : selectedRecurrence,
                                reminders: reminders.isEmpty ? null : reminders);
                              await taskBox.add(task);
                              await NotificationService().scheduleForTask(task);
                            }
                            await WidgetService.updateWidget();
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          },
                          child: Text(existing != null ? t.saveChanges : t.addGift,
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
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  const _Field({required this.controller, required this.hint, required this.theme,
    required this.isDark, this.keyboardType, this.inputFormatters});
  @override
  Widget build(BuildContext context) => TextField(controller: controller,
    keyboardType: keyboardType, inputFormatters: inputFormatters,
    style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
    decoration: InputDecoration(hintText: hint,
      hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
      filled: true, fillColor: isDark ? const Color(0xFF1e1e2e) : theme.colorScheme.surfaceVariant.withValues(alpha: 0.4),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)));
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
