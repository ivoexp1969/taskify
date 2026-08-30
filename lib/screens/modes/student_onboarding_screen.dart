import 'package:flutter/material.dart';

import '../../models/university.dart';
import '../../services/university_service.dart';
import '../../services/school_calendar_service.dart';
import '../../services/weekly_schedule_service.dart';
import '../../utils/localization.dart';

/// Онбординг на „Режим Студент": ВУЗ → факултет → специалност → курс → форма.
///
/// ВУЗ идват от вградения регистър (`universities_bg.json`). Факултетът е
/// свободен текст (Ограничение #2 — не гадаем факултети). Специалността се
/// избира от примерните на ВУЗ-а, ако има, или се въвежда ръчно.
///
/// Отваря се и при първо включване, и при редакция на профила (нова учебна
/// година → студентът мени курса). При запис активира режима.
class StudentOnboardingScreen extends StatefulWidget {
  const StudentOnboardingScreen({super.key});

  @override
  State<StudentOnboardingScreen> createState() =>
      _StudentOnboardingScreenState();
}

class _StudentOnboardingScreenState extends State<StudentOnboardingScreen> {
  final _service = UniversityService();
  final _wsvc = WeeklyScheduleService();

  List<University> _unis = const [];
  University? _uni;
  final _uniNameCtrl = TextEditingController(); // за „Друг университет"
  final _facultyCtrl = TextEditingController();
  String _program = ''; // избрана от списъка специалност
  final _programCtrl = TextEditingController(); // за ръчна специалност
  final _groupCtrl = TextEditingController(); // студентска група (free-text)
  String _initialGroup = ''; // за детекция на смяна на групата
  bool _manualProgram = false; // true = въвежда ръчно („Друга")
  int _year = 1;
  StudyForm _form = StudyForm.regular;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final unis = await _service.loadUniversities();
    await _wsvc.load(); // нужно за проверка при смяна на групата
    final p = _service.profile;
    setState(() {
      _unis = unis;
      if (p != null) {
        _uni = _service.universityById(p.uniId);
        _uniNameCtrl.text = p.uniName ?? '';
        _facultyCtrl.text = p.faculty;
        // Специалността е „ръчна", ако ВУЗ-ът няма списък или тя не е в списъка.
        final inList = _uni?.programs.contains(p.program) ?? false;
        if (inList) {
          _program = p.program;
        } else {
          _manualProgram = p.program.isNotEmpty;
          _programCtrl.text = p.program;
        }
        _year = p.year;
        _form = p.form;
        _groupCtrl.text = p.groupNumber;
        _initialGroup = p.groupNumber;
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _uniNameCtrl.dispose();
    _facultyCtrl.dispose();
    _programCtrl.dispose();
    _groupCtrl.dispose();
    super.dispose();
  }

  static String _t(Map<String, String> m, String lang) => m[lang] ?? m['en']!;

  static const _title = {
    'en': 'Student mode', 'bg': 'Режим Студент', 'de': 'Studenten-Modus',
    'fr': 'Mode Étudiant', 'it': 'Modalità Studente', 'el': 'Λειτουργία Φοιτητή',
    'es': 'Modo Estudiante', 'pt': 'Modo Estudante', 'ru': 'Режим Студент',
    'tr': 'Öğrenci modu', 'ja': '大学生モード',
  };
  static const _uniLabel = {
    'en': 'University', 'bg': 'ВУЗ', 'de': 'Hochschule', 'fr': 'Université',
    'it': 'Università', 'el': 'Πανεπιστήμιο', 'es': 'Universidad',
    'pt': 'Universidade', 'ru': 'Вуз', 'tr': 'Üniversite', 'ja': '大学',
  };
  static const _uniNameLabel = {
    'en': 'University name', 'bg': 'Име на университета', 'de': 'Name der Hochschule',
    'fr': "Nom de l'université", 'it': 'Nome università', 'el': 'Όνομα πανεπιστημίου',
    'es': 'Nombre de la universidad', 'pt': 'Nome da universidade',
    'ru': 'Название вуза', 'tr': 'Üniversite adı', 'ja': '大学名',
  };
  static const _facultyLabel = {
    'en': 'Faculty (optional)', 'bg': 'Факултет (по избор)', 'de': 'Fakultät (optional)',
    'fr': 'Faculté (facultatif)', 'it': 'Facoltà (facoltativo)',
    'el': 'Σχολή (προαιρετικό)', 'es': 'Facultad (opcional)',
    'pt': 'Faculdade (opcional)', 'ru': 'Факультет (необязательно)',
    'tr': 'Fakülte (isteğe bağlı)', 'ja': '学部（任意）',
  };
  static const _programLabel = {
    'en': 'Program', 'bg': 'Специалност', 'de': 'Studiengang', 'fr': 'Filière',
    'it': 'Corso di laurea', 'el': 'Ειδικότητα', 'es': 'Especialidad',
    'pt': 'Curso', 'ru': 'Специальность', 'tr': 'Bölüm', 'ja': '専攻',
  };
  static const _programOther = {
    'en': 'Other — type it', 'bg': 'Друга — въведи ръчно', 'de': 'Andere — eingeben',
    'fr': 'Autre — saisir', 'it': 'Altro — inserisci', 'el': 'Άλλο — πληκτρολόγησε',
    'es': 'Otra — escríbela', 'pt': 'Outra — escreve', 'ru': 'Другая — введите',
    'tr': 'Diğer — yaz', 'ja': 'その他 — 入力',
  };
  static const _yearLabel = {
    'en': 'Year', 'bg': 'Курс', 'de': 'Studienjahr', 'fr': 'Année',
    'it': 'Anno', 'el': 'Έτος', 'es': 'Curso', 'pt': 'Ano', 'ru': 'Курс',
    'tr': 'Sınıf', 'ja': '学年',
  };
  static const _formLabel = {
    'en': 'Study form', 'bg': 'Форма на обучение', 'de': 'Studienform',
    'fr': "Forme d'études", 'it': 'Forma di studio', 'el': 'Μορφή σπουδών',
    'es': 'Modalidad', 'pt': 'Forma de estudo', 'ru': 'Форма обучения',
    'tr': 'Öğrenim şekli', 'ja': '就学形態',
  };
  static const _formRegular = {
    'en': 'Full-time', 'bg': 'Редовно', 'de': 'Vollzeit', 'fr': 'À temps plein',
    'it': 'A tempo pieno', 'el': 'Πλήρης', 'es': 'Presencial', 'pt': 'Tempo integral',
    'ru': 'Очно', 'tr': 'Örgün', 'ja': '通学',
  };
  static const _formPartTime = {
    'en': 'Part-time', 'bg': 'Задочно', 'de': 'Teilzeit', 'fr': 'À temps partiel',
    'it': 'Part-time', 'el': 'Μερική', 'es': 'Semipresencial', 'pt': 'Tempo parcial',
    'ru': 'Заочно', 'tr': 'İkinci öğretim', 'ja': '夜間',
  };
  static const _formDistance = {
    'en': 'Distance', 'bg': 'Дистанционно', 'de': 'Fernstudium', 'fr': 'À distance',
    'it': 'A distanza', 'el': 'Εξ αποστάσεως', 'es': 'A distancia', 'pt': 'À distância',
    'ru': 'Дистанционно', 'tr': 'Uzaktan', 'ja': '通信',
  };
  // Контекстно: студентска група (не спортна/друга) → ключ student_group_number.
  static const _groupLabel = {
    'en': 'Group (optional)', 'bg': 'Група (по избор)', 'de': 'Gruppe (optional)',
    'fr': 'Groupe (facultatif)', 'it': 'Gruppo (facoltativo)',
    'el': 'Ομάδα (προαιρετικό)', 'es': 'Grupo (opcional)', 'pt': 'Grupo (opcional)',
    'ru': 'Группа (необязательно)', 'tr': 'Grup (isteğe bağlı)', 'ja': 'グループ（任意）',
  };
  static const _groupHint = {
    'en': 'Your student group (see it in the academic calendar or the schedule).',
    'bg': 'Твоята студентска група (виж я в академичния календар или разписанието на ВУЗ-а).',
    'de': 'Deine Studiengruppe (im Studienkalender oder Stundenplan).',
    'fr': 'Ton groupe étudiant (dans le calendrier ou l\'emploi du temps).',
    'it': 'Il tuo gruppo studenti (nel calendario o nell\'orario).',
    'el': 'Η φοιτητική σου ομάδα (στο ακαδημαϊκό ημερολόγιο ή το πρόγραμμα).',
    'es': 'Tu grupo de estudiante (en el calendario o el horario).',
    'pt': 'O teu grupo de estudante (no calendário ou no horário).',
    'ru': 'Твоя студенческая группа (см. в календаре или расписании).',
    'tr': 'Öğrenci grubun (akademik takvim veya ders programında).',
    'ja': 'あなたの学生グループ（学年暦や時間割で確認）。',
  };
  static const _changeGroupTitle = {
    'en': 'Group changed', 'bg': 'Смяна на група', 'de': 'Gruppe geändert',
    'fr': 'Groupe modifié', 'it': 'Gruppo cambiato', 'el': 'Άλλαξε η ομάδα',
    'es': 'Grupo cambiado', 'pt': 'Grupo alterado', 'ru': 'Группа изменена',
    'tr': 'Grup değişti', 'ja': 'グループを変更',
  };
  static const _changeGroupBody = {
    'en': 'Delete the current schedule and enter a new one?',
    'bg': 'Да изтрия ли разписанието и да въведеш ново?',
    'de': 'Aktuellen Stundenplan löschen und neu eingeben?',
    'fr': 'Supprimer l\'emploi du temps actuel et en saisir un nouveau ?',
    'it': 'Eliminare l\'orario attuale e inserirne uno nuovo?',
    'el': 'Διαγραφή του τρέχοντος προγράμματος και εισαγωγή νέου;',
    'es': '¿Eliminar el horario actual e introducir uno nuevo?',
    'pt': 'Eliminar o horário atual e introduzir um novo?',
    'ru': 'Удалить текущее расписание и ввести новое?',
    'tr': 'Mevcut ders programını silip yenisini gir?',
    'ja': '現在の時間割を削除して新しく入力しますか？',
  };
  static const _keepSchedule = {
    'en': 'Keep it', 'bg': 'Запази', 'de': 'Behalten', 'fr': 'Garder',
    'it': 'Mantieni', 'el': 'Διατήρηση', 'es': 'Mantener', 'pt': 'Manter',
    'ru': 'Оставить', 'tr': 'Koru', 'ja': '保持',
  };
  static const _deleteSchedule = {
    'en': 'Delete schedule', 'bg': 'Изтрий разписанието', 'de': 'Löschen',
    'fr': 'Supprimer', 'it': 'Elimina', 'el': 'Διαγραφή', 'es': 'Eliminar',
    'pt': 'Eliminar', 'ru': 'Удалить', 'tr': 'Sil', 'ja': '削除',
  };
  static const _pickHint = {
    'en': 'Tap to choose', 'bg': 'Докосни, за да избереш', 'de': 'Zum Wählen tippen',
    'fr': 'Touche pour choisir', 'it': 'Tocca per scegliere', 'el': 'Πάτησε για επιλογή',
    'es': 'Toca para elegir', 'pt': 'Toca para escolher', 'ru': 'Нажми, чтобы выбрать',
    'tr': 'Seçmek için dokun', 'ja': 'タップして選択',
  };
  static const _search = {
    'en': 'Search…', 'bg': 'Търси…', 'de': 'Suchen…', 'fr': 'Rechercher…',
    'it': 'Cerca…', 'el': 'Αναζήτηση…', 'es': 'Buscar…', 'pt': 'Pesquisar…',
    'ru': 'Поиск…', 'tr': 'Ara…', 'ja': '検索…',
  };
  static const _saveLabel = {
    'en': 'Save & turn on', 'bg': 'Запази и включи', 'de': 'Speichern & an',
    'fr': 'Enregistrer & activer', 'it': 'Salva e attiva', 'el': 'Αποθήκευση & ενεργ.',
    'es': 'Guardar y activar', 'pt': 'Guardar e ativar', 'ru': 'Сохранить и вкл.',
    'tr': 'Kaydet ve aç', 'ja': '保存してオン',
  };
  static const _turnOff = {
    'en': 'Turn off', 'bg': 'Изключи', 'de': 'Ausschalten', 'fr': 'Désactiver',
    'it': 'Disattiva', 'el': 'Απενεργοποίηση', 'es': 'Desactivar', 'pt': 'Desativar',
    'ru': 'Выключить', 'tr': 'Kapat', 'ja': 'オフにする',
  };

  bool get _canSave => _uni != null;

  /// Търсим избор от списък низове (за ВУЗ и специалности).
  Future<T?> _pickFromList<T>({
    required String lang,
    required List<T> items,
    required String Function(T) label,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final q = query.trim().toLowerCase();
            final filtered = q.isEmpty
                ? items
                : items
                    .where((e) => label(e).toLowerCase().contains(q))
                    .toList();
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.75,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: _t(_search, lang),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => setSheet(() => query = v),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => ListTile(
                          title: Text(label(filtered[i])),
                          onTap: () => Navigator.pop(ctx, filtered[i]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickUniversity(String lang) async {
    final picked = await _pickFromList<University>(
      lang: lang,
      items: _unis,
      label: (u) => u.name,
    );
    if (picked != null) {
      setState(() {
        _uni = picked;
        // При смяна на ВУЗ нулираме избора на специалност (различни списъци).
        if (!picked.programs.contains(_program)) {
          _program = '';
        }
        // Ако новият ВУЗ няма списък → режим „ръчно" (само текстово поле).
        _manualProgram = picked.programs.isEmpty && _programCtrl.text.isNotEmpty;
      });
    }
  }

  Future<void> _pickProgram(String lang) async {
    final uni = _uni;
    if (uni == null || uni.programs.isEmpty) return;
    final other = _t(_programOther, lang);
    final options = [...uni.programs, other];
    final picked = await _pickFromList<String>(
      lang: lang,
      items: options,
      label: (s) => s,
    );
    if (picked == null) return;
    setState(() {
      if (picked == other) {
        // „Друга" → скрий списъка, покажи ръчното поле.
        _manualProgram = true;
        _program = '';
      } else {
        _manualProgram = false;
        _program = picked;
        _programCtrl.text = picked;
      }
    });
  }

  Future<void> _save(String lang) async {
    final uni = _uni!;
    final manual = uni.programs.isEmpty || _manualProgram;
    final program = manual ? _programCtrl.text.trim() : _program;
    final group = _groupCtrl.text.trim();

    // Смяна на групата (стар профил с група → нова, различна) + има разписание →
    // питаме дали да го изтрием (различната група обикновено има друга програма).
    if (_initialGroup.isNotEmpty &&
        group != _initialGroup &&
        !_wsvc.isEmpty) {
      final wipe = await _confirmGroupChange(lang);
      if (wipe == null) return; // отказ → нищо не правим
      if (wipe) await _wsvc.clearAll();
    }

    final profile = UniversityProfile(
      uniId: uni.id,
      uniName: uni.isOther ? _uniNameCtrl.text.trim() : null,
      faculty: _facultyCtrl.text.trim(),
      program: program,
      year: _year,
      form: _form,
      groupNumber: group,
      lastScheduleSync: _service.profile?.lastScheduleSync,
    );
    await _service.setProfile(profile);
    await _service.setEnabled(true);
    // Режимите са взаимно изключващи се (ученик ИЛИ студент).
    await SchoolCalendarService().setEnabled(false);
    if (mounted) Navigator.pop(context, true);
  }

  /// Пита при смяна на групата: `true` = изтрий разписанието, `false` = запази,
  /// `null` = отказ (не записваме).
  Future<bool?> _confirmGroupChange(String lang) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t(_changeGroupTitle, lang)),
        content: Text(_t(_changeGroupBody, lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t(_keepSchedule, lang)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t(_deleteSchedule, lang)),
          ),
        ],
      ),
    );
  }

  Future<void> _turnOffMode() async {
    await _service.setEnabled(false);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageScope.of(context).locale.languageCode;
    final theme = Theme.of(context);
    final uni = _uni;
    final hasPrograms = uni != null && uni.programs.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text('🎓 ${_t(_title, lang)}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                // ── ВУЗ ──
                Text(_t(_uniLabel, lang),
                    style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                OutlinedButton(
                  onPressed: () => _pickUniversity(lang),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  child: Text(
                    uni?.name ?? _t(_pickHint, lang),
                    style: TextStyle(
                        color: uni == null
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface),
                  ),
                ),
                // Ръчно име за „Друг университет".
                if (uni != null && uni.isOther) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _uniNameCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: _t(_uniNameLabel, lang),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // ── Факултет (free-text) ──
                TextField(
                  controller: _facultyCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: _t(_facultyLabel, lang),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Специалност ──
                Text(_t(_programLabel, lang), style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                // ВУЗ с примерни специалности → dropdown (вкл. „Друга — ръчно").
                if (hasPrograms)
                  OutlinedButton(
                    onPressed: () => _pickProgram(lang),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                    ),
                    child: Text(
                      _manualProgram
                          ? _t(_programOther, lang)
                          : (_program.isNotEmpty
                              ? _program
                              : _t(_pickHint, lang)),
                      style: TextStyle(
                          color: (!_manualProgram && _program.isEmpty)
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface),
                    ),
                  ),
                // Ръчно поле — само ако няма списък ИЛИ е избрано „Друга".
                if (!hasPrograms || _manualProgram) ...[
                  if (hasPrograms) const SizedBox(height: 8),
                  TextField(
                    controller: _programCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: _t(_programLabel, lang),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // ── Курс ──
                Text(_t(_yearLabel, lang), style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (int y = 1; y <= 6; y++)
                      ChoiceChip(
                        label: Text('$y'),
                        selected: _year == y,
                        onSelected: (_) => setState(() => _year = y),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Група (свободен текст, незадължителна) ──
                TextField(
                  controller: _groupCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: _t(_groupLabel, lang),
                    helperText: _t(_groupHint, lang),
                    helperMaxLines: 3,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Форма на обучение ──
                Text(_t(_formLabel, lang), style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(_t(_formRegular, lang)),
                      selected: _form == StudyForm.regular,
                      onSelected: (_) =>
                          setState(() => _form = StudyForm.regular),
                    ),
                    ChoiceChip(
                      label: Text(_t(_formPartTime, lang)),
                      selected: _form == StudyForm.partTime,
                      onSelected: (_) =>
                          setState(() => _form = StudyForm.partTime),
                    ),
                    ChoiceChip(
                      label: Text(_t(_formDistance, lang)),
                      selected: _form == StudyForm.distance,
                      onSelected: (_) =>
                          setState(() => _form = StudyForm.distance),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                FilledButton.icon(
                  onPressed: _canSave ? () => _save(lang) : null,
                  icon: const Icon(Icons.check),
                  label: Text(_t(_saveLabel, lang)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                if (_service.enabled) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _turnOffMode,
                    icon: const Icon(Icons.power_settings_new),
                    label: Text(_t(_turnOff, lang)),
                  ),
                ],
              ],
            ),
    );
  }
}
