import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/task.dart';
import '../../models/category.dart';
import '../../utils/localization.dart';
import '../../utils/file_saver.dart';
import '../../utils/gsi_button.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../auth/login_screen.dart';
import 'statistics_screen.dart';
import 'ai_settings_screen.dart';
import 'delete_account_flow.dart';
import '../../services/task_view_preference.dart';
import '../home/home_screen.dart';
import '../../services/google_calendar_service.dart';
import '../../services/calendar_import_service.dart';
import '../../services/ios_calendar_service.dart';
import '../../services/morning_briefing_service.dart';
import '../../services/name_days_service.dart';
import '../../services/holidays_service.dart';
import '../../services/pro_service.dart';
import '../paywall/paywall_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  final _viewPreference = TaskViewPreference();
  bool _isSyncing = false;
  bool _isCalendarConnected = false;
  final _calendarService = GoogleCalendarService();
  final _iosCalendarService = IosCalendarService();
  bool _isIosCalendarGranted = false;
  final _morningBriefingService = MorningBriefingService();
  bool _isMorningBriefingEnabled = false;
  int _briefingHour = 8;
  int _briefingMinute = 0;
  bool _nameDaysEnabled = false;
  bool _holidaysEnabled = false;
  String _holidaysCountry = 'BG';
  StreamSubscription<dynamic>? _authSub;

  @override
  void initState() {
    super.initState();
    _loadBriefingTime();
    _loadMorningBriefingSetting();
    _loadNameDaysSetting();
    _loadHolidaysSetting();
    _checkCalendarConnection();
    if (!kIsWeb && Platform.isIOS) _checkIosCalendarPermission();
    // Този екран живее в IndexedStack и се build-ва още при стартиране,
    // ПРЕДИ Firebase Auth да възстанови запазената сесия (асинхронно).
    // Слушаме промените, за да се пребилдне акаунт секцията щом сесията
    // се възстанови — иначе изглежда сякаш потребителят е излязъл.
    _authSub = _authService.authStateChanges.listen((_) {
      if (mounted) setState(() {});
    });
    // Web: входът в Google Calendar идва асинхронно от GIS бутона → обновяваме
    // UI-я щом връзката се промени.
    _calendarService.connectionNotifier.addListener(_onCalendarConnChanged);
    // Web: показва бутона „Разреши достъп" щом влезем, но още без календарен достъп.
    _calendarService.webAuthPending.addListener(_onCalendarConnChanged);
    // Web: гарантираме, че GIS клиентът е инициализиран, за да се рендира
    // официалният бутон (иначе стои на „Getting ready").
    if (kIsWeb) {
      _calendarService.ensureInitialized().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _onCalendarConnChanged() {
    if (mounted) {
      setState(() => _isCalendarConnected = _calendarService.isConnected);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _calendarService.connectionNotifier.removeListener(_onCalendarConnChanged);
    _calendarService.webAuthPending.removeListener(_onCalendarConnChanged);
    super.dispose();
  }

  Future<void> _loadHolidaysSetting() async {
    final enabled = await HolidaysService().loadEnabled();
    if (!mounted) return;
    setState(() {
      _holidaysEnabled = enabled;
      _holidaysCountry = HolidaysService().country;
    });
  }

  Future<void> _loadNameDaysSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nameDaysEnabled = prefs.getBool('name_days_enabled') ?? false;
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

  /// Секция „България" в Настройки. Празна извън BG контекст.
  /// Засега съдържа toggle „Именни дни" (premium).
  List<Widget> _buildBulgariaSection(BuildContext context) {
    if (!_isBgContext) return const [];
    final theme = Theme.of(context);
    final lang = LanguageScope.of(context).locale.languageCode;

    const sectionTitle = {
      'en': 'Bulgaria', 'bg': 'България', 'de': 'Bulgarien', 'fr': 'Bulgarie',
      'it': 'Bulgaria', 'el': 'Βουλγαρία', 'es': 'Bulgaria', 'pt': 'Bulgária',
      'ru': 'Болгария', 'tr': 'Bulgaristan', 'ja': 'ブルガリア',
    };
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

    String tr(Map<String, String> m) => m[lang] ?? m['en']!;
    final isPro = ProService().isPro;

    return [
      const SizedBox(height: 24),
      Text(
        tr(sectionTitle),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Card(
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
    ];
  }

  // Държави за официални празници (флаг + неутрално английско име).
  // Само поддържани от Nager.Date. Auto-detect от locale е по подразбиране.
  // Бел.: Индия (IN) не се поддържа от Nager, затова липсва (макар да имаме hi).
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

  Widget _buildHolidaysTile(BuildContext context, String lang) {
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

  Future<void> _loadMorningBriefingSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isMorningBriefingEnabled = prefs.getBool('morning_briefing_enabled') ?? false;
    });
  }

  Future<void> _saveMorningBriefingSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('morning_briefing_enabled', value);
  }

  Future<void> _checkCalendarConnection() async {
    // isConnected reflects in-memory state (set by tryReconnect at startup).
    // Fallback to prefs in case tryReconnect() is still in progress (race condition).
    bool connected = _calendarService.isConnected;
    if (!connected) {
      final prefs = await SharedPreferences.getInstance();
      connected = prefs.getBool('google_calendar_connected') ?? false;
    }
    if (mounted) setState(() { _isCalendarConnected = connected; });
  }

  Future<void> _checkIosCalendarPermission() async {
    final granted = await _iosCalendarService.hasPermission();
    if (mounted) setState(() => _isIosCalendarGranted = granted);
  }

  // Списък с предефинирани цветове за color picker
  static const List<Color> _categoryColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  /// Показва диалог за управление на категориите
  void _showCategoryManagementDialog() {
    final languageController = LanguageScope.of(context);
    final langCode = languageController.locale.languageCode;
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final categoryBox = Hive.box<Category>('categories');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (innerContext, setSheetState) {
            final categories = categoryBox.values.toList();

            return Container(
              height: MediaQuery.of(innerContext).size.height * 0.7,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.category_rounded,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          t.categories,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(innerContext),
                          icon: Icon(
                            Icons.close_rounded,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Category list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final catColor = Color(cat.colorValue);
                        final localizedName = cat.isDefault
                            ? {
                                'work': t.catWork,
                                'personal': t.catPersonal,
                                'shopping': t.catShopping,
                                'birthday': t.catBirthdays,
                                'meeting': t.catMeeting,
                                'workout': t.catWorkout,
                                'payment': t.catPayment,
                                'travel': t.catTravel,
                                'gift': t.catGift,
                              }[cat.id] ?? cat.name
                            : cat.name;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.folder_rounded,
                                color: catColor,
                              ),
                            ),
                            title: Text(
                              localizedName,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: cat.isDefault
                                ? Text(
                                    t.defaultCategory,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Edit button
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    color: theme.colorScheme.primary,
                                  ),
                                  onPressed: () {
                                    _showEditCategoryDialog(
                                      cat,
                                      t,
                                      theme,
                                      () {
                                        setSheetState(() {});
                                        setState(() {});
                                      },
                                    );
                                  },
                                ),
                                // Delete button (само за не-default)
                                if (!cat.isDefault)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: innerContext,
                                        builder: (ctx) => AlertDialog(
                                          title: Text(t.deletion),
                                          content: Text(t.deleteCategoryMessage(cat.name)),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: Text(t.cancel),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.redAccent,
                                              ),
                                              child: Text(t.delete),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await categoryBox.delete(cat.id);
                                        setSheetState(() {});
                                        setState(() {});
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Add category button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showAddCategoryDialog(t, theme, () {
                            setSheetState(() {});
                            setState(() {});
                          });
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: Text(t.addCategory),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Показва диалог за добавяне на нова категория
  void _showAddCategoryDialog( AppText t, ThemeData theme, VoidCallback onComplete) {
    final controller = TextEditingController();
    Color selectedColor = Colors.blue;
    final categoryBox = Hive.box<Category>('categories');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(t.newCategory),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: t.name,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t.color,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categoryColors.map((color) {
                          final isSelected = selectedColor.value == color.value;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedColor = color;
                              });
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(t.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      final id = DateTime.now().millisecondsSinceEpoch.toString();
                      final newCat = Category(
                        id: id,
                        name: name,
                        colorValue: selectedColor.value,
                        isDefault: false,
                      );
                      categoryBox.put(id, newCat);
                      Navigator.pop(ctx);
                      onComplete();
                    }
                  },
                  child: Text(t.add),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Показва диалог за редактиране на категория
  void _showEditCategoryDialog(Category cat, AppText t, ThemeData theme, VoidCallback onComplete) {
    final controller = TextEditingController(text: cat.name);
    Color selectedColor = Color(cat.colorValue);
    final categoryBox = Hive.box<Category>('categories');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(t.editCategory),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: controller,
                        enabled: !cat.isDefault, // Default категориите не могат да се преименуват
                        decoration: InputDecoration(
                          labelText: t.name,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          helperText: cat.isDefault
                              ? (t.defaultCategoryNameCannotChange)
                              : null,
                          helperMaxLines: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t.color,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categoryColors.map((color) {
                          final isSelected = selectedColor.value == color.value;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedColor = color;
                              });
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(t.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      // За default категории, запазваме оригиналното име
                      final updatedCat = Category(
                        id: cat.id,
                        name: cat.isDefault ? cat.name : name,
                        colorValue: selectedColor.value,
                        isDefault: cat.isDefault,
                      );
                      categoryBox.put(cat.id, updatedCat);
                      Navigator.pop(ctx);
                      onComplete();
                    }
                  },
                  child: Text(t.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Показва диалог за избор на език
  void _showLanguageDialog(BuildContext context, LanguageController languageController, Locale currentLocale) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.language_rounded,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      AppText.of(context).language,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Списък с езици - SCROLLABLE
              Expanded(
                child: ListView.builder(
                  itemCount: SupportedLocales.all.length,
                  itemBuilder: (context, index) {
                    final locale = SupportedLocales.all[index];
                    final isSelected = currentLocale.languageCode == locale.languageCode;
                    return ListTile(
                      leading: Text(
                        SupportedLocales.flags[locale.languageCode] ?? '🌐',
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        SupportedLocales.names[locale.languageCode] ?? locale.languageCode,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                          : null,
                      onTap: () {
                        languageController.setLocale(locale);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Load saved briefing time
  Future<void> _loadBriefingTime() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _briefingHour = prefs.getInt('briefing_hour') ?? 8;
      _briefingMinute = prefs.getInt('briefing_minute') ?? 0;
    });
  }

  // Format time for display
  String _formatTime(int hour, int minute) {
    final hourStr = hour.toString().padLeft(2, '0');
    
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hourStr:$minuteStr';
  }

  // Select briefing time
  Future<void> _selectBriefingTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _briefingHour, minute: _briefingMinute),
    );
    
    if (picked != null) {
      setState(() {
        _briefingHour = picked.hour;
        _briefingMinute = picked.minute;
      });
      
      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('briefing_hour', _briefingHour);
      await prefs.setInt('briefing_minute', _briefingMinute);
      
      // Reschedule briefing
      await _morningBriefingService.scheduleDailyBriefing(
        hour: _briefingHour,
        minute: _briefingMinute,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppText.of(context).briefingTimeSetTo(_formatTime(_briefingHour, _briefingMinute))),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _exportData(BuildContext context) async {
    final t = AppText.of(context);
    final languageController = LanguageScope.of(context);
    final langCode = languageController.locale.languageCode;

    try {
      final taskBox = Hive.box<Task>('tasks');
      final categoryBox = Hive.box<Category>('categories');

      final data = {
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0',
        'categories': categoryBox.values.map((c) => {
          'id': c.id,
          'name': c.name,
          'colorValue': c.colorValue,
          'isDefault': c.isDefault,
        }).toList(),
        'tasks': taskBox.values.map((t) => {
          'title': t.title,
          'dueDate': t.dueDate.toIso8601String(),
          'categoryId': t.categoryId,
          'priority': t.priority,
          'isCompleted': t.isCompleted,
          'recurrence': t.recurrence,
          'reminder': t.reminder,
          'subtasks': t.subtasks,
          'notes': t.notes,
          'completedAt': t.completedAt?.toIso8601String(),
          // ВАЖНО: пази връзката към Google Calendar, иначе при възстановяване
          // авто-импортът ще ги мисли за нови → масови дубли.
          'googleCalendarEventId': t.googleCalendarEventId,
          'importedFromCalendar': t.importedFromCalendar,
          'template': t.template,
        }).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      // Web: dart:io File / getTemporaryDirectory не съществуват → сваляме
      // файла директно през браузъра (Blob download).
      if (kIsWeb) {
        final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        await saveTextFile('task_manager_backup_$ts.json', jsonString);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.tasksBackup)),
          );
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'task_manager_backup_$timestamp.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      // iOS popover anchor: share_plus иска non-zero sharePositionOrigin,
      // иначе хвърля PlatformException на iPad/iOS. На Android се игнорира.
      final box = context.findRenderObject() as RenderBox?;
      final size = MediaQuery.of(context).size;
      final origin = (box != null && box.hasSize)
          ? box.localToGlobal(Offset.zero) & box.size
          : Rect.fromCenter(
              center: Offset(size.width / 2, size.height / 2),
              width: 1,
              height: 1,
            );

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: t.backupSubject,
        text: t.tasksBackup,
        sharePositionOrigin: origin,
      );

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${t.exportError}: $e',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _importData(BuildContext context) async {
    final t = AppText.of(context);
    final languageController = LanguageScope.of(context);
    final langCode = languageController.locale.languageCode;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.single.path;
      if (filePath == null) return;

      final file = File(filePath);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final taskBox = Hive.box<Task>('tasks');
      final categoryBox = Hive.box<Category>('categories');

      if (context.mounted) {
        final tasksCount = (data['tasks'] as List).length;
        final categoriesCount = (data['categories'] as List).length;

        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(t.confirmation),
            content: Text(t.importConfirmMessage(tasksCount, categoriesCount)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: Text(t.replace),
              ),
            ],
          ),
        );

        if (confirm != true) return;
      }

      await taskBox.clear();
      await categoryBox.clear();

      final categories = data['categories'] as List<dynamic>;
      for (final c in categories) {
        final category = Category(
          id: c['id'] as String,
          name: c['name'] as String,
          colorValue: c['colorValue'] as int,
          isDefault: c['isDefault'] as bool? ?? false,
        );
        await categoryBox.put(category.id, category);
      }

      final tasks = data['tasks'] as List<dynamic>;
      for (final taskData in tasks) {
        final task = Task(
          title: taskData['title'] as String,
          dueDate: DateTime.parse(taskData['dueDate'] as String),
          categoryId: taskData['categoryId'] as String,
          priority: taskData['priority'] as int? ?? 1,
          recurrence: taskData['recurrence'] as String?,
          reminder: taskData['reminder'] as String?,
          subtasks: (taskData['subtasks'] as List<dynamic>?)?.cast<String>(),
          notes: taskData['notes'] as String?,
          completedAt: taskData['completedAt'] != null
              ? DateTime.parse(taskData['completedAt'] as String)
              : null,
          googleCalendarEventId: taskData['googleCalendarEventId'] as String?,
          importedFromCalendar: taskData['importedFromCalendar'] as bool?,
          template: taskData['template'] as String?,
        );
        task.isCompleted = taskData['isCompleted'] as bool? ?? false;
        await taskBox.add(task);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.importSuccessMessage(tasks.length, categories.length)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${t.importError}: $e',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _openLogin() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _logout() async {
    final t = AppText.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.logout),
        content: Text(
          t.logoutConfirm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: Text(t.logout),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// ФАЗА 2Б: единен ръчен синхрон (merge с облака). Замества старите
  /// „Качване"/„Сваляне" огледални бутони, които триеха данни. Безопасен —
  /// само слива, нищо не се губи.
  Future<void> _syncNow() async {
    final t = AppText.of(context);
    setState(() => _isSyncing = true);
    final result = await SyncService().mergeWithCloud();
    if (!mounted) return;
    setState(() => _isSyncing = false);
    if (result.error == 'in-progress') return; // тих — вече тече синхрон
    final String msg;
    final bool ok = result.success;
    if (ok) {
      msg = t.syncSuccess;
    } else if (result.error == 'not-signed-in') {
      msg = t.signInToSync; // приятелско — не „грешка"
    } else {
      msg = '${t.error}: ${result.error}';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? Colors.green : Colors.orange,
      ),
    );
  }

  /// Авторитетно нулиране: трие облака + локалното. После потребителят
  /// импортира чистия бекъп (напр. iPhone Export Data JSON).
  Future<void> _resetSync() async {
    final t = AppText.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.resetSync),
        content: Text(t.resetSyncConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isSyncing = true);
    final n = await SyncService().wipeAllTasks();
    if (!mounted) return;
    setState(() => _isSyncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.resetSyncDone(n)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// ФАЗА 2Б/3: ръчен двупосочен Google Calendar синхрон (импорт + експорт +
  /// облачен merge). Безобиден — само слива; изтриване само през tombstone.
  Future<void> _calendarSyncNow() async {
    final t = AppText.of(context);
    setState(() => _isSyncing = true);
    try {
      final taskBox = Hive.box<Task>('tasks');
      final categoryBox = Hive.box<Category>('categories');

      // 1) Импорт от Google (нови събития/задачи).
      await CalendarImportService.runImport(
        taskBox, categoryBox, t,
        interactive: true,
      );
      await CalendarImportService.markSynced();

      // 2) Експорт/обновяване на локалните задачи към Google. Със същото ID →
      //    events.update (без дубли); insert само ако още няма googleEventId.
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      for (final task in taskBox.values.toList()) {
        if (task.isCompleted || task.isArchived) continue;
        if (!task.dueDate.isAfter(today.subtract(const Duration(days: 1)))) continue;
        // Нативните рождени дни се управляват само в приложението → не ги
        // качваме като събития (иначе плодим „рождени дни" в Google Calendar).
        if (task.categoryId == 'birthday' || task.template == 'birthday') continue;
        if (task.googleCalendarEventId != null) {
          await _calendarService.updateCalendarEvent(
              task.googleCalendarEventId!, task, interactive: true);
        } else if (task.importedFromCalendar != true) {
          // Само ИСТИНСКИ твои задачи се качват като нови събития. Календарни
          // задачи без eventId (загубен линк) НЕ се пресъздават → без дубли в
          // Google Calendar; импортът по-горе вече ги е ре-свързал, ако още ги има.
          final eventId =
              await _calendarService.addTaskToCalendar(task, interactive: true);
          if (eventId != null) {
            task.googleCalendarEventId = eventId;
            await task.save();
          }
        }
      }

      // 3) Облачен merge (Firebase).
      await SyncService().mergeWithCloud();
    } catch (e) {
      debugPrint('Calendar sync error: $e');
    }
    if (!mounted) return;
    setState(() => _isSyncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.syncSuccess)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final languageController = LanguageScope.of(context);
    final themeController = ThemeScope.of(context);
    final langCode = languageController.locale.languageCode;

    final currentLocale = languageController.locale;
    final currentMode = themeController.mode;
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        children: [
          // Език - НАЙ-ОТГОРЕ
          Text(
            t.language,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  SupportedLocales.flags[currentLocale.languageCode] ?? '🌐',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              title: Text(SupportedLocales.names[currentLocale.languageCode] ?? 'English'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLanguageDialog(context, languageController, currentLocale),
            ),
          ),

          const SizedBox(height: 16),

          // Статистики секция
          Text(
            t.activity,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Colors.purple,
                ),
              ),
              title: Text(t.statistics),
              subtitle: Text(
                t.viewProgress,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StatisticsScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Категории секция
          Text(
            t.categories,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.category_rounded,
                  color: Colors.teal,
                ),
              ),
              title: Text(t.manageCategories),
              subtitle: Text(
                t.editAddDeleteCategories,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showCategoryManagementDialog,
            ),
          ),

          const SizedBox(height: 16),

          // AI секция
          Text(
            t.aiSettings,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.purple,
                ),
              ),
              title: Text(t.aiSettings),
              subtitle: Text(
                t.aiSettingsSubtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Акаунт секция
          Text(
            t.account,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: user != null
                ? ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        user.email?.substring(0, 1).toUpperCase() ?? '?',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(user.email ?? ''),
                    subtitle: Text(
                      t.signedIn,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: _logout,
                      child: Text(
                        t.logout,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  )
                : ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.person_outline,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    title: Text(t.login),
                    subtitle: Text(
                      t.signInToSync,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openLogin,
                  ),
          ),

          // Синхронизация (само ако е логнат)
          if (user != null) ...[
            const SizedBox(height: 16),
            Text(
              t.cloudSync,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isSyncing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_sync_outlined,
                              color: Colors.blue),
                    ),
                    title: Text(t.syncNow),
                    subtitle: Text(
                      // Сливането е автоматично и невидимо; този бутон само форсира.
                      t.autoSyncDesc,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _isSyncing ? null : _syncNow,
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.restart_alt, color: Colors.red),
                    ),
                    title: Text(t.resetSync),
                    subtitle: Text(t.resetSyncDesc,
                        style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _isSyncing ? null : _resetSync,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          // Google Calendar
          // Google Calendar
          Text(
            t.googleCalendar,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isCalendarConnected ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isCalendarConnected ? Icons.event_available : Icons.event_busy,
                      color: _isCalendarConnected ? Colors.green : Colors.grey,
                    ),
                  ),
                  title: Text(_isCalendarConnected ? t.calendarConnected : t.calendarNotConnected,
                    style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                    _isCalendarConnected ? t.calendarSyncEnabled : t.connectForSync,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  trailing: (kIsWeb && !_isCalendarConnected)
                      // Web: authenticate() не работи → официален GIS бутон.
                      // Резултатът идва през connectionNotifier (listener в
                      // initState обновява _isCalendarConnected).
                      ? SizedBox(width: 200, child: googleSignInButton())
                      : TextButton(
                          onPressed: () async {
                            if (_isCalendarConnected) {
                              await _calendarService.disconnect();
                              setState(() => _isCalendarConnected = false);
                            } else {
                              final success = await _calendarService.connect();
                              setState(() => _isCalendarConnected = success);
                              if (!success && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(t.connectionFailed)),
                                );
                              }
                            }
                          },
                          child: Text(_isCalendarConnected ? t.disconnect : t.connect),
                        ),
                ),
                // Web: влязъл, но без календарен достъп → ръчен бутон (директен
                // клик, за да не блокира браузърът OAuth popup-а).
                if (kIsWeb &&
                    !_isCalendarConnected &&
                    _calendarService.webAuthPending.value) ...[
                  const Divider(height: 0),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.lock_open, color: Colors.green),
                    ),
                    title: Text(t.allowCalendarAccess),
                    subtitle: Text(t.allowCalendarAccessDesc,
                        style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final ok =
                          await _calendarService.authorizeCalendarOnWeb();
                      if (!mounted) return;
                      setState(() => _isCalendarConnected = ok);
                      if (!ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t.connectionFailed)),
                        );
                      }
                    },
                  ),
                ],
                if (_isCalendarConnected) ...[
                  const Divider(height: 0),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isSyncing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync, color: Colors.blue),
                    ),
                    // ФАЗА 2Б: един безобиден ръчен синхрон. Импорт/експорт се
                    // случват автоматично, двупосочно — потребителят не избира
                    // посока. Старите ръчни „Експорт"/„Импорт"/bulk-изтриване
                    // бутони са премахнати (бяха източник на загуба на данни).
                    title: Text(t.syncNow),
                    subtitle: Text(t.autoSyncDesc, style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _isSyncing ? null : _calendarSyncNow,
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.cleaning_services, color: Colors.orange),
                    ),
                    title: Text(t.removeDuplicates),
                    subtitle: Text(t.removeDuplicatesDesc, style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('${t.removeDuplicates}?'),
                          content: Text(t.removeDuplicatesDesc),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(t.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(t.delete, style: const TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${t.removeDuplicates}…')),
                        );
                      }
                      final removed = await _calendarService.removeDuplicateEvents(interactive: true);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t.removedDuplicates(removed))),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          // iOS Calendar
          if (!kIsWeb && Platform.isIOS) ...[
            const SizedBox(height: 16),
            Text(
              'Apple Calendar',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isIosCalendarGranted
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.calendar_month,
                        color: _isIosCalendarGranted ? Colors.green : Colors.grey,
                      ),
                    ),
                    title: Text(_isIosCalendarGranted ? t.appleCalendarConnected : 'Apple Calendar'),
                    subtitle: Text(
                      _isIosCalendarGranted
                          ? t.appleCalendarConnectedDesc
                          : t.appleCalendarPermission,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        if (_isIosCalendarGranted) {
                          setState(() => _isIosCalendarGranted = false);
                        } else {
                          final granted = await _iosCalendarService.requestPermission();
                          setState(() => _isIosCalendarGranted = granted);
                          if (!granted && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(t.calendarAccessDenied)),
                            );
                          }
                        }
                      },
                      child: Text(_isIosCalendarGranted ? t.disconnect : t.connect),
                    ),
                  ),
                  if (_isIosCalendarGranted) ...[
                    const Divider(height: 0),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.upload, color: Colors.blue),
                      ),
                      title: Text(t.exportTasks),
                      subtitle: Text(
                        t.exportTasksDesc,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final taskBox = Hive.box<Task>('tasks');
                        final tasks = taskBox.values
                            .where((t) => !t.isCompleted && !t.isArchived)
                            .toList();
                        final count = await _iosCalendarService.exportAllTasks(tasks);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t.tasksAddedToAppleCalendar(count))),
                          );
                        }
                      },
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.event_busy, color: Colors.red),
                      ),
                      title: Text(t.deleteExportedTasks),
                      subtitle: Text(t.deleteExportedDesc, style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text('${t.deleteExportedTasks}?'),
                            content: Text(t.deleteExportedConfirm),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(t.cancel),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(t.delete, style: const TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        final taskBox = Hive.box<Task>('tasks');
                        final removed = await _iosCalendarService
                            .deleteAllExportedTasks(taskBox.values.toList());
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t.deletedExportedTasks(removed))),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
          // Тема
          Text(
            t.theme,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                RadioListTile<int>(
                  value: 0,
                  groupValue: themeController.isAmoled ? 3 : (currentMode == ThemeMode.system ? 0 : (currentMode == ThemeMode.light ? 1 : 2)),
                  title: Text(t.systemTheme),
                  onChanged: (value) {
                    themeController.setMode(ThemeMode.system);
                  },
                ),
                const Divider(height: 0),
                RadioListTile<int>(
                  value: 1,
                  groupValue: themeController.isAmoled ? 3 : (currentMode == ThemeMode.system ? 0 : (currentMode == ThemeMode.light ? 1 : 2)),
                  title: Text(t.lightTheme),
                  onChanged: (value) {
                    themeController.setMode(ThemeMode.light);
                  },
                ),
                const Divider(height: 0),
                RadioListTile<int>(
                  value: 2,
                  groupValue: themeController.isAmoled ? 3 : (currentMode == ThemeMode.system ? 0 : (currentMode == ThemeMode.light ? 1 : 2)),
                  title: Text(t.darkTheme),
                  onChanged: (value) {
                    themeController.setMode(ThemeMode.dark);
                  },
                ),
                const Divider(height: 0),
                RadioListTile<int>(
                  value: 3,
                  groupValue: themeController.isAmoled ? 3 : (currentMode == ThemeMode.system ? 0 : (currentMode == ThemeMode.light ? 1 : 2)),
                  title: Text(t.amoledTheme),
                  subtitle: Text(
                    'OLED',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  onChanged: (value) {
                    themeController.setAmoled(true);
                  },
                ),
              ],
            ),
          ),

          

          const SizedBox(height: 16),


          // Morning Briefing
          Text(
            t.morningBriefing,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.wb_sunny_rounded, color: Colors.orange),
              ),
              title: Text(t.morningBriefing),
              subtitle: Text(t.dailyTaskSummaryAt(_formatTime(_briefingHour, _briefingMinute))),
              value: _isMorningBriefingEnabled,
              onChanged: (value) async {
                setState(() => _isMorningBriefingEnabled = value);
                await _saveMorningBriefingSetting(value);
                if (value) {
                  await _morningBriefingService.scheduleDailyBriefing(
                    hour: _briefingHour,
                    minute: _briefingMinute,
                  );
                } else {
                  await _morningBriefingService.cancelDailyBriefing();
                }
              },
            ),
          ),
          // Time Picker (only show if briefing enabled)
          if (_isMorningBriefingEnabled) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.access_time, color: Colors.blue),
                ),
                title: Text(t.briefingTime),
                subtitle: Text(_formatTime(_briefingHour, _briefingMinute)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectBriefingTime,
              ),
            ),
          ],

          // Официални празници — достъпно за всички държави (не само BG).
          const SizedBox(height: 16),
          _buildHolidaysTile(
              context, LanguageScope.of(context).locale.languageCode),

          // Раздел „България" (именни дни) — само при BG език/локация.
          ..._buildBulgariaSection(context),

          const SizedBox(height: 16),
          // Backup / Restore
          Text(
            t.localData,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.upload_rounded,
                      color: Colors.green,
                    ),
                  ),
                  title: Text(t.exportData),
                  subtitle: Text(
                    t.shareBackup,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportData(context),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.download_rounded,
                      color: Colors.teal,
                    ),
                  ),
                  title: Text(t.importData),
                  subtitle: Text(
                    t.restoreFromJson,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _importData(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // App info
          Center(
            child: Text(
              'Taskify v1.0',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),

          // Delete Account (само ако е логнат)
          if (user != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                t.account.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: Text(
                  t.deleteAccount,
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  t.deleteAccountSubtitle,
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () => DeleteAccountFlow.start(context),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }
}



