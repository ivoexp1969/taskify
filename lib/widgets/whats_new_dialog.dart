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
  /// ★1.0.70 → versionCode 80★.
  static const int _build = 80;

  static const String _prefKey = 'whats_new_seen_build';

  /// Точките за текущата версия (1.0.70), ×13 езика.
  static const Map<String, List<String>> _items = {
    'en': [
      '📅 Calendar and name days are now free.',
      '📄 Track up to 3 documents for free.',
      '🎂 Expanded Bulgarian name-day calendar — more names and dates.',
    ],
    'bg': [
      '📅 Календарът и имените дни вече са безплатни.',
      '📄 До 3 документа безплатно.',
      '🎂 Разширен именник — още имена и дати.',
    ],
    'de': [
      '📅 Kalender und Namenstage sind jetzt kostenlos.',
      '📄 Verfolge bis zu 3 Dokumente kostenlos.',
      '🎂 Erweiterter Namenstags-Kalender — mehr Namen und Daten.',
    ],
    'fr': [
      '📅 Le calendrier et les fêtes des prénoms sont désormais gratuits.',
      '📄 Suis jusqu\'à 3 documents gratuitement.',
      '🎂 Calendrier des fêtes des prénoms enrichi — plus de noms et de dates.',
    ],
    'it': [
      '📅 Calendario e onomastici ora sono gratuiti.',
      '📄 Tieni traccia di un massimo di 3 documenti gratis.',
      '🎂 Calendario degli onomastici ampliato — più nomi e date.',
    ],
    'el': [
      '📅 Το ημερολόγιο και οι ονομαστικές εορτές είναι πλέον δωρεάν.',
      '📄 Παρακολούθησε έως 3 έγγραφα δωρεάν.',
      '🎂 Εμπλουτισμένο ημερολόγιο ονομαστικών εορτών — περισσότερα ονόματα και ημερομηνίες.',
    ],
    'es': [
      '📅 El calendario y las onomásticas ahora son gratis.',
      '📄 Controla hasta 3 documentos gratis.',
      '🎂 Calendario de onomásticas ampliado — más nombres y fechas.',
    ],
    'pt': [
      '📅 O calendário e os dias do nome agora são grátis.',
      '📄 Acompanha até 3 documentos grátis.',
      '🎂 Calendário de dias do nome ampliado — mais nomes e datas.',
    ],
    'ru': [
      '📅 Календарь и именины теперь бесплатны.',
      '📄 Отслеживай до 3 документов бесплатно.',
      '🎂 Расширенный календарь именин — больше имён и дат.',
    ],
    'tr': [
      '📅 Takvim ve isim günleri artık ücretsiz.',
      '📄 3 belgeye kadar ücretsiz takip et.',
      '🎂 Genişletilmiş isim günü takvimi — daha fazla isim ve tarih.',
    ],
    'nl': [
      '📅 Agenda en naamdagen zijn nu gratis.',
      '📄 Volg tot 3 documenten gratis.',
      '🎂 Uitgebreide naamdagkalender — meer namen en datums.',
    ],
    'uk': [
      '📅 Календар та іменини тепер безкоштовні.',
      '📄 Відстежуй до 3 документів безкоштовно.',
      '🎂 Розширений календар іменин — більше імен і дат.',
    ],
    'ja': [
      '📅 カレンダーと聖名祝日が無料になりました。',
      '📄 最大3件のドキュメントを無料で管理。',
      '🎂 ブルガリアの聖名祝日カレンダーを拡充 — 名前と日付が増えました。',
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
