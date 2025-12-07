import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'models/task.dart';
import 'models/category.dart';
import 'screens/home/home_screen.dart';
import 'utils/localization.dart';
import 'services/widget_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // FIREBASE ИНИЦИАЛИЗАЦИЯ - ИЗПОЛЗВА firebase_options.dart
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
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

class MyApp extends StatefulWidget {
  final LanguageController languageController;
  final ThemeController themeController;

  const MyApp({
    super.key,
    required this.languageController,
    required this.themeController,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    // Заявка за разрешение при първо стартиране
    final notificationService = NotificationService();
    final enabled = await notificationService.areNotificationsEnabled();
    
    if (!enabled && kIsWeb) {
      // На Web показваме prompt само след user interaction
      // Това ще стане при първо създаване на задача с reminder
      print('Notifications not yet enabled - will prompt on first reminder');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LanguageScope(
      controller: widget.languageController,
      child: ThemeScope(
        controller: widget.themeController,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            widget.languageController,
            widget.themeController
          ]),
          builder: (context, _) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Taskify',
              themeMode: widget.themeController.mode,
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