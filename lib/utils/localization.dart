import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Поддържани езици
class SupportedLocales {
  static const List<Locale> all = [
    Locale('en'), // English (default)
    Locale('bg'), // Bulgarian
    Locale('de'), // German
    Locale('fr'), // French
    Locale('it'), // Italian
    Locale('el'), // Greek
    Locale('es'), // Spanish
    Locale('pt'), // Portuguese
    Locale('ru'), // Russian
    Locale('tr'), // Turkish
    Locale('ja'), // Japanese
  ];

  static const Map<String, String> names = {
    'en': 'English',
    'bg': 'Български',
    'de': 'Deutsch',
    'fr': 'Français',
    'it': 'Italiano',
    'el': 'Ελληνικά',
    'es': 'Español',
    'pt': 'Português',
    'ru': 'Русский',
    'tr': 'Türkçe',
    'ja': '日本語',
  };

  static const Map<String, String> flags = {
    'en': '🇬🇧',
    'bg': '🇧🇬',
    'de': '🇩🇪',
    'fr': '🇫🇷',
    'it': '🇮🇹',
    'el': '🇬🇷',
    'es': '🇪🇸',
    'pt': '🇵🇹',
    'ru': '🇷🇺',
    'tr': '🇹🇷',
    'ja': '🇯🇵',
  };

  static bool isSupported(String langCode) {
    return all.any((l) => l.languageCode == langCode);
  }

  static Locale getBestMatch(Locale systemLocale) {
    if (isSupported(systemLocale.languageCode)) {
      return Locale(systemLocale.languageCode);
    }
    return const Locale('en');
  }
}

/// Контролер за езика
class LanguageController extends ChangeNotifier {
  LanguageController([Locale? initial])
      : _locale = initial ?? const Locale('en');

  Locale _locale;
  Locale get locale => _locale;

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', locale.languageCode);
    notifyListeners();
  }

  Future<void> loadSavedLocale(Locale systemLocale) async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('app_language');
    if (langCode != null && SupportedLocales.isSupported(langCode)) {
      _locale = Locale(langCode);
    } else {
      _locale = SupportedLocales.getBestMatch(systemLocale);
      await prefs.setString('app_language', _locale.languageCode);
    }
    notifyListeners();
  }
}

class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({
    super.key,
    required LanguageController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static LanguageController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LanguageScope>();
    assert(scope != null, 'LanguageScope not found');
    return scope!.notifier!;
  }
}

class ThemeController extends ChangeNotifier {
  ThemeController([ThemeMode? initial]) : _mode = initial ?? ThemeMode.system;
  ThemeMode _mode;
  bool _isAmoled = false;
  
  ThemeMode get mode => _mode;
  bool get isAmoled => _isAmoled;

  Future<void> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt('themeMode') ?? 0;
    _isAmoled = prefs.getBool('isAmoled') ?? false;
    _mode = ThemeMode.values[modeIndex];
    notifyListeners();
  }

  void setMode(ThemeMode mode) {
    if (_mode == mode && !_isAmoled) return;
    _mode = mode;
    _isAmoled = false;
    _saveTheme();
    notifyListeners();
  }

  void setAmoled(bool value) {
    _isAmoled = value;
    if (value) _mode = ThemeMode.dark;
    _saveTheme();
    notifyListeners();
  }

  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', _mode.index);
    await prefs.setBool('isAmoled', _isAmoled);
  }
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope not found');
    return scope!.notifier!;
  }
}

/// Локализирани текстове - ПЪЛНА ВЕРСИЯ
class AppText {
  final Locale locale;
  final String lang;

  AppText._(this.locale) : lang = locale.languageCode;

  static AppText of(BuildContext context) {
    final controller = LanguageScope.of(context);
    return AppText._(controller.locale);
  }

  bool get isBg => lang == 'bg';

  String _t(Map<String, String> m) => m[lang] ?? m['en'] ?? '';

  // ==================== ОСНОВНИ ЕКРАНИ ====================
  String get tasks => _t({'en': 'Tasks', 'bg': 'Задачи', 'de': 'Aufgaben', 'fr': 'Tâches', 'it': 'Attività', 'el': 'Εργασίες', 'es': 'Tareas', 'pt': 'Tarefas', 'ru': 'Задачи', 'tr': 'Görevler', 'ja': 'タスク'});
  String get calendar => _t({'en': 'Calendar', 'bg': 'Календар', 'de': 'Kalender', 'fr': 'Calendrier', 'it': 'Calendario', 'el': 'Ημερολόγιο', 'es': 'Calendario', 'pt': 'Calendário', 'ru': 'Календарь', 'tr': 'Takvim', 'ja': 'カレンダー'});
  String get settings => _t({'en': 'Settings', 'bg': 'Настройки', 'de': 'Einstellungen', 'fr': 'Paramètres', 'it': 'Impostazioni', 'el': 'Ρυθμίσεις', 'es': 'Ajustes', 'pt': 'Configurações', 'ru': 'Настройки', 'tr': 'Ayarlar', 'ja': '設定'});

  // ==================== СТАТИСТИКА ====================
  String get total => _t({'en': 'Total', 'bg': 'Общо', 'de': 'Gesamt', 'fr': 'Total', 'it': 'Totale', 'el': 'Σύνολο', 'es': 'Total', 'pt': 'Total', 'ru': 'Всего', 'tr': 'Toplam', 'ja': '合計'});
  String get completed => _t({'en': 'Completed', 'bg': 'Завършени', 'de': 'Erledigt', 'fr': 'Terminées', 'it': 'Completate', 'el': 'Ολοκληρωμένες', 'es': 'Completadas', 'pt': 'Concluídas', 'ru': 'Завершено', 'tr': 'Tamamlandı', 'ja': '完了'});
  String get overdue => _t({'en': 'Overdue', 'bg': 'Просрочени', 'de': 'Überfällig', 'fr': 'En retard', 'it': 'Scadute', 'el': 'Εκπρόθεσμες', 'es': 'Vencidas', 'pt': 'Atrasadas', 'ru': 'Просрочено', 'tr': 'Gecikmiş', 'ja': '期限切れ'});
  String get upcoming => _t({'en': 'Upcoming', 'bg': 'Предстоящи', 'de': 'Bevorstehend', 'fr': 'À venir', 'it': 'In arrivo', 'el': 'Επερχόμενες', 'es': 'Próximas', 'pt': 'Próximas', 'ru': 'Предстоящие', 'tr': 'Yaklaşan', 'ja': '今後'});
  String get activity => _t({'en': 'Activity', 'bg': 'Активност', 'de': 'Aktivität', 'fr': 'Activité', 'it': 'Attività', 'el': 'Δραστηριότητα', 'es': 'Actividad', 'pt': 'Atividade', 'ru': 'Активность', 'tr': 'Etkinlik', 'ja': 'アクティビティ'});
  String get taskView => _t({'en': 'Task View', 'bg': 'Изглед на задачите', 'de': 'Aufgabenansicht', 'fr': 'Vue des tâches', 'it': 'Vista attività', 'el': 'Προβολή εργασιών', 'es': 'Vista de tareas', 'pt': 'Visualização', 'ru': 'Вид задач', 'tr': 'Görev Görünümü', 'ja': 'タスク表示'});
  String get viewExpanded => _t({'en': 'Expanded', 'bg': 'Разширен', 'de': 'Erweitert', 'fr': 'Étendu', 'it': 'Espanso', 'el': 'Αναπτυγμένη', 'es': 'Expandido', 'pt': 'Expandido', 'ru': 'Расширенный', 'tr': 'Genişletilmiş', 'ja': '展開'});
  String get viewExpandedDesc => _t({'en': 'With details and badges', 'bg': 'С детайли и значки', 'de': 'Mit Details', 'fr': 'Avec détails', 'it': 'Con dettagli', 'el': 'Με λεπτομέρειες', 'es': 'Con detalles', 'pt': 'Com detalhes', 'ru': 'С подробностями', 'tr': 'Detaylarla', 'ja': '詳細とバッジ付き'});
  String get viewCompact => _t({'en': 'Compact', 'bg': 'Компактен', 'de': 'Kompakt', 'fr': 'Compact', 'it': 'Compatto', 'el': 'Συμπαγής', 'es': 'Compacto', 'pt': 'Compacto', 'ru': 'Компактный', 'tr': 'Kompakt', 'ja': 'コンパクト'});
  String get viewCompactDesc => _t({'en': 'Less space, more tasks', 'bg': 'По-малко място, повече задачи', 'de': 'Weniger Platz', 'fr': 'Moins de place', 'it': 'Meno spazio', 'el': 'Λιγότερος χώρος', 'es': 'Menos espacio', 'pt': 'Menos espaço', 'ru': 'Меньше места', 'tr': 'Daha az alan', 'ja': 'スペースを節約してより多くのタスクを表示'});

  // ==================== ВЪНШЕН ВИД / СТИЛ НА КАРТИТЕ ====================
  String get appearance => _t({'en': 'Appearance', 'bg': 'Външен вид', 'de': 'Darstellung', 'fr': 'Apparence', 'it': 'Aspetto', 'el': 'Εμφάνιση', 'es': 'Apariencia', 'pt': 'Aparência', 'ru': 'Внешний вид', 'tr': 'Görünüm', 'ja': '外観'});
  String get taskCardStyle => _t({'en': 'Task style', 'bg': 'Стил на задачите', 'de': 'Aufgabenstil', 'fr': 'Style des tâches', 'it': 'Stile attività', 'el': 'Στυλ εργασιών', 'es': 'Estilo de tareas', 'pt': 'Estilo das tarefas', 'ru': 'Стиль задач', 'tr': 'Görev stili', 'ja': 'タスクのスタイル'});
  String get cardStyleClassic => _t({'en': 'Classic', 'bg': 'Класически', 'de': 'Klassisch', 'fr': 'Classique', 'it': 'Classico', 'el': 'Κλασικό', 'es': 'Clásico', 'pt': 'Clássico', 'ru': 'Классический', 'tr': 'Klasik', 'ja': 'クラシック'});
  String get cardStyleTicket => _t({'en': 'Tickets', 'bg': 'Билети', 'de': 'Tickets', 'fr': 'Billets', 'it': 'Biglietti', 'el': 'Εισιτήρια', 'es': 'Billetes', 'pt': 'Bilhetes', 'ru': 'Билеты', 'tr': 'Biletler', 'ja': 'チケット'});
  String get cardStyleClassicDesc => _t({'en': 'Standard cards', 'bg': 'Стандартни карти', 'de': 'Standardkarten', 'fr': 'Cartes standard', 'it': 'Schede standard', 'el': 'Τυπικές κάρτες', 'es': 'Tarjetas estándar', 'pt': 'Cartões padrão', 'ru': 'Стандартные карточки', 'tr': 'Standart kartlar', 'ja': '標準カード'});
  String get cardStyleTicketDesc => _t({'en': 'Tear-off ticket style', 'bg': 'Билет с откъсване', 'de': 'Abreißticket-Stil', 'fr': 'Style billet détachable', 'it': 'Stile biglietto strappabile', 'el': 'Στυλ αποκόμματος εισιτηρίου', 'es': 'Estilo billete con corte', 'pt': 'Estilo bilhete destacável', 'ru': 'Билет с отрывом', 'tr': 'Yırtmalı bilet stili', 'ja': '切り取りチケット風'});
  String get overdueLabel => _t({'en': 'overdue', 'bg': 'просрочена', 'de': 'überfällig', 'fr': 'en retard', 'it': 'scaduta', 'el': 'εκπρόθεσμη', 'es': 'vencida', 'pt': 'atrasada', 'ru': 'просрочена', 'tr': 'gecikmiş', 'ja': '期限切れ'});
  String get tomorrow => _t({'en': 'tomorrow', 'bg': 'утре', 'de': 'morgen', 'fr': 'demain', 'it': 'domani', 'el': 'αύριο', 'es': 'mañana', 'pt': 'amanhã', 'ru': 'завтра', 'tr': 'yarın', 'ja': '明日'});
  String get ticketTearHint => _t({'en': 'Pull the stub down to complete', 'bg': 'Дръпни отрязъка надолу за готово', 'de': 'Abschnitt nach unten ziehen zum Erledigen', 'fr': 'Tirez le talon vers le bas pour terminer', 'it': 'Tira il tagliando giù per completare', 'el': 'Τράβα το απόκομμα κάτω για ολοκλήρωση', 'es': 'Tira del talón hacia abajo para completar', 'pt': 'Puxe o canhoto para baixo para concluir', 'ru': 'Потяни корешок вниз, чтобы завершить', 'tr': 'Tamamlamak için koçanı aşağı çek', 'ja': '切り取り部分を下に引いて完了'});

  String get statistics => _t({'en': 'Statistics', 'bg': 'Статистики', 'de': 'Statistiken', 'fr': 'Statistiques', 'it': 'Statistiche', 'el': 'Στατιστικά', 'es': 'Estadísticas', 'pt': 'Estatísticas', 'ru': 'Статистика', 'tr': 'İstatistikler', 'ja': '統計'});
  String get viewProgress => _t({'en': 'See everything you\'ve accomplished', 'bg': 'Виж всичко, което си постигнал', 'de': 'Sieh, was du alles geschafft hast', 'fr': 'Voyez tout ce que vous avez accompli', 'it': 'Guarda tutto ciò che hai realizzato', 'el': 'Δες όλα όσα έχεις πετύχει', 'es': 'Mira todo lo que has logrado', 'pt': 'Veja tudo o que você conquistou', 'ru': 'Посмотрите, чего вы достигли', 'tr': 'Neler başardığını gör', 'ja': 'これまでの成果を確認'});
  String get today => _t({'en': 'Today', 'bg': 'Днес', 'de': 'Heute', 'fr': "Aujourd'hui", 'it': 'Oggi', 'el': 'Σήμερα', 'es': 'Hoy', 'pt': 'Hoje', 'ru': 'Сегодня', 'tr': 'Bugün', 'ja': '今日'});
  String get week => _t({'en': 'Week', 'bg': 'Седмица', 'de': 'Woche', 'fr': 'Semaine', 'it': 'Settimana', 'el': 'Εβδομάδα', 'es': 'Semana', 'pt': 'Semana', 'ru': 'Неделя', 'tr': 'Hafta', 'ja': '週'});
  String get month => _t({'en': 'Month', 'bg': 'Месец', 'de': 'Monat', 'fr': 'Mois', 'it': 'Mese', 'el': 'Μήνας', 'es': 'Mes', 'pt': 'Mês', 'ru': 'Месяц', 'tr': 'Ay', 'ja': '月'});
  String get day => _t({'en': 'Day', 'bg': 'Ден', 'de': 'Tag', 'fr': 'Jour', 'it': 'Giorno', 'el': 'Ημέρα', 'es': 'Día', 'pt': 'Dia', 'ru': 'День', 'tr': 'Gün', 'ja': '日'});
  String get task => _t({'en': 'task', 'bg': 'задача', 'de': 'Aufgabe', 'fr': 'tâche', 'it': 'attività', 'el': 'εργασία', 'es': 'tarea', 'pt': 'tarefa', 'ru': 'задача', 'tr': 'görev', 'ja': 'タスク'});
  String get noTasks => _t({'en': 'No tasks for this day', 'bg': 'Няма задачи за този ден', 'de': 'Keine Aufgaben für diesen Tag', 'fr': 'Pas de tâches pour ce jour', 'it': 'Nessuna attività per questo giorno', 'el': 'Δεν υπάρχουν εργασίες για αυτή την ημέρα', 'es': 'No hay tareas para este día', 'pt': 'Sem tarefas para este dia', 'ru': 'Нет задач на этот день', 'tr': 'Bu gün için görev yok', 'ja': 'この日のタスクはありません'});
  String get taskTitle => _t({'en': 'Task title', 'bg': 'Заглавие на задача', 'de': 'Aufgabentitel', 'fr': 'Titre de la tâche', 'it': 'Titolo attività', 'el': 'Τίτλος εργασίας', 'es': 'Título de tarea', 'pt': 'Título da tarefa', 'ru': 'Название задачи', 'tr': 'Görev başlığı', 'ja': 'タスクのタイトル'});

  // ==================== ДНИ НА СЕДМИЦАТА (ПЪЛНИ) ====================
  String get monday => _t({'en': 'Monday', 'bg': 'Понеделник', 'de': 'Montag', 'fr': 'Lundi', 'it': 'Lunedì', 'el': 'Δευτέρα', 'es': 'Lunes', 'pt': 'Segunda-feira', 'ru': 'Понедельник', 'tr': 'Pazartesi', 'ja': '月曜日'});
  String get tuesday => _t({'en': 'Tuesday', 'bg': 'Вторник', 'de': 'Dienstag', 'fr': 'Mardi', 'it': 'Martedì', 'el': 'Τρίτη', 'es': 'Martes', 'pt': 'Terça-feira', 'ru': 'Вторник', 'tr': 'Salı', 'ja': '火曜日'});
  String get wednesday => _t({'en': 'Wednesday', 'bg': 'Сряда', 'de': 'Mittwoch', 'fr': 'Mercredi', 'it': 'Mercoledì', 'el': 'Τετάρτη', 'es': 'Miércoles', 'pt': 'Quarta-feira', 'ru': 'Среда', 'tr': 'Çarşamba', 'ja': '水曜日'});
  String get thursday => _t({'en': 'Thursday', 'bg': 'Четвъртък', 'de': 'Donnerstag', 'fr': 'Jeudi', 'it': 'Giovedì', 'el': 'Πέμπτη', 'es': 'Jueves', 'pt': 'Quinta-feira', 'ru': 'Четверг', 'tr': 'Perşembe', 'ja': '木曜日'});
  String get friday => _t({'en': 'Friday', 'bg': 'Петък', 'de': 'Freitag', 'fr': 'Vendredi', 'it': 'Venerdì', 'el': 'Παρασκευή', 'es': 'Viernes', 'pt': 'Sexta-feira', 'ru': 'Пятница', 'tr': 'Cuma', 'ja': '金曜日'});
  String get saturday => _t({'en': 'Saturday', 'bg': 'Събота', 'de': 'Samstag', 'fr': 'Samedi', 'it': 'Sabato', 'el': 'Σάββατο', 'es': 'Sábado', 'pt': 'Sábado', 'ru': 'Суббота', 'tr': 'Cumartesi', 'ja': '土曜日'});
  String get sunday => _t({'en': 'Sunday', 'bg': 'Неделя', 'de': 'Sonntag', 'fr': 'Dimanche', 'it': 'Domenica', 'el': 'Κυριακή', 'es': 'Domingo', 'pt': 'Domingo', 'ru': 'Воскресенье', 'tr': 'Pazar', 'ja': '日曜日'});

  // ==================== ДНИ НА СЕДМИЦАТА (КРАТКИ) ====================
  String get mon => _t({'en': 'Mon', 'bg': 'Пон', 'de': 'Mo', 'fr': 'Lun', 'it': 'Lun', 'el': 'Δευ', 'es': 'Lun', 'pt': 'Seg', 'ru': 'Пн', 'tr': 'Pzt', 'ja': '月'});
  String get tue => _t({'en': 'Tue', 'bg': 'Вто', 'de': 'Di', 'fr': 'Mar', 'it': 'Mar', 'el': 'Τρι', 'es': 'Mar', 'pt': 'Ter', 'ru': 'Вт', 'tr': 'Sal', 'ja': '火'});
  String get wed => _t({'en': 'Wed', 'bg': 'Сря', 'de': 'Mi', 'fr': 'Mer', 'it': 'Mer', 'el': 'Τετ', 'es': 'Mié', 'pt': 'Qua', 'ru': 'Ср', 'tr': 'Çar', 'ja': '水'});
  String get thu => _t({'en': 'Thu', 'bg': 'Чет', 'de': 'Do', 'fr': 'Jeu', 'it': 'Gio', 'el': 'Πεμ', 'es': 'Jue', 'pt': 'Qui', 'ru': 'Чт', 'tr': 'Per', 'ja': '木'});
  String get fri => _t({'en': 'Fri', 'bg': 'Пет', 'de': 'Fr', 'fr': 'Ven', 'it': 'Ven', 'el': 'Παρ', 'es': 'Vie', 'pt': 'Sex', 'ru': 'Пт', 'tr': 'Cum', 'ja': '金'});
  String get sat => _t({'en': 'Sat', 'bg': 'Съб', 'de': 'Sa', 'fr': 'Sam', 'it': 'Sab', 'el': 'Σαβ', 'es': 'Sáb', 'pt': 'Sáb', 'ru': 'Сб', 'tr': 'Cmt', 'ja': '土'});
  String get sun => _t({'en': 'Sun', 'bg': 'Нед', 'de': 'So', 'fr': 'Dim', 'it': 'Dom', 'el': 'Κυρ', 'es': 'Dom', 'pt': 'Dom', 'ru': 'Вс', 'tr': 'Paz', 'ja': '日'});

  // ==================== МЕСЕЦИ ====================
  String get january => _t({'en': 'January', 'bg': 'Януари', 'de': 'Januar', 'fr': 'Janvier', 'it': 'Gennaio', 'el': 'Ιανουάριος', 'es': 'Enero', 'pt': 'Janeiro', 'ru': 'Январь', 'tr': 'Ocak', 'ja': '1月'});
  String get february => _t({'en': 'February', 'bg': 'Февруари', 'de': 'Februar', 'fr': 'Février', 'it': 'Febbraio', 'el': 'Φεβρουάριος', 'es': 'Febrero', 'pt': 'Fevereiro', 'ru': 'Февраль', 'tr': 'Şubat', 'ja': '2月'});
  String get march => _t({'en': 'March', 'bg': 'Март', 'de': 'März', 'fr': 'Mars', 'it': 'Marzo', 'el': 'Μάρτιος', 'es': 'Marzo', 'pt': 'Março', 'ru': 'Март', 'tr': 'Mart', 'ja': '3月'});
  String get april => _t({'en': 'April', 'bg': 'Април', 'de': 'April', 'fr': 'Avril', 'it': 'Aprile', 'el': 'Απρίλιος', 'es': 'Abril', 'pt': 'Abril', 'ru': 'Апрель', 'tr': 'Nisan', 'ja': '4月'});
  String get may => _t({'en': 'May', 'bg': 'Май', 'de': 'Mai', 'fr': 'Mai', 'it': 'Maggio', 'el': 'Μάιος', 'es': 'Mayo', 'pt': 'Maio', 'ru': 'Май', 'tr': 'Mayıs', 'ja': '5月'});
  String get june => _t({'en': 'June', 'bg': 'Юни', 'de': 'Juni', 'fr': 'Juin', 'it': 'Giugno', 'el': 'Ιούνιος', 'es': 'Junio', 'pt': 'Junho', 'ru': 'Июнь', 'tr': 'Haziran', 'ja': '6月'});
  String get july => _t({'en': 'July', 'bg': 'Юли', 'de': 'Juli', 'fr': 'Juillet', 'it': 'Luglio', 'el': 'Ιούλιος', 'es': 'Julio', 'pt': 'Julho', 'ru': 'Июль', 'tr': 'Temmuz', 'ja': '7月'});
  String get august => _t({'en': 'August', 'bg': 'Август', 'de': 'August', 'fr': 'Août', 'it': 'Agosto', 'el': 'Αύγουστος', 'es': 'Agosto', 'pt': 'Agosto', 'ru': 'Август', 'tr': 'Ağustos', 'ja': '8月'});
  String get september => _t({'en': 'September', 'bg': 'Септември', 'de': 'September', 'fr': 'Septembre', 'it': 'Settembre', 'el': 'Σεπτέμβριος', 'es': 'Septiembre', 'pt': 'Setembro', 'ru': 'Сентябрь', 'tr': 'Eylül', 'ja': '9月'});
  String get october => _t({'en': 'October', 'bg': 'Октомври', 'de': 'Oktober', 'fr': 'Octobre', 'it': 'Ottobre', 'el': 'Οκτώβριος', 'es': 'Octubre', 'pt': 'Outubro', 'ru': 'Октябрь', 'tr': 'Ekim', 'ja': '10月'});
  String get november => _t({'en': 'November', 'bg': 'Ноември', 'de': 'November', 'fr': 'Novembre', 'it': 'Novembre', 'el': 'Νοέμβριος', 'es': 'Noviembre', 'pt': 'Novembro', 'ru': 'Ноябрь', 'tr': 'Kasım', 'ja': '11月'});
  String get december => _t({'en': 'December', 'bg': 'Декември', 'de': 'Dezember', 'fr': 'Décembre', 'it': 'Dicembre', 'el': 'Δεκέμβριος', 'es': 'Diciembre', 'pt': 'Dezembro', 'ru': 'Декабрь', 'tr': 'Aralık', 'ja': '12月'});

  // ==================== ПРИОРИТЕТ ====================
  String get low => _t({'en': 'Low', 'bg': 'Нисък', 'de': 'Niedrig', 'fr': 'Basse', 'it': 'Bassa', 'el': 'Χαμηλή', 'es': 'Baja', 'pt': 'Baixa', 'ru': 'Низкий', 'tr': 'Düşük', 'ja': '低'});
  String get medium => _t({'en': 'Medium', 'bg': 'Среден', 'de': 'Mittel', 'fr': 'Moyenne', 'it': 'Media', 'el': 'Μέτρια', 'es': 'Media', 'pt': 'Média', 'ru': 'Средний', 'tr': 'Orta', 'ja': '中'});
  String get high => _t({'en': 'High', 'bg': 'Висок', 'de': 'Hoch', 'fr': 'Haute', 'it': 'Alta', 'el': 'Υψηλή', 'es': 'Alta', 'pt': 'Alta', 'ru': 'Высокий', 'tr': 'Yüksek', 'ja': '高'});

  // ==================== ПОВТОРЯЕМОСТ ====================
  String get noRepeat => _t({'en': 'No repeat', 'bg': 'Без повторение', 'de': 'Keine Wiederholung', 'fr': 'Pas de répétition', 'it': 'Nessuna ripetizione', 'el': 'Χωρίς επανάληψη', 'es': 'Sin repetición', 'pt': 'Sem repetição', 'ru': 'Без повтора', 'tr': 'Tekrar yok', 'ja': '繰り返しなし'});
  String get daily => _t({'en': 'Daily', 'bg': 'Ежедневно', 'de': 'Täglich', 'fr': 'Quotidien', 'it': 'Giornaliero', 'el': 'Καθημερινά', 'es': 'Diario', 'pt': 'Diário', 'ru': 'Ежедневно', 'tr': 'Günlük', 'ja': '毎日'});
  String get weekly => _t({'en': 'Weekly', 'bg': 'Ежеседмично', 'de': 'Wöchentlich', 'fr': 'Hebdomadaire', 'it': 'Settimanale', 'el': 'Εβδομαδιαία', 'es': 'Semanal', 'pt': 'Semanal', 'ru': 'Еженедельно', 'tr': 'Haftalık', 'ja': '毎週'});
  String get monthly => _t({'en': 'Monthly', 'bg': 'Ежемесечно', 'de': 'Monatlich', 'fr': 'Mensuel', 'it': 'Mensile', 'el': 'Μηνιαία', 'es': 'Mensual', 'pt': 'Mensal', 'ru': 'Ежемесячно', 'tr': 'Aylık', 'ja': '毎月'});
  String get yearly => _t({'en': 'Yearly', 'bg': 'Ежегодно', 'de': 'Jährlich', 'fr': 'Annuel', 'it': 'Annuale', 'el': 'Ετήσια', 'es': 'Anual', 'pt': 'Anual', 'ru': 'Ежегодно', 'tr': 'Yıllık', 'ja': '毎年'});

  // ==================== ОБЩИ БУТОНИ ====================
  String get add => _t({'en': 'Add', 'bg': 'Добави', 'de': 'Hinzufügen', 'fr': 'Ajouter', 'it': 'Aggiungi', 'el': 'Προσθήκη', 'es': 'Añadir', 'pt': 'Adicionar', 'ru': 'Добавить', 'tr': 'Ekle', 'ja': '追加'});
  String get cancel => _t({'en': 'Cancel', 'bg': 'Отказ', 'de': 'Abbrechen', 'fr': 'Annuler', 'it': 'Annulla', 'el': 'Ακύρωση', 'es': 'Cancelar', 'pt': 'Cancelar', 'ru': 'Отмена', 'tr': 'İptal', 'ja': 'キャンセル'});
  String get save => _t({'en': 'Save', 'bg': 'Запази', 'de': 'Speichern', 'fr': 'Enregistrer', 'it': 'Salva', 'el': 'Αποθήκευση', 'es': 'Guardar', 'pt': 'Salvar', 'ru': 'Сохранить', 'tr': 'Kaydet', 'ja': '保存'});
  String get delete => _t({'en': 'Delete', 'bg': 'Изтрий', 'de': 'Löschen', 'fr': 'Supprimer', 'it': 'Elimina', 'el': 'Διαγραφή', 'es': 'Eliminar', 'pt': 'Excluir', 'ru': 'Удалить', 'tr': 'Sil', 'ja': '削除'});
  String get edit => _t({'en': 'Edit', 'bg': 'Редактирай', 'de': 'Bearbeiten', 'fr': 'Modifier', 'it': 'Modifica', 'el': 'Επεξεργασία', 'es': 'Editar', 'pt': 'Editar', 'ru': 'Редактировать', 'tr': 'Düzenle', 'ja': '編集'});
  String get done => _t({'en': 'Done', 'bg': 'Готово', 'de': 'Fertig', 'fr': 'Terminé', 'it': 'Fatto', 'el': 'Έτοιμο', 'es': 'Hecho', 'pt': 'Feito', 'ru': 'Готово', 'tr': 'Tamam', 'ja': '完了'});
  String get allTasksCompleted => _t({'en': 'All tasks completed!', 'bg': 'Всички задачи са завършени!', 'de': 'Alle Aufgaben erledigt!', 'fr': 'Toutes les tâches terminées!', 'it': 'Tutte le attività completate!', 'el': 'Όλες οι εργασίες ολοκληρώθηκαν!', 'es': '¡Todas las tareas completadas!', 'pt': 'Todas as tarefas concluídas!', 'ru': 'Все задачи выполнены!', 'tr': 'Tüm görevler tamamlandı!', 'ja': 'すべてのタスクが完了しました！'});
  String get greatJob => _t({'en': 'Great job!', 'bg': 'Страхотна работа!', 'de': 'Großartige Arbeit!', 'fr': 'Excellent travail!', 'it': 'Ottimo lavoro!', 'el': 'Εξαιρετική δουλειά!', 'es': '¡Buen trabajo!', 'pt': 'Ótimo trabalho!', 'ru': 'Отличная работа!', 'tr': 'Harika iş!', 'ja': 'よくできました！'});
  String get tapToContinue => _t({'en': 'Tap to continue', 'bg': 'Докосни за продължение', 'de': 'Tippen zum Fortfahren', 'fr': 'Appuyez pour continuer', 'it': 'Tocca per continuare', 'el': 'Πατήστε για συνέχεια', 'es': 'Toca para continuar', 'pt': 'Toque para continuar', 'ru': 'Нажмите для продолжения', 'tr': 'Devam etmek için dokunun', 'ja': 'タップして続行'});
  String get confirm => _t({'en': 'Confirm', 'bg': 'Потвърди', 'de': 'Bestätigen', 'fr': 'Confirmer', 'it': 'Conferma', 'el': 'Επιβεβαίωση', 'es': 'Confirmar', 'pt': 'Confirmar', 'ru': 'Подтвердить', 'tr': 'Onayla', 'ja': '確認'});
  String get replace => _t({'en': 'Replace', 'bg': 'Замени', 'de': 'Ersetzen', 'fr': 'Remplacer', 'it': 'Sostituisci', 'el': 'Αντικατάσταση', 'es': 'Reemplazar', 'pt': 'Substituir', 'ru': 'Заменить', 'tr': 'Değiştir', 'ja': '置き換え'});
  String get all => _t({'en': 'All', 'bg': 'Всички', 'de': 'Alle', 'fr': 'Tous', 'it': 'Tutti', 'el': 'Όλα', 'es': 'Todos', 'pt': 'Todos', 'ru': 'Все', 'tr': 'Tümü', 'ja': 'すべて'});

  // ==================== ПОЛЕТА НА ЗАДАЧАТА ====================
  String get category => _t({'en': 'Category', 'bg': 'Категория', 'de': 'Kategorie', 'fr': 'Catégorie', 'it': 'Categoria', 'el': 'Κατηγορία', 'es': 'Categoría', 'pt': 'Categoria', 'ru': 'Категория', 'tr': 'Kategori', 'ja': 'カテゴリー'});
  String get title => _t({'en': 'Title', 'bg': 'Заглавие', 'de': 'Titel', 'fr': 'Titre', 'it': 'Titolo', 'el': 'Τίτλος', 'es': 'Título', 'pt': 'Título', 'ru': 'Название', 'tr': 'Başlık', 'ja': 'タイトル'});
  String get newTask => _t({'en': 'New Task', 'bg': 'Нова задача', 'de': 'Neue Aufgabe', 'fr': 'Nouvelle tâche', 'it': 'Nuova attività', 'el': 'Νέα εργασία', 'es': 'Nueva tarea', 'pt': 'Nova tarefa', 'ru': 'Новая задача', 'tr': 'Yeni görev', 'ja': '新しいタスク'});
  String get editTask => _t({'en': 'Edit Task', 'bg': 'Редактиране', 'de': 'Aufgabe bearbeiten', 'fr': 'Modifier la tâche', 'it': 'Modifica attività', 'el': 'Επεξεργασία εργασίας', 'es': 'Editar tarea', 'pt': 'Editar tarefa', 'ru': 'Редактировать задачу', 'tr': 'Görevi düzenle', 'ja': 'タスクを編集'});
  String get addTask => _t({'en': 'Add Task', 'bg': 'Добави задача', 'de': 'Aufgabe hinzufügen', 'fr': 'Ajouter une tâche', 'it': 'Aggiungi attività', 'el': 'Προσθήκη εργασίας', 'es': 'Añadir tarea', 'pt': 'Adicionar tarefa', 'ru': 'Добавить задачу', 'tr': 'Görev ekle', 'ja': 'タスクを追加'});
  String get saveChanges => _t({'en': 'Save Changes', 'bg': 'Запази промените', 'de': 'Änderungen speichern', 'fr': 'Enregistrer les modifications', 'it': 'Salva modifiche', 'el': 'Αποθήκευση αλλαγών', 'es': 'Guardar cambios', 'pt': 'Salvar alterações', 'ru': 'Сохранить изменения', 'tr': 'Değişiklikleri kaydet', 'ja': '変更を保存'});
  String get dueDate => _t({'en': 'Due date', 'bg': 'Срок', 'de': 'Fälligkeitsdatum', 'fr': 'Date limite', 'it': 'Scadenza', 'el': 'Προθεσμία', 'es': 'Fecha límite', 'pt': 'Data limite', 'ru': 'Срок', 'tr': 'Bitiş tarihi', 'ja': '期限'});
  String get dateAndTime => _t({'en': 'Date & Time', 'bg': 'Дата и час', 'de': 'Datum & Uhrzeit', 'fr': 'Date et heure', 'it': 'Data e ora', 'el': 'Ημερομηνία & Ώρα', 'es': 'Fecha y hora', 'pt': 'Data e hora', 'ru': 'Дата и время', 'tr': 'Tarih ve Saat', 'ja': '日付と時刻'});
  String get time => _t({'en': 'Time', 'bg': 'Час', 'de': 'Uhrzeit', 'fr': 'Heure', 'it': 'Ora', 'el': 'Ώρα', 'es': 'Hora', 'pt': 'Hora', 'ru': 'Время', 'tr': 'Saat', 'ja': '時刻'});
  String get priority => _t({'en': 'Priority', 'bg': 'Приоритет', 'de': 'Priorität', 'fr': 'Priorité', 'it': 'Priorità', 'el': 'Προτεραιότητα', 'es': 'Prioridad', 'pt': 'Prioridade', 'ru': 'Приоритет', 'tr': 'Öncelik', 'ja': '優先度'});
  String get sortBy => _t({'en': 'Sort by', 'bg': 'Сортирай по', 'de': 'Sortieren nach', 'fr': 'Trier par', 'it': 'Ordina per', 'el': 'Ταξινόμηση κατά', 'es': 'Ordenar por', 'pt': 'Ordenar por', 'ru': 'Сортировать по', 'tr': 'Sırala', 'ja': '並べ替え'});
  String get date => _t({'en': 'Date', 'bg': 'Дата', 'de': 'Datum', 'fr': 'Date', 'it': 'Data', 'el': 'Ημερομηνία', 'es': 'Fecha', 'pt': 'Data', 'ru': 'Дата', 'tr': 'Tarih', 'ja': '日付'});
  String get name => _t({'en': 'Name', 'bg': 'Име', 'de': 'Name', 'fr': 'Nom', 'it': 'Nome', 'el': 'Όνομα', 'es': 'Nombre', 'pt': 'Nome', 'ru': 'Имя', 'tr': 'Ad', 'ja': '名前'});
  String get repeat => _t({'en': 'Repeat', 'bg': 'Повторение', 'de': 'Wiederholung', 'fr': 'Répétition', 'it': 'Ripetizione', 'el': 'Επανάληψη', 'es': 'Repetir', 'pt': 'Repetir', 'ru': 'Повтор', 'tr': 'Tekrar', 'ja': '繰り返し'});
  String get whatNeedsToBeDone => _t({'en': 'What needs to be done?', 'bg': 'Какво трябва да направиш?', 'de': 'Was muss erledigt werden?', 'fr': 'Que faut-il faire?', 'it': 'Cosa bisogna fare?', 'el': 'Τι πρέπει να γίνει;', 'es': '¿Qué hay que hacer?', 'pt': 'O que precisa ser feito?', 'ru': 'Что нужно сделать?', 'tr': 'Ne yapılmalı?', 'ja': '何をする必要がありますか？'});

  // ==================== КАТЕГОРИИ ====================
  String get work => _t({'en': 'Work', 'bg': 'Работа', 'de': 'Arbeit', 'fr': 'Travail', 'it': 'Lavoro', 'el': 'Εργασία', 'es': 'Trabajo', 'pt': 'Trabalho', 'ru': 'Работа', 'tr': 'İş', 'ja': '仕事'});
  String get personal => _t({'en': 'Personal', 'bg': 'Лични', 'de': 'Persönlich', 'fr': 'Personnel', 'it': 'Personale', 'el': 'Προσωπικά', 'es': 'Personal', 'pt': 'Pessoal', 'ru': 'Личное', 'tr': 'Kişisel', 'ja': '個人'});
  String get shoppingList => _t({'en': 'Shopping List', 'bg': 'Списък за пазаруване', 'de': 'Einkaufsliste', 'fr': 'Liste de courses', 'it': 'Lista della spesa', 'el': 'Λίστα αγορών', 'es': 'Lista de compras', 'pt': 'Lista de compras', 'ru': 'Список покупок', 'tr': 'Alışveriş listesi', 'ja': '買い物リスト'});
  String get addItem => _t({'en': 'Add item...', 'bg': 'Добави артикул...', 'de': 'Artikel hinzufügen...', 'fr': 'Ajouter un article...', 'it': 'Aggiungi articolo...', 'el': 'Προσθήκη αντικειμένου...', 'es': 'Añadir artículo...', 'pt': 'Adicionar item...', 'ru': 'Добавить товар...', 'tr': 'Öğe ekle...', 'ja': '項目を追加...'});
  String get enterItem => _t({'en': 'Enter item...', 'bg': 'Въведи артикул...', 'de': 'Artikel eingeben...', 'fr': 'Saisir un article...', 'it': 'Inserisci articolo...', 'el': 'Εισάγετε αντικείμενο...', 'es': 'Introducir artículo...', 'pt': 'Digite o item...', 'ru': 'Введите товар...', 'tr': 'Öğe girin...', 'ja': '項目を入力...'});
  String get clearCompleted => _t({'en': 'Clear done', 'bg': 'Изчисти готовите', 'de': 'Erledigte löschen', 'fr': 'Effacer les faits', 'it': 'Cancella completati', 'el': 'Καθαρισμός ολοκληρωμένων', 'es': 'Limpiar hechos', 'pt': 'Limpar concluídos', 'ru': 'Очистить выполненные', 'tr': 'Tamamlananları temizle', 'ja': '完了済みを消去'});
  String get shopping => _t({'en': 'Shopping', 'bg': 'Пазаруване', 'de': 'Einkaufen', 'fr': 'Courses', 'it': 'Spesa', 'el': 'Αγορές', 'es': 'Compras', 'pt': 'Compras', 'ru': 'Покупки', 'tr': 'Alışveriş', 'ja': '買い物'});
  String get categories => _t({'en': 'Categories', 'bg': 'Категории', 'de': 'Kategorien', 'fr': 'Catégories', 'it': 'Categorie', 'el': 'Κατηγορίες', 'es': 'Categorías', 'pt': 'Categorias', 'ru': 'Категории', 'tr': 'Kategoriler', 'ja': 'カテゴリー'});
  String get manageCategories => _t({'en': 'Manage Categories', 'bg': 'Управление на категории', 'de': 'Kategorien verwalten', 'fr': 'Gérer les catégories', 'it': 'Gestisci categorie', 'el': 'Διαχείριση κατηγοριών', 'es': 'Gestionar categorías', 'pt': 'Gerenciar categorias', 'ru': 'Управление категориями', 'tr': 'Kategorileri yönet', 'ja': 'カテゴリーを管理'});
  String get editAddDeleteCategories => _t({'en': 'Organize your tasks your way', 'bg': 'Подреди задачите си както ти е удобно', 'de': 'Organisiere deine Aufgaben nach deinen Wünschen', 'fr': 'Organisez vos tâches à votre façon', 'it': 'Organizza le attività come preferisci', 'el': 'Οργάνωσε τις εργασίες σου όπως θες', 'es': 'Organiza tus tareas a tu manera', 'pt': 'Organize suas tarefas do seu jeito', 'ru': 'Организуйте задачи так, как удобно вам', 'tr': 'Görevlerini istediğin gibi düzenle', 'ja': 'タスクを自分流に整理'});
  String get newCategory => _t({'en': 'New Category', 'bg': 'Нова категория', 'de': 'Neue Kategorie', 'fr': 'Nouvelle catégorie', 'it': 'Nuova categoria', 'el': 'Νέα κατηγορία', 'es': 'Nueva categoría', 'pt': 'Nova categoria', 'ru': 'Новая категория', 'tr': 'Yeni kategori', 'ja': '新しいカテゴリー'});
  String get editCategory => _t({'en': 'Edit Category', 'bg': 'Редактирай категория', 'de': 'Kategorie bearbeiten', 'fr': 'Modifier la catégorie', 'it': 'Modifica categoria', 'el': 'Επεξεργασία κατηγορίας', 'es': 'Editar categoría', 'pt': 'Editar categoria', 'ru': 'Редактировать категорию', 'tr': 'Kategoriyi düzenle', 'ja': 'カテゴリーを編集'});
  String get addCategory => _t({'en': 'Add Category', 'bg': 'Добави категория', 'de': 'Kategorie hinzufügen', 'fr': 'Ajouter une catégorie', 'it': 'Aggiungi categoria', 'el': 'Προσθήκη κατηγορίας', 'es': 'Añadir categoría', 'pt': 'Adicionar categoria', 'ru': 'Добавить категорию', 'tr': 'Kategori ekle', 'ja': 'カテゴリーを追加'});
  String get defaultCategory => _t({'en': 'Default category', 'bg': 'Стандартна категория', 'de': 'Standardkategorie', 'fr': 'Catégorie par défaut', 'it': 'Categoria predefinita', 'el': 'Προεπιλεγμένη κατηγορία', 'es': 'Categoría predeterminada', 'pt': 'Categoria padrão', 'ru': 'Категория по умолчанию', 'tr': 'Varsayılan kategori', 'ja': 'デフォルトカテゴリー'});
  String get defaultCategoryNameCannotChange => _t({'en': 'Default category names cannot be changed', 'bg': 'Името на стандартните категории не може да се променя', 'de': 'Standardkategorienamen können nicht geändert werden', 'fr': 'Les noms des catégories par défaut ne peuvent pas être modifiés', 'it': 'I nomi delle categorie predefinite non possono essere modificati', 'el': 'Τα ονόματα των προεπιλεγμένων κατηγοριών δεν μπορούν να αλλάξουν', 'es': 'Los nombres de las categorías predeterminadas no se pueden cambiar', 'pt': 'Os nomes das categorias padrão não podem ser alterados', 'ru': 'Названия категорий по умолчанию нельзя изменить', 'tr': 'Varsayılan kategori adları değiştirilemez', 'ja': 'デフォルトカテゴリーの名前は変更できません'});
  String get newCat => _t({'en': 'New', 'bg': 'Нова', 'de': 'Neu', 'fr': 'Nouveau', 'it': 'Nuovo', 'el': 'Νέο', 'es': 'Nuevo', 'pt': 'Novo', 'ru': 'Новая', 'tr': 'Yeni', 'ja': '新規'});
  String get color => _t({'en': 'Color', 'bg': 'Цвят', 'de': 'Farbe', 'fr': 'Couleur', 'it': 'Colore', 'el': 'Χρώμα', 'es': 'Color', 'pt': 'Cor', 'ru': 'Цвет', 'tr': 'Renk', 'ja': '色'});

  // ==================== ЕЗИК И ТЕМА ====================
  String get language => _t({'en': 'Language', 'bg': 'Език', 'de': 'Sprache', 'fr': 'Langue', 'it': 'Lingua', 'el': 'Γλώσσα', 'es': 'Idioma', 'pt': 'Idioma', 'ru': 'Язык', 'tr': 'Dil', 'ja': '言語'});
  String get bulgarian => _t({'en': 'Bulgarian', 'bg': 'Български', 'de': 'Bulgarisch', 'fr': 'Bulgare', 'it': 'Bulgaro', 'el': 'Βουλγαρικά', 'es': 'Búlgaro', 'pt': 'Búlgaro', 'ru': 'Болгарский', 'tr': 'Bulgarca', 'ja': 'ブルガリア語'});
  String get english => _t({'en': 'English', 'bg': 'Английски', 'de': 'Englisch', 'fr': 'Anglais', 'it': 'Inglese', 'el': 'Αγγλικά', 'es': 'Inglés', 'pt': 'Inglês', 'ru': 'Английский', 'tr': 'İngilizce', 'ja': '英語'});
  String get theme => _t({'en': 'Theme', 'bg': 'Тема', 'de': 'Design', 'fr': 'Thème', 'it': 'Tema', 'el': 'Θέμα', 'es': 'Tema', 'pt': 'Tema', 'ru': 'Тема', 'tr': 'Tema', 'ja': 'テーマ'});
  String get systemTheme => _t({'en': 'System', 'bg': 'Системна', 'de': 'System', 'fr': 'Système', 'it': 'Sistema', 'el': 'Σύστημα', 'es': 'Sistema', 'pt': 'Sistema', 'ru': 'Системная', 'tr': 'Sistem', 'ja': 'システム'});
  String get lightTheme => _t({'en': 'Light', 'bg': 'Светла', 'de': 'Hell', 'fr': 'Clair', 'it': 'Chiaro', 'el': 'Φωτεινό', 'es': 'Claro', 'pt': 'Claro', 'ru': 'Светлая', 'tr': 'Açık', 'ja': 'ライト'});
  String get darkTheme => _t({'en': 'Dark', 'bg': 'Тъмна', 'de': 'Dunkel', 'fr': 'Sombre', 'it': 'Scuro', 'el': 'Σκοτεινό', 'es': 'Oscuro', 'pt': 'Escuro', 'ru': 'Темная', 'tr': 'Koyu', 'ja': 'ダーク'});
  String get amoledTheme => _t({'en': 'AMOLED Black', 'bg': 'AMOLED черна', 'de': 'AMOLED Schwarz', 'fr': 'AMOLED Noir', 'it': 'AMOLED Nero', 'el': 'AMOLED Μαύρο', 'es': 'AMOLED Negro', 'pt': 'AMOLED Preto', 'ru': 'AMOLED Черная', 'tr': 'AMOLED Siyah', 'ja': 'AMOLEDブラック'});

  // ==================== АРХИВ ====================
  String get archive => _t({'en': 'Archive', 'bg': 'Архивирай', 'de': 'Archivieren', 'fr': 'Archiver', 'it': 'Archivia', 'el': 'Αρχειοθέτηση', 'es': 'Archivar', 'pt': 'Arquivar', 'ru': 'Архивировать', 'tr': 'Arşivle', 'ja': 'アーカイブ'});
  String get unarchive => _t({'en': 'Unarchive', 'bg': 'Възстанови', 'de': 'Wiederherstellen', 'fr': 'Désarchiver', 'it': 'Ripristina', 'el': 'Επαναφορά', 'es': 'Desarchivar', 'pt': 'Desarquivar', 'ru': 'Восстановить', 'tr': 'Arşivden çıkar', 'ja': 'アーカイブ解除'});
  String get restore => _t({'en': 'Restore', 'bg': 'Възстанови', 'de': 'Wiederherstellen', 'fr': 'Restaurer', 'it': 'Ripristina', 'el': 'Επαναφορά', 'es': 'Restaurar', 'pt': 'Restaurar', 'ru': 'Восстановить', 'tr': 'Geri yükle', 'ja': '復元'});
  String get archived => _t({'en': 'Archived', 'bg': 'Архивирани', 'de': 'Archiviert', 'fr': 'Archivées', 'it': 'Archiviate', 'el': 'Αρχειοθετημένες', 'es': 'Archivadas', 'pt': 'Arquivadas', 'ru': 'Архивировано', 'tr': 'Arşivlenmiş', 'ja': 'アーカイブ済み'});

  // ==================== НАПОМНЯНИЯ ====================
  String get reminders => _t({'en': 'Reminders', 'bg': 'Напомняния', 'de': 'Erinnerungen', 'fr': 'Rappels', 'it': 'Promemoria', 'el': 'Υπενθυμίσεις', 'es': 'Recordatorios', 'pt': 'Lembretes', 'ru': 'Напоминания', 'tr': 'Hatırlatıcılar', 'ja': 'リマインダー'});
  String get reminder => _t({'en': 'reminder', 'bg': 'напомняне', 'de': 'Erinnerung', 'fr': 'rappel', 'it': 'promemoria', 'el': 'υπενθύμιση', 'es': 'recordatorio', 'pt': 'lembrete', 'ru': 'напоминание', 'tr': 'hatırlatıcı', 'ja': 'リマインダー'});

  // ==================== ПОДЗАДАЧИ ====================
  String get subtasks => _t({'en': 'Subtasks', 'bg': 'Подзадачи', 'de': 'Unteraufgaben', 'fr': 'Sous-tâches', 'it': 'Sottoattività', 'el': 'Υποεργασίες', 'es': 'Subtareas', 'pt': 'Subtarefas', 'ru': 'Подзадачи', 'tr': 'Alt görevler', 'ja': 'サブタスク'});
  String get newSubtask => _t({'en': 'New Subtask', 'bg': 'Нова подзадача', 'de': 'Neue Unteraufgabe', 'fr': 'Nouvelle sous-tâche', 'it': 'Nuova sottoattività', 'el': 'Νέα υποεργασία', 'es': 'Nueva subtarea', 'pt': 'Nova subtarefa', 'ru': 'Новая подзадача', 'tr': 'Yeni alt görev', 'ja': '新しいサブタスク'});
  String get addSubtask => _t({'en': 'Add subtask', 'bg': 'Добави подзадача', 'de': 'Unteraufgabe hinzufügen', 'fr': 'Ajouter une sous-tâche', 'it': 'Aggiungi sottoattività', 'el': 'Προσθήκη υποεργασίας', 'es': 'Añadir subtarea', 'pt': 'Adicionar subtarefa', 'ru': 'Добавить подзадачу', 'tr': 'Alt görev ekle', 'ja': 'サブタスクを追加'});
  String get enterSubtask => _t({'en': 'Enter subtask...', 'bg': 'Въведи подзадача...', 'de': 'Unteraufgabe eingeben...', 'fr': 'Entrer une sous-tâche...', 'it': 'Inserisci sottoattività...', 'el': 'Εισάγετε υποεργασία...', 'es': 'Introducir subtarea...', 'pt': 'Digite subtarefa...', 'ru': 'Введите подзадачу...', 'tr': 'Alt görev girin...', 'ja': 'サブタスクを入力...'});

  // ==================== БЕЛЕЖКИ ====================
  String get notes => _t({'en': 'Notes', 'bg': 'Бележки', 'de': 'Notizen', 'fr': 'Notes', 'it': 'Note', 'el': 'Σημειώσεις', 'es': 'Notas', 'pt': 'Notas', 'ru': 'Заметки', 'tr': 'Notlar', 'ja': 'メモ'});
  String get addNote => _t({'en': 'Add note...', 'bg': 'Добави бележка...', 'de': 'Notiz hinzufügen...', 'fr': 'Ajouter une note...', 'it': 'Aggiungi nota...', 'el': 'Προσθήκη σημείωσης...', 'es': 'Añadir nota...', 'pt': 'Adicionar nota...', 'ru': 'Добавить заметку...', 'tr': 'Not ekle...', 'ja': 'メモを追加...'});
  String get additionalInfo => _t({'en': 'Additional information...', 'bg': 'Допълнителна информация...', 'de': 'Zusätzliche Informationen...', 'fr': 'Informations supplémentaires...', 'it': 'Informazioni aggiuntive...', 'el': 'Επιπλέον πληροφορίες...', 'es': 'Información adicional...', 'pt': 'Informações adicionais...', 'ru': 'Дополнительная информация...', 'tr': 'Ek bilgi...', 'ja': '追加情報...'});

  // ==================== АКАУНТ ====================
  String get account => _t({'en': 'Account', 'bg': 'Акаунт', 'de': 'Konto', 'fr': 'Compte', 'it': 'Account', 'el': 'Λογαριασμός', 'es': 'Cuenta', 'pt': 'Conta', 'ru': 'Аккаунт', 'tr': 'Hesap', 'ja': 'アカウント'});
  String get signedIn => _t({'en': 'Your tasks are safely backed up', 'bg': 'Задачите ти са в безопасност в облака', 'de': 'Deine Aufgaben sind sicher gesichert', 'fr': 'Vos tâches sont sauvegardées en toute sécurité', 'it': 'Le tue attività sono al sicuro', 'el': 'Οι εργασίες σου είναι ασφαλείς', 'es': 'Tus tareas están a salvo', 'pt': 'Suas tarefas estão seguras', 'ru': 'Ваши задачи надёжно сохранены', 'tr': 'Görevlerin güvende', 'ja': 'タスクは安全に保存されています'});
  String get logout => _t({'en': 'Logout', 'bg': 'Изход', 'de': 'Abmelden', 'fr': 'Déconnexion', 'it': 'Esci', 'el': 'Αποσύνδεση', 'es': 'Cerrar sesión', 'pt': 'Sair', 'ru': 'Выйти', 'tr': 'Çıkış', 'ja': 'ログアウト'});
  String get logoutConfirm => _t({'en': 'Are you sure you want to logout?', 'bg': 'Сигурен ли си, че искаш да излезеш?', 'de': 'Möchtest du dich wirklich abmelden?', 'fr': 'Êtes-vous sûr de vouloir vous déconnecter?', 'it': 'Sei sicuro di voler uscire?', 'el': 'Είστε σίγουροι ότι θέλετε να αποσυνδεθείτε;', 'es': '¿Estás seguro de que quieres cerrar sesión?', 'pt': 'Tem certeza de que deseja sair?', 'ru': 'Вы уверены, что хотите выйти?', 'tr': 'Çıkış yapmak istediğinize emin misiniz?', 'ja': 'ログアウトしてもよろしいですか？'});
  String get notLoggedIn => _t({'en': 'Not logged in', 'bg': 'Не си влязъл', 'de': 'Nicht angemeldet', 'fr': 'Non connecté', 'it': 'Non connesso', 'el': 'Δεν έχετε συνδεθεί', 'es': 'No conectado', 'pt': 'Não conectado', 'ru': 'Не выполнен вход', 'tr': 'Giriş yapılmadı', 'ja': 'ログインしていません'});
  String get loginToSync => _t({'en': 'Login to sync tasks', 'bg': 'Влез, за да синхронизираш', 'de': 'Anmelden zum Synchronisieren', 'fr': 'Connectez-vous pour synchroniser', 'it': 'Accedi per sincronizzare', 'el': 'Συνδεθείτε για συγχρονισμό', 'es': 'Inicia sesión para sincronizar', 'pt': 'Entre para sincronizar', 'ru': 'Войдите для синхронизации', 'tr': 'Senkronize etmek için giriş yapın', 'ja': 'ログインしてタスクを同期'});
  String get login => _t({'en': 'Login', 'bg': 'Вход', 'de': 'Anmelden', 'fr': 'Connexion', 'it': 'Accedi', 'el': 'Σύνδεση', 'es': 'Iniciar sesión', 'pt': 'Entrar', 'ru': 'Войти', 'tr': 'Giriş', 'ja': 'ログイン'});

  // ==================== CLOUD SYNC ====================
  String get cloudSync => _t({'en': 'Cloud Sync', 'bg': 'Облачна синхронизация', 'de': 'Cloud-Synchronisierung', 'fr': 'Synchronisation cloud', 'it': 'Sincronizzazione cloud', 'el': 'Συγχρονισμός cloud', 'es': 'Sincronización en la nube', 'pt': 'Sincronização na nuvem', 'ru': 'Облачная синхронизация', 'tr': 'Bulut senkronizasyonu', 'ja': 'クラウド同期'});
  String get uploadToCloud => _t({'en': 'Upload to Cloud', 'bg': 'Качване в облака', 'de': 'In Cloud hochladen', 'fr': 'Télécharger vers le cloud', 'it': 'Carica su cloud', 'el': 'Μεταφόρτωση στο cloud', 'es': 'Subir a la nube', 'pt': 'Enviar para a nuvem', 'ru': 'Загрузить в облако', 'tr': 'Buluta yükle', 'ja': 'クラウドにアップロード'});
  String get uploadToCloudDesc => _t({'en': 'Backup tasks to the cloud', 'bg': 'Качи задачите в облака', 'de': 'Aufgaben in der Cloud sichern', 'fr': 'Sauvegarder les tâches dans le cloud', 'it': 'Backup attività nel cloud', 'el': 'Αντίγραφο ασφαλείας εργασιών στο cloud', 'es': 'Guardar tareas en la nube', 'pt': 'Fazer backup de tarefas na nuvem', 'ru': 'Резервное копирование в облако', 'tr': 'Görevleri buluta yedekle', 'ja': 'タスクをクラウドにバックアップ'});
  String get downloadFromCloud => _t({'en': 'Download from Cloud', 'bg': 'Сваляне от облака', 'de': 'Aus Cloud herunterladen', 'fr': 'Télécharger depuis le cloud', 'it': 'Scarica da cloud', 'el': 'Λήψη από cloud', 'es': 'Descargar de la nube', 'pt': 'Baixar da nuvem', 'ru': 'Скачать из облака', 'tr': 'Buluttan indir', 'ja': 'クラウドからダウンロード'});
  String get downloadFromCloudDesc => _t({'en': 'Restore tasks from the cloud', 'bg': 'Възстанови задачите от облака', 'de': 'Aufgaben aus Cloud wiederherstellen', 'fr': 'Restaurer les tâches depuis le cloud', 'it': 'Ripristina attività dal cloud', 'el': 'Επαναφορά εργασιών από cloud', 'es': 'Restaurar tareas de la nube', 'pt': 'Restaurar tarefas da nuvem', 'ru': 'Восстановить из облака', 'tr': 'Görevleri buluttan geri yükle', 'ja': 'クラウドからタスクを復元'});
  String get upload => _t({'en': 'Upload', 'bg': 'Качи', 'de': 'Hochladen', 'fr': 'Télécharger', 'it': 'Carica', 'el': 'Μεταφόρτωση', 'es': 'Subir', 'pt': 'Enviar', 'ru': 'Загрузить', 'tr': 'Yükle', 'ja': 'アップロード'});
  String get download => _t({'en': 'Download', 'bg': 'Свали', 'de': 'Herunterladen', 'fr': 'Télécharger', 'it': 'Scarica', 'el': 'Λήψη', 'es': 'Descargar', 'pt': 'Baixar', 'ru': 'Скачать', 'tr': 'İndir', 'ja': 'ダウンロード'});
  String get syncing => _t({'en': 'Syncing...', 'bg': 'Синхронизиране...', 'de': 'Synchronisiere...', 'fr': 'Synchronisation...', 'it': 'Sincronizzazione...', 'el': 'Συγχρονισμός...', 'es': 'Sincronizando...', 'pt': 'Sincronizando...', 'ru': 'Синхронизация...', 'tr': 'Senkronize ediliyor...', 'ja': '同期中...'});
  String get syncSuccess => _t({'en': 'Sync successful', 'bg': 'Синхронизацията е успешна', 'de': 'Synchronisierung erfolgreich', 'fr': 'Synchronisation réussie', 'it': 'Sincronizzazione riuscita', 'el': 'Επιτυχής συγχρονισμός', 'es': 'Sincronización exitosa', 'pt': 'Sincronização bem-sucedida', 'ru': 'Синхронизация выполнена', 'tr': 'Senkronizasyon başarılı', 'ja': '同期に成功しました'});

  // ==================== ЛОКАЛНИ ДАННИ ====================
  String get localData => _t({'en': 'Local Data', 'bg': 'Локални данни', 'de': 'Lokale Daten', 'fr': 'Données locales', 'it': 'Dati locali', 'el': 'Τοπικά δεδομένα', 'es': 'Datos locales', 'pt': 'Dados locais', 'ru': 'Локальные данные', 'tr': 'Yerel veriler', 'ja': 'ローカルデータ'});
  String get exportData => _t({'en': 'Export Data', 'bg': 'Експорт на данни', 'de': 'Daten exportieren', 'fr': 'Exporter les données', 'it': 'Esporta dati', 'el': 'Εξαγωγή δεδομένων', 'es': 'Exportar datos', 'pt': 'Exportar dados', 'ru': 'Экспорт данных', 'tr': 'Verileri dışa aktar', 'ja': 'データをエクスポート'});
  String get exportDataDesc => _t({'en': 'Save tasks to file', 'bg': 'Запази задачите във файл', 'de': 'Aufgaben in Datei speichern', 'fr': 'Enregistrer les tâches dans un fichier', 'it': 'Salva attività su file', 'el': 'Αποθήκευση εργασιών σε αρχείο', 'es': 'Guardar tareas en archivo', 'pt': 'Salvar tarefas em arquivo', 'ru': 'Сохранить задачи в файл', 'tr': 'Görevleri dosyaya kaydet', 'ja': 'タスクをファイルに保存'});
  String get importData => _t({'en': 'Import Data', 'bg': 'Импорт на данни', 'de': 'Daten importieren', 'fr': 'Importer des données', 'it': 'Importa dati', 'el': 'Εισαγωγή δεδομένων', 'es': 'Importar datos', 'pt': 'Importar dados', 'ru': 'Импорт данных', 'tr': 'Verileri içe aktar', 'ja': 'データをインポート'});
  String get importDataDesc => _t({'en': 'Restore tasks from file', 'bg': 'Възстанови задачите от файл', 'de': 'Aufgaben aus Datei wiederherstellen', 'fr': 'Restaurer les tâches depuis un fichier', 'it': 'Ripristina attività da file', 'el': 'Επαναφορά εργασιών από αρχείο', 'es': 'Restaurar tareas desde archivo', 'pt': 'Restaurar tarefas de arquivo', 'ru': 'Восстановить задачи из файла', 'tr': 'Görevleri dosyadan geri yükle', 'ja': 'ファイルからタスクを復元'});
  String get tasksBackup => _t({'en': 'Tasks backup', 'bg': 'Backup на задачите', 'de': 'Aufgaben-Backup', 'fr': 'Sauvegarde des tâches', 'it': 'Backup attività', 'el': 'Αντίγραφο ασφαλείας εργασιών', 'es': 'Copia de seguridad de tareas', 'pt': 'Backup de tarefas', 'ru': 'Резервная копия задач', 'tr': 'Görev yedeği', 'ja': 'タスクのバックアップ'});

  // ==================== ДИАЛОЗИ И ПОТВЪРЖДЕНИЯ ====================
  String get confirmation => _t({'en': 'Confirmation', 'bg': 'Потвърждение', 'de': 'Bestätigung', 'fr': 'Confirmation', 'it': 'Conferma', 'el': 'Επιβεβαίωση', 'es': 'Confirmación', 'pt': 'Confirmação', 'ru': 'Подтверждение', 'tr': 'Onay', 'ja': '確認'});
  String get deleteConfirm => _t({'en': 'Are you sure you want to delete this?', 'bg': 'Сигурен ли си, че искаш да изтриеш?', 'de': 'Möchtest du das wirklich löschen?', 'fr': 'Êtes-vous sûr de vouloir supprimer?', 'it': 'Sei sicuro di voler eliminare?', 'el': 'Είστε σίγουροι ότι θέλετε να διαγράψετε;', 'es': '¿Estás seguro de que quieres eliminar?', 'pt': 'Tem certeza de que deseja excluir?', 'ru': 'Вы уверены, что хотите удалить?', 'tr': 'Silmek istediğinize emin misiniz?', 'ja': 'これを削除してもよろしいですか？'});
  String get deletion => _t({'en': 'Delete', 'bg': 'Изтриване', 'de': 'Löschen', 'fr': 'Supprimer', 'it': 'Eliminare', 'el': 'Διαγραφή', 'es': 'Eliminar', 'pt': 'Excluir', 'ru': 'Удаление', 'tr': 'Silme', 'ja': '削除'});

  // ==================== ГЛАС ====================
  String get listening => _t({'en': 'Listening...', 'bg': 'Слушам...', 'de': 'Höre zu...', 'fr': 'Écoute...', 'it': 'Ascolto...', 'el': 'Ακούω...', 'es': 'Escuchando...', 'pt': 'Ouvindo...', 'ru': 'Слушаю...', 'tr': 'Dinleniyor...', 'ja': '聞き取り中...'});
  String get speakNow => _t({'en': 'Speak now', 'bg': 'Говори сега', 'de': 'Jetzt sprechen', 'fr': 'Parlez maintenant', 'it': 'Parla ora', 'el': 'Μιλήστε τώρα', 'es': 'Habla ahora', 'pt': 'Fale agora', 'ru': 'Говорите', 'tr': 'Şimdi konuşun', 'ja': '今すぐ話してください'});

  // ==================== ГРЕШКИ ====================
  String get error => _t({'en': 'Error', 'bg': 'Грешка', 'de': 'Fehler', 'fr': 'Erreur', 'it': 'Errore', 'el': 'Σφάλμα', 'es': 'Error', 'pt': 'Erro', 'ru': 'Ошибка', 'tr': 'Hata', 'ja': 'エラー'});
  String get exportError => _t({'en': 'Export error', 'bg': 'Грешка при експорт', 'de': 'Exportfehler', 'fr': "Erreur d'exportation", 'it': 'Errore di esportazione', 'el': 'Σφάλμα εξαγωγής', 'es': 'Error de exportación', 'pt': 'Erro de exportação', 'ru': 'Ошибка экспорта', 'tr': 'Dışa aktarma hatası', 'ja': 'エクスポートエラー'});
  String get importError => _t({'en': 'Import error', 'bg': 'Грешка при импорт', 'de': 'Importfehler', 'fr': "Erreur d'importation", 'it': 'Errore di importazione', 'el': 'Σφάλμα εισαγωγής', 'es': 'Error de importación', 'pt': 'Erro de importação', 'ru': 'Ошибка импорта', 'tr': 'İçe aktarma hatası', 'ja': 'インポートエラー'});

  // ==================== ТЪРСЕНЕ ====================
  String get searchTasks => _t({'en': 'Search tasks', 'bg': 'Търсене в задачите', 'de': 'Aufgaben suchen', 'fr': 'Rechercher des tâches', 'it': 'Cerca attività', 'el': 'Αναζήτηση εργασιών', 'es': 'Buscar tareas', 'pt': 'Pesquisar tarefas', 'ru': 'Поиск задач', 'tr': 'Görev ara', 'ja': 'タスクを検索'});

  // ==================== ГЛАСОВО РАЗПОЗНАВАНЕ ====================
  String get speechNotAvailable => _t({'en': 'Speech recognition not available', 'bg': 'Гласовото разпознаване не е налично', 'de': 'Spracherkennung nicht verfügbar', 'fr': 'Reconnaissance vocale non disponible', 'it': 'Riconoscimento vocale non disponibile', 'el': 'Η αναγνώριση φωνής δεν είναι διαθέσιμη', 'es': 'Reconocimiento de voz no disponible', 'pt': 'Reconhecimento de voz não disponível', 'ru': 'Распознавание речи недоступно', 'tr': 'Ses tanıma kullanılamıyor', 'ja': '音声認識を利用できません'});

  // ==================== ДОПЪЛНИТЕЛНИ ====================
  String get deleteTaskConfirm => _t({'en': 'Delete this task?', 'bg': 'Изтриване на задачата?', 'de': 'Diese Aufgabe löschen?', 'fr': 'Supprimer cette tâche?', 'it': 'Eliminare questa attività?', 'el': 'Διαγραφή αυτής της εργασίας;', 'es': '¿Eliminar esta tarea?', 'pt': 'Excluir esta tarefa?', 'ru': 'Удалить эту задачу?', 'tr': 'Bu görevi sil?', 'ja': 'このタスクを削除しますか？'});
  String get deleteCategoryConfirm => _t({'en': 'Delete this category?', 'bg': 'Изтриване на категорията?', 'de': 'Diese Kategorie löschen?', 'fr': 'Supprimer cette catégorie?', 'it': 'Eliminare questa categoria?', 'el': 'Διαγραφή αυτής της κατηγορίας;', 'es': '¿Eliminar esta categoría?', 'pt': 'Excluir esta categoria?', 'ru': 'Удалить эту категорию?', 'tr': 'Bu kategoriyi sil?', 'ja': 'このカテゴリーを削除しますか？'});
  String get willDeleteTasks => _t({'en': 'This will also delete all tasks in this category', 'bg': 'Това ще изтрие и всички задачи в тази категория', 'de': 'Dies löscht auch alle Aufgaben in dieser Kategorie', 'fr': 'Cela supprimera également toutes les tâches de cette catégorie', 'it': 'Questo eliminerà anche tutte le attività in questa categoria', 'el': 'Αυτό θα διαγράψει επίσης όλες τις εργασίες σε αυτήν την κατηγορία', 'es': 'Esto también eliminará todas las tareas de esta categoría', 'pt': 'Isso também excluirá todas as tarefas nesta categoria', 'ru': 'Это также удалит все задачи в этой категории', 'tr': 'Bu, bu kategorideki tüm görevleri de siler', 'ja': 'このカテゴリー内のすべてのタスクも削除されます'});
  String get replaceLocalData => _t({'en': 'This will replace all local data', 'bg': 'Това ще замени всички локални данни', 'de': 'Dies ersetzt alle lokalen Daten', 'fr': 'Cela remplacera toutes les données locales', 'it': 'Questo sostituirà tutti i dati locali', 'el': 'Αυτό θα αντικαταστήσει όλα τα τοπικά δεδομένα', 'es': 'Esto reemplazará todos los datos locales', 'pt': 'Isso substituirá todos os dados locais', 'ru': 'Это заменит все локальные данные', 'tr': 'Bu, tüm yerel verilerin yerini alacak', 'ja': 'すべてのローカルデータが置き換えられます'});
  String get uploadConfirm => _t({'en': 'Upload tasks to cloud?', 'bg': 'Качване на задачите в облака?', 'de': 'Aufgaben in die Cloud hochladen?', 'fr': 'Télécharger les tâches vers le cloud?', 'it': 'Caricare le attività nel cloud?', 'el': 'Μεταφόρτωση εργασιών στο cloud;', 'es': '¿Subir tareas a la nube?', 'pt': 'Enviar tarefas para a nuvem?', 'ru': 'Загрузить задачи в облако?', 'tr': 'Görevler buluta yüklensin mi?', 'ja': 'タスクをクラウドにアップロードしますか？'});
  String get downloadConfirm => _t({'en': 'Download tasks from cloud?', 'bg': 'Сваляне на задачите от облака?', 'de': 'Aufgaben aus der Cloud herunterladen?', 'fr': 'Télécharger les tâches depuis le cloud?', 'it': 'Scaricare le attività dal cloud?', 'el': 'Λήψη εργασιών από το cloud;', 'es': '¿Descargar tareas de la nube?', 'pt': 'Baixar tarefas da nuvem?', 'ru': 'Скачать задачи из облака?', 'tr': 'Görevler buluttan indirilsin mi?', 'ja': 'クラウドからタスクをダウンロードしますか？'});

  // ==================== ДИНАМИЧНИ СЪОБЩЕНИЯ ====================
  String deleteTaskMessage(String title) => _t({
    'en': 'Are you sure you want to delete "$title"?',
    'bg': 'Сигурен ли си, че искаш да изтриеш "$title"?',
    'de': 'Möchtest du "$title" wirklich löschen?',
    'fr': 'Êtes-vous sûr de vouloir supprimer "$title"?',
    'it': 'Sei sicuro di voler eliminare "$title"?',
    'el': 'Είστε σίγουροι ότι θέλετε να διαγράψετε "$title";',
    'es': '¿Estás seguro de que quieres eliminar "$title"?',
    'pt': 'Tem certeza de que deseja excluir "$title"?',
    'ru': 'Вы уверены, что хотите удалить "$title"?',
    'tr': '"$title" silmek istediğinize emin misiniz?', 'ja': '「$title」を削除してもよろしいですか？',
  });

  String deleteCategoryMessage(String name) => _t({
    'en': 'Are you sure you want to delete "$name"?',
    'bg': 'Сигурен ли си, че искаш да изтриеш "$name"?',
    'de': 'Möchtest du "$name" wirklich löschen?',
    'fr': 'Êtes-vous sûr de vouloir supprimer "$name"?',
    'it': 'Sei sicuro di voler eliminare "$name"?',
    'el': 'Είστε σίγουροι ότι θέλετε να διαγράψετε "$name";',
    'es': '¿Estás seguro de que quieres eliminar "$name"?',
    'pt': 'Tem certeza de que deseja excluir "$name"?',
    'ru': 'Вы уверены, что хотите удалить "$name"?',
    'tr': '"$name" silmek istediğinize emin misiniz?', 'ja': '「$name」を削除してもよろしいですか？',
  });

  String importConfirmMessage(int tasks, int cats) => _t({
    'en': 'Will import $tasks tasks and $cats categories.\n\nThis will replace all current data. Continue?',
    'bg': 'Ще бъдат импортирани $tasks задачи и $cats категории.\n\nТова ще замени всички текущи данни. Продължи?',
    'de': 'Es werden $tasks Aufgaben und $cats Kategorien importiert.\n\nDies ersetzt alle aktuellen Daten. Fortfahren?',
    'fr': 'Importation de $tasks tâches et $cats catégories.\n\nCela remplacera toutes les données actuelles. Continuer?',
    'it': 'Verranno importate $tasks attività e $cats categorie.\n\nQuesto sostituirà tutti i dati attuali. Continuare?',
    'el': 'Θα εισαχθούν $tasks εργασίες και $cats κατηγορίες.\n\nΑυτό θα αντικαταστήσει όλα τα τρέχοντα δεδομένα. Συνέχεια;',
    'es': 'Se importarán $tasks tareas y $cats categorías.\n\nEsto reemplazará todos los datos actuales. ¿Continuar?',
    'pt': 'Serão importadas $tasks tarefas e $cats categorias.\n\nIsso substituirá todos os dados atuais. Continuar?',
    'ru': 'Будет импортировано $tasks задач и $cats категорий.\n\nЭто заменит все текущие данные. Продолжить?',
    'tr': '$tasks görev ve $cats kategori içe aktarılacak.\n\nBu, tüm mevcut verilerin yerini alacak. Devam edilsin mi?', 'ja': '$tasks件のタスクと$cats件のカテゴリーをインポートします。\n\n現在のすべてのデータが置き換えられます。続行しますか？',
  });

  String importSuccessMessage(int tasks, int cats) => _t({
    'en': 'Imported $tasks tasks and $cats categories',
    'bg': 'Импортирани $tasks задачи и $cats категории',
    'de': '$tasks Aufgaben und $cats Kategorien importiert',
    'fr': '$tasks tâches et $cats catégories importées',
    'it': 'Importate $tasks attività e $cats categorie',
    'el': 'Εισήχθησαν $tasks εργασίες και $cats κατηγορίες',
    'es': 'Importadas $tasks tareas y $cats categorías',
    'pt': 'Importadas $tasks tarefas e $cats categorias',
    'ru': 'Импортировано $tasks задач и $cats категорий',
    'tr': '$tasks görev ve $cats kategori içe aktarıldı', 'ja': '$tasks件のタスクと$cats件のカテゴリーをインポートしました',
  });

  String uploadConfirmMessage(int tasks, int cats) => _t({
    'en': 'Will upload $tasks tasks and $cats categories.\n\nThis will replace cloud data. Continue?',
    'bg': 'Ще бъдат качени $tasks задачи и $cats категории.\n\nТова ще замени данните в облака. Продължи?',
    'de': 'Es werden $tasks Aufgaben und $cats Kategorien hochgeladen.\n\nDies ersetzt die Cloud-Daten. Fortfahren?',
    'fr': 'Téléchargement de $tasks tâches et $cats catégories.\n\nCela remplacera les données cloud. Continuer?',
    'it': 'Verranno caricate $tasks attività e $cats categorie.\n\nQuesto sostituirà i dati cloud. Continuare?',
    'el': 'Θα μεταφορτωθούν $tasks εργασίες και $cats κατηγορίες.\n\nΑυτό θα αντικαταστήσει τα δεδομένα cloud. Συνέχεια;',
    'es': 'Se subirán $tasks tareas y $cats categorías.\n\nEsto reemplazará los datos en la nube. ¿Continuar?',
    'pt': 'Serão enviadas $tasks tarefas e $cats categorias.\n\nIsso substituirá os dados na nuvem. Continuar?',
    'ru': 'Будет загружено $tasks задач и $cats категорий.\n\nЭто заменит данные в облаке. Продолжить?',
    'tr': '$tasks görev ve $cats kategori yüklenecek.\n\nBu, bulut verilerinin yerini alacak. Devam edilsin mi?', 'ja': '$tasks件のタスクと$cats件のカテゴリーをアップロードします。\n\nクラウドのデータが置き換えられます。続行しますか？',
  });

  String uploadSuccessMessage(int tasks, int cats) => _t({
    'en': 'Uploaded $tasks tasks and $cats categories',
    'bg': 'Качени $tasks задачи и $cats категории',
    'de': '$tasks Aufgaben und $cats Kategorien hochgeladen',
    'fr': '$tasks tâches et $cats catégories téléchargées',
    'it': 'Caricate $tasks attività e $cats categorie',
    'el': 'Μεταφορτώθηκαν $tasks εργασίες και $cats κατηγορίες',
    'es': 'Subidas $tasks tareas y $cats categorías',
    'pt': 'Enviadas $tasks tarefas e $cats categorias',
    'ru': 'Загружено $tasks задач и $cats категорий',
    'tr': '$tasks görev ve $cats kategori yüklendi', 'ja': '$tasks件のタスクと$cats件のカテゴリーをアップロードしました',
  });

  String downloadConfirmMessage(int tasks, int cats) => _t({
    'en': 'Cloud has $tasks tasks and $cats categories.\n\nThis will replace local data. Continue?',
    'bg': 'В облака има $tasks задачи и $cats категории.\n\nТова ще замени локалните данни. Продължи?',
    'de': 'Cloud enthält $tasks Aufgaben und $cats Kategorien.\n\nDies ersetzt lokale Daten. Fortfahren?',
    'fr': 'Le cloud contient $tasks tâches et $cats catégories.\n\nCela remplacera les données locales. Continuer?',
    'it': 'Il cloud contiene $tasks attività e $cats categorie.\n\nQuesto sostituirà i dati locali. Continuare?',
    'el': 'Το cloud περιέχει $tasks εργασίες και $cats κατηγορίες.\n\nΑυτό θα αντικαταστήσει τα τοπικά δεδομένα. Συνέχεια;',
    'es': 'La nube tiene $tasks tareas y $cats categorías.\n\nEsto reemplazará los datos locales. ¿Continuar?',
    'pt': 'A nuvem tem $tasks tarefas e $cats categorias.\n\nIsso substituirá os dados locais. Continuar?',
    'ru': 'В облаке $tasks задач и $cats категорий.\n\nЭто заменит локальные данные. Продолжить?',
    'tr': 'Bulutta $tasks görev ve $cats kategori var.\n\nBu, yerel verilerin yerini alacak. Devam edilsin mi?', 'ja': 'クラウドには$tasks件のタスクと$cats件のカテゴリーがあります。\n\nローカルデータが置き換えられます。続行しますか？',
  });

  String downloadSuccessMessage(int tasks, int cats) => _t({
    'en': 'Downloaded $tasks tasks and $cats categories',
    'bg': 'Свалени $tasks задачи и $cats категории',
    'de': '$tasks Aufgaben und $cats Kategorien heruntergeladen',
    'fr': '$tasks tâches et $cats catégories téléchargées',
    'it': 'Scaricate $tasks attività e $cats categorie',
    'el': 'Λήφθηκαν $tasks εργασίες και $cats κατηγορίες',
    'es': 'Descargadas $tasks tareas y $cats categorías',
    'pt': 'Baixadas $tasks tarefas e $cats categorias',
    'ru': 'Скачано $tasks задач и $cats категорий',
    'tr': '$tasks görev ve $cats kategori indirildi', 'ja': '$tasks件のタスクと$cats件のカテゴリーをダウンロードしました',
  });

  String get signInToSync => _t({'en': 'Keep your tasks on all your devices', 'bg': 'Задачите ти на всичките ти устройства', 'de': 'Deine Aufgaben auf allen Geräten', 'fr': 'Vos tâches sur tous vos appareils', 'it': 'Le tue attività su tutti i dispositivi', 'el': 'Οι εργασίες σου σε όλες τις συσκευές', 'es': 'Tus tareas en todos tus dispositivos', 'pt': 'Suas tarefas em todos os dispositivos', 'ru': 'Задачи на всех ваших устройствах', 'tr': 'Görevlerin tüm cihazlarında', 'ja': 'すべての端末でタスクを共有'});
  String get saveToCloud => _t({'en': 'Save tasks to cloud', 'bg': 'Запази задачите в облака', 'de': 'Aufgaben in Cloud speichern', 'fr': 'Enregistrer les tâches dans le cloud', 'it': 'Salva attività nel cloud', 'el': 'Αποθήκευση εργασιών στο cloud', 'es': 'Guardar tareas en la nube', 'pt': 'Salvar tarefas na nuvem', 'ru': 'Сохранить задачи в облако', 'tr': 'Görevleri buluta kaydet', 'ja': 'タスクをクラウドに保存'});
  String get restoreFromCloud => _t({'en': 'Restore tasks from cloud', 'bg': 'Възстанови задачите от облака', 'de': 'Aufgaben aus Cloud wiederherstellen', 'fr': 'Restaurer les tâches depuis le cloud', 'it': 'Ripristina attività dal cloud', 'el': 'Επαναφορά εργασιών από cloud', 'es': 'Restaurar tareas de la nube', 'pt': 'Restaurar tarefas da nuvem', 'ru': 'Восстановить задачи из облака', 'tr': 'Görevleri buluttan geri yükle', 'ja': 'クラウドからタスクを復元'});
  String get saveToFile => _t({'en': 'Save tasks to file', 'bg': 'Запази задачите във файл', 'de': 'Aufgaben in Datei speichern', 'fr': 'Enregistrer les tâches dans un fichier', 'it': 'Salva attività su file', 'el': 'Αποθήκευση εργασιών σε αρχείο', 'es': 'Guardar tareas en archivo', 'pt': 'Salvar tarefas em arquivo', 'ru': 'Сохранить задачи в файл', 'tr': 'Görevleri dosyaya kaydet', 'ja': 'タスクをファイルに保存'});
  String get restoreFromFile => _t({'en': 'Restore tasks from file', 'bg': 'Възстанови задачите от файл', 'de': 'Aufgaben aus Datei wiederherstellen', 'fr': 'Restaurer les tâches depuis un fichier', 'it': 'Ripristina attività da file', 'el': 'Επαναφορά εργασιών από αρχείο', 'es': 'Restaurar tareas desde archivo', 'pt': 'Restaurar tarefas de arquivo', 'ru': 'Восстановить задачи из файла', 'tr': 'Görevleri dosyadan geri yükle', 'ja': 'ファイルからタスクを復元'});
  String get shareBackup => _t({'en': 'Save a copy of your tasks', 'bg': 'Запази копие на задачите си', 'de': 'Sichere eine Kopie deiner Aufgaben', 'fr': 'Enregistrez une copie de vos tâches', 'it': 'Salva una copia delle tue attività', 'el': 'Αποθήκευσε ένα αντίγραφο των εργασιών σου', 'es': 'Guarda una copia de tus tareas', 'pt': 'Salve uma cópia das suas tarefas', 'ru': 'Сохраните копию своих задач', 'tr': 'Görevlerinin bir kopyasını kaydet', 'ja': 'タスクのコピーを保存'});
  String get restoreFromJson => _t({'en': 'Restore your tasks from a saved copy', 'bg': 'Възстанови задачите от запазено копие', 'de': 'Stelle deine Aufgaben aus einer Sicherung wieder her', 'fr': 'Restaurez vos tâches depuis une copie enregistrée', 'it': 'Ripristina le tue attività da una copia salvata', 'el': 'Επανέφερε τις εργασίες σου από αποθηκευμένο αντίγραφο', 'es': 'Restaura tus tareas desde una copia guardada', 'pt': 'Restaure suas tarefas de uma cópia salva', 'ru': 'Восстановите задачи из сохранённой копии', 'tr': 'Görevlerini kayıtlı bir kopyadan geri yükle', 'ja': '保存したコピーからタスクを復元'});

  // ==================== СТАТИСТИКИ ====================
  String get summary => _t({'en': 'Summary', 'bg': 'Обобщение', 'de': 'Zusammenfassung', 'fr': 'Résumé', 'it': 'Riepilogo', 'el': 'Περίληψη', 'es': 'Resumen', 'pt': 'Resumo', 'ru': 'Сводка', 'tr': 'Özet', 'ja': '概要'});
  String get progress => _t({'en': 'Progress', 'bg': 'Прогрес', 'de': 'Fortschritt', 'fr': 'Progression', 'it': 'Progresso', 'el': 'Πρόοδος', 'es': 'Progreso', 'pt': 'Progresso', 'ru': 'Прогресс', 'tr': 'İlerleme', 'ja': '進捗'});
  String get completionRate => _t({'en': 'Completion rate', 'bg': 'Изпълнение', 'de': 'Abschlussrate', 'fr': 'Taux de réalisation', 'it': 'Tasso di completamento', 'el': 'Ποσοστό ολοκλήρωσης', 'es': 'Tasa de finalización', 'pt': 'Taxa de conclusão', 'ru': 'Процент выполнения', 'tr': 'Tamamlanma oranı', 'ja': '完了率'});
  String get tasksCompletedThisWeek => _t({'en': 'tasks completed\nthis week', 'bg': 'изпълнени\nтази седмица', 'de': 'Aufgaben erledigt\ndiese Woche', 'fr': 'tâches terminées\ncette semaine', 'it': 'attività completate\nquesta settimana', 'el': 'εργασίες\nαυτή την εβδομάδα', 'es': 'tareas completadas\nesta semana', 'pt': 'tarefas concluídas\nesta semana', 'ru': 'выполнено\nна этой неделе', 'tr': 'bu hafta\ntamamlandı', 'ja': '今週完了した\nタスク'});
  String get dayStreak => _t({'en': 'day streak', 'bg': 'дни streak', 'de': 'Tage Serie', 'fr': 'jours consécutifs', 'it': 'giorni consecutivi', 'el': 'ημέρες σερί', 'es': 'días seguidos', 'pt': 'dias seguidos', 'ru': 'дней подряд', 'tr': 'gün serisi', 'ja': '日連続'});
  String get mostProductive => _t({'en': 'most productive', 'bg': 'най-продуктивен', 'de': 'am produktivsten', 'fr': 'le plus productif', 'it': 'più produttivo', 'el': 'πιο παραγωγικός', 'es': 'más productivo', 'pt': 'mais produtivo', 'ru': 'самый продуктивный', 'tr': 'en verimli', 'ja': '最も生産的'});
  String get byCategory => _t({'en': 'By category', 'bg': 'По категории', 'de': 'Nach Kategorie', 'fr': 'Par catégorie', 'it': 'Per categoria', 'el': 'Ανά κατηγορία', 'es': 'Por categoría', 'pt': 'Por categoria', 'ru': 'По категориям', 'tr': 'Kategoriye göre', 'ja': 'カテゴリー別'});
  String get last7Days => _t({'en': 'Last 7 days', 'bg': 'Последните 7 дни', 'de': 'Letzte 7 Tage', 'fr': '7 derniers jours', 'it': 'Ultimi 7 giorni', 'el': 'Τελευταίες 7 ημέρες', 'es': 'Últimos 7 días', 'pt': 'Últimos 7 dias', 'ru': 'Последние 7 дней', 'tr': 'Son 7 gün', 'ja': '過去7日'});
  String get other => _t({'en': 'Other', 'bg': 'Друго', 'de': 'Andere', 'fr': 'Autre', 'it': 'Altro', 'el': 'Άλλο', 'es': 'Otro', 'pt': 'Outro', 'ru': 'Другое', 'tr': 'Diğer', 'ja': 'その他'});

  // Дни от седмицата (пълни)
  String dayName(int index) {
    const days = {
      'en': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
      'bg': ['Понеделник', 'Вторник', 'Сряда', 'Четвъртък', 'Петък', 'Събота', 'Неделя'],
      'de': ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'],
      'fr': ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'],
      'it': ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'],
      'el': ['Δευτέρα', 'Τρίτη', 'Τετάρτη', 'Πέμπτη', 'Παρασκευή', 'Σάββατο', 'Κυριακή'],
      'es': ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'],
      'pt': ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'],
      'ru': ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'],
      'tr': ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'],
    };
    return (days[lang] ?? days['en']!)[index];
  }

  // Кратки дни за графики
  String dayShort(int index) {
    const days = {
      'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      'bg': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'],
      'de': ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'],
      'fr': ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'],
      'it': ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'],
      'el': ['Δευ', 'Τρί', 'Τετ', 'Πέμ', 'Παρ', 'Σάβ', 'Κυρ'],
      'es': ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'],
      'pt': ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'],
      'ru': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
      'tr': ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'],
    };
    return (days[lang] ?? days['en']!)[index];
  }

  String tasksOfTotal(int completed, int total) => _t({
    'en': '$completed of $total tasks',
    'bg': '$completed от $total задачи',
    'de': '$completed von $total Aufgaben',
    'fr': '$completed sur $total tâches',
    'it': '$completed di $total attività',
    'el': '$completed από $total εργασίες',
    'es': '$completed de $total tareas',
    'pt': '$completed de $total tarefas',
    'ru': '$completed из $total задач',
    'tr': '$total görevden $completed', 'ja': '$completed / $total 件のタスク',
  });

  // ==================== TRIAL / PRO ====================
  String trialDaysLeft(int days) => _t({
    'en': 'Trial: $days days left',
    'bg': 'Пробен период: $days дни',
    'de': 'Testversion: $days Tage übrig',
    'fr': 'Essai: $days jours restants',
    'it': 'Prova: $days giorni rimasti',
    'el': 'Δοκιμή: $days ημέρες',
    'es': 'Prueba: $days días restantes',
    'pt': 'Teste: $days dias restantes',
    'ru': 'Пробный период: $days дней',
    'tr': 'Deneme: $days gün kaldı', 'ja': 'トライアル: 残り$days日',
  });

  String promoDaysLeft(int days) => _t({
    'en': 'Promo: $days days left',
    'bg': 'Промо код: $days дни',
    'de': 'Promo: $days Tage übrig',
    'fr': 'Promo: $days jours restants',
    'it': 'Promo: $days giorni rimasti',
    'el': 'Promo: $days ημέρες',
    'es': 'Promo: $days días restantes',
    'pt': 'Promo: $days dias restantes',
    'ru': 'Промо: $days дней',
    'tr': 'Promo: $days gün kaldı', 'ja': 'プロモ: 残り$days日',
  });

  String get upgrade => _t({
    'en': 'Upgrade',
    'bg': 'Надгради',
    'de': 'Upgraden',
    'fr': 'Améliorer',
    'it': 'Aggiorna',
    'el': 'Αναβάθμιση',
    'es': 'Mejorar',
    'pt': 'Atualizar',
    'ru': 'Улучшить',
    'tr': 'Yükselt', 'ja': 'アップグレード',
  });

  // ==================== GOOGLE CALENDAR ====================
  String get googleCalendar => _t({
    'en': 'Google Calendar',
    'bg': 'Google Календар',
    'de': 'Google Kalender',
    'fr': 'Google Agenda',
    'it': 'Google Calendar',
    'el': 'Ημερολόγιο Google',
    'es': 'Google Calendar',
    'pt': 'Google Agenda',
    'ru': 'Google Календарь',
    'tr': 'Google Takvim', 'ja': 'Google Calendar',
  });

  String get calendarConnected => _t({
    'en': 'Connected',
    'bg': 'Свързан',
    'de': 'Verbunden',
    'fr': 'Connecté',
    'it': 'Connesso',
    'el': 'Συνδεδεμένο',
    'es': 'Conectado',
    'pt': 'Conectado',
    'ru': 'Подключено',
    'tr': 'Bağlı', 'ja': '接続済み',
  });

  String get calendarNotConnected => _t({
    'en': 'Not connected',
    'bg': 'Не е свързан',
    'de': 'Nicht verbunden',
    'fr': 'Non connecté',
    'it': 'Non connesso',
    'el': 'Μη συνδεδεμένο',
    'es': 'No conectado',
    'pt': 'Não conectado',
    'ru': 'Не подключено',
    'tr': 'Bağlı değil', 'ja': '未接続',
  });

  String get calendarSyncEnabled => _t({
    'en': 'Your tasks and Google Calendar stay in sync',
    'bg': 'Задачите и Google Календар са винаги синхронизирани',
    'de': 'Deine Aufgaben und Google Kalender bleiben synchron',
    'fr': 'Vos tâches et Google Agenda restent synchronisés',
    'it': 'Le tue attività e Google Calendar restano sincronizzati',
    'el': 'Οι εργασίες σου και το Ημερολόγιο Google παραμένουν συγχρονισμένα',
    'es': 'Tus tareas y Google Calendar siempre sincronizados',
    'pt': 'Suas tarefas e o Google Agenda sempre sincronizados',
    'ru': 'Ваши задачи и Google Календарь всегда синхронны',
    'tr': 'Görevlerin ve Google Takvim hep senkron', 'ja': 'タスクとGoogleカレンダーが常に同期',
  });

  String get connectForSync => _t({
    'en': 'See your tasks and events together',
    'bg': 'Виж задачи и събития на едно място',
    'de': 'Aufgaben und Termine zusammen sehen',
    'fr': 'Voyez tâches et événements ensemble',
    'it': 'Vedi attività ed eventi insieme',
    'el': 'Δες εργασίες και γεγονότα μαζί',
    'es': 'Ve tus tareas y eventos juntos',
    'pt': 'Veja tarefas e eventos juntos',
    'ru': 'Задачи и события в одном месте',
    'tr': 'Görev ve etkinlikleri birlikte gör', 'ja': 'タスクと予定をまとめて表示',
  });

  String get calendarSource => _t({
    'en': 'Calendar sync',
    'bg': 'Синхронизация с календар',
    'de': 'Kalender-Synchronisierung',
    'fr': 'Synchronisation du calendrier',
    'it': 'Sincronizzazione calendario',
    'el': 'Συγχρονισμός ημερολογίου',
    'es': 'Sincronización del calendario',
    'pt': 'Sincronização do calendário',
    'ru': 'Синхронизация с календарём',
    'tr': 'Takvim senkronizasyonu', 'ja': 'カレンダー同期',
  });

  String get calendarSyncOff => _t({
    'en': 'Off',
    'bg': 'Изключена',
    'de': 'Aus',
    'fr': 'Désactivée',
    'it': 'Disattivata',
    'el': 'Ανενεργό',
    'es': 'Desactivada',
    'pt': 'Desativada',
    'ru': 'Выключена',
    'tr': 'Kapalı', 'ja': 'オフ',
  });

  String get appleCalendarSendOnly => _t({
    'en': 'Apple Calendar (send only)',
    'bg': 'Apple Calendar (само изпращане)',
    'de': 'Apple Kalender (nur senden)',
    'fr': 'Apple Calendrier (envoi seul)',
    'it': 'Apple Calendario (solo invio)',
    'el': 'Apple Ημερολόγιο (μόνο αποστολή)',
    'es': 'Apple Calendario (solo enviar)',
    'pt': 'Apple Calendário (apenas enviar)',
    'ru': 'Apple Календарь (только отправка)',
    'tr': 'Apple Takvim (yalnızca gönder)', 'ja': 'Apple Calendar（送信のみ）',
  });

  String get appleCalendarSendOnlyDesc => _t({
    'en': 'Sends your tasks to the calendar',
    'bg': 'Изпраща задачите ти в календара',
    'de': 'Sendet deine Aufgaben an den Kalender',
    'fr': 'Envoie vos tâches vers le calendrier',
    'it': 'Invia le tue attività al calendario',
    'el': 'Στέλνει τις εργασίες σου στο ημερολόγιο',
    'es': 'Envía tus tareas al calendario',
    'pt': 'Envia suas tarefas para o calendário',
    'ru': 'Отправляет ваши задачи в календарь',
    'tr': 'Görevlerini takvime gönderir', 'ja': 'タスクをカレンダーに送信します',
  });

  String get connect => _t({
    'en': 'Connect',
    'bg': 'Свържи',
    'de': 'Verbinden',
    'fr': 'Connecter',
    'it': 'Connetti',
    'el': 'Σύνδεση',
    'es': 'Conectar',
    'pt': 'Conectar',
    'ru': 'Подключить',
    'tr': 'Bağlan', 'ja': '接続',
  });

  String get disconnect => _t({
    'en': 'Disconnect',
    'bg': 'Прекъсни',
    'de': 'Trennen',
    'fr': 'Déconnecter',
    'it': 'Disconnetti',
    'el': 'Αποσύνδεση',
    'es': 'Desconectar',
    'pt': 'Desconectar',
    'ru': 'Отключить',
    'tr': 'Bağlantıyı kes', 'ja': '切断',
  });

  String get syncNow => _t({
    'en': 'Sync now',
    'bg': 'Синхронизирай',
    'de': 'Jetzt synchronisieren',
    'fr': 'Synchroniser',
    'it': 'Sincronizza ora',
    'el': 'Συγχρονισμός τώρα',
    'es': 'Sincronizar ahora',
    'pt': 'Sincronizar agora',
    'ru': 'Синхронизировать',
    'tr': 'Şimdi senkronize et', 'ja': '今すぐ同期',
  });

  String get autoSyncDesc => _t({
    'en': 'Updates automatically — tap to refresh now',
    'bg': 'Обновява се автоматично — натисни за обновяване',
    'de': 'Aktualisiert automatisch — zum Aktualisieren tippen',
    'fr': 'Mise à jour automatique — touchez pour actualiser',
    'it': 'Si aggiorna da solo — tocca per aggiornare',
    'el': 'Ενημερώνεται αυτόματα — πάτησε για ανανέωση',
    'es': 'Se actualiza solo — toca para actualizar',
    'pt': 'Atualiza sozinho — toque para atualizar',
    'ru': 'Обновляется автоматически — нажмите, чтобы обновить',
    'tr': 'Otomatik güncellenir — yenilemek için dokun',
    'ja': '自動更新 — タップで今すぐ更新',
  });

  String get resetSync => _t({
    'en': 'Reset sync (wipe cloud + local)',
    'bg': 'Нулирай синхронизацията (изтрий облак + локално)',
    'de': 'Sync zurücksetzen (Cloud + lokal löschen)',
    'fr': 'Réinitialiser la sync (cloud + local)',
    'it': 'Reimposta sync (cloud + locale)',
    'el': 'Επαναφορά συγχρονισμού (cloud + τοπικά)',
    'es': 'Restablecer sync (nube + local)',
    'pt': 'Redefinir sync (nuvem + local)',
    'ru': 'Сбросить синхронизацию (облако + локально)',
    'tr': 'Senkronizasyonu sıfırla (bulut + yerel)',
    'ja': '同期をリセット（クラウド＋ローカル削除）',
  });

  String get resetSyncDesc => _t({
    'en': 'Erases all tasks, then restore from a backup. Use only if something broke.',
    'bg': 'Изтрива всички задачи; после възстановяваш от бекъп. Само при проблем.',
    'de': 'Löscht alle Aufgaben; danach aus einem Backup wiederherstellen. Nur im Notfall.',
    'fr': 'Efface toutes les tâches, puis restaurez depuis une sauvegarde. En cas de problème seulement.',
    'it': 'Cancella tutte le attività; poi ripristina da un backup. Solo in caso di problemi.',
    'el': 'Σβήνει όλες τις εργασίες· μετά κάνεις επαναφορά από αντίγραφο. Μόνο σε πρόβλημα.',
    'es': 'Borra todas las tareas; luego restaura desde una copia. Solo si algo falló.',
    'pt': 'Apaga todas as tarefas; depois restaura de um backup. Só em caso de problema.',
    'ru': 'Удаляет все задачи; затем восстановите из копии. Только при проблеме.',
    'tr': 'Tüm görevleri siler; sonra bir yedekten geri yükle. Yalnızca sorun olduğunda.',
    'ja': 'すべてのタスクを削除し、バックアップから復元します。問題時のみ使用。',
  });

  String get resetSyncConfirm => _t({
    'en': 'This deletes ALL tasks from the cloud AND this device. Continue?',
    'bg': 'Това изтрива ВСИЧКИ задачи от облака И от това устройство. Да продължа?',
    'de': 'Dies löscht ALLE Aufgaben aus der Cloud UND von diesem Gerät. Fortfahren?',
    'fr': 'Ceci supprime TOUTES les tâches du cloud ET de cet appareil. Continuer?',
    'it': 'Questo elimina TUTTE le attività dal cloud E da questo dispositivo. Continuare?',
    'el': 'Αυτό διαγράφει ΟΛΕΣ τις εργασίες από το cloud ΚΑΙ από αυτή τη συσκευή. Συνέχεια;',
    'es': 'Esto elimina TODAS las tareas de la nube Y de este dispositivo. ¿Continuar?',
    'pt': 'Isto apaga TODAS as tarefas da nuvem E deste dispositivo. Continuar?',
    'ru': 'Это удалит ВСЕ задачи из облака И с этого устройства. Продолжить?',
    'tr': 'Bu, TÜM görevleri buluttan VE bu cihazdan siler. Devam edilsin mi?',
    'ja': 'クラウドとこの端末からすべてのタスクを削除します。続行しますか？',
  });

  String resetSyncDone(int count) => _t({
    'en': 'Wiped $count cloud tasks. Now import from your clean backup.',
    'bg': 'Изтрити $count облачни задачи. Сега импортирай от чистия бекъп.',
    'de': '$count Cloud-Aufgaben gelöscht. Jetzt aus sauberem Backup importieren.',
    'fr': '$count tâches cloud supprimées. Importez depuis votre sauvegarde propre.',
    'it': '$count attività cloud eliminate. Ora importa dal backup pulito.',
    'el': 'Διαγράφηκαν $count εργασίες cloud. Τώρα κάνε εισαγωγή από καθαρό αντίγραφο.',
    'es': '$count tareas en la nube eliminadas. Ahora importa desde tu copia limpia.',
    'pt': '$count tarefas na nuvem apagadas. Agora importa do backup limpo.',
    'ru': 'Удалено $count облачных задач. Теперь импортируй из чистой копии.',
    'tr': '$count bulut görevi silindi. Şimdi temiz yedekten içe aktar.',
    'ja': 'クラウドの$count件のタスクを削除しました。クリーンなバックアップからインポートしてください。',
  });

  String get allowCalendarAccess => _t({
    'en': 'Allow calendar access',
    'bg': 'Разреши достъп до календара',
    'de': 'Kalenderzugriff erlauben',
    'fr': 'Autoriser l\'accès au calendrier',
    'it': 'Consenti accesso al calendario',
    'el': 'Επίτρεψε πρόσβαση στο ημερολόγιο',
    'es': 'Permitir acceso al calendario',
    'pt': 'Permitir acesso ao calendário',
    'ru': 'Разрешить доступ к календарю',
    'tr': 'Takvim erişimine izin ver',
    'ja': 'カレンダーへのアクセスを許可',
  });

  String get allowCalendarAccessDesc => _t({
    'en': 'Signed in — tap to allow calendar access',
    'bg': 'Влязохте — натиснете за достъп до календара',
    'de': 'Angemeldet — für Kalenderzugriff tippen',
    'fr': 'Connecté — touchez pour autoriser le calendrier',
    'it': 'Accesso effettuato — tocca per il calendario',
    'el': 'Συνδεθήκατε — πατήστε για πρόσβαση στο ημερολόγιο',
    'es': 'Sesión iniciada — toca para el calendario',
    'pt': 'Sessão iniciada — toque para o calendário',
    'ru': 'Вы вошли — нажмите для доступа к календарю',
    'tr': 'Giriş yapıldı — takvim erişimi için dokun',
    'ja': 'サインイン済み — タップでカレンダーへのアクセスを許可',
  });

  String get connectionFailed => _t({
    'en': 'Connection failed',
    'bg': 'Неуспешно свързване',
    'de': 'Verbindung fehlgeschlagen',
    'fr': 'Échec de la connexion',
    'it': 'Connessione fallita',
    'el': 'Η σύνδεση απέτυχε',
    'es': 'Error de conexión',
    'pt': 'Falha na conexão',
    'ru': 'Ошибка подключения',
    'tr': 'Bağlantı başarısız', 'ja': '接続に失敗しました',
  });

  String tasksSynced(int count) => _t({
    'en': '$count tasks synced',
    'bg': '$count задачи синхронизирани',
    'de': '$count Aufgaben synchronisiert',
    'fr': '$count tâches synchronisées',
    'it': '$count attività sincronizzate',
    'el': '$count εργασίες συγχρονίστηκαν',
    'es': '$count tareas sincronizadas',
    'pt': '$count tarefas sincronizadas',
    'ru': '$count задач синхронизировано',
    'tr': '$count görev senkronize edildi', 'ja': '$count 件のタスクを同期しました',
  });

  String get syncFromCalendar => _t({
    'en': 'Sync from Calendar',
    'bg': 'Синхронизирай от Calendar',
    'de': 'Vom Kalender sync',
    'fr': 'Sync depuis Calendar',
    'it': 'Sincronizza da Calendar',
    'el': 'Συγχρονισμός από Calendar',
    'es': 'Sincronizar desde Calendar',
    'pt': 'Sincronizar do Calendar',
    'ru': 'Синхронизировать из Calendar',
    'tr': 'Calendar\'dan senkronize et', 'ja': 'カレンダーから同期',
  });

  String tasksUpdated(int count) => _t({
    'en': '$count tasks updated',
    'bg': '$count задачи обновени',
    'de': '$count Aufgaben aktualisiert',
    'fr': '$count tâches mises à jour',
    'it': '$count attività aggiornate',
    'el': '$count εργασίες ενημερώθηκαν',
    'es': '$count tareas actualizadas',
    'pt': '$count tarefas atualizadas',
    'ru': '$count задач обновлено',
    'tr': '$count görev güncellendi', 'ja': '$count 件のタスクを更新しました',
  });

  String get importFromCalendar => _t({
    'en': 'Import from Calendar',
    'bg': 'Импортирай от Calendar',
    'de': 'Vom Kalender importieren',
    'fr': 'Importer du Calendar',
    'it': 'Importa da Calendar',
    'el': 'Εισαγωγή από Calendar',
    'es': 'Importar desde Calendar',
    'pt': 'Importar do Calendar',
    'ru': 'Импорт из Calendar',
    'tr': 'Calendar\'dan içe aktar', 'ja': 'カレンダーからインポート',
  });

  String eventsImported(int count) => _t({
    'en': '$count events imported',
    'bg': '$count събития импортирани',
    'de': '$count Ereignisse importiert',
    'fr': '$count événements importés',
    'it': '$count eventi importati',
    'el': '$count εκδηλώσεις εισάχθηκαν',
    'es': '$count eventos importados',
    'pt': '$count eventos importados',
    'ru': '$count событий импортировано',
    'tr': '$count etkinlik içe aktarıldı', 'ja': '$count 件のイベントをインポートしました',
  });
  String get goodMorning => _t({
    'en': 'Good Morning! 🌅',
    'bg': 'Добро утро! 🌅',
    'de': 'Guten Morgen! 🌅',
    'fr': 'Bonjour! 🌅',
    'it': 'Buongiorno! 🌅',
    'el': 'Καλημέρα! 🌅',
    'es': '¡Buenos días! 🌅',
    'pt': 'Bom dia! 🌅',
    'ru': 'Доброе утро! 🌅',
    'tr': 'Günaydın! 🌅', 'ja': 'おはようございます！🌅',
  });

  String get noTasksToday => _t({
    'en': 'No tasks for today! ✨',
    'bg': 'Няма задачи за днес! ✨',
    'de': 'Keine Aufgaben heute! ✨',
    'fr': "Pas de tâches aujourd'hui! ✨",
    'it': 'Nessuna attività oggi! ✨',
    'el': 'Δεν υπάρχουν εργασίες σήμερα! ✨',
    'es': '¡Sin tareas hoy! ✨',
    'pt': 'Sem tarefas hoje! ✨',
    'ru': 'Нет задач на сегодня! ✨',
    'tr': 'Bugün görev yok! ✨', 'ja': '今日のタスクはありません！✨',
  });

  String get enjoyYourDay => _t({
    'en': 'Enjoy your day!',
    'bg': 'Приятен ден!',
    'de': 'Genieß deinen Tag!',
    'fr': 'Profitez de votre journée!',
    'it': 'Goditi la giornata!',
    'el': 'Απολαύστε την ημέρα σας!',
    'es': '¡Que tengas un buen día!',
    'pt': 'Aproveite o seu dia!',
    'ru': 'Хорошего дня!',
    'tr': 'İyi günler!', 'ja': '良い一日を！',
  });

  String get morningBriefing => _t({'en': 'Morning Briefing', 'bg': 'Сутрешен преглед', 'de': 'Morgenübersicht', 'fr': 'Résumé du matin', 'it': 'Riepilogo mattutino', 'el': 'Πρωινή ενημέρωση', 'es': 'Resumen matutino', 'pt': 'Resumo matinal', 'ru': 'Утренний обзор', 'tr': 'Sabah özeti', 'ja': '朝のブリーフィング'});
  String get briefingTime => _t({'en': 'Briefing Time', 'bg': 'Час на прегледа', 'de': 'Übersichtszeit', 'fr': 'Heure du résumé', 'it': 'Orario riepilogo', 'el': 'Ώρα ενημέρωσης', 'es': 'Hora del resumen', 'pt': 'Hora do resumo', 'ru': 'Время обзора', 'tr': 'Özet saati', 'ja': 'ブリーフィングの時刻'});
  String dailyTaskSummaryAt(String time) => _t({'en': 'Daily task summary at $time', 'bg': 'Дневен преглед на задачите в $time', 'de': 'Tägliche Aufgabenübersicht um $time', 'fr': 'Résumé quotidien à $time', 'it': 'Riepilogo giornaliero alle $time', 'el': 'Ημερήσια σύνοψη εργασιών στις $time', 'es': 'Resumen diario a las $time', 'pt': 'Resumo diário às $time', 'ru': 'Ежедневный обзор задач в $time', 'tr': 'Günlük görev özeti saat $time', 'ja': '$timeに毎日のタスク概要'});
  String briefingTimeSetTo(String time) => _t({'en': 'Briefing time set to $time', 'bg': 'Часът на прегледа е зададен на $time', 'de': 'Übersichtszeit auf $time gesetzt', 'fr': 'Heure du résumé réglée à $time', 'it': 'Orario riepilogo impostato alle $time', 'el': 'Ώρα ενημέρωσης ορίστηκε στις $time', 'es': 'Hora del resumen establecida a las $time', 'pt': 'Hora do resumo definida para $time', 'ru': 'Время обзора установлено на $time', 'tr': 'Özet saati $time olarak ayarlandı', 'ja': 'ブリーフィングの時刻を$timeに設定しました'});
  String get googleTasks => _t({'en': 'Google Tasks', 'bg': 'Google Задачи', 'de': 'Google Aufgaben', 'fr': 'Google Tasks', 'it': 'Google Tasks', 'el': 'Google Tasks', 'es': 'Google Tasks', 'pt': 'Google Tasks', 'ru': 'Google Задачи', 'tr': 'Google Görevler', 'ja': 'Google Tasks'});
  String get deleteAllCalendarTasks => _t({'en': 'Delete All Calendar Tasks', 'bg': 'Изтрий всички календарни задачи', 'de': 'Alle Kalenderaufgaben löschen', 'fr': 'Supprimer toutes les tâches du calendrier', 'it': 'Elimina tutte le attività del calendario', 'el': 'Διαγραφή όλων των εργασιών ημερολογίου', 'es': 'Eliminar todas las tareas del calendario', 'pt': 'Excluir todas as tarefas do calendário', 'ru': 'Удалить все задачи из календаря', 'tr': 'Tüm takvim görevlerini sil', 'ja': 'カレンダーのタスクをすべて削除'});
  String get deleteCalendarTasksConfirm => _t({'en': 'This will delete all tasks imported from Google Calendar. This action cannot be undone.', 'bg': 'Това ще изтрие всички задачи, импортирани от Google Calendar. Действието е необратимо.', 'de': 'Dies löscht alle aus Google Kalender importierten Aufgaben. Diese Aktion kann nicht rückgängig gemacht werden.', 'fr': 'Cela supprimera toutes les tâches importées de Google Agenda. Cette action est irréversible.', 'it': 'Questo eliminerà tutte le attività importate da Google Calendar. Questa azione non può essere annullata.', 'el': 'Αυτό θα διαγράψει όλες τις εργασίες που εισήχθησαν από το Ημερολόγιο Google. Αυτή η ενέργεια δεν μπορεί να αναιρεθεί.', 'es': 'Esto eliminará todas las tareas importadas de Google Calendar. Esta acción no se puede deshacer.', 'pt': 'Isso excluirá todas as tarefas importadas do Google Agenda. Esta ação não pode ser desfeita.', 'ru': 'Это удалит все задачи, импортированные из Google Календаря. Это действие нельзя отменить.', 'tr': 'Bu, Google Takvimden içe aktarılan tüm görevleri silecektir. Bu işlem geri alınamaz.', 'ja': 'Google Calendarからインポートしたすべてのタスクが削除されます。この操作は取り消せません。'});

  String get goodAfternoon => _t({'en': 'Good Afternoon! ☀️', 'bg': 'Добър ден! ☀️', 'de': 'Guten Tag! ☀️', 'fr': 'Bon après-midi! ☀️', 'it': 'Buon pomeriggio! ☀️', 'el': 'Καλό απόγευμα! ☀️', 'es': '¡Buenas tardes! ☀️', 'pt': 'Boa tarde! ☀️', 'ru': 'Добрый день! ☀️', 'tr': 'İyi öğleden sonralar! ☀️', 'ja': 'こんにちは！☀️'});
  String get goodEvening => _t({'en': 'Good Evening! 🌙', 'bg': 'Добър вечер! 🌙', 'de': 'Guten Abend! 🌙', 'fr': 'Bonsoir! 🌙', 'it': 'Buonasera! 🌙', 'el': 'Καλό βράδυ! 🌙', 'es': '¡Buenas noches! 🌙', 'pt': 'Boa noite! 🌙', 'ru': 'Добрый вечер! 🌙', 'tr': 'İyi akşamlar! 🌙', 'ja': 'こんばんは！🌙'});
  String get totalItems => _t({
    'en': 'Total items',
    'bg': 'Общо артикули',
    'de': 'Artikel insgesamt',
    'fr': 'Articles au total',
    'it': 'Articoli totali',
    'el': 'Σύνολο αντικειμένων',
    'es': 'Artículos totales',
    'pt': 'Total de itens',
    'ru': 'Всего товаров',
    'tr': 'Toplam ürün', 'ja': '項目の合計',
  });

  String get purchased => _t({
    'en': 'Purchased',
    'bg': 'Купени',
    'de': 'Gekauft',
    'fr': 'Achetés',
    'it': 'Acquistati',
    'el': 'Αγορασμένα',
    'es': 'Comprados',
    'pt': 'Comprados',
    'ru': 'Куплено',
    'tr': 'Satın alındı', 'ja': '購入済み',
  });
  String get taskTemplate => _t({
    'en': 'Template',
    'bg': 'Шаблон',
    'de': 'Vorlage',
    'fr': 'Modèle',
    'it': 'Modello',
    'el': 'Πρότυπο',
    'es': 'Plantilla',
    'pt': 'Modelo',
    'ru': 'Шаблон',
    'tr': 'Şablon', 'ja': 'テンプレート',
  });

  String get templateNone => _t({
    'en': 'None',
    'bg': 'Няма',
    'de': 'Keine',
    'fr': 'Aucun',
    'it': 'Nessuno',
    'el': 'Κανένα',
    'es': 'Ninguno',
    'pt': 'Nenhum',
    'ru': 'Нет',
    'tr': 'Yok', 'ja': 'なし',
  });

  String get templateShopping => _t({
    'en': 'Shopping List',
    'bg': 'Списък за пазаруване',
    'de': 'Einkaufsliste',
    'fr': 'Liste de courses',
    'it': 'Lista della spesa',
    'el': 'Λίστα αγορών',
    'es': 'Lista de compras',
    'pt': 'Lista de compras',
    'ru': 'Список покупок',
    'tr': 'Alışveriş listesi', 'ja': '買い物リスト',
  });



  String greetingForHour(int hour) {
    if (hour >= 5 && hour < 12) return goodMorning;
    if (hour >= 12 && hour < 18) return goodAfternoon;
    return goodEvening;
  }

  // Calendar import/export strings
  String get removeAllImported => _t({'en': 'Remove all imported events', 'bg': 'Премахни всички импортирани събития', 'de': 'Alle importierten Ereignisse entfernen', 'fr': 'Supprimer tous les événements importés', 'it': 'Rimuovi tutti gli eventi importati', 'el': 'Αφαίρεση όλων των εισαγόμενων γεγονότων', 'es': 'Eliminar todos los eventos importados', 'pt': 'Remover todos os eventos importados', 'ru': 'Удалить все импортированные события', 'tr': 'Tüm içe aktarılan etkinlikleri kaldır', 'ja': 'インポートしたイベントをすべて削除'});
  String importedSkipped(int imported, int skipped) => _t({'en': 'Imported: $imported, Skipped: $skipped', 'bg': 'Импортирани: $imported, Пропуснати: $skipped', 'de': 'Importiert: $imported, Übersprungen: $skipped', 'fr': 'Importés: $imported, Ignorés: $skipped', 'it': 'Importati: $imported, Saltati: $skipped', 'el': 'Εισαγωγή: $imported, Παράλειψη: $skipped', 'es': 'Importados: $imported, Omitidos: $skipped', 'pt': 'Importados: $imported, Ignorados: $skipped', 'ru': 'Импортировано: $imported, Пропущено: $skipped', 'tr': 'İçe aktarılan: $imported, Atlanan: $skipped', 'ja': 'インポート: $imported、スキップ: $skipped'});
  String deletedCalendarTasks(int count) => _t({'en': 'Deleted $count calendar tasks', 'bg': 'Изтрити $count календарни задачи', 'de': '$count Kalenderaufgaben gelöscht', 'fr': '$count tâches du calendrier supprimées', 'it': '$count attività del calendario eliminate', 'el': 'Διαγράφηκαν $count εργασίες ημερολογίου', 'es': '$count tareas del calendario eliminadas', 'pt': '$count tarefas do calendário excluídas', 'ru': 'Удалено задач из календаря: $count', 'tr': '$count takvim görevi silindi', 'ja': '$count件のカレンダータスクを削除しました'});

  // Calendar — ясни 4 действия (експорт / импорт / изтрий импортнати / изтрий експортнати)
  String get exportToCalendar => _t({'en': 'Export to calendar', 'bg': 'Експортирай в календара', 'de': 'In Kalender exportieren', 'fr': 'Exporter vers le calendrier', 'it': 'Esporta nel calendario', 'el': 'Εξαγωγή στο ημερολόγιο', 'es': 'Exportar al calendario', 'pt': 'Exportar para o calendário', 'ru': 'Экспорт в календарь', 'tr': 'Takvime aktar', 'ja': 'カレンダーにエクスポート'});
  String get exportToCalendarDesc => _t({'en': 'Adds your active tasks to the calendar', 'bg': 'Добавя активните ти задачи в календара', 'de': 'Fügt deine aktiven Aufgaben zum Kalender hinzu', 'fr': 'Ajoute vos tâches actives au calendrier', 'it': 'Aggiunge le tue attività attive al calendario', 'el': 'Προσθέτει τις ενεργές εργασίες σου στο ημερολόγιο', 'es': 'Añade tus tareas activas al calendario', 'pt': 'Adiciona suas tarefas ativas ao calendário', 'ru': 'Добавляет ваши активные задачи в календарь', 'tr': 'Aktif görevlerinizi takvime ekler', 'ja': '有効なタスクをカレンダーに追加します'});
  String get importFromCalendarDesc => _t({'en': 'Imports calendar events as tasks', 'bg': 'Внася събитията от календара като задачи', 'de': 'Importiert Kalenderereignisse als Aufgaben', 'fr': 'Importe les événements du calendrier comme tâches', 'it': 'Importa gli eventi del calendario come attività', 'el': 'Εισάγει τα γεγονότα του ημερολογίου ως εργασίες', 'es': 'Importa los eventos del calendario como tareas', 'pt': 'Importa os eventos do calendário como tarefas', 'ru': 'Импортирует события календаря как задачи', 'tr': 'Takvim etkinliklerini görev olarak içe aktarır', 'ja': 'カレンダーの予定をタスクとして取り込みます'});
  String get deleteImportedTasks => _t({'en': 'Delete imported tasks', 'bg': 'Изтрий импортираните задачи', 'de': 'Importierte Aufgaben löschen', 'fr': 'Supprimer les tâches importées', 'it': 'Elimina le attività importate', 'el': 'Διαγραφή εισαγόμενων εργασιών', 'es': 'Eliminar tareas importadas', 'pt': 'Excluir tarefas importadas', 'ru': 'Удалить импортированные задачи', 'tr': 'İçe aktarılan görevleri sil', 'ja': 'インポートしたタスクを削除'});
  String get deleteImportedDesc => _t({'en': 'Removes tasks imported from the calendar (keeps the calendar events)', 'bg': 'Маха задачите, внесени от календара (събитията в календара остават)', 'de': 'Entfernt aus dem Kalender importierte Aufgaben (Kalenderereignisse bleiben)', 'fr': 'Supprime les tâches importées du calendrier (les événements restent)', 'it': "Rimuove le attività importate dal calendario (gli eventi restano)", 'el': 'Αφαιρεί τις εργασίες που εισήχθησαν από το ημερολόγιο (τα γεγονότα παραμένουν)', 'es': 'Elimina las tareas importadas del calendario (los eventos permanecen)', 'pt': 'Remove as tarefas importadas do calendário (os eventos permanecem)', 'ru': 'Удаляет задачи, импортированные из календаря (события остаются)', 'tr': 'Takvimden içe aktarılan görevleri kaldırır (etkinlikler kalır)', 'ja': 'カレンダーから取り込んだタスクを削除します（予定は残ります）'});
  String get deleteExportedTasks => _t({'en': 'Delete exported events', 'bg': 'Изтрий експортираните събития', 'de': 'Exportierte Ereignisse löschen', 'fr': 'Supprimer les événements exportés', 'it': 'Elimina gli eventi esportati', 'el': 'Διαγραφή εξαγόμενων γεγονότων', 'es': 'Eliminar eventos exportados', 'pt': 'Excluir eventos exportados', 'ru': 'Удалить экспортированные события', 'tr': 'Dışa aktarılan etkinlikleri sil', 'ja': 'エクスポートした予定を削除'});
  String get deleteExportedDesc => _t({'en': 'Removes events this app added to the calendar (keeps your tasks)', 'bg': 'Маха събитията, които приложението добави в календара (задачите остават)', 'de': 'Entfernt Ereignisse, die diese App zum Kalender hinzugefügt hat (Aufgaben bleiben)', 'fr': "Supprime les événements que l'app a ajoutés au calendrier (vos tâches restent)", 'it': "Rimuove gli eventi aggiunti dall'app al calendario (le attività restano)", 'el': 'Αφαιρεί τα γεγονότα που πρόσθεσε η εφαρμογή στο ημερολόγιο (οι εργασίες παραμένουν)', 'es': 'Elimina los eventos que la app añadió al calendario (tus tareas permanecen)', 'pt': 'Remove os eventos que o app adicionou ao calendário (suas tarefas permanecem)', 'ru': 'Удаляет события, добавленные приложением в календарь (задачи остаются)', 'tr': 'Uygulamanın takvime eklediği etkinlikleri kaldırır (görevleriniz kalır)', 'ja': 'アプリがカレンダーに追加した予定を削除します（タスクは残ります）'});
  String get deleteExportedConfirm => _t({'en': 'This will remove from the calendar all events that were exported from your tasks. Your tasks will stay in the app.', 'bg': 'Това ще премахне от календара всички събития, експортирани от твоите задачи. Задачите остават в приложението.', 'de': 'Dies entfernt aus dem Kalender alle aus deinen Aufgaben exportierten Ereignisse. Deine Aufgaben bleiben in der App.', 'fr': 'Cela supprimera du calendrier tous les événements exportés depuis vos tâches. Vos tâches restent dans l\'app.', 'it': 'Questo rimuoverà dal calendario tutti gli eventi esportati dalle tue attività. Le tue attività restano nell\'app.', 'el': 'Αυτό θα αφαιρέσει από το ημερολόγιο όλα τα γεγονότα που εξήχθησαν από τις εργασίες σου. Οι εργασίες σου παραμένουν στην εφαρμογή.', 'es': 'Esto eliminará del calendario todos los eventos exportados desde tus tareas. Tus tareas permanecerán en la app.', 'pt': 'Isso removerá do calendário todos os eventos exportados das suas tarefas. Suas tarefas permanecem no app.', 'ru': 'Это удалит из календаря все события, экспортированные из ваших задач. Ваши задачи останутся в приложении.', 'tr': 'Bu, görevlerinizden dışa aktarılan tüm etkinlikleri takvimden kaldıracaktır. Görevleriniz uygulamada kalır.', 'ja': 'タスクからエクスポートしたすべての予定をカレンダーから削除します。タスクはアプリに残ります。'});
  String deletedExportedTasks(int count) => _t({'en': 'Removed $count events from the calendar', 'bg': 'Премахнати $count събития от календара', 'de': '$count Ereignisse aus dem Kalender entfernt', 'fr': '$count événements supprimés du calendrier', 'it': '$count eventi rimossi dal calendario', 'el': 'Αφαιρέθηκαν $count γεγονότα από το ημερολόγιο', 'es': '$count eventos eliminados del calendario', 'pt': '$count eventos removidos do calendário', 'ru': 'Удалено $count событий из календаря', 'tr': 'Takvimden $count etkinlik kaldırıldı', 'ja': 'カレンダーから$count件の予定を削除しました'});
  String get removeDuplicates => _t({'en': 'Remove duplicates', 'bg': 'Премахни дубликати', 'de': 'Duplikate entfernen', 'fr': 'Supprimer les doublons', 'it': 'Rimuovi duplicati', 'el': 'Αφαίρεση διπλότυπων', 'es': 'Eliminar duplicados', 'pt': 'Remover duplicados', 'ru': 'Удалить дубликаты', 'tr': 'Yinelenenleri kaldır', 'ja': '重複を削除'});
  String get removeDuplicatesDesc => _t({'en': 'Tidies up repeated events — keeps just one of each', 'bg': 'Изчиства повтарящи се събития — оставя по едно', 'de': 'Räumt doppelte Termine auf — behält je eines', 'fr': 'Nettoie les événements en double — n\'en garde qu\'un', 'it': 'Pulisce gli eventi ripetuti — ne tiene uno solo', 'el': 'Καθαρίζει διπλά γεγονότα — κρατά ένα από κάθε', 'es': 'Limpia eventos repetidos — conserva solo uno', 'pt': 'Limpa eventos repetidos — mantém só um', 'ru': 'Убирает повторяющиеся события — оставляет по одному', 'tr': 'Tekrar eden etkinlikleri temizler — birer tane bırakır', 'ja': '重複した予定を整理 — 各1件だけ残します'});
  String removedDuplicates(int count) => _t({'en': 'Removed $count duplicate events', 'bg': 'Премахнати $count дублирани събития', 'de': '$count doppelte Ereignisse entfernt', 'fr': '$count événements en double supprimés', 'it': '$count eventi duplicati rimossi', 'el': 'Αφαιρέθηκαν $count διπλότυπα γεγονότα', 'es': '$count eventos duplicados eliminados', 'pt': '$count eventos duplicados removidos', 'ru': 'Удалено $count дублированных событий', 'tr': '$count yinelenen etkinlik kaldırıldı', 'ja': '$count件の重複予定を削除しました'});

  String get duplicatesInSyncedCalendar => _t({
    'en': 'Duplicates are in a synced (read-only) calendar — remove them from its source',
    'bg': 'Дублите са в синхронизиран календар (само за четене) — изтрий ги от източника му',
    'de': 'Duplikate liegen in einem synchronisierten (schreibgeschützten) Kalender — entferne sie an der Quelle',
    'fr': 'Les doublons sont dans un calendrier synchronisé (lecture seule) — supprimez-les à la source',
    'it': 'I duplicati sono in un calendario sincronizzato (sola lettura) — rimuovili dalla fonte',
    'el': 'Τα διπλότυπα είναι σε συγχρονισμένο (μόνο για ανάγνωση) ημερολόγιο — αφαίρεσέ τα από την πηγή',
    'es': 'Los duplicados están en un calendario sincronizado (solo lectura) — elimínalos desde su origen',
    'pt': 'Os duplicados estão num calendário sincronizado (só leitura) — remova-os na origem',
    'ru': 'Дубликаты в синхронизированном (только для чтения) календаре — удалите их в источнике',
    'tr': 'Yinelemeler senkronize (salt okunur) takvimde — kaynağından kaldırın', 'ja': '重複は同期された（読み取り専用）カレンダーにあります — 元の場所で削除してください',
  });
  String get untitledEvent => _t({'en': 'Untitled Event', 'bg': 'Без заглавие', 'de': 'Unbenanntes Ereignis', 'fr': 'Événement sans titre', 'it': 'Evento senza titolo', 'el': 'Χωρίς τίτλο', 'es': 'Evento sin título', 'pt': 'Evento sem título', 'ru': 'Без названия', 'tr': 'Adsız etkinlik', 'ja': '無題のイベント'});
  String get untitledTask => _t({'en': 'Untitled Task', 'bg': 'Без заглавие', 'de': 'Unbenannte Aufgabe', 'fr': 'Tâche sans titre', 'it': 'Attività senza titolo', 'el': 'Χωρίς τίτλο', 'es': 'Tarea sin título', 'pt': 'Tarefa sem título', 'ru': 'Без названия', 'tr': 'Adsız görev', 'ja': '無題のタスク'});
  String get backupSubject => _t({'en': 'Taskify Backup', 'bg': 'Taskify Архив', 'de': 'Taskify Sicherung', 'fr': 'Sauvegarde Taskify', 'it': 'Backup Taskify', 'el': 'Αντίγραφο Taskify', 'es': 'Copia de Taskify', 'pt': 'Backup Taskify', 'ru': 'Резервная копия Taskify', 'tr': 'Taskify Yedek', 'ja': 'Taskifyバックアップ'});
  String get catWork => _t({'en': 'Work', 'bg': 'Работа', 'de': 'Arbeit', 'fr': 'Travail', 'it': 'Lavoro', 'el': 'Εργασία', 'es': 'Trabajo', 'pt': 'Trabalho', 'ru': 'Работа', 'tr': 'İş', 'ja': '仕事'});
  String get catPersonal => _t({'en': 'Personal', 'bg': 'Лични', 'de': 'Persönlich', 'fr': 'Personnel', 'it': 'Personale', 'el': 'Προσωπικά', 'es': 'Personal', 'pt': 'Pessoal', 'ru': 'Личное', 'tr': 'Kişisel', 'ja': '個人'});
  String get catShopping => _t({'en': 'Shopping', 'bg': 'Пазаруване', 'de': 'Einkaufen', 'fr': 'Courses', 'it': 'Acquisti', 'el': 'Αγορές', 'es': 'Compras', 'pt': 'Compras', 'ru': 'Покупки', 'tr': 'Alışveriş', 'ja': '買い物'});
  String get catBirthdays => _t({'en': 'Birthdays', 'bg': 'Рождени дни', 'de': 'Geburtstage', 'fr': 'Anniversaires', 'it': 'Compleanni', 'el': 'Γενέθλια', 'es': 'Cumpleaños', 'pt': 'Aniversários', 'ru': 'Дни рождения', 'tr': 'Doğum günleri', 'ja': '誕生日'});
  String get catOutOfOffice => _t({'en': 'Out of Office', 'bg': 'Извън офиса', 'de': 'Außer Haus', 'fr': 'Hors du bureau', 'it': 'Fuori ufficio', 'el': 'Εκτός γραφείου', 'es': 'Fuera de la oficina', 'pt': 'Fora do escritório', 'ru': 'Вне офиса', 'tr': 'Ofis dışında', 'ja': '外出中'});
  String get catFocusTime => _t({'en': 'Focus Time', 'bg': 'Фокус', 'de': 'Fokuszeit', 'fr': 'Temps de concentration', 'it': 'Tempo di concentrazione', 'el': 'Χρόνος εστίασης', 'es': 'Tiempo de enfoque', 'pt': 'Tempo de foco', 'ru': 'Время фокуса', 'tr': 'Odaklanma zamanı', 'ja': '集中タイム'});
  String get catWorkLocation => _t({'en': 'Work Location', 'bg': 'Работно място', 'de': 'Arbeitsort', 'fr': 'Lieu de travail', 'it': 'Luogo di lavoro', 'el': 'Τοποθεσία εργασίας', 'es': 'Ubicación de trabajo', 'pt': 'Local de trabalho', 'ru': 'Место работы', 'tr': 'Çalışma yeri', 'ja': '勤務地'});
  String get catCalendarEvents => _t({'en': 'Calendar Events', 'bg': 'Календарни събития', 'de': 'Kalendereinträge', 'fr': 'Événements du calendrier', 'it': 'Eventi del calendario', 'el': 'Εκδηλώσεις ημερολογίου', 'es': 'Eventos del calendario', 'pt': 'Eventos do calendário', 'ru': 'События календаря', 'tr': 'Takvim etkinlikleri', 'ja': 'カレンダーのイベント'});
  // Default category names
  // Notification fallbacks
  String get reminderFallback => _t({'en': 'Reminder', 'bg': 'Напомняне', 'de': 'Erinnerung', 'fr': 'Rappel', 'it': 'Promemoria', 'el': 'Υπενθύμιση', 'es': 'Recordatorio', 'pt': 'Lembrete', 'ru': 'Напоминание', 'tr': 'Hatırlatıcı', 'ja': 'リマインダー'});
  String get taskDueFallback => _t({'en': 'You have a task to complete', 'bg': 'Имаш задача за изпълнение', 'de': 'Du hast eine Aufgabe zu erledigen', 'fr': 'Vous avez une tâche à accomplir', 'it': 'Hai un\'attività da completare', 'el': 'Έχετε μια εργασία να ολοκληρώσετε', 'es': 'Tienes una tarea por completar', 'pt': 'Você tem uma tarefa para concluir', 'ru': 'У вас есть задача для выполнения', 'tr': 'Tamamlamanız gereken bir görev var', 'ja': '完了すべきタスクがあります'});


  String get newEntry => _t({'en': 'New Entry', 'bg': 'Нов запис', 'de': 'Neuer Eintrag', 'fr': 'Nouvelle entrée', 'it': 'Nuova voce', 'el': 'Νέα εγγραφή', 'es': 'Nueva entrada', 'pt': 'Nova entrada', 'ru': 'Новая запись', 'tr': 'Yeni kayıt', 'ja': '新しい項目'});
  String get typeTask => _t({'en': 'Task', 'bg': 'Задача', 'de': 'Aufgabe', 'fr': 'Tâche', 'it': 'Attività', 'el': 'Εργασία', 'es': 'Tarea', 'pt': 'Tarefa', 'ru': 'Задача', 'tr': 'Görev', 'ja': 'タスク'});
  String get typeShopping => _t({'en': 'Shopping', 'bg': 'Пазаруване', 'de': 'Einkaufen', 'fr': 'Courses', 'it': 'Spesa', 'el': 'Αγορές', 'es': 'Compras', 'pt': 'Compras', 'ru': 'Покупки', 'tr': 'Alışveriş', 'ja': '買い物'});
  String get typeBirthday => _t({'en': 'Birthday', 'bg': 'Рожден ден', 'de': 'Geburtstag', 'fr': 'Anniversaire', 'it': 'Compleanno', 'el': 'Γενέθλια', 'es': 'Cumpleaños', 'pt': 'Aniversário', 'ru': 'День рождения', 'tr': 'Doğum günü', 'ja': '誕生日'});
  String get typeMeeting => _t({'en': 'Meeting', 'bg': 'Среща', 'de': 'Treffen', 'fr': 'Réunion', 'it': 'Incontro', 'el': 'Συνάντηση', 'es': 'Reunión', 'pt': 'Reunião', 'ru': 'Встреча', 'tr': 'Toplantı', 'ja': '会議'});
  String get typeWorkout => _t({'en': 'Workout', 'bg': 'Тренировка', 'de': 'Training', 'fr': 'Entraînement', 'it': 'Allenamento', 'el': 'Γυμναστική', 'es': 'Ejercicio', 'pt': 'Treino', 'ru': 'Тренировка', 'tr': 'Egzersiz', 'ja': 'ワークアウト'});
  String get typePayment => _t({'en': 'Payment', 'bg': 'Плащане', 'de': 'Zahlung', 'fr': 'Paiement', 'it': 'Pagamento', 'el': 'Πληρωμή', 'es': 'Pago', 'pt': 'Pagamento', 'ru': 'Платёж', 'tr': 'Ödeme', 'ja': '支払い'});
  String get typeTravel => _t({'en': 'Travel', 'bg': 'Пътуване', 'de': 'Reise', 'fr': 'Voyage', 'it': 'Viaggio', 'el': 'Ταξίδι', 'es': 'Viaje', 'pt': 'Viagem', 'ru': 'Путешествие', 'tr': 'Seyahat', 'ja': '旅行'});
  String get typeGift => _t({'en': 'Gift', 'bg': 'Подарък', 'de': 'Geschenk', 'fr': 'Cadeau', 'it': 'Regalo', 'el': 'Δώρο', 'es': 'Regalo', 'pt': 'Presente', 'ru': 'Подарок', 'tr': 'Hediye', 'ja': 'ギフト'});
  String get typeDocument => _t({'en': 'Document', 'bg': 'Документ', 'de': 'Dokument', 'fr': 'Document', 'it': 'Documento', 'el': 'Έγγραφο', 'es': 'Documento', 'pt': 'Documento', 'ru': 'Документ', 'tr': 'Belge', 'ja': '書類'});
  // Режими Уча — учебни типове задачи
  String get typeHomework => _t({'en': 'Homework', 'bg': 'Домашно', 'de': 'Hausaufgabe', 'fr': 'Devoir', 'it': 'Compiti', 'el': 'Εργασία για το σπίτι', 'es': 'Deberes', 'pt': 'Trabalho de casa', 'ru': 'Домашнее задание', 'tr': 'Ödev', 'ja': '宿題'});
  String get typeEssay => _t({'en': 'Essay', 'bg': 'Есе', 'de': 'Aufsatz', 'fr': 'Dissertation', 'it': 'Saggio', 'el': 'Δοκίμιο', 'es': 'Ensayo', 'pt': 'Ensaio', 'ru': 'Эссе', 'tr': 'Deneme', 'ja': 'エッセイ'});
  String get typeCoursework => _t({'en': 'Coursework', 'bg': 'Курсова работа', 'de': 'Hausarbeit', 'fr': 'Travail de cours', 'it': 'Tesina', 'el': 'Εργασία εξαμήνου', 'es': 'Trabajo de curso', 'pt': 'Trabalho de curso', 'ru': 'Курсовая работа', 'tr': 'Dönem ödevi', 'ja': 'コースワーク'});

  // ==================== ДОКУМЕНТИ (изтичащ срок) ====================
  String get documents => _t({'en': 'Documents', 'bg': 'Документи', 'de': 'Dokumente', 'fr': 'Documents', 'it': 'Documenti', 'el': 'Έγγραφα', 'es': 'Documentos', 'pt': 'Documentos', 'ru': 'Документы', 'tr': 'Belgeler', 'ja': '書類'});
  String get catDocuments => _t({'en': 'Documents', 'bg': 'Документи', 'de': 'Dokumente', 'fr': 'Documents', 'it': 'Documenti', 'el': 'Έγγραφα', 'es': 'Documentos', 'pt': 'Documentos', 'ru': 'Документы', 'tr': 'Belgeler', 'ja': '書類'});
  String get addDocument => _t({'en': 'Add Document', 'bg': 'Добави документ', 'de': 'Dokument hinzufügen', 'fr': 'Ajouter un document', 'it': 'Aggiungi documento', 'el': 'Προσθήκη εγγράφου', 'es': 'Añadir documento', 'pt': 'Adicionar documento', 'ru': 'Добавить документ', 'tr': 'Belge ekle', 'ja': '書類を追加'});
  String get editDocument => _t({'en': 'Edit Document', 'bg': 'Редакция на документ', 'de': 'Dokument bearbeiten', 'fr': 'Modifier le document', 'it': 'Modifica documento', 'el': 'Επεξεργασία εγγράφου', 'es': 'Editar documento', 'pt': 'Editar documento', 'ru': 'Редактировать документ', 'tr': 'Belgeyi düzenle', 'ja': '書類を編集'});
  String get documentType => _t({'en': 'Document type', 'bg': 'Вид документ', 'de': 'Dokumenttyp', 'fr': 'Type de document', 'it': 'Tipo di documento', 'el': 'Τύπος εγγράφου', 'es': 'Tipo de documento', 'pt': 'Tipo de documento', 'ru': 'Тип документа', 'tr': 'Belge türü', 'ja': '書類の種類'});
  String get documentExpiry => _t({'en': 'Expiry date', 'bg': 'Срок на изтичане', 'de': 'Ablaufdatum', 'fr': "Date d'expiration", 'it': 'Data di scadenza', 'el': 'Ημερομηνία λήξης', 'es': 'Fecha de caducidad', 'pt': 'Data de validade', 'ru': 'Срок действия', 'tr': 'Son geçerlilik tarihi', 'ja': '有効期限'});
  String get documentNameHint => _t({'en': 'Name (optional)', 'bg': 'Име (по избор)', 'de': 'Name (optional)', 'fr': 'Nom (facultatif)', 'it': 'Nome (facoltativo)', 'el': 'Όνομα (προαιρετικό)', 'es': 'Nombre (opcional)', 'pt': 'Nome (opcional)', 'ru': 'Название (необязательно)', 'tr': 'Ad (isteğe bağlı)', 'ja': '名前（任意）'});
  String get documentAnnual => _t({'en': 'Renews every year', 'bg': 'Подновява се всяка година', 'de': 'Jährliche Verlängerung', 'fr': 'Renouvellement annuel', 'it': 'Si rinnova ogni anno', 'el': 'Ανανεώνεται κάθε χρόνο', 'es': 'Se renueva cada año', 'pt': 'Renova-se todos os anos', 'ru': 'Продлевается ежегодно', 'tr': 'Her yıl yenilenir', 'ja': '毎年更新'});
  String get documentsEmpty => _t({'en': 'Track documents that expire — ID, passport, license, insurance, inspection. Add your first to get reminders before it runs out.', 'bg': 'Следи документи с изтичащ срок — лична карта, паспорт, книжка, застраховка, тех. преглед. Добави първия и ще те подсещам преди да изтече.', 'de': 'Verfolge ablaufende Dokumente — Ausweis, Pass, Führerschein, Versicherung, Prüfung. Füge das erste hinzu für rechtzeitige Erinnerungen.', 'fr': 'Suis les documents qui expirent — pièce d’identité, passeport, permis, assurance, contrôle. Ajoute le premier pour être prévenu à temps.', 'it': 'Tieni traccia dei documenti in scadenza — carta d’identità, passaporto, patente, assicurazione, revisione. Aggiungi il primo per i promemoria.', 'el': 'Παρακολούθησε έγγραφα που λήγουν — ταυτότητα, διαβατήριο, δίπλωμα, ασφάλεια, έλεγχος. Πρόσθεσε το πρώτο για υπενθυμίσεις.', 'es': 'Controla documentos que caducan — DNI, pasaporte, carnet, seguro, inspección. Añade el primero para recibir avisos a tiempo.', 'pt': 'Acompanha documentos que expiram — identidade, passaporte, carta, seguro, inspeção. Adiciona o primeiro para receberes lembretes.', 'ru': 'Следи за документами с истекающим сроком — паспорт, удостоверение, права, страховка, техосмотр. Добавь первый и получай напоминания.', 'tr': 'Süresi dolan belgeleri takip et — kimlik, pasaport, ehliyet, sigorta, muayene. İlkini ekle, zamanında hatırlatalım.', 'ja': '期限切れになる書類を管理 — 身分証、パスポート、免許、保険、車検。最初の1件を追加するとリマインドします。'});


  String get jan => _t({'en': 'Jan', 'bg': 'ян', 'de': 'Jan', 'fr': 'jan', 'it': 'gen', 'el': 'Ιαν', 'es': 'ene', 'pt': 'jan', 'ru': 'янв', 'tr': 'Oca', 'ja': '1月'});
  String get feb => _t({'en': 'Feb', 'bg': 'фев', 'de': 'Feb', 'fr': 'fév', 'it': 'feb', 'el': 'Φεβ', 'es': 'feb', 'pt': 'fev', 'ru': 'фев', 'tr': 'Şub', 'ja': '2月'});
  String get mar => _t({'en': 'Mar', 'bg': 'мар', 'de': 'Mär', 'fr': 'mar', 'it': 'mar', 'el': 'Μαρ', 'es': 'mar', 'pt': 'mar', 'ru': 'мар', 'tr': 'Mar', 'ja': '3月'});
  String get apr => _t({'en': 'Apr', 'bg': 'апр', 'de': 'Apr', 'fr': 'avr', 'it': 'apr', 'el': 'Απρ', 'es': 'abr', 'pt': 'abr', 'ru': 'апр', 'tr': 'Nis', 'ja': '4月'});
  String get jun => _t({'en': 'Jun', 'bg': 'юн', 'de': 'Jun', 'fr': 'jun', 'it': 'giu', 'el': 'Ιουν', 'es': 'jun', 'pt': 'jun', 'ru': 'июн', 'tr': 'Haz', 'ja': '6月'});
  String get jul => _t({'en': 'Jul', 'bg': 'юл', 'de': 'Jul', 'fr': 'jul', 'it': 'lug', 'el': 'Ιουλ', 'es': 'jul', 'pt': 'jul', 'ru': 'июл', 'tr': 'Tem', 'ja': '7月'});
  String get aug => _t({'en': 'Aug', 'bg': 'авг', 'de': 'Aug', 'fr': 'aoû', 'it': 'ago', 'el': 'Αυγ', 'es': 'ago', 'pt': 'ago', 'ru': 'авг', 'tr': 'Ağu', 'ja': '8月'});
  String get sep => _t({'en': 'Sep', 'bg': 'сеп', 'de': 'Sep', 'fr': 'sep', 'it': 'set', 'el': 'Σεπ', 'es': 'sep', 'pt': 'set', 'ru': 'сен', 'tr': 'Eyl', 'ja': '9月'});
  String get oct => _t({'en': 'Oct', 'bg': 'окт', 'de': 'Okt', 'fr': 'oct', 'it': 'ott', 'el': 'Οκτ', 'es': 'oct', 'pt': 'out', 'ru': 'окт', 'tr': 'Eki', 'ja': '10月'});
  String get nov => _t({'en': 'Nov', 'bg': 'ное', 'de': 'Nov', 'fr': 'nov', 'it': 'nov', 'el': 'Νοε', 'es': 'nov', 'pt': 'nov', 'ru': 'ноя', 'tr': 'Kas', 'ja': '11月'});
  String get dec => _t({'en': 'Dec', 'bg': 'дек', 'de': 'Dez', 'fr': 'déc', 'it': 'dic', 'el': 'Δεκ', 'es': 'dic', 'pt': 'dez', 'ru': 'дек', 'tr': 'Ara', 'ja': '12月'});
  String get addBirthday => _t({'en': 'Add Birthday', 'bg': 'Добави рожден ден', 'de': 'Geburtstag hinzufügen', 'fr': 'Ajouter anniversaire', 'it': 'Aggiungi compleanno', 'el': 'Προσθήκη γενεθλίων', 'es': 'Añadir cumpleaños', 'pt': 'Adicionar aniversário', 'ru': 'Добавить день рождения', 'tr': 'Doğum günü ekle', 'ja': '誕生日を追加'});
  String get editBirthday => _t({'en': 'Edit Birthday', 'bg': 'Редакция', 'de': 'Bearbeiten', 'fr': 'Modifier', 'it': 'Modifica', 'el': 'Επεξεργασία', 'es': 'Editar', 'pt': 'Editar', 'ru': 'Редактировать', 'tr': 'Düzenle', 'ja': '誕生日を編集'});
  String get birthdayDate => _t({'en': 'Birthday date', 'bg': 'Дата на рождения ден', 'de': 'Geburtsdatum', 'fr': 'Date d\'anniversaire', 'it': 'Data di nascita', 'el': 'Ημερομηνία γενεθλίων', 'es': 'Fecha de cumpleaños', 'pt': 'Data de aniversário', 'ru': 'Дата рождения', 'tr': 'Doğum tarihi', 'ja': '誕生日の日付'});
  String get birthdayNameHint => _t({'en': 'e.g. Maria', 'bg': 'напр. Мария', 'de': 'z.B. Maria', 'fr': 'ex. Maria', 'it': 'es. Maria', 'el': 'π.χ. Μαρία', 'es': 'ej. María', 'pt': 'ex. Maria', 'ru': 'напр. Мария', 'tr': 'ör. Maria', 'ja': '例: マリア'});
  String get birthYear => _t({'en': 'Birth year', 'bg': 'Година на раждане', 'de': 'Geburtsjahr', 'fr': 'Année de naissance', 'it': 'Anno di nascita', 'el': 'Έτος γέννησης', 'es': 'Año de nacimiento', 'pt': 'Ano de nascimento', 'ru': 'Год рождения', 'tr': 'Doğum yılı', 'ja': '生まれた年'});
  String get birthYearHint => _t({'en': 'e.g. 1990', 'bg': 'напр. 1990', 'de': 'z.B. 1990', 'fr': 'ex. 1990', 'it': 'es. 1990', 'el': 'π.χ. 1990', 'es': 'ej. 1990', 'pt': 'ex. 1990', 'ru': 'напр. 1990', 'tr': 'ör. 1990', 'ja': '例: 1990'});
  String get onDay => _t({'en': 'On the day', 'bg': 'На деня', 'de': 'Am Tag', 'fr': 'Le jour même', 'it': 'Il giorno', 'el': 'Ην ημέρα', 'es': 'El día', 'pt': 'No dia', 'ru': 'В день', 'tr': 'Günü', 'ja': '当日'});
  String get oneDayBefore => _t({'en': '1 day before', 'bg': '1 ден преди', 'de': '1 Tag vorher', 'fr': '1 jour avant', 'it': '1 giorno prima', 'el': '1 μέρα πριν', 'es': '1 día antes', 'pt': '1 dia antes', 'ru': 'За 1 день', 'tr': '1 gün önce', 'ja': '1日前'});
  String get oneWeekBefore => _t({'en': '1 week before', 'bg': '1 седмица преди', 'de': '1 Woche vorher', 'fr': '1 semaine avant', 'it': '1 settimana prima', 'el': '1 εβδομάδα πριν', 'es': '1 semana antes', 'pt': '1 semana antes', 'ru': 'За 1 неделю', 'tr': '1 hafta önce', 'ja': '1週間前'});
  String get optional => _t({'en': 'optional', 'bg': 'незадължително', 'de': 'optional', 'fr': 'facultatif', 'it': 'facoltativo', 'el': 'πραιρετικό', 'es': 'opcional', 'pt': 'opcional', 'ru': 'необязательно', 'tr': 'isteğe bağlı', 'ja': '任意'});
  String turnsAge(int age) => _t({'en': 'turns $age', 'bg': 'става $age', 'de': 'wird $age', 'fr': 'aura $age ans', 'it': 'compie $age', 'el': 'γίνεται $age', 'es': 'cumple $age', 'pt': 'completa $age', 'ru': 'исполняется $age', 'tr': '$age yaşına giriyor', 'ja': '$age歳になります'});


  String get sameDayMorning => _t({'en': 'Same day at 8:00', 'bg': 'Същия ден в 8:00', 'de': 'Am selben Tag um 8:00', 'fr': 'Le même jour à 8h00', 'it': 'Lo stesso giorno alle 8:00', 'el': 'Την ίδια μέρα στις 8:00', 'es': 'El mismo día a las 8:00', 'pt': 'No mesmo dia às 8:00', 'ru': 'В тот же день в 8:00', 'tr': 'Aynı gün saat 8:00', 'ja': '当日の8:00'});


  String get catMeeting => _t({'en': 'Meetings', 'bg': 'Срещи', 'de': 'Treffen', 'fr': 'Réunions', 'it': 'Incontri', 'el': 'Συναντήσεις', 'es': 'Reuniones', 'pt': 'Reuniões', 'ru': 'Встречи', 'tr': 'Toplantılar', 'ja': '会議'});
  String get catWorkout => _t({'en': 'Workouts', 'bg': 'Тренировки', 'de': 'Training', 'fr': 'Entraînements', 'it': 'Allenamenti', 'el': 'Γυμναστική', 'es': 'Ejercicios', 'pt': 'Treinos', 'ru': 'Тренировки', 'tr': 'Antrenmanlar', 'ja': 'ワークアウト'});
  String get catPayment => _t({'en': 'Payments', 'bg': 'Плащания', 'de': 'Zahlungen', 'fr': 'Paiements', 'it': 'Pagamenti', 'el': 'Πληρωμές', 'es': 'Pagos', 'pt': 'Pagamentos', 'ru': 'Платежи', 'tr': 'Ödemeler', 'ja': '支払い'});
  String get catTravel => _t({'en': 'Travel', 'bg': 'Пътувания', 'de': 'Reisen', 'fr': 'Voyages', 'it': 'Viaggi', 'el': 'Ταξίδια', 'es': 'Viajes', 'pt': 'Viagens', 'ru': 'Путешествия', 'tr': 'Seyahatler', 'ja': '旅行'});
  String get catGift => _t({'en': 'Gifts', 'bg': 'Подаръци', 'de': 'Geschenke', 'fr': 'Cadeaux', 'it': 'Regali', 'el': 'Δώρα', 'es': 'Regalos', 'pt': 'Presentes', 'ru': 'Подарки', 'tr': 'Hediyeler', 'ja': 'ギフト'});

  String get addMeeting => _t({'en': 'Add Meeting', 'bg': 'Добави среща', 'de': 'Treffen hinzufügen', 'fr': 'Ajouter réunion', 'it': 'Aggiungi incontro', 'el': 'Προσθήκη συνάντησης', 'es': 'Añadir reunión', 'pt': 'Adicionar reunião', 'ru': 'Добавить встречу', 'tr': 'Toplantı ekle', 'ja': '会議を追加'});

  String get editMeeting => _t({'en': 'Edit Meeting', 'bg': 'Редакция на среща', 'de': 'Treffen bearbeiten', 'fr': 'Modifier réunion', 'it': 'Modifica incontro', 'el': 'Επεξεργασία συνάντησης', 'es': 'Editar reunión', 'pt': 'Editar reunião', 'ru': 'Редактировать', 'tr': 'Toplantıyı düzenle', 'ja': '会議を編集'});

  String get meetingWith => _t({'en': 'With who', 'bg': 'С кого', 'de': 'Mit wem', 'fr': 'Avec qui', 'it': 'Con chi', 'el': 'Με ποιον', 'es': 'Con quién', 'pt': 'Com quem', 'ru': 'С кем', 'tr': 'Kiminle', 'ja': '同行者'});

  String get meetingWithHint => _t({'en': 'e.g. Ivan', 'bg': 'напр. Иван', 'de': 'z.B. Ivan', 'fr': 'ex. Ivan', 'it': 'es. Ivan', 'el': 'π.χ. Ιβαν', 'es': 'ej. Ivan', 'pt': 'ex. Ivan', 'ru': 'напр. Иван', 'tr': 'ör. Ivan', 'ja': '例: イワン'});

  String get meetingPlace => _t({'en': 'Place', 'bg': 'Място', 'de': 'Ort', 'fr': 'Lieu', 'it': 'Luogo', 'el': 'Τόπος', 'es': 'Lugar', 'pt': 'Local', 'ru': 'Место', 'tr': 'Yer', 'ja': '場所'});

  String get meetingPlaceHint => _t({'en': 'e.g. Office', 'bg': 'напр. Офис', 'de': 'z.B. Büro', 'fr': 'ex. Bureau', 'it': 'es. Ufficio', 'el': 'π.χ. Γραφείο', 'es': 'ej. Oficina', 'pt': 'ex. Escritório', 'ru': 'напр. Офис', 'tr': 'ör. Ofis', 'ja': '例: オフィス'});

  String get atTime => _t({'en': 'At time', 'bg': 'В часа', 'de': 'Zur Zeit', 'fr': 'A l\'heure', 'it': 'All\'ora', 'el': 'Στην ώρα', 'es': 'A la hora', 'pt': 'Na hora', 'ru': 'В время', 'tr': 'Saatinde', 'ja': '指定時刻に'});

  String get minus15m => _t({'en': '15 min before', 'bg': '15 мин. преди', 'de': '15 Min. vorher', 'fr': '15 min avant', 'it': '15 min prima', 'el': '15 λεπτά πριν', 'es': '15 min antes', 'pt': '15 min antes', 'ru': 'За 15 мин.', 'tr': '15 dk önce', 'ja': '15分前'});

  String get minus1h => _t({'en': '1 hour before', 'bg': '1 час преди', 'de': '1 Std. vorher', 'fr': '1 heure avant', 'it': '1 ora prima', 'el': '1 ώρα πριν', 'es': '1 hora antes', 'pt': '1 hora antes', 'ru': 'За 1 час', 'tr': '1 saat önce', 'ja': '1時間前'});

  String meetingTitle(String name) => _t({'en': 'Meeting with $name', 'bg': 'Среща с $name', 'de': 'Treffen mit $name', 'fr': 'Réunion avec $name', 'it': 'Incontro con $name', 'el': 'Συνάντηση με $name', 'es': 'Reunión con $name', 'pt': 'Reunião com $name', 'ru': 'Встреча с $name', 'tr': '$name ile toplantı', 'ja': '$nameとの会議'});

  String get addWorkout => _t({'en': 'Add Workout', 'bg': 'Добави тренировка', 'de': 'Training hinzufügen', 'fr': 'Ajouter entraînement', 'it': 'Aggiungi allenamento', 'el': 'Προσθήκη γυμναστικής', 'es': 'Añadir entrenamiento', 'pt': 'Adicionar treino', 'ru': 'Добавить тренировку', 'tr': 'Antrenman ekle', 'ja': 'ワークアウトを追加'});

  String get editWorkout => _t({'en': 'Edit Workout', 'bg': 'Редакция на тренировка', 'de': 'Training bearbeiten', 'fr': 'Modifier entraînement', 'it': 'Modifica allenamento', 'el': 'Επεξεργασία γυμναστικής', 'es': 'Editar entrenamiento', 'pt': 'Editar treino', 'ru': 'Редактировать', 'tr': 'Antrenmanı düzenle', 'ja': 'ワークアウトを編集'});

  String get workoutType => _t({'en': 'Type of workout', 'bg': 'Вид тренировка', 'de': 'Trainingsart', 'fr': 'Type d\'entrainement', 'it': 'Tipo di allenamento', 'el': 'Είδος γυμναστικής', 'es': 'Tipo de entrenamiento', 'pt': 'Tipo de treino', 'ru': 'Вид тренировки', 'tr': 'Antrenman türü', 'ja': 'ワークアウトの種類'});

  String get workoutTypeHint => _t({'en': 'e.g. Running', 'bg': 'напр. Бягане', 'de': 'z.B. Laufen', 'fr': 'ex. Course', 'it': 'es. Corsa', 'el': 'π.χ. Τρέξιμο', 'es': 'ej. Correr', 'pt': 'ex. Corrida', 'ru': 'напр. Бег', 'tr': 'ör. Koşma', 'ja': '例: ランニング'});

  String get workoutDuration => _t({'en': 'Duration', 'bg': 'Продължителност', 'de': 'Dauer', 'fr': 'Durée', 'it': 'Durata', 'el': 'Διάρκεια', 'es': 'Duración', 'pt': 'Duração', 'ru': 'Продолжительность', 'tr': 'Süre', 'ja': '所要時間'});

  String get workoutDurationHint => _t({'en': 'e.g. 45 min', 'bg': 'напр. 45 мин', 'de': 'z.B. 45 Min', 'fr': 'ex. 45 min', 'it': 'es. 45 min', 'el': 'π.χ. 45 λεπτά', 'es': 'ej. 45 min', 'pt': 'ex. 45 min', 'ru': 'напр. 45 мин', 'tr': 'ör. 45 dak', 'ja': '例: 45分'});

  String get addPayment => _t({'en': 'Add Payment', 'bg': 'Добави плащане', 'de': 'Zahlung hinzufügen', 'fr': 'Ajouter paiement', 'it': 'Aggiungi pagamento', 'el': 'Προσθήκη πληρωμής', 'es': 'Añadir pago', 'pt': 'Adicionar pagamento', 'ru': 'Добавить платёж', 'tr': 'Ödeme ekle', 'ja': '支払いを追加'});

  String get editPayment => _t({'en': 'Edit Payment', 'bg': 'Редакция на плащане', 'de': 'Zahlung bearbeiten', 'fr': 'Modifier paiement', 'it': 'Modifica pagamento', 'el': 'Επεξεργασία πληρωμής', 'es': 'Editar pago', 'pt': 'Editar pagamento', 'ru': 'Редактировать', 'tr': 'Ödemeyi düzenle', 'ja': '支払いを編集'});

  String get paymentWhat => _t({'en': 'What', 'bg': 'Какво', 'de': 'Was', 'fr': 'Quoi', 'it': 'Cosa', 'el': 'Τι', 'es': 'Qué', 'pt': 'O quê', 'ru': 'Что', 'tr': 'Ne', 'ja': '内容'});

  String get paymentWhatHint => _t({'en': 'e.g. Rent', 'bg': 'напр. Наем', 'de': 'z.B. Miete', 'fr': 'ex. Loyer', 'it': 'es. Affitto', 'el': 'π.χ. Ενοίκιο', 'es': 'ej. Alquiler', 'pt': 'ex. Aluguel', 'ru': 'напр. Аренда', 'tr': 'ör. Kira', 'ja': '例: 家賃'});

  String get paymentAmount => _t({'en': 'Amount', 'bg': 'Сума', 'de': 'Betrag', 'fr': 'Montant', 'it': 'Importo', 'el': 'Ποσό', 'es': 'Monto', 'pt': 'Valor', 'ru': 'Сумма', 'tr': 'Tutar', 'ja': '金額'});

  String get paymentAmountHint => _t({'en': 'e.g. 500', 'bg': 'напр. 500', 'de': 'z.B. 500', 'fr': 'ex. 500', 'it': 'es. 500', 'el': 'π.χ. 500', 'es': 'ej. 500', 'pt': 'ex. 500', 'ru': 'напр. 500', 'tr': 'ör. 500', 'ja': '例: 500'});

  String get addTravel => _t({'en': 'Add Travel', 'bg': 'Добави пътуване', 'de': 'Reise hinzufügen', 'fr': 'Ajouter voyage', 'it': 'Aggiungi viaggio', 'el': 'Προσθήκη ταξιδιού', 'es': 'Añadir viaje', 'pt': 'Adicionar viagem', 'ru': 'Добавить путешествие', 'tr': 'Seyahat ekle', 'ja': '旅行を追加'});

  String get editTravel => _t({'en': 'Edit Travel', 'bg': 'Редакция на пътуване', 'de': 'Reise bearbeiten', 'fr': 'Modifier voyage', 'it': 'Modifica viaggio', 'el': 'Επεξεργασία ταξιδιού', 'es': 'Editar viaje', 'pt': 'Editar viagem', 'ru': 'Редактировать', 'tr': 'Seyahati düzenle', 'ja': '旅行を編集'});

  String get travelDestination => _t({'en': 'Destination', 'bg': 'Дестинация', 'de': 'Ziel', 'fr': 'Destination', 'it': 'Destinazione', 'el': 'Προορισμός', 'es': 'Destino', 'pt': 'Destino', 'ru': 'Назначение', 'tr': 'Hedef', 'ja': '目的地'});

  String get travelDestHint => _t({'en': 'e.g. London', 'bg': 'напр. Лондон', 'de': 'z.B. London', 'fr': 'ex. Londres', 'it': 'es. Londra', 'el': 'π.χ. Λονδίνο', 'es': 'ej. Londres', 'pt': 'ex. Londres', 'ru': 'напр. Лондон', 'tr': 'ör. Londra', 'ja': '例: ロンドン'});

  String get travelDeparture => _t({'en': 'Departure', 'bg': 'Тръгване', 'de': 'Abfahrt', 'fr': 'Départ', 'it': 'Partenza', 'el': 'Αναχώρηση', 'es': 'Salida', 'pt': 'Partida', 'ru': 'Отъезд', 'tr': 'Kalkış', 'ja': '出発'});

  String get travelReturn => _t({'en': 'Return', 'bg': 'Връщане', 'de': 'Rückkehr', 'fr': 'Retour', 'it': 'Ritorno', 'el': 'Επιστροφή', 'es': 'Regreso', 'pt': 'Regresso', 'ru': 'Возвращение', 'tr': 'Dönüş', 'ja': '戻る'});

  String get addGift => _t({'en': 'Add Gift', 'bg': 'Добави подарък', 'de': 'Geschenk hinzufügen', 'fr': 'Ajouter cadeau', 'it': 'Aggiungi regalo', 'el': 'Προσθήκη δώρου', 'es': 'Añadir regalo', 'pt': 'Adicionar presente', 'ru': 'Добавить подарок', 'tr': 'Hediye ekle', 'ja': 'ギフトを追加'});

  String get editGift => _t({'en': 'Edit Gift', 'bg': 'Редакция на подарък', 'de': 'Geschenk bearbeiten', 'fr': 'Modifier cadeau', 'it': 'Modifica regalo', 'el': 'Επεξεργασία δώρου', 'es': 'Editar regalo', 'pt': 'Editar presente', 'ru': 'Редактировать', 'tr': 'Hediyeyi düzenle', 'ja': 'ギフトを編集'});

  String get giftFor => _t({'en': 'For who', 'bg': 'За кого', 'de': 'Für wen', 'fr': 'Pour qui', 'it': 'Per chi', 'el': 'Για ποιον', 'es': 'Para quién', 'pt': 'Para quem', 'ru': 'Для кого', 'tr': 'Kime', 'ja': '対象者'});

  String get giftForHint => _t({'en': 'e.g. Maria', 'bg': 'напр. Мария', 'de': 'z.B. Maria', 'fr': 'ex. Maria', 'it': 'es. Maria', 'el': 'π.χ. Μαρία', 'es': 'ej. María', 'pt': 'ex. Maria', 'ru': 'напр. Мария', 'tr': 'ör. Maria', 'ja': '例: マリア'});

  String get giftOccasion => _t({'en': 'Occasion', 'bg': 'Повод', 'de': 'Anlass', 'fr': 'Occasion', 'it': 'Occasione', 'el': 'Αφορμή', 'es': 'Ocasión', 'pt': 'Ocasião', 'ru': 'Повод', 'tr': 'Vesile', 'ja': '機会'});

  String get giftOccasionHint => _t({'en': 'e.g. Birthday', 'bg': 'напр. Рожден ден', 'de': 'z.B. Geburtstag', 'fr': 'ex. Anniversaire', 'it': 'es. Compleanno', 'el': 'π.χ. Γενέθλια', 'es': 'ej. Cumpleaños', 'pt': 'ex. Aniversário', 'ru': 'напр. День рождения', 'tr': 'ör. Doğum günü', 'ja': '例: 誕生日'});

  String get giftBudget => _t({'en': 'Budget', 'bg': 'Бюджет', 'de': 'Budget', 'fr': 'Budget', 'it': 'Budget', 'el': 'Προϋπολογισμός', 'es': 'Presupuesto', 'pt': 'Orçamento', 'ru': 'Бюджет', 'tr': 'Bütçe', 'ja': '予算'});

  String get giftBudgetHint => _t({'en': 'e.g. 50', 'bg': 'напр. 50', 'de': 'z.B. 50', 'fr': 'ex. 50', 'it': 'es. 50', 'el': 'π.χ. 50', 'es': 'ej. 50', 'pt': 'ex. 50', 'ru': 'напр. 50', 'tr': 'ör. 50', 'ja': '例: 50'});

  String get giftDeadline => _t({'en': 'Deadline', 'bg': 'Краен срок', 'de': 'Fällig', 'fr': 'Date limite', 'it': 'Scadenza', 'el': 'Προθεσμία', 'es': 'Fecha límite', 'pt': 'Prazo', 'ru': 'Срок', 'tr': 'Son tarih', 'ja': '締め切り'});

  String get none2 => _t({'en': 'None', 'bg': 'Без', 'de': 'Keine', 'fr': 'Aucune', 'it': 'Nessuna', 'el': 'Καμία', 'es': 'Ninguna', 'pt': 'Nenhuma', 'ru': 'Нет', 'tr': 'Yok', 'ja': 'なし'});

  String travelTitle(String name) => _t({'en': 'Trip to $name', 'bg': 'Пътуване до $name', 'de': 'Reise nach $name', 'fr': 'Voyage à $name', 'it': 'Viaggio a $name', 'el': 'Ταξίδι στο $name', 'es': 'Viaje a $name', 'pt': 'Viagem a $name', 'ru': 'Поездка в $name', 'tr': "$name'a seyahat", 'ja': '$nameへの旅行'});

  // ==================== ONBOARDING ====================
  String get onboardingSkip => _t({'en': 'Skip', 'bg': 'Пропусни', 'de': 'Überspringen', 'fr': 'Passer', 'it': 'Salta', 'el': 'Παράλειψη', 'es': 'Omitir', 'pt': 'Pular', 'ru': 'Пропустить', 'tr': 'Atla', 'ja': 'スキップ'});
  String get onboardingNext => _t({'en': 'Next', 'bg': 'Напред', 'de': 'Weiter', 'fr': 'Suivant', 'it': 'Avanti', 'el': 'Επόμενο', 'es': 'Siguiente', 'pt': 'Próximo', 'ru': 'Далее', 'tr': 'İleri', 'ja': '次へ'});
  String get onboardingGetStarted => _t({'en': 'Get started', 'bg': 'Започни', 'de': 'Loslegen', 'fr': 'Commencer', 'it': 'Inizia', 'el': 'Ξεκινήστε', 'es': 'Empezar', 'pt': 'Começar', 'ru': 'Начать', 'tr': 'Başla', 'ja': '始める'});
  String get onboardingPage1Title => _t({'en': 'Welcome to Taskify', 'bg': 'Добре дошъл в Taskify', 'de': 'Willkommen bei Taskify', 'fr': 'Bienvenue dans Taskify', 'it': 'Benvenuto in Taskify', 'el': 'Καλώς ήρθες στο Taskify', 'es': 'Bienvenido a Taskify', 'pt': 'Bem-vindo ao Taskify', 'ru': 'Добро пожаловать в Taskify', 'tr': 'Taskify\'e Hoş Geldiniz', 'ja': 'Taskifyへようこそ'});
  String get onboardingPage1Desc => _t({'en': 'Smart task management in your pocket. Organize your day, meet your goals.', 'bg': 'Умно управление на задачи в джоба ти. Организирай деня си, постигай целите си.', 'de': 'Intelligentes Aufgabenmanagement in deiner Tasche.', 'fr': 'Gestion intelligente des tâches dans votre poche.', 'it': 'Gestione intelligente delle attività sempre con te.', 'el': 'Έξυπνη διαχείριση εργασιών στην τσέπη σου.', 'es': 'Gestión inteligente de tareas en tu bolsillo.', 'pt': 'Gerenciamento inteligente de tarefas no seu bolso.', 'ru': 'Умное управление задачами у тебя в кармане.', 'tr': 'Akıllı görev yönetimi cebinizde.', 'ja': 'ポケットの中のスマートなタスク管理。一日を整理して、目標を達成しましょう。'});
  String get onboardingPage2Title => _t({'en': 'Stay organized', 'bg': 'Бъди организиран', 'de': 'Organisiert bleiben', 'fr': 'Restez organisé', 'it': 'Resta organizzato', 'el': 'Μείνε οργανωμένος', 'es': 'Mantente organizado', 'pt': 'Fique organizado', 'ru': 'Оставайся организованным', 'tr': 'Düzenli kal', 'ja': '整理整頓を維持'});
  String get onboardingPage2Desc => _t({'en': 'Create tasks with categories, priorities and subtasks. Set due dates and recurring reminders.', 'bg': 'Създавай задачи с категории, приоритети и подзадачи. Задавай крайни срокове и повтарящи се напомняния.', 'de': 'Erstelle Aufgaben mit Kategorien, Prioritäten und Unteraufgaben.', 'fr': 'Créez des tâches avec catégories, priorités et sous-tâches.', 'it': 'Crea attività con categorie, priorità e sottoattività.', 'el': 'Δημιούργησε εργασίες με κατηγορίες, προτεραιότητες και υποεργασίες.', 'es': 'Crea tareas con categorías, prioridades y subtareas.', 'pt': 'Crie tarefas com categorias, prioridades e subtarefas.', 'ru': 'Создавай задачи с категориями, приоритетами и подзадачами.', 'tr': 'Kategoriler, öncelikler ve alt görevlerle görevler oluşturun.', 'ja': 'カテゴリー、優先度、サブタスク付きでタスクを作成。期限や繰り返しリマインダーも設定できます。'});
  String get onboardingPage3Title => _t({'en': 'Never forget', 'bg': 'Никога не забравяй', 'de': 'Nie vergessen', 'fr': 'Ne rien oublier', 'it': 'Non dimenticare mai', 'el': 'Μην ξεχάσεις ποτέ', 'es': 'Nunca olvides', 'pt': 'Nunca esqueça', 'ru': 'Никогда не забывай', 'tr': 'Asla unutma', 'ja': '忘れない'});
  String get onboardingPage3Desc => _t({'en': 'Set smart reminders and get notified at the right time. Daily morning briefings keep you on track.', 'bg': 'Задавай умни напомняния и получавай известия навреме. Ежедневните сутрешни брифинги ти помагат да не изоставаш.', 'de': 'Stelle Erinnerungen ein und bleib auf dem richtigen Weg.', 'fr': 'Définissez des rappels intelligents et restez sur la bonne voie.', 'it': 'Imposta promemoria intelligenti e ricevi notifiche al momento giusto.', 'el': 'Ορίστε έξυπνες υπενθυμίσεις και λάβετε ειδοποιήσεις την κατάλληλη στιγμή.', 'es': 'Configura recordatorios inteligentes y recibe notificaciones en el momento adecuado.', 'pt': 'Configure lembretes inteligentes e receba notificações na hora certa.', 'ru': 'Устанавливай умные напоминания и получай уведомления вовремя.', 'tr': 'Akıllı hatırlatıcılar ayarlayın ve doğru zamanda bildirim alın.', 'ja': 'スマートなリマインダーを設定して、適切なタイミングで通知。毎朝のブリーフィングで予定を把握できます。'});
  String get onboardingPage4Title => _t({'en': 'You\'re all set!', 'bg': 'Готов си!', 'de': 'Alles bereit!', 'fr': 'Tout est prêt!', 'it': 'Tutto pronto!', 'el': 'Είσαι έτοιμος!', 'es': '¡Todo listo!', 'pt': 'Tudo pronto!', 'ru': 'Всё готово!', 'tr': 'Hazırsın!', 'ja': '準備完了です！'});
  String get onboardingPage4Desc => _t({
    'en': 'Start managing your tasks like a pro. Your 14-day free Pro trial is already active!',
    'bg': 'Започни да управляваш задачите си като про. Твоят 14-дневен безплатен Pro пробен период вече е активен!',
    'de': 'Starte dein Aufgabenmanagement wie ein Profi. Dein 14-tägiger Pro-Test ist bereits aktiv!',
    'fr': 'Gérez vos tâches comme un pro. Votre essai gratuit Pro de 14 jours est déjà actif!',
    'it': 'Gestisci le tue attività come un professionista. Il periodo di prova Pro da 14 giorni è già attivo!',
    'el': 'Ξεκίνα επαγγελματικά. Η δωρεάν δοκιμή Pro 14 ημερών είναι ήδη ενεργή!',
    'es': 'Gestiona tus tareas como un profesional. Tu prueba Pro de 14 días ya está activa!',
    'pt': 'Gerencie suas tarefas como um profissional. Seu teste Pro de 14 dias já está ativo!',
    'ru': 'Управляй задачами как профессионал. 14-дневный бесплатный Pro период уже активен!',
    'tr': 'Görevlerinizi profesyonel gibi yönetin. 14 günlük ücretsiz Pro denemeniz aktif!', 'ja': 'プロのようにタスク管理を始めましょう。14日間の無料Proトライアルはすでに有効です！',
  });

  String giftTitle(String name) => _t({'en': 'Gift for $name', 'bg': 'Подарък за $name', 'de': 'Geschenk für $name', 'fr': 'Cadeau pour $name', 'it': 'Regalo per $name', 'el': 'Δώρο για $name', 'es': 'Regalo para $name', 'pt': 'Presente para $name', 'ru': 'Подарок для $name', 'tr': '$name için hediye', 'ja': '$nameへのギフト'});
  String birthdayTitle(String name) => _t({'en': "$name's birthday", 'bg': 'Рожден ден на $name', 'de': 'Geburtstag von $name', 'fr': 'Anniversaire de $name', 'it': 'Compleanno di $name', 'el': 'Γενέθλια του $name', 'es': 'Cumpleaños de $name', 'pt': 'Aniversário de $name', 'ru': 'День рождения $name', 'tr': '$name doğum günü', 'ja': '$nameの誕生日'});

  // ==================== PRODUCTIVITY ====================
  String get streakDays => _t({'en': 'day streak', 'bg': 'дни поред', 'de': 'Tage-Serie', 'fr': 'jours consécutifs', 'it': 'giorni di fila', 'el': 'μέρες σερί', 'es': 'días seguidos', 'pt': 'dias seguidos', 'ru': 'дней подряд', 'tr': 'günlük seri', 'ja': '日連続'});
  String get todayScore => _t({'en': 'Today', 'bg': 'Днес', 'de': 'Heute', 'fr': "Aujourd'hui", 'it': 'Oggi', 'el': 'Σήμερα', 'es': 'Hoy', 'pt': 'Hoje', 'ru': 'Сегодня', 'tr': 'Bugün', 'ja': '今日'});

  // ==================== POMODORO ====================
  String get pomodoroFocus => _t({'en': 'Focus', 'bg': 'Фокус', 'de': 'Fokus', 'fr': 'Focus', 'it': 'Focus', 'el': 'Εστίαση', 'es': 'Foco', 'pt': 'Foco', 'ru': 'Фокус', 'tr': 'Odak', 'ja': '集中'});
  String get pomodoroSession => _t({'en': 'Focus Session', 'bg': 'Сесия на фокус', 'de': 'Fokus-Sitzung', 'fr': 'Session de focus', 'it': 'Sessione focus', 'el': 'Συνεδρία εστίασης', 'es': 'Sesión de enfoque', 'pt': 'Sessão de foco', 'ru': 'Сессия фокуса', 'tr': 'Odak Seansı', 'ja': '集中セッション'});
  String get pomodoroComplete => _t({'en': 'Session complete!', 'bg': 'Сесията приключи!', 'de': 'Sitzung abgeschlossen!', 'fr': 'Session terminée!', 'it': 'Sessione completata!', 'el': 'Η συνεδρία ολοκληρώθηκε!', 'es': '¡Sesión completada!', 'pt': 'Sessão concluída!', 'ru': 'Сессия завершена!', 'tr': 'Seans tamamlandı!', 'ja': 'セッション完了！'});
  String get pomodoroStart => _t({'en': 'Start', 'bg': 'Старт', 'de': 'Starten', 'fr': 'Démarrer', 'it': 'Avvia', 'el': 'Έναρξη', 'es': 'Iniciar', 'pt': 'Iniciar', 'ru': 'Старт', 'tr': 'Başlat', 'ja': '開始'});
  String get pomodoroPause => _t({'en': 'Pause', 'bg': 'Пауза', 'de': 'Pause', 'fr': 'Pause', 'it': 'Pausa', 'el': 'Παύση', 'es': 'Pausar', 'pt': 'Pausar', 'ru': 'Пауза', 'tr': 'Duraklat', 'ja': '一時停止'});
  String get pomodoroStop => _t({'en': 'Stop', 'bg': 'Спри', 'de': 'Stopp', 'fr': 'Arrêter', 'it': 'Ferma', 'el': 'Διακοπή', 'es': 'Detener', 'pt': 'Parar', 'ru': 'Стоп', 'tr': 'Durdur', 'ja': '停止'});
  String get pomodoroClose => _t({'en': 'Close', 'bg': 'Затвори', 'de': 'Schließen', 'fr': 'Fermer', 'it': 'Chiudi', 'el': 'Κλείσιμο', 'es': 'Cerrar', 'pt': 'Fechar', 'ru': 'Закрыть', 'tr': 'Kapat', 'ja': '閉じる'});

  // ==================== APPLE CALENDAR ====================
  String get appleCalendarConnected => _t({'en': 'Apple Calendar connected', 'bg': 'Apple Calendar свързан', 'de': 'Apple Kalender verbunden', 'fr': 'Apple Calendrier connecté', 'it': 'Apple Calendario connesso', 'el': 'Το Apple Ημερολόγιο συνδέθηκε', 'es': 'Apple Calendario conectado', 'pt': 'Apple Calendário conectado', 'ru': 'Apple Календарь подключён', 'tr': 'Apple Takvimi bağlandı', 'ja': 'Apple Calendarに接続しました'});
  String get appleCalendarConnectedDesc => _t({'en': 'You can export tasks to Apple Calendar', 'bg': 'Можеш да експортираш задачи в Apple Calendar', 'de': 'Du kannst Aufgaben in den Apple Kalender exportieren', 'fr': 'Vous pouvez exporter des tâches vers Apple Calendrier', 'it': 'Puoi esportare attività in Apple Calendario', 'el': 'Μπορείς να εξάγεις εργασίες στο Apple Ημερολόγιο', 'es': 'Puedes exportar tareas a Apple Calendario', 'pt': 'Podes exportar tarefas para o Apple Calendário', 'ru': 'Можно экспортировать задачи в Apple Календарь', 'tr': 'Görevleri Apple Takvimine aktarabilirsin', 'ja': 'タスクをApple Calendarにエクスポートできます'});
  String get appleCalendarPermission => _t({'en': 'Allow access to Apple Calendar', 'bg': 'Разреши достъп до Apple Calendar', 'de': 'Zugriff auf Apple Kalender erlauben', 'fr': 'Autoriser l\'accès à Apple Calendrier', 'it': 'Consenti accesso ad Apple Calendario', 'el': 'Να επιτρέπεται η πρόσβαση στο Apple Ημερολόγιο', 'es': 'Permitir acceso a Apple Calendario', 'pt': 'Permitir acesso ao Apple Calendário', 'ru': 'Разрешить доступ к Apple Календарю', 'tr': 'Apple Takvimine erişime izin ver', 'ja': 'Apple Calendarへのアクセスを許可'});
  String get calendarAccessDenied => _t({'en': 'Calendar access denied', 'bg': 'Достъпът до Calendar е отказан', 'de': 'Kalenderzugriff verweigert', 'fr': 'Accès calendrier refusé', 'it': 'Accesso al calendario negato', 'el': 'Άρνηση πρόσβασης ημερολογίου', 'es': 'Acceso al calendario denegado', 'pt': 'Acesso ao calendário negado', 'ru': 'Доступ к календарю запрещён', 'tr': 'Takvim erişimi reddedildi', 'ja': 'カレンダーへのアクセスが拒否されました'});
  String get exportTasks => _t({'en': 'Export tasks', 'bg': 'Експортирай задачи', 'de': 'Aufgaben exportieren', 'fr': 'Exporter les tâches', 'it': 'Esporta attività', 'el': 'Εξαγωγή εργασιών', 'es': 'Exportar tareas', 'pt': 'Exportar tarefas', 'ru': 'Экспорт задач', 'tr': 'Görevleri dışa aktar', 'ja': 'タスクをエクスポート'});
  String get exportTasksDesc => _t({'en': 'Adds active tasks to Apple Calendar', 'bg': 'Добавя активните задачи в Apple Calendar', 'de': 'Fügt aktive Aufgaben zum Apple Kalender hinzu', 'fr': 'Ajoute les tâches actives à Apple Calendrier', 'it': 'Aggiunge le attività attive ad Apple Calendario', 'el': 'Προσθέτει ενεργές εργασίες στο Apple Ημερολόγιο', 'es': 'Añade tareas activas a Apple Calendario', 'pt': 'Adiciona tarefas ativas ao Apple Calendário', 'ru': 'Добавляет активные задачи в Apple Календарь', 'tr': 'Aktif görevleri Apple Takvimine ekler', 'ja': '有効なタスクをApple Calendarに追加します'});
  String tasksAddedToAppleCalendar(int count) => _t({'en': '$count tasks added to Apple Calendar', 'bg': '$count задачи добавени в Apple Calendar', 'de': '$count Aufgaben zum Apple Kalender hinzugefügt', 'fr': '$count tâches ajoutées à Apple Calendrier', 'it': '$count attività aggiunte ad Apple Calendario', 'el': '$count εργασίες προστέθηκαν στο Apple Ημερολόγιο', 'es': '$count tareas añadidas a Apple Calendario', 'pt': '$count tarefas adicionadas ao Apple Calendário', 'ru': '$count задач добавлено в Apple Календарь', 'tr': '$count görev Apple Takvimine eklendi', 'ja': '$count 件のタスクをApple Calendarに追加しました'});
  String get pomodoroAgain => _t({'en': 'Again', 'bg': 'Отново', 'de': 'Nochmal', 'fr': 'Encore', 'it': 'Di nuovo', 'el': 'Ξανά', 'es': 'Otra vez', 'pt': 'Novamente', 'ru': 'Снова', 'tr': 'Tekrar', 'ja': 'もう一度'});

  // ==================== DELETE ACCOUNT ====================
  String get password => _t({'en': 'Password', 'bg': 'Парола', 'de': 'Passwort', 'fr': 'Mot de passe', 'it': 'Password', 'el': 'Κωδικός', 'es': 'Contraseña', 'pt': 'Senha', 'ru': 'Пароль', 'tr': 'Şifre', 'ja': 'パスワード'});
  String get continueAction => _t({'en': 'Continue', 'bg': 'Продължи', 'de': 'Weiter', 'fr': 'Continuer', 'it': 'Continua', 'el': 'Συνέχεια', 'es': 'Continuar', 'pt': 'Continuar', 'ru': 'Продолжить', 'tr': 'Devam', 'ja': '続行'});
  String get deleteAccount => _t({'en': 'Delete Account', 'bg': 'Изтрий акаунт', 'de': 'Konto löschen', 'fr': 'Supprimer le compte', 'it': 'Elimina account', 'el': 'Διαγραφή λογαριασμού', 'es': 'Eliminar cuenta', 'pt': 'Excluir conta', 'ru': 'Удалить аккаунт', 'tr': 'Hesabı sil', 'ja': 'アカウントを削除'});
  String get deleteAccountSubtitle => _t({'en': 'Permanently delete your account and all data', 'bg': 'Изтрий акаунта и всички данни завинаги', 'de': 'Konto und alle Daten dauerhaft löschen', 'fr': 'Supprimer définitivement votre compte et toutes les données', 'it': 'Elimina definitivamente account e tutti i dati', 'el': 'Μόνιμη διαγραφή λογαριασμού και όλων των δεδομένων', 'es': 'Eliminar permanentemente tu cuenta y todos los datos', 'pt': 'Excluir permanentemente sua conta e todos os dados', 'ru': 'Навсегда удалить аккаунт и все данные', 'tr': 'Hesabınızı ve tüm verilerinizi kalıcı olarak silin', 'ja': 'アカウントとすべてのデータを完全に削除'});
  String get deleteAccountConfirm1Title => _t({'en': 'Delete your account?', 'bg': 'Изтриване на акаунта?', 'de': 'Konto löschen?', 'fr': 'Supprimer votre compte?', 'it': 'Eliminare l\'account?', 'el': 'Διαγραφή λογαριασμού;', 'es': '¿Eliminar tu cuenta?', 'pt': 'Excluir sua conta?', 'ru': 'Удалить аккаунт?', 'tr': 'Hesabınızı silin mi?', 'ja': 'アカウントを削除しますか？'});
  String get deleteAccountConfirm1Body => _t({'en': 'This action is permanent and cannot be undone.', 'bg': 'Това действие е необратимо и не може да бъде отменено.', 'de': 'Diese Aktion ist dauerhaft und kann nicht rückgängig gemacht werden.', 'fr': 'Cette action est permanente et ne peut pas être annulée.', 'it': 'Questa azione è permanente e non può essere annullata.', 'el': 'Αυτή η ενέργεια είναι μόνιμη και δεν μπορεί να αναιρεθεί.', 'es': 'Esta acción es permanente y no se puede deshacer.', 'pt': 'Esta ação é permanente e não pode ser desfeita.', 'ru': 'Это действие необратимо и не может быть отменено.', 'tr': 'Bu işlem kalıcıdır ve geri alınamaz.', 'ja': 'この操作は取り消せません。'});
  String get deleteAccountConfirm2Title => _t({'en': 'Are you absolutely sure?', 'bg': 'Абсолютно сигурен ли си?', 'de': 'Bist du absolut sicher?', 'fr': 'Êtes-vous absolument sûr?', 'it': 'Sei assolutamente sicuro?', 'el': 'Είστε απολύτως σίγουροι;', 'es': '¿Estás completamente seguro?', 'pt': 'Tem absoluta certeza?', 'ru': 'Вы абсолютно уверены?', 'tr': 'Kesinlikle emin misiniz?', 'ja': '本当によろしいですか？'});
  String deleteAccountConfirm2Body(int tasks, int cats) => _t({'en': 'You have $tasks tasks and $cats categories that will be deleted permanently.', 'bg': 'Имаш $tasks задачи и $cats категории, които ще бъдат изтрити завинаги.', 'de': 'Du hast $tasks Aufgaben und $cats Kategorien, die dauerhaft gelöscht werden.', 'fr': 'Vous avez $tasks tâches et $cats catégories qui seront supprimées définitivement.', 'it': 'Hai $tasks attività e $cats categorie che verranno eliminate definitivamente.', 'el': 'Έχετε $tasks εργασίες και $cats κατηγορίες που θα διαγραφούν μόνιμα.', 'es': 'Tienes $tasks tareas y $cats categorías que se eliminarán permanentemente.', 'pt': 'Você tem $tasks tarefas e $cats categorias que serão excluídas permanentemente.', 'ru': 'У вас $tasks задач и $cats категорий, которые будут удалены навсегда.', 'tr': '$tasks görev ve $cats kategoriniz kalıcı olarak silinecek.', 'ja': '$tasks件のタスクと$cats件のカテゴリーが完全に削除されます。'});
  String get deleteAccountSubscriptionTitle => _t({'en': 'Active Subscription', 'bg': 'Активен абонамент', 'de': 'Aktives Abonnement', 'fr': 'Abonnement actif', 'it': 'Abbonamento attivo', 'el': 'Ενεργή συνδρομή', 'es': 'Suscripción activa', 'pt': 'Assinatura ativa', 'ru': 'Активная подписка', 'tr': 'Aktif abonelik', 'ja': '有効なサブスクリプション'});
  String get deleteAccountSubscriptionBody => _t({'en': 'If you have an active subscription, it will continue to bill through Apple unless you cancel it separately.', 'bg': 'Ако имаш активен абонамент, той ще продължи да се таксува чрез Apple, освен ако не го отмениш отделно.', 'de': 'Wenn du ein aktives Abonnement hast, wird es weiterhin über Apple abgerechnet, es sei denn, du kündigst es separat.', 'fr': 'Si vous avez un abonnement actif, il continuera à être facturé via Apple à moins que vous ne l\'annuliez séparément.', 'it': 'Se hai un abbonamento attivo, continuerà a essere addebitato tramite Apple a meno che non lo annulli separatamente.', 'el': 'Εάν έχετε ενεργή συνδρομή, θα συνεχίσει να χρεώνεται μέσω Apple εκτός αν την ακυρώσετε ξεχωριστά.', 'es': 'Si tienes una suscripción activa, Apple continuará cobrándola a menos que la canceles por separado.', 'pt': 'Se você tem uma assinatura ativa, ela continuará sendo cobrada pela Apple a menos que você a cancele separadamente.', 'ru': 'Если у вас есть активная подписка, Apple продолжит взимать плату, если вы не отмените её отдельно.', 'tr': 'Aktif aboneliğiniz varsa, ayrıca iptal etmediğiniz sürece Apple üzerinden ücretlendirilmeye devam edecektir.', 'ja': '有効なサブスクリプションがある場合、別途解約しない限りAppleを通じて請求が続きます。'});
  String get manageSubscriptions => _t({'en': 'Manage Subscriptions', 'bg': 'Управление на абонаментите', 'de': 'Abonnements verwalten', 'fr': 'Gérer les abonnements', 'it': 'Gestisci abbonamenti', 'el': 'Διαχείριση συνδρομών', 'es': 'Gestionar suscripciones', 'pt': 'Gerenciar assinaturas', 'ru': 'Управление подписками', 'tr': 'Abonelikleri yönet', 'ja': 'サブスクリプションを管理'});
  String get deleteAccountReauthTitle => _t({'en': 'Confirm Your Identity', 'bg': 'Потвърди самоличността си', 'de': 'Identität bestätigen', 'fr': 'Confirmez votre identité', 'it': 'Conferma la tua identità', 'el': 'Επιβεβαίωση ταυτότητας', 'es': 'Confirma tu identidad', 'pt': 'Confirme sua identidade', 'ru': 'Подтвердите личность', 'tr': 'Kimliğinizi onaylayın', 'ja': '本人確認'});
  String get deleteAccountReauthBody => _t({'en': 'For security, please enter your password.', 'bg': 'От съображения за сигурност, моля въведи паролата си.', 'de': 'Aus Sicherheitsgründen geben Sie bitte Ihr Passwort ein.', 'fr': 'Pour des raisons de sécurité, veuillez entrer votre mot de passe.', 'it': 'Per sicurezza, inserisci la tua password.', 'el': 'Για λόγους ασφαλείας, εισάγετε τον κωδικό πρόσβασής σας.', 'es': 'Por seguridad, introduce tu contraseña.', 'pt': 'Por segurança, insira sua senha.', 'ru': 'В целях безопасности введите ваш пароль.', 'tr': 'Güvenlik için lütfen şifrenizi girin.', 'ja': 'セキュリティのため、パスワードを入力してください。'});
  String get deleteAccountInProgress => _t({'en': 'Deleting your account...', 'bg': 'Изтриване на акаунта...', 'de': 'Konto wird gelöscht...', 'fr': 'Suppression de votre compte...', 'it': 'Eliminazione dell\'account...', 'el': 'Διαγραφή λογαριασμού...', 'es': 'Eliminando tu cuenta...', 'pt': 'Excluindo sua conta...', 'ru': 'Удаление аккаунта...', 'tr': 'Hesabınız siliniyor...', 'ja': 'アカウントを削除しています...'});
  String get deleteAccountError => _t({'en': 'Could not delete account. Please try again.', 'bg': 'Грешка при изтриване на акаунта. Опитай отново.', 'de': 'Konto konnte nicht gelöscht werden. Bitte versuche es erneut.', 'fr': 'Impossible de supprimer le compte. Veuillez réessayer.', 'it': 'Impossibile eliminare l\'account. Riprova.', 'el': 'Δεν ήταν δυνατή η διαγραφή του λογαριασμού. Παρακαλώ δοκιμάστε ξανά.', 'es': 'No se pudo eliminar la cuenta. Por favor, inténtalo de nuevo.', 'pt': 'Não foi possível excluir a conta. Por favor, tente novamente.', 'ru': 'Не удалось удалить аккаунт. Попробуйте ещё раз.', 'tr': 'Hesap silinemedi. Lütfen tekrar deneyin.', 'ja': 'アカウントを削除できませんでした。もう一度お試しください。'});

  // ==================== QUICK ADD ====================
  String get quickAddDone => _t({'en': 'Task added', 'bg': 'Задачата е добавена', 'de': 'Aufgabe hinzugefügt', 'fr': 'Tâche ajoutée', 'it': 'Attività aggiunta', 'el': 'Εργασία προστέθηκε', 'es': 'Tarea añadida', 'pt': 'Tarefa adicionada', 'ru': 'Задача добавлена', 'tr': 'Görev eklendi', 'ja': 'タスクを追加しました'});

  // ==================== ONBOARDING FEATURES PAGE ====================
  String get onboardingFeaturesTitle => _t({'en': 'Power features', 'bg': 'Мощни функции', 'de': 'Starke Funktionen', 'fr': 'Fonctionnalités avancées', 'it': 'Funzionalità potenti', 'el': 'Ισχυρές δυνατότητες', 'es': 'Funciones potentes', 'pt': 'Recursos avançados', 'ru': 'Мощные функции', 'tr': 'Güçlü özellikler', 'ja': 'パワフルな機能'});
  String get onboardingFeaturePomodoro => _t({'en': 'Focus Timer — 25-min Pomodoro sessions', 'bg': 'Таймер за фокус — 25-минутни Pomodoro сесии', 'de': 'Fokus-Timer — 25-min Pomodoro-Sitzungen', 'fr': 'Minuteur Focus — séances Pomodoro de 25 min', 'it': 'Timer focus — sessioni Pomodoro da 25 min', 'el': 'Χρονόμετρο εστίασης — 25-λεπτες συνεδρίες', 'es': 'Temporizador Focus — sesiones Pomodoro de 25 min', 'pt': 'Temporizador Focus — sessões Pomodoro de 25 min', 'ru': 'Таймер фокуса — 25-минутные сессии Pomodoro', 'tr': 'Odak Zamanlayıcı — 25 dakikalık Pomodoro seansları', 'ja': '集中タイマー — 25分のポモドーロセッション'});
  String get onboardingFeatureStreak => _t({'en': 'Daily Streak — track your productivity momentum', 'bg': 'Дневна серия — следи продуктивността си', 'de': 'Tages-Serie — verfolge deine Produktivität', 'fr': 'Série quotidienne — suivez votre élan productif', 'it': 'Serie giornaliera — monitora la tua produttività', 'el': 'Ημερήσια σερί — παρακολούθηση παραγωγικότητας', 'es': 'Racha diaria — sigue tu impulso de productividad', 'pt': 'Sequência diária — acompanhe sua produtividade', 'ru': 'Дневная серия — следи за своей продуктивностью', 'tr': 'Günlük seri — üretkenlik momentumunu takip et', 'ja': 'デイリーストリーク — 生産性の勢いを記録'});
  String get onboardingFeatureNlp => _t({'en': "Smart Input — type 'tomorrow' to set the date", 'bg': "Умен ввод — напиши 'утре' за автодата", 'de': "Smarte Eingabe — tippe 'morgen' für das Datum", 'fr': "Saisie intelligente — tapez 'demain' pour la date", 'it': "Input intelligente — scrivi 'domani' per la data", 'el': "Έξυπνη εισαγωγή — γράψε 'αύριο' για ημερομηνία", 'es': "Entrada inteligente — escribe 'mañana' para la fecha", 'pt': "Entrada inteligente — escreva 'amanhã' para a data", 'ru': "Умный ввод — напиши 'завтра' для даты", 'tr': "Akıllı giriş — tarih için 'yarın' yazın", 'ja': 'スマート入力 — 「明日」と入力すると日付を設定'});
  String get onboardingFeatureQuickAdd => _t({'en': 'Quick-Add — add tasks directly from notifications', 'bg': 'Бързо добавяне — задачи директно от известия', 'de': 'Schnell-Hinzufügen — Aufgaben aus Benachrichtigungen', 'fr': 'Ajout rapide — ajoutez des tâches depuis les notifications', 'it': 'Aggiunta rapida — aggiungi attività dalle notifiche', 'el': 'Γρήγορη προσθήκη — εργασίες από ειδοποιήσεις', 'es': 'Añadir rápido — añade tareas desde notificaciones', 'pt': 'Adição rápida — adicione tarefas das notificações', 'ru': 'Быстрое добавление — задачи прямо из уведомлений', 'tr': 'Hızlı Ekle — bildirimlerden görev ekle', 'ja': 'クイック追加 — 通知から直接タスクを追加'});

  // ----- AI onboarding страница (как се ползва AI) -----
  String get onboardingAiTitle => _t({'en': 'AI does the heavy lifting', 'bg': 'AI върши тежката работа', 'de': 'KI übernimmt die Arbeit', 'fr': "L'IA fait le gros du travail", 'it': 'L\'IA fa il lavoro pesante', 'el': 'Το AI κάνει τη δουλειά', 'es': 'La IA hace el trabajo pesado', 'pt': 'A IA faz o trabalho pesado', 'ru': 'ИИ делает всю работу', 'tr': 'Zor işi yapay zekâ yapar', 'ja': 'AIにおまかせ'});
  String get onboardingAiParse => _t({'en': "Type naturally — e.g. 'call mom tomorrow at 5pm' — then tap the ✨ AI button. It fills in the date, time, priority and category for you.", 'bg': "Пиши свободно — напр. 'обади се на мама утре в 17ч' — и натисни бутона ✨ AI. Той попълва датата, часа, приоритета и категорията вместо теб.", 'de': "Schreib natürlich — z. B. 'Mama morgen um 17 Uhr anrufen' — und tippe auf die ✨ KI-Taste. Datum, Uhrzeit, Priorität und Kategorie werden für dich ausgefüllt.", 'fr': "Écrivez naturellement — par ex. 'appeler maman demain à 17h' — puis touchez le bouton ✨ IA. La date, l'heure, la priorité et la catégorie sont remplies pour vous.", 'it': "Scrivi in modo naturale — es. 'chiama la mamma domani alle 17' — poi tocca il pulsante ✨ IA. Data, ora, priorità e categoria vengono compilate per te.", 'el': "Γράψε φυσικά — π.χ. 'πάρε τη μαμά αύριο στις 5μμ' — και πάτα το κουμπί ✨ AI. Συμπληρώνει ημερομηνία, ώρα, προτεραιότητα και κατηγορία για σένα.", 'es': "Escribe con naturalidad — p. ej. 'llamar a mamá mañana a las 17h' — y toca el botón ✨ IA. Rellena la fecha, la hora, la prioridad y la categoría por ti.", 'pt': "Escreve naturalmente — ex. 'ligar à mãe amanhã às 17h' — e toca no botão ✨ IA. Preenche a data, hora, prioridade e categoria por ti.", 'ru': "Пиши обычным языком — напр. 'позвонить маме завтра в 17:00' — и нажми кнопку ✨ AI. Дата, время, приоритет и категория заполнятся автоматически.", 'tr': "Doğal yaz — örn. 'yarın 17:00 annemi ara' — ve ✨ AI düğmesine dokun. Tarih, saat, öncelik ve kategori senin için doldurulur.", 'ja': '自然に入力 — 例：「明日の午後5時にお母さんに電話」— そして✨ AIボタンをタップ。日付、時刻、優先度、カテゴリーを自動で入力します。'});
  String get onboardingAiBreakdown => _t({'en': "Got a big task? Open it and tap 'Break into steps' — AI splits it into clear, doable subtasks.", 'bg': "Голяма задача? Отвори я и натисни 'Разбий на стъпки' — AI я разделя на ясни, изпълними подзадачи.", 'de': "Große Aufgabe? Öffne sie und tippe auf 'In Schritte aufteilen' — die KI zerlegt sie in klare, machbare Unteraufgaben.", 'fr': "Une grosse tâche ? Ouvrez-la et touchez 'Diviser en étapes' — l'IA la découpe en sous-tâches claires et réalisables.", 'it': "Attività grande? Aprila e tocca 'Dividi in passaggi' — l'IA la suddivide in sottotask chiari e fattibili.", 'el': "Μεγάλη εργασία; Άνοιξέ την και πάτα 'Ανάλυση σε βήματα' — το AI τη χωρίζει σε ξεκάθαρες υποεργασίες.", 'es': "¿Una tarea grande? Ábrela y toca 'Dividir en pasos' — la IA la divide en subtareas claras y factibles.", 'pt': "Tarefa grande? Abre-a e toca em 'Dividir em etapas' — a IA divide-a em subtarefas claras e viáveis.", 'ru': "Большая задача? Открой её и нажми 'Разбить на шаги' — ИИ разделит её на чёткие выполнимые подзадачи.", 'tr': "Büyük görev mi? Aç ve 'Adımlara böl'e dokun — AI onu net, yapılabilir alt görevlere ayırır.", 'ja': '大きなタスクですか？開いて「ステップに分解」をタップすると、AIが明確で実行しやすいサブタスクに分けます。'});
  String get onboardingAiVoice => _t({'en': 'Tap the microphone and just speak. Your words turn into a task and are parsed automatically.', 'bg': 'Натисни микрофона и просто говори. Думите ти стават задача и се анализират автоматично.', 'de': 'Tippe auf das Mikrofon und sprich einfach. Deine Worte werden zur Aufgabe und automatisch analysiert.', 'fr': 'Touchez le micro et parlez simplement. Vos mots deviennent une tâche, analysée automatiquement.', 'it': 'Tocca il microfono e parla. Le tue parole diventano un\'attività, analizzata automaticamente.', 'el': 'Πάτα το μικρόφωνο και απλώς μίλα. Τα λόγια σου γίνονται εργασία και αναλύονται αυτόματα.', 'es': 'Toca el micrófono y habla. Tus palabras se convierten en una tarea y se analizan automáticamente.', 'pt': 'Toca no microfone e fala. As tuas palavras viram uma tarefa e são analisadas automaticamente.', 'ru': 'Нажми на микрофон и просто говори. Твои слова станут задачей и проанализируются автоматически.', 'tr': 'Mikrofona dokun ve konuş. Sözlerin otomatik olarak göreve dönüşür ve ayrıştırılır.', 'ja': 'マイクをタップして話すだけ。あなたの言葉がタスクになり、自動的に解析されます。'});
  String get onboardingAiNote => _t({'en': 'Premium feature · replies in your language · up to 20 AI requests per day.', 'bg': 'Premium функция · отговаря на твоя език · до 20 AI заявки на ден.', 'de': 'Premium-Funktion · antwortet in deiner Sprache · bis zu 20 KI-Anfragen pro Tag.', 'fr': 'Fonction Premium · répond dans votre langue · jusqu\'à 20 requêtes IA par jour.', 'it': 'Funzione Premium · risponde nella tua lingua · fino a 20 richieste IA al giorno.', 'el': 'Λειτουργία Premium · απαντά στη γλώσσα σου · έως 20 αιτήματα AI την ημέρα.', 'es': 'Función Premium · responde en tu idioma · hasta 20 solicitudes de IA al día.', 'pt': 'Recurso Premium · responde no teu idioma · até 20 pedidos de IA por dia.', 'ru': 'Premium-функция · отвечает на твоём языке · до 20 запросов к ИИ в день.', 'tr': 'Premium özellik · senin dilinde yanıtlar · günde 20 AI isteğine kadar.', 'ja': 'プレミアム機能 · あなたの言語で返信 · 1日最大20回のAIリクエスト。'});

  // ==================== EISENHOWER MATRIX ====================
  String get matrix => _t({'en': 'Matrix', 'bg': 'Матрица', 'de': 'Matrix', 'fr': 'Matrice', 'it': 'Matrice', 'el': 'Μήτρα', 'es': 'Matriz', 'pt': 'Matriz', 'ru': 'Матрица', 'tr': 'Matris', 'ja': 'マトリックス'});
  String get matrixDoFirst => _t({'en': 'Do First', 'bg': 'Правя сега', 'de': 'Sofort erledigen', 'fr': 'Faire maintenant', 'it': 'Fai subito', 'el': 'Κάνε πρώτα', 'es': 'Hacer ya', 'pt': 'Fazer agora', 'ru': 'Сделать сейчас', 'tr': 'Hemen Yap', 'ja': '最初に行う'});
  String get matrixSchedule => _t({'en': 'Schedule', 'bg': 'Планирам', 'de': 'Planen', 'fr': 'Planifier', 'it': 'Pianifica', 'el': 'Προγραμμάτισε', 'es': 'Planificar', 'pt': 'Planejar', 'ru': 'Запланировать', 'tr': 'Planla', 'ja': 'スケジュール'});
  String get matrixDelegate => _t({'en': 'Delegate', 'bg': 'Делегирам', 'de': 'Delegieren', 'fr': 'Déléguer', 'it': 'Delega', 'el': 'Ανάθεσε', 'es': 'Delegar', 'pt': 'Delegar', 'ru': 'Делегировать', 'tr': 'Devret', 'ja': '委任'});
  String get matrixEliminate => _t({'en': 'Eliminate', 'bg': 'Изтрий', 'de': 'Eliminieren', 'fr': 'Éliminer', 'it': 'Elimina', 'el': 'Εξάλειψε', 'es': 'Eliminar', 'pt': 'Eliminar', 'ru': 'Устранить', 'tr': 'Yok Et', 'ja': '排除'});
  String get matrixUrgentImportant => _t({'en': 'Urgent • Important', 'bg': 'Спешно • Важно', 'de': 'Dringend • Wichtig', 'fr': 'Urgent • Important', 'it': 'Urgente • Importante', 'el': 'Επείγον • Σημαντικό', 'es': 'Urgente • Importante', 'pt': 'Urgente • Importante', 'ru': 'Срочно • Важно', 'tr': 'Acil • Önemli', 'ja': '緊急 • 重要'});
  String get matrixImportantOnly => _t({'en': 'Important • Not urgent', 'bg': 'Важно • Не спешно', 'de': 'Wichtig • Nicht dringend', 'fr': 'Important • Pas urgent', 'it': 'Importante • Non urgente', 'el': 'Σημαντικό • Μη επείγον', 'es': 'Importante • No urgente', 'pt': 'Importante • Não urgente', 'ru': 'Важно • Не срочно', 'tr': 'Önemli • Acil değil', 'ja': '重要 • 緊急でない'});
  String get matrixUrgentOnly => _t({'en': 'Urgent • Not important', 'bg': 'Спешно • Не важно', 'de': 'Dringend • Nicht wichtig', 'fr': 'Urgent • Pas important', 'it': 'Urgente • Non importante', 'el': 'Επείγον • Μη σημαντικό', 'es': 'Urgente • No importante', 'pt': 'Urgente • Não importante', 'ru': 'Срочно • Не важно', 'tr': 'Acil • Önemli değil', 'ja': '緊急 • 重要でない'});
  String get matrixNeither => _t({'en': 'Not urgent • Not important', 'bg': 'Не спешно • Не важно', 'de': 'Nicht dringend • Nicht wichtig', 'fr': 'Pas urgent • Pas important', 'it': 'Non urgente • Non importante', 'el': 'Μη επείγον • Μη σημαντικό', 'es': 'No urgente • No importante', 'pt': 'Não urgente • Não importante', 'ru': 'Не срочно • Не важно', 'tr': 'Acil değil • Önemli değil', 'ja': '緊急でない • 重要でない'});
  String get matrixEmpty => _t({'en': 'No tasks', 'bg': 'Няма задачи', 'de': 'Keine Aufgaben', 'fr': 'Aucune tâche', 'it': 'Nessuna attività', 'el': 'Δεν υπάρχουν εργασίες', 'es': 'Sin tareas', 'pt': 'Sem tarefas', 'ru': 'Нет задач', 'tr': 'Görev yok', 'ja': 'タスクなし'});
  String get matrixUrgent => _t({'en': 'Urgent', 'bg': 'Спешно', 'de': 'Dringend', 'fr': 'Urgent', 'it': 'Urgente', 'el': 'Επείγον', 'es': 'Urgente', 'pt': 'Urgente', 'ru': 'Срочно', 'tr': 'Acil', 'ja': '緊急'});
  String get matrixNotUrgent => _t({'en': 'Not urgent', 'bg': 'Не спешно', 'de': 'Nicht dringend', 'fr': 'Pas urgent', 'it': 'Non urgente', 'el': 'Μη επείγον', 'es': 'No urgente', 'pt': 'Не срочно', 'ru': 'Не срочно', 'tr': 'Acil değil', 'ja': '緊急でない'});
  String get matrixImportant => _t({'en': 'Important', 'bg': 'Важно', 'de': 'Wichtig', 'fr': 'Important', 'it': 'Importante', 'el': 'Σημαντικό', 'es': 'Importante', 'pt': 'Importante', 'ru': 'Важно', 'tr': 'Önemli', 'ja': '重要'});
  String get matrixNotImportant => _t({'en': 'Not important', 'bg': 'Не важно', 'de': 'Nicht wichtig', 'fr': 'Pas important', 'it': 'Non importante', 'el': 'Μη σημαντικό', 'es': 'No importante', 'pt': 'Não importante', 'ru': 'Не важно', 'tr': 'Önemli değil', 'ja': '重要でない'});

  // ==================== AI FEATURES ====================
  String get aiParse => _t({'en': 'AI Parse', 'bg': 'AI парсване', 'de': 'KI-Analyse', 'fr': 'Analyse IA', 'it': 'Analisi IA', 'el': 'Ανάλυση ΑΙ', 'es': 'Análisis IA', 'pt': 'Análise IA', 'ru': 'AI анализ', 'tr': 'AI Analiz', 'ja': 'AI解析'});
  String get aiBreakdown => _t({'en': 'Breakdown', 'bg': 'Разбий', 'de': 'Aufteilen', 'fr': 'Décomposer', 'it': 'Suddividi', 'el': 'Ανάλυση', 'es': 'Dividir', 'pt': 'Dividir', 'ru': 'Разбить', 'tr': 'Böl', 'ja': '分解'});
  String get aiBreakdownAction => _t({'en': 'Break into steps', 'bg': 'Разбий на стъпки', 'de': 'In Schritte aufteilen', 'fr': 'Diviser en étapes', 'it': 'Dividi in passaggi', 'el': 'Ανάλυση σε βήματα', 'es': 'Dividir en pasos', 'pt': 'Dividir em etapas', 'ru': 'Разбить на шаги', 'tr': 'Adımlara böl', 'ja': 'ステップに分解'});
  String get aiParsing => _t({'en': 'Parsing...', 'bg': 'Анализирам...', 'de': 'Analysiere...', 'fr': 'Analyse...', 'it': 'Analisi...', 'el': 'Ανάλυση...', 'es': 'Analizando...', 'pt': 'Analisando...', 'ru': 'Анализирую...', 'tr': 'Analiz ediliyor...', 'ja': '解析中...'});
  String get aiBreaking => _t({'en': 'Generating subtasks...', 'bg': 'Генерирам подзадачи...', 'de': 'Unteraufgaben generieren...', 'fr': 'Génération sous-tâches...', 'it': 'Generazione sottotask...', 'el': 'Δημιουργία υποεργασιών...', 'es': 'Generando subtareas...', 'pt': 'Gerando subtarefas...', 'ru': 'Генерирую подзадачи...', 'tr': 'Alt görevler oluşturuluyor...', 'ja': 'サブタスクを生成中...'});
  String get aiError => _t({'en': 'AI unavailable. Fill manually.', 'bg': 'AI недостъпен. Попълни ръчно.', 'de': 'KI nicht verfügbar. Manuell ausfüllen.', 'fr': 'IA indisponible. Remplissez manuellement.', 'it': 'IA non disponibile. Compilare manualmente.', 'el': 'AI μη διαθέσιμο. Συμπλήρωσε χειροκίνητα.', 'es': 'IA no disponible. Rellena manualmente.', 'pt': 'IA indisponível. Preencha manualmente.', 'ru': 'AI недоступен. Заполните вручную.', 'tr': 'AI kullanılamıyor. Lütfen manuel doldurun.', 'ja': 'AIを利用できません。手動で入力してください。'});
  String get aiBreakdownTitle => _t({'en': 'AI Subtasks', 'bg': 'AI подзадачи', 'de': 'KI-Unteraufgaben', 'fr': 'Sous-tâches IA', 'it': 'Sottotask IA', 'el': 'Υποεργασίες ΑΙ', 'es': 'Subtareas IA', 'pt': 'Subtarefas IA', 'ru': 'AI подзадачи', 'tr': 'AI Alt Görevler', 'ja': 'AIサブタスク'});
  String get aiBreakdownApply => _t({'en': 'Apply', 'bg': 'Приложи', 'de': 'Übernehmen', 'fr': 'Appliquer', 'it': 'Applica', 'el': 'Εφαρμογή', 'es': 'Aplicar', 'pt': 'Aplicar', 'ru': 'Применить', 'tr': 'Uygula', 'ja': '適用'});

  // ----- AI настройки + rate limit -----
  String get aiSettings => _t({'en': 'AI Settings', 'bg': 'AI настройки', 'de': 'KI-Einstellungen', 'fr': 'Paramètres IA', 'it': 'Impostazioni IA', 'el': 'Ρυθμίσεις AI', 'es': 'Ajustes de IA', 'pt': 'Configurações de IA', 'ru': 'Настройки AI', 'tr': 'AI Ayarları', 'ja': 'AI設定'});
  String get aiSettingsSubtitle => _t({'en': 'Save time with smart text and voice', 'bg': 'Спести време с умен текст и глас', 'de': 'Spare Zeit mit smartem Text und Sprache', 'fr': 'Gagnez du temps avec le texte intelligent et la voix', 'it': 'Risparmia tempo con testo intelligente e voce', 'el': 'Κέρδισε χρόνο με έξυπνο κείμενο και φωνή', 'es': 'Ahorra tiempo con texto inteligente y voz', 'pt': 'Ganhe tempo com texto inteligente e voz', 'ru': 'Экономьте время: умный ввод и голос', 'tr': 'Akıllı metin ve sesle zaman kazan', 'ja': 'スマート入力と音声で時短'});
  String get aiParsingSetting => _t({'en': 'AI parsing', 'bg': 'AI парсване', 'de': 'KI-Analyse', 'fr': 'Analyse IA', 'it': 'Analisi IA', 'el': 'Ανάλυση AI', 'es': 'Análisis IA', 'pt': 'Análise IA', 'ru': 'AI анализ', 'tr': 'AI analiz', 'ja': 'AI解析'});
  String get aiParsingSettingDesc => _t({'en': 'Auto-fill task details from text', 'bg': 'Авто-попълване на детайли от текста', 'de': 'Aufgabendetails aus Text ausfüllen', 'fr': 'Remplir les détails depuis le texte', 'it': 'Compila i dettagli dal testo', 'el': 'Αυτόματη συμπλήρωση από κείμενο', 'es': 'Rellenar detalles desde el texto', 'pt': 'Preencher detalhes a partir do texto', 'ru': 'Автозаполнение деталей из текста', 'tr': 'Metinden görev detaylarını doldur', 'ja': 'テキストからタスクの詳細を自動入力'});
  String get voiceInputSetting => _t({'en': 'Voice input', 'bg': 'Гласово въвеждане', 'de': 'Spracheingabe', 'fr': 'Saisie vocale', 'it': 'Input vocale', 'el': 'Φωνητική εισαγωγή', 'es': 'Entrada de voz', 'pt': 'Entrada de voz', 'ru': 'Голосовой ввод', 'tr': 'Sesli giriş', 'ja': '音声入力'});
  String get voiceInputSettingDesc => _t({'en': 'Add tasks by speaking', 'bg': 'Добавяй задачи с глас', 'de': 'Aufgaben per Sprache hinzufügen', 'fr': 'Ajouter des tâches en parlant', 'it': 'Aggiungi attività parlando', 'el': 'Προσθήκη εργασιών με φωνή', 'es': 'Añadir tareas hablando', 'pt': 'Adicionar tarefas falando', 'ru': 'Добавляйте задачи голосом', 'tr': 'Konuşarak görev ekle', 'ja': '話してタスクを追加'});
  String get aiUsageSettingTitle => _t({'en': 'Daily AI usage', 'bg': 'Дневна AI употреба', 'de': 'Tägliche KI-Nutzung', 'fr': 'Usage IA quotidien', 'it': 'Uso IA giornaliero', 'el': 'Ημερήσια χρήση AI', 'es': 'Uso diario de IA', 'pt': 'Uso diário de IA', 'ru': 'Дневной лимит AI', 'tr': 'Günlük AI kullanımı', 'ja': '1日のAI使用量'});
  String aiUsageToday(int used, int limit) => _t({
    'en': 'Used today: $used/$limit',
    'bg': 'Използвани днес: $used/$limit',
    'de': 'Heute genutzt: $used/$limit',
    'fr': "Utilisé aujourd'hui : $used/$limit",
    'it': 'Usato oggi: $used/$limit',
    'el': 'Χρήση σήμερα: $used/$limit',
    'es': 'Usado hoy: $used/$limit',
    'pt': 'Usado hoje: $used/$limit',
    'ru': 'Использовано сегодня: $used/$limit',
    'tr': 'Bugün kullanılan: $used/$limit', 'ja': '本日の使用: $used/$limit',
  });
  String get aiLimitReached => _t({'en': "You've reached today's AI limit, try again tomorrow", 'bg': 'Достигна дневния лимит за AI, опитай утре', 'de': 'Tägliches KI-Limit erreicht, versuche es morgen', 'fr': "Limite IA quotidienne atteinte, réessaie demain", 'it': "Limite IA giornaliero raggiunto, riprova domani", 'el': 'Έφτασες το ημερήσιο όριο AI, δοκίμασε αύριο', 'es': 'Has alcanzado el límite diario de IA, inténtalo mañana', 'pt': 'Atingiste o limite diário de IA, tenta amanhã', 'ru': 'Достигнут дневной лимит AI, попробуйте завтра', 'tr': 'Günlük AI sınırına ulaştın, yarın tekrar dene', 'ja': '本日のAI上限に達しました。明日もう一度お試しください'});
  // ----- ФАЗА 2: мек AI limit UI (free) -----
  String get aiLimitTitle => _t({'en': 'Daily AI limit reached', 'bg': 'Достигна дневния AI лимит', 'de': 'Tägliches KI-Limit erreicht', 'fr': 'Limite IA quotidienne atteinte', 'it': 'Limite IA giornaliero raggiunto', 'el': 'Έφτασες το ημερήσιο όριο AI', 'es': 'Límite diario de IA alcanzado', 'pt': 'Limite diário de IA atingido', 'ru': 'Достигнут дневной лимит AI', 'tr': 'Günlük AI sınırına ulaşıldı', 'ja': '本日のAI上限に達しました'});
  String aiLimitBody(int n) => _t({
    'en': "You've used your $n free AI recognitions for today. With Premium they're unlimited.",
    'bg': 'Използва $n-те безплатни AI разпознавания за днес. С Premium са неограничени.',
    'de': 'Du hast deine $n kostenlosen KI-Erkennungen für heute genutzt. Mit Premium sind sie unbegrenzt.',
    'fr': "Vous avez utilisé vos $n reconnaissances IA gratuites pour aujourd'hui. Avec Premium, elles sont illimitées.",
    'it': 'Hai usato i tuoi $n riconoscimenti IA gratuiti per oggi. Con Premium sono illimitati.',
    'el': 'Χρησιμοποίησες τις $n δωρεάν αναγνωρίσεις AI για σήμερα. Με το Premium είναι απεριόριστες.',
    'es': 'Has usado tus $n reconocimientos de IA gratuitos de hoy. Con Premium son ilimitados.',
    'pt': 'Usaste os teus $n reconhecimentos de IA gratuitos de hoje. Com Premium são ilimitados.',
    'ru': 'Вы использовали свои $n бесплатных AI-распознаваний на сегодня. С Premium они безлимитны.',
    'tr': 'Bugünkü $n ücretsiz AI tanımanı kullandın. Premium ile sınırsız.',
    'ja': '本日の無料AI認識$n回を使い切りました。Premiumなら無制限です。',
  });
  String get aiSeePremium => _t({'en': 'See Premium', 'bg': 'Виж Premium', 'de': 'Premium ansehen', 'fr': 'Voir Premium', 'it': 'Scopri Premium', 'el': 'Δες το Premium', 'es': 'Ver Premium', 'pt': 'Ver Premium', 'ru': 'Открыть Premium', 'tr': "Premium'u gör", 'ja': 'Premiumを見る'});
  String get aiTomorrowAgain => _t({'en': 'Again tomorrow', 'bg': 'Утре отново', 'de': 'Morgen wieder', 'fr': 'Demain à nouveau', 'it': 'Di nuovo domani', 'el': 'Ξανά αύριο', 'es': 'Mañana otra vez', 'pt': 'Amanhã de novo', 'ru': 'Завтра снова', 'tr': 'Yarın tekrar', 'ja': 'また明日'});

  // ==================== VOICE INPUT ====================
  String get voiceListening => _t({'en': 'Listening...', 'bg': 'Слушам...', 'de': 'Höre zu...', 'fr': 'Écoute...', 'it': 'Ascolto...', 'el': 'Ακούω...', 'es': 'Escuchando...', 'pt': 'Ouvindo...', 'ru': 'Слушаю...', 'tr': 'Dinliyorum...', 'ja': '聞き取り中...'});
  String get voiceError => _t({'en': 'Microphone unavailable', 'bg': 'Микрофонът е недостъпен', 'de': 'Mikrofon nicht verfügbar', 'fr': 'Micro indisponible', 'it': 'Microfono non disponibile', 'el': 'Μικρόφωνο μη διαθέσιμο', 'es': 'Micrófono no disponible', 'pt': 'Microfone indisponível', 'ru': 'Микрофон недоступен', 'tr': 'Mikrofon kullanılamıyor', 'ja': 'マイクを利用できません'});
  String get voiceNoSpeech => _t({'en': "Didn't catch that, try again", 'bg': 'Не те разбрах, опитай пак', 'de': 'Nicht verstanden, versuche es erneut', 'fr': "Je n'ai pas compris, réessaie", 'it': 'Non ho capito, riprova', 'el': 'Δεν το έπιασα, δοκίμασε ξανά', 'es': 'No te entendí, inténtalo de nuevo', 'pt': 'Não entendi, tenta de novo', 'ru': 'Не расслышал, попробуйте ещё раз', 'tr': 'Anlayamadım, tekrar dene', 'ja': '聞き取れませんでした。もう一度お試しください'});
  String get voiceLangUnsupported => _t({'en': 'Voice input is not available for this language on iOS', 'bg': 'Гласовото въвеждане не е налично за този език на iOS', 'de': 'Spracheingabe ist für diese Sprache unter iOS nicht verfügbar', 'fr': "La saisie vocale n'est pas disponible pour cette langue sur iOS", 'it': "L'inserimento vocale non è disponibile per questa lingua su iOS", 'el': 'Η φωνητική εισαγωγή δεν είναι διαθέσιμη για αυτή τη γλώσσα στο iOS', 'es': 'La entrada de voz no está disponible para este idioma en iOS', 'pt': 'A entrada de voz não está disponível para este idioma no iOS', 'ru': 'Голосовой ввод недоступен для этого языка на iOS', 'tr': "Sesli giriş bu dilde iOS'ta kullanılamıyor", 'ja': 'iOSではこの言語の音声入力を利用できません'});

  String get markAsDone => _t({'en': 'Mark as done', 'bg': 'Маркирай като завършена', 'de': 'Als erledigt markieren', 'fr': 'Marquer comme fait', 'it': 'Segna come fatto', 'el': 'Σημείωσε ως ολοκληρωμένο', 'es': 'Marcar como hecho', 'pt': 'Marcar como concluído', 'ru': 'Отметить как выполненное', 'tr': 'Tamamlandı olarak işaretle', 'ja': '完了にする'});

  // ==================== СПОДЕЛЕНИ ГРУПИ ====================
  String get sharedTab => _t({'en': 'Shared', 'bg': 'Споделени', 'de': 'Geteilt', 'fr': 'Partagé', 'it': 'Condivisi', 'el': 'Κοινά', 'es': 'Compartido', 'pt': 'Partilhado', 'ru': 'Общие', 'tr': 'Paylaşılan', 'ja': '共有'});
  String get sharedSignInPrompt => _t({'en': 'Share lists with family or your team — the shopping run, the trip, the project. Sign in to create and join shared lists.', 'bg': 'Сподели списък със семейството или екипа — пазарът, ваканцията, проектът. Влез, за да създаваш и да се присъединяваш към споделени списъци.', 'de': 'Teile Listen mit Familie oder Team — Einkauf, Reise, Projekt. Melde dich an, um geteilte Listen zu erstellen und beizutreten.', 'fr': 'Partage des listes avec ta famille ou ton équipe — les courses, le voyage, le projet. Connecte-toi pour créer et rejoindre des listes partagées.', 'it': 'Condividi liste con la famiglia o il team — la spesa, il viaggio, il progetto. Accedi per creare e unirti a liste condivise.', 'el': 'Μοιράσου λίστες με την οικογένεια ή την ομάδα — τα ψώνια, το ταξίδι, το έργο. Συνδέσου για να φτιάχνεις και να μπαίνεις σε κοινές λίστες.', 'es': 'Comparte listas con la familia o tu equipo — la compra, el viaje, el proyecto. Inicia sesión para crear y unirte a listas compartidas.', 'pt': 'Partilha listas com a família ou a equipa — as compras, a viagem, o projeto. Inicia sessão para criar e juntar-te a listas partilhadas.', 'ru': 'Делись списками с семьёй или командой — покупки, поездка, проект. Войди, чтобы создавать и присоединяться к общим спискам.', 'tr': 'Listeleri ailenle veya ekibinle paylaş — alışveriş, tatil, proje. Paylaşılan listeler oluşturmak ve katılmak için giriş yap.', 'ja': '家族やチームとリストを共有 — 買い物、旅行、プロジェクト。ログインして共有リストの作成や参加ができます。'});
  String get sharedEmpty => _t({'en': 'Share a list with family or your team — the shopping run, the trip, the project. Create your first group.', 'bg': 'Сподели списък със семейството или екипа — пазарът, ваканцията, проектът. Създай първата си група.', 'de': 'Teile eine Liste mit Familie oder Team — Einkauf, Reise, Projekt. Erstelle deine erste Gruppe.', 'fr': 'Partage une liste avec ta famille ou ton équipe — les courses, le voyage, le projet. Crée ton premier groupe.', 'it': 'Condividi una lista con la famiglia o il team — la spesa, il viaggio, il progetto. Crea il tuo primo gruppo.', 'el': 'Μοιράσου μια λίστα με την οικογένεια ή την ομάδα — τα ψώνια, το ταξίδι, το έργο. Δημιούργησε την πρώτη σου ομάδα.', 'es': 'Comparte una lista con la familia o tu equipo — la compra, el viaje, el proyecto. Crea tu primer grupo.', 'pt': 'Partilha uma lista com a família ou a equipa — as compras, a viagem, o projeto. Cria o teu primeiro grupo.', 'ru': 'Поделись списком с семьёй или командой — покупки, поездка, проект. Создай свою первую группу.', 'tr': 'Bir listeyi ailenle veya ekibinle paylaş — alışveriş, tatil, proje. İlk grubunu oluştur.', 'ja': '家族やチームとリストを共有 — 買い物、旅行、プロジェクト。最初のグループを作ろう。'});
  String get newGroup => _t({'en': 'New group', 'bg': 'Нова група', 'de': 'Neue Gruppe', 'fr': 'Nouveau groupe', 'it': 'Nuovo gruppo', 'el': 'Νέα ομάδα', 'es': 'Nuevo grupo', 'pt': 'Novo grupo', 'ru': 'Новая группа', 'tr': 'Yeni grup', 'ja': '新しいグループ'});
  String get groupNameHint => _t({'en': 'Group name (e.g. Home, Trip, Team)', 'bg': 'Име на групата (напр. Вкъщи, Пътуване, Екип)', 'de': 'Gruppenname (z. B. Zuhause, Reise, Team)', 'fr': 'Nom du groupe (ex. Maison, Voyage, Équipe)', 'it': 'Nome del gruppo (es. Casa, Viaggio, Team)', 'el': 'Όνομα ομάδας (π.χ. Σπίτι, Ταξίδι, Ομάδα)', 'es': 'Nombre del grupo (ej. Casa, Viaje, Equipo)', 'pt': 'Nome do grupo (ex. Casa, Viagem, Equipa)', 'ru': 'Название группы (напр. Дом, Поездка, Команда)', 'tr': 'Grup adı (örn. Ev, Gezi, Ekip)', 'ja': 'グループ名（例：家、旅行、チーム）'});
  String get createGroupAction => _t({'en': 'Create', 'bg': 'Създай', 'de': 'Erstellen', 'fr': 'Créer', 'it': 'Crea', 'el': 'Δημιουργία', 'es': 'Crear', 'pt': 'Criar', 'ru': 'Создать', 'tr': 'Oluştur', 'ja': '作成'});
  String get joinWithCode => _t({'en': 'Join with code', 'bg': 'Присъедини се с код', 'de': 'Mit Code beitreten', 'fr': 'Rejoindre avec un code', 'it': 'Unisciti con codice', 'el': 'Συμμετοχή με κωδικό', 'es': 'Unirse con código', 'pt': 'Juntar-se com código', 'ru': 'Войти по коду', 'tr': 'Kodla katıl', 'ja': 'コードで参加'});
  String get joinCodeHint => _t({'en': 'Enter the code', 'bg': 'Въведи кода', 'de': 'Code eingeben', 'fr': 'Saisis le code', 'it': 'Inserisci il codice', 'el': 'Εισήγαγε τον κωδικό', 'es': 'Introduce el código', 'pt': 'Introduz o código', 'ru': 'Введи код', 'tr': 'Kodu gir', 'ja': 'コードを入力'});
  String get joinAction => _t({'en': 'Join', 'bg': 'Присъедини се', 'de': 'Beitreten', 'fr': 'Rejoindre', 'it': 'Unisciti', 'el': 'Συμμετοχή', 'es': 'Unirse', 'pt': 'Juntar-se', 'ru': 'Войти', 'tr': 'Katıl', 'ja': '参加'});
  String get inviteTitle => _t({'en': 'Invite', 'bg': 'Покани', 'de': 'Einladen', 'fr': 'Inviter', 'it': 'Invita', 'el': 'Πρόσκληση', 'es': 'Invitar', 'pt': 'Convidar', 'ru': 'Пригласить', 'tr': 'Davet et', 'ja': '招待'});
  String get inviteSubtitle => _t({'en': 'Share this code so others can join the list.', 'bg': 'Сподели този код, за да се присъединят и други към списъка.', 'de': 'Teile diesen Code, damit andere der Liste beitreten können.', 'fr': 'Partage ce code pour que d’autres rejoignent la liste.', 'it': 'Condividi questo codice così altri possono unirsi alla lista.', 'el': 'Μοιράσου αυτόν τον κωδικό για να μπουν κι άλλοι στη λίστα.', 'es': 'Comparte este código para que otros se unan a la lista.', 'pt': 'Partilha este código para que outros se juntem à lista.', 'ru': 'Поделись этим кодом, чтобы другие присоединились к списку.', 'tr': 'Başkalarının listeye katılması için bu kodu paylaş.', 'ja': 'このコードを共有して、他の人をリストに招待しよう。'});
  String get shareInvite => _t({'en': 'Share', 'bg': 'Сподели', 'de': 'Teilen', 'fr': 'Partager', 'it': 'Condividi', 'el': 'Κοινοποίηση', 'es': 'Compartir', 'pt': 'Partilhar', 'ru': 'Поделиться', 'tr': 'Paylaş', 'ja': '共有'});
  String get members => _t({'en': 'Members', 'bg': 'Членове', 'de': 'Mitglieder', 'fr': 'Membres', 'it': 'Membri', 'el': 'Μέλη', 'es': 'Miembros', 'pt': 'Membros', 'ru': 'Участники', 'tr': 'Üyeler', 'ja': 'メンバー'});
  String get ownerLabel => _t({'en': 'Owner', 'bg': 'Собственик', 'de': 'Eigentümer', 'fr': 'Propriétaire', 'it': 'Proprietario', 'el': 'Ιδιοκτήτης', 'es': 'Propietario', 'pt': 'Proprietário', 'ru': 'Владелец', 'tr': 'Sahip', 'ja': 'オーナー'});
  String get leaveGroup => _t({'en': 'Leave group', 'bg': 'Напусни групата', 'de': 'Gruppe verlassen', 'fr': 'Quitter le groupe', 'it': 'Abbandona il gruppo', 'el': 'Αποχώρηση από την ομάδα', 'es': 'Salir del grupo', 'pt': 'Sair do grupo', 'ru': 'Покинуть группу', 'tr': 'Gruptan ayrıl', 'ja': 'グループを退出'});
  String get leaveGroupConfirm => _t({'en': 'Leave this group? You can rejoin later with the code.', 'bg': 'Да напуснеш ли групата? Можеш да се върнеш по-късно с кода.', 'de': 'Diese Gruppe verlassen? Du kannst später mit dem Code wieder beitreten.', 'fr': 'Quitter ce groupe ? Tu peux revenir plus tard avec le code.', 'it': 'Abbandonare il gruppo? Puoi rientrare più tardi con il codice.', 'el': 'Αποχώρηση από την ομάδα; Μπορείς να ξαναμπείς αργότερα με τον κωδικό.', 'es': '¿Salir de este grupo? Puedes volver más tarde con el código.', 'pt': 'Sair deste grupo? Podes voltar mais tarde com o código.', 'ru': 'Покинуть группу? Вернуться можно позже по коду.', 'tr': 'Bu gruptan ayrılmak istiyor musun? Daha sonra kodla tekrar katılabilirsin.', 'ja': 'このグループを退出しますか？後でコードで再参加できます。'});
  String get deleteGroup => _t({'en': 'Delete group', 'bg': 'Изтрий групата', 'de': 'Gruppe löschen', 'fr': 'Supprimer le groupe', 'it': 'Elimina gruppo', 'el': 'Διαγραφή ομάδας', 'es': 'Eliminar grupo', 'pt': 'Eliminar grupo', 'ru': 'Удалить группу', 'tr': 'Grubu sil', 'ja': 'グループを削除'});
  String get deleteGroupConfirm => _t({'en': 'Delete this group for everyone? All its tasks will be removed. This cannot be undone.', 'bg': 'Да изтрия групата за всички? Всичките ѝ задачи ще се премахнат. Това е необратимо.', 'de': 'Diese Gruppe für alle löschen? Alle Aufgaben werden entfernt. Dies kann nicht rückgängig gemacht werden.', 'fr': 'Supprimer ce groupe pour tout le monde ? Toutes ses tâches seront supprimées. Action irréversible.', 'it': 'Eliminare il gruppo per tutti? Tutte le sue attività saranno rimosse. Non è reversibile.', 'el': 'Διαγραφή της ομάδας για όλους; Όλες οι εργασίες της θα αφαιρεθούν. Δεν αναιρείται.', 'es': '¿Eliminar este grupo para todos? Se borrarán todas sus tareas. No se puede deshacer.', 'pt': 'Eliminar este grupo para todos? Todas as suas tarefas serão removidas. Não pode ser desfeito.', 'ru': 'Удалить группу для всех? Все её задачи будут удалены. Это необратимо.', 'tr': 'Bu grubu herkes için sil? Tüm görevleri kaldırılacak. Geri alınamaz.', 'ja': 'このグループを全員から削除しますか？すべてのタスクが削除されます。元に戻せません。'});
  String get groupAddTask => _t({'en': 'Add task', 'bg': 'Добави задача', 'de': 'Aufgabe hinzufügen', 'fr': 'Ajouter une tâche', 'it': 'Aggiungi attività', 'el': 'Προσθήκη εργασίας', 'es': 'Añadir tarea', 'pt': 'Adicionar tarefa', 'ru': 'Добавить задачу', 'tr': 'Görev ekle', 'ja': 'タスクを追加'});
  String get groupTaskHint => _t({'en': 'What needs to be done?', 'bg': 'Какво трябва да се направи?', 'de': 'Was ist zu tun?', 'fr': 'Que faut-il faire ?', 'it': 'Cosa va fatto?', 'el': 'Τι πρέπει να γίνει;', 'es': '¿Qué hay que hacer?', 'pt': 'O que é preciso fazer?', 'ru': 'Что нужно сделать?', 'tr': 'Ne yapılmalı?', 'ja': '何をする？'});
  String get groupTasksEmpty => _t({'en': 'No tasks yet. Add the first one — everyone in the group will see it.', 'bg': 'Още няма задачи. Добави първата — всички в групата ще я видят.', 'de': 'Noch keine Aufgaben. Füge die erste hinzu — alle in der Gruppe sehen sie.', 'fr': 'Aucune tâche pour l’instant. Ajoute la première — tout le groupe la verra.', 'it': 'Ancora nessuna attività. Aggiungi la prima — la vedranno tutti nel gruppo.', 'el': 'Καμία εργασία ακόμη. Πρόσθεσε την πρώτη — θα τη δουν όλοι στην ομάδα.', 'es': 'Aún no hay tareas. Añade la primera — todos en el grupo la verán.', 'pt': 'Ainda sem tarefas. Adiciona a primeira — todos no grupo a verão.', 'ru': 'Пока нет задач. Добавь первую — её увидят все в группе.', 'tr': 'Henüz görev yok. İlkini ekle — gruptaki herkes görecek.', 'ja': 'まだタスクがありません。最初の1件を追加しよう — グループ全員に表示されます。'});
  String get onlyAuthorCanManage => _t({'en': 'Only the person who added this task can complete or delete it.', 'bg': 'Само този, който е добавил задачата, може да я завърши или изтрие.', 'de': 'Nur wer die Aufgabe hinzugefügt hat, kann sie abschließen oder löschen.', 'fr': 'Seule la personne qui a ajouté cette tâche peut la terminer ou la supprimer.', 'it': 'Solo chi ha aggiunto questa attività può completarla o eliminarla.', 'el': 'Μόνο όποιος πρόσθεσε την εργασία μπορεί να την ολοκληρώσει ή να τη διαγράψει.', 'es': 'Solo quien añadió esta tarea puede completarla o eliminarla.', 'pt': 'Só quem adicionou esta tarefa a pode concluir ou eliminar.', 'ru': 'Только тот, кто добавил задачу, может завершить или удалить её.', 'tr': 'Bu görevi yalnızca ekleyen kişi tamamlayabilir veya silebilir.', 'ja': 'このタスクを完了・削除できるのは追加した本人だけです。'});
  String get groupErrOwnerLimit => _t({'en': "You've reached the limit of groups you can own.", 'bg': 'Достигна лимита групи, на които можеш да си собственик.', 'de': 'Du hast die Grenze der Gruppen erreicht, die du besitzen kannst.', 'fr': 'Tu as atteint la limite de groupes que tu peux posséder.', 'it': 'Hai raggiunto il limite di gruppi che puoi possedere.', 'el': 'Έφτασες το όριο ομάδων που μπορείς να έχεις.', 'es': 'Has alcanzado el límite de grupos que puedes tener.', 'pt': 'Atingiste o limite de grupos que podes ter.', 'ru': 'Достигнут лимит групп, которыми ты можешь владеть.', 'tr': 'Sahip olabileceğin grup sınırına ulaştın.', 'ja': '所有できるグループ数の上限に達しました。'});
  String get groupErrMemberLimit => _t({'en': 'This group is full.', 'bg': 'Групата е пълна.', 'de': 'Diese Gruppe ist voll.', 'fr': 'Ce groupe est complet.', 'it': 'Questo gruppo è pieno.', 'el': 'Αυτή η ομάδα είναι γεμάτη.', 'es': 'Este grupo está lleno.', 'pt': 'Este grupo está cheio.', 'ru': 'Группа заполнена.', 'tr': 'Bu grup dolu.', 'ja': 'このグループは満員です。'});
  String get groupErrTaskLimit => _t({'en': 'This group has reached its task limit.', 'bg': 'Групата достигна лимита си от задачи.', 'de': 'Diese Gruppe hat ihr Aufgabenlimit erreicht.', 'fr': 'Ce groupe a atteint sa limite de tâches.', 'it': 'Questo gruppo ha raggiunto il limite di attività.', 'el': 'Αυτή η ομάδα έφτασε το όριο εργασιών.', 'es': 'Este grupo alcanzó su límite de tareas.', 'pt': 'Este grupo atingiu o limite de tarefas.', 'ru': 'Группа достигла лимита задач.', 'tr': 'Bu grup görev sınırına ulaştı.', 'ja': 'このグループはタスク数の上限に達しました。'});
  String get groupErrInvalidCode => _t({'en': "That code doesn't match any group.", 'bg': 'Този код не съответства на група.', 'de': 'Dieser Code passt zu keiner Gruppe.', 'fr': 'Ce code ne correspond à aucun groupe.', 'it': 'Questo codice non corrisponde a nessun gruppo.', 'el': 'Αυτός ο κωδικός δεν αντιστοιχεί σε καμία ομάδα.', 'es': 'Ese código no coincide con ningún grupo.', 'pt': 'Esse código não corresponde a nenhum grupo.', 'ru': 'Этот код не соответствует ни одной группе.', 'tr': 'Bu kod hiçbir grupla eşleşmiyor.', 'ja': 'そのコードに一致するグループがありません。'});
  String get groupErrGeneric => _t({'en': 'Something went wrong. Please try again.', 'bg': 'Нещо се обърка. Опитай пак.', 'de': 'Etwas ist schiefgelaufen. Bitte erneut versuchen.', 'fr': 'Une erreur est survenue. Réessaie.', 'it': 'Qualcosa è andato storto. Riprova.', 'el': 'Κάτι πήγε στραβά. Δοκίμασε ξανά.', 'es': 'Algo salió mal. Inténtalo de nuevo.', 'pt': 'Algo correu mal. Tenta novamente.', 'ru': 'Что-то пошло не так. Попробуй ещё раз.', 'tr': 'Bir şeyler ters gitti. Tekrar dene.', 'ja': '問題が発生しました。もう一度お試しください。'});
  String completedByName(String name) => _t({'en': 'completed by {n}', 'bg': 'завършена от {n}', 'de': 'erledigt von {n}', 'fr': 'terminée par {n}', 'it': 'completata da {n}', 'el': 'ολοκληρώθηκε από {n}', 'es': 'completada por {n}', 'pt': 'concluída por {n}', 'ru': 'выполнил(а) {n}', 'tr': '{n} tamamladı', 'ja': '{n} が完了'}).replaceAll('{n}', name);
  String joinedGroup(String name) => _t({'en': "Done! You're in '{n}' 🎉", 'bg': "Готово! Вече си в '{n}' 🎉", 'de': "Fertig! Du bist in '{n}' 🎉", 'fr': "C'est fait ! Tu es dans '{n}' 🎉", 'it': "Fatto! Sei in '{n}' 🎉", 'el': "Έτοιμο! Είσαι στην '{n}' 🎉", 'es': "¡Listo! Ya estás en '{n}' 🎉", 'pt': "Pronto! Já estás em '{n}' 🎉", 'ru': "Готово! Ты в '{n}' 🎉", 'tr': "Tamam! Artık '{n}' içindesin 🎉", 'ja': "完了！「{n}」に参加しました 🎉"}).replaceAll('{n}', name);
  String membersCount(int n) => _t({'en': '{n} members', 'bg': '{n} члена', 'de': '{n} Mitglieder', 'fr': '{n} membres', 'it': '{n} membri', 'el': '{n} μέλη', 'es': '{n} miembros', 'pt': '{n} membros', 'ru': 'участников: {n}', 'tr': '{n} üye', 'ja': 'メンバー {n} 人'}).replaceAll('{n}', '$n');
  String get displayName => _t({'en': 'Name', 'bg': 'Име', 'de': 'Name', 'fr': 'Nom', 'it': 'Nome', 'el': 'Όνομα', 'es': 'Nombre', 'pt': 'Nome', 'ru': 'Имя', 'tr': 'İsim', 'ja': '名前'});
  String get displayNameDesc => _t({'en': 'How others see you in shared lists', 'bg': 'Как другите те виждат в споделените списъци', 'de': 'Wie andere dich in geteilten Listen sehen', 'fr': 'Comment les autres te voient dans les listes partagées', 'it': 'Come ti vedono gli altri nelle liste condivise', 'el': 'Πώς σε βλέπουν οι άλλοι στις κοινές λίστες', 'es': 'Cómo te ven los demás en las listas compartidas', 'pt': 'Como os outros te veem nas listas partilhadas', 'ru': 'Как другие видят тебя в общих списках', 'tr': 'Paylaşılan listelerde başkaları seni nasıl görür', 'ja': '共有リストで他の人に表示される名前'});
  String get addName => _t({'en': 'Add a name', 'bg': 'Добави име', 'de': 'Namen hinzufügen', 'fr': 'Ajouter un nom', 'it': 'Aggiungi un nome', 'el': 'Πρόσθεσε όνομα', 'es': 'Añadir un nombre', 'pt': 'Adicionar um nome', 'ru': 'Добавить имя', 'tr': 'İsim ekle', 'ja': '名前を追加'});
}