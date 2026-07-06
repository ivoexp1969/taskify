import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../task/task_screen.dart';
import '../calendar/calendar_screen.dart';
import '../settings/settings_screen.dart';
import '../documents/documents_screen.dart';
import '../shared/shared_groups_screen.dart';
import '../../utils/localization.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../services/pro_service.dart';
import '../../services/holidays_service.dart';
import '../../services/sync_service.dart';
import '../paywall/paywall_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final ProService _proService = ProService();
  bool _welcomeChecked = false;

  /// Разделът „Документи" се показва на ВСИЧКИ (универсална функция; Pro gated).
  bool get _showDocuments => true;

  /// Екраните в долната навигация. „Документи" се вмъква преди Настройки.
  List<Widget> get _screens => [
        const TaskScreen(),
        const SharedGroupsScreen(),
        const CalendarScreen(),
        if (_showDocuments) const DocumentsScreen(),
        const SettingsScreen(),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _proService.addListener(_onProStatusChanged);
    if (!kIsWeb) {
      _initAndShowWelcome();
      _maybeShowHolidaysPrompt();
      // ФАЗА 4: cold-start routing на ден-3/ден-7 нотификация (app беше убит).
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _consumePendingConversionRoute());
    }
  }

  /// Консумира маршрута, оставен от notification tap при студен старт.
  Future<void> _consumePendingConversionRoute() async {
    final prefs = await SharedPreferences.getInstance();

    // Идея 1: cold-start от напомняне за документ → отваря „Документи" (там е CTA-то).
    final renew = prefs.getString('renew_pending_route');
    if (renew != null) {
      await prefs.remove('renew_pending_route');
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DocumentsScreen()),
        );
      }
      return;
    }

    final route = prefs.getString('conv_pending_route');
    if (route == null) return;
    await prefs.remove('conv_pending_route');
    if (!context.mounted) return;
    if (route == 'conv_day7') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
    } else {
      await TaskEditorBridge.openNewSelfManaged();
    }
  }

  /// ФАЗА 2В: синхрон при връщане на фокус (resume). На iOS това е основният
  /// надежден тригер (applicationDidBecomeActive), защото фоновата работа е
  /// силно ограничена. На Android/web също е безобидно полезно.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SyncService().syncNow();
    }
  }

  /// Еднократно, проактивно одобрение за официалните празници (само BG контекст,
  /// БЕЗ GPS — държавата идва от device locale). Топъл, личен тон.
  Future<void> _maybeShowHolidaysPrompt() async {
    // Изчакваме да минат другите стартови диалози (welcome и т.н.).
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final lang = LanguageScope.of(context).locale.languageCode;
    final country = WidgetsBinding.instance.platformDispatcher.locale.countryCode
        ?.toUpperCase();
    final isBg = lang == 'bg' || country == 'BG';
    if (!isBg) return;

    if (await HolidaysService().isPromptShown()) return;
    if (HolidaysService.enabledNotifier.value) {
      await HolidaysService().markPromptShown();
      return;
    }
    await HolidaysService().markPromptShown();
    if (!mounted) return;

    const title = {
      'en': 'Public holidays', 'bg': 'Официални празници',
      'de': 'Gesetzliche Feiertage', 'fr': 'Jours fériés',
      'it': 'Festività ufficiali', 'el': 'Επίσημες αργίες',
      'es': 'Días festivos', 'pt': 'Feriados oficiais',
      'ru': 'Официальные праздники', 'tr': 'Resmi tatiller', 'ja': '祝日',
    };
    const body = {
      'en': "I see you're in Bulgaria. Want me to show the official holidays in your calendar? 🇧🇬",
      'bg': 'Виждам, че си в България. Да ти показвам ли официалните празници в календара? 🇧🇬',
      'de': 'Ich sehe, du bist in Bulgarien. Soll ich die Feiertage in deinem Kalender anzeigen? 🇧🇬',
      'fr': 'Je vois que tu es en Bulgarie. Je t\'affiche les jours fériés dans le calendrier? 🇧🇬',
      'it': 'Vedo che sei in Bulgaria. Ti mostro le festività nel calendario? 🇧🇬',
      'el': 'Βλέπω ότι είσαι στη Βουλγαρία. Να σου δείχνω τις αργίες στο ημερολόγιο; 🇧🇬',
      'es': 'Veo que estás en Bulgaria. ¿Te muestro los festivos en el calendario? 🇧🇬',
      'pt': 'Vejo que estás na Bulgária. Mostro os feriados no teu calendário? 🇧🇬',
      'ru': 'Вижу, что ты в Болгарии. Показывать праздники в календаре? 🇧🇬',
      'tr': 'Bulgaristan\'da olduğunu görüyorum. Resmi tatilleri takvimde göstereyim mi? 🇧🇬', 'ja': 'ブルガリアにいらっしゃるようですね。公式の祝日をカレンダーに表示しますか？🇧🇬',
    };
    const yes = {
      'en': 'Yes, please', 'bg': 'Да, покажи', 'de': 'Ja, gern',
      'fr': 'Oui', 'it': 'Sì', 'el': 'Ναι', 'es': 'Sí',
      'pt': 'Sim', 'ru': 'Да', 'tr': 'Evet', 'ja': 'はい、お願いします',
    };
    const no = {
      'en': 'Not now', 'bg': 'Не сега', 'de': 'Nicht jetzt',
      'fr': 'Pas maintenant', 'it': 'Non ora', 'el': 'Όχι τώρα',
      'es': 'Ahora no', 'pt': 'Agora não', 'ru': 'Не сейчас', 'tr': 'Şimdi değil', 'ja': '後で',
    };
    String tr(Map<String, String> m) => m[lang] ?? m['en']!;

    final accept = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.flag_rounded,
            size: 40, color: Color(HolidaysService.colorValue)),
        title: Text(tr(title)),
        content: Text(tr(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr(no)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr(yes)),
          ),
        ],
      ),
    );

    if (accept == true) {
      await HolidaysService().setEnabled(true);
      await HolidaysService().loadForCurrentYears();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _proService.removeListener(_onProStatusChanged);
    super.dispose();
  }

  void _onProStatusChanged() {
    if (mounted) {
      setState(() {});
      // Ако ProService е инициализиран и още не сме проверили welcome
      if (!_welcomeChecked && _proService.isInitialized) {
        _showTrialWelcome();
      }
    }
  }

  /// Чака ProService да се инициализира, после показва welcome
  Future<void> _initAndShowWelcome() async {
    // Чакаме ProService да се инициализира (ако не е)
    if (!_proService.isInitialized) {
      await _proService.initialize();
    }
    _showTrialWelcome();
  }

  void _showTrialWelcome() async {
    if (_welcomeChecked) return;
    _welcomeChecked = true;
    
    // Проверяваме SharedPreferences ПЪРВО
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool('taskify_welcome_shown_v2') ?? false;
    
    debugPrint('Welcome check: alreadyShown=$alreadyShown, isTrial=${_proService.isTrial}, daysLeft=${_proService.trialDaysLeft}');
    
    if (alreadyShown) {
      debugPrint('Welcome dialog already shown, skipping');
      return;
    }
    
    // Показваме само ако е в trial и има поне 13 дни
    if (_proService.isTrial && _proService.trialDaysLeft >= 13) {
      // Маркираме като показан ПРЕДИ да покажем диалога
      await prefs.setBool('taskify_welcome_shown_v2', true);
      debugPrint('Welcome dialog will be shown, marked as shown');
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final languageController = LanguageScope.of(context);
        final lang = languageController.locale.languageCode;
        
        const welcomeTitle = {'en': 'Welcome!', 'bg': 'Добре дошъл!', 'de': 'Willkommen!', 'fr': 'Bienvenue!', 'it': 'Benvenuto!', 'el': 'Καλώς ήρθες!', 'es': '¡Bienvenido!', 'pt': 'Bem-vindo!', 'ru': 'Добро пожаловать!', 'tr': 'Hoş geldin!', 'ja': 'ようこそ！'};
        const welcomeBody = {'en': 'You have 14 days free Pro access!\n\nTry all features and see how Taskify can help you be more productive.', 'bg': 'Имаш 14 дни безплатен Pro достъп!\n\nИзползвай всички функции и виж как Taskify ще ти помогне да си по-продуктивен.', 'de': 'Du hast 14 Tage kostenlosen Pro-Zugang!\n\nProbiere alle Funktionen aus.', 'fr': 'Vous avez 14 jours d\'accès Pro gratuit!\n\nEssayez toutes les fonctionnalités.', 'it': 'Hai 14 giorni di accesso Pro gratuito!\n\nProva tutte le funzionalità.', 'el': 'Έχεις 14 ημέρες δωρεάν Pro πρόσβαση!\n\nΔοκίμασε όλες τις λειτουργίες.', 'es': '¡Tienes 14 días de acceso Pro gratis!\n\nPrueba todas las funciones.', 'pt': 'Você tem 14 dias de acesso Pro grátis!\n\nExperimente todos os recursos.', 'ru': 'У вас 14 дней бесплатного Pro доступа!\n\nПопробуйте все функции.', 'tr': '14 gün ücretsiz Pro erişiminiz var!\n\nTüm özellikleri deneyin.', 'ja': '14日間の無料Proアクセスがあります！\n\nすべての機能を試して、Taskifyがどれだけ生産性を高めるか体験してください。'};
        const welcomeBtn = {'en': 'Awesome!', 'bg': 'Страхотно!', 'de': 'Super!', 'fr': 'Génial!', 'it': 'Fantastico!', 'el': 'Τέλεια!', 'es': '¡Genial!', 'pt': 'Incrível!', 'ru': 'Отлично!', 'tr': 'Harika!', 'ja': '最高！'};
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.celebration_rounded, size: 48, color: Colors.amber),
            title: Text(welcomeTitle[lang] ?? welcomeTitle['en']!),
            content: Text(
              welcomeBody[lang] ?? welcomeBody['en']!,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(welcomeBtn[lang] ?? welcomeBtn['en']!),
              ),
            ],
          ),
        );
      });
    }
  }

  void _onDestinationSelected(int index) async {
    if (!kIsWeb && index == 2 && !_proService.canUseCalendar) {
      final languageController = LanguageScope.of(context);
      final lang = languageController.locale.languageCode;
      const calendarName = {'en': 'Calendar', 'bg': 'Календар', 'de': 'Kalender', 'fr': 'Calendrier', 'it': 'Calendario', 'el': 'Ημερολόγιο', 'es': 'Calendario', 'pt': 'Calendário', 'ru': 'Календарь', 'tr': 'Takvim', 'ja': 'カレンダー'};

      final upgraded = await showPaywallIfNeeded(
        context,
        isFeatureAvailable: false,
        featureName: calendarName[lang] ?? calendarName['en']!,
      );

      if (!upgraded) return;
    }

    // Идея 1 / Фаза 3: „Документи" вече е достъпен и за free потребители — така
    // partner CTA-то „Поднови сега" стига до цялата база. Лимитът е на БРОЯ
    // документи и се налага при СЪЗДАВАНЕ (виж DocumentDialog), не на входа.

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Списъкът може да се промени (вкл./изкл. на „България") — пазим индекса валиден.
    final screens = _screens;
    final showDocuments = _showDocuments;
    if (_currentIndex >= screens.length) _currentIndex = 0;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            if (!kIsWeb && !_proService.isPaid && !_proService.isPromoCode && _proService.isTrial)
              _buildProBanner(context),

            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
            ),
            
            const BannerAdWidget(),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: theme.colorScheme.surface,
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Theme(
              data: theme.copyWith(
                navigationBarTheme: NavigationBarThemeData(
                  labelTextStyle: WidgetStateProperty.all(
                    const TextStyle(
                      fontSize: 10,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              child: NavigationBar(
              height: 64,
              backgroundColor: Colors.transparent,
              indicatorColor: theme.colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.12),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              selectedIndex: _currentIndex,
              onDestinationSelected: _onDestinationSelected,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.checklist_rtl_outlined),
                  selectedIcon: const Icon(Icons.checklist_rtl),
                  label: t.tasks,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.groups_outlined),
                  selectedIcon: const Icon(Icons.groups_rounded),
                  label: t.sharedTab,
                ),
                NavigationDestination(
                  icon: Stack(
                    children: [
                      const Icon(Icons.calendar_today_outlined),
                      if (!kIsWeb && !_proService.canUseCalendar)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Icon(
                            Icons.lock,
                            size: 12,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                  selectedIcon: const Icon(Icons.calendar_today),
                  label: t.calendar,
                ),
                if (showDocuments)
                  NavigationDestination(
                    icon: Stack(
                      children: [
                        const Icon(Icons.badge_outlined),
                        if (!kIsWeb && !_proService.isPro)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Icon(
                              Icons.lock,
                              size: 12,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                    selectedIcon: const Icon(Icons.badge),
                    label: t.documents,
                  ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: t.settings,
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildProBanner(BuildContext context) {
    final theme = Theme.of(context);
    
    final daysLeft = _proService.isTrial 
        ? _proService.trialDaysLeft 
        : _proService.promoDaysLeft;
    
    final isUrgent = daysLeft <= 3;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUrgent 
              ? [Colors.orange.shade600, Colors.red.shade600]
              : [theme.colorScheme.primary, theme.colorScheme.secondary],
        ),
      ),
      child: Row(
        children: [
          Icon(
            isUrgent ? Icons.warning_rounded : Icons.workspace_premium_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _proService.isTrial
                  ? AppText.of(context).trialDaysLeft(daysLeft)
                  : AppText.of(context).promoDaysLeft(daysLeft),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PaywallScreen()),
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: Text(
              AppText.of(context).upgrade,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}




