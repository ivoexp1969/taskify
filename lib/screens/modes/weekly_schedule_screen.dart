import 'package:flutter/material.dart';

import '../../models/weekly_schedule.dart';
import '../../services/weekly_schedule_service.dart';
import '../../services/university_service.dart';
import '../../utils/category_colors.dart';
import '../../utils/localization.dart';
import 'study_events_screen.dart';

/// Изглед на разписанието по седмичен шаблон: всички слотове, само видимите в
/// четна или само в нечетна седмица.
enum _WeekView { all, even, odd }

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

  /// Избран ден в таб-навигацията (1=пон … 5=пет). По подразбиране днешният
  /// работен ден (или понеделник през уикенда).
  late int _selectedDay;

  /// Филтър на изгледа по седмичен шаблон (само студенти).
  _WeekView _weekView = _WeekView.all;

  @override
  void initState() {
    super.initState();
    final wd = DateTime.now().weekday;
    _selectedDay = wd >= 1 && wd <= 5 ? wd : 1;
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
  // Централно празно състояние (цялото разписание за срока е празно).
  static const _emptyTitle = {
    'en': 'No classes yet', 'bg': 'Още нямаш въведени часове',
    'de': 'Noch keine Stunden', 'fr': 'Aucun cours pour l\'instant',
    'it': 'Ancora nessuna lezione', 'el': 'Δεν υπάρχουν μαθήματα ακόμη',
    'es': 'Aún no hay clases', 'pt': 'Ainda não há aulas',
    'ru': 'Пока нет занятий', 'tr': 'Henüz ders yok', 'ja': 'まだ授業がありません',
  };
  static const _addFirst = {
    'en': 'Add your first class →', 'bg': 'Добави първия си час →',
    'de': 'Erste Stunde hinzufügen →', 'fr': 'Ajoute ton premier cours →',
    'it': 'Aggiungi la prima lezione →', 'el': 'Πρόσθεσε το πρώτο μάθημα →',
    'es': 'Añade tu primera clase →', 'pt': 'Adiciona a tua primeira aula →',
    'ru': 'Добавь первое занятие →', 'tr': 'İlk dersini ekle →',
    'ja': '最初の授業を追加 →',
  };
  // Индикатор за текущата седмица (студент + зададено начало на семестъра).
  static const _thisWeekEven = {
    'en': 'This week is even', 'bg': 'Тази седмица е четна',
    'de': 'Diese Woche ist gerade', 'fr': 'Cette semaine est paire',
    'it': 'Questa settimana è pari', 'el': 'Αυτή η εβδομάδα είναι ζυγή',
    'es': 'Esta semana es par', 'pt': 'Esta semana é par',
    'ru': 'Эта неделя чётная', 'tr': 'Bu hafta çift', 'ja': '今週は偶数週',
  };
  static const _thisWeekOdd = {
    'en': 'This week is odd', 'bg': 'Тази седмица е нечетна',
    'de': 'Diese Woche ist ungerade', 'fr': 'Cette semaine est impaire',
    'it': 'Questa settimana è dispari', 'el': 'Αυτή η εβδομάδα είναι μονή',
    'es': 'Esta semana es impar', 'pt': 'Esta semana é ímpar',
    'ru': 'Эта неделя нечётная', 'tr': 'Bu hafta tek', 'ja': '今週は奇数週',
  };
  static const _weekNo = {
    'en': 'week {n} of the semester', 'bg': 'седмица {n} от началото на семестъра',
    'de': 'Woche {n} des Semesters', 'fr': 'semaine {n} du semestre',
    'it': 'settimana {n} del semestre', 'el': 'εβδομάδα {n} του εξαμήνου',
    'es': 'semana {n} del semestre', 'pt': 'semana {n} do semestre',
    'ru': 'неделя {n} семестра', 'tr': 'dönemin {n}. haftası',
    'ja': '学期の第{n}週',
  };
  static const _setSemesterStart = {
    'en': 'Set semester start →', 'bg': 'Задай начало на семестъра →',
    'de': 'Semesterbeginn festlegen →', 'fr': 'Définir le début du semestre →',
    'it': 'Imposta inizio semestre →', 'el': 'Όρισε έναρξη εξαμήνου →',
    'es': 'Definir inicio de semestre →', 'pt': 'Definir início do semestre →',
    'ru': 'Указать начало семестра →', 'tr': 'Dönem başını ayarla →',
    'ja': '学期の開始日を設定 →',
  };
  // Филтър на изгледа (студент).
  static const _viewAll = {
    'en': 'All', 'bg': 'Всички', 'de': 'Alle', 'fr': 'Toutes', 'it': 'Tutte',
    'el': 'Όλα', 'es': 'Todas', 'pt': 'Todas', 'ru': 'Все', 'tr': 'Tümü',
    'ja': 'すべて',
  };
  static const _viewEven = {
    'en': 'Even', 'bg': 'Четна', 'de': 'Gerade', 'fr': 'Paire', 'it': 'Pari',
    'el': 'Ζυγή', 'es': 'Par', 'pt': 'Par', 'ru': 'Чётная', 'tr': 'Çift',
    'ja': '偶数',
  };
  static const _viewOdd = {
    'en': 'Odd', 'bg': 'Нечетна', 'de': 'Ungerade', 'fr': 'Impaire',
    'it': 'Dispari', 'el': 'Μονή', 'es': 'Impar', 'pt': 'Ímpar',
    'ru': 'Нечётная', 'tr': 'Tek', 'ja': '奇数',
  };
  // Кратки етикети за седмичния шаблон на слота (badge в списъка).
  static const _evenBadge = {
    'en': 'even', 'bg': 'четна', 'de': 'gerade', 'fr': 'paire', 'it': 'pari',
    'el': 'ζυγή', 'es': 'par', 'pt': 'par', 'ru': 'чёт.', 'tr': 'çift', 'ja': '偶',
  };
  static const _oddBadge = {
    'en': 'odd', 'bg': 'нечетна', 'de': 'ungerade', 'fr': 'impaire',
    'it': 'dispari', 'el': 'μονή', 'es': 'impar', 'pt': 'ímpar', 'ru': 'нечёт.',
    'tr': 'tek', 'ja': '奇',
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

  bool _passesView(ScheduleSlot s) {
    switch (_weekView) {
      case _WeekView.all:
        return true;
      case _WeekView.even:
        return s.weekPattern != WeekPattern.oddOnly;
      case _WeekView.odd:
        return s.weekPattern != WeekPattern.evenOnly;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageScope.of(context).locale.languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(_t(_title, lang))),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addForDay(lang, _selectedDay),
              icon: const Icon(Icons.add),
              label: Text(_t(_addLesson, lang)),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedBuilder(
              animation: WeeklyScheduleService.revision,
              builder: (context, _) {
                final termEmpty = _svc.isEmptyForTerm();
                return Column(
                  children: [
                    _termSelector(context, lang),
                    _weekIndicator(context, lang),
                    _viewFilter(context, lang),
                    _dayTabs(context, lang),
                    const Divider(height: 1),
                    Expanded(
                      child: termEmpty
                          ? _centralEmpty(context, lang)
                          : ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(8, 8, 8, 96),
                              children: _dayContent(context, lang, _selectedDay),
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

  /// Малка карта „Тази седмица е нечетна (седмица N)" — само за студент със
  /// зададено начало на семестъра; иначе бутон „Задай начало на семестъра →".
  Widget _weekIndicator(BuildContext context, String lang) {
    if (!UniversityService().enabled) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final start = UniversityService().currentSemesterStart();
    final weekNo = currentWeekNumber(start, DateTime.now());
    if (weekNo < 1) {
      // Няма (или бъдещо) начало на семестъра → подкана да го зададе.
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            icon: const Icon(Icons.event_available, size: 18),
            label: Text(_t(_setSemesterStart, lang)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StudyEventsScreen()),
            ),
          ),
        ),
      );
    }
    final isEven = weekNo % 2 == 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(isEven ? Icons.looks_two_outlined : Icons.looks_one_outlined,
              size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(
                text: _t(isEven ? _thisWeekEven : _thisWeekOdd, lang),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text:
                    ' · ${_t(_weekNo, lang).replaceAll('{n}', '$weekNo')}',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ])),
          ),
        ],
      ),
    );
  }

  /// Филтър „Всички / Четна / Нечетна" (само студенти). Пълна ширина, за да
  /// се събира текстът на един ред.
  Widget _viewFilter(BuildContext context, String lang) {
    if (!UniversityService().enabled) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<_WeekView>(
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          segments: [
            ButtonSegment(
                value: _WeekView.all,
                label: Text(_t(_viewAll, lang),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
            ButtonSegment(
                value: _WeekView.even,
                label: Text(_t(_viewEven, lang),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
            ButtonSegment(
                value: _WeekView.odd,
                label: Text(_t(_viewOdd, lang),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
          selected: {_weekView},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _weekView = s.first),
        ),
      ),
    );
  }

  /// Табове по дни (Пн–Пт). Показва точка, ако денят има часове в текущия срок.
  Widget _dayTabs(BuildContext context, String lang) {
    final theme = Theme.of(context);
    final short = _dayNames[lang] ?? _dayNames['en']!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          for (int day = 1; day <= 5; day++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                label: Text(short[day - 1]),
                selected: _selectedDay == day,
                avatar: _svc.forDay(day).isNotEmpty
                    ? Icon(Icons.circle,
                        size: 8, color: theme.colorScheme.primary)
                    : null,
                onSelected: (_) => setState(() => _selectedDay = day),
              ),
            ),
        ],
      ),
    );
  }

  /// Съдържанието за избрания ден: часовете (филтрирани по изгледа), цветни;
  /// празно → приятелски ред с покана.
  List<Widget> _dayContent(BuildContext context, String lang, int day) {
    final theme = Theme.of(context);
    final slots = _svc.forDay(day).where(_passesView).toList();
    if (slots.isEmpty) {
      return [
        InkWell(
          onTap: () => _addForDay(lang, day),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              children: [
                Icon(Icons.add_circle_outline,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_t(_noLessonsDay, lang),
                      style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    return [for (final s in slots) _slotCard(context, lang, s)];
  }

  Widget _slotCard(BuildContext context, String lang, ScheduleSlot s) {
    final theme = Theme.of(context);
    final color = s.colorValue != null
        ? Color(s.colorValue!)
        : theme.colorScheme.primary;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
              s.kind == SlotKind.lecture
                  ? Icons.school_outlined
                  : Icons.menu_book_outlined,
              color: color),
        ),
        title: Text(s.subject.isNotEmpty ? s.subject : '—'),
        isThreeLine: s.location != null && s.location!.isNotEmpty,
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${s.fromLabel}–${s.toLabel}'),
                if (s.weekPattern != WeekPattern.every) ...[
                  const SizedBox(width: 6),
                  _weekBadge(theme, lang, s.weekPattern),
                ],
              ],
            ),
            if (s.location != null && s.location!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('📍 ${s.location}',
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
          tooltip: _t(_deleteTip, lang),
          onPressed: () async {
            await _svc.remove(s.id);
            if (mounted) setState(() {});
          },
        ),
        onTap: () => _addOrEdit(lang, existing: s),
      ),
    );
  }

  Widget _weekBadge(ThemeData theme, String lang, WeekPattern p) {
    final txt =
        _t(p == WeekPattern.evenOnly ? _evenBadge : _oddBadge, lang);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(txt,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.tertiary)),
    );
  }

  /// Централно празно състояние за целия срок (вместо 5× „Няма часове").
  Widget _centralEmpty(BuildContext context, String lang) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 56, color: theme.colorScheme.primary.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(_t(_emptyTitle, lang),
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _addForDay(lang, _selectedDay),
              icon: const Icon(Icons.add),
              label: Text(_t(_addFirst, lang)),
            ),
          ],
        ),
      ),
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
  WeekPattern weekPattern = existing?.weekPattern ?? WeekPattern.every;
  int? colorValue = existing?.colorValue;
  // Ръчно избран цвят? (пази авто-предложението да не презапише избора.)
  bool colorTouched = existing?.colorValue != null;
  // Седмичният шаблон (четна/нечетна) е реалност за студенти → показва се само
  // в режим Студент; учениците виждат опростен диалог.
  final bool isStudent = UniversityService().enabled;

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
  // За студенти „урокът" е упражнение/семинар (различно от лекция).
  const exerciseLbl = {
    'en': 'Exercise', 'bg': 'Упражнение', 'de': 'Übung', 'fr': 'Exercices',
    'it': 'Esercitazione', 'el': 'Άσκηση', 'es': 'Práctica', 'pt': 'Prática',
    'ru': 'Практика', 'tr': 'Uygulama', 'ja': '演習',
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
  const repeatLabel = {
    'en': 'Repeats', 'bg': 'Повтаряне', 'de': 'Wiederholung', 'fr': 'Répétition',
    'it': 'Ripetizione', 'el': 'Επανάληψη', 'es': 'Repetición', 'pt': 'Repetição',
    'ru': 'Повтор', 'tr': 'Tekrar', 'ja': '繰り返し',
  };
  const everyWeek = {
    'en': 'Every week', 'bg': 'Всяка седмица', 'de': 'Jede Woche',
    'fr': 'Chaque semaine', 'it': 'Ogni settimana', 'el': 'Κάθε εβδομάδα',
    'es': 'Cada semana', 'pt': 'Todas as semanas', 'ru': 'Каждую неделю',
    'tr': 'Her hafta', 'ja': '毎週',
  };
  const evenWeek = {
    'en': 'Even week', 'bg': 'Четна седмица', 'de': 'Gerade Woche',
    'fr': 'Semaine paire', 'it': 'Settimana pari', 'el': 'Ζυγή εβδομάδα',
    'es': 'Semana par', 'pt': 'Semana par', 'ru': 'Чётная неделя',
    'tr': 'Çift hafta', 'ja': '偶数週',
  };
  const oddWeek = {
    'en': 'Odd week', 'bg': 'Нечетна седмица', 'de': 'Ungerade Woche',
    'fr': 'Semaine impaire', 'it': 'Settimana dispari', 'el': 'Μονή εβδομάδα',
    'es': 'Semana impar', 'pt': 'Semana ímpar', 'ru': 'Нечётная неделя',
    'tr': 'Tek hafta', 'ja': '奇数週',
  };
  const evenHelp = {
    'en': 'Shows only in even weeks from the semester start.',
    'bg': 'Показва се само в четните седмици от началото на семестъра.',
    'de': 'Nur in geraden Wochen ab Semesterbeginn.',
    'fr': 'Affiché uniquement les semaines paires depuis le début du semestre.',
    'it': 'Mostrato solo nelle settimane pari dall\'inizio del semestre.',
    'el': 'Εμφανίζεται μόνο σε ζυγές εβδομάδες από την έναρξη του εξαμήνου.',
    'es': 'Se muestra solo en semanas pares desde el inicio del semestre.',
    'pt': 'Aparece só nas semanas pares desde o início do semestre.',
    'ru': 'Показывается только в чётные недели от начала семестра.',
    'tr': 'Yalnızca dönem başından itibaren çift haftalarda görünür.',
    'ja': '学期開始からの偶数週にのみ表示されます。',
  };
  const oddHelp = {
    'en': 'Shows only in odd weeks from the semester start.',
    'bg': 'Показва се само в нечетните седмици от началото на семестъра.',
    'de': 'Nur in ungeraden Wochen ab Semesterbeginn.',
    'fr': 'Affiché uniquement les semaines impaires depuis le début du semestre.',
    'it': 'Mostrato solo nelle settimane dispari dall\'inizio del semestre.',
    'el': 'Εμφανίζεται μόνο σε μονές εβδομάδες από την έναρξη του εξαμήνου.',
    'es': 'Se muestra solo en semanas impares desde el inicio del semestre.',
    'pt': 'Aparece só nas semanas ímpares desde o início do semestre.',
    'ru': 'Показывается только в нечётные недели от начала семестра.',
    'tr': 'Yalnızca dönem başından itibaren tek haftalarda görünür.',
    'ja': '学期開始からの奇数週にのみ表示されます。',
  };
  const colorLabel = {
    'en': 'Color', 'bg': 'Цвят', 'de': 'Farbe', 'fr': 'Couleur', 'it': 'Colore',
    'el': 'Χρώμα', 'es': 'Color', 'pt': 'Cor', 'ru': 'Цвет', 'tr': 'Renk',
    'ja': '色',
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
                  // Ако предмет със същото име вече има цвят → предложи го (освен
                  // ако потребителят вече е избрал цвят ръчно).
                  onChanged: (v) {
                    if (colorTouched) return;
                    final suggested = svc.colorForSubject(v);
                    if (suggested != colorValue) {
                      setD(() => colorValue = suggested);
                    }
                  },
                ),
                // Тип на часа само за студенти (упражнение/лекция). При
                // учениците няма разлика — просто „час" (kind остава lesson).
                if (isStudent) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(t(exerciseLbl)),
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
                ],
                // ── Повтаряне: всяка / четна / нечетна седмица (само студенти) ──
                if (isStudent) ...[
                  const SizedBox(height: 12),
                  Text(t(repeatLabel),
                      style: Theme.of(ctx).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: Text(t(everyWeek)),
                        selected: weekPattern == WeekPattern.every,
                        onSelected: (_) =>
                            setD(() => weekPattern = WeekPattern.every),
                      ),
                      ChoiceChip(
                        label: Text(t(evenWeek)),
                        selected: weekPattern == WeekPattern.evenOnly,
                        onSelected: (_) =>
                            setD(() => weekPattern = WeekPattern.evenOnly),
                      ),
                      ChoiceChip(
                        label: Text(t(oddWeek)),
                        selected: weekPattern == WeekPattern.oddOnly,
                        onSelected: (_) =>
                            setD(() => weekPattern = WeekPattern.oddOnly),
                      ),
                    ],
                  ),
                  if (weekPattern != WeekPattern.every)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                          t(weekPattern == WeekPattern.evenOnly
                              ? evenHelp
                              : oddHelp),
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ),
                ],
                // ── Цвят на предмета ──
                const SizedBox(height: 12),
                Text(t(colorLabel), style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // „Без цвят".
                    _ColorDot(
                      color: null,
                      selected: colorValue == null,
                      onTap: () => setD(() {
                        colorValue = null;
                        colorTouched = true;
                      }),
                    ),
                    for (final c in kCategoryColors)
                      _ColorDot(
                        color: c,
                        selected: colorValue == c.toARGB32(),
                        onTap: () => setD(() {
                          colorValue = c.toARGB32();
                          colorTouched = true;
                        }),
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
                        weekPattern: weekPattern,
                        colorValue: colorValue,
                        clearColor: colorValue == null,
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
                        weekPattern: weekPattern,
                        colorValue: colorValue,
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

/// Кръгче за избор на цвят на предмета. [color] == null → „без цвят".
class _ColorDot extends StatelessWidget {
  final Color? color;
  final bool selected;
  final VoidCallback onTap;
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color ?? Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? theme.colorScheme.onSurface
                : theme.colorScheme.outlineVariant,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: color == null
            ? Icon(Icons.block,
                size: 16, color: theme.colorScheme.onSurfaceVariant)
            : (selected
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null),
      ),
    );
  }
}
