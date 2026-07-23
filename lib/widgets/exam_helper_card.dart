import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/school_calendar.dart';
import '../models/task.dart';
import '../models/category.dart';
import '../services/school_calendar_service.dart';
import '../utils/localization.dart';
import '../utils/subtask_format.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';

/// Помощник НВО/ДЗИ (Режими Уча) — показва се САМО за класове 4, 7, 10, 12 и
/// само ако има предстоящи изпити за класа (от Firestore `school_calendar`).
/// За другите класове не се показва нищо (извън обхвата на V1).
///
/// Всяка секция изрежда изпитите с обратно броене + бутон „Създай учебна
/// задача", който прави задача „Подготовка за [изпит]" с учебни сесии през ден
/// в продължение на X дни (по подразбиране 30).
class ExamHelperCard extends StatelessWidget {
  const ExamHelperCard({super.key});

  static const Set<int> _examGrades = {4, 7, 10, 12};

  static String _t(Map<String, String> m, String lang) => m[lang] ?? m['en']!;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: SchoolCalendarService.revision,
      builder: (context, _, __) {
        final svc = SchoolCalendarService();
        final grade = svc.grade;
        if (!svc.enabled || grade == null || !_examGrades.contains(grade)) {
          return const SizedBox.shrink();
        }
        final exams = svc.upcomingExams();
        if (exams.isEmpty) return const SizedBox.shrink();

        final lang = LanguageScope.of(context).locale.languageCode;
        final theme = Theme.of(context);
        return Card(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_sectionTitle(lang, grade),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: theme.colorScheme.primary)),
                const SizedBox(height: 4),
                for (final e in exams) _examRow(context, lang, e),
              ],
            ),
          ),
        );
      },
    );
  }

  String _sectionTitle(String lang, int grade) {
    if (grade == 12) {
      return _t(const {
        'en': 'State matriculation (Matura)', 'bg': 'ДЗИ (матура)',
        'de': 'Abiturprüfungen', 'fr': 'Baccalauréat', 'it': 'Esame di maturità',
        'el': 'Απολυτήριες εξετάσεις', 'es': 'Bachillerato', 'pt': 'Exames finais',
        'ru': 'Выпускные экзамены', 'tr': 'Olgunluk sınavı', 'ja': '卒業試験',
      }, lang);
    }
    final nvo = _t(const {
      'en': 'National exams', 'bg': 'НВО', 'de': 'Landesweite Prüfungen',
      'fr': 'Épreuves nationales', 'it': 'Prove nazionali', 'el': 'Εθνικές εξετάσεις',
      'es': 'Pruebas nacionales', 'pt': 'Provas nacionais', 'ru': 'Нац. оценивание',
      'tr': 'Ulusal sınavlar', 'ja': '全国テスト',
    }, lang);
    final gradeWord = _t(const {
      'en': 'grade', 'bg': 'клас', 'de': 'Klasse', 'fr': 'classe', 'it': 'classe',
      'el': 'τάξη', 'es': 'grado', 'pt': 'ano', 'ru': 'класс', 'tr': 'sınıf',
      'ja': '年生',
    }, lang);
    return '$nvo ($grade. $gradeWord)';
  }

  Widget _examRow(BuildContext context, String lang, SchoolExam e) {
    final theme = Theme.of(context);
    final n = daysBetween(DateTime.now(), e.date);
    final months = _months[lang] ?? _months['en']!;
    final dateStr = '${e.date.day} ${months[e.date.month - 1]}';
    final rel = n <= 0
        ? _t(const {
            'en': 'today', 'bg': 'днес', 'de': 'heute', 'fr': "aujourd'hui",
            'it': 'oggi', 'el': 'σήμερα', 'es': 'hoy', 'pt': 'hoje',
            'ru': 'сегодня', 'tr': 'bugün', 'ja': '今日',
          }, lang)
        : _t(const {
            'en': 'in {n} days', 'bg': 'след {n} дни', 'de': 'in {n} Tagen',
            'fr': 'dans {n} jours', 'it': 'tra {n} giorni', 'el': 'σε {n} μέρες',
            'es': 'en {n} días', 'pt': 'em {n} dias', 'ru': 'через {n} дн.',
            'tr': '{n} gün sonra', 'ja': 'あと{n}日',
          }, lang).replaceAll('{n}', '$n');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📝', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  e.name.isNotEmpty ? e.name : (e.subject ?? '—'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (!e.mandatory)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    _t(const {
                      'en': 'optional', 'bg': 'по избор', 'de': 'optional',
                      'fr': 'au choix', 'it': 'facoltativo', 'el': 'προαιρετικό',
                      'es': 'opcional', 'pt': 'opcional', 'ru': 'по выбору',
                      'tr': 'seçmeli', 'ja': '選択',
                    }, lang),
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 2),
            child: Text('$dateStr · $rel',
                style: TextStyle(
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurfaceVariant)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(left: 18),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              icon: const Icon(Icons.add_task, size: 16),
              label: Text(_t(const {
                'en': 'Create study task', 'bg': 'Създай учебна задача',
                'de': 'Lernaufgabe erstellen', 'fr': 'Créer une tâche de révision',
                'it': 'Crea attività di studio', 'el': 'Δημιουργία εργασίας μελέτης',
                'es': 'Crear tarea de estudio', 'pt': 'Criar tarefa de estudo',
                'ru': 'Создать учебную задачу', 'tr': 'Çalışma görevi oluştur',
                'ja': '学習タスクを作成',
              }, lang)),
              onPressed: () => _createStudyTask(context, lang, e),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createStudyTask(
      BuildContext context, String lang, SchoolExam e) async {
    int days = await _askDays(context, lang) ?? -1;
    if (days <= 0) return;
    if (!context.mounted) return;

    final taskBox = Hive.box<Task>('tasks');
    final categoryBox = Hive.box<Category>('categories');
    final categories =
        categoryBox.values.where((c) => c.id != 'documents').toList();
    if (categories.isEmpty) return;
    final categoryId = categories.first.id;

    // Учебни сесии през ден в прозорец от [days] дни, но не след изпита.
    final today = DateTime.now();
    final t0 = DateTime(today.year, today.month, today.day);
    final windowEnd = t0.add(Duration(days: days));
    final examDay = DateTime(e.date.year, e.date.month, e.date.day);
    final end = windowEnd.isBefore(examDay) ? windowEnd : examDay;
    final months = _months[lang] ?? _months['en']!;
    final sessionWord = _t(const {
      'en': 'Study session', 'bg': 'Учебна сесия', 'de': 'Lerneinheit',
      'fr': 'Session de révision', 'it': 'Sessione di studio', 'el': 'Μελέτη',
      'es': 'Sesión de estudio', 'pt': 'Sessão de estudo', 'ru': 'Учебная сессия',
      'tr': 'Çalışma', 'ja': '学習セッション',
    }, lang);

    final subtasks = <String>[];
    for (var d = t0;
        !d.isAfter(end);
        d = d.add(const Duration(days: 2))) {
      subtasks.add(SubtaskCodec.format(
          text: '$sessionWord · ${d.day} ${months[d.month - 1]}'));
    }

    final prep = _t(const {
      'en': 'Prepare for', 'bg': 'Подготовка за', 'de': 'Vorbereitung auf',
      'fr': 'Préparer', 'it': 'Preparazione per', 'el': 'Προετοιμασία για',
      'es': 'Preparación para', 'pt': 'Preparação para', 'ru': 'Подготовка к',
      'tr': 'Hazırlık', 'ja': '準備',
    }, lang);
    final title = '$prep ${e.name}';

    final task = Task(
      title: title,
      dueDate: DateTime(e.date.year, e.date.month, e.date.day, 9),
      categoryId: categoryId,
      priority: 2,
      taskKind: 'homework',
      subtasks: subtasks.isEmpty ? null : subtasks,
    );
    await taskBox.add(task);
    await NotificationService().scheduleForTask(task);
    await WidgetService.updateWidget();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t(const {
          'en': 'Study task created', 'bg': 'Учебната задача е създадена',
          'de': 'Lernaufgabe erstellt', 'fr': 'Tâche de révision créée',
          'it': 'Attività di studio creata', 'el': 'Δημιουργήθηκε εργασία μελέτης',
          'es': 'Tarea de estudio creada', 'pt': 'Tarefa de estudo criada',
          'ru': 'Учебная задача создана', 'tr': 'Çalışma görevi oluşturuldu',
          'ja': '学習タスクを作成しました',
        }, lang)),
      ));
    }
  }

  /// Пита за брой дни (по подразбиране 30) чрез слайдер.
  Future<int?> _askDays(BuildContext context, String lang) {
    int days = 30;
    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(_t(const {
            'en': 'How many days to prepare?', 'bg': 'Колко дни подготовка?',
            'de': 'Wie viele Tage vorbereiten?', 'fr': 'Combien de jours ?',
            'it': 'Quanti giorni di preparazione?', 'el': 'Πόσες μέρες προετοιμασία;',
            'es': '¿Cuántos días de preparación?', 'pt': 'Quantos dias de preparação?',
            'ru': 'Сколько дней на подготовку?', 'tr': 'Kaç gün hazırlık?',
            'ja': '準備日数は？',
          }, lang)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$days',
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold)),
              Slider(
                value: days.toDouble(),
                min: 7,
                max: 90,
                divisions: 83,
                label: '$days',
                onChanged: (v) => setD(() => days = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_t(const {
                'en': 'Cancel', 'bg': 'Отказ', 'de': 'Abbrechen', 'fr': 'Annuler',
                'it': 'Annulla', 'el': 'Άκυρο', 'es': 'Cancelar', 'pt': 'Cancelar',
                'ru': 'Отмена', 'tr': 'İptal', 'ja': 'キャンセル',
              }, lang)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, days),
              child: Text(_t(const {
                'en': 'Create', 'bg': 'Създай', 'de': 'Erstellen', 'fr': 'Créer',
                'it': 'Crea', 'el': 'Δημιουργία', 'es': 'Crear', 'pt': 'Criar',
                'ru': 'Создать', 'tr': 'Oluştur', 'ja': '作成',
              }, lang)),
            ),
          ],
        ),
      ),
    );
  }

  static const Map<String, List<String>> _months = {
    'en': ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'],
    'bg': ['яну','фев','мар','апр','май','юни','юли','авг','сеп','окт','ное','дек'],
    'de': ['Jan','Feb','März','Apr','Mai','Jun','Jul','Aug','Sep','Okt','Nov','Dez'],
    'fr': ['janv','févr','mars','avr','mai','juin','juil','août','sept','oct','nov','déc'],
    'it': ['gen','feb','mar','apr','mag','giu','lug','ago','set','ott','nov','dic'],
    'el': ['Ιαν','Φεβ','Μαρ','Απρ','Μαϊ','Ιουν','Ιουλ','Αυγ','Σεπ','Οκτ','Νοε','Δεκ'],
    'es': ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'],
    'pt': ['jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez'],
    'ru': ['янв','фев','мар','апр','мая','июн','июл','авг','сен','окт','ноя','дек'],
    'tr': ['Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'],
    'ja': ['1月','2月','3月','4月','5月','6月','7月','8月','9月','10月','11月','12月'],
  };
}
