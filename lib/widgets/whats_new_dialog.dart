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
  static const int _build = 72;

  static const String _prefKey = 'whats_new_seen_build';

  /// Точките за текущата версия, по език.
  static const Map<String, List<String>> _items = {
    'bg': [
      '🎉 Нова секция „Още от 1969" в Настройки — препоръка за „Навици", моето приложение за навици. С код NAVICI30 → 30 дни Pro в Taskify при инсталация на Навици.',
    ],
    'en': [
      '🎉 New "More from 1969" section in Settings — recommending Навици, my habit tracker. Use code NAVICI30 for 30 days of Taskify Pro when you install Навици.',
    ],
    'de': [
      '🎉 Neuer Bereich „Mehr von 1969" in den Einstellungen — Empfehlung für Навици, meine Gewohnheits-App. Mit Code NAVICI30 → 30 Tage Taskify Pro bei Installation von Навици.',
    ],
    'fr': [
      '🎉 Nouvelle section « Plus de 1969 » dans les Réglages — Навици, mon appli d\'habitudes. Code NAVICI30 → 30 jours de Taskify Pro à l\'installation de Навици.',
    ],
    'it': [
      '🎉 Nuova sezione "Altro da 1969" nelle Impostazioni — Навици, la mia app per le abitudini. Codice NAVICI30 → 30 giorni di Taskify Pro installando Навици.',
    ],
    'el': [
      '🎉 Νέα ενότητα «Περισσότερα από το 1969» στις Ρυθμίσεις — το Навици, η εφαρμογή μου για συνήθειες. Κωδικός NAVICI30 → 30 ημέρες Taskify Pro με την εγκατάσταση του Навици.',
    ],
    'es': [
      '🎉 Nueva sección "Más de 1969" en Ajustes — Навици, mi app de hábitos. Con el código NAVICI30 → 30 días de Taskify Pro al instalar Навици.',
    ],
    'pt': [
      '🎉 Nova seção "Mais de 1969" nas Configurações — Навици, meu app de hábitos. Com o código NAVICI30 → 30 dias de Taskify Pro ao instalar Навици.',
    ],
    'ru': [
      '🎉 Новый раздел «Ещё от 1969» в Настройках — Навици, моё приложение для привычек. Код NAVICI30 → 30 дней Taskify Pro при установке Навици.',
    ],
    'tr': [
      '🎉 Ayarlar\'da yeni "1969\'dan daha fazlası" bölümü — alışkanlık uygulamam Навици. NAVICI30 kodu → Навици\'yi yükleyince 30 gün Taskify Pro.',
    ],
    'ja': [
      '🎉 設定に新セクション「1969のその他のアプリ」— 習慣アプリ Навици のおすすめ。コード NAVICI30 で、Навици をインストールすると Taskify Pro が30日間。',
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
