import 'package:flutter/material.dart';

import '../../services/school_calendar_service.dart';
import '../../widgets/school_countdown_card.dart';
import '../../utils/localization.dart';

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

  static String _t(Map<String, String> m, String lang) =>
      m[lang] ?? m['en']!;

  static const _title = {
    'en': 'Study', 'bg': 'Уча', 'de': 'Lernen', 'fr': 'Études',
    'it': 'Studio', 'el': 'Μελέτη', 'es': 'Estudio', 'pt': 'Estudo',
    'ru': 'Учёба', 'tr': 'Okul', 'ja': '学習',
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
  static const _soon = {
    'en': 'Coming soon', 'bg': 'Очаквайте скоро', 'de': 'Demnächst',
    'fr': 'Bientôt', 'it': 'Presto', 'el': 'Σύντομα', 'es': 'Muy pronto',
    'pt': 'Em breve', 'ru': 'Скоро', 'tr': 'Yakında', 'ja': '近日公開',
  };
  static const _gradeShort = {
    'en': 'grade', 'bg': 'клас', 'de': 'Klasse', 'fr': 'classe',
    'it': 'classe', 'el': 'τάξη', 'es': 'grado', 'pt': 'ano',
    'ru': 'класс', 'tr': 'sınıf', 'ja': '年生',
  };
  static const _intro = {
    'en': 'Turn on a mode to get features made just for you.',
    'bg': 'Активирай режим, за да получиш функции специално за теб.',
    'de': 'Aktiviere einen Modus für Funktionen speziell für dich.',
    'fr': 'Active un mode pour des fonctions rien que pour toi.',
    'it': 'Attiva una modalità per funzioni pensate per te.',
    'el': 'Ενεργοποίησε μια λειτουργία για δυνατότητες ειδικά για σένα.',
    'es': 'Activa un modo para tener funciones hechas para ti.',
    'pt': 'Ativa um modo para funções feitas para ti.',
    'ru': 'Включи режим, чтобы получить функции специально для тебя.',
    'tr': 'Sana özel özellikler için bir mod aç.',
    'ja': 'モードをオンにすると、あなた専用の機能が使えます。',
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

  Future<void> _configurePupil(String lang) async {
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
                        await _school.setEnabled(true);
                        if (mounted) setState(() {});
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                ].map((w) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4), child: w)).toList(),
              ),
              if (_school.enabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextButton.icon(
                    icon: const Icon(Icons.power_settings_new),
                    label: Text(_t(_turnOff, lang)),
                    onPressed: () async {
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
        title: Text('🎓 ${_t(_title, lang)}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: SchoolCalendarService.revision,
        builder: (context, _, __) {
          final pupilOn = _school.enabled && _school.grade != null;
          final pupilStatus = pupilOn
              ? '${_school.grade} ${_t(_gradeShort, lang)}'
              : _t(_off, lang);
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: [
              if (!pupilOn)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  child: Text(_t(_intro, lang),
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
                ),
              _modeCard(
                emoji: '🎒',
                title: _t(_pupil, lang),
                status: pupilStatus,
                enabled: pupilOn,
                onTap: () => _configurePupil(lang),
                extra: pupilOn
                    ? const Padding(
                        padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: SchoolCountdownCard(),
                      )
                    : null,
              ),
              _modeCard(
                emoji: '🎓',
                title: _t(_student, lang),
                status: _t(_soon, lang),
                enabled: false,
                comingSoon: true,
              ),
            ],
          );
        },
      ),
    );
  }
}
