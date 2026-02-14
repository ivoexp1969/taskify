import 'services/google_calendar_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'services/google_calendar_service.dart';
import 'package:flutter/material.dart';
import 'services/google_calendar_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/google_calendar_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'models/task.dart';
import 'models/category.dart';
import 'screens/home/home_screen.dart';
import 'utils/localization.dart';
import 'services/widget_service.dart';
import 'services/pro_service.dart';
import 'services/ad_service.dart';
import 'services/task_view_preference.dart';
import 'services/notification_service.dart';
import 'widgets/morning_briefing_dialog.dart';
import 'services/google_calendar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _checkMorningBriefingOnLaunch() async {
  final prefs = await SharedPreferences.getInstance();
  final lastScheduled = prefs.getInt('morning_briefing_last_scheduled');
  final lastShown = prefs.getInt('morning_briefing_last_shown');
  
  if (lastScheduled != null) {
    final scheduledTime = DateTime.fromMillisecondsSinceEpoch(lastScheduled);
    final now = DateTime.now();
    
    // If launched within 10 minutes after scheduled time and not shown yet
    final diff = now.difference(scheduledTime).inMinutes;
    if (diff >= 0 && diff <= 10 && lastShown != lastScheduled) {
      // Show briefing after a short delay to let UI initialize
      Future.delayed(const Duration(seconds: 1), () {
        final context = MyApp.navigatorKey.currentContext;
        if (context != null) {
          MorningBriefingDialog.show(context);
          prefs.setInt('morning_briefing_last_shown', lastScheduled);
        }
      });
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter();
  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(CategoryAdapter());
  await Hive.openBox<Task>('tasks');
  await Hive.openBox<Category>('categories');

  // Widget инициализация - само за mobile
  if (!kIsWeb) {
    WidgetService.setupWidgetListener();
    await WidgetService.syncFromWidget();
    await WidgetService.updateWidget();
  }

  // Pro и Ad сервизи инициализация
  await ProService().initialize();
  await AdService().initialize();
  await TaskViewPreference().initialize();
  
  // Setup morning briefing notification callback
  NotificationService.setMorningBriefingCallback((BuildContext context) {
    MorningBriefingDialog.show(context);
  });
  
  // Check if we should show morning briefing on launch
  await _checkMorningBriefingOnLaunch();

  final languageController = LanguageController(const Locale('en'));
  // Зареждаме системния език при първо стартиране
  final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
  await languageController.loadSavedLocale(systemLocale);
  
  final themeController = ThemeController(ThemeMode.system);
  await themeController.loadSavedTheme();
  

  runApp(
    MyApp(
      languageController: languageController,
      themeController: themeController,
    ),
  );
}

class MyApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
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
          animation: Listenable.merge([languageController, themeController]),
          builder: (context, _) {
            return MaterialApp(
                navigatorKey: MyApp.navigatorKey,
                debugShowCheckedModeBanner: false,
              title: 'Taskify',
              themeMode: themeController.isAmoled ? ThemeMode.dark : themeController.mode,
              theme: _buildLightTheme(),
              darkTheme: themeController.isAmoled ? _buildAmoledTheme() : _buildDarkTheme(),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  ThemeData _buildAmoledTheme() {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF4F46E5),
      brightness: Brightness.dark,
    );
    return base.copyWith(
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
      cardTheme: base.cardTheme.copyWith(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: base.bottomNavigationBarTheme.copyWith(
        backgroundColor: Colors.black,
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: Colors.black,
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        elevation: 3,
        shape: const StadiumBorder(),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: const Color(0xFF0A0A0A),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: const Color(0xFF0A0A0A),
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: const Color(0xFF0A0A0A),
      ),
      colorScheme: base.colorScheme.copyWith(
        surface: Colors.black,
      ),
    );
  }
}

