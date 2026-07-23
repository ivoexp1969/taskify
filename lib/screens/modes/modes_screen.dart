import 'package:flutter/material.dart';

import '../../services/school_calendar_service.dart';
import '../../services/university_service.dart';
import '../../widgets/school_countdown_card.dart';
import '../../widgets/exam_helper_card.dart';
import '../../utils/localization.dart';
import 'student_onboarding_screen.dart';
import 'weekly_schedule_screen.dart';

/// Таб „Уча 🎓" — вход към режимите за учащи: **Ученик** (готов, българска учебна
/// година + обратно броене) и **Студент** (Фаза 4 — предстои). Всяка карта показва
/// текущия статус; тап отваря настройката ѝ.
class ModesScreen extends StatefulWidget {
  const ModesScreen({super.key});

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
  static const _off = {
    'en': 'Off', 'bg': 'Изключен', 'de': 'Aus', 'fr': 'Désactivé',
    'it': 'Disattivato', 'el': 'Ανενεργό', 'es': 'Desactivado',
    'pt': 'Desativado', 'ru': 'Выключен', 'tr': 'Kapalı', 'ja': 'オフ',
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
  static const _setUp = {
    'en': 'Set up', 'bg': 'Настрой', 'de': 'Einrichten', 'fr': 'Configurer',
    'it': 'Configura', 'el': 'Ρύθμιση', 'es': 'Configurar', 'pt': 'Configurar',
    'ru': 'Настроить', 'tr': 'Kur', 'ja': '設定',
  };
  static const _mySchedule = {
    'en': 'My schedule', 'bg': 'Моето разписание', 'de': 'Mein Stundenplan',
    'fr': 'Mon emploi du temps', 'it': 'Il mio orario', 'el': 'Το πρόγραμμά μου',
    'es': 'Mi horario', 'pt': 'O meu horário', 'ru': 'Моё расписание',
    'tr': 'Ders programım', 'ja': '時間割',
  };

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

  Widget _modeCard({
    required String emoji,
    required String title,
    required String status,
    required bool enabled,
    bool comingSoon = false,
    VoidCallback? onTap,
    Widget? extra,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          ListTile(
            leading: Text(emoji, style: const TextStyle(fontSize: 30)),
            title: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            subtitle: Text(status,
                style: TextStyle(
                    color: enabled
                        ? const Color(0xFF0AA674)
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: enabled ? FontWeight.w600 : FontWeight.normal)),
            trailing: comingSoon
                ? Chip(
                    label: Text(status, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact)
                : const Icon(Icons.chevron_right),
            onTap: comingSoon ? null : onTap,
            enabled: !comingSoon,
          ),
          if (extra != null) extra,
        ],
      ),
    );
  }

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
          final pupilStatus = pupilOn
              ? '${_school.grade} ${_t(_gradeShort, lang)}'
              : _t(_off, lang);
          final studentOn = _uni.enabled && _uni.profile != null;
          final studentStatus = studentOn
              ? (_uni.displayUniversityName ?? _t(_setUp, lang))
              : _t(_off, lang);
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: [
              // Показва се САМО активният режим (изборът Ученик/Студент е от
              // Настройки → Училищен режим).
              if (!pupilOn && !studentOn)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  child: Text(_t(_pickInSettings, lang),
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
                ),
              if (pupilOn)
                _modeCard(
                  emoji: '🎒',
                  title: _t(_pupil, lang),
                  status: pupilStatus,
                  enabled: true,
                  onTap: () => _configurePupil(lang),
                  extra: const Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(12, 0, 12, 4),
                        child: SchoolCountdownCard(),
                      ),
                      ExamHelperCard(),
                    ],
                  ),
                ),
              if (studentOn)
                _modeCard(
                  emoji: '🎓',
                  title: _t(_student, lang),
                  status: studentStatus,
                  enabled: true,
                  onTap: () async {
                    await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const StudentOnboardingScreen(),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                ),
              if (pupilOn || studentOn)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: const Text('📅', style: TextStyle(fontSize: 26)),
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
