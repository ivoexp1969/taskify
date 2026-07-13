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
  static const int _build = 63;

  static const String _prefKey = 'whats_new_seen_build';

  /// Точките за текущата версия, по език.
  static const Map<String, List<String>> _items = {
    'bg': [
      'Widget-ът вече показва и просрочените задачи, маркирани в червено.',
      'Отмятай задачи направо от widget-а (iOS 17+) — без да отваряш приложението.',
      'Прави картички за имени и рождени дни — с истинска снимка за фон.',
    ],
    'en': [
      'The widget now shows overdue tasks too, marked in red.',
      'Check off tasks right from the widget (iOS 17+) — no need to open the app.',
      'Make greeting cards for name days and birthdays — with a real photo background.',
    ],
    'de': [
      'Das Widget zeigt jetzt auch überfällige Aufgaben, rot markiert.',
      'Hake Aufgaben direkt im Widget ab (iOS 17+) — ohne die App zu öffnen.',
      'Erstelle Grußkarten für Namenstage und Geburtstage — mit echtem Foto-Hintergrund.',
    ],
    'fr': [
      'Le widget affiche aussi les tâches en retard, marquées en rouge.',
      "Coche les tâches directement depuis le widget (iOS 17+) — sans ouvrir l'app.",
      'Crée des cartes pour les fêtes du prénom et les anniversaires — avec une vraie photo en fond.',
    ],
    'it': [
      'Il widget ora mostra anche le attività scadute, segnate in rosso.',
      "Segna le attività direttamente dal widget (iOS 17+) — senza aprire l'app.",
      'Crea cartoline per onomastici e compleanni — con una vera foto di sfondo.',
    ],
    'el': [
      'Το widget δείχνει τώρα και τις εκπρόθεσμες εργασίες, με κόκκινο.',
      'Τσέκαρε εργασίες κατευθείαν από το widget (iOS 17+) — χωρίς να ανοίξεις την εφαρμογή.',
      'Φτιάξε κάρτες για ονομαστικές εορτές και γενέθλια — με πραγματική φωτογραφία φόντο.',
    ],
    'es': [
      'El widget ahora también muestra las tareas vencidas, marcadas en rojo.',
      'Marca tareas directamente desde el widget (iOS 17+) — sin abrir la app.',
      'Crea tarjetas para onomásticas y cumpleaños — con una foto real de fondo.',
    ],
    'pt': [
      'O widget mostra agora também as tarefas atrasadas, marcadas a vermelho.',
      'Marca tarefas diretamente no widget (iOS 17+) — sem abrir a app.',
      'Cria cartões para dias do nome e aniversários — com uma foto real de fundo.',
    ],
    'ru': [
      'Виджет теперь показывает и просроченные задачи, отмеченные красным.',
      'Отмечай задачи прямо из виджета (iOS 17+) — не открывая приложение.',
      'Создавай открытки на именины и дни рождения — с настоящим фото на фоне.',
    ],
    'tr': [
      'Widget artık gecikmiş görevleri de kırmızıyla gösteriyor.',
      "Görevleri doğrudan widget'tan işaretle (iOS 17+) — uygulamayı açmadan.",
      'İsim günleri ve doğum günleri için kart yap — gerçek fotoğraf arka planıyla.',
    ],
    'ja': [
      'ウィジェットが期限切れのタスクも赤で表示するようになりました。',
      'ウィジェットから直接タスクを完了（iOS 17以降）— アプリを開かずに。',
      '聖名祝日や誕生日のカードを作成 — 本物の写真を背景に。',
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
        content: SingleChildScrollView(
          child: Column(
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
