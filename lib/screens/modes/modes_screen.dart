import 'package:flutter/material.dart';

import '../../models/school_calendar.dart';
import '../../models/university.dart';
import '../../services/school_calendar_service.dart';
import '../../services/university_service.dart';
import '../../widgets/exam_helper_card.dart';
import '../../widgets/study_countdown_card.dart';
import '../../widgets/today_schedule_card.dart';
import '../../widgets/study_today_tasks_card.dart';
import '../../utils/localization.dart';
import 'student_onboarding_screen.dart';
import 'weekly_schedule_screen.dart';

/// Таб „Обучение" — плътен екран за учащия: компактна карта на профила, обратно
/// броене до значими дати, днешното разписание, днешните учебни задачи и
/// предстоящите изпити. Показва се само активният режим (Ученик ИЛИ Студент).
class ModesScreen extends StatefulWidget {
  /// Превключва към таб Задачи (подаден от началния екран, за бутона „Виж
  /// всички задачи" в секцията с днешните задачи).
  final VoidCallback? onOpenTasks;

  const ModesScreen({super.key, this.onOpenTasks});

  @override
  State<ModesScreen> createState() => _ModesScreenState();
}

class _ModesScreenState extends State<ModesScreen> {
  final _school = SchoolCalendarService();
  final _uni = UniversityService();
  final _schoolCtrl = TextEditingController();

  @override
  void dispose() {
    _schoolCtrl.dispose();
    super.dispose();
  }

  static String _t(Map<String, String> m, String lang) =>
      m[lang] ?? m['en']!;

  static const _title = {
    'en': 'Learning', 'bg': 'Обучение', 'de': 'Bildung', 'fr': 'Éducation',
    'it': 'Istruzione', 'el': 'Εκπαίδευση', 'es': 'Educación', 'pt': 'Educação',
    'ru': 'Обучение', 'tr': 'Eğitim', 'ja': '学び',
  };
  static const _pupil = {
    'en': 'Pupil', 'bg': 'Ученик', 'de': 'Schüler', 'fr': 'Élève',
    'it': 'Alunno', 'el': 'Μαθητής', 'es': 'Alumno', 'pt': 'Aluno',
    'ru': 'Ученик', 'tr': 'Öğrenci', 'ja': '生徒',
  };
  static const _student = {
    'en': 'Student', 'bg': 'Студент', 'de': 'Student', 'fr': 'Étudiant',
    'it': 'Studente', 'el': 'Φοιτητής', 'es': 'Estudiante', 'pt': 'Estudante',
    'ru': 'Студент', 'tr': 'Üniversite', 'ja': '大学生',
  };
  static const _gradeShort = {
    'en': 'grade', 'bg': 'клас', 'de': 'Klasse', 'fr': 'classe',
    'it': 'classe', 'el': 'τάξη', 'es': 'grado', 'pt': 'ano',
    'ru': 'класс', 'tr': 'sınıf', 'ja': '年生',
  };
  static const _pickInSettings = {
    'en': 'Choose Pupil or Student in Settings → School mode.',
    'bg': 'Избери Ученик или Студент от Настройки → Училищен режим.',
    'de': 'Wähle Schüler oder Student in Einstellungen → Schulmodus.',
    'fr': 'Choisis Élève ou Étudiant dans Réglages → Mode école.',
    'it': 'Scegli Alunno o Studente in Impostazioni → Modalità scuola.',
    'el': 'Διάλεξε Μαθητή ή Φοιτητή στις Ρυθμίσεις → Λειτουργία σχολείου.',
    'es': 'Elige Alumno o Estudiante en Ajustes → Modo escolar.',
    'pt': 'Escolhe Aluno ou Estudante em Definições → Modo escolar.',
    'ru': 'Выбери Ученика или Студента в Настройках → Школьный режим.',
    'tr': 'Ayarlar → Okul modunda Öğrenci veya Üniversite seç.',
    'ja': '設定 → 学校モードで生徒か大学生を選択。',
  };
  static const _pickGrade = {
    'en': 'Pick your grade', 'bg': 'Избери класа си', 'de': 'Wähle deine Klasse',
    'fr': 'Choisis ta classe', 'it': 'Scegli la classe', 'el': 'Διάλεξε τάξη',
    'es': 'Elige tu grado', 'pt': 'Escolhe o teu ano', 'ru': 'Выбери класс',
    'tr': 'Sınıfını seç', 'ja': '学年を選ぶ',
  };
  static const _turnOff = {
    'en': 'Turn off', 'bg': 'Изключи', 'de': 'Ausschalten', 'fr': 'Désactiver',
    'it': 'Disattiva', 'el': 'Απενεργοποίηση', 'es': 'Desactivar',
    'pt': 'Desativar', 'ru': 'Выключить', 'tr': 'Kapat', 'ja': 'オフにする',
  };
  static const _schoolLabel = {
    'en': 'School (optional)', 'bg': 'Училище (по избор)', 'de': 'Schule (optional)',
    'fr': 'École (facultatif)', 'it': 'Scuola (facoltativo)', 'el': 'Σχολείο (προαιρετικό)',
    'es': 'Escuela (opcional)', 'pt': 'Escola (opcional)', 'ru': 'Школа (необязательно)',
    'tr': 'Okul (isteğe bağlı)', 'ja': '学校（任意）',
  };
  static const _mySchedule = {
    'en': 'My schedule', 'bg': 'Моето разписание', 'de': 'Mein Stundenplan',
    'fr': 'Mon emploi du temps', 'it': 'Il mio orario', 'el': 'Το πρόγραμμά μου',
    'es': 'Mi horario', 'pt': 'O meu horário', 'ru': 'Моё расписание',
    'tr': 'Ders programım', 'ja': '時間割',
  };
  static const _classWord = {
    'en': 'grade', 'bg': 'клас', 'de': 'Klasse', 'fr': 'classe',
    'it': 'classe', 'el': 'τάξη', 'es': 'grado', 'pt': 'ano',
    'ru': 'класс', 'tr': 'sınıf', 'ja': '年生',
  };
  // Кратък етикет за студентска група (пред номера, напр. „гр. 12А").
  static const _groupShort = {
    'en': 'grp', 'bg': 'гр.', 'de': 'Gr.', 'fr': 'grp', 'it': 'gr.',
    'el': 'ομ.', 'es': 'gr.', 'pt': 'gr.', 'ru': 'гр.', 'tr': 'grp', 'ja': '班',
  };
  static const _examsTitle = {
    'en': 'Upcoming exams', 'bg': 'Предстоящи изпити', 'de': 'Anstehende Prüfungen',
    'fr': 'Examens à venir', 'it': 'Prossimi esami', 'el': 'Επερχόμενες εξετάσεις',
    'es': 'Próximos exámenes', 'pt': 'Próximos exames', 'ru': 'Предстоящие экзамены',
    'tr': 'Yaklaşan sınavlar', 'ja': '今後の試験',
  };
  static const _todayWord = {
    'en': 'today', 'bg': 'днес', 'de': 'heute', 'fr': "aujourd'hui",
    'it': 'oggi', 'el': 'σήμερα', 'es': 'hoy', 'pt': 'hoje',
    'ru': 'сегодня', 'tr': 'bugün', 'ja': '今日',
  };
  static const _inDays = {
    'en': 'in {n} days', 'bg': 'след {n} дни', 'de': 'in {n} Tagen',
    'fr': 'dans {n} jours', 'it': 'tra {n} giorni', 'el': 'σε {n} μέρες',
    'es': 'en {n} días', 'pt': 'em {n} dias', 'ru': 'через {n} дн.',
    'tr': '{n} gün sonra', 'ja': 'あと{n}日',
  };
  // Форма на обучение (студент) по ключ.
  static const _formLabels = {
    'redovno': {
      'en': 'Full-time', 'bg': 'Редовно', 'de': 'Vollzeit', 'fr': 'Présentiel',
      'it': 'Diurno', 'el': 'Πλήρης', 'es': 'Presencial', 'pt': 'Presencial',
      'ru': 'Очно', 'tr': 'Örgün', 'ja': '通学',
    },
    'zadochno': {
      'en': 'Part-time', 'bg': 'Задочно', 'de': 'Teilzeit', 'fr': 'À distance',
      'it': 'Part-time', 'el': 'Μερική', 'es': 'A distancia', 'pt': 'Pós-laboral',
      'ru': 'Заочно', 'tr': 'Uzaktan', 'ja': '通信',
    },
    'distancionno': {
      'en': 'Distance', 'bg': 'Дистанционно', 'de': 'Fernstudium', 'fr': 'En ligne',
      'it': 'A distanza', 'el': 'Εξ αποστάσεως', 'es': 'En línea', 'pt': 'À distância',
      'ru': 'Дистанционно', 'tr': 'Çevrimiçi', 'ja': 'オンライン',
    },
  };

  String _courseLabel(String lang, int year) {
    switch (lang) {
      case 'bg': return '$year. курс';
      case 'ru': return '$year курс';
      case 'de': return '$year. Jahr';
      case 'fr': return year == 1 ? '1re année' : '${year}e année';
      case 'ja': return '$year年';
      default: return 'Year $year';
    }
  }

  Future<void> _configurePupil(String lang) async {
    _schoolCtrl.text = _school.school ?? '';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text('🎒 ${_t(_pickGrade, lang)}',
                    style: Theme.of(ctx).textTheme.titleLarge),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int g = 1; g <= 12; g++)
                    ChoiceChip(
                      label: Text('$g ${_t(_gradeShort, lang)}'),
                      selected: _school.enabled && _school.grade == g,
                      onSelected: (_) async {
                        await _school.setGrade(g);
                        await _school.setSchool(_schoolCtrl.text);
                        await _school.setEnabled(true);
                        // Режимите са взаимно изключващи се (ученик ИЛИ студент).
                        await _uni.setEnabled(false);
                        if (mounted) setState(() {});
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                ].map((w) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4), child: w)).toList(),
              ),
              // Училище (опционално, свободен текст — за бъдещи функции).
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: TextField(
                  controller: _schoolCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: _t(_schoolLabel, lang),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (v) => _school.setSchool(v),
                ),
              ),
              if (_school.enabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextButton.icon(
                    icon: const Icon(Icons.power_settings_new),
                    label: Text(_t(_turnOff, lang)),
                    onPressed: () async {
                      await _school.setSchool(_schoolCtrl.text);
                      await _school.setEnabled(false);
                      if (mounted) setState(() {});
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Компактна карта на профила (Ф7) — един ред „кой е", тап → пълния екран.
  Widget _compactProfile({
    required String emoji,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: ListTile(
        leading: Text(emoji, style: const TextStyle(fontSize: 28)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: (subtitle != null && subtitle.isNotEmpty)
            ? Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  String _studentSubtitle(String lang) {
    final p = _uni.profile;
    if (p == null) return '';
    final parts = <String>[
      _courseLabel(lang, p.year),
      if (p.groupNumber.isNotEmpty) '${_t(_groupShort, lang)} ${p.groupNumber}',
      if (p.program.isNotEmpty) p.program,
      _t(_formLabels[p.form.key] ?? _formLabels['redovno']!, lang),
    ];
    return parts.join(' · ');
  }

  /// Предстоящи изпити за студент (Ф6) — от ръчните ключови дати `exam`.
  Widget _studentExams(String lang) {
    final now = DateTime.now();
    final exams = _uni
        .upcomingKeyDates(now)
        .where((d) => d.kind == StudentDateKind.exam)
        .toList();
    if (exams.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🎯 ${_t(_examsTitle, lang)}',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: theme.colorScheme.primary)),
            const SizedBox(height: 4),
            for (final e in exams.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Text('📝', style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.title.isNotEmpty
                            ? e.title
                            : _t(_examsTitle, lang),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_relDays(lang, daysBetween(now, e.date)),
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _relDays(String lang, int n) => n <= 0
      ? _t(_todayWord, lang)
      : _t(_inDays, lang).replaceAll('{n}', '$n');

  @override
  Widget build(BuildContext context) {
    final lang = LanguageScope.of(context).locale.languageCode;
    return Scaffold(
      appBar: AppBar(
        title: Text('📚 ${_t(_title, lang)}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          SchoolCalendarService.revision,
          SchoolCalendarService.enabledNotifier,
          UniversityService.revision,
          UniversityService.enabledNotifier,
        ]),
        builder: (context, _) {
          final pupilOn = _school.enabled && _school.grade != null;
          final studentOn = _uni.enabled && _uni.profile != null;
          final active = pupilOn || studentOn;
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
            children: [
              // Показва се САМО активният режим (изборът Ученик/Студент е от
              // Настройки → Училищен режим / Профил).
              if (!active)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(_t(_pickInSettings, lang),
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
                ),

              // ── Ф7: компактна карта на профила ──
              if (pupilOn)
                _compactProfile(
                  emoji: '🎒',
                  title:
                      '${_t(_pupil, lang)} · ${_school.grade} ${_t(_classWord, lang)}',
                  subtitle: _school.school,
                  onTap: () => _configurePupil(lang),
                ),
              if (studentOn)
                _compactProfile(
                  emoji: '🎓',
                  title:
                      '${_t(_student, lang)} · ${_uni.displayUniversityName ?? ''}',
                  subtitle: _studentSubtitle(lang),
                  onTap: () async {
                    await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const StudentOnboardingScreen(),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                ),

              // ── Ф2: обратно броене (реактивно, Ученик/Студент) ──
              if (active) const StudyCountdownCard(),

              // ── Ф3: днешно разписание ──
              if (active) const TodayScheduleCard(),

              // ── Ф5: днешни учебни задачи ──
              if (active) StudyTodayTasksCard(onOpenTasks: widget.onOpenTasks),

              // ── Ф6: предстоящи изпити ──
              if (pupilOn) const ExamHelperCard(),
              if (studentOn) _studentExams(lang),

              // ── Вход към пълния екран „Моето разписание" ──
              if (active)
                Card(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: ListTile(
                    leading: const Text('📅', style: TextStyle(fontSize: 24)),
                    title: Text(_t(_mySchedule, lang),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WeeklyScheduleScreen(),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
