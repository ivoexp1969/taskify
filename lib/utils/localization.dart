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
  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
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
  String get statistics => _t({'en': 'Statistics', 'bg': 'Статистики', 'de': 'Statistiken', 'fr': 'Statistiques', 'it': 'Statistiche', 'el': 'Στατιστικά', 'es': 'Estadísticas', 'pt': 'Estatísticas', 'ru': 'Статистика', 'tr': 'İstatistikler'});
  String get viewProgress => _t({'en': 'View your progress', 'bg': 'Преглед на твоя прогрес', 'de': 'Zeige deinen Fortschritt', 'fr': 'Voir votre progression', 'it': 'Visualizza i tuoi progressi', 'el': 'Δείτε την πρόοδό σας', 'es': 'Ver tu progreso', 'pt': 'Ver seu progresso', 'ru': 'Посмотреть прогресс', 'tr': 'İlerlemenizi görün'});
  String get today => _t({'en': 'Today', 'bg': 'Днес', 'de': 'Heute', 'fr': "Aujourd'hui", 'it': 'Oggi', 'el': 'Σήμερα', 'es': 'Hoy', 'pt': 'Hoje', 'ru': 'Сегодня', 'tr': 'Bugün'});
  String get week => _t({'en': 'Week', 'bg': 'Седмица', 'de': 'Woche', 'fr': 'Semaine', 'it': 'Settimana', 'el': 'Εβδομάδα', 'es': 'Semana', 'pt': 'Semana', 'ru': 'Неделя', 'tr': 'Hafta'});
  String get month => _t({'en': 'Month', 'bg': 'Месец', 'de': 'Monat', 'fr': 'Mois', 'it': 'Mese', 'el': 'Μήνας', 'es': 'Mes', 'pt': 'Mês', 'ru': 'Месяц', 'tr': 'Ay'});
  String get day => _t({'en': 'Day', 'bg': 'Ден', 'de': 'Tag', 'fr': 'Jour', 'it': 'Giorno', 'el': 'Ημέρα', 'es': 'Día', 'pt': 'Dia', 'ru': 'День', 'tr': 'Gün'});

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
  String get repeat => _t({'en': 'Repeat', 'bg': 'Повторение', 'de': 'Wiederholung', 'fr': 'Répétition', 'it': 'Ripetizione', 'el': 'Επανάληψη', 'es': 'Repetir', 'pt': 'Repetir', 'ru': 'Повтор', 'tr': 'Tekrar'});
  String get whatNeedsToBeDone => _t({'en': 'What needs to be done?', 'bg': 'Какво трябва да направиш?', 'de': 'Was muss erledigt werden?', 'fr': 'Que faut-il faire?', 'it': 'Cosa bisogna fare?', 'el': 'Τι πρέπει να γίνει;', 'es': '¿Qué hay que hacer?', 'pt': 'O que precisa ser feito?', 'ru': 'Что нужно сделать?', 'tr': 'Ne yapılmalı?'});

  // ==================== КАТЕГОРИИ ====================
  String get work => _t({'en': 'Work', 'bg': 'Работа', 'de': 'Arbeit', 'fr': 'Travail', 'it': 'Lavoro', 'el': 'Εργασία', 'es': 'Trabajo', 'pt': 'Trabalho', 'ru': 'Работа', 'tr': 'İş'});
  String get personal => _t({'en': 'Personal', 'bg': 'Лични', 'de': 'Persönlich', 'fr': 'Personnel', 'it': 'Personale', 'el': 'Προσωπικά', 'es': 'Personal', 'pt': 'Pessoal', 'ru': 'Личное', 'tr': 'Kişisel'});
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
  String get name => _t({'en': 'Name', 'bg': 'Име', 'de': 'Name', 'fr': 'Nom', 'it': 'Nome', 'el': 'Όνομα', 'es': 'Nombre', 'pt': 'Nome', 'ru': 'Название', 'tr': 'Ad'});

  // ==================== ЕЗИК И ТЕМА ====================
  String get language => _t({'en': 'Language', 'bg': 'Език', 'de': 'Sprache', 'fr': 'Langue', 'it': 'Lingua', 'el': 'Γλώσσα', 'es': 'Idioma', 'pt': 'Idioma', 'ru': 'Язык', 'tr': 'Dil'});
  String get bulgarian => _t({'en': 'Bulgarian', 'bg': 'Български', 'de': 'Bulgarisch', 'fr': 'Bulgare', 'it': 'Bulgaro', 'el': 'Βουλγαρικά', 'es': 'Búlgaro', 'pt': 'Búlgaro', 'ru': 'Болгарский', 'tr': 'Bulgarca'});
  String get english => _t({'en': 'English', 'bg': 'Английски', 'de': 'Englisch', 'fr': 'Anglais', 'it': 'Inglese', 'el': 'Αγγλικά', 'es': 'Inglés', 'pt': 'Inglês', 'ru': 'Английский', 'tr': 'İngilizce'});
  String get theme => _t({'en': 'Theme', 'bg': 'Тема', 'de': 'Design', 'fr': 'Thème', 'it': 'Tema', 'el': 'Θέμα', 'es': 'Tema', 'pt': 'Tema', 'ru': 'Тема', 'tr': 'Tema'});
  String get systemTheme => _t({'en': 'System', 'bg': 'Системна', 'de': 'System', 'fr': 'Système', 'it': 'Sistema', 'el': 'Σύστημα', 'es': 'Sistema', 'pt': 'Sistema', 'ru': 'Системная', 'tr': 'Sistem'});
  String get lightTheme => _t({'en': 'Light', 'bg': 'Светла', 'de': 'Hell', 'fr': 'Clair', 'it': 'Chiaro', 'el': 'Φωτεινό', 'es': 'Claro', 'pt': 'Claro', 'ru': 'Светлая', 'tr': 'Açık'});
  String get darkTheme => _t({'en': 'Dark', 'bg': 'Тъмна', 'de': 'Dunkel', 'fr': 'Sombre', 'it': 'Scuro', 'el': 'Σκοτεινό', 'es': 'Oscuro', 'pt': 'Escuro', 'ru': 'Темная', 'tr': 'Koyu'});

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
}
