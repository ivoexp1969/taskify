import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';
import 'pro_service.dart';
import '../screens/paywall/paywall_screen.dart';

/// ФАЗА 4: конверсионни тригери (само за FREE потребители).
///
/// Правила (общи за всички тригери):
///  * показват се САМО на free (Pro никога не стига дотук);
///  * максимум ЕДИН prompt на ден ОБЩО (по локална дата);
///  * всеки тип се показва само ВЕДНЪЖ ЗАВИНАГИ (persist в [_kShown]).
///
/// Пази се в SharedPreferences (както другите prefs в проекта — виж CLAUDE.md:
/// „Settings persist in SharedPreferences, not Hive"). Не пипа Hive/sync.
class ConversionService {
  ConversionService._();
  static final ConversionService instance = ConversionService._();

  static const String _kFirstLaunch = 'conv_first_launch';
  static const String _kShown = 'conv_shown_prompts';
  static const String _kLastPromptDate = 'conv_last_prompt_date';
  static const String _kCompletedCount = 'conv_completed_count';
  // Cold-start routing (app killed → tap): консумира се в HomeScreen.
  static const String kPendingRoute = 'conv_pending_route';

  /// Фиксирани notification ID-та (висок диапазон, за да не се сблъскат с
  /// random-ите на task напомнянията).
  static const int nDay3 = 990000003;
  static const int nDay7 = 990000007;

  /// Кумулативен праг за тригера „N-та завършена задача".
  static const int completedThreshold = 7;

  /// Ден-ключ в local time (yyyy-MM-dd). Pure — за тестове.
  static String dateKeyFor(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// Pure логика „веднъж завинаги + макс. 1/ден". За тестове.
  static bool shouldPrompt({
    required String id,
    required List<String> shown,
    required String? lastPromptDate,
    required String todayKey,
  }) {
    if (shown.contains(id)) return false; // веднъж завинаги
    if (lastPromptDate == todayKey) return false; // макс. 1/ден
    return true;
  }

  // ── Локализирани текстове (inline, ×11 езика — като другите services) ──
  static const Map<String, Map<String, String>> _tx = {
    'seventhTitle': {
      'en': 'Already 7 tasks done! 🎉', 'bg': 'Вече 7 свършени задачи! 🎉',
      'de': 'Schon 7 Aufgaben erledigt! 🎉', 'fr': 'Déjà 7 tâches terminées ! 🎉',
      'it': 'Già 7 attività completate! 🎉', 'el': 'Ήδη 7 εργασίες ολοκληρώθηκαν! 🎉',
      'es': '¡Ya 7 tareas completadas! 🎉', 'pt': 'Já 7 tarefas concluídas! 🎉',
      'ru': 'Уже 7 задач выполнено! 🎉', 'tr': 'Şimdiden 7 görev tamam! 🎉',
      'ja': 'もう7つのタスク完了！🎉',
    },
    'seventhBody': {
      'en': 'Unlock unlimited AI and no ads with Premium.',
      'bg': 'Отключи неограничен AI и без реклами с Premium.',
      'de': 'Schalte unbegrenzte KI und werbefrei mit Premium frei.',
      'fr': 'Débloquez l\'IA illimitée et sans publicité avec Premium.',
      'it': 'Sblocca l\'IA illimitata e nessuna pubblicità con Premium.',
      'el': 'Ξεκλειδώστε απεριόριστη AI και χωρίς διαφημίσεις με Premium.',
      'es': 'Desbloquea IA ilimitada y sin anuncios con Premium.',
      'pt': 'Desbloqueie IA ilimitada e sem anúncios com o Premium.',
      'ru': 'Откройте безлимитный AI и без рекламы с Premium.',
      'tr': 'Premium ile sınırsız yapay zekâ ve reklamsız deneyim.',
      'ja': 'Premiumで無制限のAIと広告なしを解放しましょう。',
    },
    'seedPremium': {
      'en': 'See Premium', 'bg': 'Виж Premium', 'de': 'Premium ansehen',
      'fr': 'Voir Premium', 'it': 'Scopri Premium', 'el': 'Δείτε το Premium',
      'es': 'Ver Premium', 'pt': 'Ver Premium', 'ru': 'Смотреть Premium',
      'tr': 'Premium\'u gör', 'ja': 'Premiumを見る',
    },
    'notNow': {
      'en': 'Not now', 'bg': 'Не сега', 'de': 'Nicht jetzt', 'fr': 'Plus tard',
      'it': 'Non ora', 'el': 'Όχι τώρα', 'es': 'Ahora no', 'pt': 'Agora não',
      'ru': 'Не сейчас', 'tr': 'Şimdi değil', 'ja': '今はしない',
    },
    'day3Title': {
      'en': 'Tip: let Taskify read your task 🪄',
      'bg': 'Съвет: остави Taskify да разпознае задачата 🪄',
      'de': 'Tipp: Taskify erkennt deine Aufgabe 🪄',
      'fr': 'Astuce : laissez Taskify comprendre votre tâche 🪄',
      'it': 'Consiglio: lascia che Taskify capisca l\'attività 🪄',
      'el': 'Συμβουλή: αφήστε το Taskify να καταλάβει την εργασία 🪄',
      'es': 'Consejo: deja que Taskify entienda tu tarea 🪄',
      'pt': 'Dica: deixe o Taskify entender sua tarefa 🪄',
      'ru': 'Совет: пусть Taskify распознает задачу 🪄',
      'tr': 'İpucu: Taskify görevini anlasın 🪄',
      'ja': 'ヒント：Taskifyにタスクを読み取らせましょう 🪄',
    },
    'day3Body': {
      'en': 'Type "doctor thursday 2pm" and Taskify recognizes it automatically.',
      'bg': 'Напиши „лекар четвъртък 14:00" и Taskify сам ще разпознае задачата.',
      'de': 'Tippe „Arzt Donnerstag 14 Uhr" und Taskify erkennt es automatisch.',
      'fr': 'Tapez « médecin jeudi 14h » et Taskify le reconnaît automatiquement.',
      'it': 'Scrivi "medico giovedì 14:00" e Taskify lo riconosce da solo.',
      'el': 'Γράψε «γιατρός Πέμπτη 14:00» και το Taskify το αναγνωρίζει αυτόματα.',
      'es': 'Escribe "médico jueves 14:00" y Taskify lo reconoce automáticamente.',
      'pt': 'Digite "médico quinta 14h" e o Taskify reconhece automaticamente.',
      'ru': 'Напишите «врач четверг 14:00», и Taskify распознает это сам.',
      'tr': '"doktor perşembe 14:00" yaz, Taskify otomatik tanısın.',
      'ja': '「医者 木曜 14時」と入力すると、Taskifyが自動で認識します。',
    },
    'day7Title': {
      'en': 'A week with Taskify! 🚀', 'bg': 'Седмица с Taskify! 🚀',
      'de': 'Eine Woche mit Taskify! 🚀', 'fr': 'Une semaine avec Taskify ! 🚀',
      'it': 'Una settimana con Taskify! 🚀', 'el': 'Μια εβδομάδα με το Taskify! 🚀',
      'es': '¡Una semana con Taskify! 🚀', 'pt': 'Uma semana com o Taskify! 🚀',
      'ru': 'Неделя с Taskify! 🚀', 'tr': 'Taskify ile bir hafta! 🚀',
      'ja': 'Taskifyと1週間！🚀',
    },
    'day7Body': {
      'en': 'See what Premium unlocks for you.',
      'bg': 'Виж какво отключва Premium за теб.',
      'de': 'Sieh, was Premium für dich freischaltet.',
      'fr': 'Découvrez ce que Premium débloque pour vous.',
      'it': 'Scopri cosa sblocca Premium per te.',
      'el': 'Δες τι ξεκλειδώνει το Premium για σένα.',
      'es': 'Descubre qué desbloquea Premium para ti.',
      'pt': 'Veja o que o Premium desbloqueia para você.',
      'ru': 'Посмотрите, что открывает Premium.',
      'tr': 'Premium\'un senin için neler açtığını gör.',
      'ja': 'Premiumが何を解放するか見てみましょう。',
    },
  };

  static String _t(String key, String lang) =>
      _tx[key]?[lang] ?? _tx[key]?['en'] ?? '';

  Future<String> _lang() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('app_language') ?? 'en';
  }

  /// Записва датата на първо стартиране (веднъж) и (пре)насрочва ден-3/ден-7
  /// engagement нотификациите. Извиква се при старт (main).
  Future<void> ensureFirstLaunchAndSchedule() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    var firstStr = prefs.getString(_kFirstLaunch);
    if (firstStr == null) {
      firstStr = DateTime.now().toIso8601String();
      await prefs.setString(_kFirstLaunch, firstStr);
    }
    // Времевите нотификации стигат до FREE и TRIAL, но НЕ до реално платили
    // абонати (isPaid). Заб.: локалният 14-дн. trial прави isPro=true в целия
    // ден-3/ден-7 прозорец, затова тук гейтваме по isPaid, не по isPro.
    if (ProService().isPaid) return;
    final first = DateTime.parse(firstStr);
    await _scheduleEngagement(first);
  }

  Future<void> _scheduleEngagement(DateTime firstLaunch) async {
    final lang = await _lang();
    final now = DateTime.now();
    // 10:00 local на съответния ден.
    DateTime at(int addDays) => DateTime(
        firstLaunch.year, firstLaunch.month, firstLaunch.day, 10)
        .add(Duration(days: addDays));

    final day3 = at(3);
    final day7 = at(7);

    if (day3.isAfter(now)) {
      await NotificationService().scheduleNotification(
        id: nDay3,
        title: _t('day3Title', lang),
        body: _t('day3Body', lang),
        scheduledDate: day3,
        payload: 'conv_day3',
      );
    }
    if (day7.isAfter(now)) {
      await NotificationService().scheduleNotification(
        id: nDay7,
        title: _t('day7Title', lang),
        body: _t('day7Body', lang),
        scheduledDate: day7,
        payload: 'conv_day7',
      );
    }
  }

  /// Тригер „N-та завършена задача" (кумулативно). Вика се при ВСЯКО завършване
  /// на задача (не при отмятане обратно). Брои само за free.
  Future<void> onTaskCompleted(BuildContext context) async {
    if (kIsWeb || ProService().isPro) return;
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_kCompletedCount) ?? 0) + 1;
    await prefs.setInt(_kCompletedCount, count);
    if (count != completedThreshold) return;
    if (!context.mounted) return;
    await _maybePrompt(context, 'seventh_task', _showSeventhSheet);
  }

  Future<void> _maybePrompt(
    BuildContext context,
    String id,
    Future<void> Function(BuildContext) show,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getStringList(_kShown) ?? <String>[];
    final today = dateKeyFor(DateTime.now());
    if (!shouldPrompt(
      id: id,
      shown: shown,
      lastPromptDate: prefs.getString(_kLastPromptDate),
      todayKey: today,
    )) {
      return;
    }
    if (!context.mounted) return;
    // Маркираме ПРЕДИ показване → гарантирано „веднъж завинаги" дори при dismiss.
    shown.add(id);
    await prefs.setStringList(_kShown, shown);
    await prefs.setString(_kLastPromptDate, today);
    if (context.mounted) await show(context);
  }

  Future<void> _showSeventhSheet(BuildContext context) async {
    final lang = await _lang();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        final theme = Theme.of(sheetCtx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('🎉', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text(
                  _t('seventhTitle', lang),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _t('seventhBody', lang),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PaywallScreen()),
                    );
                  },
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: Text(_t('seedPremium', lang)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                  child: Text(_t('notNow', lang)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
