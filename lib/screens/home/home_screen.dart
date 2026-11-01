import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../task/task_screen.dart';
import '../calendar/calendar_screen.dart';
import '../settings/settings_screen.dart';
import '../documents/documents_screen.dart';
import '../modes/modes_screen.dart';
import '../../utils/localization.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/gift_cta.dart';
import '../../widgets/whats_new_dialog.dart';
import '../../services/pro_service.dart';
import '../../services/name_days_service.dart';
import '../../services/update_prompt_service.dart';
import '../../services/holidays_service.dart';
import '../../services/school_calendar_service.dart';
import '../../services/university_service.dart';
import '../../services/sync_service.dart';
import '../../services/prefs_sync_service.dart';
import '../../services/widget_service.dart';
import '../../services/analytics_service.dart';
import '../../utils/debug_overrides.dart';
import '../paywall/paywall_screen.dart';

/// Етикет за таб „Обучение" (11 езика) — обединява Ученик + Студент; неутрален,
/// защото и двамата учат. Кратък за долната навигация.
const Map<String, String> _studyLabel = {
  'en': 'Learning', 'nl': 'Leren', 'uk': 'Навчання', 'bg': 'Обучение', 'de': 'Bildung', 'fr': 'Éducation',
  'it': 'Istruzione', 'el': 'Εκπαίδευση', 'es': 'Educación', 'pt': 'Educação',
  'ru': 'Обучение', 'tr': 'Eğitim', 'ja': '学び',
};

// ★1.0.70★ Споделени между преходните диалози (изтекъл trial / изтекъл промо код):
// списъкът „безплатно" vs „Pro" + двата бутона. Един източник, 13 езика.
const Map<String, String> _kFreeList = {
  'en': 'Free: Calendar, up to 3 documents, name days + contacts, joining shared lists, up to 50 tasks, 10 categories, recurring tasks, voice input, themes & languages.', 'nl': 'Gratis: Agenda, tot 3 documenten, naamdagen + contacten, deelnemen aan gedeelde lijsten, tot 50 taken, 10 categorieën, terugkerende taken, spraakinvoer, thema\'s & talen.', 'uk': 'Безкоштовно: Календар, до 3 документів, іменини + контакти, приєднання до спільних списків, до 50 завдань, 10 категорій, повторювані завдання, голосове введення, теми та мови.',
  'bg': 'Безплатно: Календар, до 3 документа, имени дни + контакти, присъединяване към споделени списъци, до 50 задачи, 10 категории, повтарящи се задачи, гласово въвеждане, теми и езици.',
  'de': 'Kostenlos: Kalender, bis zu 3 Dokumente, Namenstage + Kontakte, geteilten Listen beitreten, bis zu 50 Aufgaben, 10 Kategorien, wiederkehrende Aufgaben, Spracheingabe, Themes & Sprachen.',
  'fr': 'Gratuit : Calendrier, jusqu\'à 3 documents, fêtes des prénoms + contacts, rejoindre des listes partagées, jusqu\'à 50 tâches, 10 catégories, tâches récurrentes, saisie vocale, thèmes et langues.',
  'it': 'Gratis: Calendario, fino a 3 documenti, onomastici + contatti, unirsi a liste condivise, fino a 50 attività, 10 categorie, attività ricorrenti, input vocale, temi e lingue.',
  'el': 'Δωρεάν: Ημερολόγιο, έως 3 έγγραφα, ονομαστικές + επαφές, συμμετοχή σε κοινές λίστες, έως 50 εργασίες, 10 κατηγορίες, επαναλαμβανόμενες εργασίες, φωνητική εισαγωγή, θέματα & γλώσσες.',
  'es': 'Gratis: Calendario, hasta 3 documentos, onomásticas + contactos, unirte a listas compartidas, hasta 50 tareas, 10 categorías, tareas recurrentes, entrada de voz, temas e idiomas.',
  'pt': 'Grátis: Calendário, até 3 documentos, dias do nome + contactos, juntar-te a listas partilhadas, até 50 tarefas, 10 categorias, tarefas recorrentes, entrada de voz, temas e idiomas.',
  'ru': 'Бесплатно: Календарь, до 3 документов, именины + контакты, присоединение к общим спискам, до 50 задач, 10 категорий, повторяющиеся задачи, голосовой ввод, темы и языки.',
  'tr': 'Ücretsiz: Takvim, en fazla 3 belge, isim günleri + kişiler, paylaşılan listelere katılma, en fazla 50 görev, 10 kategori, yinelenen görevler, sesli giriş, temalar ve diller.',
  'ja': '無料: カレンダー、最大3件のドキュメント、聖名祝日＋連絡先、共有リストへの参加、最大50タスク・10カテゴリ、繰り返しタスク、音声入力、テーマと言語。',
};
const Map<String, String> _kProList = {
  'en': 'Pro unlocks: unlimited tasks, unlimited AI, Statistics, cloud sync, widgets, creating shared lists — and removes ads.', 'nl': 'Pro ontgrendelt: onbeperkte taken, onbeperkte AI, Statistieken, cloudsync, widgets, gedeelde lijsten maken — en verwijdert advertenties.', 'uk': 'Pro відкриває: необмежені завдання, необмежений AI, Статистику, хмарну синхронізацію, віджети, створення спільних списків — і прибирає рекламу.',
  'bg': 'Pro отключва: неограничени задачи, неограничен AI, Статистика, облачна синхронизация, widgets, създаване на споделени списъци — и маха рекламите.',
  'de': 'Pro schaltet frei: unbegrenzte Aufgaben, unbegrenzte KI, Statistik, Cloud-Sync, Widgets, geteilte Listen erstellen — und entfernt Werbung.',
  'fr': 'Pro débloque : tâches illimitées, IA illimitée, Statistiques, sync cloud, widgets, création de listes partagées — et retire les pubs.',
  'it': 'Pro sblocca: attività illimitate, IA illimitata, Statistiche, sync cloud, widget, creazione di liste condivise — e rimuove la pubblicità.',
  'el': 'Το Pro ξεκλειδώνει: απεριόριστες εργασίες, απεριόριστη AI, Στατιστικά, cloud sync, widgets, δημιουργία κοινών λιστών — και αφαιρεί τις διαφημίσεις.',
  'es': 'Pro desbloquea: tareas ilimitadas, IA ilimitada, Estadísticas, sync en la nube, widgets, crear listas compartidas — y quita los anuncios.',
  'pt': 'Pro desbloqueia: tarefas ilimitadas, IA ilimitada, Estatísticas, sync na nuvem, widgets, criar listas partilhadas — e remove os anúncios.',
  'ru': 'Pro открывает: безлимитные задачи, безлимитный ИИ, Статистику, облачную синхронизацию, виджеты, создание общих списков — и убирает рекламу.',
  'tr': 'Pro açar: sınırsız görev, sınırsız AI, İstatistikler, bulut senkronizasyonu, widget\'lar, paylaşılan liste oluşturma — ve reklamları kaldırır.',
  'ja': 'Proで解除: 無制限のタスク、無制限のAI、統計、クラウド同期、ウィジェット、共有リストの作成 — さらに広告も消えます。',
};
const Map<String, String> _kBtnContinueFree = {
  'en': 'Continue free', 'nl': 'Gratis doorgaan', 'uk': 'Продовжити безкоштовно', 'bg': 'Продължи безплатно', 'de': 'Kostenlos weiter',
  'fr': 'Continuer gratuit', 'it': 'Continua gratis', 'el': 'Συνέχεια δωρεάν',
  'es': 'Seguir gratis', 'pt': 'Continuar grátis', 'ru': 'Продолжить бесплатно',
  'tr': 'Ücretsiz devam', 'ja': '無料で続ける',
};
const Map<String, String> _kBtnGetPro = {
  'en': 'Get Pro', 'nl': 'Pro nemen', 'uk': 'Отримати Pro', 'bg': 'Вземи Pro', 'de': 'Pro holen', 'fr': 'Obtenir Pro',
  'it': 'Ottieni Pro', 'el': 'Απόκτηση Pro', 'es': 'Obtener Pro',
  'pt': 'Obter Pro', 'ru': 'Получить Pro', 'tr': 'Pro al', 'ja': 'Proを入手',
};
// Заглавие + тяло за екрана „Промокодът ти изтече" (отделно от изтекъл trial).
const Map<String, String> _kPromoExpiredTitle = {
  'en': 'Your promo code expired', 'nl': 'Je promocode is verlopen', 'uk': 'Термін промокоду минув', 'bg': 'Промокодът ти изтече',
  'de': 'Dein Promo-Code ist abgelaufen', 'fr': 'Ton code promo a expiré',
  'it': 'Il tuo codice promo è scaduto', 'el': 'Ο προωθητικός κωδικός σου έληξε',
  'es': 'Tu código promocional caducó', 'pt': 'O teu código promo expirou',
  'ru': 'Твой промокод истёк', 'tr': 'Promosyon kodun sona erdi', 'ja': 'プロモコードの有効期限が切れました',
};
const Map<String, String> _kPromoExpiredBody = {
  'en': 'Your promo Pro period has ended. Nothing is lost — all your tasks and categories stay. Here\'s what\'s free, and what Pro unlocks:', 'nl': 'Je promo Pro-periode is afgelopen. Er gaat niets verloren — al je taken en categorieën blijven. Dit is gratis, en dit ontgrendelt Pro:', 'uk': 'Твій промо Pro-період завершився. Нічого не втрачено — усі завдання та категорії залишаються. Ось що безкоштовно, а що відкриває Pro:',
  'bg': 'Промо Pro периодът ти приключи. Нищо не се губи — всичките ти задачи и категории остават. Ето какво е безплатно и какво отключва Pro:',
  'de': 'Dein Promo-Pro-Zeitraum ist vorbei. Nichts geht verloren — alle Aufgaben und Kategorien bleiben. Das ist kostenlos, das schaltet Pro frei:',
  'fr': 'Ta période Pro promo est terminée. Rien n\'est perdu — toutes tes tâches et catégories restent. Voici ce qui est gratuit et ce que Pro débloque :',
  'it': 'Il tuo periodo Pro promo è finito. Nulla è perso — tutte le tue attività e categorie restano. Ecco cosa è gratis e cosa sblocca Pro:',
  'el': 'Η περίοδος Pro με προωθητικό κωδικό έληξε. Τίποτα δεν χάνεται — όλες οι εργασίες και κατηγορίες μένουν. Να τι είναι δωρεάν και τι ξεκλειδώνει το Pro:',
  'es': 'Tu periodo Pro promocional ha terminado. No se pierde nada — todas tus tareas y categorías quedan. Esto es gratis y esto desbloquea Pro:',
  'pt': 'O teu período Pro promo terminou. Nada se perde — todas as tuas tarefas e categorias ficam. Eis o que é grátis e o que o Pro desbloqueia:',
  'ru': 'Твой промо Pro-период закончился. Ничего не потеряно — все задачи и категории остаются. Вот что бесплатно и что открывает Pro:',
  'tr': 'Promosyon Pro dönemin bitti. Hiçbir şey kaybolmaz — tüm görevlerin ve kategorilerin kalıyor. İşte ücretsiz olanlar ve Pro\'nun açtıkları:',
  'ja': 'プロモによるProの期間が終了しました。何も失われません — タスクとカテゴリはすべて残ります。無料の内容と、Proで解除される内容はこちら:',
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final ProService _proService = ProService();
  bool _welcomeChecked = false;
  bool _downgradeChecked = false;
  bool _promoExpiredChecked = false; // 1.0.70: екран „Промокодът ти изтече"

  // ★1.0.70★ Стартов поток (welcome / downgrade / „Какво ново" / празници /
  // училище) — СЕРИАЛИЗИРАН: диалозите се показват един след друг, за да НЕ се
  // трупат на един старт.
  bool _startupStarted = false;
  bool _startupDone = false;
  bool _dialogBusy = false;
  // ★1.0.70★ При ПЪРВО пускане (нова инсталация) показваме МАКСИМУМ welcome.
  // Празници + Училищен интро се отлагат за второто отваряне (не се трупат).
  bool _firstLaunch = false;

  // Trial банер (последните дни) — затваря се „за деня" (пази се датата).
  bool _trialBannerDismissedToday = false;
  bool _trialBannerShownLogged = false;

  /// Разделът „Документи" се показва на ВСИЧКИ (универсална функция; Pro gated).
  bool get _showDocuments => true;

  /// Екраните в долната навигация. Таб „Споделени" е ОБЕДИНЕН в „Задачи"
  /// (Фаза 1: споделените се достъпват от иконата в AppBar-а на Задачи) →
  /// освободеният слот е за таб „Уча 🎓" (Фаза 2).
  List<Widget> get _screens => [
        const TaskScreen(),
        if (_showModes)
          ModesScreen(onOpenTasks: () => setState(() => _currentIndex = 0)),
        const CalendarScreen(),
        if (_showDocuments) const DocumentsScreen(),
        const SettingsScreen(),
      ];

  /// Табът се показва САМО когато е активиран режим — Ученик ИЛИ Студент. Така
  /// студент-само потребител също вижда таба (иначе трябваше да включи училищния,
  /// за да го достигне → и двата светваха).
  bool get _showModes =>
      SchoolCalendarService.enabledNotifier.value ||
      UniversityService.enabledNotifier.value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _proService.addListener(_onProStatusChanged);
    // Появяване/скриване на таба при вкл./изкл. на който и да е режим.
    SchoolCalendarService.enabledNotifier.addListener(_onModesChanged);
    UniversityService.enabledNotifier.addListener(_onModesChanged);
    if (!kIsWeb) {
      _loadTrialBannerDismissed();
      // Единен, сериализиран стартов поток (виж [_runStartupFlow]).
      _startStartup();
      // ФАЗА 4: cold-start routing на ден-3/ден-7 нотификация (app беше убит).
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _consumePendingConversionRoute());
      // Бутонът „+" в home-screen widget-а (студен старт).
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _consumeWidgetAction());
    }
  }

  /// Ключ за „днес" (локална дата, с debug override) за затваряне на банера.
  String _todayKey() {
    final d = _trialNow();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// „Сега" с евентуален debug override — за да реагира банерът на симулираната
  /// дата в dev билда (иначе = DateTime.now()).
  DateTime _trialNow() => DebugOverrides.now();

  Future<void> _loadTrialBannerDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final d = prefs.getString('trial_banner_dismissed_date');
      if (d == _todayKey() && mounted) {
        setState(() => _trialBannerDismissedToday = true);
      }
    } catch (_) {}
  }

  /// Стартира сериализирания поток веднъж (чака ProService да се init-не).
  Future<void> _startStartup() async {
    if (kIsWeb || _startupStarted) return;
    _startupStarted = true;
    // Брояч на пусканията → при ПЪРВО пускане (нова инсталация) показваме само welcome.
    try {
      final prefs = await SharedPreferences.getInstance();
      final c = (prefs.getInt('app_launch_count') ?? 0) + 1;
      await prefs.setInt('app_launch_count', c);
      _firstLaunch = c == 1;
    } catch (_) {}
    if (!_proService.isInitialized) {
      try {
        await _proService.initialize();
      } catch (_) {}
    }
    if (!mounted) return;
    await _runStartupFlow();
  }

  /// Показва стартовите диалози ЕДИН СЛЕД ДРУГ (await между всеки), за да не се
  /// трупат: 1) welcome (trial ден 1) ИЛИ преходен екран при изтекъл trial;
  /// 2) „Какво ново" + подкана за обновяване; 3) празници (BG); 4) училищен интро.
  Future<void> _runStartupFlow() async {
    if (kIsWeb || _dialogBusy) return;
    _dialogBusy = true;
    try {
      await _showTrialWelcome(); // no-op ако не е ден 1 / вече показан
      if (!mounted) return;
      // 1.0.70: изтекъл промо код има приоритет пред изтекъл-trial диалога —
      // ако е показан, не трупаме и trial-диалога в същия старт.
      final promoExpiredShown = await _maybeShowPromoExpiredDialog();
      if (!mounted) return;
      if (!promoExpiredShown) {
        await _maybeShowDowngradeDialog(); // no-op ако не е eligible / вече показан
        if (!mounted) return;
      }
      final lang = LanguageScope.of(context).locale.languageCode;
      await WhatsNewDialog.maybeShow(context, lang);
      if (!mounted) return;
      await UpdatePromptService.instance.maybePrompt(context, lang);
      if (!mounted) return;
      // Празници + Училищен интро — НЕ при първо пускане (нова инсталация вижда
      // само welcome); най-рано на второто отваряне.
      if (!_firstLaunch) {
        await _maybeShowHolidaysPrompt();
        if (!mounted) return;
        await _maybeShowSchoolIntro();
      }
    } finally {
      _dialogBusy = false;
      _startupDone = true;
    }
  }

  void _onModesChanged() {
    if (mounted) setState(() {});
  }

  /// Бутонът „+" на Android widget-а отваря редактора за нова задача.
  /// MainActivity пази действието; тук го консумираме при старт и при resume.
  Future<void> _consumeWidgetAction() async {
    final action = await WidgetService.consumePendingAction();
    if (action != 'new_task' || !mounted) return;
    if (_currentIndex != 0) setState(() => _currentIndex = 0); // таб „Задачи"
    await TaskEditorBridge.openNewSelfManaged();
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

    // Монетизация: cold-start от напомняне за рожден ден → „цветя/подарък" CTA.
    final gift = prefs.getString('gift_pending_route');
    if (gift != null) {
      await prefs.remove('gift_pending_route');
      if (context.mounted) {
        await GiftOffer.tap(context,
            lang: LanguageScope.of(context).locale.languageCode,
            kind: 'gift_birthday');
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
      PrefsSyncService().syncNow();
      // Trial/промо се смятат при четене → при връщане пресмятаме наново спрямо
      // текущата дата (ако е изтекъл, докато app-ът е бил на заден план).
      _proService.onAppResumed();
      if (!kIsWeb) {
        _consumeWidgetAction(); // „+" от widget-а, докато app-ът върви
        WidgetService.syncFromWidget(); // отметки от widget-а (iOS чек-бутон)
        // Нов ден → trial банерът може пак да се покаже (датата на затваряне е друга).
        _trialBannerDismissedToday = false;
        _loadTrialBannerDismissed();
      }
    }
  }

  /// Еднократно, проактивно одобрение за официалните празници (само BG контекст,
  /// БЕЗ GPS — държавата идва от device locale). Топъл, личен тон.
  Future<void> _maybeShowHolidaysPrompt() async {
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
      'en': 'Public holidays', 'nl': 'Feestdagen', 'uk': 'Офіційні свята', 'bg': 'Официални празници',
      'de': 'Gesetzliche Feiertage', 'fr': 'Jours fériés',
      'it': 'Festività ufficiali', 'el': 'Επίσημες αργίες',
      'es': 'Días festivos', 'pt': 'Feriados oficiais',
      'ru': 'Официальные праздники', 'tr': 'Resmi tatiller', 'ja': '祝日',
    };
    const body = {
      'en': "I see you're in Bulgaria. Want me to show the official holidays in your calendar? 🇧🇬", 'nl': 'Ik zie dat je in Bulgarije bent. Zal ik de officiële feestdagen in je agenda tonen? 🇧🇬', 'uk': 'Бачу, ви в Болгарії. Показати офіційні свята у вашому календарі? 🇧🇬',
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
      'en': 'Yes, please', 'nl': 'Ja, graag', 'uk': 'Так, будь ласка', 'bg': 'Да, покажи', 'de': 'Ja, gern',
      'fr': 'Oui', 'it': 'Sì', 'el': 'Ναι', 'es': 'Sí',
      'pt': 'Sim', 'ru': 'Да', 'tr': 'Evet', 'ja': 'はい、お願いします',
    };
    const no = {
      'en': 'Not now', 'nl': 'Niet nu', 'uk': 'Не зараз', 'bg': 'Не сега', 'de': 'Nicht jetzt',
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

  /// Еднократни инструкции „в началото" как да включиш Училищния режим (само
  /// BG контекст, ако още не е включен). Без този интро новата функция остава
  /// неоткрита. Показва се веднъж (`school_intro_shown`) и НЕ се стека с други
  /// диалози (проверява, че home маршрутът е най-отгоре).
  Future<void> _maybeShowSchoolIntro() async {
    if (!mounted) return;

    final lang = LanguageScope.of(context).locale.languageCode;
    final country = WidgetsBinding.instance.platformDispatcher.locale.countryCode
        ?.toUpperCase();
    final isBg = lang == 'bg' || country == 'BG';
    if (!isBg) return;

    if (SchoolCalendarService.enabledNotifier.value) return; // вече е включен
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('school_intro_shown') ?? false) return;

    // Не се стекваме върху друг диалог — ако има отворен, ще опитаме следващата
    // сесия (флагът се вдига чак когато реално покажем интрото).
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;

    await prefs.setBool('school_intro_shown', true);
    if (!mounted) return;

    String tr(Map<String, String> m) => m[lang] ?? m['en']!;
    const title = {
      'en': 'School mode 🎒', 'nl': 'Schoolmodus 🎒', 'uk': 'Шкільний режим 🎒', 'bg': 'Училищен режим 🎒', 'de': 'Schulmodus 🎒',
      'fr': 'Mode école 🎒', 'it': 'Modalità scuola 🎒',
      'el': 'Λειτουργία σχολείου 🎒', 'es': 'Modo escolar 🎒',
      'pt': 'Modo escolar 🎒', 'ru': 'Школьный режим 🎒', 'tr': 'Okul modu 🎒',
      'ja': '学校モード 🎒',
    };
    const body = {
      'en': 'Want a countdown to the next school vacation right on your home ', 'nl': 'Wil je een aftelklok naar de volgende schoolvakantie op je beginscherm ', 'uk': 'Хочете відлік до наступних канікул прямо на головному екрані '
          'screen? Turn on School mode in Settings → Bulgaria and pick your grade.',
      'bg': 'Искаш ли обратно броене до следващата ваканция направо на началния '
          'екран? Включи Училищен режим от Настройки → България и избери класа си.',
      'de': 'Möchtest du einen Countdown bis zu den nächsten Ferien auf dem '
          'Startbildschirm? Aktiviere den Schulmodus in Einstellungen → Bulgarien.',
      'fr': 'Envie d\'un compte à rebours des prochaines vacances sur l\'accueil ? '
          'Active le Mode école dans Réglages → Bulgarie et choisis ta classe.',
      'it': 'Vuoi un conto alla rovescia per le prossime vacanze in home? '
          'Attiva la Modalità scuola in Impostazioni → Bulgaria e scegli la classe.',
      'el': 'Θέλεις αντίστροφη μέτρηση για τις επόμενες διακοπές στην αρχική; '
          'Ενεργοποίησε τη Λειτουργία σχολείου στις Ρυθμίσεις → Βουλγαρία.',
      'es': '¿Quieres una cuenta atrás para las próximas vacaciones en el inicio? '
          'Activa el Modo escolar en Ajustes → Bulgaria y elige tu grado.',
      'pt': 'Queres uma contagem para as próximas férias no ecrã inicial? '
          'Ativa o Modo escolar em Definições → Bulgária e escolhe o teu ano.',
      'ru': 'Хочешь обратный отсчёт до ближайших каникул прямо на главном экране? '
          'Включи Школьный режим в Настройки → Болгария и выбери класс.',
      'tr': 'Ana ekranda bir sonraki tatile geri sayım ister misin? '
          'Ayarlar → Bulgaristan\'dan Okul modunu aç ve sınıfını seç.',
      'ja': '次の休みまでのカウントダウンをホーム画面に表示しませんか？'
          '設定 → ブルガリア で学校モードをオンにして学年を選びましょう。',
    };
    const later = {
      'en': 'Later', 'nl': 'Later', 'uk': 'Пізніше', 'bg': 'По-късно', 'de': 'Später', 'fr': 'Plus tard',
      'it': 'Più tardi', 'el': 'Αργότερα', 'es': 'Más tarde', 'pt': 'Mais tarde',
      'ru': 'Позже', 'tr': 'Sonra', 'ja': '後で',
    };
    const gotIt = {
      'en': 'Got it', 'nl': 'Begrepen', 'uk': 'Зрозуміло', 'bg': 'Разбрах', 'de': 'Verstanden', 'fr': 'Compris',
      'it': 'Capito', 'el': 'Κατάλαβα', 'es': 'Entendido', 'pt': 'Percebi',
      'ru': 'Понятно', 'tr': 'Anladım', 'ja': 'わかった',
    };

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.school_rounded, size: 40, color: Color(0xFF7B2FF7)),
        title: Text(tr(title)),
        content: Text(tr(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr(later)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr(gotIt)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _proService.removeListener(_onProStatusChanged);
    SchoolCalendarService.enabledNotifier.removeListener(_onModesChanged);
    UniversityService.enabledNotifier.removeListener(_onModesChanged);
    super.dispose();
  }

  void _onProStatusChanged() {
    if (!mounted) return;
    setState(() {});
    // Стартовият поток тръгва веднъж, щом Pro се init-не (initState също го пуска;
    // guard-нато с _startupStarted).
    if (!_startupStarted && _proService.isInitialized && !kIsWeb) {
      _startStartup();
    } else if (_startupDone && !_dialogBusy) {
      // Късна корекция от RC/изтичане (promo init е async чрез .then в main) →
      // преходен диалог. Промо-изтекъл има приоритет пред trial-изтекъл; НЕ се
      // трупа върху текущ стартов диалог.
      _maybeShowLateTransition();
    }
    // Текстът на именните нотификации зависи от Pro статуса → препланираме.
    if (!kIsWeb) {
      NameDaysService().refreshNotificationsFromPrefs(
          LanguageScope.of(context).locale.languageCode);
    }
  }

  /// ЧАСТ 3: еднократен, топъл преходен диалог за старите потребители, които са
  /// имали кеширан Pro/изтекъл trial и сега RevenueCat потвърди, че НЕ са Pro.
  /// Показва се веднъж (flag `downgrade_dialog_shown`), не трие никакви данни,
  /// и предлага жест (7 дни gratis Pro) като благодарност за ранната подкрепа.
  Future<void> _maybeShowDowngradeDialog() async {
    if (_downgradeChecked || kIsWeb) return;
    if (!_proService.isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    final trialStartStr = prefs.getString('trial_start_date');
    final trialStart =
        trialStartStr != null ? DateTime.tryParse(trialStartStr) : null;

    // Кой е „стар" потребител, който току-що губи Pro?
    //  (а) бивш ПЛАТЕЦ: кешът казваше Pro, RC потвърди неактивен, ИЛИ
    //  (б) POST-TRIAL free: имал е локален trial, който вече е изтекъл, и сега
    //      НЕ е Pro (нито платец, нито промо, нито активен trial).
    // Брандновите потребители са в активен trial → isPro=true → не са допустими.
    bool eligible = _proService.wasDowngradedFromCache;
    if (!eligible && !_proService.isPro && trialStart != null) {
      final end = trialStart.add(const Duration(days: trialPeriodDays));
      if (DateTime.now().isAfter(end)) eligible = true;
    }
    if (!eligible) return;
    _downgradeChecked = true;

    // „7 дни Pro подарък" САМО за ранните потребители — първа инсталация ПРЕДИ
    // 1.0.49 (пусната 10.07.2026). trial_start_date се записва при първото
    // пускане изобщо → надежден прокси за датата на инсталация. Новите (и по-
    // късните) инсталации НЕ получават подарък.
    final giftEligible =
        trialStart != null && trialStart.isBefore(DateTime(2026, 7, 10));

    if (prefs.getBool('downgrade_dialog_shown') ?? false) {
      _proService.clearDowngradeFlag();
      return;
    }
    await prefs.setBool('downgrade_dialog_shown', true);
    _proService.clearDowngradeFlag();
    if (!mounted) return;

    {
      final lang = LanguageScope.of(context).locale.languageCode;
      String tr(Map<String, String> m) => m[lang] ?? m['en']!;

      const dTitle = {
        'en': 'Thank you for being here 🙏', 'nl': 'Bedankt dat je er bent 🙏', 'uk': 'Дякуємо, що ви з нами 🙏',
        'bg': 'Благодарим ти, че си с нас 🙏',
        'de': 'Danke, dass du dabei bist 🙏',
        'fr': 'Merci d\'être là 🙏',
        'it': 'Grazie di esserci 🙏',
        'el': 'Ευχαριστούμε που είσαι εδώ 🙏',
        'es': 'Gracias por estar aquí 🙏',
        'pt': 'Obrigado por estares aqui 🙏',
        'ru': 'Спасибо, что ты с нами 🙏',
        'tr': 'Burada olduğun için teşekkürler 🙏',
        'ja': 'ご利用ありがとうございます 🙏',
      };
      const dBody = {
        'en': 'Your free trial has ended. Nothing is lost — all your tasks and categories stay. Here\'s what\'s free, and what Pro unlocks:', 'nl': 'Je gratis proefperiode is afgelopen. Er gaat niets verloren — al je taken en categorieën blijven. Dit is gratis, en dit ontgrendelt Pro:', 'uk': 'Ваш безкоштовний пробний період завершився. Нічого не втрачено — усі завдання та категорії залишаються. Ось що безкоштовно, а що відкриває Pro:',
        'bg': 'Пробният ти период приключи. Нищо не се губи — всичките ти задачи и категории остават. Ето какво е безплатно и какво отключва Pro:',
        'de': 'Deine kostenlose Testphase ist vorbei. Nichts geht verloren — alle Aufgaben und Kategorien bleiben. Das ist kostenlos, das schaltet Pro frei:',
        'fr': 'Ta période d\'essai est terminée. Rien n\'est perdu — toutes tes tâches et catégories restent. Voici ce qui est gratuit et ce que Pro débloque :',
        'it': 'Il tuo periodo di prova è finito. Nulla è perso — tutte le tue attività e categorie restano. Ecco cosa è gratis e cosa sblocca Pro:',
        'el': 'Η δωρεάν δοκιμή σου έληξε. Τίποτα δεν χάνεται — όλες οι εργασίες και κατηγορίες μένουν. Να τι είναι δωρεάν και τι ξεκλειδώνει το Pro:',
        'es': 'Tu prueba gratuita ha terminado. No se pierde nada — todas tus tareas y categorías quedan. Esto es gratis y esto desbloquea Pro:',
        'pt': 'O teu período de teste terminou. Nada se perde — todas as tuas tarefas e categorias ficam. Eis o que é grátis e o que o Pro desbloqueia:',
        'ru': 'Твой пробный период закончился. Ничего не потеряно — все задачи и категории остаются. Вот что бесплатно и что открывает Pro:',
        'tr': 'Ücretsiz deneme süren bitti. Hiçbir şey kaybolmaz — tüm görevlerin ve kategorilerin kalıyor. İşte ücretsiz olanlar ve Pro\'nun açtıkları:',
        'ja': '無料トライアルが終了しました。何も失われません — タスクとカテゴリはすべて残ります。無料の内容と、Proで解除される内容はこちら:',
      };
      // ★1.0.70★ Списъците free/Pro вече са изнесени на файлово ниво
      // (`_kFreeList`/`_kProList`) и се ползват и от екрана „Промокодът ти изтече".
      const dGift = {
        'en': 'As a thank-you for your early support, here are 7 days of Pro on us. 💛', 'nl': 'Als dank voor je vroege steun krijg je 7 dagen Pro van ons. 💛', 'uk': 'На знак подяки за вашу ранню підтримку — 7 днів Pro від нас. 💛',
        'bg': 'Като благодарност за ранната ти подкрепа — 7 дни Pro от нас. 💛',
        'de': 'Als Dank für deine frühe Unterstützung: 7 Tage Pro geschenkt. 💛',
        'fr': 'Pour te remercier de ton soutien précoce, voici 7 jours de Pro offerts. 💛',
        'it': 'Per ringraziarti del tuo supporto iniziale, ecco 7 giorni di Pro in regalo. 💛',
        'el': 'Ως ευχαριστώ για την πρώιμη υποστήριξή σου, να 7 ημέρες Pro δώρο. 💛',
        'es': 'Como agradecimiento por tu apoyo inicial, aquí tienes 7 días de Pro gratis. 💛',
        'pt': 'Como agradecimento pelo teu apoio inicial, aqui estão 7 dias de Pro grátis. 💛',
        'ru': 'В благодарность за раннюю поддержку — 7 дней Pro в подарок. 💛',
        'tr': 'Erken desteğin için teşekkür olarak, 7 gün Pro bizden. 💛',
        'ja': '早期からのご支援への感謝を込めて、7日間のProをプレゼントします。💛',
      };
      const bAcceptGift = {
        'en': 'Accept 7 free days', 'nl': 'Accepteer 7 gratis dagen', 'uk': 'Отримати 7 безкоштовних днів', 'bg': 'Приеми 7 дни', 'de': '7 Tage annehmen',
        'fr': 'Accepter 7 jours', 'it': 'Accetta 7 giorni', 'el': 'Δέξου 7 ημέρες',
        'es': 'Aceptar 7 días', 'pt': 'Aceitar 7 dias', 'ru': 'Взять 7 дней',
        'tr': '7 günü al', 'ja': '7日間を受け取る',
      };
      const giftSnack = {
        'en': 'Enjoy 7 days of Pro! 💛', 'nl': 'Geniet van 7 dagen Pro! 💛', 'uk': 'Насолоджуйтесь 7 днями Pro! 💛', 'bg': 'Приятни 7 дни Pro! 💛',
        'de': 'Viel Spaß mit 7 Tagen Pro! 💛', 'fr': 'Profite de 7 jours de Pro ! 💛',
        'it': 'Goditi 7 giorni di Pro! 💛', 'el': 'Απόλαυσε 7 ημέρες Pro! 💛',
        'es': '¡Disfruta 7 días de Pro! 💛', 'pt': 'Aproveita 7 dias de Pro! 💛',
        'ru': 'Приятных 7 дней Pro! 💛', 'tr': '7 gün Pro\'nun tadını çıkar! 💛',
        'ja': '7日間のProをお楽しみください！💛',
      };

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.favorite_rounded, size: 40, color: Colors.pinkAccent),
          title: Text(tr(dTitle)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(dBody)),
                const SizedBox(height: 12),
                Text(tr(_kFreeList), style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                Text(tr(_kProList),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                if (giftEligible) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(tr(dGift),
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr(_kBtnContinueFree)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaywallScreen()),
                );
              },
              child: Text(tr(_kBtnGetPro)),
            ),
            if (giftEligible)
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _proService.grantEarlySupporterGrace(7);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr(giftSnack))),
                  );
                },
                child: Text(tr(bAcceptGift)),
              ),
          ],
        ),
      );
    }
  }

  /// 1.0.70: еднократен екран „Промокодът ти изтече" — показва се, когато промо
  /// код от тип „days" е изтекъл и няма друг валиден Pro. Ползва ОТДЕЛЕН флаг
  /// `promo_expired_dialog_shown` (нулиран при нов промо код →
  /// `ProService._resetPromoExpiredFlag`), за да се покаже ПАК при следващо
  /// изтичане. Връща true, ако е показан (тогава изтекъл-trial диалогът се пропуска).
  /// Късен преход (след стартовия поток, напр. щом RC/изтичане коригира статуса):
  /// показва промо-изтекъл диалог с приоритет, иначе trial-изтекъл.
  Future<void> _maybeShowLateTransition() async {
    final shown = await _maybeShowPromoExpiredDialog();
    if (!shown && mounted) await _maybeShowDowngradeDialog();
  }

  Future<bool> _maybeShowPromoExpiredDialog() async {
    if (_promoExpiredChecked || kIsWeb) return false;
    if (!_proService.isInitialized) return false;
    debugPrint('PROMO_EXP_CHECK init=${_proService.isInitialized} '
        'justExpired=${_proService.promoJustExpired} isPro=${_proService.isPro}');
    if (!_proService.promoJustExpired) return false;
    _promoExpiredChecked = true;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('promo_expired_dialog_shown') ?? false) return false;
    await prefs.setBool('promo_expired_dialog_shown', true);
    if (!mounted) return false;

    AnalyticsService().logPromoExpired();

    final lang = LanguageScope.of(context).locale.languageCode;
    String tr(Map<String, String> m) => m[lang] ?? m['en']!;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.local_offer_rounded,
            size: 40, color: Colors.deepPurpleAccent),
        title: Text(tr(_kPromoExpiredTitle)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(_kPromoExpiredBody)),
              const SizedBox(height: 12),
              Text(tr(_kFreeList), style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              Text(tr(_kProList),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr(_kBtnContinueFree)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PaywallScreen()),
              );
            },
            child: Text(tr(_kBtnGetPro)),
          ),
        ],
      ),
    );
    return true;
  }

  Future<void> _showTrialWelcome() async {
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
    
    // Показваме само ако е в trial и има поне 13 дни (ден 1 — еднократно).
    if (_proService.isTrial && _proService.trialDaysLeft >= 13) {
      // Маркираме като показан ПРЕДИ да покажем диалога
      await prefs.setBool('taskify_welcome_shown_v2', true);
      // Нова инсталация → welcome поема; „Какво ново" не бива да изскача отгоре.
      await WhatsNewDialog.markSeen();
      debugPrint('Welcome dialog will be shown, marked as shown');
      if (!mounted) return;
      final languageController = LanguageScope.of(context);
      final lang = languageController.locale.languageCode;

      const welcomeTitle = {'en': 'Welcome!', 'nl': 'Welkom!', 'uk': 'Ласкаво просимо!', 'bg': 'Добре дошъл!', 'de': 'Willkommen!', 'fr': 'Bienvenue!', 'it': 'Benvenuto!', 'el': 'Καλώς ήρθες!', 'es': '¡Bienvenido!', 'pt': 'Bem-vindo!', 'ru': 'Добро пожаловать!', 'tr': 'Hoş geldin!', 'ja': 'ようこそ！'};
      const welcomeBody = {'en': 'You have 14 days free Pro access!\n\nTry all features and see how Taskify can help you be more productive.', 'nl': 'Je hebt 14 dagen gratis Pro-toegang!\n\nProbeer alle functies en ontdek hoe Taskify je productiever kan maken.', 'uk': 'У вас 14 днів безкоштовного доступу до Pro!\n\nСпробуйте всі функції та побачте, як Taskify допомагає бути продуктивнішими.', 'bg': 'Имаш 14 дни безплатен Pro достъп!\n\nИзползвай всички функции и виж как Taskify ще ти помогне да си по-продуктивен.', 'de': 'Du hast 14 Tage kostenlosen Pro-Zugang!\n\nProbiere alle Funktionen aus.', 'fr': 'Vous avez 14 jours d\'accès Pro gratuit!\n\nEssayez toutes les fonctionnalités.', 'it': 'Hai 14 giorni di accesso Pro gratuito!\n\nProva tutte le funzionalità.', 'el': 'Έχεις 14 ημέρες δωρεάν Pro πρόσβαση!\n\nΔοκίμασε όλες τις λειτουργίες.', 'es': '¡Tienes 14 días de acceso Pro gratis!\n\nPrueba todas las funciones.', 'pt': 'Você tem 14 dias de acesso Pro grátis!\n\nExperimente todos os recursos.', 'ru': 'У вас 14 дней бесплатного Pro доступа!\n\nПопробуйте все функции.', 'tr': '14 gün ücretsiz Pro erişiminiz var!\n\nTüm özellikleri deneyin.', 'ja': '14日間の無料Proアクセスがあります！\n\nすべての機能を試して、Taskifyがどれだけ生産性を高めるか体験してください。'};
      const welcomeBtn = {'en': 'Awesome!', 'nl': 'Geweldig!', 'uk': 'Чудово!', 'bg': 'Страхотно!', 'de': 'Super!', 'fr': 'Génial!', 'it': 'Fantastico!', 'el': 'Τέλεια!', 'es': '¡Genial!', 'pt': 'Incrível!', 'ru': 'Отлично!', 'tr': 'Harika!', 'ja': '最高！'};

      await showDialog<void>(
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
    }
  }

  void _onDestinationSelected(int index) async {
    if (!kIsWeb && index == 2 && !_proService.canUseCalendar) {
      final languageController = LanguageScope.of(context);
      final lang = languageController.locale.languageCode;
      const calendarName = {'en': 'Calendar', 'nl': 'Agenda', 'uk': 'Календар', 'bg': 'Календар', 'de': 'Kalender', 'fr': 'Calendrier', 'it': 'Calendario', 'el': 'Ημερολόγιο', 'es': 'Calendario', 'pt': 'Calendário', 'ru': 'Календарь', 'tr': 'Takvim', 'ja': 'カレンダー'};

      final upgraded = await showPaywallIfNeeded(
        context,
        isFeatureAvailable: false,
        featureName: calendarName[lang] ?? calendarName['en']!,
        source: 'calendar',
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
            // ★1.0.70★ Trial банерът се показва САМО в последните дни (≈ден 11–14)
            // и се затваря „за деня". Ден 1 → welcome диалогът (еднократно).
            // Постоянната „Стани Pro" лента е МАХНАТА (виж Профил за оставащите дни).
            if (_showTrialBannerNow) _buildProBanner(context),

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
                if (_showModes)
                  NavigationDestination(
                    icon: const Icon(Icons.menu_book_outlined),
                    selectedIcon: const Icon(Icons.menu_book_rounded),
                    label: _studyLabel[t.lang] ?? _studyLabel['en']!,
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

  /// Показва ли се trial банерът СЕГА? Само в последните ≈4 дни (ден 11–14 от
  /// 14-дневния trial) и ако не е затворен за деня. Ден 1 се покрива от welcome
  /// диалога, а дни 2–10 нямат банер (ненатрапчиво).
  bool get _showTrialBannerNow {
    if (kIsWeb || _proService.isPaid || _proService.isPromoCode) return false;
    if (!_proService.isTrial) return false;
    final left = _proService.trialDaysLeft;
    if (left < 0 || left > 4) return false;
    return !_trialBannerDismissedToday;
  }

  Future<void> _dismissTrialBanner() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('trial_banner_dismissed_date', _todayKey());
    } catch (_) {}
    if (mounted) setState(() => _trialBannerDismissedToday = true);
    AnalyticsService().logTrialBannerDismissed('last_days');
  }

  Widget _buildProBanner(BuildContext context) {
    final theme = Theme.of(context);
    final daysLeft = _proService.trialDaysLeft;
    final isUrgent = daysLeft <= 3;

    // Логваме показването веднъж на сесия (phase = последни дни).
    if (!_trialBannerShownLogged) {
      _trialBannerShownLogged = true;
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => AnalyticsService().logTrialBannerShown('last_days'));
    }

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
              AppText.of(context).trialDaysLeft(daysLeft),
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
          // Затваряне „за деня" (× бутон) — банерът пак излиза на следващия ден.
          IconButton(
            onPressed: _dismissTrialBanner,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}




