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
///   2) подмени [_items] с точките за новата версия (поне BG + EN; останалите
///      езици падат на EN).
///
/// Нови инсталации НЕ го виждат (те виждат welcome диалога).
class WhatsNewDialog {
  /// Билдът, за който са точките по-долу (= `pubspec.yaml` build number).
  /// ★1.0.72 → versionCode 82★ (1.0.71 взема 81 на отделния клон).
  static const int _build = 82;

  static const String _prefKey = 'whats_new_seen_build';

  /// Точките за текущата версия (1.0.72 — споделено пазаруване), ×13 езика.
  static const Map<String, List<String>> _items = {
    'en': [
      '🛒 Shared shopping lists in groups — everyone sees check-offs live.',
      '👪 "Move to group" — turn a personal list or task into a shared one.',
      '🔔 Reminders for group tasks.',
    ],
    'bg': [
      '🛒 Споделен списък за пазаруване в групите — всеки член вижда отметките на живо.',
      '👪 „Премести в група" — направи личен списък или задача споделена.',
      '🔔 Напомняния за груповите задачи.',
    ],
    'de': [
      '🛒 Gemeinsame Einkaufslisten in Gruppen — alle sehen Abhakungen live.',
      '👪 „In Gruppe verschieben" — mach eine persönliche Liste oder Aufgabe geteilt.',
      '🔔 Erinnerungen für Gruppenaufgaben.',
    ],
    'fr': [
      '🛒 Listes de courses partagées dans les groupes — tout le monde voit les cases cochées en direct.',
      '👪 « Déplacer vers un groupe » — rends une liste ou une tâche personnelle partagée.',
      '🔔 Rappels pour les tâches de groupe.',
    ],
    'it': [
      '🛒 Liste della spesa condivise nei gruppi — tutti vedono le spunte in tempo reale.',
      '👪 «Sposta nel gruppo» — rendi condivisa una lista o un\'attività personale.',
      '🔔 Promemoria per le attività di gruppo.',
    ],
    'el': [
      '🛒 Κοινόχρηστες λίστες για ψώνια στις ομάδες — όλοι βλέπουν τα τσεκαρίσματα ζωντανά.',
      '👪 «Μετακίνηση σε ομάδα» — κάνε μια προσωπική λίστα ή εργασία κοινόχρηστη.',
      '🔔 Υπενθυμίσεις για τις εργασίες ομάδας.',
    ],
    'es': [
      '🛒 Listas de la compra compartidas en los grupos — todos ven las marcas en tiempo real.',
      '👪 «Mover al grupo» — convierte una lista o tarea personal en compartida.',
      '🔔 Recordatorios para las tareas de grupo.',
    ],
    'pt': [
      '🛒 Listas de compras partilhadas nos grupos — todos veem as marcações em tempo real.',
      '👪 «Mover para grupo» — torna partilhada uma lista ou tarefa pessoal.',
      '🔔 Lembretes para as tarefas de grupo.',
    ],
    'ru': [
      '🛒 Общие списки покупок в группах — все видят отметки в реальном времени.',
      '👪 «Переместить в группу» — сделай личный список или задачу общими.',
      '🔔 Напоминания для групповых задач.',
    ],
    'tr': [
      '🛒 Gruplarda ortak alışveriş listeleri — herkes işaretlemeleri anında görür.',
      '👪 "Gruba taşı" — kişisel bir listeyi veya görevi paylaşımlı yap.',
      '🔔 Grup görevleri için hatırlatıcılar.',
    ],
    'nl': [
      '🛒 Gedeelde boodschappenlijsten in groepen — iedereen ziet het afvinken live.',
      '👪 "Naar groep verplaatsen" — maak een persoonlijke lijst of taak gedeeld.',
      '🔔 Herinneringen voor groepstaken.',
    ],
    'uk': [
      '🛒 Спільні списки покупок у групах — усі бачать позначки в реальному часі.',
      '👪 «Перемістити в групу» — зроби особистий список або завдання спільними.',
      '🔔 Нагадування для групових завдань.',
    ],
    'ja': [
      '🛒 グループで買い物リストを共有 — チェックがリアルタイムで全員に見えます。',
      '👪 「グループに移動」— 個人のリストやタスクを共有できます。',
      '🔔 グループタスクのリマインダー。',
    ],
  };

  static const Map<String, String> _title = {
    'en': "What's new", 'nl': 'Wat is er nieuw', 'uk': 'Що нового', 'bg': 'Какво ново', 'de': 'Was ist neu',
    'fr': 'Quoi de neuf', 'it': 'Novità', 'el': 'Τι νέο υπάρχει',
    'es': 'Novedades', 'pt': 'Novidades', 'ru': 'Что нового',
    'tr': 'Yenilikler', 'ja': '新着情報',
  };

  static const Map<String, String> _button = {
    'en': 'Got it!', 'nl': 'Begrepen!', 'uk': 'Зрозуміло!', 'bg': 'Супер!', 'de': 'Super!', 'fr': 'Compris!',
    'it': 'Ottimo!', 'el': 'Τέλεια!', 'es': '¡Genial!', 'pt': 'Ótimo!',
    'ru': 'Отлично!', 'tr': 'Harika!', 'ja': '了解！',
  };

  /// Отбелязва текущия билд като „видян" БЕЗ да показва диалога. Ползва се при
  /// нова инсталация (welcome диалогът поема) — така „Какво ново" не се трупа
  /// отгоре на welcome на един старт.
  static Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, _build);
    } catch (_) {}
  }

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
