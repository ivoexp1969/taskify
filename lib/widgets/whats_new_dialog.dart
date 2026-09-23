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
  static const int _build = 73;

  static const String _prefKey = 'whats_new_seen_build';

  /// Точките за текущата версия, по език.
  static const Map<String, List<String>> _items = {
    'bg': [
      '🎉 Секцията „Още от 1969" вече работи и на iOS — с детекция дали Навици е инсталирано. С код NAVICI30 → 30 дни Pro в Taskify при инсталация на Навици.',
    ],
    'en': [
      '🎉 The "More from 1969" section now works on iOS — with detection of whether Навици is installed. Code NAVICI30 → 30 days of Taskify Pro when you install Навици.',
    ],
    'de': [
      '🎉 Der Bereich „Mehr von 1969" funktioniert jetzt auch auf iOS — mit Erkennung, ob Навици installiert ist. Code NAVICI30 → 30 Tage Taskify Pro bei Installation von Навици.',
    ],
    'fr': [
      '🎉 La section « Plus de 1969 » fonctionne désormais sur iOS — avec détection si Навици est installé. Code NAVICI30 → 30 jours de Taskify Pro à l\'installation de Навици.',
    ],
    'it': [
      '🎉 La sezione "Altro da 1969" ora funziona anche su iOS — con rilevamento se Навици è installato. Codice NAVICI30 → 30 giorni di Taskify Pro installando Навици.',
    ],
    'el': [
      '🎉 Η ενότητα «Περισσότερα από το 1969» λειτουργεί τώρα και σε iOS — με ανίχνευση αν το Навици είναι εγκατεστημένο. Κωδικός NAVICI30 → 30 ημέρες Taskify Pro με την εγκατάσταση του Навици.',
    ],
    'es': [
      '🎉 La sección "Más de 1969" ahora funciona en iOS — con detección de si Навици está instalado. Código NAVICI30 → 30 días de Taskify Pro al instalar Навици.',
    ],
    'pt': [
      '🎉 A seção "Mais de 1969" agora funciona no iOS — com detecção de se o Навици está instalado. Código NAVICI30 → 30 dias de Taskify Pro ao instalar Навици.',
    ],
    'ru': [
      '🎉 Раздел «Ещё от 1969» теперь работает и на iOS — с определением, установлено ли Навици. Код NAVICI30 → 30 дней Taskify Pro при установке Навици.',
    ],
    'tr': [
      '🎉 "1969\'dan daha fazlası" bölümü artık iOS\'ta da çalışıyor — Навици\'nin yüklü olup olmadığını algılar. NAVICI30 kodu → Навици\'yi yükleyince 30 gün Taskify Pro.',
    ],
    'ja': [
      '🎉 「1969のその他のアプリ」が iOS でも動作 — Навици がインストール済みか検出します。コード NAVICI30 で、Навици をインストールすると Taskify Pro が30日間。',
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
