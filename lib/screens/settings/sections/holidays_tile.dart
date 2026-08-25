import 'package:flutter/material.dart';

import '../../../services/holidays_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final theme = Theme.of(context);
    const title = {
      'en': 'Public holidays', 'bg': 'Официални празници',
      'de': 'Gesetzliche Feiertage', 'fr': 'Jours fériés',
      'it': 'Festività ufficiali', 'el': 'Επίσημες αργίες',
      'es': 'Días festivos', 'pt': 'Feriados oficiais',
      'ru': 'Официальные праздники', 'tr': 'Resmi tatiller', 'ja': '祝日',
    };
    const subtitle = {
      'en': 'Holidays for your country in the calendar',
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
      'en': 'Country', 'bg': 'Държава', 'de': 'Land', 'fr': 'Pays',
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
                        setState(() => _holidaysCountry = code);
                        await HolidaysService().setCountry(code);
                        await HolidaysService().loadForCurrentYears();
                        // loadForCurrentYears bump-ва revision → календарът се обновява.
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
