import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/task.dart';
import '../../../models/category.dart';
import '../../../utils/localization.dart';
import '../../../utils/gsi_button.dart';
import '../../../services/google_calendar_service.dart';
import '../../../services/calendar_import_service.dart';
import '../../../services/ios_calendar_service.dart';
import '../../../services/sync_service.dart';
import 'settings_group.dart';

/// Секция „Облачна синхронизация" в Настройки: единен избор на календарен
/// източник (none/google/apple), ръчен синхрон + премахване на дубли, и
/// облачен merge/reset (само за влезли потребители).
///
/// [signedIn] е true за не-анонимен акаунт (gate за Синхронизирай/Нулирай).
/// Изнесено от `settings_screen.dart` без промяна на поведение.
class CloudSyncSection extends StatefulWidget {
  const CloudSyncSection({super.key, required this.signedIn});

  final bool signedIn;

  @override
  State<CloudSyncSection> createState() => _CloudSyncSectionState();
}

class _CloudSyncSectionState extends State<CloudSyncSection> {
  bool _isSyncing = false;
  bool _isCalendarConnected = false;
  final _calendarService = GoogleCalendarService();
  final _iosCalendarService = IosCalendarService();
  bool _isIosCalendarGranted = false;
  // Единен избор на календарен източник: 'none' | 'google' | 'apple'.
  // Двата източника са взаимно изключващи се (иначе при външна GCal↔Apple
  // връзка всяко събитие се появява двойно). Виж IosCalendarService.
  String _calMode = 'none';

  @override
  void initState() {
    super.initState();
    _checkCalendarConnection();
    if (!kIsWeb && Platform.isIOS) _checkIosCalendarPermission();
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
      setState(() {
        _isCalendarConnected = _calendarService.isConnected;
        // Web GIS вход → отразяваме режима като Google.
        if (_isCalendarConnected) _calMode = 'google';
      });
    }
  }

  @override
  void dispose() {
    _calendarService.connectionNotifier.removeListener(_onCalendarConnChanged);
    _calendarService.webAuthPending.removeListener(_onCalendarConnChanged);
    super.dispose();
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

    // (Акаунтът се управлява от карта „Профил" горе → ProfileScreen.)
    // Календарна синхронизация — ЕДИН избор. Източниците са взаимно
    // изключващи се: ако потребителят има външна GCal↔Apple връзка, двата
    // активни наведнъж биха показвали всяко събитие двойно. Apple е
    // export-only (без импорт) — виж IosCalendarService.
    return SettingsGroup(
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
        if (widget.signedIn) ...[
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
    );
  }
}
