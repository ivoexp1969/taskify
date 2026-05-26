import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'models/task.dart';
import 'models/category.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'utils/localization.dart';
import 'services/widget_service.dart';
import 'services/pro_service.dart';
import 'services/ad_service.dart';
import 'services/task_view_preference.dart';
import 'services/notification_service.dart';
import 'widgets/morning_briefing_dialog.dart';
import 'services/google_calendar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/morning_briefing_service.dart';

Future<void> _checkMorningBriefingOnLaunch() async {
  final prefs = await SharedPreferences.getInstance();
  final shouldShow = prefs.getBool('show_morning_briefing') ?? false;
  
  if (shouldShow) {
    await prefs.setBool('show_morning_briefing', false); // Clear flag immediately
    Future.delayed(const Duration(seconds: 1), () {
      final context = MyApp.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        MorningBriefingDialog.show(context);
      }
    });
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
    WidgetService.updateWidget();
  }

  await TaskViewPreference().initialize();

  // Initialize notification service (registers tap handler)
  await NotificationService().init();

  // Setup morning briefing notification callback
  NotificationService.setMorningBriefingCallback((BuildContext context) {
    MorningBriefingDialog.show(context);
  });

  // Pro и Ad сервизи — fire-and-forget, не блокират UI
  // Trial notification се планира след като ProService завърши инициализацията
  ProService().initialize().then((_) {
    if (!kIsWeb && ProService().isTrial) {
      final trialEnd = ProService().trialEndDate;
      if (trialEnd != null) {
        NotificationService().scheduleTrialCountdownNotification(trialEnd);
      }
    }
  });
  AdService().initialize();

  // Try reconnect Google Calendar silently
  GoogleCalendarService().tryReconnect();

  // Morning briefing — refresh top 3 tasks on every launch
  if (!kIsWeb) {
    MorningBriefingService().updateBriefingContent();
  }

  final languageController = LanguageController(const Locale('en'));
  // Зареждаме системния език при първо стартиране
  final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
  await languageController.loadSavedLocale(systemLocale);
  
  final themeController = ThemeController(ThemeMode.system);
  await themeController.loadSavedTheme();

  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_v1_done') ?? false;

  runApp(
    MyApp(
      languageController: languageController,
      themeController: themeController,
      onboardingDone: onboardingDone,
    ),
  );
  
  // Check morning briefing AFTER widget tree is built
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _checkMorningBriefingOnLaunch();
  });
}

class MyApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  final LanguageController languageController;
  final ThemeController themeController;
  final bool onboardingDone;

  const MyApp({
    super.key,
    required this.languageController,
    required this.themeController,
    this.onboardingDone = true,
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
              locale: languageController.locale,
              supportedLocales: SupportedLocales.all,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              themeMode: themeController.isAmoled ? ThemeMode.dark : themeController.mode,
              theme: _buildLightTheme(),
              darkTheme: themeController.isAmoled ? _buildAmoledTheme() : _buildDarkTheme(),
              home: onboardingDone ? const HomeScreen() : const OnboardingScreen(),
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
      textTheme: GoogleFonts.poppinsTextTheme(),
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
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData(brightness: Brightness.dark).textTheme),
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
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData(brightness: Brightness.dark).textTheme),
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
            color: Colors.white.withValues(alpha: 0.08),
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




