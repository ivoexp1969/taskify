import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// „Какво ново" — изскачащ прозорец, който се показва ВЕДНЪЖ след ъпдейт до
/// нова версия (и на Android, и на iOS). Потребителите не четат release notes
/// в магазина → ако не го обявим вътре в приложението, новите функции остават
/// неоткрити.
///
/// ★ПРИ ВСЕКИ РЕЛИЙЗ★ (преди `flutter build appbundle` / Xcode archive):
///   1) вдигни [_build] на новия versionCode от `pubspec.yaml`;
///   2) подмени [_items] с точките за новата версия (11 езика).
///
/// Нови инсталации НЕ го виждат (те виждат welcome диалога).
class WhatsNewDialog {
  /// Билдът, за който са точките по-долу (= `pubspec.yaml` build number).
  static const int _build = 61;

  static const String _prefKey = 'whats_new_seen_build';

  /// Точките за текущата версия, по език.
  static const Map<String, List<String>> _items = {
    'bg': [
      'Бутон „+" в widget-а на началния екран — нова задача с едно докосване.',
      'Widget-ът вече показва и твоя локален контекст: изтичащ документ, имен ден или празник.',
      'Когато нямаш задачи за деня, widget-ът показва полезното (напр. „Винетката изтича след 3 дни").',
    ],
    'en': [
      'A "+" button on the home-screen widget — add a task with one tap.',
      'The widget now shows your local context: an expiring document, a name day or a holiday.',
      'With no tasks for the day, the widget shows what actually matters (e.g. "Insurance expires in 3 days").',
    ],
    'de': [
      'Ein „+"-Button im Homescreen-Widget — neue Aufgabe mit einem Tippen.',
      'Das Widget zeigt jetzt deinen lokalen Kontext: ablaufendes Dokument, Namenstag oder Feiertag.',
      'Ohne Aufgaben zeigt das Widget das Wichtige (z.B. „Versicherung läuft in 3 Tagen ab").',
    ],
    'fr': [
      'Un bouton « + » sur le widget — nouvelle tâche en un seul geste.',
      'Le widget affiche votre contexte local : document qui expire, fête du prénom ou jour férié.',
      "Sans tâches, le widget affiche l'essentiel (ex. « L'assurance expire dans 3 jours »).",
    ],
    'it': [
      'Un pulsante "+" nel widget — nuova attività con un tocco.',
      'Il widget mostra il tuo contesto locale: documento in scadenza, onomastico o festività.',
      'Senza attività, il widget mostra ciò che conta (es. "L\'assicurazione scade tra 3 giorni").',
    ],
    'el': [
      'Κουμπί «+» στο widget — νέα εργασία με ένα άγγιγμα.',
      'Το widget δείχνει το τοπικό σου πλαίσιο: έγγραφο που λήγει, ονομαστική εορτή ή αργία.',
      'Χωρίς εργασίες, το widget δείχνει το χρήσιμο (π.χ. «Η ασφάλεια λήγει σε 3 ημέρες»).',
    ],
    'es': [
      'Botón "+" en el widget — nueva tarea con un solo toque.',
      'El widget muestra tu contexto local: documento que caduca, onomástica o festivo.',
      'Sin tareas, el widget muestra lo útil (p. ej. "El seguro caduca en 3 días").',
    ],
    'pt': [
      'Botão "+" no widget — nova tarefa com um toque.',
      'O widget mostra o teu contexto local: documento a expirar, dia do nome ou feriado.',
      'Sem tarefas, o widget mostra o que importa (ex. "O seguro expira em 3 dias").',
    ],
    'ru': [
      'Кнопка «+» в виджете — новая задача одним касанием.',
      'Виджет показывает ваш локальный контекст: истекающий документ, именины или праздник.',
      'Когда задач нет, виджет показывает полезное (напр. «Страховка истекает через 3 дня»).',
    ],
    'tr': [
      'Widget\'ta "+" düğmesi — tek dokunuşla yeni görev.',
      'Widget artık yerel bağlamını gösteriyor: süresi dolan belge, isim günü veya tatil.',
      'Görev yoksa widget işine yarayanı gösterir (örn. "Sigorta 3 gün içinde doluyor").',
    ],
    'ja': [
      'ホーム画面ウィジェットに「+」ボタン — ワンタップで新しいタスク。',
      'ウィジェットがローカルな文脈を表示：期限切れ間近の書類、聖名祝日、祝日。',
      'タスクがない日は、役立つ情報を表示（例「保険は3日後に期限切れ」）。',
    ],
  };

  static const Map<String, String> _title = {
    'en': "What's new", 'bg': 'Какво ново', 'de': 'Was ist neu',
    'fr': 'Quoi de neuf', 'it': 'Novità', 'el': 'Τι νέο υπάρχει',
    'es': 'Novedades', 'pt': 'Novidades', 'ru': 'Что нового',
    'tr': 'Yenilikler', 'ja': '新着情報',
  };

  static const Map<String, String> _button = {
    'en': 'Got it!', 'bg': 'Супер!', 'de': 'Super!', 'fr': 'Compris!',
    'it': 'Ottimo!', 'el': 'Τέλεια!', 'es': '¡Genial!', 'pt': 'Ótimo!',
    'ru': 'Отлично!', 'tr': 'Harika!', 'ja': '了解！',
  };

  /// Показва диалога веднъж за текущия билд. Безопасно при повторно извикване.
  static Future<void> maybeShow(BuildContext context, String lang) async {
    if (kIsWeb) return;

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getInt(_prefKey) ?? 0;
    if (seen >= _build) return;

    // Нова инсталация (никога не е стигала до welcome диалога) → само отбелязваме
    // билда; тя няма „ново", тя е нова.
    final freshInstall =
        seen == 0 && !(prefs.getBool('taskify_welcome_shown_v2') ?? false);
    await prefs.setInt(_prefKey, _build);
    if (freshInstall) return;

    String version = '';
    try {
      version = (await PackageInfo.fromPlatform()).version;
    } catch (_) {/* без версия в заглавието */}

    if (!context.mounted) return;

    final items = _items[lang] ?? _items['en']!;
    final title = _title[lang] ?? _title['en']!;
    final button = _button[lang] ?? _button['en']!;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.auto_awesome, size: 44, color: Colors.amber),
        title: Text(version.isEmpty ? title : '$title — $version'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3, right: 8),
                      child: Icon(Icons.check_circle, size: 18,
                          color: Colors.green),
                    ),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(button),
          ),
        ],
      ),
    );
  }
}
