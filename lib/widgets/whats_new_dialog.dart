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
      '🌍 Taskify вече говори нидерландски и украински! Смени езика от Настройки → Език.',
    ],
    'en': [
      '🌍 Taskify now speaks Dutch and Ukrainian! Change it in Settings → Language.',
    ],
    'nl': [
      '🌍 Taskify spreekt nu Nederlands en Oekraïens! Wijzig het bij Instellingen → Taal.',
    ],
    'uk': [
      '🌍 Taskify тепер розмовляє нідерландською та українською! Змініть у Налаштування → Мова.',
    ],
    'de': [
      '🌍 Taskify spricht jetzt Niederländisch und Ukrainisch! Ändere es in Einstellungen → Sprache.',
    ],
    'fr': [
      '🌍 Taskify parle désormais néerlandais et ukrainien ! Changez-le dans Réglages → Langue.',
    ],
    'it': [
      '🌍 Taskify ora parla olandese e ucraino! Cambia lingua in Impostazioni → Lingua.',
    ],
    'el': [
      '🌍 Το Taskify μιλάει τώρα ολλανδικά και ουκρανικά! Άλλαξέ το στις Ρυθμίσεις → Γλώσσα.',
    ],
    'es': [
      '🌍 ¡Taskify ahora habla neerlandés y ucraniano! Cámbialo en Ajustes → Idioma.',
    ],
    'pt': [
      '🌍 O Taskify agora fala holandês e ucraniano! Altere em Configurações → Idioma.',
    ],
    'ru': [
      '🌍 Taskify теперь говорит на нидерландском и украинском! Измените в Настройках → Язык.',
    ],
    'tr': [
      '🌍 Taskify artık Felemenkçe ve Ukraynaca konuşuyor! Ayarlar → Dil bölümünden değiştir.',
    ],
    'ja': [
      '🌍 Taskify がオランダ語とウクライナ語に対応しました！設定 → 言語 で変更できます。',
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
