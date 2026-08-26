import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../utils/localization.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import 'statistics_screen.dart';
import 'ai_settings_screen.dart';
import '../../services/task_view_preference.dart';
import '../home/home_screen.dart';
import '../../services/morning_briefing_service.dart';
import '../../services/pro_service.dart';
import 'sections/settings_group.dart';
import 'sections/cloud_sync_section.dart';
import 'sections/go_pro_card.dart';
import 'sections/profile_card.dart';
import 'sections/appearance_section.dart';
import 'sections/about_section.dart';
import 'sections/holidays_tile.dart';
import 'sections/bulgaria_section.dart';
import 'sections/category_management.dart';
import 'sections/language_dialog.dart';
import 'sections/data_export_import.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  final _viewPreference = TaskViewPreference();
  final _morningBriefingService = MorningBriefingService();
  bool _isMorningBriefingEnabled = false;
  int _briefingHour = 8;
  int _briefingMinute = 0;
  String? _profilePhotoPath; // локална снимка на профила (Пакет 2)
  StreamSubscription<dynamic>? _authSub;

  @override
  void initState() {
    super.initState();
    _loadBriefingTime();
    _loadMorningBriefingSetting();
    _loadProfilePhoto();
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
  }

  void _onProChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _authSub?.cancel();
    ProService().removeListener(_onProChanged);
    super.dispose();
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
                  onTap: () => showLanguageDialog(
                      context, languageController, currentLocale),
                ),
              ),
              HolidaysTile(lang: currentLocale.languageCode),
              const BulgariaSection(),
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
                onTap: () => CategoryManagement.show(context,
                    onChanged: () => setState(() {})),
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

          CloudSyncSection(signedIn: user != null),
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
                  onTap: () => exportData(context),
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
                  onTap: () => importData(context),
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



