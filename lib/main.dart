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
    // КОНФИГУРАЦИЯ ЗА WEB (ТОЧНИТЕ КЛЮЧОВЕ)
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDAwis_cnXVpWIMrNzvWAcaOhPVrIJSewE",
        authDomain: "taskify-1969.firebasestorage.app",
        projectId: "taskify-1969",
        storageBucket: "taskify-1969.firebasestorage.app",
        messagingSenderId: "929046134968",
        appId: "1:929046134968:web:5f2754f3d7efee5bc8744d",
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

class MyApp extends StatelessWidget {
  final LanguageController languageController;
  final ThemeController themeController;

  const MyApp({
    super.key,
    required this.languageController,
    required this.themeController,
  });

  @override
  Widget build(BuildContext context) {
    return LanguageScope(
      controller: languageController,
      child: ThemeScope(
        controller: themeController,
        child: AnimatedBuilder(
          animation:
              Listenable.merge([languageController, themeController]),
          builder: (context, _) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Taskify',
              themeMode: themeController.mode,
              theme: _buildLightTheme(),
              darkTheme: _buildDarkTheme(),
              home: const HomeScreen(),
            );
          },
        ),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF4F46E5),
      brightness: Brightness.light,
    );
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF4F4F7),
      cardTheme: base.cardTheme.copyWith(
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        centerTitle: true,
        elevation: 0,
        backgroundColor: base.colorScheme.surface,
        foregroundColor: base.colorScheme.onSurface,
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        elevation: 3,
        shape: const StadiumBorder(),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF4F46E5),
      brightness: Brightness.dark,
    );
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF020617),
      cardTheme: base.cardTheme.copyWith(
        elevation: 1,
        margin: EdgeInsets.zero,
        color: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: base.colorScheme.onSurface,
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        elevation: 3,
        shape: const StadiumBorder(),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
}