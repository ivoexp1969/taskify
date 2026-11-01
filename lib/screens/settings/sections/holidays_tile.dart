import 'package:flutter/material.dart';

import '../../../services/holidays_service.dart';
import '../../../services/name_days_service.dart';

/// Тайл „Официални празници" — включване + избор на държава. Изнесен 1:1 от
/// [SettingsScreen] (`_buildHolidaysTile`). Тук е самостоятелен: чете/пише
/// състоянието директно през [HolidaysService] (единственият, който го ползва),
/// така че екранът вече не държи `_holidaysEnabled`/`_holidaysCountry`.
class HolidaysTile extends StatefulWidget {
  const HolidaysTile({super.key, required this.lang});

  final String lang;

  @override
  State<HolidaysTile> createState() => _HolidaysTileState();
}

class _HolidaysTileState extends State<HolidaysTile> {
  bool _holidaysEnabled = false;
  String _holidaysCountry = 'BG';

  static const List<(String, String)> _holidayCountries = [
    ('AT', '🇦🇹 Austria'),
    ('BG', '🇧🇬 Bulgaria'),
    ('CN', '🇨🇳 China'),
    ('CZ', '🇨🇿 Czechia'),
    ('FR', '🇫🇷 France'),
    ('DE', '🇩🇪 Germany'),
    ('GR', '🇬🇷 Greece'),
    ('HU', '🇭🇺 Hungary'),
    ('ID', '🇮🇩 Indonesia'),
    ('IT', '🇮🇹 Italy'),
    ('JP', '🇯🇵 Japan'),
    ('MK', '🇲🇰 North Macedonia'),
    ('NL', '🇳🇱 Netherlands'),
    ('PL', '🇵🇱 Poland'),
    ('PT', '🇵🇹 Portugal'),
    ('RO', '🇷🇴 Romania'),
    ('RU', '🇷🇺 Russia'),
    ('RS', '🇷🇸 Serbia'),
    ('KR', '🇰🇷 South Korea'),
    ('ES', '🇪🇸 Spain'),
    ('CH', '🇨🇭 Switzerland'),
    ('TR', '🇹🇷 Turkey'),
    ('UA', '🇺🇦 Ukraine'),
    ('GB', '🇬🇧 United Kingdom'),
    ('US', '🇺🇸 United States'),
  ];

  @override
  void initState() {
    super.initState();
    _loadHolidaysSetting();
  }

  Future<void> _loadHolidaysSetting() async {
    final enabled = await HolidaysService().loadEnabled();
    if (!mounted) return;
    setState(() {
      _holidaysEnabled = enabled;
      _holidaysCountry = HolidaysService().country;
    });
  }

  /// Имен-ден (само български dataset) следва избора на държава:
  ///  • BG → друга държава, при включен имен-ден: еднократен въпрос
  ///    „Да запазим ли българските имени дни?" [Запази] / [Изключи].
  ///  • друга държава → BG: пуска имен-ден пак, АКО не е изключван ръчно.
  Future<void> _handleNameDaysForCountryChange(
      String oldCountry, String newCountry) async {
    final nd = NameDaysService();
    final wasBg = oldCountry.toUpperCase() == 'BG';
    final isBg = newCountry.toUpperCase() == 'BG';
    if (wasBg == isBg) return; // няма преход BG ↔ друга държава

    if (wasBg && !isBg) {
      // Напускаме България. Питаме само ако имен-ден е включен в момента.
      final enabled = await nd.loadEnabled();
      if (!enabled || !mounted) return;
      final keep = await _askKeepNameDays();
      if (keep == false) {
        // Контекстно изключване (напускаме BG) — НЕ го броим за постоянен ръчен
        // opt-out, за да се върнат имен-ден автоматично при обратно към BG.
        // Само toggle-ът на самия превключвател е постоянно „изключено ръчно".
        await nd.setEnabled(false, userInitiated: false);
        await nd.cancelNotifications();
      }
      // keep == true (или затворен диалог) → остава включен.
    } else {
      // Връщаме се в България. Пускаме пак, ако не е изключван ръчно.
      final manualOff = await nd.isManuallyDisabled();
      final enabled = await nd.loadEnabled();
      if (!manualOff && !enabled) {
        await nd.setEnabled(true, userInitiated: false);
        await nd.scheduleNotifications(lang: widget.lang);
      }
    }
  }

  /// Диалог при напускане на BG. Връща true=запази, false=изключи, null=отказ.
  Future<bool?> _askKeepNameDays() async {
    final lang = widget.lang;
    const dTitle = {
      'en': 'Bulgarian name days?', 'nl': 'Bulgaarse naamdagen?',
      'uk': 'Болгарські іменини?', 'bg': 'Български имени дни?',
      'de': 'Bulgarische Namenstage?', 'fr': 'Fêtes des prénoms bulgares ?',
      'it': 'Onomastici bulgari?', 'el': 'Βουλγαρικές ονομαστικές εορτές;',
      'es': '¿Onomásticas búlgaras?', 'pt': 'Dias do nome búlgaros?',
      'ru': 'Болгарские именины?', 'tr': 'Bulgarca isim günleri?',
      'ja': 'ブルガリアの聖名祝日？',
    };
    const dBody = {
      'en': 'You changed country. Keep Bulgarian name days in the calendar?',
      'nl': 'Je hebt van land gewisseld. Bulgaarse naamdagen in de agenda houden?',
      'uk': 'Ви змінили країну. Залишити болгарські іменини в календарі?',
      'bg': 'Смени държавата. Да запазим ли българските имени дни в календара?',
      'de': 'Du hast das Land gewechselt. Bulgarische Namenstage im Kalender behalten?',
      'fr': 'Tu as changé de pays. Garder les fêtes des prénoms bulgares dans le calendrier ?',
      'it': 'Hai cambiato paese. Mantenere gli onomastici bulgari nel calendario?',
      'el': 'Άλλαξες χώρα. Να κρατήσουμε τις βουλγαρικές ονομαστικές εορτές στο ημερολόγιο;',
      'es': 'Cambiaste de país. ¿Mantener las onomásticas búlgaras en el calendario?',
      'pt': 'Mudaste de país. Manter os dias do nome búlgaros no calendário?',
      'ru': 'Вы сменили страну. Оставить болгарские именины в календаре?',
      'tr': 'Ülkeyi değiştirdin. Bulgarca isim günleri takvimde kalsın mı?',
      'ja': '国を変更しました。カレンダーにブルガリアの聖名祝日を残しますか？',
    };
    const dKeep = {
      'en': 'Keep', 'nl': 'Behouden', 'uk': 'Залишити', 'bg': 'Запази',
      'de': 'Behalten', 'fr': 'Garder', 'it': 'Mantieni', 'el': 'Διατήρηση',
      'es': 'Mantener', 'pt': 'Manter', 'ru': 'Оставить', 'tr': 'Kalsın',
      'ja': '残す',
    };
    const dDisable = {
      'en': 'Disable', 'nl': 'Uitschakelen', 'uk': 'Вимкнути', 'bg': 'Изключи',
      'de': 'Deaktivieren', 'fr': 'Désactiver', 'it': 'Disattiva',
      'el': 'Απενεργοποίηση', 'es': 'Desactivar', 'pt': 'Desativar',
      'ru': 'Отключить', 'tr': 'Kapat', 'ja': '無効にする',
    };
    String tr(Map<String, String> m) => m[lang] ?? m['en']!;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(dTitle)),
        content: Text(tr(dBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr(dDisable)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr(dKeep)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final theme = Theme.of(context);
    const title = {
      'en': 'Public holidays', 'nl': 'Feestdagen', 'uk': 'Офіційні свята', 'bg': 'Официални празници',
      'de': 'Gesetzliche Feiertage', 'fr': 'Jours fériés',
      'it': 'Festività ufficiali', 'el': 'Επίσημες αργίες',
      'es': 'Días festivos', 'pt': 'Feriados oficiais',
      'ru': 'Официальные праздники', 'tr': 'Resmi tatiller', 'ja': '祝日',
    };
    const subtitle = {
      'en': 'Holidays for your country in the calendar', 'nl': 'Feestdagen voor jouw land in de agenda', 'uk': 'Свята вашої країни в календарі',
      'bg': 'Празниците на твоята държава в календара',
      'de': 'Feiertage deines Landes im Kalender',
      'fr': 'Les jours fériés de ton pays dans le calendrier',
      'it': 'Le festività del tuo paese nel calendario',
      'el': 'Οι αργίες της χώρας σου στο ημερολόγιο',
      'es': 'Los festivos de tu país en el calendario',
      'pt': 'Os feriados do teu país no calendário',
      'ru': 'Праздники твоей страны в календаре',
      'tr': 'Ülkenin tatilleri takvimde', 'ja': 'カレンダーにお住まいの国の祝日を表示',
    };
    const countryLabel = {
      'en': 'Country', 'nl': 'Land', 'uk': 'Країна', 'bg': 'Държава', 'de': 'Land', 'fr': 'Pays',
      'it': 'Paese', 'el': 'Χώρα', 'es': 'País', 'pt': 'País',
      'ru': 'Страна', 'tr': 'Ülke', 'ja': '国',
    };
    String tr(Map<String, String> m) => m[lang] ?? m['en']!;

    // Ако текущата държава не е в списъка, добавяме я временно най-отгоре.
    final items = List<(String, String)>.from(_holidayCountries);
    if (!items.any((c) => c.$1 == _holidaysCountry)) {
      items.insert(0, (_holidaysCountry, _holidaysCountry));
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(HolidaysService.colorValue)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.flag_rounded,
                  color: Color(HolidaysService.colorValue)),
            ),
            title: Text(tr(title)),
            subtitle: Text(
              tr(subtitle),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            value: _holidaysEnabled,
            onChanged: (value) async {
              setState(() => _holidaysEnabled = value);
              await HolidaysService().setEnabled(value);
              if (value) await HolidaysService().loadForCurrentYears();
            },
          ),
          if (_holidaysEnabled) ...[
            const Divider(height: 0),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  Text(
                    tr(countryLabel),
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _holidaysCountry,
                      isExpanded: true,
                      alignment: Alignment.centerRight,
                      underline: const SizedBox.shrink(),
                      items: items
                          .map((c) => DropdownMenuItem(
                                value: c.$1,
                                child: Text(c.$2,
                                    textAlign: TextAlign.right,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (code) async {
                        if (code == null) return;
                        final previous = _holidaysCountry;
                        setState(() => _holidaysCountry = code);
                        await HolidaysService().setCountry(code);
                        await HolidaysService().loadForCurrentYears();
                        // loadForCurrentYears bump-ва revision → календарът се обновява.
                        // Имен-ден (само български dataset) следва държавата.
                        await _handleNameDaysForCountryChange(previous, code);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
