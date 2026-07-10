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
import '../../widgets/gift_cta.dart';
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
  bool _downgradeChecked = false;

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
      // Downgrade може да дойде по-късно през RC слушателя (мрежа) → проверяваме
      // и тук, не само при старта.
      _maybeShowDowngradeDialog();
    }
  }

  /// Чака ProService да се инициализира, после показва welcome
  Future<void> _initAndShowWelcome() async {
    // Чакаме ProService да се инициализира (ако не е)
    if (!_proService.isInitialized) {
      await _proService.initialize();
    }
    _showTrialWelcome();
    _maybeShowDowngradeDialog();
  }

  /// ЧАСТ 3: еднократен, топъл преходен диалог за старите потребители, които са
  /// имали кеширан Pro/изтекъл trial и сега RevenueCat потвърди, че НЕ са Pro.
  /// Показва се веднъж (flag `downgrade_dialog_shown`), не трие никакви данни,
  /// и предлага жест (7 дни gratis Pro) като благодарност за ранната подкрепа.
  Future<void> _maybeShowDowngradeDialog() async {
    if (_downgradeChecked || kIsWeb) return;
    if (!_proService.isInitialized) return;

    final prefs = await SharedPreferences.getInstance();

    // Кой е „стар" потребител, който току-що губи Pro?
    //  (а) бивш ПЛАТЕЦ: кешът казваше Pro, RC потвърди неактивен, ИЛИ
    //  (б) POST-TRIAL free: имал е локален trial, който вече е изтекъл, и сега
    //      НЕ е Pro (нито платец, нито промо, нито активен trial).
    // Брандновите потребители са в активен trial → isPro=true → не са допустими.
    bool eligible = _proService.wasDowngradedFromCache;
    if (!eligible && !_proService.isPro) {
      final trialStartStr = prefs.getString('trial_start_date');
      if (trialStartStr != null) {
        final end = DateTime.tryParse(trialStartStr)
            ?.add(const Duration(days: trialPeriodDays));
        if (end != null && DateTime.now().isAfter(end)) {
          eligible = true;
        }
      }
    }
    if (!eligible) return;
    _downgradeChecked = true;

    if (prefs.getBool('downgrade_dialog_shown') ?? false) {
      _proService.clearDowngradeFlag();
      return;
    }
    await prefs.setBool('downgrade_dialog_shown', true);
    _proService.clearDowngradeFlag();
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lang = LanguageScope.of(context).locale.languageCode;
      String tr(Map<String, String> m) => m[lang] ?? m['en']!;

      const dTitle = {
        'en': 'Thank you for being here 🙏',
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
        'en': 'Your free trial has ended. Nothing is lost — all your tasks and categories stay. Here\'s what\'s free, and what Pro unlocks:',
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
      const dFree = {
        'en': 'Free: up to 50 tasks & 10 categories, recurring tasks, voice input, themes & languages.',
        'bg': 'Безплатно: до 50 задачи и 10 категории, повтарящи се задачи, гласово въвеждане, теми и езици.',
        'de': 'Kostenlos: bis zu 50 Aufgaben & 10 Kategorien, wiederkehrende Aufgaben, Spracheingabe, Themes & Sprachen.',
        'fr': 'Gratuit : jusqu\'à 50 tâches et 10 catégories, tâches récurrentes, saisie vocale, thèmes et langues.',
        'it': 'Gratis: fino a 50 attività e 10 categorie, attività ricorrenti, input vocale, temi e lingue.',
        'el': 'Δωρεάν: έως 50 εργασίες & 10 κατηγορίες, επαναλαμβανόμενες εργασίες, φωνητική εισαγωγή, θέματα & γλώσσες.',
        'es': 'Gratis: hasta 50 tareas y 10 categorías, tareas recurrentes, entrada de voz, temas e idiomas.',
        'pt': 'Grátis: até 50 tarefas e 10 categorias, tarefas recorrentes, entrada de voz, temas e idiomas.',
        'ru': 'Бесплатно: до 50 задач и 10 категорий, повторяющиеся задачи, голосовой ввод, темы и языки.',
        'tr': 'Ücretsiz: en fazla 50 görev ve 10 kategori, yinelenen görevler, sesli giriş, temalar ve diller.',
        'ja': '無料: 最大50タスク・10カテゴリ、繰り返しタスク、音声入力、テーマと言語。',
      };
      const dPro = {
        'en': 'Pro unlocks: Calendar, Documents, Statistics, AI, cloud sync, widgets, shared lists, name days — and removes ads.',
        'bg': 'Pro отключва: Календар, Документи, Статистика, AI, облак, widgets, споделени списъци, именни дни — и маха рекламите.',
        'de': 'Pro schaltet frei: Kalender, Dokumente, Statistik, KI, Cloud-Sync, Widgets, geteilte Listen, Namenstage — und entfernt Werbung.',
        'fr': 'Pro débloque : Calendrier, Documents, Statistiques, IA, sync cloud, widgets, listes partagées, fêtes des prénoms — et retire les pubs.',
        'it': 'Pro sblocca: Calendario, Documenti, Statistiche, IA, sync cloud, widget, liste condivise, onomastici — e rimuove la pubblicità.',
        'el': 'Το Pro ξεκλειδώνει: Ημερολόγιο, Έγγραφα, Στατιστικά, AI, cloud sync, widgets, κοινές λίστες, ονομαστικές εορτές — και αφαιρεί τις διαφημίσεις.',
        'es': 'Pro desbloquea: Calendario, Documentos, Estadísticas, IA, sync en la nube, widgets, listas compartidas, onomásticas — y quita los anuncios.',
        'pt': 'Pro desbloqueia: Calendário, Documentos, Estatísticas, IA, sync na nuvem, widgets, listas partilhadas, dias do nome — e remove os anúncios.',
        'ru': 'Pro открывает: Календарь, Документы, Статистику, ИИ, облако, виджеты, общие списки, именины — и убирает рекламу.',
        'tr': 'Pro açar: Takvim, Belgeler, İstatistikler, AI, bulut senkronizasyonu, widget\'lar, paylaşılan listeler, isim günleri — ve reklamları kaldırır.',
        'ja': 'Proで解除: カレンダー、ドキュメント、統計、AI、クラウド同期、ウィジェット、共有リスト、聖名祝日 — さらに広告も消えます。',
      };
      const dGift = {
        'en': 'As a thank-you for your early support, here are 7 days of Pro on us. 💛',
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
      const bContinueFree = {
        'en': 'Continue free', 'bg': 'Продължи безплатно', 'de': 'Kostenlos weiter',
        'fr': 'Continuer gratuit', 'it': 'Continua gratis', 'el': 'Συνέχεια δωρεάν',
        'es': 'Seguir gratis', 'pt': 'Continuar grátis', 'ru': 'Продолжить бесплатно',
        'tr': 'Ücretsiz devam', 'ja': '無料で続ける',
      };
      const bGetPro = {
        'en': 'Get Pro', 'bg': 'Вземи Pro', 'de': 'Pro holen', 'fr': 'Obtenir Pro',
        'it': 'Ottieni Pro', 'el': 'Απόκτηση Pro', 'es': 'Obtener Pro',
        'pt': 'Obter Pro', 'ru': 'Получить Pro', 'tr': 'Pro al', 'ja': 'Proを入手',
      };
      const bAcceptGift = {
        'en': 'Accept 7 free days', 'bg': 'Приеми 7 дни', 'de': '7 Tage annehmen',
        'fr': 'Accepter 7 jours', 'it': 'Accetta 7 giorni', 'el': 'Δέξου 7 ημέρες',
        'es': 'Aceptar 7 días', 'pt': 'Aceitar 7 dias', 'ru': 'Взять 7 дней',
        'tr': '7 günü al', 'ja': '7日間を受け取る',
      };
      const giftSnack = {
        'en': 'Enjoy 7 days of Pro! 💛', 'bg': 'Приятни 7 дни Pro! 💛',
        'de': 'Viel Spaß mit 7 Tagen Pro! 💛', 'fr': 'Profite de 7 jours de Pro ! 💛',
        'it': 'Goditi 7 giorni di Pro! 💛', 'el': 'Απόλαυσε 7 ημέρες Pro! 💛',
        'es': '¡Disfruta 7 días de Pro! 💛', 'pt': 'Aproveita 7 dias de Pro! 💛',
        'ru': 'Приятных 7 дней Pro! 💛', 'tr': '7 gün Pro\'nun tadını çıkar! 💛',
        'ja': '7日間のProをお楽しみください！💛',
      };

      showDialog(
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
                Text(tr(dFree), style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                Text(tr(dPro),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
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
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr(bContinueFree)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaywallScreen()),
                );
              },
              child: Text(tr(bGetPro)),
            ),
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
    });
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
              _buildProBanner(context)
            // Не-trial, не-Pro → ненатрапчива постоянна лента към paywall.
            else if (!kIsWeb && !_proService.isPro)
              _buildGoProStrip(context),

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

  /// Дискретна постоянна лента към paywall за не-Pro потребители без активен
  /// trial (иначе нямат видим път до покупка след края на пробния период).
  Widget _buildGoProStrip(BuildContext context) {
    final theme = Theme.of(context);
    final lang = LanguageScope.of(context).locale.languageCode;
    const label = {
      'en': 'Unlock Pro features', 'bg': 'Отключи Pro функциите',
      'de': 'Pro-Funktionen freischalten', 'fr': 'Débloquer les fonctions Pro',
      'it': 'Sblocca le funzioni Pro', 'el': 'Ξεκλείδωσε τις λειτουργίες Pro',
      'es': 'Desbloquea las funciones Pro', 'pt': 'Desbloqueia as funções Pro',
      'ru': 'Открой Pro-функции', 'tr': 'Pro özellikleri aç',
      'ja': 'Pro機能をアンロック',
    };
    final color = theme.colorScheme.primary;
    return Material(
      color: color.withValues(alpha: 0.08),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PaywallScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.workspace_premium_rounded, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label[lang] ?? label['en']!,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }
}




