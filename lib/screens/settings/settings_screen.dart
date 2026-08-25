import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/task.dart';
import '../../models/category.dart';
import '../../utils/localization.dart';
import '../../utils/category_colors.dart';
import '../../utils/file_saver.dart';
import '../../utils/gsi_button.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../services/sync_service.dart';
import 'statistics_screen.dart';
import 'ai_settings_screen.dart';
import '../../services/task_view_preference.dart';
import '../home/home_screen.dart';
import '../../services/google_calendar_service.dart';
import '../../services/calendar_import_service.dart';
import '../../services/ios_calendar_service.dart';
import '../../services/morning_briefing_service.dart';
import '../../services/name_days_service.dart';
import '../../services/contact_name_index.dart';
import '../../services/pro_service.dart';
import '../paywall/paywall_screen.dart';
import 'sections/settings_group.dart';
import 'sections/go_pro_card.dart';
import 'sections/profile_card.dart';
import 'sections/appearance_section.dart';
import 'sections/about_section.dart';
import 'sections/holidays_tile.dart';
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
  // Единен избор на календарен източник: 'none' | 'google' | 'apple'.
  // Двата източника са взаимно изключващи се (иначе при външна GCal↔Apple
  // връзка всяко събитие се появява двойно). Виж IosCalendarService.
  String _calMode = 'none';
  final _morningBriefingService = MorningBriefingService();
  bool _isMorningBriefingEnabled = false;
  int _briefingHour = 8;
  int _briefingMinute = 0;
  bool _nameDaysEnabled = false;
  bool _contactsNameDayEnabled = false;
  String? _profilePhotoPath; // локална снимка на профила (Пакет 2)
  StreamSubscription<dynamic>? _authSub;

  @override
  void initState() {
    super.initState();
    _loadBriefingTime();
    _loadMorningBriefingSetting();
    _loadNameDaysSetting();
    _loadProfilePhoto();
    _checkCalendarConnection();
    if (!kIsWeb && Platform.isIOS) _checkIosCalendarPermission();
    // Този екран живее в IndexedStack и се build-ва още при стартиране,
    // ПРЕДИ Firebase Auth да възстанови запазената сесия (асинхронно).
    // Слушаме промените, за да се пребилдне акаунт секцията щом сесията
    // се възстанови — иначе изглежда сякаш потребителят е излязъл.
    _authSub = _authService.authStateChanges.listen((_) {
      if (mounted) setState(() {});
    });
    // Обновяваме „Стани Pro" картата (показва се само при !isPro) веднага щом
    // покупка/restore/RevenueCat промени статуса.
    ProService().addListener(_onProChanged);
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

  void _onProChanged() {
    if (mounted) setState(() {});
  }

  void _onCalendarConnChanged() {
    if (mounted) {
      setState(() {
        _isCalendarConnected = _calendarService.isConnected;
        // Web GIS вход → отразяваме режима като Google.
        if (_isCalendarConnected) _calMode = 'google';
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    ProService().removeListener(_onProChanged);
    _calendarService.connectionNotifier.removeListener(_onCalendarConnChanged);
    _calendarService.webAuthPending.removeListener(_onCalendarConnChanged);
    super.dispose();
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

  /// Възстановяване на покупки (RevenueCat). Задължително за iOS (Apple) +
  /// помага на платци, сменили устройство.
  Future<void> _restorePurchases() async {
    final lang = LanguageScope.of(context).locale.languageCode;
    String tr(Map<String, String> m) => m[lang] ?? m['en']!;

    const restoring = {
      'en': 'Restoring…', 'bg': 'Възстановяване…', 'de': 'Wird wiederhergestellt…',
      'fr': 'Restauration…', 'it': 'Ripristino…', 'el': 'Επαναφορά…',
      'es': 'Restaurando…', 'pt': 'Restaurando…', 'ru': 'Восстановление…',
      'tr': 'Geri yükleniyor…', 'ja': '復元中…',
    };
    const success = {
      'en': 'Purchases restored', 'bg': 'Покупките са възстановени',
      'de': 'Käufe wiederhergestellt', 'fr': 'Achats restaurés',
      'it': 'Acquisti ripristinati', 'el': 'Οι αγορές επαναφέρθηκαν',
      'es': 'Compras restauradas', 'pt': 'Compras restauradas',
      'ru': 'Покупки восстановлены', 'tr': 'Satın alımlar geri yüklendi',
      'ja': '購入を復元しました',
    };
    const none = {
      'en': 'No purchases to restore', 'bg': 'Няма покупки за възстановяване',
      'de': 'Keine Käufe zum Wiederherstellen',
      'fr': 'Aucun achat à restaurer', 'it': 'Nessun acquisto da ripristinare',
      'el': 'Δεν υπάρχουν αγορές για επαναφορά',
      'es': 'No hay compras para restaurar',
      'pt': 'Nenhuma compra para restaurar',
      'ru': 'Нет покупок для восстановления',
      'tr': 'Geri yüklenecek satın alım yok', 'ja': '復元する購入はありません',
    };

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(tr(restoring)), duration: const Duration(seconds: 1)),
    );
    final ok = await ProService().restorePurchases();
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? tr(success) : tr(none))),
    );
    setState(() {});
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
    return [
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
    ];
  }

  // Държави за официални празници (флаг + неутрално английско име).
  // Само поддържани от Nager.Date. Auto-detect от locale е по подразбиране.
  // Бел.: Индия (IN) не се поддържа от Nager, затова липсва (макар да имаме hi).
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
    // Извеждаме режима: записаният избор печели; за стари потребители без
    // запис, но със свързан Google → google.
    final mode = await IosCalendarService.currentMode();
    final resolved = (mode == 'none' && connected) ? 'google' : mode;
    if (mounted) setState(() { _isCalendarConnected = connected; _calMode = resolved; });
  }

  Future<void> _checkIosCalendarPermission() async {
    final granted = await _iosCalendarService.hasPermission();
    if (mounted) setState(() => _isIosCalendarGranted = granted);
  }

  /// Превключва календарния източник. Източниците са взаимно изключващи се:
  /// избор на Apple изключва Google и обратно.
  Future<void> _setCalendarMode(String mode) async {
    final t = AppText.of(context);
    if (mode == _calMode) return;

    if (mode == 'none') {
      if (_calendarService.isConnected) await _calendarService.disconnect();
      await IosCalendarService.setMode('none');
      if (mounted) setState(() { _calMode = 'none'; _isCalendarConnected = false; });
      return;
    }

    if (mode == 'google') {
      await IosCalendarService.setMode('google'); // Apple export off
      // Ако вече сме свързани (напр. връщане от Apple) — не пускай нов OAuth,
      // за да не иска разрешение всеки път.
      if (_calendarService.isConnected) {
        if (mounted) setState(() { _calMode = 'google'; _isCalendarConnected = true; });
        return;
      }
      if (kIsWeb) {
        // На web самият GIS бутон върши входа; само маркираме режима и
        // оставяме UI-я да покаже бутона/„Разреши достъп".
        if (mounted) setState(() => _calMode = 'google');
        return;
      }
      // Първо тих reconnect (от keychain) — без диалог, ако вече е оторизиран.
      await _calendarService.tryReconnect();
      bool ok = _calendarService.isConnected;
      if (!ok) ok = await _calendarService.connect();
      if (mounted) {
        setState(() {
          _isCalendarConnected = ok;
          if (ok) _calMode = 'google';
        });
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.connectionFailed)),
          );
        }
      }
      return;
    }

    // mode == 'apple'
    final granted = await _iosCalendarService.requestPermission();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.calendarAccessDenied)),
        );
      }
      return;
    }
    // НЕ изключваме Google акаунта (за да не иска разрешение наново при връщане).
    // Взаимната изключителност се пази от gate-а `!exportEnabled` в Google
    // hook-овете — щом Apple е активен, Google експортът е заспал.
    await IosCalendarService.setMode('apple');
    if (mounted) {
      setState(() {
        _calMode = 'apple';
        _isIosCalendarGranted = true;
        // _isCalendarConnected се запазва — Google акаунтът остава, но заспал.
      });
    }
    // Еднократен първоначален експорт на отворените задачи.
    final taskBox = Hive.box<Task>('tasks');
    final tasks = taskBox.values
        .where((t) => !t.isCompleted && !t.isArchived && !t.deleted)
        .toList();
    final count = await _iosCalendarService.exportOpenTasks(tasks);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.tasksAddedToAppleCalendar(count))),
      );
    }
  }

  // Списък с предефинирани цветове за color picker (споделен — виж utils/category_colors.dart)
  static const List<Color> _categoryColors = kCategoryColors;

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
                        final localizedName = cat.id == 'cal_events'
                            ? t.catCalendarEvents
                            : cat.id == 'documents'
                            ? t.catDocuments
                            : cat.isDefault
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

  Future<void> _editDisplayName() async {
    final t = AppText.of(context);
    final ctrl = TextEditingController(text: _authService.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.displayName),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: t.displayName,
            helperText: t.displayNameDesc,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(t.save),
          ),
        ],
      ),
    );
    if (name == null) return;
    await _authService.updateDisplayName(name);
    // Разпространи новото име към всичките ми групи (за „завършена от …" и членове).
    await GroupService().syncMyMemberInfo();
    if (mounted) setState(() {});
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

  Future<void> _loadProfilePhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final p = prefs.getString('profile_photo_path');
    final path = (p != null && File(p).existsSync()) ? p : null;
    if (mounted && path != _profilePhotoPath) {
      setState(() => _profilePhotoPath = path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final languageController = LanguageScope.of(context);

    final currentLocale = languageController.locale;
    // Анонимните сесии (създадени само за affiliate-attribution лог) НЕ са
    // „акаунт" → показваме им секцията за вход, не панел за профил.
    final rawUser = _authService.currentUser;
    final user =
        (rawUser != null && !rawUser.isAnonymous) ? rawUser : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        children: [
          // „Стани Pro" — постоянен вход към paywall, само за не-Pro на mobile.
          if (!kIsWeb && !ProService().isPro)
            GoProCard(onRestore: _restorePurchases),

          // ── КАРТА „ПРОФИЛ" (най-горе) → ProfileScreen ──
          ProfileCard(
            profilePhotoPath: _profilePhotoPath,
            onReturn: () async {
              await _loadProfilePhoto(); // снимката/името може да са сменени
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 16),

          // ═══ Група 1 — 🇧🇬 Език и регион ═══
          SettingsGroup(
            title: t.langAndRegion,
            icon: Icons.language_rounded,
            color: Colors.indigo,
            children: [
              Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: Text(
                    SupportedLocales.flags[currentLocale.languageCode] ?? '🌐',
                    style: const TextStyle(fontSize: 22),
                  ),
                  title: Text(t.language),
                  subtitle: Text(
                      SupportedLocales.names[currentLocale.languageCode] ??
                          'English'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLanguageDialog(
                      context, languageController, currentLocale),
                ),
              ),
              HolidaysTile(lang: currentLocale.languageCode),
              ..._buildBulgariaSection(context),
            ],
          ),

          const SizedBox(height: 16),

          // ═══ Група 2 — 🎨 Външен вид (Стил карти + Тема + Добави widget) ═══
          const AppearanceSection(),

          // ── Задачи (падаща група): Статистики, Категории, AI ──
          SettingsGroup(
            title: t.tasksAndAi,
            icon: Icons.task_alt_rounded,
            color: Colors.teal,
            children: [
              ListTile(
                leading: const Icon(Icons.bar_chart_rounded, color: Colors.purple),
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
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.category_rounded, color: Colors.teal),
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
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.auto_awesome, color: Colors.purple),
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
            ],
          ),

          const SizedBox(height: 16),

          // (Акаунтът се управлява от карта „Профил" горе → ProfileScreen.)
          // Календарна синхронизация — ЕДИН избор. Източниците са взаимно
          // изключващи се: ако потребителят има външна GCal↔Apple връзка, двата
          // активни наведнъж биха показвали всяко събитие двойно. Apple е
          // export-only (без импорт) — виж IosCalendarService.
          SettingsGroup(
            title: t.cloudSync,
            icon: Icons.sync_rounded,
            color: Colors.blue,
            children: [
              Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                child: Column(
              children: [
                RadioListTile<String>(
                  value: 'none',
                  groupValue: _calMode,
                  title: Text(t.calendarSyncOff),
                  onChanged: (v) => _setCalendarMode(v!),
                ),
                const Divider(height: 0),
                RadioListTile<String>(
                  value: 'google',
                  groupValue: _calMode,
                  title: Text(t.googleCalendar),
                  subtitle: Text(
                    _isCalendarConnected ? t.calendarSyncEnabled : t.connectForSync,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  onChanged: (v) => _setCalendarMode(v!),
                ),
                // Web: избран Google, но още без достъп → официален GIS бутон /
                // „Разреши достъп" (браузърът не пуска програмен OAuth popup).
                if (_calMode == 'google' && kIsWeb && !_isCalendarConnected)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _calendarService.webAuthPending.value
                        ? ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.lock_open, color: Colors.green),
                            title: Text(t.allowCalendarAccess),
                            subtitle: Text(t.allowCalendarAccessDesc,
                                style: const TextStyle(fontSize: 12)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              final ok = await _calendarService.authorizeCalendarOnWeb();
                              if (!mounted) return;
                              setState(() => _isCalendarConnected = ok);
                              if (!ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(t.connectionFailed)),
                                );
                              }
                            },
                          )
                        : SizedBox(width: 220, child: googleSignInButton()),
                  ),
                // Google свързан: ръчен синхрон + премахни дублирани събития.
                if (_calMode == 'google' && _isCalendarConnected) ...[
                  const Divider(height: 0),
                  ListTile(
                    leading: _isSyncing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync, color: Colors.blue),
                    title: Text(t.syncNow),
                    subtitle: Text(t.autoSyncDesc, style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _isSyncing ? null : _calendarSyncNow,
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services, color: Colors.orange),
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
                // Apple Calendar — само на iOS, export-only (без импорт).
                if (!kIsWeb && Platform.isIOS) ...[
                  const Divider(height: 0),
                  RadioListTile<String>(
                    value: 'apple',
                    groupValue: _calMode,
                    title: Text(t.appleCalendarSendOnly),
                    subtitle: Text(
                      t.appleCalendarSendOnlyDesc,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    onChanged: (v) => _setCalendarMode(v!),
                  ),
                  // Ръчно почистване на заварени дубли в Apple Calendar.
                  if (_calMode == 'apple') ...[
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.cleaning_services, color: Colors.orange),
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
                        final taskBox = Hive.box<Task>('tasks');
                        final res = await _iosCalendarService
                            .removeDuplicateEvents(taskBox.values.toList());
                        if (mounted) {
                          // Ако нищо не е изтрито, но има дубли в read-only
                          // (синхронизиран) календар — обясни защо.
                          final msg = (res.removed == 0 && res.blockedReadonly > 0)
                              ? t.duplicatesInSyncedCalendar
                              : t.removedDuplicates(res.removed);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg)),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
              // Синхронизирай / Нулирай — преместени тук от Акаунт (Пакет 2).
              if (user != null) ...[
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: _isSyncing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.cloud_sync_outlined,
                                color: Colors.blue),
                        title: Text(t.syncNow),
                        subtitle: Text(t.autoSyncDesc,
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6))),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _isSyncing ? null : _syncNow,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.restart_alt, color: Colors.red),
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
            ],
          ),
          const SizedBox(height: 16),

          // ── Известия и данни (падаща група): Morning Briefing + Backup ──
          SettingsGroup(
            title: t.morningBriefing,
            icon: Icons.notifications_active_rounded,
            color: Colors.orange,
            children: [
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
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
          if (_isMorningBriefingEnabled)
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
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
          ),

          const SizedBox(height: 16),
          // (Празници + Именни дни/Контакти са в група „Език и регион" — Пакет 2.)
          // ── Данни (падаща група): Backup / Restore ──
          SettingsGroup(
            title: t.localData,
            icon: Icons.storage_rounded,
            color: Colors.green,
            children: [
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
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
            ],
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

          // (Изтрий акаунт е в Профил → Опасна зона — Пакет 2.)
          const SizedBox(height: 16),

          // „За приложението" — най-долу.
          const AboutSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}



