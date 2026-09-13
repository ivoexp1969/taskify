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
  static const int _build = 70;

  static const String _prefKey = 'whats_new_seen_build';

  /// Точките за текущата версия, по език.
  static const Map<String, List<String>> _items = {
    'bg': [
      '☁️ Синхронизация между устройства: разписанието и профилът (ученик/студент) вече се пазят в облака и се появяват на всичките ти устройства.',
    ],
    'en': [
      '☁️ Cross-device sync: your schedule and school/student profile now stay in sync across your devices.',
    ],
    'de': [
      '☁️ Geräteübergreifende Synchronisierung: Dein Stundenplan und dein Schüler-/Studentenprofil werden jetzt auf allen Geräten synchron gehalten.',
    ],
    'fr': [
      '☁️ Synchronisation multi-appareils : ton emploi du temps et ton profil élève/étudiant sont désormais synchronisés sur tous tes appareils.',
    ],
    'it': [
      '☁️ Sincronizzazione tra dispositivi: il tuo orario e il profilo studente ora restano sincronizzati su tutti i dispositivi.',
    ],
    'el': [
      '☁️ Συγχρονισμός μεταξύ συσκευών: το πρόγραμμά σου και το μαθητικό/φοιτητικό προφίλ συγχρονίζονται πλέον σε όλες τις συσκευές σου.',
    ],
    'es': [
      '☁️ Sincronización entre dispositivos: tu horario y tu perfil de estudiante ahora se sincronizan en todos tus dispositivos.',
    ],
    'pt': [
      '☁️ Sincronização entre dispositivos: o teu horário e o perfil de aluno/estudante agora ficam sincronizados em todos os teus dispositivos.',
    ],
    'ru': [
      '☁️ Синхронизация между устройствами: расписание и профиль ученика/студента теперь синхронизируются на всех ваших устройствах.',
    ],
    'tr': [
      '☁️ Cihazlar arası senkronizasyon: ders programın ve öğrenci profilin artık tüm cihazlarında senkron kalıyor.',
    ],
    'ja': [
      '☁️ デバイス間同期：時間割と生徒・学生プロフィールが、すべての端末で同期されるようになりました。',
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
