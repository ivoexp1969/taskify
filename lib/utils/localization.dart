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
  String get tasks => _t({'en': 'Tasks', 'bg': 'Задачи', 'de': 'Aufgaben', 'fr': 'Tâches', 'it': 'Attività', 'el': 'Εργασίες', 'es': 'Tareas', 'pt': 'Tarefas', 'ru': 'Задачи', 'tr': 'Görevler'});
  String get calendar => _t({'en': 'Calendar', 'bg': 'Календар', 'de': 'Kalender', 'fr': 'Calendrier', 'it': 'Calendario', 'el': 'Ημερολόγιο', 'es': 'Calendario', 'pt': 'Calendário', 'ru': 'Календарь', 'tr': 'Takvim'});
  String get settings => _t({'en': 'Settings', 'bg': 'Настройки', 'de': 'Einstellungen', 'fr': 'Paramètres', 'it': 'Impostazioni', 'el': 'Ρυθμίσεις', 'es': 'Ajustes', 'pt': 'Configurações', 'ru': 'Настройки', 'tr': 'Ayarlar'});

  // ==================== СТАТИСТИКА ====================
  String get total => _t({'en': 'Total', 'bg': 'Общо', 'de': 'Gesamt', 'fr': 'Total', 'it': 'Totale', 'el': 'Σύνολο', 'es': 'Total', 'pt': 'Total', 'ru': 'Всего', 'tr': 'Toplam'});
  String get completed => _t({'en': 'Completed', 'bg': 'Завършени', 'de': 'Erledigt', 'fr': 'Terminées', 'it': 'Completate', 'el': 'Ολοκληρωμένες', 'es': 'Completadas', 'pt': 'Concluídas', 'ru': 'Завершено', 'tr': 'Tamamlandı'});
  String get overdue => _t({'en': 'Overdue', 'bg': 'Просрочени', 'de': 'Überfällig', 'fr': 'En retard', 'it': 'Scadute', 'el': 'Εκπρόθεσμες', 'es': 'Vencidas', 'pt': 'Atrasadas', 'ru': 'Просрочено', 'tr': 'Gecikmiş'});
  String get upcoming => _t({'en': 'Upcoming', 'bg': 'Предстоящи', 'de': 'Bevorstehend', 'fr': 'À venir', 'it': 'In arrivo', 'el': 'Επερχόμενες', 'es': 'Próximas', 'pt': 'Próximas', 'ru': 'Предстоящие', 'tr': 'Yaklaşan'});
  String get activity => _t({'en': 'Activity', 'bg': 'Активност', 'de': 'Aktivität', 'fr': 'Activité', 'it': 'Attività', 'el': 'Δραστηριότητα', 'es': 'Actividad', 'pt': 'Atividade', 'ru': 'Активность', 'tr': 'Etkinlik'});
  String get taskView => _t({'en': 'Task View', 'bg': 'Изглед на задачите', 'de': 'Aufgabenansicht', 'fr': 'Vue des tâches', 'it': 'Vista attività', 'el': 'Προβολή εργασιών', 'es': 'Vista de tareas', 'pt': 'Visualização', 'ru': 'Вид задач', 'tr': 'Görev Görünümü'});
  String get viewExpanded => _t({'en': 'Expanded', 'bg': 'Разширен', 'de': 'Erweitert', 'fr': 'Étendu', 'it': 'Espanso', 'el': 'Αναπτυγμένη', 'es': 'Expandido', 'pt': 'Expandido', 'ru': 'Расширенный', 'tr': 'Genişletilmiş'});
  String get viewExpandedDesc => _t({'en': 'With details and badges', 'bg': 'С детайли и значки', 'de': 'Mit Details', 'fr': 'Avec détails', 'it': 'Con dettagli', 'el': 'Με λεπτομέρειες', 'es': 'Con detalles', 'pt': 'Com detalhes', 'ru': 'С подробностями', 'tr': 'Detaylarla'});
  String get viewCompact => _t({'en': 'Compact', 'bg': 'Компактен', 'de': 'Kompakt', 'fr': 'Compact', 'it': 'Compatto', 'el': 'Συμπαγής', 'es': 'Compacto', 'pt': 'Compacto', 'ru': 'Компактный', 'tr': 'Kompakt'});
  String get viewCompactDesc => _t({'en': 'Less space, more tasks', 'bg': 'По-малко място, повече задачи', 'de': 'Weniger Platz', 'fr': 'Moins de place', 'it': 'Meno spazio', 'el': 'Λιγότερος χώρος', 'es': 'Menos espacio', 'pt': 'Menos espaço', 'ru': 'Меньше места', 'tr': 'Daha az alan'});

  String get statistics => _t({'en': 'Statistics', 'bg': 'Статистики', 'de': 'Statistiken', 'fr': 'Statistiques', 'it': 'Statistiche', 'el': 'Στατιστικά', 'es': 'Estadísticas', 'pt': 'Estatísticas', 'ru': 'Статистика', 'tr': 'İstatistikler'});
  String get viewProgress => _t({'en': 'View your progress', 'bg': 'Преглед на твоя прогрес', 'de': 'Zeige deinen Fortschritt', 'fr': 'Voir votre progression', 'it': 'Visualizza i tuoi progressi', 'el': 'Δείτε την πρόοδό σας', 'es': 'Ver tu progreso', 'pt': 'Ver seu progresso', 'ru': 'Посмотреть прогресс', 'tr': 'İlerlemenizi görün'});
  String get today => _t({'en': 'Today', 'bg': 'Днес', 'de': 'Heute', 'fr': "Aujourd'hui", 'it': 'Oggi', 'el': 'Σήμερα', 'es': 'Hoy', 'pt': 'Hoje', 'ru': 'Сегодня', 'tr': 'Bugün'});
  String get week => _t({'en': 'Week', 'bg': 'Седмица', 'de': 'Woche', 'fr': 'Semaine', 'it': 'Settimana', 'el': 'Εβδομάδα', 'es': 'Semana', 'pt': 'Semana', 'ru': 'Неделя', 'tr': 'Hafta'});
  String get month => _t({'en': 'Month', 'bg': 'Месец', 'de': 'Monat', 'fr': 'Mois', 'it': 'Mese', 'el': 'Μήνας', 'es': 'Mes', 'pt': 'Mês', 'ru': 'Месяц', 'tr': 'Ay'});
  String get day => _t({'en': 'Day', 'bg': 'Ден', 'de': 'Tag', 'fr': 'Jour', 'it': 'Giorno', 'el': 'Ημέρα', 'es': 'Día', 'pt': 'Dia', 'ru': 'День', 'tr': 'Gün'});
  String get task => _t({'en': 'task', 'bg': 'задача', 'de': 'Aufgabe', 'fr': 'tâche', 'it': 'attività', 'el': 'εργασία', 'es': 'tarea', 'pt': 'tarefa', 'ru': 'задача', 'tr': 'görev'});
  String get noTasks => _t({'en': 'No tasks for this day', 'bg': 'Няма задачи за този ден', 'de': 'Keine Aufgaben für diesen Tag', 'fr': 'Pas de tâches pour ce jour', 'it': 'Nessuna attività per questo giorno', 'el': 'Δεν υπάρχουν εργασίες για αυτή την ημέρα', 'es': 'No hay tareas para este día', 'pt': 'Sem tarefas para este dia', 'ru': 'Нет задач на этот день', 'tr': 'Bu gün için görev yok'});
  String get taskTitle => _t({'en': 'Task title', 'bg': 'Заглавие на задача', 'de': 'Aufgabentitel', 'fr': 'Titre de la tâche', 'it': 'Titolo attività', 'el': 'Τίτλος εργασίας', 'es': 'Título de tarea', 'pt': 'Título da tarefa', 'ru': 'Название задачи', 'tr': 'Görev başlığı'});

  // ==================== ДНИ НА СЕДМИЦАТА (ПЪЛНИ) ====================
  String get monday => _t({'en': 'Monday', 'bg': 'Понеделник', 'de': 'Montag', 'fr': 'Lundi', 'it': 'Lunedì', 'el': 'Δευτέρα', 'es': 'Lunes', 'pt': 'Segunda-feira', 'ru': 'Понедельник', 'tr': 'Pazartesi'});
  String get tuesday => _t({'en': 'Tuesday', 'bg': 'Вторник', 'de': 'Dienstag', 'fr': 'Mardi', 'it': 'Martedì', 'el': 'Τρίτη', 'es': 'Martes', 'pt': 'Terça-feira', 'ru': 'Вторник', 'tr': 'Salı'});
  String get wednesday => _t({'en': 'Wednesday', 'bg': 'Сряда', 'de': 'Mittwoch', 'fr': 'Mercredi', 'it': 'Mercoledì', 'el': 'Τετάρτη', 'es': 'Miércoles', 'pt': 'Quarta-feira', 'ru': 'Среда', 'tr': 'Çarşamba'});
  String get thursday => _t({'en': 'Thursday', 'bg': 'Четвъртък', 'de': 'Donnerstag', 'fr': 'Jeudi', 'it': 'Giovedì', 'el': 'Πέμπτη', 'es': 'Jueves', 'pt': 'Quinta-feira', 'ru': 'Четверг', 'tr': 'Perşembe'});
  String get friday => _t({'en': 'Friday', 'bg': 'Петък', 'de': 'Freitag', 'fr': 'Vendredi', 'it': 'Venerdì', 'el': 'Παρασκευή', 'es': 'Viernes', 'pt': 'Sexta-feira', 'ru': 'Пятница', 'tr': 'Cuma'});
  String get saturday => _t({'en': 'Saturday', 'bg': 'Събота', 'de': 'Samstag', 'fr': 'Samedi', 'it': 'Sabato', 'el': 'Σάββατο', 'es': 'Sábado', 'pt': 'Sábado', 'ru': 'Суббота', 'tr': 'Cumartesi'});
  String get sunday => _t({'en': 'Sunday', 'bg': 'Неделя', 'de': 'Sonntag', 'fr': 'Dimanche', 'it': 'Domenica', 'el': 'Κυριακή', 'es': 'Domingo', 'pt': 'Domingo', 'ru': 'Воскресенье', 'tr': 'Pazar'});

  // ==================== ДНИ НА СЕДМИЦАТА (КРАТКИ) ====================
  String get mon => _t({'en': 'Mon', 'bg': 'Пон', 'de': 'Mo', 'fr': 'Lun', 'it': 'Lun', 'el': 'Δευ', 'es': 'Lun', 'pt': 'Seg', 'ru': 'Пн', 'tr': 'Pzt'});
  String get tue => _t({'en': 'Tue', 'bg': 'Вто', 'de': 'Di', 'fr': 'Mar', 'it': 'Mar', 'el': 'Τρι', 'es': 'Mar', 'pt': 'Ter', 'ru': 'Вт', 'tr': 'Sal'});
  String get wed => _t({'en': 'Wed', 'bg': 'Сря', 'de': 'Mi', 'fr': 'Mer', 'it': 'Mer', 'el': 'Τετ', 'es': 'Mié', 'pt': 'Qua', 'ru': 'Ср', 'tr': 'Çar'});
  String get thu => _t({'en': 'Thu', 'bg': 'Чет', 'de': 'Do', 'fr': 'Jeu', 'it': 'Gio', 'el': 'Πεμ', 'es': 'Jue', 'pt': 'Qui', 'ru': 'Чт', 'tr': 'Per'});
  String get fri => _t({'en': 'Fri', 'bg': 'Пет', 'de': 'Fr', 'fr': 'Ven', 'it': 'Ven', 'el': 'Παρ', 'es': 'Vie', 'pt': 'Sex', 'ru': 'Пт', 'tr': 'Cum'});
  String get sat => _t({'en': 'Sat', 'bg': 'Съб', 'de': 'Sa', 'fr': 'Sam', 'it': 'Sab', 'el': 'Σαβ', 'es': 'Sáb', 'pt': 'Sáb', 'ru': 'Сб', 'tr': 'Cmt'});
  String get sun => _t({'en': 'Sun', 'bg': 'Нед', 'de': 'So', 'fr': 'Dim', 'it': 'Dom', 'el': 'Κυρ', 'es': 'Dom', 'pt': 'Dom', 'ru': 'Вс', 'tr': 'Paz'});

  // ==================== МЕСЕЦИ ====================
  String get january => _t({'en': 'January', 'bg': 'Януари', 'de': 'Januar', 'fr': 'Janvier', 'it': 'Gennaio', 'el': 'Ιανουάριος', 'es': 'Enero', 'pt': 'Janeiro', 'ru': 'Январь', 'tr': 'Ocak'});
  String get february => _t({'en': 'February', 'bg': 'Февруари', 'de': 'Februar', 'fr': 'Février', 'it': 'Febbraio', 'el': 'Φεβρουάριος', 'es': 'Febrero', 'pt': 'Fevereiro', 'ru': 'Февраль', 'tr': 'Şubat'});
  String get march => _t({'en': 'March', 'bg': 'Март', 'de': 'März', 'fr': 'Mars', 'it': 'Marzo', 'el': 'Μάρτιος', 'es': 'Marzo', 'pt': 'Março', 'ru': 'Март', 'tr': 'Mart'});
  String get april => _t({'en': 'April', 'bg': 'Април', 'de': 'April', 'fr': 'Avril', 'it': 'Aprile', 'el': 'Απρίλιος', 'es': 'Abril', 'pt': 'Abril', 'ru': 'Апрель', 'tr': 'Nisan'});
  String get may => _t({'en': 'May', 'bg': 'Май', 'de': 'Mai', 'fr': 'Mai', 'it': 'Maggio', 'el': 'Μάιος', 'es': 'Mayo', 'pt': 'Maio', 'ru': 'Май', 'tr': 'Mayıs'});
  String get june => _t({'en': 'June', 'bg': 'Юни', 'de': 'Juni', 'fr': 'Juin', 'it': 'Giugno', 'el': 'Ιούνιος', 'es': 'Junio', 'pt': 'Junho', 'ru': 'Июнь', 'tr': 'Haziran'});
  String get july => _t({'en': 'July', 'bg': 'Юли', 'de': 'Juli', 'fr': 'Juillet', 'it': 'Luglio', 'el': 'Ιούλιος', 'es': 'Julio', 'pt': 'Julho', 'ru': 'Июль', 'tr': 'Temmuz'});
  String get august => _t({'en': 'August', 'bg': 'Август', 'de': 'August', 'fr': 'Août', 'it': 'Agosto', 'el': 'Αύγουστος', 'es': 'Agosto', 'pt': 'Agosto', 'ru': 'Август', 'tr': 'Ağustos'});
  String get september => _t({'en': 'September', 'bg': 'Септември', 'de': 'September', 'fr': 'Septembre', 'it': 'Settembre', 'el': 'Σεπτέμβριος', 'es': 'Septiembre', 'pt': 'Setembro', 'ru': 'Сентябрь', 'tr': 'Eylül'});
  String get october => _t({'en': 'October', 'bg': 'Октомври', 'de': 'Oktober', 'fr': 'Octobre', 'it': 'Ottobre', 'el': 'Οκτώβριος', 'es': 'Octubre', 'pt': 'Outubro', 'ru': 'Октябрь', 'tr': 'Ekim'});
  String get november => _t({'en': 'November', 'bg': 'Ноември', 'de': 'November', 'fr': 'Novembre', 'it': 'Novembre', 'el': 'Νοέμβριος', 'es': 'Noviembre', 'pt': 'Novembro', 'ru': 'Ноябрь', 'tr': 'Kasım'});
  String get december => _t({'en': 'December', 'bg': 'Декември', 'de': 'Dezember', 'fr': 'Décembre', 'it': 'Dicembre', 'el': 'Δεκέμβριος', 'es': 'Diciembre', 'pt': 'Dezembro', 'ru': 'Декабрь', 'tr': 'Aralık'});

  // ==================== ПРИОРИТЕТ ====================
  String get low => _t({'en': 'Low', 'bg': 'Нисък', 'de': 'Niedrig', 'fr': 'Basse', 'it': 'Bassa', 'el': 'Χαμηλή', 'es': 'Baja', 'pt': 'Baixa', 'ru': 'Низкий', 'tr': 'Düşük'});
  String get medium => _t({'en': 'Medium', 'bg': 'Среден', 'de': 'Mittel', 'fr': 'Moyenne', 'it': 'Media', 'el': 'Μέτρια', 'es': 'Media', 'pt': 'Média', 'ru': 'Средний', 'tr': 'Orta'});
  String get high => _t({'en': 'High', 'bg': 'Висок', 'de': 'Hoch', 'fr': 'Haute', 'it': 'Alta', 'el': 'Υψηλή', 'es': 'Alta', 'pt': 'Alta', 'ru': 'Высокий', 'tr': 'Yüksek'});

  // ==================== ПОВТОРЯЕМОСТ ====================
  String get noRepeat => _t({'en': 'No repeat', 'bg': 'Без повторение', 'de': 'Keine Wiederholung', 'fr': 'Pas de répétition', 'it': 'Nessuna ripetizione', 'el': 'Χωρίς επανάληψη', 'es': 'Sin repetición', 'pt': 'Sem repetição', 'ru': 'Без повтора', 'tr': 'Tekrar yok'});
  String get daily => _t({'en': 'Daily', 'bg': 'Ежедневно', 'de': 'Täglich', 'fr': 'Quotidien', 'it': 'Giornaliero', 'el': 'Καθημερινά', 'es': 'Diario', 'pt': 'Diário', 'ru': 'Ежедневно', 'tr': 'Günlük'});
  String get weekly => _t({'en': 'Weekly', 'bg': 'Ежеседмично', 'de': 'Wöchentlich', 'fr': 'Hebdomadaire', 'it': 'Settimanale', 'el': 'Εβδομαδιαία', 'es': 'Semanal', 'pt': 'Semanal', 'ru': 'Еженедельно', 'tr': 'Haftalık'});
  String get monthly => _t({'en': 'Monthly', 'bg': 'Ежемесечно', 'de': 'Monatlich', 'fr': 'Mensuel', 'it': 'Mensile', 'el': 'Μηνιαία', 'es': 'Mensual', 'pt': 'Mensal', 'ru': 'Ежемесячно', 'tr': 'Aylık'});
  String get yearly => _t({'en': 'Yearly', 'bg': 'Ежегодно', 'de': 'Jährlich', 'fr': 'Annuel', 'it': 'Annuale', 'el': 'Ετήσια', 'es': 'Anual', 'pt': 'Anual', 'ru': 'Ежегодно', 'tr': 'Yıllık'});

  // ==================== ОБЩИ БУТОНИ ====================
  String get add => _t({'en': 'Add', 'bg': 'Добави', 'de': 'Hinzufügen', 'fr': 'Ajouter', 'it': 'Aggiungi', 'el': 'Προσθήκη', 'es': 'Añadir', 'pt': 'Adicionar', 'ru': 'Добавить', 'tr': 'Ekle'});
  String get cancel => _t({'en': 'Cancel', 'bg': 'Отказ', 'de': 'Abbrechen', 'fr': 'Annuler', 'it': 'Annulla', 'el': 'Ακύρωση', 'es': 'Cancelar', 'pt': 'Cancelar', 'ru': 'Отмена', 'tr': 'İptal'});
  String get save => _t({'en': 'Save', 'bg': 'Запази', 'de': 'Speichern', 'fr': 'Enregistrer', 'it': 'Salva', 'el': 'Αποθήκευση', 'es': 'Guardar', 'pt': 'Salvar', 'ru': 'Сохранить', 'tr': 'Kaydet'});
  String get delete => _t({'en': 'Delete', 'bg': 'Изтрий', 'de': 'Löschen', 'fr': 'Supprimer', 'it': 'Elimina', 'el': 'Διαγραφή', 'es': 'Eliminar', 'pt': 'Excluir', 'ru': 'Удалить', 'tr': 'Sil'});
  String get edit => _t({'en': 'Edit', 'bg': 'Редактирай', 'de': 'Bearbeiten', 'fr': 'Modifier', 'it': 'Modifica', 'el': 'Επεξεργασία', 'es': 'Editar', 'pt': 'Editar', 'ru': 'Редактировать', 'tr': 'Düzenle'});
  String get done => _t({'en': 'Done', 'bg': 'Готово', 'de': 'Fertig', 'fr': 'Terminé', 'it': 'Fatto', 'el': 'Έτοιμο', 'es': 'Hecho', 'pt': 'Feito', 'ru': 'Готово', 'tr': 'Tamam'});
  String get allTasksCompleted => _t({'en': 'All tasks completed!', 'bg': 'Всички задачи са завършени!', 'de': 'Alle Aufgaben erledigt!', 'fr': 'Toutes les tâches terminées!', 'it': 'Tutte le attività completate!', 'el': 'Όλες οι εργασίες ολοκληρώθηκαν!', 'es': '¡Todas las tareas completadas!', 'pt': 'Todas as tarefas concluídas!', 'ru': 'Все задачи выполнены!', 'tr': 'Tüm görevler tamamlandı!'});
  String get greatJob => _t({'en': 'Great job!', 'bg': 'Страхотна работа!', 'de': 'Großartige Arbeit!', 'fr': 'Excellent travail!', 'it': 'Ottimo lavoro!', 'el': 'Εξαιρετική δουλειά!', 'es': '¡Buen trabajo!', 'pt': 'Ótimo trabalho!', 'ru': 'Отличная работа!', 'tr': 'Harika iş!'});
  String get tapToContinue => _t({'en': 'Tap to continue', 'bg': 'Докосни за продължение', 'de': 'Tippen zum Fortfahren', 'fr': 'Appuyez pour continuer', 'it': 'Tocca per continuare', 'el': 'Πατήστε για συνέχεια', 'es': 'Toca para continuar', 'pt': 'Toque para continuar', 'ru': 'Нажмите для продолжения', 'tr': 'Devam etmek için dokunun'});
  String get confirm => _t({'en': 'Confirm', 'bg': 'Потвърди', 'de': 'Bestätigen', 'fr': 'Confirmer', 'it': 'Conferma', 'el': 'Επιβεβαίωση', 'es': 'Confirmar', 'pt': 'Confirmar', 'ru': 'Подтвердить', 'tr': 'Onayla'});
  String get replace => _t({'en': 'Replace', 'bg': 'Замени', 'de': 'Ersetzen', 'fr': 'Remplacer', 'it': 'Sostituisci', 'el': 'Αντικατάσταση', 'es': 'Reemplazar', 'pt': 'Substituir', 'ru': 'Заменить', 'tr': 'Değiştir'});
  String get all => _t({'en': 'All', 'bg': 'Всички', 'de': 'Alle', 'fr': 'Tous', 'it': 'Tutti', 'el': 'Όλα', 'es': 'Todos', 'pt': 'Todos', 'ru': 'Все', 'tr': 'Tümü'});

  // ==================== ПОЛЕТА НА ЗАДАЧАТА ====================
  String get category => _t({'en': 'Category', 'bg': 'Категория', 'de': 'Kategorie', 'fr': 'Catégorie', 'it': 'Categoria', 'el': 'Κατηγορία', 'es': 'Categoría', 'pt': 'Categoria', 'ru': 'Категория', 'tr': 'Kategori'});
  String get title => _t({'en': 'Title', 'bg': 'Заглавие', 'de': 'Titel', 'fr': 'Titre', 'it': 'Titolo', 'el': 'Τίτλος', 'es': 'Título', 'pt': 'Título', 'ru': 'Название', 'tr': 'Başlık'});
  String get newTask => _t({'en': 'New Task', 'bg': 'Нова задача', 'de': 'Neue Aufgabe', 'fr': 'Nouvelle tâche', 'it': 'Nuova attività', 'el': 'Νέα εργασία', 'es': 'Nueva tarea', 'pt': 'Nova tarefa', 'ru': 'Новая задача', 'tr': 'Yeni görev'});
  String get editTask => _t({'en': 'Edit Task', 'bg': 'Редактиране', 'de': 'Aufgabe bearbeiten', 'fr': 'Modifier la tâche', 'it': 'Modifica attività', 'el': 'Επεξεργασία εργασίας', 'es': 'Editar tarea', 'pt': 'Editar tarefa', 'ru': 'Редактировать задачу', 'tr': 'Görevi düzenle'});
  String get addTask => _t({'en': 'Add Task', 'bg': 'Добави задача', 'de': 'Aufgabe hinzufügen', 'fr': 'Ajouter une tâche', 'it': 'Aggiungi attività', 'el': 'Προσθήκη εργασίας', 'es': 'Añadir tarea', 'pt': 'Adicionar tarefa', 'ru': 'Добавить задачу', 'tr': 'Görev ekle'});
  String get saveChanges => _t({'en': 'Save Changes', 'bg': 'Запази промените', 'de': 'Änderungen speichern', 'fr': 'Enregistrer les modifications', 'it': 'Salva modifiche', 'el': 'Αποθήκευση αλλαγών', 'es': 'Guardar cambios', 'pt': 'Salvar alterações', 'ru': 'Сохранить изменения', 'tr': 'Değişiklikleri kaydet'});
  String get dueDate => _t({'en': 'Due date', 'bg': 'Срок', 'de': 'Fälligkeitsdatum', 'fr': 'Date limite', 'it': 'Scadenza', 'el': 'Προθεσμία', 'es': 'Fecha límite', 'pt': 'Data limite', 'ru': 'Срок', 'tr': 'Bitiş tarihi'});
  String get dateAndTime => _t({'en': 'Date & Time', 'bg': 'Дата и час', 'de': 'Datum & Uhrzeit', 'fr': 'Date et heure', 'it': 'Data e ora', 'el': 'Ημερομηνία & Ώρα', 'es': 'Fecha y hora', 'pt': 'Data e hora', 'ru': 'Дата и время', 'tr': 'Tarih ve Saat'});
  String get time => _t({'en': 'Time', 'bg': 'Час', 'de': 'Uhrzeit', 'fr': 'Heure', 'it': 'Ora', 'el': 'Ώρα', 'es': 'Hora', 'pt': 'Hora', 'ru': 'Время', 'tr': 'Saat'});
  String get priority => _t({'en': 'Priority', 'bg': 'Приоритет', 'de': 'Priorität', 'fr': 'Priorité', 'it': 'Priorità', 'el': 'Προτεραιότητα', 'es': 'Prioridad', 'pt': 'Prioridade', 'ru': 'Приоритет', 'tr': 'Öncelik'});
  String get sortBy => _t({'en': 'Sort by', 'bg': 'Сортирай по', 'de': 'Sortieren nach', 'fr': 'Trier par', 'it': 'Ordina per', 'el': 'Ταξινόμηση κατά', 'es': 'Ordenar por', 'pt': 'Ordenar por', 'ru': 'Сортировать по', 'tr': 'Sırala'});
  String get date => _t({'en': 'Date', 'bg': 'Дата', 'de': 'Datum', 'fr': 'Date', 'it': 'Data', 'el': 'Ημερομηνία', 'es': 'Fecha', 'pt': 'Data', 'ru': 'Дата', 'tr': 'Tarih'});
  String get name => _t({'en': 'Name', 'bg': 'Име', 'de': 'Name', 'fr': 'Nom', 'it': 'Nome', 'el': 'Όνομα', 'es': 'Nombre', 'pt': 'Nome', 'ru': 'Имя', 'tr': 'Ad'});
  String get repeat => _t({'en': 'Repeat', 'bg': 'Повторение', 'de': 'Wiederholung', 'fr': 'Répétition', 'it': 'Ripetizione', 'el': 'Επανάληψη', 'es': 'Repetir', 'pt': 'Repetir', 'ru': 'Повтор', 'tr': 'Tekrar'});
  String get whatNeedsToBeDone => _t({'en': 'What needs to be done?', 'bg': 'Какво трябва да направиш?', 'de': 'Was muss erledigt werden?', 'fr': 'Que faut-il faire?', 'it': 'Cosa bisogna fare?', 'el': 'Τι πρέπει να γίνει;', 'es': '¿Qué hay que hacer?', 'pt': 'O que precisa ser feito?', 'ru': 'Что нужно сделать?', 'tr': 'Ne yapılmalı?'});

  // ==================== КАТЕГОРИИ ====================
  String get work => _t({'en': 'Work', 'bg': 'Работа', 'de': 'Arbeit', 'fr': 'Travail', 'it': 'Lavoro', 'el': 'Εργασία', 'es': 'Trabajo', 'pt': 'Trabalho', 'ru': 'Работа', 'tr': 'İş'});
  String get personal => _t({'en': 'Personal', 'bg': 'Лични', 'de': 'Persönlich', 'fr': 'Personnel', 'it': 'Personale', 'el': 'Προσωπικά', 'es': 'Personal', 'pt': 'Pessoal', 'ru': 'Личное', 'tr': 'Kişisel'});
  String get shoppingList => _t({'en': 'Shopping List', 'bg': 'Списък за пазаруване', 'de': 'Einkaufsliste', 'fr': 'Liste de courses', 'it': 'Lista della spesa', 'el': 'Λίστα αγορών', 'es': 'Lista de compras', 'pt': 'Lista de compras', 'ru': 'Список покупок', 'tr': 'Alışveriş listesi'});
  String get addItem => _t({'en': 'Add item...', 'bg': 'Добави артикул...', 'de': 'Artikel hinzufügen...', 'fr': 'Ajouter un article...', 'it': 'Aggiungi articolo...', 'el': 'Προσθήκη αντικειμένου...', 'es': 'Añadir artículo...', 'pt': 'Adicionar item...', 'ru': 'Добавить товар...', 'tr': 'Öğe ekle...'});
  String get enterItem => _t({'en': 'Enter item...', 'bg': 'Въведи артикул...', 'de': 'Artikel eingeben...', 'fr': 'Saisir un article...', 'it': 'Inserisci articolo...', 'el': 'Εισάγετε αντικείμενο...', 'es': 'Introducir artículo...', 'pt': 'Digite o item...', 'ru': 'Введите товар...', 'tr': 'Öğe girin...'});
  String get clearCompleted => _t({'en': 'Clear done', 'bg': 'Изчисти готовите', 'de': 'Erledigte löschen', 'fr': 'Effacer les faits', 'it': 'Cancella completati', 'el': 'Καθαρισμός ολοκληρωμένων', 'es': 'Limpiar hechos', 'pt': 'Limpar concluídos', 'ru': 'Очистить выполненные', 'tr': 'Tamamlananları temizle'});
  String get shopping => _t({'en': 'Shopping', 'bg': 'Пазаруване', 'de': 'Einkaufen', 'fr': 'Courses', 'it': 'Spesa', 'el': 'Αγορές', 'es': 'Compras', 'pt': 'Compras', 'ru': 'Покупки', 'tr': 'Alışveriş'});
  String get categories => _t({'en': 'Categories', 'bg': 'Категории', 'de': 'Kategorien', 'fr': 'Catégories', 'it': 'Categorie', 'el': 'Κατηγορίες', 'es': 'Categorías', 'pt': 'Categorias', 'ru': 'Категории', 'tr': 'Kategoriler'});
  String get manageCategories => _t({'en': 'Manage Categories', 'bg': 'Управление на категории', 'de': 'Kategorien verwalten', 'fr': 'Gérer les catégories', 'it': 'Gestisci categorie', 'el': 'Διαχείριση κατηγοριών', 'es': 'Gestionar categorías', 'pt': 'Gerenciar categorias', 'ru': 'Управление категориями', 'tr': 'Kategorileri yönet'});
  String get editAddDeleteCategories => _t({'en': 'Edit, add or delete categories', 'bg': 'Редактирай, добави или изтрий категории', 'de': 'Kategorien bearbeiten, hinzufügen oder löschen', 'fr': 'Modifier, ajouter ou supprimer des catégories', 'it': 'Modifica, aggiungi o elimina categorie', 'el': 'Επεξεργασία, προσθήκη ή διαγραφή κατηγοριών', 'es': 'Editar, añadir o eliminar categorías', 'pt': 'Editar, adicionar ou excluir categorias', 'ru': 'Редактировать, добавить или удалить категории', 'tr': 'Kategorileri düzenle, ekle veya sil'});
  String get newCategory => _t({'en': 'New Category', 'bg': 'Нова категория', 'de': 'Neue Kategorie', 'fr': 'Nouvelle catégorie', 'it': 'Nuova categoria', 'el': 'Νέα κατηγορία', 'es': 'Nueva categoría', 'pt': 'Nova categoria', 'ru': 'Новая категория', 'tr': 'Yeni kategori'});
  String get editCategory => _t({'en': 'Edit Category', 'bg': 'Редактирай категория', 'de': 'Kategorie bearbeiten', 'fr': 'Modifier la catégorie', 'it': 'Modifica categoria', 'el': 'Επεξεργασία κατηγορίας', 'es': 'Editar categoría', 'pt': 'Editar categoria', 'ru': 'Редактировать категорию', 'tr': 'Kategoriyi düzenle'});
  String get addCategory => _t({'en': 'Add Category', 'bg': 'Добави категория', 'de': 'Kategorie hinzufügen', 'fr': 'Ajouter une catégorie', 'it': 'Aggiungi categoria', 'el': 'Προσθήκη κατηγορίας', 'es': 'Añadir categoría', 'pt': 'Adicionar categoria', 'ru': 'Добавить категорию', 'tr': 'Kategori ekle'});
  String get defaultCategory => _t({'en': 'Default category', 'bg': 'Стандартна категория', 'de': 'Standardkategorie', 'fr': 'Catégorie par défaut', 'it': 'Categoria predefinita', 'el': 'Προεπιλεγμένη κατηγορία', 'es': 'Categoría predeterminada', 'pt': 'Categoria padrão', 'ru': 'Категория по умолчанию', 'tr': 'Varsayılan kategori'});
  String get defaultCategoryNameCannotChange => _t({'en': 'Default category names cannot be changed', 'bg': 'Името на стандартните категории не може да се променя', 'de': 'Standardkategorienamen können nicht geändert werden', 'fr': 'Les noms des catégories par défaut ne peuvent pas être modifiés', 'it': 'I nomi delle categorie predefinite non possono essere modificati', 'el': 'Τα ονόματα των προεπιλεγμένων κατηγοριών δεν μπορούν να αλλάξουν', 'es': 'Los nombres de las categorías predeterminadas no se pueden cambiar', 'pt': 'Os nomes das categorias padrão não podem ser alterados', 'ru': 'Названия категорий по умолчанию нельзя изменить', 'tr': 'Varsayılan kategori adları değiştirilemez'});
  String get newCat => _t({'en': 'New', 'bg': 'Нова', 'de': 'Neu', 'fr': 'Nouveau', 'it': 'Nuovo', 'el': 'Νέο', 'es': 'Nuevo', 'pt': 'Novo', 'ru': 'Новая', 'tr': 'Yeni'});
  String get color => _t({'en': 'Color', 'bg': 'Цвят', 'de': 'Farbe', 'fr': 'Couleur', 'it': 'Colore', 'el': 'Χρώμα', 'es': 'Color', 'pt': 'Cor', 'ru': 'Цвет', 'tr': 'Renk'});

  // ==================== ЕЗИК И ТЕМА ====================
  String get language => _t({'en': 'Language', 'bg': 'Език', 'de': 'Sprache', 'fr': 'Langue', 'it': 'Lingua', 'el': 'Γλώσσα', 'es': 'Idioma', 'pt': 'Idioma', 'ru': 'Язык', 'tr': 'Dil'});
  String get bulgarian => _t({'en': 'Bulgarian', 'bg': 'Български', 'de': 'Bulgarisch', 'fr': 'Bulgare', 'it': 'Bulgaro', 'el': 'Βουλγαρικά', 'es': 'Búlgaro', 'pt': 'Búlgaro', 'ru': 'Болгарский', 'tr': 'Bulgarca'});
  String get english => _t({'en': 'English', 'bg': 'Английски', 'de': 'Englisch', 'fr': 'Anglais', 'it': 'Inglese', 'el': 'Αγγλικά', 'es': 'Inglés', 'pt': 'Inglês', 'ru': 'Английский', 'tr': 'İngilizce'});
  String get theme => _t({'en': 'Theme', 'bg': 'Тема', 'de': 'Design', 'fr': 'Thème', 'it': 'Tema', 'el': 'Θέμα', 'es': 'Tema', 'pt': 'Tema', 'ru': 'Тема', 'tr': 'Tema'});
  String get systemTheme => _t({'en': 'System', 'bg': 'Системна', 'de': 'System', 'fr': 'Système', 'it': 'Sistema', 'el': 'Σύστημα', 'es': 'Sistema', 'pt': 'Sistema', 'ru': 'Системная', 'tr': 'Sistem'});
  String get lightTheme => _t({'en': 'Light', 'bg': 'Светла', 'de': 'Hell', 'fr': 'Clair', 'it': 'Chiaro', 'el': 'Φωτεινό', 'es': 'Claro', 'pt': 'Claro', 'ru': 'Светлая', 'tr': 'Açık'});
  String get darkTheme => _t({'en': 'Dark', 'bg': 'Тъмна', 'de': 'Dunkel', 'fr': 'Sombre', 'it': 'Scuro', 'el': 'Σκοτεινό', 'es': 'Oscuro', 'pt': 'Escuro', 'ru': 'Темная', 'tr': 'Koyu'});
  String get amoledTheme => _t({'en': 'AMOLED Black', 'bg': 'AMOLED черна', 'de': 'AMOLED Schwarz', 'fr': 'AMOLED Noir', 'it': 'AMOLED Nero', 'el': 'AMOLED Μαύρο', 'es': 'AMOLED Negro', 'pt': 'AMOLED Preto', 'ru': 'AMOLED Черная', 'tr': 'AMOLED Siyah'});

  // ==================== АРХИВ ====================
  String get archive => _t({'en': 'Archive', 'bg': 'Архивирай', 'de': 'Archivieren', 'fr': 'Archiver', 'it': 'Archivia', 'el': 'Αρχειοθέτηση', 'es': 'Archivar', 'pt': 'Arquivar', 'ru': 'Архивировать', 'tr': 'Arşivle'});
  String get unarchive => _t({'en': 'Unarchive', 'bg': 'Възстанови', 'de': 'Wiederherstellen', 'fr': 'Désarchiver', 'it': 'Ripristina', 'el': 'Επαναφορά', 'es': 'Desarchivar', 'pt': 'Desarquivar', 'ru': 'Восстановить', 'tr': 'Arşivden çıkar'});
  String get restore => _t({'en': 'Restore', 'bg': 'Възстанови', 'de': 'Wiederherstellen', 'fr': 'Restaurer', 'it': 'Ripristina', 'el': 'Επαναφορά', 'es': 'Restaurar', 'pt': 'Restaurar', 'ru': 'Восстановить', 'tr': 'Geri yükle'});
  String get archived => _t({'en': 'Archived', 'bg': 'Архивирани', 'de': 'Archiviert', 'fr': 'Archivées', 'it': 'Archiviate', 'el': 'Αρχειοθετημένες', 'es': 'Archivadas', 'pt': 'Arquivadas', 'ru': 'Архивировано', 'tr': 'Arşivlenmiş'});

  // ==================== НАПОМНЯНИЯ ====================
  String get reminders => _t({'en': 'Reminders', 'bg': 'Напомняния', 'de': 'Erinnerungen', 'fr': 'Rappels', 'it': 'Promemoria', 'el': 'Υπενθυμίσεις', 'es': 'Recordatorios', 'pt': 'Lembretes', 'ru': 'Напоминания', 'tr': 'Hatırlatıcılar'});
  String get reminder => _t({'en': 'reminder', 'bg': 'напомняне', 'de': 'Erinnerung', 'fr': 'rappel', 'it': 'promemoria', 'el': 'υπενθύμιση', 'es': 'recordatorio', 'pt': 'lembrete', 'ru': 'напоминание', 'tr': 'hatırlatıcı'});

  // ==================== ПОДЗАДАЧИ ====================
  String get subtasks => _t({'en': 'Subtasks', 'bg': 'Подзадачи', 'de': 'Unteraufgaben', 'fr': 'Sous-tâches', 'it': 'Sottoattività', 'el': 'Υποεργασίες', 'es': 'Subtareas', 'pt': 'Subtarefas', 'ru': 'Подзадачи', 'tr': 'Alt görevler'});
  String get newSubtask => _t({'en': 'New Subtask', 'bg': 'Нова подзадача', 'de': 'Neue Unteraufgabe', 'fr': 'Nouvelle sous-tâche', 'it': 'Nuova sottoattività', 'el': 'Νέα υποεργασία', 'es': 'Nueva subtarea', 'pt': 'Nova subtarefa', 'ru': 'Новая подзадача', 'tr': 'Yeni alt görev'});
  String get addSubtask => _t({'en': 'Add subtask', 'bg': 'Добави подзадача', 'de': 'Unteraufgabe hinzufügen', 'fr': 'Ajouter une sous-tâche', 'it': 'Aggiungi sottoattività', 'el': 'Προσθήκη υποεργασίας', 'es': 'Añadir subtarea', 'pt': 'Adicionar subtarefa', 'ru': 'Добавить подзадачу', 'tr': 'Alt görev ekle'});
  String get enterSubtask => _t({'en': 'Enter subtask...', 'bg': 'Въведи подзадача...', 'de': 'Unteraufgabe eingeben...', 'fr': 'Entrer une sous-tâche...', 'it': 'Inserisci sottoattività...', 'el': 'Εισάγετε υποεργασία...', 'es': 'Introducir subtarea...', 'pt': 'Digite subtarefa...', 'ru': 'Введите подзадачу...', 'tr': 'Alt görev girin...'});

  // ==================== БЕЛЕЖКИ ====================
  String get notes => _t({'en': 'Notes', 'bg': 'Бележки', 'de': 'Notizen', 'fr': 'Notes', 'it': 'Note', 'el': 'Σημειώσεις', 'es': 'Notas', 'pt': 'Notas', 'ru': 'Заметки', 'tr': 'Notlar'});
  String get addNote => _t({'en': 'Add note...', 'bg': 'Добави бележка...', 'de': 'Notiz hinzufügen...', 'fr': 'Ajouter une note...', 'it': 'Aggiungi nota...', 'el': 'Προσθήκη σημείωσης...', 'es': 'Añadir nota...', 'pt': 'Adicionar nota...', 'ru': 'Добавить заметку...', 'tr': 'Not ekle...'});
  String get additionalInfo => _t({'en': 'Additional information...', 'bg': 'Допълнителна информация...', 'de': 'Zusätzliche Informationen...', 'fr': 'Informations supplémentaires...', 'it': 'Informazioni aggiuntive...', 'el': 'Επιπλέον πληροφορίες...', 'es': 'Información adicional...', 'pt': 'Informações adicionais...', 'ru': 'Дополнительная информация...', 'tr': 'Ek bilgi...'});

  // ==================== АКАУНТ ====================
  String get account => _t({'en': 'Account', 'bg': 'Акаунт', 'de': 'Konto', 'fr': 'Compte', 'it': 'Account', 'el': 'Λογαριασμός', 'es': 'Cuenta', 'pt': 'Conta', 'ru': 'Аккаунт', 'tr': 'Hesap'});
  String get signedIn => _t({'en': 'Signed in', 'bg': 'Влязъл си в акаунта', 'de': 'Angemeldet', 'fr': 'Connecté', 'it': 'Connesso', 'el': 'Συνδεδεμένος', 'es': 'Conectado', 'pt': 'Conectado', 'ru': 'Выполнен вход', 'tr': 'Giriş yapıldı'});
  String get logout => _t({'en': 'Logout', 'bg': 'Изход', 'de': 'Abmelden', 'fr': 'Déconnexion', 'it': 'Esci', 'el': 'Αποσύνδεση', 'es': 'Cerrar sesión', 'pt': 'Sair', 'ru': 'Выйти', 'tr': 'Çıkış'});
  String get logoutConfirm => _t({'en': 'Are you sure you want to logout?', 'bg': 'Сигурен ли си, че искаш да излезеш?', 'de': 'Möchtest du dich wirklich abmelden?', 'fr': 'Êtes-vous sûr de vouloir vous déconnecter?', 'it': 'Sei sicuro di voler uscire?', 'el': 'Είστε σίγουροι ότι θέλετε να αποσυνδεθείτε;', 'es': '¿Estás seguro de que quieres cerrar sesión?', 'pt': 'Tem certeza de que deseja sair?', 'ru': 'Вы уверены, что хотите выйти?', 'tr': 'Çıkış yapmak istediğinize emin misiniz?'});
  String get notLoggedIn => _t({'en': 'Not logged in', 'bg': 'Не си влязъл', 'de': 'Nicht angemeldet', 'fr': 'Non connecté', 'it': 'Non connesso', 'el': 'Δεν έχετε συνδεθεί', 'es': 'No conectado', 'pt': 'Não conectado', 'ru': 'Не выполнен вход', 'tr': 'Giriş yapılmadı'});
  String get loginToSync => _t({'en': 'Login to sync tasks', 'bg': 'Влез, за да синхронизираш', 'de': 'Anmelden zum Synchronisieren', 'fr': 'Connectez-vous pour synchroniser', 'it': 'Accedi per sincronizzare', 'el': 'Συνδεθείτε για συγχρονισμό', 'es': 'Inicia sesión para sincronizar', 'pt': 'Entre para sincronizar', 'ru': 'Войдите для синхронизации', 'tr': 'Senkronize etmek için giriş yapın'});
  String get login => _t({'en': 'Login', 'bg': 'Вход', 'de': 'Anmelden', 'fr': 'Connexion', 'it': 'Accedi', 'el': 'Σύνδεση', 'es': 'Iniciar sesión', 'pt': 'Entrar', 'ru': 'Войти', 'tr': 'Giriş'});

  // ==================== CLOUD SYNC ====================
  String get cloudSync => _t({'en': 'Cloud Sync', 'bg': 'Облачна синхронизация', 'de': 'Cloud-Synchronisierung', 'fr': 'Synchronisation cloud', 'it': 'Sincronizzazione cloud', 'el': 'Συγχρονισμός cloud', 'es': 'Sincronización en la nube', 'pt': 'Sincronização na nuvem', 'ru': 'Облачная синхронизация', 'tr': 'Bulut senkronizasyonu'});
  String get uploadToCloud => _t({'en': 'Upload to Cloud', 'bg': 'Качване в облака', 'de': 'In Cloud hochladen', 'fr': 'Télécharger vers le cloud', 'it': 'Carica su cloud', 'el': 'Μεταφόρτωση στο cloud', 'es': 'Subir a la nube', 'pt': 'Enviar para a nuvem', 'ru': 'Загрузить в облако', 'tr': 'Buluta yükle'});
  String get uploadToCloudDesc => _t({'en': 'Backup tasks to the cloud', 'bg': 'Качи задачите в облака', 'de': 'Aufgaben in der Cloud sichern', 'fr': 'Sauvegarder les tâches dans le cloud', 'it': 'Backup attività nel cloud', 'el': 'Αντίγραφο ασφαλείας εργασιών στο cloud', 'es': 'Guardar tareas en la nube', 'pt': 'Fazer backup de tarefas na nuvem', 'ru': 'Резервное копирование в облако', 'tr': 'Görevleri buluta yedekle'});
  String get downloadFromCloud => _t({'en': 'Download from Cloud', 'bg': 'Сваляне от облака', 'de': 'Aus Cloud herunterladen', 'fr': 'Télécharger depuis le cloud', 'it': 'Scarica da cloud', 'el': 'Λήψη από cloud', 'es': 'Descargar de la nube', 'pt': 'Baixar da nuvem', 'ru': 'Скачать из облака', 'tr': 'Buluttan indir'});
  String get downloadFromCloudDesc => _t({'en': 'Restore tasks from the cloud', 'bg': 'Възстанови задачите от облака', 'de': 'Aufgaben aus Cloud wiederherstellen', 'fr': 'Restaurer les tâches depuis le cloud', 'it': 'Ripristina attività dal cloud', 'el': 'Επαναφορά εργασιών από cloud', 'es': 'Restaurar tareas de la nube', 'pt': 'Restaurar tarefas da nuvem', 'ru': 'Восстановить из облака', 'tr': 'Görevleri buluttan geri yükle'});
  String get upload => _t({'en': 'Upload', 'bg': 'Качи', 'de': 'Hochladen', 'fr': 'Télécharger', 'it': 'Carica', 'el': 'Μεταφόρτωση', 'es': 'Subir', 'pt': 'Enviar', 'ru': 'Загрузить', 'tr': 'Yükle'});
  String get download => _t({'en': 'Download', 'bg': 'Свали', 'de': 'Herunterladen', 'fr': 'Télécharger', 'it': 'Scarica', 'el': 'Λήψη', 'es': 'Descargar', 'pt': 'Baixar', 'ru': 'Скачать', 'tr': 'İndir'});
  String get syncing => _t({'en': 'Syncing...', 'bg': 'Синхронизиране...', 'de': 'Synchronisiere...', 'fr': 'Synchronisation...', 'it': 'Sincronizzazione...', 'el': 'Συγχρονισμός...', 'es': 'Sincronizando...', 'pt': 'Sincronizando...', 'ru': 'Синхронизация...', 'tr': 'Senkronize ediliyor...'});
  String get syncSuccess => _t({'en': 'Sync successful', 'bg': 'Синхронизацията е успешна', 'de': 'Synchronisierung erfolgreich', 'fr': 'Synchronisation réussie', 'it': 'Sincronizzazione riuscita', 'el': 'Επιτυχής συγχρονισμός', 'es': 'Sincronización exitosa', 'pt': 'Sincronização bem-sucedida', 'ru': 'Синхронизация выполнена', 'tr': 'Senkronizasyon başarılı'});

  // ==================== ЛОКАЛНИ ДАННИ ====================
  String get localData => _t({'en': 'Local Data', 'bg': 'Локални данни', 'de': 'Lokale Daten', 'fr': 'Données locales', 'it': 'Dati locali', 'el': 'Τοπικά δεδομένα', 'es': 'Datos locales', 'pt': 'Dados locais', 'ru': 'Локальные данные', 'tr': 'Yerel veriler'});
  String get exportData => _t({'en': 'Export Data', 'bg': 'Експорт на данни', 'de': 'Daten exportieren', 'fr': 'Exporter les données', 'it': 'Esporta dati', 'el': 'Εξαγωγή δεδομένων', 'es': 'Exportar datos', 'pt': 'Exportar dados', 'ru': 'Экспорт данных', 'tr': 'Verileri dışa aktar'});
  String get exportDataDesc => _t({'en': 'Save tasks to file', 'bg': 'Запази задачите във файл', 'de': 'Aufgaben in Datei speichern', 'fr': 'Enregistrer les tâches dans un fichier', 'it': 'Salva attività su file', 'el': 'Αποθήκευση εργασιών σε αρχείο', 'es': 'Guardar tareas en archivo', 'pt': 'Salvar tarefas em arquivo', 'ru': 'Сохранить задачи в файл', 'tr': 'Görevleri dosyaya kaydet'});
  String get importData => _t({'en': 'Import Data', 'bg': 'Импорт на данни', 'de': 'Daten importieren', 'fr': 'Importer des données', 'it': 'Importa dati', 'el': 'Εισαγωγή δεδομένων', 'es': 'Importar datos', 'pt': 'Importar dados', 'ru': 'Импорт данных', 'tr': 'Verileri içe aktar'});
  String get importDataDesc => _t({'en': 'Restore tasks from file', 'bg': 'Възстанови задачите от файл', 'de': 'Aufgaben aus Datei wiederherstellen', 'fr': 'Restaurer les tâches depuis un fichier', 'it': 'Ripristina attività da file', 'el': 'Επαναφορά εργασιών από αρχείο', 'es': 'Restaurar tareas desde archivo', 'pt': 'Restaurar tarefas de arquivo', 'ru': 'Восстановить задачи из файла', 'tr': 'Görevleri dosyadan geri yükle'});
  String get tasksBackup => _t({'en': 'Tasks backup', 'bg': 'Backup на задачите', 'de': 'Aufgaben-Backup', 'fr': 'Sauvegarde des tâches', 'it': 'Backup attività', 'el': 'Αντίγραφο ασφαλείας εργασιών', 'es': 'Copia de seguridad de tareas', 'pt': 'Backup de tarefas', 'ru': 'Резервная копия задач', 'tr': 'Görev yedeği'});

  // ==================== ДИАЛОЗИ И ПОТВЪРЖДЕНИЯ ====================
  String get confirmation => _t({'en': 'Confirmation', 'bg': 'Потвърждение', 'de': 'Bestätigung', 'fr': 'Confirmation', 'it': 'Conferma', 'el': 'Επιβεβαίωση', 'es': 'Confirmación', 'pt': 'Confirmação', 'ru': 'Подтверждение', 'tr': 'Onay'});
  String get deleteConfirm => _t({'en': 'Are you sure you want to delete this?', 'bg': 'Сигурен ли си, че искаш да изтриеш?', 'de': 'Möchtest du das wirklich löschen?', 'fr': 'Êtes-vous sûr de vouloir supprimer?', 'it': 'Sei sicuro di voler eliminare?', 'el': 'Είστε σίγουροι ότι θέλετε να διαγράψετε;', 'es': '¿Estás seguro de que quieres eliminar?', 'pt': 'Tem certeza de que deseja excluir?', 'ru': 'Вы уверены, что хотите удалить?', 'tr': 'Silmek istediğinize emin misiniz?'});
  String get deletion => _t({'en': 'Delete', 'bg': 'Изтриване', 'de': 'Löschen', 'fr': 'Supprimer', 'it': 'Eliminare', 'el': 'Διαγραφή', 'es': 'Eliminar', 'pt': 'Excluir', 'ru': 'Удаление', 'tr': 'Silme'});

  // ==================== ГЛАС ====================
  String get listening => _t({'en': 'Listening...', 'bg': 'Слушам...', 'de': 'Höre zu...', 'fr': 'Écoute...', 'it': 'Ascolto...', 'el': 'Ακούω...', 'es': 'Escuchando...', 'pt': 'Ouvindo...', 'ru': 'Слушаю...', 'tr': 'Dinleniyor...'});
  String get speakNow => _t({'en': 'Speak now', 'bg': 'Говори сега', 'de': 'Jetzt sprechen', 'fr': 'Parlez maintenant', 'it': 'Parla ora', 'el': 'Μιλήστε τώρα', 'es': 'Habla ahora', 'pt': 'Fale agora', 'ru': 'Говорите', 'tr': 'Şimdi konuşun'});

  // ==================== ГРЕШКИ ====================
  String get error => _t({'en': 'Error', 'bg': 'Грешка', 'de': 'Fehler', 'fr': 'Erreur', 'it': 'Errore', 'el': 'Σφάλμα', 'es': 'Error', 'pt': 'Erro', 'ru': 'Ошибка', 'tr': 'Hata'});
  String get exportError => _t({'en': 'Export error', 'bg': 'Грешка при експорт', 'de': 'Exportfehler', 'fr': "Erreur d'exportation", 'it': 'Errore di esportazione', 'el': 'Σφάλμα εξαγωγής', 'es': 'Error de exportación', 'pt': 'Erro de exportação', 'ru': 'Ошибка экспорта', 'tr': 'Dışa aktarma hatası'});
  String get importError => _t({'en': 'Import error', 'bg': 'Грешка при импорт', 'de': 'Importfehler', 'fr': "Erreur d'importation", 'it': 'Errore di importazione', 'el': 'Σφάλμα εισαγωγής', 'es': 'Error de importación', 'pt': 'Erro de importação', 'ru': 'Ошибка импорта', 'tr': 'İçe aktarma hatası'});

  // ==================== ТЪРСЕНЕ ====================
  String get searchTasks => _t({'en': 'Search tasks', 'bg': 'Търсене в задачите', 'de': 'Aufgaben suchen', 'fr': 'Rechercher des tâches', 'it': 'Cerca attività', 'el': 'Αναζήτηση εργασιών', 'es': 'Buscar tareas', 'pt': 'Pesquisar tarefas', 'ru': 'Поиск задач', 'tr': 'Görev ara'});

  // ==================== ГЛАСОВО РАЗПОЗНАВАНЕ ====================
  String get speechNotAvailable => _t({'en': 'Speech recognition not available', 'bg': 'Гласовото разпознаване не е налично', 'de': 'Spracherkennung nicht verfügbar', 'fr': 'Reconnaissance vocale non disponible', 'it': 'Riconoscimento vocale non disponibile', 'el': 'Η αναγνώριση φωνής δεν είναι διαθέσιμη', 'es': 'Reconocimiento de voz no disponible', 'pt': 'Reconhecimento de voz não disponível', 'ru': 'Распознавание речи недоступно', 'tr': 'Ses tanıma kullanılamıyor'});

  // ==================== ДОПЪЛНИТЕЛНИ ====================
  String get deleteTaskConfirm => _t({'en': 'Delete this task?', 'bg': 'Изтриване на задачата?', 'de': 'Diese Aufgabe löschen?', 'fr': 'Supprimer cette tâche?', 'it': 'Eliminare questa attività?', 'el': 'Διαγραφή αυτής της εργασίας;', 'es': '¿Eliminar esta tarea?', 'pt': 'Excluir esta tarefa?', 'ru': 'Удалить эту задачу?', 'tr': 'Bu görevi sil?'});
  String get deleteCategoryConfirm => _t({'en': 'Delete this category?', 'bg': 'Изтриване на категорията?', 'de': 'Diese Kategorie löschen?', 'fr': 'Supprimer cette catégorie?', 'it': 'Eliminare questa categoria?', 'el': 'Διαγραφή αυτής της κατηγορίας;', 'es': '¿Eliminar esta categoría?', 'pt': 'Excluir esta categoria?', 'ru': 'Удалить эту категорию?', 'tr': 'Bu kategoriyi sil?'});
  String get willDeleteTasks => _t({'en': 'This will also delete all tasks in this category', 'bg': 'Това ще изтрие и всички задачи в тази категория', 'de': 'Dies löscht auch alle Aufgaben in dieser Kategorie', 'fr': 'Cela supprimera également toutes les tâches de cette catégorie', 'it': 'Questo eliminerà anche tutte le attività in questa categoria', 'el': 'Αυτό θα διαγράψει επίσης όλες τις εργασίες σε αυτήν την κατηγορία', 'es': 'Esto también eliminará todas las tareas de esta categoría', 'pt': 'Isso também excluirá todas as tarefas nesta categoria', 'ru': 'Это также удалит все задачи в этой категории', 'tr': 'Bu, bu kategorideki tüm görevleri de siler'});
  String get replaceLocalData => _t({'en': 'This will replace all local data', 'bg': 'Това ще замени всички локални данни', 'de': 'Dies ersetzt alle lokalen Daten', 'fr': 'Cela remplacera toutes les données locales', 'it': 'Questo sostituirà tutti i dati locali', 'el': 'Αυτό θα αντικαταστήσει όλα τα τοπικά δεδομένα', 'es': 'Esto reemplazará todos los datos locales', 'pt': 'Isso substituirá todos os dados locais', 'ru': 'Это заменит все локальные данные', 'tr': 'Bu, tüm yerel verilerin yerini alacak'});
  String get uploadConfirm => _t({'en': 'Upload tasks to cloud?', 'bg': 'Качване на задачите в облака?', 'de': 'Aufgaben in die Cloud hochladen?', 'fr': 'Télécharger les tâches vers le cloud?', 'it': 'Caricare le attività nel cloud?', 'el': 'Μεταφόρτωση εργασιών στο cloud;', 'es': '¿Subir tareas a la nube?', 'pt': 'Enviar tarefas para a nuvem?', 'ru': 'Загрузить задачи в облако?', 'tr': 'Görevler buluta yüklensin mi?'});
  String get downloadConfirm => _t({'en': 'Download tasks from cloud?', 'bg': 'Сваляне на задачите от облака?', 'de': 'Aufgaben aus der Cloud herunterladen?', 'fr': 'Télécharger les tâches depuis le cloud?', 'it': 'Scaricare le attività dal cloud?', 'el': 'Λήψη εργασιών από το cloud;', 'es': '¿Descargar tareas de la nube?', 'pt': 'Baixar tarefas da nuvem?', 'ru': 'Скачать задачи из облака?', 'tr': 'Görevler buluttan indirilsin mi?'});

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
    'tr': '"$title" silmek istediğinize emin misiniz?',
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
    'tr': '"$name" silmek istediğinize emin misiniz?',
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
    'tr': '$tasks görev ve $cats kategori içe aktarılacak.\n\nBu, tüm mevcut verilerin yerini alacak. Devam edilsin mi?',
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
    'tr': '$tasks görev ve $cats kategori içe aktarıldı',
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
    'tr': '$tasks görev ve $cats kategori yüklenecek.\n\nBu, bulut verilerinin yerini alacak. Devam edilsin mi?',
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
    'tr': '$tasks görev ve $cats kategori yüklendi',
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
    'tr': 'Bulutta $tasks görev ve $cats kategori var.\n\nBu, yerel verilerin yerini alacak. Devam edilsin mi?',
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
    'tr': '$tasks görev ve $cats kategori indirildi',
  });

  String get signInToSync => _t({'en': 'Sign in to sync to cloud', 'bg': 'Влез за синхронизация в облака', 'de': 'Anmelden zur Cloud-Synchronisierung', 'fr': 'Connectez-vous pour synchroniser', 'it': 'Accedi per sincronizzare', 'el': 'Συνδεθείτε για συγχρονισμό', 'es': 'Inicia sesión para sincronizar', 'pt': 'Entre para sincronizar', 'ru': 'Войдите для синхронизации', 'tr': 'Senkronize etmek için giriş yapın'});
  String get saveToCloud => _t({'en': 'Save tasks to cloud', 'bg': 'Запази задачите в облака', 'de': 'Aufgaben in Cloud speichern', 'fr': 'Enregistrer les tâches dans le cloud', 'it': 'Salva attività nel cloud', 'el': 'Αποθήκευση εργασιών στο cloud', 'es': 'Guardar tareas en la nube', 'pt': 'Salvar tarefas na nuvem', 'ru': 'Сохранить задачи в облако', 'tr': 'Görevleri buluta kaydet'});
  String get restoreFromCloud => _t({'en': 'Restore tasks from cloud', 'bg': 'Възстанови задачите от облака', 'de': 'Aufgaben aus Cloud wiederherstellen', 'fr': 'Restaurer les tâches depuis le cloud', 'it': 'Ripristina attività dal cloud', 'el': 'Επαναφορά εργασιών από cloud', 'es': 'Restaurar tareas de la nube', 'pt': 'Restaurar tarefas da nuvem', 'ru': 'Восстановить задачи из облака', 'tr': 'Görevleri buluttan geri yükle'});
  String get saveToFile => _t({'en': 'Save tasks to file', 'bg': 'Запази задачите във файл', 'de': 'Aufgaben in Datei speichern', 'fr': 'Enregistrer les tâches dans un fichier', 'it': 'Salva attività su file', 'el': 'Αποθήκευση εργασιών σε αρχείο', 'es': 'Guardar tareas en archivo', 'pt': 'Salvar tarefas em arquivo', 'ru': 'Сохранить задачи в файл', 'tr': 'Görevleri dosyaya kaydet'});
  String get restoreFromFile => _t({'en': 'Restore tasks from file', 'bg': 'Възстанови задачите от файл', 'de': 'Aufgaben aus Datei wiederherstellen', 'fr': 'Restaurer les tâches depuis un fichier', 'it': 'Ripristina attività da file', 'el': 'Επαναφορά εργασιών από αρχείο', 'es': 'Restaurar tareas desde archivo', 'pt': 'Restaurar tarefas de arquivo', 'ru': 'Восстановить задачи из файла', 'tr': 'Görevleri dosyadan geri yükle'});
  String get shareBackup => _t({'en': 'Share backup file', 'bg': 'Сподели backup файл', 'de': 'Backup-Datei teilen', 'fr': 'Partager le fichier de sauvegarde', 'it': 'Condividi file di backup', 'el': 'Κοινοποίηση αρχείου αντιγράφου', 'es': 'Compartir archivo de respaldo', 'pt': 'Compartilhar arquivo de backup', 'ru': 'Поделиться файлом резервной копии', 'tr': 'Yedek dosyasını paylaş'});
  String get restoreFromJson => _t({'en': 'Restore from JSON file', 'bg': 'Възстанови от JSON файл', 'de': 'Aus JSON-Datei wiederherstellen', 'fr': 'Restaurer depuis un fichier JSON', 'it': 'Ripristina da file JSON', 'el': 'Επαναφορά από αρχείο JSON', 'es': 'Restaurar desde archivo JSON', 'pt': 'Restaurar de arquivo JSON', 'ru': 'Восстановить из файла JSON', 'tr': 'JSON dosyasından geri yükle'});

  // ==================== СТАТИСТИКИ ====================
  String get summary => _t({'en': 'Summary', 'bg': 'Обобщение', 'de': 'Zusammenfassung', 'fr': 'Résumé', 'it': 'Riepilogo', 'el': 'Περίληψη', 'es': 'Resumen', 'pt': 'Resumo', 'ru': 'Сводка', 'tr': 'Özet'});
  String get progress => _t({'en': 'Progress', 'bg': 'Прогрес', 'de': 'Fortschritt', 'fr': 'Progression', 'it': 'Progresso', 'el': 'Πρόοδος', 'es': 'Progreso', 'pt': 'Progresso', 'ru': 'Прогресс', 'tr': 'İlerleme'});
  String get completionRate => _t({'en': 'Completion rate', 'bg': 'Изпълнение', 'de': 'Abschlussrate', 'fr': 'Taux de réalisation', 'it': 'Tasso di completamento', 'el': 'Ποσοστό ολοκλήρωσης', 'es': 'Tasa de finalización', 'pt': 'Taxa de conclusão', 'ru': 'Процент выполнения', 'tr': 'Tamamlanma oranı'});
  String get tasksCompletedThisWeek => _t({'en': 'tasks completed\nthis week', 'bg': 'изпълнени\nтази седмица', 'de': 'Aufgaben erledigt\ndiese Woche', 'fr': 'tâches terminées\ncette semaine', 'it': 'attività completate\nquesta settimana', 'el': 'εργασίες\nαυτή την εβδομάδα', 'es': 'tareas completadas\nesta semana', 'pt': 'tarefas concluídas\nesta semana', 'ru': 'выполнено\nна этой неделе', 'tr': 'bu hafta\ntamamlandı'});
  String get dayStreak => _t({'en': 'day streak', 'bg': 'дни streak', 'de': 'Tage Serie', 'fr': 'jours consécutifs', 'it': 'giorni consecutivi', 'el': 'ημέρες σερί', 'es': 'días seguidos', 'pt': 'dias seguidos', 'ru': 'дней подряд', 'tr': 'gün serisi'});
  String get mostProductive => _t({'en': 'most productive', 'bg': 'най-продуктивен', 'de': 'am produktivsten', 'fr': 'le plus productif', 'it': 'più produttivo', 'el': 'πιο παραγωγικός', 'es': 'más productivo', 'pt': 'mais produtivo', 'ru': 'самый продуктивный', 'tr': 'en verimli'});
  String get byCategory => _t({'en': 'By category', 'bg': 'По категории', 'de': 'Nach Kategorie', 'fr': 'Par catégorie', 'it': 'Per categoria', 'el': 'Ανά κατηγορία', 'es': 'Por categoría', 'pt': 'Por categoria', 'ru': 'По категориям', 'tr': 'Kategoriye göre'});
  String get last7Days => _t({'en': 'Last 7 days', 'bg': 'Последните 7 дни', 'de': 'Letzte 7 Tage', 'fr': '7 derniers jours', 'it': 'Ultimi 7 giorni', 'el': 'Τελευταίες 7 ημέρες', 'es': 'Últimos 7 días', 'pt': 'Últimos 7 dias', 'ru': 'Последние 7 дней', 'tr': 'Son 7 gün'});
  String get other => _t({'en': 'Other', 'bg': 'Друго', 'de': 'Andere', 'fr': 'Autre', 'it': 'Altro', 'el': 'Άλλο', 'es': 'Otro', 'pt': 'Outro', 'ru': 'Другое', 'tr': 'Diğer'});

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
    'tr': '$total görevden $completed',
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
    'tr': 'Deneme: $days gün kaldı',
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
    'tr': 'Promo: $days gün kaldı',
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
    'tr': 'Yükselt',
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
    'tr': 'Google Takvim',
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
    'tr': 'Bağlı',
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
    'tr': 'Bağlı değil',
  });

  String get calendarSyncEnabled => _t({
    'en': 'Tasks sync with Google Calendar',
    'bg': 'Задачите се синхронизират с Google Календар',
    'de': 'Aufgaben werden mit Google Kalender synchronisiert',
    'fr': 'Les tâches sont synchronisées avec Google Agenda',
    'it': 'Le attività si sincronizzano con Google Calendar',
    'el': 'Οι εργασίες συγχρονίζονται με το Ημερολόγιο Google',
    'es': 'Las tareas se sincronizan con Google Calendar',
    'pt': 'Tarefas sincronizam com Google Agenda',
    'ru': 'Задачи синхронизируются с Google Календарём',
    'tr': 'Görevler Google Takvim ile senkronize edilir',
  });

  String get connectForSync => _t({
    'en': 'Connect to sync tasks',
    'bg': 'Свържи се за синхронизация',
    'de': 'Verbinden zum Synchronisieren',
    'fr': 'Connecter pour synchroniser',
    'it': 'Connetti per sincronizzare',
    'el': 'Συνδεθείτε για συγχρονισμό',
    'es': 'Conectar para sincronizar',
    'pt': 'Conectar para sincronizar',
    'ru': 'Подключитесь для синхронизации',
    'tr': 'Senkronize etmek için bağlan',
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
    'tr': 'Bağlan',
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
    'tr': 'Bağlantıyı kes',
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
    'tr': 'Şimdi senkronize et',
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
    'tr': 'Bağlantı başarısız',
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
    'tr': '$count görev senkronize edildi',
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
    'tr': 'Calendar\'dan senkronize et',
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
    'tr': '$count görev güncellendi',
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
    'tr': 'Calendar\'dan içe aktar',
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
    'tr': '$count etkinlik içe aktarıldı',
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
    'tr': 'Günaydın! 🌅',
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
    'tr': 'Bugün görev yok! ✨',
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
    'tr': 'İyi günler!',
  });

  String get morningBriefing => _t({'en': 'Morning Briefing', 'bg': 'Сутрешен преглед', 'de': 'Morgenübersicht', 'fr': 'Résumé du matin', 'it': 'Riepilogo mattutino', 'el': 'Πρωινή ενημέρωση', 'es': 'Resumen matutino', 'pt': 'Resumo matinal', 'ru': 'Утренний обзор', 'tr': 'Sabah özeti'});
  String get briefingTime => _t({'en': 'Briefing Time', 'bg': 'Час на прегледа', 'de': 'Übersichtszeit', 'fr': 'Heure du résumé', 'it': 'Orario riepilogo', 'el': 'Ώρα ενημέρωσης', 'es': 'Hora del resumen', 'pt': 'Hora do resumo', 'ru': 'Время обзора', 'tr': 'Özet saati'});
  String dailyTaskSummaryAt(String time) => _t({'en': 'Daily task summary at $time', 'bg': 'Дневен преглед на задачите в $time', 'de': 'Tägliche Aufgabenübersicht um $time', 'fr': 'Résumé quotidien à $time', 'it': 'Riepilogo giornaliero alle $time', 'el': 'Ημερήσια σύνοψη εργασιών στις $time', 'es': 'Resumen diario a las $time', 'pt': 'Resumo diário às $time', 'ru': 'Ежедневный обзор задач в $time', 'tr': 'Günlük görev özeti saat $time'});
  String briefingTimeSetTo(String time) => _t({'en': 'Briefing time set to $time', 'bg': 'Часът на прегледа е зададен на $time', 'de': 'Übersichtszeit auf $time gesetzt', 'fr': 'Heure du résumé réglée à $time', 'it': 'Orario riepilogo impostato alle $time', 'el': 'Ώρα ενημέρωσης ορίστηκε στις $time', 'es': 'Hora del resumen establecida a las $time', 'pt': 'Hora do resumo definida para $time', 'ru': 'Время обзора установлено на $time', 'tr': 'Özet saati $time olarak ayarlandı'});
  String get googleTasks => _t({'en': 'Google Tasks', 'bg': 'Google Задачи', 'de': 'Google Aufgaben', 'fr': 'Google Tasks', 'it': 'Google Tasks', 'el': 'Google Tasks', 'es': 'Google Tasks', 'pt': 'Google Tasks', 'ru': 'Google Задачи', 'tr': 'Google Görevler'});
  String get deleteAllCalendarTasks => _t({'en': 'Delete All Calendar Tasks', 'bg': 'Изтрий всички календарни задачи', 'de': 'Alle Kalenderaufgaben löschen', 'fr': 'Supprimer toutes les tâches du calendrier', 'it': 'Elimina tutte le attività del calendario', 'el': 'Διαγραφή όλων των εργασιών ημερολογίου', 'es': 'Eliminar todas las tareas del calendario', 'pt': 'Excluir todas as tarefas do calendário', 'ru': 'Удалить все задачи из календаря', 'tr': 'Tüm takvim görevlerini sil'});
  String get deleteCalendarTasksConfirm => _t({'en': 'This will delete all tasks imported from Google Calendar. This action cannot be undone.', 'bg': 'Това ще изтрие всички задачи, импортирани от Google Calendar. Действието е необратимо.', 'de': 'Dies löscht alle aus Google Kalender importierten Aufgaben. Diese Aktion kann nicht rückgängig gemacht werden.', 'fr': 'Cela supprimera toutes les tâches importées de Google Agenda. Cette action est irréversible.', 'it': 'Questo eliminerà tutte le attività importate da Google Calendar. Questa azione non può essere annullata.', 'el': 'Αυτό θα διαγράψει όλες τις εργασίες που εισήχθησαν από το Ημερολόγιο Google. Αυτή η ενέργεια δεν μπορεί να αναιρεθεί.', 'es': 'Esto eliminará todas las tareas importadas de Google Calendar. Esta acción no se puede deshacer.', 'pt': 'Isso excluirá todas as tarefas importadas do Google Agenda. Esta ação não pode ser desfeita.', 'ru': 'Это удалит все задачи, импортированные из Google Календаря. Это действие нельзя отменить.', 'tr': 'Bu, Google Takvimden içe aktarılan tüm görevleri silecektir. Bu işlem geri alınamaz.'});

  String get goodAfternoon => _t({'en': 'Good Afternoon! ☀️', 'bg': 'Добър ден! ☀️', 'de': 'Guten Tag! ☀️', 'fr': 'Bon après-midi! ☀️', 'it': 'Buon pomeriggio! ☀️', 'el': 'Καλό απόγευμα! ☀️', 'es': '¡Buenas tardes! ☀️', 'pt': 'Boa tarde! ☀️', 'ru': 'Добрый день! ☀️', 'tr': 'İyi öğleden sonralar! ☀️'});
  String get goodEvening => _t({'en': 'Good Evening! 🌙', 'bg': 'Добър вечер! 🌙', 'de': 'Guten Abend! 🌙', 'fr': 'Bonsoir! 🌙', 'it': 'Buonasera! 🌙', 'el': 'Καλό βράδυ! 🌙', 'es': '¡Buenas noches! 🌙', 'pt': 'Boa noite! 🌙', 'ru': 'Добрый вечер! 🌙', 'tr': 'İyi akşamlar! 🌙'});
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
    'tr': 'Toplam ürün',
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
    'tr': 'Satın alındı',
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
    'tr': 'Şablon',
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
    'tr': 'Yok',
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
    'tr': 'Alışveriş listesi',
  });



  String greetingForHour(int hour) {
    if (hour >= 5 && hour < 12) return goodMorning;
    if (hour >= 12 && hour < 18) return goodAfternoon;
    return goodEvening;
  }

  // Calendar import/export strings
  String get removeAllImported => _t({'en': 'Remove all imported events', 'bg': 'Премахни всички импортирани събития', 'de': 'Alle importierten Ereignisse entfernen', 'fr': 'Supprimer tous les événements importés', 'it': 'Rimuovi tutti gli eventi importati', 'el': 'Αφαίρεση όλων των εισαγόμενων γεγονότων', 'es': 'Eliminar todos los eventos importados', 'pt': 'Remover todos os eventos importados', 'ru': 'Удалить все импортированные события', 'tr': 'Tüm içe aktarılan etkinlikleri kaldır'});
  String importedSkipped(int imported, int skipped) => _t({'en': 'Imported: $imported, Skipped: $skipped', 'bg': 'Импортирани: $imported, Пропуснати: $skipped', 'de': 'Importiert: $imported, Übersprungen: $skipped', 'fr': 'Importés: $imported, Ignorés: $skipped', 'it': 'Importati: $imported, Saltati: $skipped', 'el': 'Εισαγωγή: $imported, Παράλειψη: $skipped', 'es': 'Importados: $imported, Omitidos: $skipped', 'pt': 'Importados: $imported, Ignorados: $skipped', 'ru': 'Импортировано: $imported, Пропущено: $skipped', 'tr': 'İçe aktarılan: $imported, Atlanan: $skipped'});
  String deletedCalendarTasks(int count) => _t({'en': 'Deleted $count calendar tasks', 'bg': 'Изтрити $count календарни задачи', 'de': '$count Kalenderaufgaben gelöscht', 'fr': '$count tâches du calendrier supprimées', 'it': '$count attività del calendario eliminate', 'el': 'Διαγράφηκαν $count εργασίες ημερολογίου', 'es': '$count tareas del calendario eliminadas', 'pt': '$count tarefas do calendário excluídas', 'ru': 'Удалено задач из календаря: $count', 'tr': '$count takvim görevi silindi'});
  String get backupSubject => _t({'en': 'Taskify Backup', 'bg': 'Taskify Архив', 'de': 'Taskify Sicherung', 'fr': 'Sauvegarde Taskify', 'it': 'Backup Taskify', 'el': 'Αντίγραφο Taskify', 'es': 'Copia de Taskify', 'pt': 'Backup Taskify', 'ru': 'Резервная копия Taskify', 'tr': 'Taskify Yedek'});
  String get untitledEvent => _t({'en': 'Untitled Event', 'bg': 'Без заглавие', 'de': 'Unbenanntes Ereignis', 'fr': 'Événement sans titre', 'it': 'Evento senza titolo', 'el': 'Χωρίς τίτλο', 'es': 'Evento sin título', 'pt': 'Evento sem título', 'ru': 'Без названия', 'tr': 'Adsız etkinlik'});
  String get untitledTask => _t({'en': 'Untitled Task', 'bg': 'Без заглавие', 'de': 'Unbenannte Aufgabe', 'fr': 'Tâche sans titre', 'it': 'Attività senza titolo', 'el': 'Χωρίς τίτλο', 'es': 'Tarea sin título', 'pt': 'Tarefa sem título', 'ru': 'Без названия', 'tr': 'Adsız görev'});
  // Default category names
  String get catWork => _t({'en': 'Work', 'bg': 'Работа', 'de': 'Arbeit', 'fr': 'Travail', 'it': 'Lavoro', 'el': 'Εργασία', 'es': 'Trabajo', 'pt': 'Trabalho', 'ru': 'Работа', 'tr': 'İş'});
  String get catPersonal => _t({'en': 'Personal', 'bg': 'Лични', 'de': 'Persönlich', 'fr': 'Personnel', 'it': 'Personale', 'el': 'Προσωπικά', 'es': 'Personal', 'pt': 'Pessoal', 'ru': 'Личное', 'tr': 'Kişisel'});
  String get catShopping => _t({'en': 'Shopping', 'bg': 'Пазаруване', 'de': 'Einkaufen', 'fr': 'Courses', 'it': 'Acquisti', 'el': 'Αγορές', 'es': 'Compras', 'pt': 'Compras', 'ru': 'Покупки', 'tr': 'Alışveriş'});
  String get catCalendarEvents => _t({'en': 'Calendar Events', 'bg': 'Календарни събития', 'de': 'Kalenderereignisse', 'fr': 'Événements du calendrier', 'it': 'Eventi del calendario', 'el': 'Γεγονότα ημερολογίου', 'es': 'Eventos del calendario', 'pt': 'Eventos do calendário', 'ru': 'События календаря', 'tr': 'Takvim etkinlikleri'});
  String get catBirthdays => _t({'en': 'Birthdays', 'bg': 'Рождени дни', 'de': 'Geburtstage', 'fr': 'Anniversaires', 'it': 'Compleanni', 'el': 'Γενέθλια', 'es': 'Cumpleaños', 'pt': 'Aniversários', 'ru': 'Дни рождения', 'tr': 'Doğum günleri'});
  String get catOutOfOffice => _t({'en': 'Out of Office', 'bg': 'Извън офиса', 'de': 'Abwesend', 'fr': 'Absent du bureau', 'it': 'Fuori ufficio', 'el': 'Εκτός γραφείου', 'es': 'Fuera de oficina', 'pt': 'Fora do escritório', 'ru': 'Не в офисе', 'tr': 'Ofis dışında'});
  String get catFocusTime => _t({'en': 'Focus Time', 'bg': 'Фокус време', 'de': 'Fokuszeit', 'fr': 'Temps de concentration', 'it': 'Tempo di concentrazione', 'el': 'Ώρα συγκέντρωσης', 'es': 'Tiempo de concentración', 'pt': 'Tempo de foco', 'ru': 'Время концентрации', 'tr': 'Odaklanma zamanı'});
  String get catWorkLocation => _t({'en': 'Work Location', 'bg': 'Работно място', 'de': 'Arbeitsort', 'fr': 'Lieu de travail', 'it': 'Luogo di lavoro', 'el': 'Τοποθεσία εργασίας', 'es': 'Ubicación de trabajo', 'pt': 'Local de trabalho', 'ru': 'Место работы', 'tr': 'Çalışma yeri'});
  // Notification fallbacks
  String get reminderFallback => _t({'en': 'Reminder', 'bg': 'Напомняне', 'de': 'Erinnerung', 'fr': 'Rappel', 'it': 'Promemoria', 'el': 'Υπενθύμιση', 'es': 'Recordatorio', 'pt': 'Lembrete', 'ru': 'Напоминание', 'tr': 'Hatırlatıcı'});
  String get taskDueFallback => _t({'en': 'You have a task to complete', 'bg': 'Имаш задача за изпълнение', 'de': 'Du hast eine Aufgabe zu erledigen', 'fr': 'Vous avez une tâche à accomplir', 'it': 'Hai un\'attività da completare', 'el': 'Έχετε μια εργασία να ολοκληρώσετε', 'es': 'Tienes una tarea por completar', 'pt': 'Você tem uma tarefa para concluir', 'ru': 'У вас есть задача для выполнения', 'tr': 'Tamamlamanız gereken bir görev var'});

}
