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
  /// ★1.0.71 → versionCode 81★.
  static const int _build = 81;

  static const String _prefKey = 'whats_new_seen_build';

  /// Точките за текущата версия (1.0.71), ×13 езика.
  static const Map<String, List<String>> _items = {
    'en': [
      '🆕 A fresh start screen helps you add your first task faster.',
      '📅 Smarter date recognition when adding a task (e.g. "12 December", "12.12").',
      '🔒 New setting: Anonymous statistics (you can turn it off anytime).',
    ],
    'bg': [
      '🆕 Нов начален екран за по-бързо създаване на първата задача.',
      '📅 По-умно разпознаване на датата при добавяне (напр. „12 декември", „12.12").',
      '🔒 Нова настройка „Анонимна статистика" (може да се изключи по всяко време).',
    ],
    'de': [
      '🆕 Neuer Startbildschirm — füge deine erste Aufgabe schneller hinzu.',
      '📅 Bessere Datumserkennung beim Hinzufügen (z. B. „12. Dezember", „12.12").',
      '🔒 Neue Einstellung: Anonyme Statistik (jederzeit abschaltbar).',
    ],
    'fr': [
      '🆕 Nouvel écran d\'accueil pour ajouter ta première tâche plus vite.',
      '📅 Meilleure reconnaissance des dates à l\'ajout (ex. « 12 décembre », « 12.12 »).',
      '🔒 Nouveau réglage : statistiques anonymes (désactivable à tout moment).',
    ],
    'it': [
      '🆕 Nuova schermata iniziale per aggiungere la prima attività più in fretta.',
      '📅 Riconoscimento delle date migliorato (es. "12 dicembre", "12.12").',
      '🔒 Nuova impostazione: statistiche anonime (disattivabile quando vuoi).',
    ],
    'el': [
      '🆕 Νέα αρχική οθόνη για να προσθέσεις πιο γρήγορα την πρώτη σου εργασία.',
      '📅 Εξυπνότερη αναγνώριση ημερομηνίας κατά την προσθήκη (π.χ. «12 Δεκεμβρίου», «12.12»).',
      '🔒 Νέα ρύθμιση: Ανώνυμα στατιστικά (μπορείς να τα απενεργοποιήσεις όποτε θέλεις).',
    ],
    'es': [
      '🆕 Nueva pantalla de inicio para añadir tu primera tarea más rápido.',
      '📅 Mejor reconocimiento de fechas al añadir (p. ej. "12 de diciembre", "12.12").',
      '🔒 Nuevo ajuste: estadísticas anónimas (puedes desactivarlo cuando quieras).',
    ],
    'pt': [
      '🆕 Nova tela inicial para adicionar a primeira tarefa mais rápido.',
      '📅 Reconhecimento de datas mais inteligente ao adicionar (ex.: "12 de dezembro", "12.12").',
      '🔒 Nova configuração: estatísticas anônimas (pode desativar quando quiser).',
    ],
    'ru': [
      '🆕 Новый начальный экран — добавь первую задачу быстрее.',
      '📅 Умное распознавание даты при добавлении (напр. «12 декабря», «12.12»).',
      '🔒 Новая настройка: анонимная статистика (можно отключить в любой момент).',
    ],
    'tr': [
      '🆕 İlk görevini daha hızlı eklemen için yeni başlangıç ekranı.',
      '📅 Görev eklerken daha akıllı tarih tanıma (örn. "12 Aralık", "12.12").',
      '🔒 Yeni ayar: Anonim istatistikler (istediğin zaman kapatabilirsin).',
    ],
    'nl': [
      '🆕 Nieuw startscherm om je eerste taak sneller toe te voegen.',
      '📅 Slimmere datumherkenning bij het toevoegen (bijv. "12 december", "12.12").',
      '🔒 Nieuwe instelling: anonieme statistieken (altijd uit te schakelen).',
    ],
    'uk': [
      '🆕 Новий початковий екран — додай перше завдання швидше.',
      '📅 Розумніше розпізнавання дати під час додавання (напр. «12 грудня», «12.12»).',
      '🔒 Нове налаштування: анонімна статистика (можна вимкнути будь-коли).',
    ],
    'ja': [
      '🆕 新しいホーム画面で最初のタスクをすばやく追加できます。',
      '📅 タスク追加時の日付認識が賢くなりました（例：「12月12日」「12.12」）。',
      '🔒 新しい設定：匿名の統計（いつでもオフにできます）。',
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
