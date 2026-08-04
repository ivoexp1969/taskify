import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../models/task.dart';
import '../../services/analytics_service.dart';
import '../../models/category.dart';
import '../../utils/localization.dart';
import '../../services/notification_service.dart';
import '../../services/widget_service.dart';
import '../../services/documents_service.dart';
import '../../services/pro_service.dart';
import '../../widgets/reminder_selector.dart';
import '../paywall/paywall_screen.dart';

/// Диалог за документ с изтичащ срок. Документът се пази като обикновена [Task]
/// (template `document`, категория `documents`) → получава наготово напомняния,
/// Календар, „Днес", облачна синхронизация и статистики. Без отделна система.
class DocumentDialog {
  static const String categoryId = 'documents';
  static const Color _accent = Color(0xFF455A64);

  /// Възможните типове (имената идват от `documentTypeName` — вече на 11 езика).
  static const List<String> types = [
    'id_card', 'passport', 'license', 'insurance', 'inspection', 'vignette', 'other',
  ];

  /// Дълги изпреварвания за напомняния (документите имат дълъг хоризонт).
  static const List<String> reminderKeys = [
    'minus_1mo', 'minus_2w', 'minus_1w', 'minus_3d', 'minus_1d',
  ];

  /// Фаза 3: free потребители могат да следят до толкова документа; Pro е
  /// неограничено. Лимитът пази Pro стимула, а разгейтването отваря partner
  /// CTA-то „Поднови сега" към цялата база (Идея 1).
  static const int freeLimit = 2;

  /// Гарантира, че категорията „Документи" съществува (локализира се по id навсякъде).
  static Category ensureCategory(Box<Category> categoryBox) {
    final existing = categoryBox.get(categoryId);
    if (existing != null) return existing;
    final cat = Category(
      id: categoryId,
      name: 'Documents',
      colorValue: _accent.value,
      isDefault: false,
    );
    categoryBox.put(categoryId, cat);
    return cat;
  }

  static Future<void> show(BuildContext context, {Task? existing}) async {
    final taskBox = Hive.box<Task>('tasks');
    final categoryBox = Hive.box<Category>('categories');
    ensureCategory(categoryBox);

    // Фаза 3: лимит на БРОЯ документи за free (Pro неограничено). Редакцията на
    // съществуващ винаги е позволена; ограничаваме само СЪЗДАВАНЕТО на нов. На
    // web isPro е true → гейтът се прескача.
    if (existing == null && !ProService().isPro) {
      final count = taskBox.values
          .where((task) => task.template == 'document' && !task.isArchived)
          .length;
      if (count >= freeLimit) {
        final upgraded = await showPaywallIfNeeded(
          context,
          isFeatureAvailable: false,
          featureName: AppText.of(context).documents,
        );
        if (!upgraded) return;
      }
    }

    // Начални стойности (от съществуваща задача или разумни по подразбиране).
    String selectedType = 'id_card';
    String initialLabel = '';
    if (existing?.notes != null) {
      for (final line in existing!.notes!.split('\n')) {
        if (line.startsWith('doctype:')) selectedType = line.replaceFirst('doctype:', '').trim();
        if (line.startsWith('label:')) initialLabel = line.replaceFirst('label:', '');
      }
    }
    if (!types.contains(selectedType)) selectedType = 'other';

    final nameCtrl = TextEditingController(text: initialLabel);
    DateTime selectedDate = existing?.dueDate ??
        DateTime(DateTime.now().year + 1, DateTime.now().month, DateTime.now().day);
    List<String> reminders = List.from(
        existing?.remindersList ?? const ['minus_1mo', 'minus_1w', 'minus_1d']);
    bool annual = existing?.recurrence == 'yearly';

    if (!context.mounted) return; // след евент. await на paywall гейта (Фаза 3)
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
            const accent = _accent;

            final months = [t.january, t.february, t.march, t.april, t.may, t.june,
              t.july, t.august, t.september, t.october, t.november, t.december];
            final dateLabel = '${selectedDate.day} ${months[selectedDate.month - 1]} ${selectedDate.year}';

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
                          decoration: BoxDecoration(color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.badge_outlined, color: accent, size: 20)),
                        const SizedBox(width: 12),
                        Text(existing != null ? t.editDocument : t.addDocument,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                        const Spacer(),
                        IconButton(icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                          onPressed: () => Navigator.pop(ctx)),
                      ]),
                      const SizedBox(height: 20),
                      // ─── Тип документ ───
                      _DocLabel(t.documentType, theme),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: types.map((type) {
                        return _Chip(
                          label: documentTypeName(type, langCode),
                          selected: selectedType == type,
                          accent: accent,
                          onTap: () => setState(() => selectedType = type),
                        );
                      }).toList()),
                      const SizedBox(height: 16),
                      // ─── Свободно име (по избор; за „друго" е по-важно) ───
                      _DocLabel(t.documentNameHint, theme),
                      const SizedBox(height: 8),
                      _DocField(controller: nameCtrl, hint: t.documentNameHint, theme: theme, isDark: isDark),
                      const SizedBox(height: 16),
                      // ─── Срок на изтичане ───
                      _DocLabel(t.documentExpiry, theme),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(context: ctx,
                            initialDate: selectedDate, firstDate: DateTime(2000),
                            lastDate: DateTime(2100), locale: Locale(langCode));
                          if (picked != null) setState(() => selectedDate = picked);
                        },
                        child: _DateChip(label: dateLabel, accent: accent, isDark: isDark, theme: theme),
                      ),
                      const SizedBox(height: 16),
                      // ─── Годишно подновяване ───
                      GestureDetector(
                        onTap: () => setState(() => annual = !annual),
                        child: Row(children: [
                          Icon(annual ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                            color: annual ? accent : theme.colorScheme.onSurface.withValues(alpha: 0.4), size: 22),
                          const SizedBox(width: 8),
                          Text(t.documentAnnual, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface)),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      // ─── Напомняния (дълги изпреварвания) ───
                      _DocLabel(t.reminders, theme),
                      const SizedBox(height: 8),
                      ReminderSelector(
                        selectedReminders: reminders,
                        onChanged: (l) => setState(() => reminders = l),
                        langCode: langCode,
                        theme: theme,
                        availableKeys: reminderKeys,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          onPressed: () async {
                            final label = nameCtrl.text.trim();
                            // Срокът — в 09:00, за да падат напомнянията в разумен час.
                            final dueDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 9);
                            final title = documentTypeName(selectedType, langCode,
                                label: label.isEmpty ? null : label);
                            final notesStr = [
                              'doctype:$selectedType',
                              if (label.isNotEmpty) 'label:$label',
                            ].join('\n');
                            final recurrence = annual ? 'yearly' : null;
                            if (existing != null) {
                              existing..title = title..dueDate = dueDate..template = 'document'
                                ..notes = notesStr..categoryId = categoryId
                                ..recurrence = recurrence;
                              existing.setReminders(reminders);
                              await existing.save();
                              await NotificationService().scheduleForTask(existing);
                            } else {
                              final task = Task(title: title, dueDate: dueDate, categoryId: categoryId,
                                priority: 1, template: 'document', notes: notesStr, recurrence: recurrence,
                                reminders: reminders.isEmpty ? null : reminders);
                              await taskBox.add(task);
                              AnalyticsService().logTaskCreated(task);
                              await NotificationService().scheduleForTask(task);
                            }
                            await WidgetService.updateWidget();
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          },
                          child: Text(existing != null ? t.saveChanges : t.addDocument,
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

class _DocLabel extends StatelessWidget {
  final String text; final ThemeData theme;
  const _DocLabel(this.text, this.theme);
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(fontSize: 13,
    fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)));
}

class _DocField extends StatelessWidget {
  final TextEditingController controller; final String hint;
  final ThemeData theme; final bool isDark;
  const _DocField({required this.controller, required this.hint, required this.theme, required this.isDark});
  @override
  Widget build(BuildContext context) => TextField(controller: controller,
    textCapitalization: TextCapitalization.sentences,
    style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
    decoration: InputDecoration(hintText: hint,
      hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
      filled: true, fillColor: isDark ? const Color(0xFF1e1e2e) : theme.colorScheme.surfaceVariant.withValues(alpha: 0.4),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)));
}

class _DateChip extends StatelessWidget {
  final String label; final Color accent; final bool isDark; final ThemeData theme;
  const _DateChip({required this.label, required this.accent, required this.isDark, required this.theme});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: isDark ? const Color(0xFF1e1e2e) : theme.colorScheme.surfaceVariant.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12)),
    child: Row(children: [Icon(Icons.calendar_today_outlined, size: 16, color: accent),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
        overflow: TextOverflow.ellipsis))]));
}

class _Chip extends StatelessWidget {
  final String label; final bool selected; final Color accent; final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.accent, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: selected ? accent.withValues(alpha: 0.15) : Colors.transparent,
        border: Border.all(color: selected ? accent : Colors.grey.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
        color: selected ? accent : Colors.grey))));
}
