import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../models/task.dart';
import '../../models/category.dart';
import '../../models/task_templates.dart';
import '../../utils/localization.dart';
import '../../utils/subtask_format.dart';
import '../../services/task_template_service.dart';
import '../../services/notification_service.dart';
import '../../services/widget_service.dart';

/// Диалог за създаване на учебна задача (Режими Уча): Домашно / Есе / Курсова.
///
/// Пита за: предмет (категория на потребителя), краен срок и — за есе/курсова —
/// оценка за сложност (1–3). За есе и курсова автоматично създава подзадачи по
/// шаблон (`task_templates.json`), компресирани при кратък срок. Домашно няма
/// авто-подзадачи (потребителят може да добави ръчно).
class StudyTaskDialog {
  const StudyTaskDialog._();

  static String _typeLabel(AppText t, String kind) {
    switch (kind) {
      case 'homework':
        return t.typeHomework;
      case 'essay':
        return t.typeEssay;
      case 'coursework':
        return t.typeCoursework;
      default:
        return t.typeTask;
    }
  }

  static IconData _icon(String kind) {
    switch (kind) {
      case 'essay':
        return Icons.edit_note_outlined;
      case 'coursework':
        return Icons.article_outlined;
      default:
        return Icons.menu_book_outlined;
    }
  }

  /// Локализирано име на категория — default категориите се превеждат по id
  /// (иначе се виждаха суровите английски имена = „паразитни" категории).
  static String _catName(Category c, AppText t) {
    if (c.id == 'cal_events') return t.catCalendarEvents;
    if (c.id == 'documents') return t.catDocuments;
    if (c.isDefault) {
      return {
            'work': t.work,
            'personal': t.personal,
            'shopping': t.shopping,
            'birthday': t.catBirthdays,
            'meeting': t.catMeeting,
            'workout': t.catWorkout,
            'payment': t.catPayment,
            'travel': t.catTravel,
            'gift': t.catGift,
          }[c.id] ??
          c.name;
    }
    return c.name;
  }

  static Future<bool?> show(BuildContext context, {required String kind}) async {
    await TaskTemplateService().load();
    if (!context.mounted) return null;

    final taskBox = Hive.box<Task>('tasks');
    final categoryBox = Hive.box<Category>('categories');
    // Системните категории „Документи" и „Събития" (календар) не са учебни
    // предмети → изключваме ги (иначе „Събития" се дублираше).
    final categories = categoryBox.values
        .where((c) => c.id != 'documents' && c.id != 'cal_events')
        .toList();

    final titleCtrl = TextEditingController();
    String? categoryId = categories.isNotEmpty ? categories.first.id : null;
    DateTime selectedDate =
        DateTime.now().add(const Duration(days: 7));
    int complexity = 2;
    final autoBreak = kind == 'essay' || kind == 'coursework';

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final t = AppText.of(ctx);
            final lang = LanguageScope.of(ctx).locale.languageCode;
            final theme = Theme.of(ctx);
            final isDark = theme.brightness == Brightness.dark;
            final bg = isDark ? const Color(0xFF13131f) : theme.colorScheme.surface;
            const accent = Color(0xFF6A3DE8);

            final months = [t.january, t.february, t.march, t.april, t.may,
              t.june, t.july, t.august, t.september, t.october, t.november,
              t.december];
            final dateLabel =
                '${selectedDate.day} ${months[selectedDate.month - 1]} ${selectedDate.year}';

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                    color: bg,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24))),
                padding: EdgeInsets.only(
                    top: 12,
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(ctx).padding.bottom + 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color: theme.colorScheme.outline
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2))),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10)),
                            child: Icon(_icon(kind), color: accent, size: 20)),
                        const SizedBox(width: 12),
                        Text(_typeLabel(t, kind),
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface)),
                        const Spacer(),
                        IconButton(
                            icon: Icon(Icons.close,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5)),
                            onPressed: () => Navigator.pop(ctx)),
                      ]),
                      const SizedBox(height: 16),

                      // ── Заглавие (по избор) ──
                      _label(t.taskTitle, theme),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: _typeLabel(t, kind),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF1e1e2e)
                              : theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.4),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Предмет (категория) ──
                      _label(_subjectLabel(lang), theme),
                      const SizedBox(height: 6),
                      if (categories.isEmpty)
                        Text(_noSubjects(lang),
                            style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant))
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in categories)
                              ChoiceChip(
                                label: Text(_catName(c, t)),
                                selected: categoryId == c.id,
                                onSelected: (_) =>
                                    setState(() => categoryId = c.id),
                              ),
                          ],
                        ),
                      const SizedBox(height: 16),

                      // ── Краен срок ──
                      _label(_dueLabel(lang), theme),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 1)),
                            lastDate: DateTime(DateTime.now().year + 3),
                            locale: Locale(lang),
                          );
                          if (picked != null) {
                            setState(() => selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1e1e2e)
                                  : theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 16, color: accent),
                            const SizedBox(width: 8),
                            Text(dateLabel,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurface)),
                          ]),
                        ),
                      ),

                      // ── Сложност (само есе/курсова) ──
                      if (autoBreak) ...[
                        const SizedBox(height: 16),
                        _label(_complexityLabel(lang), theme),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            for (int c = 1; c <= 3; c++)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(_complexityName(lang, c)),
                                  selected: complexity == c,
                                  onSelected: (_) =>
                                      setState(() => complexity = c),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(_autoBreakHint(lang),
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14))),
                          onPressed: categoryId == null
                              ? null
                              : () async {
                                  await _create(
                                    ctx: ctx,
                                    taskBox: taskBox,
                                    kind: kind,
                                    title: titleCtrl.text.trim(),
                                    fallbackTitle: _typeLabel(t, kind),
                                    categoryId: categoryId!,
                                    dueDate: selectedDate,
                                    complexity: complexity,
                                    autoBreak: autoBreak,
                                    lang: lang,
                                    months: months,
                                  );
                                },
                          child: Text(t.add,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
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

  static Future<void> _create({
    required BuildContext ctx,
    required Box<Task> taskBox,
    required String kind,
    required String title,
    required String fallbackTitle,
    required String categoryId,
    required DateTime dueDate,
    required int complexity,
    required bool autoBreak,
    required String lang,
    required List<String> months,
  }) async {
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day, 9);
    final finalTitle = title.isNotEmpty ? title : fallbackTitle;

    List<String>? subtasks;
    if (autoBreak) {
      final steps = TaskTemplateService().stepsFor(kind);
      final planned = planSubtasks(
        steps: steps,
        dueDate: due,
        today: DateTime.now(),
        complexity: complexity,
      );
      if (planned.isNotEmpty) {
        subtasks = planned
            .map((p) => SubtaskCodec.format(
                  text:
                      '${p.localizedTitle(lang)} · ${p.date.day} ${months[p.date.month - 1]}',
                ))
            .toList();
      }
    }

    final task = Task(
      title: finalTitle,
      dueDate: due,
      categoryId: categoryId,
      priority: 1,
      taskKind: kind,
      subtasks: subtasks,
    );
    await taskBox.add(task);
    await NotificationService().scheduleForTask(task);
    await WidgetService.updateWidget();
    if (ctx.mounted) Navigator.pop(ctx, true);
  }

  static Widget _label(String text, ThemeData theme) => Text(text,
      style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6)));

  static String _tr(Map<String, String> m, String lang) => m[lang] ?? m['en']!;

  static String _subjectLabel(String lang) => _tr(const {
        'en': 'Subject', 'bg': 'Предмет', 'de': 'Fach', 'fr': 'Matière',
        'it': 'Materia', 'el': 'Μάθημα', 'es': 'Asignatura', 'pt': 'Disciplina',
        'ru': 'Предмет', 'tr': 'Ders', 'ja': '科目',
      }, lang);

  static String _noSubjects(String lang) => _tr(const {
        'en': 'Add a category first to use as a subject.',
        'bg': 'Добави първо категория, която да ползваш като предмет.',
        'de': 'Füge zuerst eine Kategorie als Fach hinzu.',
        'fr': "Ajoute d'abord une catégorie comme matière.",
        'it': 'Aggiungi prima una categoria come materia.',
        'el': 'Πρόσθεσε πρώτα μια κατηγορία ως μάθημα.',
        'es': 'Añade primero una categoría como asignatura.',
        'pt': 'Adiciona primeiro uma categoria como disciplina.',
        'ru': 'Сначала добавь категорию для предмета.',
        'tr': 'Önce ders olarak bir kategori ekle.',
        'ja': 'まず科目となるカテゴリを追加してください。',
      }, lang);

  static String _dueLabel(String lang) => _tr(const {
        'en': 'Deadline', 'bg': 'Краен срок', 'de': 'Frist', 'fr': 'Échéance',
        'it': 'Scadenza', 'el': 'Προθεσμία', 'es': 'Fecha límite',
        'pt': 'Prazo', 'ru': 'Срок', 'tr': 'Son tarih', 'ja': '締切',
      }, lang);

  static String _complexityLabel(String lang) => _tr(const {
        'en': 'Complexity', 'bg': 'Сложност', 'de': 'Komplexität',
        'fr': 'Complexité', 'it': 'Complessità', 'el': 'Δυσκολία',
        'es': 'Complejidad', 'pt': 'Complexidade', 'ru': 'Сложность',
        'tr': 'Zorluk', 'ja': '難易度',
      }, lang);

  static String _complexityName(String lang, int c) {
    const easy = {
      'en': 'Simple', 'bg': 'Лесна', 'de': 'Einfach', 'fr': 'Simple',
      'it': 'Semplice', 'el': 'Απλή', 'es': 'Simple', 'pt': 'Simples',
      'ru': 'Простая', 'tr': 'Basit', 'ja': '簡単',
    };
    const medium = {
      'en': 'Medium', 'bg': 'Средна', 'de': 'Mittel', 'fr': 'Moyenne',
      'it': 'Media', 'el': 'Μέτρια', 'es': 'Media', 'pt': 'Média',
      'ru': 'Средняя', 'tr': 'Orta', 'ja': '普通',
    };
    const hard = {
      'en': 'Complex', 'bg': 'Сложна', 'de': 'Komplex', 'fr': 'Complexe',
      'it': 'Complessa', 'el': 'Σύνθετη', 'es': 'Compleja', 'pt': 'Complexa',
      'ru': 'Сложная', 'tr': 'Karmaşık', 'ja': '複雑',
    };
    switch (c) {
      case 1:
        return _tr(easy, lang);
      case 3:
        return _tr(hard, lang);
      default:
        return _tr(medium, lang);
    }
  }

  static String _autoBreakHint(String lang) => _tr(const {
        'en': 'Subtasks will be created automatically and scheduled toward the deadline.',
        'bg': 'Подзадачите ще се създадат автоматично и разпределят до срока.',
        'de': 'Teilaufgaben werden automatisch erstellt und bis zur Frist verteilt.',
        'fr': 'Des sous-tâches seront créées automatiquement jusqu\'à l\'échéance.',
        'it': 'Le sottoattività verranno create automaticamente fino alla scadenza.',
        'el': 'Οι υποεργασίες θα δημιουργηθούν αυτόματα έως την προθεσμία.',
        'es': 'Las subtareas se crearán automáticamente hasta la fecha límite.',
        'pt': 'As subtarefas serão criadas automaticamente até ao prazo.',
        'ru': 'Подзадачи создадутся автоматически и распределятся до срока.',
        'tr': 'Alt görevler otomatik oluşturulup son tarihe göre planlanır.',
        'ja': 'サブタスクは自動的に作成され、締切まで割り当てられます。',
      }, lang);
}
