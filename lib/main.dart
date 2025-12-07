import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'models/task.dart';
import 'models/category.dart';
import 'screens/home/home_screen.dart';
import 'utils/localization.dart';
import 'services/widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // FIREBASE ИНИЦИАЛИЗАЦИЯ ЗА ВСИЧКИ ПЛАТФОРМИ
  if (kIsWeb) {
    // КОНФИГУРАЦИЯ ЗА WEB (ТВОИТЕ КЛЮЧОВЕ)
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyPublica.cnXjwJlMtNtvWkcc0iPhYzIJSmeE",
        authDomain: "taskify-1969.firebaseapp.com",
        projectId: "taskify-1969",
        storageBucket: "taskify-1969.firebasestorage.app",
        messagingSenderId: "92996434969",
        appId: "1:92996434969:web:1967D6eac4ef5c69687444",
      ),
    );
  } else {
    // СТАНДАРТНА ИНИЦИАЛИЗАЦИЯ ЗА ANDROID/IOS
    await Firebase.initializeApp();
  }
  
  // HIVE (РАБОТИ НА ВСИЧКИ ПЛАТФОРМИ)
  await Hive.initFlutter();
  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(CategoryAdapter());
  await Hive.openBox<Task>('tasks');
  await Hive.openBox<Category>('categories');

  // WIDGET СЕРВИЗ: САМО ЗА ANDROID/IOS
  if (!kIsWeb) {
    WidgetService.setupWidgetListener();
    await WidgetService.syncFromWidget();
    await WidgetService.updateWidget();
  }

  final languageController = LanguageController(const Locale('bg'));
  await languageController.loadSavedLocale();
  
  final themeController = ThemeController(ThemeMode.system);
  runApp(
    MyApp(
      languageController: languageController,
      themeController: themeController,
    ),
  );
}

// ... (ОСТАВА НЕПРОМЕНЕНА ЧАСТТА С MyApp, _buildLightTheme, _buildDarkTheme)