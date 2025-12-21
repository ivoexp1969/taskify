import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Контролер за езика (bg / en)
class LanguageController extends ChangeNotifier {
  LanguageController([Locale? initial])
      : _locale = initial ?? const Locale('bg');

  Locale _locale;

  Locale get locale => _locale;

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    
    // Запазваме в SharedPreferences за widget-а
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', locale.languageCode);
    
    notifyListeners();
  }
  
  /// Зарежда запазения език при стартиране
  Future<void> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('app_language');
    if (langCode != null) {
      _locale = Locale(langCode);
      notifyListeners();
    }
  }
}

/// Scope за езика – достъпен навсякъде в дървото
class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({
    super.key,
    required LanguageController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static LanguageController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<LanguageScope>();
    assert(scope != null, 'LanguageScope not found in context');
    return scope!.notifier!;
  }
}

/// Контролер за тема (system / light / dark)
class ThemeController extends ChangeNotifier {
  ThemeController([ThemeMode? initial])
      : _mode = initial ?? ThemeMode.system;

  ThemeMode _mode;

  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }
}

/// Scope за темата – достъпен навсякъде в дървото
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static ThemeController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope not found in context');
    return scope!.notifier!;
  }
}

/// Локализирани текстове – използва езика от LanguageScope
class AppText {
  final Locale locale;
  final bool isBg;

  AppText._(this.locale) : isBg = locale.languageCode == 'bg';

  static AppText of(BuildContext context) {
    final controller = LanguageScope.of(context);
    return AppText._(controller.locale);
  }

  // Основни екрани
  String get tasks => isBg ? 'Задачи' : 'Tasks';
  String get calendar => isBg ? 'Календар' : 'Calendar';
  String get settings => isBg ? 'Настройки' : 'Settings';

  // Статистика
  String get total => isBg ? 'Общо' : 'Total';
  String get completed => isBg ? 'Завършени' : 'Completed';
  String get overdue => isBg ? 'Просрочени' : 'Overdue';
  String get upcoming => isBg ? 'Предстоящи' : 'Upcoming';

  // Приоритет
  String get low => isBg ? 'Нисък' : 'Low';
  String get medium => isBg ? 'Среден' : 'Medium';
  String get high => isBg ? 'Висок' : 'High';

  // Повторяемост
  String get noRepeat => isBg ? 'Без повторение' : 'No repeat';
  String get daily => isBg ? 'Ежедневно' : 'Daily';
  String get weekly => isBg ? 'Ежеседмично' : 'Weekly';
  String get monthly => isBg ? 'Ежемесечно' : 'Monthly';
  String get yearly => isBg ? 'Ежегодно' : 'Yearly';

  // Общи бутони
  String get add => isBg ? 'Добави' : 'Add';
  String get cancel => isBg ? 'Отказ' : 'Cancel';

  // Полета на задачата
  String get category => isBg ? 'Категория' : 'Category';
  String get title => isBg ? 'Заглавие' : 'Title';
  String get newTask => isBg ? 'Нова задача' : 'New Task';
  String get dueDate => isBg ? 'Срок' : 'Due date';
  String get time => isBg ? 'Час' : 'Time';
  String get priority => isBg ? 'Приоритет' : 'Priority';
  String get repeat => isBg ? 'Повторение' : 'Repeat';

  // Категории (дефолтни)
  String get work => isBg ? 'Работа' : 'Work';
  String get personal => isBg ? 'Лични' : 'Personal';
  String get shopping => isBg ? 'Пазаруване' : 'Shopping';

  // Настройки – език
  String get language => isBg ? 'Език' : 'Language';
  String get bulgarian => isBg ? 'Български' : 'Bulgarian';
  String get english => isBg ? 'Английски' : 'English';

  // Настройки – тема
  String get theme => isBg ? 'Тема' : 'Theme';
  String get systemTheme => isBg ? 'Системна' : 'System';
  String get lightTheme => isBg ? 'Светла' : 'Light';
  String get darkTheme => isBg ? 'Тъмна' : 'Dark';
}