import 'package:flutter/material.dart';

import '../../models/weekly_schedule.dart';
import '../../services/weekly_schedule_service.dart';
import '../../services/university_service.dart';
import '../../utils/localization.dart';

/// Екран „Учебна програма" — прости слотове уроци/лекции по дни от седмицата,
/// организирани по **срок (ученик) / семестър (студент)**. Слотовете се виждат
/// и на календара (за текущо избрания срок).
class WeeklyScheduleScreen extends StatefulWidget {
  const WeeklyScheduleScreen({super.key});

  @override
  State<WeeklyScheduleScreen> createState() => _WeeklyScheduleScreenState();
}

class _WeeklyScheduleScreenState extends State<WeeklyScheduleScreen> {
  final _svc = WeeklyScheduleService();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _svc.load().then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  static String _t(Map<String, String> m, String lang) => m[lang] ?? m['en']!;

  static const _title = {
    'en': 'My schedule', 'bg': 'Моето разписание', 'de': 'Mein Stundenplan',
    'fr': 'Mon emploi du temps', 'it': 'Il mio orario', 'el': 'Το πρόγραμμά μου',
    'es': 'Mi horario', 'pt': 'O meu horário', 'ru': 'Моё расписание',
    'tr': 'Ders programım', 'ja': '時間割',
  };
  // Ученик — учебни срокове.
  static const _term1Pupil = {
    'en': 'Term 1', 'bg': 'I срок', 'de': '1. Halbjahr', 'fr': '1er trimestre',
    'it': '1° periodo', 'el': '1ο τρίμηνο', 'es': '1er trimestre',
    'pt': '1º período', 'ru': '1-й срок', 'tr': '1. dönem', 'ja': '前期',
  };
  static const _term2Pupil = {
    'en': 'Term 2', 'bg': 'II срок', 'de': '2. Halbjahr', 'fr': '2e trimestre',
    'it': '2° periodo', 'el': '2ο τρίμηνο', 'es': '2º trimestre',
    'pt': '2º período', 'ru': '2-й срок', 'tr': '2. dönem', 'ja': '後期',
  };
  // Студент — семестри.
  static const _term1Student = {
    'en': 'Winter sem.', 'bg': 'Зимен семестър', 'de': 'Wintersemester',
    'fr': 'Semestre d\'hiver', 'it': 'Sem. invernale', 'el': 'Χειμ. εξάμηνο',
    'es': 'Sem. de invierno', 'pt': 'Sem. de inverno', 'ru': 'Зимний семестр',
    'tr': 'Güz dönemi', 'ja': '冬学期',
  };
  static const _term2Student = {
    'en': 'Summer sem.', 'bg': 'Летен семестър', 'de': 'Sommersemester',
    'fr': 'Semestre d\'été', 'it': 'Sem. estivo', 'el': 'Θεριν. εξάμηνο',
    'es': 'Sem. de verano', 'pt': 'Sem. de verão', 'ru': 'Летний семестр',
    'tr': 'Bahar dönemi', 'ja': '夏学期',
  };
  static const _deleteTip = {
    'en': 'Delete', 'bg': 'Изтрий', 'de': 'Löschen', 'fr': 'Supprimer',
    'it': 'Elimina', 'el': 'Διαγραφή', 'es': 'Eliminar', 'pt': 'Eliminar',
    'ru': 'Удалить', 'tr': 'Sil', 'ja': '削除',
  };
  static const _addLesson = {
    'en': 'Add class', 'bg': 'Добави час', 'de': 'Stunde hinzufügen',
    'fr': 'Ajouter un cours', 'it': 'Aggiungi lezione', 'el': 'Προσθήκη μαθήματος',
    'es': 'Añadir clase', 'pt': 'Adicionar aula', 'ru': 'Добавить занятие',
    'tr': 'Ders ekle', 'ja': '授業を追加',
  };
  static const _noLessonsDay = {
    'en': 'No classes — tap to add.',
    'bg': 'Няма часове — натисни, за да добавиш.',
    'de': 'Keine Stunden – zum Hinzufügen tippen.',
    'fr': 'Aucun cours — appuie pour ajouter.',
    'it': 'Nessuna lezione — tocca per aggiungere.',
    'el': 'Κανένα μάθημα — πάτησε για προσθήκη.',
    'es': 'Sin clases: toca para añadir.',
    'pt': 'Sem aulas — toca para adicionar.',
    'ru': 'Нет занятий — нажми, чтобы добавить.',
    'tr': 'Ders yok — eklemek için dokun.',
    'ja': '授業なし — タップで追加。',
  };

  static const _dayNames = {
    'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    'bg': ['Понеделник', 'Вторник', 'Сряда', 'Четвъртък', 'Петък', 'Събота', 'Неделя'],
    'de': ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'],
    'fr': ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'],
    'it': ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'],
    'el': ['Δευ', 'Τρι', 'Τετ', 'Πεμ', 'Παρ', 'Σαβ', 'Κυρ'],
    'es': ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'],
    'pt': ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'],
    'ru': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
    'tr': ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'],
    'ja': ['月', '火', '水', '木', '金', '土', '日'],
  };

  String _dayName(String lang, int day) {
    final list = _dayNames[lang] ?? _dayNames['en']!;
    return list[(day - 1).clamp(0, 6)];
  }

  Future<void> _addOrEdit(String lang,
      {ScheduleSlot? existing,
      int? day,
      int? initialFromMinutes,
      int? initialToMinutes}) async {
    final result = await showScheduleSlotDialog(context, lang,
        existing: existing,
        initialDay: day,
        initialFromMinutes: initialFromMinutes,
        initialToMinutes: initialToMinutes);
    if (result == null) return;
    if (result.delete && existing != null) {
      await _svc.remove(existing.id);
    } else if (result.slot != null) {
      await _svc.upsert(result.slot!);
    }
    if (mounted) setState(() {});
  }

  /// Добавя нов час за конкретен ден. Началото по подразбиране е **15 минути след
  /// края на последния час** в деня (за текущия срок; редактируемо), а
  /// продължителността копира последния час (или 45 мин). При празен ден —
  /// стандартно 08:00–08:45.
  Future<void> _addForDay(String lang, int day) async {
    final slots = _svc.forDay(day);
    int? fromMin;
    int? toMin;
    if (slots.isNotEmpty) {
      final last = slots.reduce((a, b) => a.toMinutes >= b.toMinutes ? a : b);
      final dur = last.toMinutes - last.fromMinutes;
      final d = (dur >= 5 && dur <= 240) ? dur : 45;
      final f = last.toMinutes + 15;
      if (f < 24 * 60 - 1) {
        fromMin = f;
        toMin = (f + d) > (24 * 60 - 1) ? (24 * 60 - 1) : (f + d);
      }
    }
    await _addOrEdit(lang,
        day: day, initialFromMinutes: fromMin, initialToMinutes: toMin);
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageScope.of(context).locale.languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(_t(_title, lang))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedBuilder(
              animation: WeeklyScheduleService.revision,
              builder: (context, _) {
                return Column(
                  children: [
                    _termSelector(context, lang),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
                        children: [
                          // Работната седмица: понеделник (1) – петък (5).
                          for (int day = 1; day <= 5; day++)
                            _daySection(context, lang, day),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  /// Превключвател срок/семестър. Ученик → I/II срок; Студент → зимен/летен.
  Widget _termSelector(BuildContext context, String lang) {
    final isStudent = UniversityService().enabled;
    final l1 = _t(isStudent ? _term1Student : _term1Pupil, lang);
    final l2 = _t(isStudent ? _term2Student : _term2Pupil, lang);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: SegmentedButton<int>(
        segments: [
          ButtonSegment(value: 1, label: Text(l1, textAlign: TextAlign.center)),
          ButtonSegment(value: 2, label: Text(l2, textAlign: TextAlign.center)),
        ],
        selected: {_svc.currentTerm},
        showSelectedIcon: false,
        onSelectionChanged: (sel) async {
          await _svc.setCurrentTerm(sel.first);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Widget _daySection(BuildContext context, String lang, int day) {
    final slots = _svc.forDay(day);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заглавие на деня + бутон „+" за добавяне на час в този ден.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 4, 2),
          child: Row(
            children: [
              Expanded(
                child: Text(_dayName(lang, day),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: theme.colorScheme.primary)),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                visualDensity: VisualDensity.compact,
                tooltip: _t(_addLesson, lang),
                onPressed: () => _addForDay(lang, day),
              ),
            ],
          ),
        ),
        if (slots.isEmpty)
          InkWell(
            onTap: () => _addForDay(lang, day),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Text(_t(_noLessonsDay, lang),
                  style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13)),
            ),
          )
        else
          for (final s in slots)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: ListTile(
                leading: Icon(
                    s.kind == SlotKind.lecture
                        ? Icons.school_outlined
                        : Icons.menu_book_outlined,
                    color: theme.colorScheme.primary),
                title: Text(s.subject.isNotEmpty ? s.subject : '—'),
                subtitle: Text([
                  '${s.fromLabel}–${s.toLabel}',
                  if (s.location != null) '📍 ${s.location}',
                ].join('  ')),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error),
                  tooltip: _t(_deleteTip, lang),
                  onPressed: () async {
                    await _svc.remove(s.id);
                    if (mounted) setState(() {});
                  },
                ),
                onTap: () => _addOrEdit(lang, existing: s),
              ),
            ),
      ],
    );
  }
}

/// Резултат от диалога за слот: нов/редактиран слот или заявка за триене.
class ScheduleSlotResult {
  final ScheduleSlot? slot;
  final bool delete;
  const ScheduleSlotResult({this.slot, this.delete = false});
}

/// Диалог за добавяне/редакция на слот от разписа.
Future<ScheduleSlotResult?> showScheduleSlotDialog(
  BuildContext context,
  String lang, {
  ScheduleSlot? existing,
  int? initialDay,
  int? initialFromMinutes,
  int? initialToMinutes,
}) {
  String t(Map<String, String> m) => m[lang] ?? m['en']!;
  final svc = WeeklyScheduleService();

  // Ако е добавяне през уикенда (без подаден ден) → по подразбиране понеделник.
  final todayWd = DateTime.now().weekday;
  int day = existing?.day ?? initialDay ?? (todayWd > 5 ? 1 : todayWd);
  final subjectCtrl = TextEditingController(text: existing?.subject ?? '');
  final locationCtrl = TextEditingController(text: existing?.location ?? '');
  TimeOfDay from = existing != null
      ? TimeOfDay(hour: existing.fromMinutes ~/ 60, minute: existing.fromMinutes % 60)
      : (initialFromMinutes != null
          ? TimeOfDay(
              hour: initialFromMinutes ~/ 60, minute: initialFromMinutes % 60)
          : const TimeOfDay(hour: 8, minute: 0));
  TimeOfDay to = existing != null
      ? TimeOfDay(hour: existing.toMinutes ~/ 60, minute: existing.toMinutes % 60)
      : (initialToMinutes != null
          ? TimeOfDay(hour: initialToMinutes ~/ 60, minute: initialToMinutes % 60)
          : const TimeOfDay(hour: 8, minute: 45));
  SlotKind kind = existing?.kind ?? SlotKind.lesson;

  const subjectLabel = {
    'en': 'Subject', 'bg': 'Предмет', 'de': 'Fach', 'fr': 'Matière',
    'it': 'Materia', 'el': 'Μάθημα', 'es': 'Asignatura', 'pt': 'Disciplina',
    'ru': 'Предмет', 'tr': 'Ders', 'ja': '科目',
  };
  const locationLabel = {
    'en': 'Location (optional)', 'bg': 'Място (по избор)', 'de': 'Ort (optional)',
    'fr': 'Lieu (facultatif)', 'it': 'Luogo (facoltativo)', 'el': 'Τόπος (προαιρετικό)',
    'es': 'Lugar (opcional)', 'pt': 'Local (opcional)', 'ru': 'Место (необязательно)',
    'tr': 'Yer (isteğe bağlı)', 'ja': '場所（任意）',
  };
  const dayLabel = {
    'en': 'Day', 'bg': 'Ден', 'de': 'Tag', 'fr': 'Jour', 'it': 'Giorno',
    'el': 'Ημέρα', 'es': 'Día', 'pt': 'Dia', 'ru': 'День', 'tr': 'Gün', 'ja': '曜日',
  };
  const fromLbl = {
    'en': 'From', 'bg': 'От', 'de': 'Von', 'fr': 'De', 'it': 'Da', 'el': 'Από',
    'es': 'Desde', 'pt': 'De', 'ru': 'С', 'tr': 'Başlangıç', 'ja': '開始',
  };
  const toLbl = {
    'en': 'To', 'bg': 'До', 'de': 'Bis', 'fr': 'À', 'it': 'A', 'el': 'Έως',
    'es': 'Hasta', 'pt': 'Até', 'ru': 'До', 'tr': 'Bitiş', 'ja': '終了',
  };
  const lessonLbl = {
    'en': 'Lesson', 'bg': 'Урок', 'de': 'Unterricht', 'fr': 'Cours', 'it': 'Lezione',
    'el': 'Μάθημα', 'es': 'Clase', 'pt': 'Aula', 'ru': 'Урок', 'tr': 'Ders', 'ja': '授業',
  };
  const lectureLbl = {
    'en': 'Lecture', 'bg': 'Лекция', 'de': 'Vorlesung', 'fr': 'Cours magistral',
    'it': 'Lezione univ.', 'el': 'Διάλεξη', 'es': 'Clase magistral', 'pt': 'Aula teórica',
    'ru': 'Лекция', 'tr': 'Ders (üniv.)', 'ja': '講義',
  };
  const cancel = {
    'en': 'Cancel', 'bg': 'Отказ', 'de': 'Abbrechen', 'fr': 'Annuler', 'it': 'Annulla',
    'el': 'Άκυρο', 'es': 'Cancelar', 'pt': 'Cancelar', 'ru': 'Отмена', 'tr': 'İptal',
    'ja': 'キャンセル',
  };
  const save = {
    'en': 'Save', 'bg': 'Запази', 'de': 'Speichern', 'fr': 'Enregistrer', 'it': 'Salva',
    'el': 'Αποθήκευση', 'es': 'Guardar', 'pt': 'Guardar', 'ru': 'Сохранить', 'tr': 'Kaydet',
    'ja': '保存',
  };
  const badRange = {
    'en': 'End time must be after start time.',
    'bg': 'Крайният час трябва да е след началния.',
    'de': 'Die Endzeit muss nach der Startzeit liegen.',
    'fr': 'L\'heure de fin doit être après le début.',
    'it': 'L\'ora di fine deve essere dopo l\'inizio.',
    'el': 'Η ώρα λήξης πρέπει να είναι μετά την έναρξη.',
    'es': 'La hora de fin debe ser posterior al inicio.',
    'pt': 'A hora de fim deve ser após o início.',
    'ru': 'Время окончания должно быть позже начала.',
    'tr': 'Bitiş saati başlangıçtan sonra olmalı.',
    'ja': '終了時刻は開始時刻より後にしてください。',
  };
  // {0} = предмет/тип, {1} = от–до на конфликтния слот
  const overlapMsg = {
    'en': 'Overlaps with {0} ({1}).',
    'bg': 'Припокрива се с {0} ({1}).',
    'de': 'Überschneidet sich mit {0} ({1}).',
    'fr': 'Chevauche {0} ({1}).',
    'it': 'Si sovrappone a {0} ({1}).',
    'el': 'Επικαλύπτεται με {0} ({1}).',
    'es': 'Se solapa con {0} ({1}).',
    'pt': 'Sobrepõe-se a {0} ({1}).',
    'ru': 'Пересекается с {0} ({1}).',
    'tr': '{0} ({1}) ile çakışıyor.',
    'ja': '{0}（{1}）と重複しています。',
  };
  const busyFallback = {
    'en': 'another slot', 'bg': 'друг час', 'de': 'einem anderen Termin',
    'fr': 'un autre créneau', 'it': 'un altro slot', 'el': 'άλλη ώρα',
    'es': 'otro horario', 'pt': 'outro horário', 'ru': 'другим слотом',
    'tr': 'başka bir ders', 'ja': '別の予定',
  };
  const dayNames = _WeeklyScheduleScreenState._dayNames;

  String? errorText;

  String hhmm(TimeOfDay tod) =>
      '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';

  return showDialog<ScheduleSlotResult>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        final days = dayNames[lang] ?? dayNames['en']!;
        return AlertDialog(
          title: Text(t(_WeeklyScheduleScreenState._title)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t(dayLabel), style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (int d = 1; d <= 5; d++)
                      ChoiceChip(
                        label: Text(days[d - 1]),
                        selected: day == d,
                        onSelected: (_) => setD(() => day = d),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                              context: ctx, initialTime: from);
                          if (picked != null) setD(() => from = picked);
                        },
                        child: Text('${t(fromLbl)}: ${hhmm(from)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                              context: ctx, initialTime: to);
                          if (picked != null) setD(() => to = picked);
                        },
                        child: Text('${t(toLbl)}: ${hhmm(to)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: t(subjectLabel),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(t(lessonLbl)),
                      selected: kind == SlotKind.lesson,
                      onSelected: (_) => setD(() => kind = SlotKind.lesson),
                    ),
                    ChoiceChip(
                      label: Text(t(lectureLbl)),
                      selected: kind == SlotKind.lecture,
                      onSelected: (_) => setD(() => kind = SlotKind.lecture),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: t(locationLabel),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline,
                          size: 18, color: Theme.of(ctx).colorScheme.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(errorText!,
                            style: TextStyle(
                                color: Theme.of(ctx).colorScheme.error,
                                fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (existing != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => Navigator.pop(
                    ctx, const ScheduleSlotResult(delete: true)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t(cancel)),
            ),
            FilledButton(
              onPressed: () {
                final fromMin = from.hour * 60 + from.minute;
                final toMin = to.hour * 60 + to.minute;
                final slot = existing != null
                    ? existing.copyWith(
                        day: day,
                        fromMinutes: fromMin,
                        toMinutes: toMin,
                        subject: subjectCtrl.text.trim(),
                        kind: kind,
                        location: locationCtrl.text.trim(),
                      )
                    : svc.newSlot(
                        day: day,
                        fromMinutes: fromMin,
                        toMinutes: toMin,
                        subject: subjectCtrl.text.trim(),
                        kind: kind,
                        location: locationCtrl.text.trim().isEmpty
                            ? null
                            : locationCtrl.text.trim(),
                      );
                // Валидация: краят след началото + без припокриване в деня.
                if (!slot.hasValidRange) {
                  setD(() => errorText = t(badRange));
                  return;
                }
                final conflict = svc.firstConflict(slot);
                if (conflict != null) {
                  final label = conflict.subject.trim().isNotEmpty
                      ? conflict.subject.trim()
                      : t(busyFallback);
                  final range = '${conflict.fromLabel}–${conflict.toLabel}';
                  setD(() => errorText = t(overlapMsg)
                      .replaceFirst('{0}', label)
                      .replaceFirst('{1}', range));
                  return;
                }
                Navigator.pop(ctx, ScheduleSlotResult(slot: slot));
              },
              child: Text(t(save)),
            ),
          ],
        );
      },
    ),
  );
}
