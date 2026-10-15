import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/pro_service.dart';
import '../services/name_days_service.dart';
import '../services/contact_name_index.dart';
import '../services/analytics_service.dart';
import '../screens/paywall/paywall_screen.dart';
import '../utils/localization.dart';
import '../utils/debug_overrides.dart';

/// Заключена, но ВИДИМА карта в таб „Задачи" — показва се САМО на безплатен
/// потребител и САМО в ден с имен ден. Тийзър към Pro функцията „Контакти с имен
/// ден". Тап → paywall (source=contacts). Реактивна: слуша Pro статуса, индекса
/// на контактите и toggle-а за именни дни.
class NameDayTeaserCard extends StatefulWidget {
  const NameDayTeaserCard({super.key});

  @override
  State<NameDayTeaserCard> createState() => _NameDayTeaserCardState();
}

class _NameDayTeaserCardState extends State<NameDayTeaserCard> {
  final _pro = ProService();

  @override
  void initState() {
    super.initState();
    _pro.addListener(_onChange);
    ContactNameIndex().revision.addListener(_onChange);
    ContactNameIndex().enabledNotifier.addListener(_onChange);
    NameDaysService.enabledNotifier.addListener(_onChange);
    // Зареждаме dataset-а + индекса (идемпотентно), после прерисуваме.
    NameDaysService().load().then((_) {
      if (mounted) setState(() {});
    });
    ContactNameIndex().ensureLoaded();
  }

  @override
  void dispose() {
    _pro.removeListener(_onChange);
    ContactNameIndex().revision.removeListener(_onChange);
    ContactNameIndex().enabledNotifier.removeListener(_onChange);
    NameDaysService.enabledNotifier.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  void _openPaywall(String lang) {
    const feature = {
      'en': 'Name day contacts', 'nl': 'Naamdag-contacten', 'uk': 'Контакти іменин', 'bg': 'Контакти с имен ден',
      'de': 'Namenstag-Kontakte', 'fr': 'Contacts fête du prénom', 'it': 'Contatti onomastico',
      'el': 'Επαφές ονομαστικής', 'es': 'Contactos de onomástica', 'pt': 'Contactos do dia do nome',
      'ru': 'Контакты именин', 'tr': 'İsim günü kişileri', 'ja': '聖名祝日の連絡先',
    };
    AnalyticsService().logLockedFeatureTap('contacts');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          featureName: feature[lang] ?? feature['en']!,
          source: 'contacts',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Само за безплатен потребител (не web, не Pro).
    if (kIsWeb || _pro.isPro) return const SizedBox.shrink();

    final today = DebugOverrides.now();
    final nameDay = NameDaysService().forDate(today);
    if (nameDay == null || nameDay.names.isEmpty) {
      return const SizedBox.shrink();
    }

    final lang = LanguageScope.of(context).locale.languageCode;
    final theme = Theme.of(context);

    // Контакти с имен ден днес (ако функцията е вкл. + има индекс).
    final hasIndex = ContactNameIndex().isEnabled;
    final count = hasIndex
        ? ContactNameIndex().contactsForNames(nameDay.names).length
        : 0;

    // С индекс + поне 1 контакт → брой; иначе имената на деня.
    const withIndexTpl = {
      'en': '🎉 {n} of your contacts have a name day today', 'nl': '🎉 {n} van je contacten zijn vandaag jarig van naam', 'uk': '🎉 Сьогодні іменини у {n} ваших контактів',
      'bg': '🎉 Днес имат имен ден {n} от твоите контакти',
      'de': '🎉 {n} deiner Kontakte haben heute Namenstag',
      'fr': '🎉 {n} de tes contacts fêtent leur prénom aujourd\'hui',
      'it': '🎉 {n} dei tuoi contatti festeggiano l\'onomastico oggi',
      'el': '🎉 {n} από τις επαφές σου έχουν ονομαστική σήμερα',
      'es': '🎉 {n} de tus contactos celebran su santo hoy',
      'pt': '🎉 {n} dos teus contactos fazem anos do nome hoje',
      'ru': '🎉 Сегодня именины у {n} ваших контактов',
      'tr': '🎉 Bugün kişilerinden {n} kişinin isim günü', 'ja': '🎉 今日は連絡先{n}人が聖名祝日です',
    };
    const seeWho = {
      'en': '🔒 See who', 'nl': '🔒 Bekijk wie', 'uk': '🔒 Подивитися хто', 'bg': '🔒 Виж кои',
      'de': '🔒 Wer?', 'fr': '🔒 Voir qui', 'it': '🔒 Scopri chi', 'el': '🔒 Δες ποιοι',
      'es': '🔒 Ver quiénes', 'pt': '🔒 Ver quem', 'ru': '🔒 Кто именно', 'tr': '🔒 Kimler', 'ja': '🔒 誰か見る',
    };
    const noIndexTpl = {
      'en': 'Today {names} celebrate — find out which of your contacts 🔒', 'nl': 'Vandaag vieren {names} — ontdek welke van je contacten 🔒', 'uk': 'Сьогодні святкують {names} — дізнайтеся, хто з ваших контактів 🔒',
      'bg': 'Днес празнуват {names} — разбери кои от контактите ти 🔒',
      'de': 'Heute feiern {names} — finde heraus, wer deiner Kontakte 🔒',
      'fr': 'Aujourd\'hui {names} fêtent — découvre lesquels de tes contacts 🔒',
      'it': 'Oggi festeggiano {names} — scopri quali dei tuoi contatti 🔒',
      'el': 'Σήμερα γιορτάζουν {names} — δες ποιες επαφές σου 🔒',
      'es': 'Hoy celebran {names} — descubre cuáles de tus contactos 🔒',
      'pt': 'Hoje {names} celebram — descobre quais dos teus contactos 🔒',
      'ru': 'Сегодня празднуют {names} — узнайте, кто из ваших контактов 🔒',
      'tr': 'Bugün {names} kutluyor — kişilerinden hangileri gör 🔒', 'ja': '今日は{names}がお祝い — 連絡先の誰かを確認 🔒',
    };

    final bool showCount = hasIndex && count > 0;
    final titleText = showCount
        ? (withIndexTpl[lang] ?? withIndexTpl['en']!).replaceAll('{n}', '$count')
        : (noIndexTpl[lang] ?? noIndexTpl['en']!)
            .replaceAll('{names}', nameDay.names.join(', '));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Material(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _openPaywall(lang),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.30),
              ),
            ),
            child: Row(
              children: [
                const Text('🎂', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titleText,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  showCount ? (seeWho[lang] ?? seeWho['en']!) : '›',
                  style: TextStyle(
                    fontSize: showCount ? 12 : 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
