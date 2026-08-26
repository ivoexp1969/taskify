import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/localization.dart';
import '../../../services/name_days_service.dart';
import '../../../services/contact_name_index.dart';
import '../../../services/pro_service.dart';
import '../../paywall/paywall_screen.dart';

/// Секция „България" в Настройки (влива се в група „Език и регион").
/// Показва се само в BG контекст (bg език или устройство с countryCode == BG).
/// Съдържа toggle „Именни дни" (premium) + „Контакти с имен ден" (on-device).
/// Изнесено от `settings_screen.dart` без промяна на поведение.
class BulgariaSection extends StatefulWidget {
  const BulgariaSection({super.key});

  @override
  State<BulgariaSection> createState() => _BulgariaSectionState();
}

class _BulgariaSectionState extends State<BulgariaSection> {
  bool _nameDaysEnabled = false;
  bool _contactsNameDayEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadNameDaysSetting();
  }

  Future<void> _loadNameDaysSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsOn = await ContactNameIndex().loadEnabled();
    if (!mounted) return;
    setState(() {
      _nameDaysEnabled = prefs.getBool('name_days_enabled') ?? false;
      _contactsNameDayEnabled = contactsOn;
    });
  }

  /// Разделът „България" се показва само при български език или
  /// устройство на територията на България (locale countryCode == BG).
  bool get _isBgContext {
    final lang = LanguageScope.of(context).locale.languageCode;
    if (lang == 'bg') return true;
    final country =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    return country?.toUpperCase() == 'BG';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBgContext) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final lang = LanguageScope.of(context).locale.languageCode;

    const nameDaysTitle = {
      'en': 'Name days', 'bg': 'Именни дни', 'de': 'Namenstage',
      'fr': 'Fêtes des prénoms', 'it': 'Onomastici', 'el': 'Ονομαστικές εορτές',
      'es': 'Onomásticas', 'pt': 'Dias do nome', 'ru': 'Именины',
      'tr': 'İsim günleri', 'ja': '聖名祝日',
    };
    const nameDaysSubtitle = {
      'en': 'Bulgarian name days in the calendar',
      'bg': 'Български именни дни в календара',
      'de': 'Bulgarische Namenstage im Kalender',
      'fr': 'Fêtes des prénoms bulgares dans le calendrier',
      'it': 'Onomastici bulgari nel calendario',
      'el': 'Βουλγαρικές ονομαστικές εορτές στο ημερολόγιο',
      'es': 'Onomásticas búlgaras en el calendario',
      'pt': 'Dias do nome búlgaros no calendário',
      'ru': 'Болгарские именины в календаре',
      'tr': 'Takvimde Bulgarca isim günleri', 'ja': 'カレンダーにブルガリアの聖名祝日を表示',
    };
    const contactsTitle = {
      'en': 'Contacts celebrating', 'bg': 'Контакти с имен ден',
      'de': 'Feiernde Kontakte', 'fr': 'Contacts en fête',
      'it': 'Contatti in festa', 'el': 'Επαφές που γιορτάζουν',
      'es': 'Contactos que celebran', 'pt': 'Contactos em festa',
      'ru': 'Контакты с именинами', 'tr': 'İsim günü olan kişiler',
      'ja': '記念日の連絡先',
    };
    const contactsSubtitle = {
      'en': 'Show which of your contacts have a name day — stays on your device',
      'bg': 'Покажи кои от контактите ти празнуват — остава на устройството',
      'de': 'Zeigt, welche Kontakte Namenstag haben — bleibt auf dem Gerät',
      'fr': "Affiche quels contacts fêtent leur prénom — reste sur l'appareil",
      'it': 'Mostra quali contatti festeggiano — resta sul dispositivo',
      'el': 'Δείχνει ποιες επαφές γιορτάζουν — μένει στη συσκευή',
      'es': 'Muestra qué contactos celebran su santo — no sale del dispositivo',
      'pt': 'Mostra que contactos fazem anos do nome — fica no dispositivo',
      'ru': 'Показывает, у кого из контактов именины — остаётся на устройстве',
      'tr': 'Hangi kişilerin isim günü olduğunu gösterir — cihazda kalır',
      'ja': '記念日の連絡先を表示 — データは端末内のみ',
    };
    const contactsPermDenied = {
      'en': 'Contacts permission is required for this feature',
      'bg': 'Нужно е разрешение за контакти',
      'de': 'Kontaktberechtigung erforderlich',
      'fr': 'Autorisation des contacts requise',
      'it': 'Autorizzazione ai contatti necessaria',
      'el': 'Απαιτείται άδεια επαφών',
      'es': 'Se necesita permiso de contactos',
      'pt': 'É necessária permissão de contactos',
      'ru': 'Требуется доступ к контактам',
      'tr': 'Kişiler izni gerekli', 'ja': '連絡先へのアクセス許可が必要です',
    };
    const contactsRefresh = {
      'en': 'Refresh contacts', 'bg': 'Опресни контактите',
      'de': 'Kontakte aktualisieren', 'fr': 'Actualiser les contacts',
      'it': 'Aggiorna i contatti', 'el': 'Ανανέωση επαφών',
      'es': 'Actualizar contactos', 'pt': 'Atualizar contactos',
      'ru': 'Обновить контакты', 'tr': 'Kişileri yenile',
      'ja': '連絡先を更新',
    };
    const contactsRefreshHint = {
      'en': 'Rebuild the local index after contact changes',
      'bg': 'Преизгражда локалния индекс след промени',
      'de': 'Lokalen Index nach Änderungen neu aufbauen',
      'fr': "Reconstruit l'index local après modifications",
      'it': "Ricostruisce l'indice locale dopo le modifiche",
      'el': 'Αναδημιουργεί τον τοπικό δείκτη μετά από αλλαγές',
      'es': 'Reconstruye el índice local tras los cambios',
      'pt': 'Reconstrói o índice local após alterações',
      'ru': 'Перестроить локальный индекс после изменений',
      'tr': 'Değişikliklerden sonra yerel dizini yeniden oluştur',
      'ja': '変更後にローカル索引を再構築',
    };
    const contactsRefreshed = {
      'en': 'Contacts refreshed', 'bg': 'Контактите са обновени',
      'de': 'Kontakte aktualisiert', 'fr': 'Contacts actualisés',
      'it': 'Contatti aggiornati', 'el': 'Οι επαφές ανανεώθηκαν',
      'es': 'Contactos actualizados', 'pt': 'Contactos atualizados',
      'ru': 'Контакты обновлены', 'tr': 'Kişiler yenilendi',
      'ja': '連絡先を更新しました',
    };

    String tr(Map<String, String> m) => m[lang] ?? m['en']!;
    final isPro = ProService().isPro;

    // Пакет 2: връща само тайловете Именни дни / Контакти (без header + без
    // Училищен режим) — вливат се в група „Език и регион".
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          child: SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8E24AA).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cake_rounded, color: Color(0xFF8E24AA)),
            ),
            title: Row(
              children: [
                Flexible(child: Text(tr(nameDaysTitle))),
                if (!isPro) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.lock, size: 14, color: theme.colorScheme.primary),
                ],
              ],
            ),
            subtitle: Text(
              tr(nameDaysSubtitle),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            value: _nameDaysEnabled,
            onChanged: (value) async {
              if (value && !isPro) {
                final upgraded = await showPaywallIfNeeded(
                  context,
                  isFeatureAvailable: false,
                  featureName: tr(nameDaysTitle),
                );
                if (!upgraded) return;
              }
              setState(() => _nameDaysEnabled = value);
              // Записва + обновява глобалния notifier (календарът реагира веднага).
              await NameDaysService().setEnabled(value);
              // Сутрешни нотификации за имен ден (вкл./изкл.)
              if (value) {
                await NameDaysService().scheduleNotifications(lang: lang);
              } else {
                await NameDaysService().cancelNotifications();
              }
            },
          ),
        ),
        // „Контакти с имен ден" — само на мобилни (уеб няма контакти) и само
        // когато именните дни са включени (функцията ги допълва). On-device.
        if (_nameDaysEnabled && !kIsWeb) ...[
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E24AA).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.contacts_rounded,
                        color: Color(0xFF8E24AA)),
                  ),
                  title: Row(
                    children: [
                      Flexible(child: Text(tr(contactsTitle))),
                      if (!isPro) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.lock,
                            size: 14, color: theme.colorScheme.primary),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    tr(contactsSubtitle),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  value: _contactsNameDayEnabled,
                  onChanged: (value) async {
                    if (value) {
                      if (!isPro) {
                        final upgraded = await showPaywallIfNeeded(
                          context,
                          isFeatureAvailable: false,
                          featureName: tr(contactsTitle),
                        );
                        if (!upgraded) return;
                      }
                      final granted =
                          await ContactNameIndex().requestPermission();
                      if (!granted) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(tr(contactsPermDenied))),
                          );
                        }
                        return;
                      }
                      await ContactNameIndex().setEnabled(true);
                      if (mounted) {
                        setState(() => _contactsNameDayEnabled = true);
                      }
                      // Индексът се гради във фон (1000+ контакта не блокират UI).
                      unawaited(ContactNameIndex().rebuild());
                    } else {
                      await ContactNameIndex().setEnabled(false);
                      if (mounted) {
                        setState(() => _contactsNameDayEnabled = false);
                      }
                    }
                  },
                ),
                if (_contactsNameDayEnabled) ...[
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.refresh_rounded,
                        color: Color(0xFF8E24AA)),
                    title: Text(tr(contactsRefresh)),
                    subtitle: Text(
                      tr(contactsRefreshHint),
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    onTap: () async {
                      await ContactNameIndex().rebuild();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(tr(contactsRefreshed))),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
