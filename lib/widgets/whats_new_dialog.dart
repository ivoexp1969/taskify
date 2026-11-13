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
  /// ★1.0.73 → versionCode 84★ — по-точно разпознаване на дати и часове
  /// (изрична дата > ден от седмицата, Black Friday/Cyber Monday, „в 5" без
  /// am/pm, никога час в миналото).
  static const int _build = 84;

  static const String _prefKey = 'whats_new_seen_build';

  /// Точките за текущата версия (1.0.73), BG + EN; другите езици падат на EN.
  static const Map<String, List<String>> _items = {
    'en': [
      '📅 Explicit dates now win over the day of the week when adding a task.',
      '🛍️ Black Friday and Cyber Monday are recognized automatically.',
      '⏰ "at 5" without am/pm is understood — and the time is never set in the past.',
    ],
    'bg': [
      '📅 Изричната дата вече е с предимство пред деня от седмицата.',
      '🛍️ Black Friday и Cyber Monday се разпознават автоматично.',
      '⏰ „в 5" без am/pm се разбира — и часът никога не е в миналото.',
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
