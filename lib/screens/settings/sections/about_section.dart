import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../utils/localization.dart';
import '../how_to_use_screen.dart';
import 'settings_group.dart';

/// Секция „За приложението" (най-долу в Настройки): динамична версия/билд
/// (package_info_plus), подекран „Как се ползва" и полезни линкове
/// (Поверителност, Условия, лиценз на именните дни — CC BY-SA).
///
/// Изнесена 1:1 от [SettingsScreen] (`_buildAboutSection`).
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = LanguageScope.of(context).locale.languageCode;
    String tr(Map<String, String> m) => m[lang] ?? m['en']!;

    const sectionTitle = {
      'en': 'About', 'bg': 'За приложението', 'de': 'Über die App',
      'fr': 'À propos', 'it': 'Informazioni', 'el': 'Σχετικά',
      'es': 'Acerca de', 'pt': 'Sobre', 'ru': 'О приложении',
      'tr': 'Hakkında', 'ja': 'アプリについて',
    };
    const versionWord = {
      'en': 'Version', 'bg': 'Версия', 'de': 'Version', 'fr': 'Version',
      'it': 'Versione', 'el': 'Έκδοση', 'es': 'Versión', 'pt': 'Versão',
      'ru': 'Версия', 'tr': 'Sürüm', 'ja': 'バージョン',
    };
    const howToTitle = {
      'en': 'How to use', 'bg': 'Как се ползва', 'de': 'Anleitung',
      'fr': 'Comment ça marche', 'it': 'Come si usa', 'el': 'Πώς λειτουργεί',
      'es': 'Cómo se usa', 'pt': 'Como usar', 'ru': 'Как пользоваться',
      'tr': 'Nasıl kullanılır', 'ja': '使い方',
    };
    const howToSubtitle = {
      'en': 'Quick guide', 'bg': 'Кратко ръководство', 'de': 'Kurzanleitung',
      'fr': 'Guide rapide', 'it': 'Guida rapida', 'el': 'Σύντομος οδηγός',
      'es': 'Guía rápida', 'pt': 'Guia rápido', 'ru': 'Краткое руководство',
      'tr': 'Hızlı kılavuz', 'ja': 'クイックガイド',
    };
    const privacyLabel = {
      'en': 'Privacy Policy', 'bg': 'Политика за поверителност',
      'de': 'Datenschutz', 'fr': 'Confidentialité', 'it': 'Privacy',
      'el': 'Απόρρητο', 'es': 'Privacidad', 'pt': 'Privacidade',
      'ru': 'Конфиденциальность', 'tr': 'Gizlilik', 'ja': 'プライバシー',
    };
    const termsLabel = {
      'en': 'Terms of Use', 'bg': 'Условия за ползване',
      'de': 'Nutzungsbedingungen', 'fr': "Conditions d'utilisation",
      'it': "Termini d'uso", 'el': 'Όροι χρήσης', 'es': 'Términos de uso',
      'pt': 'Termos de uso', 'ru': 'Условия использования',
      'tr': 'Kullanım koşulları', 'ja': '利用規約',
    };
    const nameDaysLicense = {
      'en': 'Name days: data from Wikipedia (CC BY-SA 4.0)',
      'bg': 'Именни дни: данни от Уикипедия (CC BY-SA 4.0)',
      'de': 'Namenstage: Daten aus Wikipedia (CC BY-SA 4.0)',
      'fr': 'Fêtes des prénoms : données de Wikipédia (CC BY-SA 4.0)',
      'it': 'Onomastici: dati da Wikipedia (CC BY-SA 4.0)',
      'el': 'Ονομαστικές εορτές: δεδομένα από τη Wikipedia (CC BY-SA 4.0)',
      'es': 'Onomásticas: datos de Wikipedia (CC BY-SA 4.0)',
      'pt': 'Dias do nome: dados da Wikipédia (CC BY-SA 4.0)',
      'ru': 'Именины: данные из Википедии (CC BY-SA 4.0)',
      'tr': 'İsim günleri: Wikipedia verileri (CC BY-SA 4.0)',
      'ja': '聖名祝日: Wikipediaのデータ (CC BY-SA 4.0)',
    };

    return SettingsGroup(
      title: tr(sectionTitle),
      icon: Icons.info_outline_rounded,
      color: Colors.blueGrey,
      children: [
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              // Версия + билд — четат се ДИНАМИЧНО от package_info_plus.
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snap) {
                  final info = snap.data;
                  final subtitle = info == null
                      ? '…'
                      : '${tr(versionWord)} ${info.version} (build ${info.buildNumber})';
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.info_outline,
                          color: theme.colorScheme.primary),
                    ),
                    title: const Text('Taskify'),
                    subtitle: Text(subtitle),
                  );
                },
              ),
              const Divider(height: 1),
              // „Как се ползва" → подекран.
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.help_outline, color: theme.colorScheme.primary),
                ),
                title: Text(tr(howToTitle)),
                subtitle: Text(
                  tr(howToSubtitle),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HowToUseScreen()),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(tr(privacyLabel)),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _openUrl('https://taskify1969.com/privacy'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(tr(termsLabel)),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _openUrl('https://taskify1969.com/terms'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Лиценз на именните дни (CC BY-SA изисква атрибуция).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: InkWell(
            onTap: () =>
                _openUrl('https://bg.wikipedia.org/wiki/Имен_ден'),
            child: Text(
              tr(nameDaysLicense),
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
