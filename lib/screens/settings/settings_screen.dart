import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/task.dart';
import '../../models/category.dart';
import '../../utils/localization.dart';
import '../../utils/category_colors.dart';
import '../../utils/file_saver.dart';
import '../../utils/gsi_button.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../services/sync_service.dart';
import '../auth/login_screen.dart';
import 'statistics_screen.dart';
import 'ai_settings_screen.dart';
import 'how_to_use_screen.dart';
import 'delete_account_flow.dart';
import '../profile/profile_screen.dart';
import '../../services/task_view_preference.dart';
import '../home/home_screen.dart';
import '../../services/google_calendar_service.dart';
import '../../services/calendar_import_service.dart';
import '../../services/ios_calendar_service.dart';
import '../../services/morning_briefing_service.dart';
import '../../services/name_days_service.dart';
import '../../services/contact_name_index.dart';
import '../../services/holidays_service.dart';
import '../../services/school_calendar_service.dart';
import '../../services/university_service.dart';
import '../modes/student_onboarding_screen.dart';
import '../../services/pro_service.dart';
import '../paywall/paywall_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  final _viewPreference = TaskViewPreference();
  bool _isSyncing = false;
  bool _isCalendarConnected = false;
  final _calendarService = GoogleCalendarService();
  final _iosCalendarService = IosCalendarService();
  bool _isIosCalendarGranted = false;
  // Единен избор на календарен източник: 'none' | 'google' | 'apple'.
  // Двата източника са взаимно изключващи се (иначе при външна GCal↔Apple
  // връзка всяко събитие се появява двойно). Виж IosCalendarService.
  String _calMode = 'none';
  final _morningBriefingService = MorningBriefingService();
  bool _isMorningBriefingEnabled = false;
  int _briefingHour = 8;
  int _briefingMinute = 0;
  bool _nameDaysEnabled = false;
  bool _contactsNameDayEnabled = false;
  bool _holidaysEnabled = false;
  String _holidaysCountry = 'BG';
  bool _schoolModeEnabled = false;
  int? _schoolGrade;
  StreamSubscription<dynamic>? _authSub;

  @override
  void initState() {
    super.initState();
    _loadBriefingTime();
    _loadMorningBriefingSetting();
    _loadNameDaysSetting();
    _loadHolidaysSetting();
    _loadSchoolModeSetting();
    _checkCalendarConnection();
    if (!kIsWeb && Platform.isIOS) _checkIosCalendarPermission();
    // Този екран живее в IndexedStack и се build-ва още при стартиране,
    // ПРЕДИ Firebase Auth да възстанови запазената сесия (асинхронно).
    // Слушаме промените, за да се пребилдне акаунт секцията щом сесията
    // се възстанови — иначе изглежда сякаш потребителят е излязъл.
    _authSub = _authService.authStateChanges.listen((_) {
      if (mounted) setState(() {});
    });
    // Обновяваме „Стани Pro" картата (показва се само при !isPro) веднага щом
    // покупка/restore/RevenueCat промени статуса.
    ProService().addListener(_onProChanged);
    // Web: входът в Google Calendar идва асинхронно от GIS бутона → обновяваме
    // UI-я щом връзката се промени.
    _calendarService.connectionNotifier.addListener(_onCalendarConnChanged);
    // Web: показва бутона „Разреши достъп" щом влезем, но още без календарен достъп.
    _calendarService.webAuthPending.addListener(_onCalendarConnChanged);
    // Web: гарантираме, че GIS клиентът е инициализиран, за да се рендира
    // официалният бутон (иначе стои на „Getting ready").
    if (kIsWeb) {
      _calendarService.ensureInitialized().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _onProChanged() {
    if (mounted) setState(() {});
  }

  void _onCalendarConnChanged() {
    if (mounted) {
      setState(() {
        _isCalendarConnected = _calendarService.isConnected;
        // Web GIS вход → отразяваме режима като Google.
        if (_isCalendarConnected) _calMode = 'google';
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    ProService().removeListener(_onProChanged);
    _calendarService.connectionNotifier.removeListener(_onCalendarConnChanged);
    _calendarService.webAuthPending.removeListener(_onCalendarConnChanged);
    super.dispose();
  }

  Future<void> _loadHolidaysSetting() async {
    final enabled = await HolidaysService().loadEnabled();
    if (!mounted) return;
    setState(() {
      _holidaysEnabled = enabled;
      _holidaysCountry = HolidaysService().country;
    });
  }

  Future<void> _loadNameDaysSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsOn = await ContactNameIndex().loadEnabled();
    if (!mounted) return;
    setState(() {
      _nameDaysEnabled = prefs.getBool('name_days_enabled') ?? false;
      _contactsNameDayEnabled = contactsOn;
    });
  }

  Future<void> _loadSchoolModeSetting() async {
    final enabled = await SchoolCalendarService().loadEnabled();
    if (!mounted) return;
    setState(() {
      _schoolModeEnabled = enabled;
      _schoolGrade = SchoolCalendarService().grade;
    });
  }

  /// Локализирано „N. клас" за избора на клас (1–12).
  String _gradeLabel(String lang, int g) {
    const suffix = {
      'en': 'Grade', 'bg': 'клас', 'de': 'Klasse', 'fr': 'classe',
      'it': 'classe', 'el': 'τάξη', 'es': 'grado', 'pt': 'ano',
      'ru': 'класс', 'tr': 'sınıf', 'ja': '年生',
    };
    final s = suffix[lang] ?? suffix['en']!;
    // Английски/немски: „Grade 7"; останалите: „7. клас" / „7 sınıf".
    if (lang == 'en' || lang == 'de') return '$s $g';
    if (lang == 'ja') return '$g$s';
    if (lang == 'tr') return '$g. $s';
    return '$g. $s';
  }

  /// Диалог за избор на клас (1–12). Връща избрания клас или null.
  Future<int?> _pickGrade(BuildContext context, String lang) async {
    String tr(Map<String, String> m) => m[lang] ?? m['en']!;
    const question = {
      'en': 'Which grade are you in?', 'bg': 'В кой клас си?',
      'de': 'In welcher Klasse bist du?', 'fr': 'Tu es en quelle classe ?',
      'it': 'In che classe sei?', 'el': 'Σε ποια τάξη είσαι;',
      'es': '¿En qué grado estás?', 'pt': 'Em que ano estás?',
      'ru': 'В каком ты классе?', 'tr': 'Hangi sınıftasın?', 'ja': '何年生ですか？',
    };
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(question)),
        content: SizedBox(
          width: double.maxFinite,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(12, (i) {
              final g = i + 1;
              final selected = _schoolGrade == g;
              return ChoiceChip(
                label: Text('$g'),
                selected: selected,
                onSelected: (_) => Navigator.pop(ctx, g),
              );
            }),
          ),
        ),
      ),
    );
  }

  /// Учебни предмети, предлагани при включване на режима (id → цвят + имена +
  /// диапазон класове `min..max`, в който предметът обикновено се учи в БГ).
  /// Преизползват съществуващата система за категории (НЕ строим паралелна).
  ///
  /// Диапазоните са ОРИЕНТИРОВЪЧНИ (учебният план се мени): начални класове нямат
  /// Физика/Химия/Биология (те са от 7. клас); История/География са от 5. клас;
  /// природознанието е слято до 6. клас. Потребителят решава — оттук и опцията за
  /// собствен предмет. При съмнение → по-широк диапазон, за да не крием предмет.
  static const List<
      ({String id, int color, int min, int max, Map<String, String> name})>
      _allSubjects = [
    (id: 'subj_math', color: 0xFF3498DB, min: 1, max: 12, name: {
      'en': 'Math', 'bg': 'Математика', 'de': 'Mathe', 'fr': 'Maths',
      'it': 'Matematica', 'el': 'Μαθηματικά', 'es': 'Matemáticas',
      'pt': 'Matemática', 'ru': 'Математика', 'tr': 'Matematik', 'ja': '数学',
    }),
    (id: 'subj_bel', color: 0xFFE74C3C, min: 1, max: 12, name: {
      'en': 'Language & Lit.', 'bg': 'БЕЛ', 'de': 'Sprache & Lit.',
      'fr': 'Langue & Litt.', 'it': 'Lingua e Lett.', 'el': 'Γλώσσα & Λογ.',
      'es': 'Lengua y Lit.', 'pt': 'Língua e Lit.', 'ru': 'Язык и лит.',
      'tr': 'Dil ve Ed.', 'ja': '国語',
    }),
    (id: 'subj_en', color: 0xFF9B59B6, min: 1, max: 12, name: {
      'en': 'English', 'bg': 'Английски', 'de': 'Englisch', 'fr': 'Anglais',
      'it': 'Inglese', 'el': 'Αγγλικά', 'es': 'Inglés', 'pt': 'Inglês',
      'ru': 'Английский', 'tr': 'İngilizce', 'ja': '英語',
    }),
    // Начален етап: слято природознание/родинознание (1–6 клас).
    (id: 'subj_nature', color: 0xFF1ABC9C, min: 1, max: 6, name: {
      'en': 'Nature study', 'bg': 'Човекът и природата',
      'de': 'Sachkunde', 'fr': 'Découverte du monde',
      'it': 'Scienze (base)', 'el': 'Μελέτη περιβάλλοντος',
      'es': 'Conocimiento del medio', 'pt': 'Estudo do meio',
      'ru': 'Окружающий мир', 'tr': 'Hayat bilgisi', 'ja': '生活科',
    }),
    (id: 'subj_history', color: 0xFFD35400, min: 5, max: 12, name: {
      'en': 'History', 'bg': 'История', 'de': 'Geschichte', 'fr': 'Histoire',
      'it': 'Storia', 'el': 'Ιστορία', 'es': 'Historia', 'pt': 'História',
      'ru': 'История', 'tr': 'Tarih', 'ja': '歴史',
    }),
    (id: 'subj_geo', color: 0xFF16A085, min: 5, max: 12, name: {
      'en': 'Geography', 'bg': 'География', 'de': 'Geografie',
      'fr': 'Géographie', 'it': 'Geografia', 'el': 'Γεωγραφία',
      'es': 'Geografía', 'pt': 'Geografia', 'ru': 'География',
      'tr': 'Coğrafya', 'ja': '地理',
    }),
    (id: 'subj_bio', color: 0xFF27AE60, min: 7, max: 12, name: {
      'en': 'Biology', 'bg': 'Биология', 'de': 'Biologie', 'fr': 'Biologie',
      'it': 'Biologia', 'el': 'Βιολογία', 'es': 'Biología', 'pt': 'Biologia',
      'ru': 'Биология', 'tr': 'Biyoloji', 'ja': '生物',
    }),
    (id: 'subj_chem', color: 0xFF2980B9, min: 7, max: 12, name: {
      'en': 'Chemistry', 'bg': 'Химия', 'de': 'Chemie', 'fr': 'Chimie',
      'it': 'Chimica', 'el': 'Χημεία', 'es': 'Química', 'pt': 'Química',
      'ru': 'Химия', 'tr': 'Kimya', 'ja': '化学',
    }),
    (id: 'subj_phys', color: 0xFF8E44AD, min: 7, max: 12, name: {
      'en': 'Physics', 'bg': 'Физика', 'de': 'Physik', 'fr': 'Physique',
      'it': 'Fisica', 'el': 'Φυσική', 'es': 'Física', 'pt': 'Física',
      'ru': 'Физика', 'tr': 'Fizik', 'ja': '物理',
    }),
    (id: 'subj_it', color: 0xFF34495E, min: 3, max: 12, name: {
      'en': 'IT', 'bg': 'Информатика', 'de': 'Informatik',
      'fr': 'Informatique', 'it': 'Informatica', 'el': 'Πληροφορική',
      'es': 'Informática', 'pt': 'Informática', 'ru': 'Информатика',
      'tr': 'Bilişim', 'ja': '情報',
    }),
    (id: 'subj_music', color: 0xFFEC407A, min: 1, max: 12, name: {
      'en': 'Music', 'bg': 'Музика', 'de': 'Musik', 'fr': 'Musique',
      'it': 'Musica', 'el': 'Μουσική', 'es': 'Música', 'pt': 'Música',
      'ru': 'Музыка', 'tr': 'Müzik', 'ja': '音楽',
    }),
    (id: 'subj_art', color: 0xFFAB47BC, min: 1, max: 12, name: {
      'en': 'Art', 'bg': 'Изобразително изкуство', 'de': 'Kunst',
      'fr': 'Arts plastiques', 'it': 'Arte', 'el': 'Εικαστικά',
      'es': 'Plástica', 'pt': 'Artes', 'ru': 'ИЗО', 'tr': 'Resim',
      'ja': '美術',
    }),
    (id: 'subj_pe', color: 0xFFE67E22, min: 1, max: 12, name: {
      'en': 'PE', 'bg': 'Физическо', 'de': 'Sport', 'fr': 'EPS',
      'it': 'Ed. Fisica', 'el': 'Φυσική Αγωγή', 'es': 'Ed. Física',
      'pt': 'Ed. Física', 'ru': 'Физкультура', 'tr': 'Beden', 'ja': '体育',
    }),
    (id: 'subj_tech', color: 0xFF795548, min: 1, max: 12, name: {
      'en': 'Technology', 'bg': 'Технологии', 'de': 'Technik',
      'fr': 'Technologie', 'it': 'Tecnologia', 'el': 'Τεχνολογία',
      'es': 'Tecnología', 'pt': 'Tecnologia', 'ru': 'Технологии',
      'tr': 'Teknoloji', 'ja': '技術',
    }),
  ];

  /// Предметите, подходящи за клас [grade] (по ориентировъчния диапазон).
  static List<({String id, int color, int min, int max, Map<String, String> name})>
      _subjectsForGrade(int? grade) {
    if (grade == null) return _allSubjects;
    return _allSubjects
        .where((s) => grade >= s.min && grade <= s.max)
        .toList();
  }

  /// Диалог за избор на предмети (съобразени с класа) + собствен предмет →
  /// добавя избраните като категории.
  Future<void> _pickSubjects(BuildContext context, String lang) async {
    String tr(Map<String, String> m) => m[lang] ?? m['en']!;
    const title = {
      'en': 'Add school subjects', 'bg': 'Добави училищни предмети',
      'de': 'Schulfächer hinzufügen', 'fr': 'Ajouter des matières',
      'it': 'Aggiungi materie', 'el': 'Πρόσθεσε μαθήματα',
      'es': 'Añadir asignaturas', 'pt': 'Adicionar disciplinas',
      'ru': 'Добавить предметы', 'tr': 'Ders ekle', 'ja': '教科を追加',
    };
    const hint = {
      'en': 'Selected subjects become task categories.',
      'bg': 'Избраните предмети стават категории за задачи.',
      'de': 'Ausgewählte Fächer werden zu Aufgaben-Kategorien.',
      'fr': 'Les matières choisies deviennent des catégories.',
      'it': 'Le materie scelte diventano categorie.',
      'el': 'Τα επιλεγμένα μαθήματα γίνονται κατηγορίες.',
      'es': 'Las asignaturas elegidas se vuelven categorías.',
      'pt': 'As disciplinas escolhidas viram categorias.',
      'ru': 'Выбранные предметы станут категориями.',
      'tr': 'Seçilen dersler kategoriye dönüşür.', 'ja': '選んだ教科はカテゴリになります。',
    };
    const addBtn = {
      'en': 'Add', 'bg': 'Добави', 'de': 'Hinzufügen', 'fr': 'Ajouter',
      'it': 'Aggiungi', 'el': 'Πρόσθεσε', 'es': 'Añadir', 'pt': 'Adicionar',
      'ru': 'Добавить', 'tr': 'Ekle', 'ja': '追加',
    };
    const cancelBtn = {
      'en': 'Cancel', 'bg': 'Отказ', 'de': 'Abbrechen', 'fr': 'Annuler',
      'it': 'Annulla', 'el': 'Άκυρο', 'es': 'Cancelar', 'pt': 'Cancelar',
      'ru': 'Отмена', 'tr': 'İptal', 'ja': 'キャンセル',
    };
    const limitMsg = {
      'en': 'Category limit reached — upgrade to Pro for more.',
      'bg': 'Достигнат лимит на категориите — Pro дава повече.',
      'de': 'Kategorielimit erreicht — Pro für mehr.',
      'fr': 'Limite de catégories atteinte — passe à Pro.',
      'it': 'Limite categorie raggiunto — passa a Pro.',
      'el': 'Όριο κατηγοριών — αναβάθμιση σε Pro.',
      'es': 'Límite de categorías — pásate a Pro.',
      'pt': 'Limite de categorias — passa a Pro.',
      'ru': 'Лимит категорий — оформи Pro.',
      'tr': 'Kategori limiti — Pro\'ya geç.', 'ja': 'カテゴリ上限です — Proで解除。',
    };

    const addOwn = {
      'en': '+ Add your own', 'bg': '+ Добави свой', 'de': '+ Eigenes',
      'fr': '+ Le tien', 'it': '+ Il tuo', 'el': '+ Δικό σου',
      'es': '+ El tuyo', 'pt': '+ O teu', 'ru': '+ Свой',
      'tr': '+ Kendi dersin', 'ja': '+ 自分の教科',
    };
    const ownPrompt = {
      'en': 'New subject', 'bg': 'Нов предмет', 'de': 'Neues Fach',
      'fr': 'Nouvelle matière', 'it': 'Nuova materia', 'el': 'Νέο μάθημα',
      'es': 'Nueva asignatura', 'pt': 'Nova disciplina', 'ru': 'Новый предмет',
      'tr': 'Yeni ders', 'ja': '新しい教科',
    };

    final box = Hive.box<Category>('categories');
    final selected = <String>{};
    final customNames = <String>[]; // собствени предмети (свободен текст)

    // Палитра за собствените предмети (циклично).
    const customColors = [
      0xFF00897B, 0xFF5E35B1, 0xFFC0392B, 0xFF00838F, 0xFF6D4C41
    ];

    Future<String?> promptCustom() {
      final ctrl = TextEditingController();
      return showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(tr(ownPrompt)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: tr(ownPrompt)),
            onSubmitted: (v) => Navigator.pop(c, v.trim()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(tr(cancelBtn))),
            FilledButton(
                onPressed: () => Navigator.pop(c, ctrl.text.trim()),
                child: Text(tr(addBtn))),
          ],
        ),
      );
    }

    final gradeSubjects = _subjectsForGrade(_schoolGrade);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(tr(title)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(hint),
                      style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ...gradeSubjects.map((s) {
                        final exists = box.containsKey(s.id);
                        final isSel = selected.contains(s.id) || exists;
                        return FilterChip(
                          label: Text(tr(s.name)),
                          selected: isSel,
                          onSelected: exists
                              ? null
                              : (v) => setLocal(() {
                                    if (v) {
                                      selected.add(s.id);
                                    } else {
                                      selected.remove(s.id);
                                    }
                                  }),
                          avatar: CircleAvatar(
                              backgroundColor: Color(s.color), radius: 6),
                        );
                      }),
                      // Вече добавени собствени предмети (селектирани по подр.).
                      ...customNames.map((n) => FilterChip(
                            label: Text(n),
                            selected: true,
                            onSelected: (_) =>
                                setLocal(() => customNames.remove(n)),
                          )),
                      // Бутон „+ Добави свой".
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: Text(tr(addOwn)),
                        onPressed: () async {
                          final name = await promptCustom();
                          if (name != null && name.isNotEmpty) {
                            setLocal(() => customNames.add(name));
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr(cancelBtn))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr(addBtn))),
          ],
        ),
      ),
    );

    if (confirmed != true || (selected.isEmpty && customNames.isEmpty)) return;

    bool hitLimit = false;
    // Предефинирани предмети.
    for (final s in _allSubjects) {
      if (!selected.contains(s.id)) continue;
      if (box.containsKey(s.id)) continue;
      if (!ProService().canAddCategory(box.length)) {
        hitLimit = true;
        break;
      }
      await box.put(
        s.id,
        Category(id: s.id, name: tr(s.name), colorValue: s.color),
      );
    }
    // Собствени предмети.
    for (var i = 0; i < customNames.length && !hitLimit; i++) {
      if (!ProService().canAddCategory(box.length)) {
        hitLimit = true;
        break;
      }
      final id = 'subj_custom_${DateTime.now().microsecondsSinceEpoch}_$i';
      await box.put(
        id,
        Category(
          id: id,
          name: customNames[i],
          colorValue: customColors[i % customColors.length],
        ),
      );
    }
    if (mounted && hitLimit) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(limitMsg))));
    }
  }

  /// Секцията „Училищен режим" (в рамките на BG контекста). Връща widget-и,
  /// които се вливат в списъка на [_buildBulgariaSection].
  ///
  /// Режимът е БЕЗПЛАТЕН (виралната кука „N дни до ваканция"); монетизацията е
  /// на друго място (лимити/реклами/AI). За Pro-gate: увий toggle-а в
  /// showPaywallIfNeeded, като при именните дни.
  List<Widget> _buildSchoolModeCards(BuildContext context) {
    final theme = Theme.of(context);
    final lang = LanguageScope.of(context).locale.languageCode;
    String tr(Map<String, String> m) => m[lang] ?? m['en']!;

    const schoolTitle = {
      'en': 'School mode', 'bg': 'Училищен режим', 'de': 'Schulmodus',
      'fr': 'Mode école', 'it': 'Modalità scuola', 'el': 'Λειτουργία σχολείου',
      'es': 'Modo escolar', 'pt': 'Modo escolar', 'ru': 'Школьный режим',
      'tr': 'Okul modu', 'ja': '学校モード',
    };
    const schoolSubtitle = {
      'en': 'Countdown to the next school vacation, subjects & exams',
      'bg': 'Обратно броене до ваканция, предмети и изпити',
      'de': 'Countdown bis zu den Ferien, Fächer & Prüfungen',
      'fr': 'Compte à rebours des vacances, matières et examens',
      'it': 'Conto alla rovescia per le vacanze, materie ed esami',
      'el': 'Αντίστροφη μέτρηση για διακοπές, μαθήματα & εξετάσεις',
      'es': 'Cuenta atrás para las vacaciones, asignaturas y exámenes',
      'pt': 'Contagem para as férias, disciplinas e exames',
      'ru': 'Обратный отсчёт до каникул, предметы и экзамены',
      'tr': 'Tatile geri sayım, dersler ve sınavlar',
      'ja': '休みまでのカウントダウン、教科・試験',
    };
    const subjectsBtn = {
      'en': 'Add school subjects', 'bg': 'Добави училищни предмети',
      'de': 'Schulfächer hinzufügen', 'fr': 'Ajouter des matières',
      'it': 'Aggiungi materie', 'el': 'Πρόσθεσε μαθήματα',
      'es': 'Añadir asignaturas', 'pt': 'Adicionar disciplinas',
      'ru': 'Добавить предметы', 'tr': 'Ders ekle', 'ja': '教科を追加',
    };
    const pupilRole = {
      'en': 'Pupil', 'bg': 'Ученик', 'de': 'Schüler', 'fr': 'Élève',
      'it': 'Alunno', 'el': 'Μαθητής', 'es': 'Alumno', 'pt': 'Aluno',
      'ru': 'Ученик', 'tr': 'Öğrenci', 'ja': '生徒',
    };
    const studentRole = {
      'en': 'Student', 'bg': 'Студент', 'de': 'Student', 'fr': 'Étudiant',
      'it': 'Studente', 'el': 'Φοιτητής', 'es': 'Estudiante', 'pt': 'Estudante',
      'ru': 'Студент', 'tr': 'Üniversite', 'ja': '大学生',
    };
    const chooseRole = {
      'en': 'Choose your role', 'bg': 'Избери роля', 'de': 'Wähle deine Rolle',
      'fr': 'Choisis ton rôle', 'it': 'Scegli il ruolo', 'el': 'Διάλεξε ρόλο',
      'es': 'Elige tu rol', 'pt': 'Escolhe o teu papel', 'ru': 'Выбери роль',
      'tr': 'Rolünü seç', 'ja': '役割を選択',
    };
    const switchToStudent = {
      'en': 'Switch to Student', 'bg': 'Смени на Студент', 'de': 'Zu Student wechseln',
      'fr': 'Passer à Étudiant', 'it': 'Passa a Studente', 'el': 'Άλλαξε σε Φοιτητή',
      'es': 'Cambiar a Estudiante', 'pt': 'Mudar para Estudante',
      'ru': 'Переключить на Студента', 'tr': 'Üniversiteye geç', 'ja': '大学生に切替',
    };
    const switchToPupil = {
      'en': 'Switch to Pupil', 'bg': 'Смени на Ученик', 'de': 'Zu Schüler wechseln',
      'fr': 'Passer à Élève', 'it': 'Passa a Alunno', 'el': 'Άλλαξε σε Μαθητή',
      'es': 'Cambiar a Alumno', 'pt': 'Mudar para Aluno',
      'ru': 'Переключить на Ученика', 'tr': 'Öğrenciye geç', 'ja': '生徒に切替',
    };
    const turnOffLabel = {
      'en': 'Turn off', 'bg': 'Изключи', 'de': 'Ausschalten', 'fr': 'Désactiver',
      'it': 'Disattiva', 'el': 'Απενεργοποίηση', 'es': 'Desactivar',
      'pt': 'Desativar', 'ru': 'Выключить', 'tr': 'Kapat', 'ja': 'オフにする',
    };

    final studentOn = UniversityService().enabled;
    final studentName = UniversityService().displayUniversityName;

    // Включване на Ученик (пита клас; изключва Студент).
    Future<void> enablePupil() async {
      final g = await _pickGrade(context, lang);
      if (g == null) return;
      await SchoolCalendarService().setGrade(g);
      await SchoolCalendarService().setEnabled(true);
      await SchoolCalendarService().load();
      await UniversityService().setEnabled(false);
      if (!mounted) return;
      setState(() {
        _schoolModeEnabled = true;
        _schoolGrade = g;
      });
    }

    // Включване/редакция на Студент (онбордингът изключва Ученик при запис).
    Future<void> enableStudent() async {
      await UniversityService().loadUniversities();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const StudentOnboardingScreen()));
      if (!mounted) return;
      setState(() => _schoolModeEnabled = SchoolCalendarService().enabled);
    }

    return [
      const SizedBox(height: 8),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B2FF7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.school_rounded, color: Color(0xFF7B2FF7)),
              ),
              title: Text(tr(schoolTitle)),
              subtitle: Text(
                tr(schoolSubtitle),
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),

            // ── Изключено: избор на роля ──
            if (!_schoolModeEnabled && !studentOn) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(tr(chooseRole),
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6))),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Text('🎒'),
                        label: Text(tr(pupilRole)),
                        onPressed: enablePupil,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Text('🎓'),
                        label: Text(tr(studentRole)),
                        onPressed: enableStudent,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Ученик активен ──
            if (_schoolModeEnabled) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Text('🎒', style: TextStyle(fontSize: 22)),
                title: Text(tr(pupilRole)),
                trailing: Text(
                  _schoolGrade != null ? _gradeLabel(lang, _schoolGrade!) : '',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary),
                ),
                onTap: () async {
                  final g = await _pickGrade(context, lang);
                  if (g == null) return;
                  await SchoolCalendarService().setGrade(g);
                  if (!mounted) return;
                  setState(() => _schoolGrade = g);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.category_rounded),
                title: Text(tr(subjectsBtn)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickSubjects(context, lang),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded),
                title: Text(tr(_schoolHowToTitle)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showSchoolHowTo(context, lang),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded),
                title: Text(tr(switchToStudent)),
                onTap: enableStudent,
              ),
              ListTile(
                leading: Icon(Icons.power_settings_new,
                    color: theme.colorScheme.error),
                title: Text(tr(turnOffLabel)),
                onTap: () async {
                  await SchoolCalendarService().setEnabled(false);
                  if (!mounted) return;
                  setState(() => _schoolModeEnabled = false);
                },
              ),
            ],

            // ── Студент активен ──
            if (studentOn) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Text('🎓', style: TextStyle(fontSize: 22)),
                title: Text(tr(studentRole)),
                subtitle: studentName != null
                    ? Text(studentName,
                        maxLines: 1, overflow: TextOverflow.ellipsis)
                    : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: enableStudent, // редакция на профила
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded),
                title: Text(tr(switchToPupil)),
                onTap: enablePupil,
              ),
              ListTile(
                leading: Icon(Icons.power_settings_new,
                    color: theme.colorScheme.error),
                title: Text(tr(turnOffLabel)),
                onTap: () async {
                  await UniversityService().setEnabled(false);
                  if (!mounted) return;
                  setState(() {});
                },
              ),
            ],
          ],
        ),
      ),
    ];
  }

  static const Map<String, String> _schoolHowToTitle = {
    'en': 'How the mode works', 'bg': 'Как работи режимът',
    'de': 'So funktioniert der Modus', 'fr': 'Comment marche le mode',
    'it': 'Come funziona la modalità', 'el': 'Πώς λειτουργεί η λειτουργία',
    'es': 'Cómo funciona el modo', 'pt': 'Como funciona o modo',
    'ru': 'Как работает режим', 'tr': 'Mod nasıl çalışır', 'ja': 'モードの使い方',
  };

  /// Диалог „Как се ползва Училищния режим" (стъпки). Ползва се и от Настройки,
  /// и от еднократния интро диалог на началния екран.
  static Future<void> showSchoolHowTo(BuildContext context, String lang) {
    String tr(Map<String, String> m) => m[lang] ?? m['en']!;
    const steps = {
      'en': '1. Pick your role in Settings → School mode: Pupil (grade) or '
          'Student (university).\n'
          '2. The home screen shows a countdown — to the next vacation (pupil) '
          'or to a key date you added (student).\n'
          '3. Add your subjects — they become task categories.\n'
          '4. Tap "+" → Homework/Essay/Coursework: for essays & coursework the '
          'subtasks are created automatically up to the deadline.\n'
          '5. "My schedule" — enter your lessons; they also show on the calendar.\n'
          '6. For grades 4, 7, 10 and 12 a NEO/matriculation helper appears.',
      'bg': '1. Избери роля от Настройки → Училищен режим: Ученик (клас) или '
          'Студент (ВУЗ).\n'
          '2. На началния екран виждаш обратно броене — до ваканция (ученик) '
          'или до въведена от теб ключова дата (студент).\n'
          '3. Добави предметите си — стават категории за задачи.\n'
          '4. „+" → Домашно/Есе/Курсова: за есе и курсова подзадачите се '
          'създават автоматично до крайния срок.\n'
          '5. „Моето разписание" — въведи часовете си; виждат се и на календара.\n'
          '6. За 4., 7., 10. и 12. клас се показва помощник за НВО/ДЗИ.',
      'de': '1. Wähle deine Rolle in Einstellungen → Schulmodus: Schüler '
          '(Klasse) oder Student (Hochschule).\n'
          '2. Der Startbildschirm zeigt einen Countdown — bis zu den Ferien '
          '(Schüler) oder bis zu einem Termin (Student).\n'
          '3. Füge deine Fächer hinzu — sie werden zu Kategorien.\n'
          '4. "+" → Hausaufgabe/Aufsatz/Hausarbeit: Teilaufgaben entstehen '
          'automatisch bis zur Frist.\n'
          '5. "Mein Stundenplan" — trage Stunden ein; auch im Kalender.\n'
          '6. Für Klasse 4, 7, 10 und 12 erscheint ein Prüfungs-Helfer.',
      'fr': '1. Choisis ton rôle dans Réglages → Mode école : Élève (classe) '
          'ou Étudiant (université).\n'
          '2. L\'accueil affiche un compte à rebours — vacances (élève) ou une '
          'date clé ajoutée (étudiant).\n'
          '3. Ajoute tes matières — elles deviennent des catégories.\n'
          '4. "+" → Devoir/Dissertation/Travail : les sous-tâches sont créées '
          'automatiquement jusqu\'à l\'échéance.\n'
          '5. "Mon emploi du temps" — saisis tes cours ; aussi au calendrier.\n'
          '6. En 4e, 7e, 10e et terminale, un assistant examens apparaît.',
      'it': '1. Scegli il ruolo in Impostazioni → Modalità scuola: Alunno '
          '(classe) o Studente (università).\n'
          '2. La home mostra un conto alla rovescia — vacanze (alunno) o una '
          'data chiave aggiunta (studente).\n'
          '3. Aggiungi le materie — diventano categorie.\n'
          '4. "+" → Compiti/Saggio/Tesina: le sottoattività si creano '
          'automaticamente fino alla scadenza.\n'
          '5. "Il mio orario" — inserisci le lezioni; anche nel calendario.\n'
          '6. Per 4ª, 7ª, 10ª e 12ª appare un assistente esami.',
      'el': '1. Διάλεξε ρόλο στις Ρυθμίσεις → Λειτουργία σχολείου: Μαθητής '
          '(τάξη) ή Φοιτητής (πανεπιστήμιο).\n'
          '2. Η αρχική δείχνει μέτρηση — ως τις διακοπές (μαθητής) ή ως μια '
          'ημερομηνία (φοιτητής).\n'
          '3. Πρόσθεσε μαθήματα — γίνονται κατηγορίες.\n'
          '4. "+" → Εργασία/Δοκίμιο/Εργασία εξαμήνου: οι υποεργασίες '
          'δημιουργούνται αυτόματα ως την προθεσμία.\n'
          '5. "Το πρόγραμμά μου" — βάλε τα μαθήματα· φαίνονται και στο ημερολόγιο.\n'
          '6. Για 4η, 7η, 10η & 12η εμφανίζεται βοηθός εξετάσεων.',
      'es': '1. Elige tu rol en Ajustes → Modo escolar: Alumno (grado) o '
          'Estudiante (universidad).\n'
          '2. El inicio muestra una cuenta atrás — a las vacaciones (alumno) o '
          'a una fecha clave (estudiante).\n'
          '3. Añade tus asignaturas — se vuelven categorías.\n'
          '4. "+" → Deberes/Ensayo/Trabajo: las subtareas se crean '
          'automáticamente hasta la fecha límite.\n'
          '5. "Mi horario" — añade tus clases; también en el calendario.\n'
          '6. En 4.º, 7.º, 10.º y 12.º aparece un asistente de exámenes.',
      'pt': '1. Escolhe o teu papel em Definições → Modo escolar: Aluno (ano) '
          'ou Estudante (universidade).\n'
          '2. O início mostra uma contagem — para as férias (aluno) ou para uma '
          'data-chave (estudante).\n'
          '3. Adiciona as disciplinas — viram categorias.\n'
          '4. "+" → Trabalho de casa/Ensaio/Trabalho: as subtarefas são criadas '
          'automaticamente até ao prazo.\n'
          '5. "O meu horário" — adiciona as aulas; também no calendário.\n'
          '6. No 4.º, 7.º, 10.º e 12.º aparece um assistente de exames.',
      'ru': '1. Выбери роль в Настройках → Школьный режим: Ученик (класс) или '
          'Студент (вуз).\n'
          '2. На главном экране — обратный отсчёт: до каникул (ученик) или до '
          'добавленной даты (студент).\n'
          '3. Добавь предметы — они станут категориями.\n'
          '4. "+" → Домашнее/Эссе/Курсовая: подзадачи создаются автоматически '
          'до срока.\n'
          '5. "Моё расписание" — внеси занятия; видны и в календаре.\n'
          '6. Для 4, 7, 10 и 12 класса появляется помощник по экзаменам.',
      'tr': '1. Ayarlar → Okul modunda rolünü seç: Öğrenci (sınıf) veya '
          'Üniversite (üniversite).\n'
          '2. Ana ekranda geri sayım — tatile (öğrenci) veya eklediğin bir '
          'tarihe (üniversite).\n'
          '3. Derslerini ekle — kategoriye dönüşür.\n'
          '4. "+" → Ödev/Deneme/Dönem ödevi: alt görevler son tarihe kadar '
          'otomatik oluşturulur.\n'
          '5. "Ders programım" — derslerini gir; takvimde de görünür.\n'
          '6. 4, 7, 10 ve 12. sınıf için sınav yardımcısı görünür.',
      'ja': '1. 設定 → 学校モードで役割を選択：生徒（学年）か大学生（大学）。\n'
          '2. ホームにカウントダウン — 休み（生徒）や追加した日付（大学生）まで。\n'
          '3. 教科を追加 — カテゴリになります。\n'
          '4. 「+」→ 宿題/エッセイ/コースワーク：エッセイとコースワークは締切まで'
          'サブタスクが自動作成。\n'
          '5. 「時間割」— 授業を入力；カレンダーにも表示。\n'
          '6. 4・7・10・12年生には試験ヘルパーが表示。',
    };
    const closeBtn = {
      'en': 'Got it', 'bg': 'Разбрах', 'de': 'Verstanden', 'fr': 'Compris',
      'it': 'Capito', 'el': 'Κατάλαβα', 'es': 'Entendido', 'pt': 'Percebi',
      'ru': 'Понятно', 'tr': 'Anladım', 'ja': 'わかった',
    };
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.menu_book_rounded, size: 36, color: Color(0xFF7B2FF7)),
        title: Text(tr(_schoolHowToTitle)),
        content: SingleChildScrollView(
          child: Text(tr(steps), style: const TextStyle(height: 1.5)),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr(closeBtn)),
          ),
        ],
      ),
    );
  }

  /// „Стани Pro" картата — ПОСТОЯНЕН, забележим вход към paywall. Показва се
  /// само на mobile и само когато потребителят НЕ е Pro. Pro потребител не я вижда.
  Widget _buildGoProCard(BuildContext context) {
    final lang = LanguageScope.of(context).locale.languageCode;
    String tr(Map<String, String> m) => m[lang] ?? m['en']!;

    const title = {
      'en': 'Get Taskify Pro', 'bg': 'Стани Pro', 'de': 'Taskify Pro holen',
      'fr': 'Passer à Pro', 'it': 'Passa a Pro', 'el': 'Απόκτησε το Pro',
      'es': 'Hazte Pro', 'pt': 'Seja Pro', 'ru': 'Стать Pro',
      'tr': 'Pro\'ya geç', 'ja': 'Taskify Pro にアップグレード',
    };
    const subtitle = {
      'en': 'Calendar, AI, cloud sync, no ads and more',
      'bg': 'Календар, AI, облак, без реклами и още',
      'de': 'Kalender, KI, Cloud-Sync, keine Werbung und mehr',
      'fr': 'Calendrier, IA, sync cloud, sans pubs et plus',
      'it': 'Calendario, IA, sync cloud, niente pubblicità e altro',
      'el': 'Ημερολόγιο, AI, συγχρονισμός cloud, χωρίς διαφημίσεις και άλλα',
      'es': 'Calendario, IA, sync en la nube, sin anuncios y más',
      'pt': 'Calendário, IA, sync na nuvem, sem anúncios e mais',
      'ru': 'Календарь, ИИ, облако, без рекламы и другое',
      'tr': 'Takvim, AI, bulut senkronizasyonu, reklamsız ve daha fazlası',
      'ja': 'カレンダー、AI、クラウド同期、広告なしなど',
    };
    const getButton = {
      'en': 'Get Pro', 'bg': 'Вземи Pro', 'de': 'Pro holen',
      'fr': 'Obtenir Pro', 'it': 'Ottieni Pro', 'el': 'Απόκτηση Pro',
      'es': 'Obtener Pro', 'pt': 'Obter Pro', 'ru': 'Получить Pro',
      'tr': 'Pro al', 'ja': 'Pro を入手',
    };
    const restoreButton = {
      'en': 'Restore purchases', 'bg': 'Възстанови покупки',
      'de': 'Käufe wiederherstellen', 'fr': 'Restaurer les achats',
      'it': 'Ripristina acquisti', 'el': 'Επαναφορά αγορών',
      'es': 'Restaurar compras', 'pt': 'Restaurar compras',
      'ru': 'Восстановить покупки', 'tr': 'Satın alımları geri yükle',
      'ja': '購入を復元',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.workspace_premium,
                        color: Colors.white, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(title),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr(subtitle),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFE65100),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const PaywallScreen()),
                          );
                        },
                        child: Text(
                          tr(getButton),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _restorePurchases,
                      child: Text(tr(restoreButton)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Възстановяване на покупки (RevenueCat). Задължително за iOS (Apple) +
  /// помага на платци, сменили устройство.
  Future<void> _restorePurchases() async {
    final lang = LanguageScope.of(context).locale.languageCode;
    String tr(Map<String, String> m) => m[lang] ?? m['en']!;

    const restoring = {
      'en': 'Restoring…', 'bg': 'Възстановяване…', 'de': 'Wird wiederhergestellt…',
      'fr': 'Restauration…', 'it': 'Ripristino…', 'el': 'Επαναφορά…',
      'es': 'Restaurando…', 'pt': 'Restaurando…', 'ru': 'Восстановление…',
      'tr': 'Geri yükleniyor…', 'ja': '復元中…',
    };
    const success = {
      'en': 'Purchases restored', 'bg': 'Покупките са възстановени',
      'de': 'Käufe wiederhergestellt', 'fr': 'Achats restaurés',
      'it': 'Acquisti ripristinati', 'el': 'Οι αγορές επαναφέρθηκαν',
      'es': 'Compras restauradas', 'pt': 'Compras restauradas',
      'ru': 'Покупки восстановлены', 'tr': 'Satın alımlar geri yüklendi',
      'ja': '購入を復元しました',
    };
    const none = {
      'en': 'No purchases to restore', 'bg': 'Няма покупки за възстановяване',
      'de': 'Keine Käufe zum Wiederherstellen',
      'fr': 'Aucun achat à restaurer', 'it': 'Nessun acquisto da ripristinare',
      'el': 'Δεν υπάρχουν αγορές για επαναφορά',
      'es': 'No hay compras para restaurar',
      'pt': 'Nenhuma compra para restaurar',
      'ru': 'Нет покупок для восстановления',
      'tr': 'Geri yüklenecek satın alım yok', 'ja': '復元する購入はありません',
    };

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(tr(restoring)), duration: const Duration(seconds: 1)),
    );
    final ok = await ProService().restorePurchases();
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? tr(success) : tr(none))),
    );
    setState(() {});
  }

  /// Разделът „България" се показва само при български език или
  /// устройство на територията на България (locale countryCode == BG).
  bool get _isBgContext {
    final lang = LanguageScope.of(context).locale.languageCode;
    if (lang == 'bg') return true;
    final country =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    return country?.toUpperCase() == 'BG';
  }

  /// Секция „България" в Настройки. Празна извън BG контекст.
  /// Засега съдържа toggle „Именни дни" (premium).
  List<Widget> _buildBulgariaSection(BuildContext context) {
    if (!_isBgContext) return const [];
    final theme = Theme.of(context);
    final lang = LanguageScope.of(context).locale.languageCode;

    const sectionTitle = {
      'en': 'Bulgaria', 'bg': 'България', 'de': 'Bulgarien', 'fr': 'Bulgarie',
      'it': 'Bulgaria', 'el': 'Βουλγαρία', 'es': 'Bulgaria', 'pt': 'Bulgária',
      'ru': 'Болгария', 'tr': 'Bulgaristan', 'ja': 'ブルガリア',
    };
    const nameDaysTitle = {
      'en': 'Name days', 'bg': 'Именни дни', 'de': 'Namenstage',
      'fr': 'Fêtes des prénoms', 'it': 'Onomastici', 'el': 'Ονομαστικές εορτές',
      'es': 'Onomásticas', 'pt': 'Dias do nome', 'ru': 'Именины',
      'tr': 'İsim günleri', 'ja': '聖名祝日',
    };
    const nameDaysSubtitle = {
      'en': 'Bulgarian name days in the calendar',
      'bg': 'Български именни дни в календара',
      'de': 'Bulgarische Namenstage im Kalender',
      'fr': 'Fêtes des prénoms bulgares dans le calendrier',
      'it': 'Onomastici bulgari nel calendario',
      'el': 'Βουλγαρικές ονομαστικές εορτές στο ημερολόγιο',
      'es': 'Onomásticas búlgaras en el calendario',
      'pt': 'Dias do nome búlgaros no calendário',
      'ru': 'Болгарские именины в календаре',
      'tr': 'Takvimde Bulgarca isim günleri', 'ja': 'カレンダーにブルガリアの聖名祝日を表示',
    };
    const contactsTitle = {
      'en': 'Contacts celebrating', 'bg': 'Контакти с имен ден',
      'de': 'Feiernde Kontakte', 'fr': 'Contacts en fête',
      'it': 'Contatti in festa', 'el': 'Επαφές που γιορτάζουν',
      'es': 'Contactos que celebran', 'pt': 'Contactos em festa',
      'ru': 'Контакты с именинами', 'tr': 'İsim günü olan kişiler',
      'ja': '記念日の連絡先',
    };
    const contactsSubtitle = {
      'en': 'Show which of your contacts have a name day — stays on your device',
      'bg': 'Покажи кои от контактите ти празнуват — остава на устройството',
      'de': 'Zeigt, welche Kontakte Namenstag haben — bleibt auf dem Gerät',
      'fr': "Affiche quels contacts fêtent leur prénom — reste sur l'appareil",
      'it': 'Mostra quali contatti festeggiano — resta sul dispositivo',
      'el': 'Δείχνει ποιες επαφές γιορτάζουν — μένει στη συσκευή',
      'es': 'Muestra qué contactos celebran su santo — no sale del dispositivo',
      'pt': 'Mostra que contactos fazem anos do nome — fica no dispositivo',
      'ru': 'Показывает, у кого из контактов именины — остаётся на устройстве',
      'tr': 'Hangi kişilerin isim günü olduğunu gösterir — cihazda kalır',
      'ja': '記念日の連絡先を表示 — データは端末内のみ',
    };
    const contactsPermDenied = {
      'en': 'Contacts permission is required for this feature',
      'bg': 'Нужно е разрешение за контакти',
      'de': 'Kontaktberechtigung erforderlich',
      'fr': 'Autorisation des contacts requise',
      'it': 'Autorizzazione ai contatti necessaria',
      'el': 'Απαιτείται άδεια επαφών',
      'es': 'Se necesita permiso de contactos',
      'pt': 'É necessária permissão de contactos',
      'ru': 'Требуется доступ к контактам',
      'tr': 'Kişiler izni gerekli', 'ja': '連絡先へのアクセス許可が必要です',
    };
    const contactsRefresh = {
      'en': 'Refresh contacts', 'bg': 'Опресни контактите',
      'de': 'Kontakte aktualisieren', 'fr': 'Actualiser les contacts',
      'it': 'Aggiorna i contatti', 'el': 'Ανανέωση επαφών',
      'es': 'Actualizar contactos', 'pt': 'Atualizar contactos',
      'ru': 'Обновить контакты', 'tr': 'Kişileri yenile',
      'ja': '連絡先を更新',
    };
    const contactsRefreshHint = {
      'en': 'Rebuild the local index after contact changes',
      'bg': 'Преизгражда локалния индекс след промени',
      'de': 'Lokalen Index nach Änderungen neu aufbauen',
      'fr': "Reconstruit l'index local après modifications",
      'it': "Ricostruisce l'indice locale dopo le modifiche",
      'el': 'Αναδημιουργεί τον τοπικό δείκτη μετά από αλλαγές',
      'es': 'Reconstruye el índice local tras los cambios',
      'pt': 'Reconstrói o índice local após alterações',
      'ru': 'Перестроить локальный индекс после изменений',
      'tr': 'Değişikliklerden sonra yerel dizini yeniden oluştur',
      'ja': '変更後にローカル索引を再構築',
    };
    const contactsRefreshed = {
      'en': 'Contacts refreshed', 'bg': 'Контактите са обновени',
      'de': 'Kontakte aktualisiert', 'fr': 'Contacts actualisés',
      'it': 'Contatti aggiornati', 'el': 'Οι επαφές ανανεώθηκαν',
      'es': 'Contactos actualizados', 'pt': 'Contactos atualizados',
      'ru': 'Контакты обновлены', 'tr': 'Kişiler yenilendi',
      'ja': '連絡先を更新しました',
    };

    String tr(Map<String, String> m) => m[lang] ?? m['en']!;
    final isPro = ProService().isPro;

    return [
      const SizedBox(height: 24),
      Text(
        tr(sectionTitle),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Card(
        child: SwitchListTile(
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF8E24AA).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.cake_rounded, color: Color(0xFF8E24AA)),
          ),
          title: Row(
            children: [
              Flexible(child: Text(tr(nameDaysTitle))),
              if (!isPro) ...[
                const SizedBox(width: 6),
                Icon(Icons.lock, size: 14, color: theme.colorScheme.primary),
              ],
            ],
          ),
          subtitle: Text(
            tr(nameDaysSubtitle),
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          value: _nameDaysEnabled,
          onChanged: (value) async {
            if (value && !isPro) {
              final upgraded = await showPaywallIfNeeded(
                context,
                isFeatureAvailable: false,
                featureName: tr(nameDaysTitle),
              );
              if (!upgraded) return;
            }
            setState(() => _nameDaysEnabled = value);
            // Записва + обновява глобалния notifier (календарът реагира веднага).
            await NameDaysService().setEnabled(value);
            // Сутрешни нотификации за имен ден (вкл./изкл.)
            if (value) {
              await NameDaysService().scheduleNotifications(lang: lang);
            } else {
              await NameDaysService().cancelNotifications();
            }
          },
        ),
      ),
      // „Контакти с имен ден" — само на мобилни (уеб няма контакти) и само
      // когато именните дни са включени (функцията ги допълва). On-device.
      if (_nameDaysEnabled && !kIsWeb) ...[
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8E24AA).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.contacts_rounded,
                      color: Color(0xFF8E24AA)),
                ),
                title: Row(
                  children: [
                    Flexible(child: Text(tr(contactsTitle))),
                    if (!isPro) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.lock,
                          size: 14, color: theme.colorScheme.primary),
                    ],
                  ],
                ),
                subtitle: Text(
                  tr(contactsSubtitle),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                value: _contactsNameDayEnabled,
                onChanged: (value) async {
                  if (value) {
                    if (!isPro) {
                      final upgraded = await showPaywallIfNeeded(
                        context,
                        isFeatureAvailable: false,
                        featureName: tr(contactsTitle),
                      );
                      if (!upgraded) return;
                    }
                    final granted =
                        await ContactNameIndex().requestPermission();
                    if (!granted) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(tr(contactsPermDenied))),
                        );
                      }
                      return;
                    }
                    await ContactNameIndex().setEnabled(true);
                    if (mounted) {
                      setState(() => _contactsNameDayEnabled = true);
                    }
                    // Индексът се гради във фон (1000+ контакта не блокират UI).
                    unawaited(ContactNameIndex().rebuild());
                  } else {
                    await ContactNameIndex().setEnabled(false);
                    if (mounted) {
                      setState(() => _contactsNameDayEnabled = false);
                    }
                  }
                },
              ),
              if (_contactsNameDayEnabled) ...[
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.refresh_rounded,
                      color: Color(0xFF8E24AA)),
                  title: Text(tr(contactsRefresh)),
                  subtitle: Text(
                    tr(contactsRefreshHint),
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  onTap: () async {
                    await ContactNameIndex().rebuild();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr(contactsRefreshed))),
                      );
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ],
      // „Училищен режим" — обратно броене до ваканция + предмети + изпити.
      ..._buildSchoolModeCards(context),
    ];
  }

  // Държави за официални празници (флаг + неутрално английско име).
  // Само поддържани от Nager.Date. Auto-detect от locale е по подразбиране.
  // Бел.: Индия (IN) не се поддържа от Nager, затова липсва (макар да имаме hi).
  static const List<(String, String)> _holidayCountries = [
    ('AT', '🇦🇹 Austria'),
    ('BG', '🇧🇬 Bulgaria'),
    ('CN', '🇨🇳 China'),
    ('CZ', '🇨🇿 Czechia'),
    ('FR', '🇫🇷 France'),
    ('DE', '🇩🇪 Germany'),
    ('GR', '🇬🇷 Greece'),
    ('HU', '🇭🇺 Hungary'),
    ('ID', '🇮🇩 Indonesia'),
    ('IT', '🇮🇹 Italy'),
    ('JP', '🇯🇵 Japan'),
    ('MK', '🇲🇰 North Macedonia'),
    ('NL', '🇳🇱 Netherlands'),
    ('PL', '🇵🇱 Poland'),
    ('PT', '🇵🇹 Portugal'),
    ('RO', '🇷🇴 Romania'),
    ('RU', '🇷🇺 Russia'),
    ('RS', '🇷🇸 Serbia'),
    ('KR', '🇰🇷 South Korea'),
    ('ES', '🇪🇸 Spain'),
    ('CH', '🇨🇭 Switzerland'),
    ('TR', '🇹🇷 Turkey'),
    ('UA', '🇺🇦 Ukraine'),
    ('GB', '🇬🇧 United Kingdom'),
    ('US', '🇺🇸 United States'),
  ];

  /// Секция „Външен вид" — избор на стил на task картите (Класически / Билети).
  /// Реактивна: смяната важи веднага в целия app. „Билети" е Pro тема.
  Widget _buildAppearanceSection(BuildContext context, AppText t) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([TaskViewPreference(), ProService()]),
      builder: (context, _) {
        final pref = TaskViewPreference();
        final isPro = ProService().isPro;

        Widget styleTile({
          required IconData icon,
          required Color color,
          required String title,
          required String subtitle,
          required bool selected,
          required bool locked,
          required VoidCallback onTap,
        }) {
          return InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
                            if (locked) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.lock, size: 14, color: theme.colorScheme.primary),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle, style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          );
        }

        final themeController = ThemeScope.of(context);
        final currentMode = themeController.mode;
        final langCode = LanguageScope.of(context).locale.languageCode;
        return _settingsGroup(
          title: t.appearance,
          icon: Icons.palette_rounded,
          color: Colors.deepPurple,
          children: [
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  styleTile(
                    icon: Icons.view_agenda_rounded,
                    color: Colors.blueGrey,
                    title: t.cardStyleClassic,
                    subtitle: t.cardStyleClassicDesc,
                    selected: pref.cardStyle == CardStyle.classic,
                    locked: false,
                    onTap: () => pref.setCardStyle(CardStyle.classic),
                  ),
                  const Divider(height: 0),
                  styleTile(
                    icon: Icons.confirmation_number_outlined,
                    color: Colors.deepPurple,
                    title: t.cardStyleTicket,
                    subtitle: t.cardStyleTicketDesc,
                    selected: pref.cardStyle == CardStyle.ticket,
                    locked: !isPro,
                    onTap: () async {
                      if (!isPro) {
                        final upgraded = await showPaywallIfNeeded(
                          context,
                          isFeatureAvailable: false,
                          featureName: t.cardStyleTicket,
                        );
                        if (!upgraded) return;
                      }
                      await pref.setCardStyle(CardStyle.ticket);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Тема (light/dark/amoled) — преместена в „Външен вид" (Пакет 2).
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  RadioListTile<int>(
                    value: 0,
                    groupValue: themeController.isAmoled ? 3 : (currentMode == ThemeMode.system ? 0 : (currentMode == ThemeMode.light ? 1 : 2)),
                    title: Text(t.systemTheme),
                    onChanged: (value) => themeController.setMode(ThemeMode.system),
                  ),
                  const Divider(height: 0),
                  RadioListTile<int>(
                    value: 1,
                    groupValue: themeController.isAmoled ? 3 : (currentMode == ThemeMode.system ? 0 : (currentMode == ThemeMode.light ? 1 : 2)),
                    title: Text(t.lightTheme),
                    onChanged: (value) => themeController.setMode(ThemeMode.light),
                  ),
                  const Divider(height: 0),
                  RadioListTile<int>(
                    value: 2,
                    groupValue: themeController.isAmoled ? 3 : (currentMode == ThemeMode.system ? 0 : (currentMode == ThemeMode.light ? 1 : 2)),
                    title: Text(t.darkTheme),
                    onChanged: (value) => themeController.setMode(ThemeMode.dark),
                  ),
                  const Divider(height: 0),
                  RadioListTile<int>(
                    value: 3,
                    groupValue: themeController.isAmoled ? 3 : (currentMode == ThemeMode.system ? 0 : (currentMode == ThemeMode.light ? 1 : 2)),
                    title: Text(t.amoledTheme),
                    subtitle: Text('OLED',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                    onChanged: (value) => themeController.setAmoled(true),
                  ),
                ],
              ),
            ),
            // „Добави widget" (iOS) — преместено в „Външен вид" (Пакет 2).
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
              _buildWidgetGuideTile(context, langCode),
          ],
        );
      },
    );
  }

  Widget _buildHolidaysTile(BuildContext context, String lang) {
    final theme = Theme.of(context);
    const title = {
      'en': 'Public holidays', 'bg': 'Официални празници',
      'de': 'Gesetzliche Feiertage', 'fr': 'Jours fériés',
      'it': 'Festività ufficiali', 'el': 'Επίσημες αργίες',
      'es': 'Días festivos', 'pt': 'Feriados oficiais',
      'ru': 'Официальные праздники', 'tr': 'Resmi tatiller', 'ja': '祝日',
    };
    const subtitle = {
      'en': 'Holidays for your country in the calendar',
      'bg': 'Празниците на твоята държава в календара',
      'de': 'Feiertage deines Landes im Kalender',
      'fr': 'Les jours fériés de ton pays dans le calendrier',
      'it': 'Le festività del tuo paese nel calendario',
      'el': 'Οι αργίες της χώρας σου στο ημερολόγιο',
      'es': 'Los festivos de tu país en el calendario',
      'pt': 'Os feriados do teu país no calendário',
      'ru': 'Праздники твоей страны в календаре',
      'tr': 'Ülkenin tatilleri takvimde', 'ja': 'カレンダーにお住まいの国の祝日を表示',
    };
    const countryLabel = {
      'en': 'Country', 'bg': 'Държава', 'de': 'Land', 'fr': 'Pays',
      'it': 'Paese', 'el': 'Χώρα', 'es': 'País', 'pt': 'País',
      'ru': 'Страна', 'tr': 'Ülke', 'ja': '国',
    };
    String tr(Map<String, String> m) => m[lang] ?? m['en']!;

    // Ако текущата държава не е в списъка, добавяме я временно най-отгоре.
    final items = List<(String, String)>.from(_holidayCountries);
    if (!items.any((c) => c.$1 == _holidaysCountry)) {
      items.insert(0, (_holidaysCountry, _holidaysCountry));
    }

    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(HolidaysService.colorValue)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.flag_rounded,
                  color: Color(HolidaysService.colorValue)),
            ),
            title: Text(tr(title)),
            subtitle: Text(
              tr(subtitle),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            value: _holidaysEnabled,
            onChanged: (value) async {
              setState(() => _holidaysEnabled = value);
              await HolidaysService().setEnabled(value);
              if (value) await HolidaysService().loadForCurrentYears();
            },
          ),
          if (_holidaysEnabled) ...[
            const Divider(height: 0),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  Text(
                    tr(countryLabel),
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _holidaysCountry,
                      isExpanded: true,
                      alignment: Alignment.centerRight,
                      underline: const SizedBox.shrink(),
                      items: items
                          .map((c) => DropdownMenuItem(
                                value: c.$1,
                                child: Text(c.$2,
                                    textAlign: TextAlign.right,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (code) async {
                        if (code == null) return;
                        setState(() => _holidaysCountry = code);
                        await HolidaysService().setCountry(code);
                        await HolidaysService().loadForCurrentYears();
                        // loadForCurrentYears bump-ва revision → календарът се обновява.
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _loadMorningBriefingSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isMorningBriefingEnabled = prefs.getBool('morning_briefing_enabled') ?? false;
    });
  }

  Future<void> _saveMorningBriefingSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('morning_briefing_enabled', value);
  }

  Future<void> _checkCalendarConnection() async {
    // isConnected reflects in-memory state (set by tryReconnect at startup).
    // Fallback to prefs in case tryReconnect() is still in progress (race condition).
    bool connected = _calendarService.isConnected;
    if (!connected) {
      final prefs = await SharedPreferences.getInstance();
      connected = prefs.getBool('google_calendar_connected') ?? false;
    }
    // Извеждаме режима: записаният избор печели; за стари потребители без
    // запис, но със свързан Google → google.
    final mode = await IosCalendarService.currentMode();
    final resolved = (mode == 'none' && connected) ? 'google' : mode;
    if (mounted) setState(() { _isCalendarConnected = connected; _calMode = resolved; });
  }

  Future<void> _checkIosCalendarPermission() async {
    final granted = await _iosCalendarService.hasPermission();
    if (mounted) setState(() => _isIosCalendarGranted = granted);
  }

  /// Превключва календарния източник. Източниците са взаимно изключващи се:
  /// избор на Apple изключва Google и обратно.
  Future<void> _setCalendarMode(String mode) async {
    final t = AppText.of(context);
    if (mode == _calMode) return;

    if (mode == 'none') {
      if (_calendarService.isConnected) await _calendarService.disconnect();
      await IosCalendarService.setMode('none');
      if (mounted) setState(() { _calMode = 'none'; _isCalendarConnected = false; });
      return;
    }

    if (mode == 'google') {
      await IosCalendarService.setMode('google'); // Apple export off
      // Ако вече сме свързани (напр. връщане от Apple) — не пускай нов OAuth,
      // за да не иска разрешение всеки път.
      if (_calendarService.isConnected) {
        if (mounted) setState(() { _calMode = 'google'; _isCalendarConnected = true; });
        return;
      }
      if (kIsWeb) {
        // На web самият GIS бутон върши входа; само маркираме режима и
        // оставяме UI-я да покаже бутона/„Разреши достъп".
        if (mounted) setState(() => _calMode = 'google');
        return;
      }
      // Първо тих reconnect (от keychain) — без диалог, ако вече е оторизиран.
      await _calendarService.tryReconnect();
      bool ok = _calendarService.isConnected;
      if (!ok) ok = await _calendarService.connect();
      if (mounted) {
        setState(() {
          _isCalendarConnected = ok;
          if (ok) _calMode = 'google';
        });
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.connectionFailed)),
          );
        }
      }
      return;
    }

    // mode == 'apple'
    final granted = await _iosCalendarService.requestPermission();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.calendarAccessDenied)),
        );
      }
      return;
    }
    // НЕ изключваме Google акаунта (за да не иска разрешение наново при връщане).
    // Взаимната изключителност се пази от gate-а `!exportEnabled` в Google
    // hook-овете — щом Apple е активен, Google експортът е заспал.
    await IosCalendarService.setMode('apple');
    if (mounted) {
      setState(() {
        _calMode = 'apple';
        _isIosCalendarGranted = true;
        // _isCalendarConnected се запазва — Google акаунтът остава, но заспал.
      });
    }
    // Еднократен първоначален експорт на отворените задачи.
    final taskBox = Hive.box<Task>('tasks');
    final tasks = taskBox.values
        .where((t) => !t.isCompleted && !t.isArchived && !t.deleted)
        .toList();
    final count = await _iosCalendarService.exportOpenTasks(tasks);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.tasksAddedToAppleCalendar(count))),
      );
    }
  }

  // Списък с предефинирани цветове за color picker (споделен — виж utils/category_colors.dart)
  static const List<Color> _categoryColors = kCategoryColors;

  /// Показва диалог за управление на категориите
  void _showCategoryManagementDialog() {
    final languageController = LanguageScope.of(context);
    final langCode = languageController.locale.languageCode;
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final categoryBox = Hive.box<Category>('categories');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (innerContext, setSheetState) {
            final categories = categoryBox.values.toList();

            return Container(
              height: MediaQuery.of(innerContext).size.height * 0.7,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.category_rounded,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          t.categories,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(innerContext),
                          icon: Icon(
                            Icons.close_rounded,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Category list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final catColor = Color(cat.colorValue);
                        final localizedName = cat.id == 'cal_events'
                            ? t.catCalendarEvents
                            : cat.id == 'documents'
                            ? t.catDocuments
                            : cat.isDefault
                            ? {
                                'work': t.catWork,
                                'personal': t.catPersonal,
                                'shopping': t.catShopping,
                                'birthday': t.catBirthdays,
                                'meeting': t.catMeeting,
                                'workout': t.catWorkout,
                                'payment': t.catPayment,
                                'travel': t.catTravel,
                                'gift': t.catGift,
                              }[cat.id] ?? cat.name
                            : cat.name;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.folder_rounded,
                                color: catColor,
                              ),
                            ),
                            title: Text(
                              localizedName,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: cat.isDefault
                                ? Text(
                                    t.defaultCategory,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Edit button
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    color: theme.colorScheme.primary,
                                  ),
                                  onPressed: () {
                                    _showEditCategoryDialog(
                                      cat,
                                      t,
                                      theme,
                                      () {
                                        setSheetState(() {});
                                        setState(() {});
                                      },
                                    );
                                  },
                                ),
                                // Delete button (само за не-default)
                                if (!cat.isDefault)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: innerContext,
                                        builder: (ctx) => AlertDialog(
                                          title: Text(t.deletion),
                                          content: Text(t.deleteCategoryMessage(cat.name)),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: Text(t.cancel),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.redAccent,
                                              ),
                                              child: Text(t.delete),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await categoryBox.delete(cat.id);
                                        setSheetState(() {});
                                        setState(() {});
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Add category button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showAddCategoryDialog(t, theme, () {
                            setSheetState(() {});
                            setState(() {});
                          });
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: Text(t.addCategory),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Показва диалог за добавяне на нова категория
  void _showAddCategoryDialog( AppText t, ThemeData theme, VoidCallback onComplete) {
    final controller = TextEditingController();
    Color selectedColor = Colors.blue;
    final categoryBox = Hive.box<Category>('categories');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(t.newCategory),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: t.name,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t.color,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categoryColors.map((color) {
                          final isSelected = selectedColor.value == color.value;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedColor = color;
                              });
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(t.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      final id = DateTime.now().millisecondsSinceEpoch.toString();
                      final newCat = Category(
                        id: id,
                        name: name,
                        colorValue: selectedColor.value,
                        isDefault: false,
                      );
                      categoryBox.put(id, newCat);
                      Navigator.pop(ctx);
                      onComplete();
                    }
                  },
                  child: Text(t.add),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Показва диалог за редактиране на категория
  void _showEditCategoryDialog(Category cat, AppText t, ThemeData theme, VoidCallback onComplete) {
    final controller = TextEditingController(text: cat.name);
    Color selectedColor = Color(cat.colorValue);
    final categoryBox = Hive.box<Category>('categories');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(t.editCategory),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: controller,
                        enabled: !cat.isDefault, // Default категориите не могат да се преименуват
                        decoration: InputDecoration(
                          labelText: t.name,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          helperText: cat.isDefault
                              ? (t.defaultCategoryNameCannotChange)
                              : null,
                          helperMaxLines: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t.color,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categoryColors.map((color) {
                          final isSelected = selectedColor.value == color.value;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedColor = color;
                              });
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(t.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      // За default категории, запазваме оригиналното име
                      final updatedCat = Category(
                        id: cat.id,
                        name: cat.isDefault ? cat.name : name,
                        colorValue: selectedColor.value,
                        isDefault: cat.isDefault,
                      );
                      categoryBox.put(cat.id, updatedCat);
                      Navigator.pop(ctx);
                      onComplete();
                    }
                  },
                  child: Text(t.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Показва диалог за избор на език
  void _showLanguageDialog(BuildContext context, LanguageController languageController, Locale currentLocale) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.language_rounded,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      AppText.of(context).language,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Списък с езици - SCROLLABLE
              Expanded(
                child: ListView.builder(
                  itemCount: SupportedLocales.all.length,
                  itemBuilder: (context, index) {
                    final locale = SupportedLocales.all[index];
                    final isSelected = currentLocale.languageCode == locale.languageCode;
                    return ListTile(
                      leading: Text(
                        SupportedLocales.flags[locale.languageCode] ?? '🌐',
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        SupportedLocales.names[locale.languageCode] ?? locale.languageCode,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                          : null,
                      onTap: () {
                        languageController.setLocale(locale);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Load saved briefing time
  Future<void> _loadBriefingTime() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _briefingHour = prefs.getInt('briefing_hour') ?? 8;
      _briefingMinute = prefs.getInt('briefing_minute') ?? 0;
    });
  }

  // Format time for display
  String _formatTime(int hour, int minute) {
    final hourStr = hour.toString().padLeft(2, '0');
    
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hourStr:$minuteStr';
  }

  // Select briefing time
  Future<void> _selectBriefingTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _briefingHour, minute: _briefingMinute),
    );
    
    if (picked != null) {
      setState(() {
        _briefingHour = picked.hour;
        _briefingMinute = picked.minute;
      });
      
      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('briefing_hour', _briefingHour);
      await prefs.setInt('briefing_minute', _briefingMinute);
      
      // Reschedule briefing
      await _morningBriefingService.scheduleDailyBriefing(
        hour: _briefingHour,
        minute: _briefingMinute,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppText.of(context).briefingTimeSetTo(_formatTime(_briefingHour, _briefingMinute))),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _exportData(BuildContext context) async {
    final t = AppText.of(context);
    final languageController = LanguageScope.of(context);
    final langCode = languageController.locale.languageCode;

    try {
      final taskBox = Hive.box<Task>('tasks');
      final categoryBox = Hive.box<Category>('categories');

      final data = {
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0',
        'categories': categoryBox.values.map((c) => {
          'id': c.id,
          'name': c.name,
          'colorValue': c.colorValue,
          'isDefault': c.isDefault,
        }).toList(),
        'tasks': taskBox.values.map((t) => {
          'title': t.title,
          'dueDate': t.dueDate.toIso8601String(),
          'categoryId': t.categoryId,
          'priority': t.priority,
          'isCompleted': t.isCompleted,
          'recurrence': t.recurrence,
          'reminder': t.reminder,
          'subtasks': t.subtasks,
          'notes': t.notes,
          'completedAt': t.completedAt?.toIso8601String(),
          // ВАЖНО: пази връзката към Google Calendar, иначе при възстановяване
          // авто-импортът ще ги мисли за нови → масови дубли.
          'googleCalendarEventId': t.googleCalendarEventId,
          'importedFromCalendar': t.importedFromCalendar,
          'template': t.template,
        }).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      // Web: dart:io File / getTemporaryDirectory не съществуват → сваляме
      // файла директно през браузъра (Blob download).
      if (kIsWeb) {
        final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        await saveTextFile('task_manager_backup_$ts.json', jsonString);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.tasksBackup)),
          );
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'task_manager_backup_$timestamp.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      // iOS popover anchor: share_plus иска non-zero sharePositionOrigin,
      // иначе хвърля PlatformException на iPad/iOS. На Android се игнорира.
      final box = context.findRenderObject() as RenderBox?;
      final size = MediaQuery.of(context).size;
      final origin = (box != null && box.hasSize)
          ? box.localToGlobal(Offset.zero) & box.size
          : Rect.fromCenter(
              center: Offset(size.width / 2, size.height / 2),
              width: 1,
              height: 1,
            );

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: t.backupSubject,
        text: t.tasksBackup,
        sharePositionOrigin: origin,
      );

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${t.exportError}: $e',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _importData(BuildContext context) async {
    final t = AppText.of(context);
    final languageController = LanguageScope.of(context);
    final langCode = languageController.locale.languageCode;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.single.path;
      if (filePath == null) return;

      final file = File(filePath);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final taskBox = Hive.box<Task>('tasks');
      final categoryBox = Hive.box<Category>('categories');

      if (context.mounted) {
        final tasksCount = (data['tasks'] as List).length;
        final categoriesCount = (data['categories'] as List).length;

        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(t.confirmation),
            content: Text(t.importConfirmMessage(tasksCount, categoriesCount)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: Text(t.replace),
              ),
            ],
          ),
        );

        if (confirm != true) return;
      }

      await taskBox.clear();
      await categoryBox.clear();

      final categories = data['categories'] as List<dynamic>;
      for (final c in categories) {
        final category = Category(
          id: c['id'] as String,
          name: c['name'] as String,
          colorValue: c['colorValue'] as int,
          isDefault: c['isDefault'] as bool? ?? false,
        );
        await categoryBox.put(category.id, category);
      }

      final tasks = data['tasks'] as List<dynamic>;
      for (final taskData in tasks) {
        final task = Task(
          title: taskData['title'] as String,
          dueDate: DateTime.parse(taskData['dueDate'] as String),
          categoryId: taskData['categoryId'] as String,
          priority: taskData['priority'] as int? ?? 1,
          recurrence: taskData['recurrence'] as String?,
          reminder: taskData['reminder'] as String?,
          subtasks: (taskData['subtasks'] as List<dynamic>?)?.cast<String>(),
          notes: taskData['notes'] as String?,
          completedAt: taskData['completedAt'] != null
              ? DateTime.parse(taskData['completedAt'] as String)
              : null,
          googleCalendarEventId: taskData['googleCalendarEventId'] as String?,
          importedFromCalendar: taskData['importedFromCalendar'] as bool?,
          template: taskData['template'] as String?,
        );
        task.isCompleted = taskData['isCompleted'] as bool? ?? false;
        await taskBox.add(task);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.importSuccessMessage(tasks.length, categories.length)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${t.importError}: $e',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _openLogin() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _editDisplayName() async {
    final t = AppText.of(context);
    final ctrl = TextEditingController(text: _authService.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.displayName),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: t.displayName,
            helperText: t.displayNameDesc,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(t.save),
          ),
        ],
      ),
    );
    if (name == null) return;
    await _authService.updateDisplayName(name);
    // Разпространи новото име към всичките ми групи (за „завършена от …" и членове).
    await GroupService().syncMyMemberInfo();
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    final t = AppText.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.logout),
        content: Text(
          t.logoutConfirm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: Text(t.logout),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// ФАЗА 2Б: единен ръчен синхрон (merge с облака). Замества старите
  /// „Качване"/„Сваляне" огледални бутони, които триеха данни. Безопасен —
  /// само слива, нищо не се губи.
  Future<void> _syncNow() async {
    final t = AppText.of(context);
    setState(() => _isSyncing = true);
    final result = await SyncService().mergeWithCloud();
    if (!mounted) return;
    setState(() => _isSyncing = false);
    if (result.error == 'in-progress') return; // тих — вече тече синхрон
    final String msg;
    final bool ok = result.success;
    if (ok) {
      msg = t.syncSuccess;
    } else if (result.error == 'not-signed-in') {
      msg = t.signInToSync; // приятелско — не „грешка"
    } else {
      msg = '${t.error}: ${result.error}';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? Colors.green : Colors.orange,
      ),
    );
  }

  /// Авторитетно нулиране: трие облака + локалното. После потребителят
  /// импортира чистия бекъп (напр. iPhone Export Data JSON).
  Future<void> _resetSync() async {
    final t = AppText.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.resetSync),
        content: Text(t.resetSyncConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isSyncing = true);
    final n = await SyncService().wipeAllTasks();
    if (!mounted) return;
    setState(() => _isSyncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.resetSyncDone(n)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// ФАЗА 2Б/3: ръчен двупосочен Google Calendar синхрон (импорт + експорт +
  /// облачен merge). Безобиден — само слива; изтриване само през tombstone.
  Future<void> _calendarSyncNow() async {
    final t = AppText.of(context);
    setState(() => _isSyncing = true);
    try {
      final taskBox = Hive.box<Task>('tasks');
      final categoryBox = Hive.box<Category>('categories');

      // 1) Импорт от Google (нови събития/задачи).
      await CalendarImportService.runImport(
        taskBox, categoryBox, t,
        interactive: true,
      );
      await CalendarImportService.markSynced();

      // 2) Експорт/обновяване на локалните задачи към Google. Със същото ID →
      //    events.update (без дубли); insert само ако още няма googleEventId.
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      for (final task in taskBox.values.toList()) {
        if (task.isCompleted || task.isArchived) continue;
        if (!task.dueDate.isAfter(today.subtract(const Duration(days: 1)))) continue;
        // Нативните рождени дни се управляват само в приложението → не ги
        // качваме като събития (иначе плодим „рождени дни" в Google Calendar).
        if (task.categoryId == 'birthday' || task.template == 'birthday') continue;
        if (task.googleCalendarEventId != null) {
          await _calendarService.updateCalendarEvent(
              task.googleCalendarEventId!, task, interactive: true);
        } else if (task.importedFromCalendar != true) {
          // Само ИСТИНСКИ твои задачи се качват като нови събития. Календарни
          // задачи без eventId (загубен линк) НЕ се пресъздават → без дубли в
          // Google Calendar; импортът по-горе вече ги е ре-свързал, ако още ги има.
          final eventId =
              await _calendarService.addTaskToCalendar(task, interactive: true);
          if (eventId != null) {
            task.googleCalendarEventId = eventId;
            await task.save();
          }
        }
      }

      // 3) Облачен merge (Firebase).
      await SyncService().mergeWithCloud();
    } catch (e) {
      debugPrint('Calendar sync error: $e');
    }
    if (!mounted) return;
    setState(() => _isSyncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.syncSuccess)),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Секция „За приложението" (най-долу в Настройки): динамична версия/билд
  /// (package_info_plus), подекран „Как се ползва" и полезни линкове
  /// (Поверителност, Условия, лиценз на именните дни — CC BY-SA).
  List<Widget> _buildAboutSection(BuildContext context) {
    final theme = Theme.of(context);
    final lang = LanguageScope.of(context).locale.languageCode;
    String tr(Map<String, String> m) => m[lang] ?? m['en']!;

    const sectionTitle = {
      'en': 'About', 'bg': 'За приложението', 'de': 'Über die App',
      'fr': 'À propos', 'it': 'Informazioni', 'el': 'Σχετικά',
      'es': 'Acerca de', 'pt': 'Sobre', 'ru': 'О приложении',
      'tr': 'Hakkında', 'ja': 'アプリについて',
    };
    const versionWord = {
      'en': 'Version', 'bg': 'Версия', 'de': 'Version', 'fr': 'Version',
      'it': 'Versione', 'el': 'Έκδοση', 'es': 'Versión', 'pt': 'Versão',
      'ru': 'Версия', 'tr': 'Sürüm', 'ja': 'バージョン',
    };
    const howToTitle = {
      'en': 'How to use', 'bg': 'Как се ползва', 'de': 'Anleitung',
      'fr': 'Comment ça marche', 'it': 'Come si usa', 'el': 'Πώς λειτουργεί',
      'es': 'Cómo se usa', 'pt': 'Como usar', 'ru': 'Как пользоваться',
      'tr': 'Nasıl kullanılır', 'ja': '使い方',
    };
    const howToSubtitle = {
      'en': 'Quick guide', 'bg': 'Кратко ръководство', 'de': 'Kurzanleitung',
      'fr': 'Guide rapide', 'it': 'Guida rapida', 'el': 'Σύντομος οδηγός',
      'es': 'Guía rápida', 'pt': 'Guia rápido', 'ru': 'Краткое руководство',
      'tr': 'Hızlı kılavuz', 'ja': 'クイックガイド',
    };
    const privacyLabel = {
      'en': 'Privacy Policy', 'bg': 'Политика за поверителност',
      'de': 'Datenschutz', 'fr': 'Confidentialité', 'it': 'Privacy',
      'el': 'Απόρρητο', 'es': 'Privacidad', 'pt': 'Privacidade',
      'ru': 'Конфиденциальность', 'tr': 'Gizlilik', 'ja': 'プライバシー',
    };
    const termsLabel = {
      'en': 'Terms of Use', 'bg': 'Условия за ползване',
      'de': 'Nutzungsbedingungen', 'fr': "Conditions d'utilisation",
      'it': "Termini d'uso", 'el': 'Όροι χρήσης', 'es': 'Términos de uso',
      'pt': 'Termos de uso', 'ru': 'Условия использования',
      'tr': 'Kullanım koşulları', 'ja': '利用規約',
    };
    const nameDaysLicense = {
      'en': 'Name days: data from Wikipedia (CC BY-SA 4.0)',
      'bg': 'Именни дни: данни от Уикипедия (CC BY-SA 4.0)',
      'de': 'Namenstage: Daten aus Wikipedia (CC BY-SA 4.0)',
      'fr': 'Fêtes des prénoms : données de Wikipédia (CC BY-SA 4.0)',
      'it': 'Onomastici: dati da Wikipedia (CC BY-SA 4.0)',
      'el': 'Ονομαστικές εορτές: δεδομένα από τη Wikipedia (CC BY-SA 4.0)',
      'es': 'Onomásticas: datos de Wikipedia (CC BY-SA 4.0)',
      'pt': 'Dias do nome: dados da Wikipédia (CC BY-SA 4.0)',
      'ru': 'Именины: данные из Википедии (CC BY-SA 4.0)',
      'tr': 'İsim günleri: Wikipedia verileri (CC BY-SA 4.0)',
      'ja': '聖名祝日: Wikipediaのデータ (CC BY-SA 4.0)',
    };

    return [
      _settingsGroup(
        title: tr(sectionTitle),
        icon: Icons.info_outline_rounded,
        color: Colors.blueGrey,
        children: [
      Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            // Версия + билд — четат се ДИНАМИЧНО от package_info_plus.
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snap) {
                final info = snap.data;
                final subtitle = info == null
                    ? '…'
                    : '${tr(versionWord)} ${info.version} (build ${info.buildNumber})';
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.info_outline,
                        color: theme.colorScheme.primary),
                  ),
                  title: const Text('Taskify'),
                  subtitle: Text(subtitle),
                );
              },
            ),
            const Divider(height: 1),
            // „Как се ползва" → подекран.
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.help_outline, color: theme.colorScheme.primary),
              ),
              title: Text(tr(howToTitle)),
              subtitle: Text(
                tr(howToSubtitle),
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HowToUseScreen()),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(tr(privacyLabel)),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _openUrl('https://taskify1969.com/privacy'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(tr(termsLabel)),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _openUrl('https://taskify1969.com/terms'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      // Лиценз на именните дни (CC BY-SA изисква атрибуция).
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: InkWell(
          onTap: () =>
              _openUrl('https://bg.wikipedia.org/wiki/Имен_ден'),
          child: Text(
            tr(nameDaysLicense),
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
        ],
      ),
    ];
  }

  // ── Упътване „Как да добавя widget" (iOS) ─────────────────────────────
  static const Map<String, Map<String, String>> _widgetGuide = {
    'title': {
      'en': 'Add the widget', 'bg': 'Добави widget', 'de': 'Widget hinzufügen',
      'fr': 'Ajouter le widget', 'it': 'Aggiungi il widget', 'el': 'Πρόσθεσε το widget',
      'es': 'Añadir el widget', 'pt': 'Adicionar o widget', 'ru': 'Добавить виджет',
      'tr': 'Widget ekle', 'ja': 'ウィジェットを追加',
    },
    'subtitle': {
      'en': "See today's tasks on your Home Screen",
      'bg': 'Виж днешните си задачи на началния екран',
      'de': 'Zeige heutige Aufgaben auf dem Home-Bildschirm',
      'fr': "Vois tes tâches du jour sur l'écran d'accueil",
      'it': 'Vedi le attività di oggi nella schermata Home',
      'el': 'Δες τις σημερινές εργασίες στην αρχική οθόνη',
      'es': 'Ve las tareas de hoy en la pantalla de inicio',
      'pt': 'Vê as tarefas de hoje no ecrã inicial',
      'ru': 'Смотри задачи на сегодня на главном экране',
      'tr': 'Bugünkü görevleri ana ekranda gör',
      'ja': 'ホーム画面で今日のタスクを表示',
    },
    's1': {
      'en': 'Touch and hold an empty spot on the Home Screen.',
      'bg': 'Задръж пръст върху празно място на началния екран.',
      'de': 'Halte eine leere Stelle auf dem Home-Bildschirm gedrückt.',
      'fr': "Appuie longuement sur une zone vide de l'écran d'accueil.",
      'it': 'Tieni premuto uno spazio vuoto nella schermata Home.',
      'el': 'Κράτα πατημένο ένα κενό σημείο στην αρχική οθόνη.',
      'es': 'Mantén pulsado un espacio vacío en la pantalla de inicio.',
      'pt': 'Toca e mantém num espaço vazio do ecrã inicial.',
      'ru': 'Нажми и удерживай пустое место на главном экране.',
      'tr': 'Ana ekranda boş bir yere basılı tut.',
      'ja': 'ホーム画面の空いている場所を長押しします。',
    },
    's2': {
      'en': 'Tap the + button in the top corner.',
      'bg': 'Натисни бутона + в горния ъгъл.',
      'de': 'Tippe auf + in der oberen Ecke.',
      'fr': 'Touche le bouton + dans le coin supérieur.',
      'it': 'Tocca il pulsante + in alto.',
      'el': 'Πάτησε το + στην επάνω γωνία.',
      'es': 'Toca el botón + en la esquina superior.',
      'pt': 'Toca no botão + no canto superior.',
      'ru': 'Нажми кнопку + в верхнем углу.',
      'tr': 'Üst köşedeki + düğmesine dokun.',
      'ja': '上隅の + ボタンをタップします。',
    },
    's3': {
      'en': 'Search for “Taskify”.', 'bg': 'Потърси „Taskify".',
      'de': 'Suche nach „Taskify".', 'fr': 'Cherche « Taskify ».',
      'it': 'Cerca “Taskify”.', 'el': 'Αναζήτησε «Taskify».',
      'es': 'Busca «Taskify».', 'pt': 'Procura “Taskify”.',
      'ru': 'Найди «Taskify».', 'tr': '“Taskify” ara.', 'ja': '「Taskify」を検索します。',
    },
    's4': {
      'en': 'Pick a size and tap “Add Widget”.',
      'bg': 'Избери размер и натисни „Добави widget".',
      'de': 'Wähle eine Größe und tippe auf „Widget hinzufügen".',
      'fr': 'Choisis une taille et touche « Ajouter le widget ».',
      'it': 'Scegli una dimensione e tocca “Aggiungi widget”.',
      'el': 'Διάλεξε μέγεθος και πάτησε «Προσθήκη widget».',
      'es': 'Elige un tamaño y toca «Añadir widget».',
      'pt': 'Escolhe um tamanho e toca “Adicionar widget”.',
      'ru': 'Выбери размер и нажми «Добавить виджет».',
      'tr': 'Bir boyut seç ve “Widget Ekle”ye dokun.',
      'ja': 'サイズを選んで「ウィジェットを追加」をタップします。',
    },
    'ok': {
      'en': 'Got it', 'bg': 'Разбрах', 'de': 'Verstanden', 'fr': 'Compris',
      'it': 'Ho capito', 'el': 'Κατάλαβα', 'es': 'Entendido', 'pt': 'Percebi',
      'ru': 'Понятно', 'tr': 'Anladım', 'ja': 'わかりました',
    },
  };

  String _wg(String k, String lang) =>
      _widgetGuide[k]?[lang] ?? _widgetGuide[k]?['en'] ?? '';

  Widget _buildWidgetGuideTile(BuildContext context, String lang) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6A3DE8).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.widgets_outlined, color: Color(0xFF6A3DE8)),
          ),
          title: Text(_wg('title', lang)),
          subtitle: Text(_wg('subtitle', lang)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(_wg('title', lang)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in ['s1', 's2', 's3', 's4'])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${['s1', 's2', 's3', 's4'].indexOf(s) + 1}.  ',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            Expanded(child: Text(_wg(s, lang))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(_wg('ok', lang)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Падаща (сгъваема) група в Настройки — намалява претрупването. Логиката на
  /// всяка секция остава непокътната; тук само я обгръщаме визуално.
  Widget _settingsGroup({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // Скрий стандартните разделители на ExpansionTile за по-чист вид.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(title,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.2,
              )),
          initiallyExpanded: initiallyExpanded,
          shape: const Border(),
          collapsedShape: const Border(),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          children: children,
        ),
      ),
    );
  }

  /// Компактна карта „Профил" горе в Настройки (Пакет 2). Два реда (аватар +
  /// име/имейл) БЕЗ CTA; трети ред само при активен режим. Тап → [ProfileScreen].
  Widget _buildProfileCard(BuildContext context) {
    final theme = Theme.of(context);
    final lang = LanguageScope.of(context).locale.languageCode;
    String tr(Map<String, String> m) => m[lang] ?? m['en']!;
    final rawUser = _authService.currentUser;
    final user = (rawUser != null && !rawUser.isAnonymous) ? rawUser : null;
    final name = _authService.displayName;
    final email = user?.email ?? '';
    final title = name.isNotEmpty
        ? name
        : (email.isNotEmpty ? email : tr(const {
            'en': 'Profile', 'bg': 'Профил', 'de': 'Profil', 'fr': 'Profil',
            'it': 'Profilo', 'el': 'Προφίλ', 'es': 'Perfil', 'pt': 'Perfil',
            'ru': 'Профиль', 'tr': 'Profil', 'ja': 'プロフィール',
          }));
    final initial = (title.isNotEmpty ? title : '?').substring(0, 1).toUpperCase();

    // Ред за режим (само ако е активен).
    String? modeLine;
    final school = SchoolCalendarService();
    final uni = UniversityService();
    if (school.enabled && school.grade != null) {
      modeLine = '🎒 ${tr(const {
        'en': 'Pupil', 'bg': 'Ученик', 'de': 'Schüler', 'fr': 'Élève',
        'it': 'Alunno', 'el': 'Μαθητής', 'es': 'Alumno', 'pt': 'Aluno',
        'ru': 'Ученик', 'tr': 'Öğrenci', 'ja': '生徒',
      })} · ${school.grade} ${tr(const {
        'en': 'grade', 'bg': 'клас', 'de': 'Klasse', 'fr': 'classe',
        'it': 'classe', 'el': 'τάξη', 'es': 'grado', 'pt': 'ano',
        'ru': 'класс', 'tr': 'sınıf', 'ja': '年生',
      })}';
    } else if (uni.enabled && uni.profile != null) {
      modeLine = '🎓 ${tr(const {
        'en': 'Student', 'bg': 'Студент', 'de': 'Student', 'fr': 'Étudiant',
        'it': 'Studente', 'el': 'Φοιτητής', 'es': 'Estudiante', 'pt': 'Estudante',
        'ru': 'Студент', 'tr': 'Üniversite', 'ja': '大学生',
      })}${uni.displayUniversityName != null ? ' · ${uni.displayUniversityName}' : ''}';
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primary,
                child: Text(initial,
                    style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (email.isNotEmpty && name.isNotEmpty)
                      Text(email,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: theme.colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    if (modeLine != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(modeLine,
                            style: TextStyle(
                                fontSize: 12.5,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final languageController = LanguageScope.of(context);

    final currentLocale = languageController.locale;
    // Анонимните сесии (създадени само за affiliate-attribution лог) НЕ са
    // „акаунт" → показваме им секцията за вход, не панел за профил.
    final rawUser = _authService.currentUser;
    final user =
        (rawUser != null && !rawUser.isAnonymous) ? rawUser : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        children: [
          // „Стани Pro" — постоянен вход към paywall, само за не-Pro на mobile.
          if (!kIsWeb && !ProService().isPro) _buildGoProCard(context),

          // ── КАРТА „ПРОФИЛ" (най-горе) → ProfileScreen ──
          _buildProfileCard(context),
          const SizedBox(height: 16),

          // Език - НАЙ-ОТГОРЕ
          Text(
            t.language,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  SupportedLocales.flags[currentLocale.languageCode] ?? '🌐',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              title: Text(SupportedLocales.names[currentLocale.languageCode] ?? 'English'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLanguageDialog(context, languageController, currentLocale),
            ),
          ),

          const SizedBox(height: 16),

          // ═══ Група — 🎨 Външен вид (Стил карти + Тема + Добави widget) ═══
          _buildAppearanceSection(context, t),

          // ── Задачи (падаща група): Статистики, Категории, AI ──
          _settingsGroup(
            title: t.tasksAndAi,
            icon: Icons.task_alt_rounded,
            color: Colors.teal,
            children: [
              ListTile(
                leading: const Icon(Icons.bar_chart_rounded, color: Colors.purple),
                title: Text(t.statistics),
                subtitle: Text(
                  t.viewProgress,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StatisticsScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.category_rounded, color: Colors.teal),
                title: Text(t.manageCategories),
                subtitle: Text(
                  t.editAddDeleteCategories,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showCategoryManagementDialog,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.auto_awesome, color: Colors.purple),
                title: Text(t.aiSettings),
                subtitle: Text(
                  t.aiSettingsSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // (Акаунтът се управлява от карта „Профил" горе → ProfileScreen.)
          // Календарна синхронизация — ЕДИН избор. Източниците са взаимно
          // изключващи се: ако потребителят има външна GCal↔Apple връзка, двата
          // активни наведнъж биха показвали всяко събитие двойно. Apple е
          // export-only (без импорт) — виж IosCalendarService.
          _settingsGroup(
            title: t.cloudSync,
            icon: Icons.sync_rounded,
            color: Colors.blue,
            children: [
              Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                child: Column(
              children: [
                RadioListTile<String>(
                  value: 'none',
                  groupValue: _calMode,
                  title: Text(t.calendarSyncOff),
                  onChanged: (v) => _setCalendarMode(v!),
                ),
                const Divider(height: 0),
                RadioListTile<String>(
                  value: 'google',
                  groupValue: _calMode,
                  title: Text(t.googleCalendar),
                  subtitle: Text(
                    _isCalendarConnected ? t.calendarSyncEnabled : t.connectForSync,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  onChanged: (v) => _setCalendarMode(v!),
                ),
                // Web: избран Google, но още без достъп → официален GIS бутон /
                // „Разреши достъп" (браузърът не пуска програмен OAuth popup).
                if (_calMode == 'google' && kIsWeb && !_isCalendarConnected)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _calendarService.webAuthPending.value
                        ? ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.lock_open, color: Colors.green),
                            title: Text(t.allowCalendarAccess),
                            subtitle: Text(t.allowCalendarAccessDesc,
                                style: const TextStyle(fontSize: 12)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              final ok = await _calendarService.authorizeCalendarOnWeb();
                              if (!mounted) return;
                              setState(() => _isCalendarConnected = ok);
                              if (!ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(t.connectionFailed)),
                                );
                              }
                            },
                          )
                        : SizedBox(width: 220, child: googleSignInButton()),
                  ),
                // Google свързан: ръчен синхрон + премахни дублирани събития.
                if (_calMode == 'google' && _isCalendarConnected) ...[
                  const Divider(height: 0),
                  ListTile(
                    leading: _isSyncing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync, color: Colors.blue),
                    title: Text(t.syncNow),
                    subtitle: Text(t.autoSyncDesc, style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _isSyncing ? null : _calendarSyncNow,
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services, color: Colors.orange),
                    title: Text(t.removeDuplicates),
                    subtitle: Text(t.removeDuplicatesDesc, style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('${t.removeDuplicates}?'),
                          content: Text(t.removeDuplicatesDesc),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(t.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(t.delete, style: const TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${t.removeDuplicates}…')),
                        );
                      }
                      final removed = await _calendarService.removeDuplicateEvents(interactive: true);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t.removedDuplicates(removed))),
                        );
                      }
                    },
                  ),
                ],
                // Apple Calendar — само на iOS, export-only (без импорт).
                if (!kIsWeb && Platform.isIOS) ...[
                  const Divider(height: 0),
                  RadioListTile<String>(
                    value: 'apple',
                    groupValue: _calMode,
                    title: Text(t.appleCalendarSendOnly),
                    subtitle: Text(
                      t.appleCalendarSendOnlyDesc,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    onChanged: (v) => _setCalendarMode(v!),
                  ),
                  // Ръчно почистване на заварени дубли в Apple Calendar.
                  if (_calMode == 'apple') ...[
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.cleaning_services, color: Colors.orange),
                      title: Text(t.removeDuplicates),
                      subtitle: Text(t.removeDuplicatesDesc, style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text('${t.removeDuplicates}?'),
                            content: Text(t.removeDuplicatesDesc),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(t.cancel),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(t.delete, style: const TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${t.removeDuplicates}…')),
                          );
                        }
                        final taskBox = Hive.box<Task>('tasks');
                        final res = await _iosCalendarService
                            .removeDuplicateEvents(taskBox.values.toList());
                        if (mounted) {
                          // Ако нищо не е изтрито, но има дубли в read-only
                          // (синхронизиран) календар — обясни защо.
                          final msg = (res.removed == 0 && res.blockedReadonly > 0)
                              ? t.duplicatesInSyncedCalendar
                              : t.removedDuplicates(res.removed);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg)),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
              // Синхронизирай / Нулирай — преместени тук от Акаунт (Пакет 2).
              if (user != null) ...[
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: _isSyncing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.cloud_sync_outlined,
                                color: Colors.blue),
                        title: Text(t.syncNow),
                        subtitle: Text(t.autoSyncDesc,
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6))),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _isSyncing ? null : _syncNow,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.restart_alt, color: Colors.red),
                        title: Text(t.resetSync),
                        subtitle: Text(t.resetSyncDesc,
                            style: const TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _isSyncing ? null : _resetSync,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // ── Известия и данни (падаща група): Morning Briefing + Backup ──
          _settingsGroup(
            title: t.morningBriefing,
            icon: Icons.notifications_active_rounded,
            color: Colors.orange,
            children: [
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.wb_sunny_rounded, color: Colors.orange),
              ),
              title: Text(t.morningBriefing),
              subtitle: Text(t.dailyTaskSummaryAt(_formatTime(_briefingHour, _briefingMinute))),
              value: _isMorningBriefingEnabled,
              onChanged: (value) async {
                setState(() => _isMorningBriefingEnabled = value);
                await _saveMorningBriefingSetting(value);
                if (value) {
                  await _morningBriefingService.scheduleDailyBriefing(
                    hour: _briefingHour,
                    minute: _briefingMinute,
                  );
                } else {
                  await _morningBriefingService.cancelDailyBriefing();
                }
              },
            ),
          ),
          // Time Picker (only show if briefing enabled)
          if (_isMorningBriefingEnabled)
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.access_time, color: Colors.blue),
                ),
                title: Text(t.briefingTime),
                subtitle: Text(_formatTime(_briefingHour, _briefingMinute)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectBriefingTime,
              ),
            ),
            ],
          ),

          const SizedBox(height: 16),
          // Официални празници — достъпно за всички държави (не само BG).
          _buildHolidaysTile(
              context, LanguageScope.of(context).locale.languageCode),

          // Раздел „България" (именни дни) — само при BG език/локация.
          ..._buildBulgariaSection(context),

          const SizedBox(height: 16),
          // ── Данни (падаща група): Backup / Restore ──
          _settingsGroup(
            title: t.localData,
            icon: Icons.storage_rounded,
            color: Colors.green,
            children: [
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.upload_rounded,
                      color: Colors.green,
                    ),
                  ),
                  title: Text(t.exportData),
                  subtitle: Text(
                    t.shareBackup,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportData(context),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.download_rounded,
                      color: Colors.teal,
                    ),
                  ),
                  title: Text(t.importData),
                  subtitle: Text(
                    t.restoreFromJson,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _importData(context),
                ),
              ],
            ),
          ),
            ],
          ),

          const SizedBox(height: 16),

          // App info
          Center(
            child: Text(
              'Taskify v1.0',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),

          // Delete Account (само ако е логнат)
          if (user != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                t.account.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: Text(
                  t.deleteAccount,
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  t.deleteAccountSubtitle,
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () => DeleteAccountFlow.start(context),
              ),
            ),
            const SizedBox(height: 32),
          ],

          // „За приложението" — най-долу.
          ..._buildAboutSection(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}



