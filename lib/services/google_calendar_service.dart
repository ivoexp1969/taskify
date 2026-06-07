import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class GoogleCalendarService {
  static final GoogleCalendarService _instance = GoogleCalendarService._internal();
  factory GoogleCalendarService() => _instance;
  GoogleCalendarService._internal();

  bool _initialized = false;
  GoogleSignInAccount? _currentAccount;
  bool _isConnected = false;

  static const List<String> scopes = [
    'https://www.googleapis.com/auth/calendar',
    'https://www.googleapis.com/auth/tasks.readonly',
  ];

  bool get isConnected => _isConnected;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb
          ? null
          : '929046134968-g21i568en2jccqqvlkj4e2reqks9kuij.apps.googleusercontent.com',
      serverClientId: kIsWeb
          ? '929046134968-m6ffgsd8dsotabi7ivkjdsqfnlm041n.apps.googleusercontent.com'
          : null,
    );
    _initialized = true;
  }

  Future<void> tryReconnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasConnected = prefs.getBool('google_calendar_connected') ?? false;
      if (!wasConnected) return;

      // Restore the connection FLAG immediately so the UI shows "connected".
      _isConnected = true;

      // On Android attemptLightweightAuthentication() pops the Credential Manager
      // account-picker on every cold start, so we skip it and restore the account
      // lazily from explicit user actions (interactive: true).
      //
      // On iOS lightweight auth is SILENT (restores the session from the keychain
      // with no UI). Skipping it there left _currentAccount null after every
      // relaunch, so the first calendar call hit an expired/absent token → 401 →
      // _disconnectOnAuthError() dropped the connection. Restore it silently here
      // so the iOS connection actually survives an app restart.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          await _ensureInitialized();
          final future = GoogleSignIn.instance.attemptLightweightAuthentication();
          if (future != null) _currentAccount = await future;
        } catch (e) {
          debugPrint('iOS silent reconnect failed (will retry lazily): $e');
        }
      }
      debugPrint('Google Calendar: connection state restored');
    } catch (e) {
      debugPrint('Silent reconnect failed: $e');
    }
  }

  Future<bool> connect() async {
    try {
      await _ensureInitialized();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: scopes,
      );
      _currentAccount = account;
      _isConnected = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('google_calendar_connected', true);
      return true;
    } catch (e) {
      debugPrint('Error connecting to Google Calendar: $e');
      _isConnected = false;
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _ensureInitialized();
      await GoogleSignIn.instance.signOut();
      _currentAccount = null;
      _isConnected = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('google_calendar_connected', false);
    } catch (e) {
      debugPrint('Error disconnecting from Google Calendar: $e');
    }
  }

  /// Returns an access token for [scopes].
  ///
  /// [interactive] == false (default, used by startup auto-sync and any
  /// background work): NEVER shows UI. If the account isn't already in memory,
  /// or the scopes aren't already authorized, returns null and the caller skips
  /// silently. This is what guarantees no auth dialog at app startup.
  ///
  /// [interactive] == true (only from explicit user taps): may show the Google
  /// account picker / consent UI to restore the account and authorize scopes.
  Future<String?> _getAccessToken({bool interactive = false}) async {
    try {
      await _ensureInitialized();

      // Restore the signed-in account if it isn't in memory (e.g. after a cold
      // start). Every restore path below can show UI, so it only runs when the
      // caller explicitly allows interaction.
      if (_currentAccount == null) {
        if (!interactive) return null; // background — never show UI
        final future = GoogleSignIn.instance.attemptLightweightAuthentication();
        if (future != null) _currentAccount = await future;
        _currentAccount ??=
            await GoogleSignIn.instance.authenticate(scopeHint: scopes);
      }

      final client = _currentAccount!.authorizationClient;
      final GoogleSignInClientAuthorization? authz = interactive
          ? await client.authorizeScopes(scopes) // may prompt
          : await client.authorizationForScopes(scopes); // silent, null if none
      return authz?.accessToken;
    } catch (e) {
      debugPrint('Error getting access token: $e');
      return null; // transient error — don't disconnect
    }
  }

  /// Called only when Google API returns 401 — the token is genuinely revoked.
  Future<void> _disconnectOnAuthError() async {
    _isConnected = false;
    _currentAccount = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('google_calendar_connected', false);
    debugPrint('Google Calendar: disconnected — token revoked (401)');
  }

  /// === CALENDAR EVENTS API ===

  Future<List<Map<String, dynamic>>> getUpcomingEvents({int days = 30, bool interactive = false}) async {
    try {
      final token = await _getAccessToken(interactive: interactive);
      if (token == null) {
        debugPrint('No access token available');
        return [];
      }

      final now = DateTime.now();
      final timeMin = now.toUtc().toIso8601String();
      final timeMax = now.add(Duration(days: days)).toUtc().toIso8601String();

      final url = Uri.parse(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events'
        '?timeMin=$timeMin'
        '&timeMax=$timeMax'
        '&singleEvents=true'
        '&orderBy=startTime',
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];

        return items.map((item) {
          final start = item['start'];
          String? startDateTime;
          if (start != null) {
            startDateTime = start['dateTime'] ?? start['date'];
          }

          return {
            'id': item['id'],
            'summary': item['summary'],
            'description': item['description'],
            'startDateTime': startDateTime,
            'eventType': item['eventType'],
          };
        }).toList();
      } else if (response.statusCode == 401) {
        await _disconnectOnAuthError();
        return [];
      } else {
        debugPrint('Get events error: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching events: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCalendarEvent(String eventId, {bool interactive = false}) async {
    try {
      final token = await _getAccessToken(interactive: interactive);
      if (token == null) return null;

      final url = Uri.parse(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events/$eventId',
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final event = jsonDecode(response.body);
        final start = event['start'];
        String? startDateTime;
        if (start != null) {
          startDateTime = start['dateTime'] ?? start['date'];
        }

        return {
          'id': event['id'],
          'summary': event['summary'],
          'description': event['description'],
          'startDateTime': startDateTime,
          'deleted': false,
        };
      } else if (response.statusCode == 404) {
        return {'deleted': true};
      }

      return null;
    } catch (e) {
      debugPrint('Error fetching event: $e');
      return null;
    }
  }

  /// Преобразува task.reminders ('minus_15m', 'at_time', ...) в Google Calendar
  /// reminder overrides (минути преди началото). Google допуска макс. 5.
  List<Map<String, dynamic>> _reminderOverrides(Task task) {
    final list = task.reminders;
    if (list == null || list.isEmpty) return [];
    final seen = <int>{};
    final overrides = <Map<String, dynamic>>[];
    for (final r in list) {
      int? minutes;
      switch (r) {
        case 'at_time': minutes = 0; break;
        case 'minus_5m': minutes = 5; break;
        case 'minus_15m': minutes = 15; break;
        case 'minus_30m': minutes = 30; break;
        case 'minus_1h': minutes = 60; break;
        case 'minus_2h': minutes = 120; break;
        case 'minus_1d': minutes = 1440; break;
        case 'same_day_8':
          final sameDay8 = DateTime(
              task.dueDate.year, task.dueDate.month, task.dueDate.day, 8);
          final diff = task.dueDate.difference(sameDay8).inMinutes;
          minutes = diff >= 0 ? diff : 0;
          break;
      }
      if (minutes == null || minutes < 0 || minutes > 40320) continue;
      if (seen.add(minutes)) {
        overrides.add({'method': 'popup', 'minutes': minutes});
      }
    }
    return overrides.take(5).toList();
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Тялото на Google Calendar събитието за дадена задача (вкл. напомняния).
  /// [allDay] = true пази събитието „целодневно" (date вместо dateTime), за да
  /// не се получава смесен формат при PATCH → „Sync Error".
  Map<String, dynamic> _eventBody(Task task, {bool allDay = false}) {
    final overrides = _reminderOverrides(task);
    final body = <String, dynamic>{
      'summary': task.title,
      'description': task.notes ?? '',
      // ВИНАГИ useDefault:false + явни overrides (дори празни). PATCH мърджва
      // reminders обекта, затова само `useDefault:true` би оставил старите
      // overrides → грешка „cannotUseDefaultRemindersAndSpecifyOverride" (400).
      // Празен overrides списък = задачата няма напомняния.
      'reminders': {'useDefault': false, 'overrides': overrides},
    };
    if (allDay) {
      body['start'] = {'date': _ymd(task.dueDate)};
      body['end'] = {'date': _ymd(task.dueDate.add(const Duration(days: 1)))};
    } else {
      body['start'] = {
        'dateTime': task.dueDate.toUtc().toIso8601String(),
        'timeZone': 'UTC',
      };
      body['end'] = {
        'dateTime': task.dueDate.add(const Duration(hours: 1)).toUtc().toIso8601String(),
        'timeZone': 'UTC',
      };
    }
    return body;
  }

  Future<String?> addTaskToCalendar(Task task, {bool interactive = false}) async {
    try {
      final token = await _getAccessToken(interactive: interactive);
      if (token == null) return null;

      final url = Uri.parse(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events',
      );

      final event = _eventBody(task);

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(event),
      );

      debugPrint('GCALSYNC add: post ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['id'];
      } else if (response.statusCode == 401) {
        await _disconnectOnAuthError();
        return null;
      }

      debugPrint('GCALSYNC add: error ${response.statusCode}: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Error adding task to calendar: $e');
      return null;
    }
  }

  /// Обновява вече свързано събитие (PATCH със същото [eventId]) → НЕ дублира.
  /// Връща true при успех. Ако събитието е изтрито на Google страна (404/410),
  /// пресъздава ново и записва новото ID в задачата.
  Future<bool> updateCalendarEvent(String eventId, Task task, {bool interactive = false}) async {
    try {
      final token = await _getAccessToken(interactive: interactive);
      if (token == null) return false;

      const base =
          'https://www.googleapis.com/calendar/v3/calendars/primary/events';

      // 1) Вземи съществуващото събитие — за да знаем формата (all-day vs timed)
      //    и дали изобщо подлежи на редакция. Така избягваме „Sync Error" и
      //    случайни дубли от сляп PATCH/recreate.
      final getResp = await http.get(
        Uri.parse('$base/$eventId'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );

      if (getResp.statusCode == 401) {
        await _disconnectOnAuthError();
        return false;
      }

      bool gone = getResp.statusCode == 404 || getResp.statusCode == 410;
      Map<String, dynamic>? existing;
      if (getResp.statusCode == 200) {
        existing = jsonDecode(getResp.body) as Map<String, dynamic>;
        if (existing['status'] == 'cancelled') gone = true;
      }

      if (gone) {
        // Импортирана задача, чийто източник вече липсва в Google (или е
        // нередактируем recurring/birthday instance, който GET-ът не намира) →
        // НЕ пресъздаваме. Иначе се появяват дубли (рождените дни като
        // 00:00–01:00 събития). Само ЛОКАЛНО създадени задачи се пресъздават.
        if (task.importedFromCalendar == true) {
          debugPrint('GCALSYNC update: imported event gone → skip (no recreate)');
          return false;
        }
        debugPrint('GCALSYNC update: local event gone → recreate');
        final newId = await addTaskToCalendar(task, interactive: interactive);
        if (newId != null) {
          task.googleCalendarEventId = newId;
          await task.save();
          return true;
        }
        return false;
      }

      if (existing == null) {
        debugPrint('GCALSYNC update: get ${getResp.statusCode}: ${getResp.body}');
        return false;
      }

      // Специални типове (рожден ден, OOO, focus time, working location) не се
      // редактират през стандартния events.patch → пропусни тихо.
      final eventType = existing['eventType'] as String? ?? 'default';
      if (eventType != 'default') {
        debugPrint('GCALSYNC update: skip eventType=$eventType');
        return false;
      }

      final isAllDay = (existing['start'] as Map?)?.containsKey('date') ?? false;

      final patchResp = await http.patch(
        Uri.parse('$base/$eventId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(_eventBody(task, allDay: isAllDay)),
      );

      debugPrint('GCALSYNC update: patch ${patchResp.statusCode} (allDay=$isAllDay)');
      if (patchResp.statusCode == 200) return true;
      if (patchResp.statusCode == 401) {
        await _disconnectOnAuthError();
        return false;
      }
      debugPrint('GCALSYNC update: patch error ${patchResp.statusCode}: ${patchResp.body}');
      return false;
    } catch (e) {
      debugPrint('GCALSYNC update: exception $e');
      return false;
    }
  }

  Future<bool> deleteCalendarEvent(String eventId, {bool interactive = false}) async {
    try {
      final token = await _getAccessToken(interactive: interactive);
      if (token == null) return false;

      final url = Uri.parse(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events/$eventId',
      );

      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 401) {
        await _disconnectOnAuthError();
        return false;
      }
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting event: $e');
      return false;
    }
  }

  /// Премахва дублирани събития от primary календара: събития с ЕДНАКВО
  /// заглавие на същата или близка дата (в рамките на [dayTolerance] дни)
  /// се свеждат до едно. Безопасно — НЕ пипа:
  ///  • рождени дни (eventType=birthday),
  ///  • легитимни повтарящи се серии (имат recurringEventId).
  /// Връща броя изтрити събития.
  Future<int> removeDuplicateEvents({bool interactive = false, int dayTolerance = 3}) async {
    try {
      final token = await _getAccessToken(interactive: interactive);
      if (token == null) return 0;

      final now = DateTime.now();
      final timeMin = now.subtract(const Duration(days: 400)).toUtc().toIso8601String();
      final timeMax = now.add(const Duration(days: 800)).toUtc().toIso8601String();

      // Заглавие → списък от (eventId, начало) за standalone събития.
      final byTitle = <String, List<MapEntry<String, DateTime>>>{};
      String? pageToken;
      do {
        final url = Uri.parse(
          'https://www.googleapis.com/calendar/v3/calendars/primary/events'
          '?timeMin=$timeMin&timeMax=$timeMax&singleEvents=true&orderBy=startTime'
          '&maxResults=250${pageToken != null ? '&pageToken=$pageToken' : ''}',
        );
        final resp = await http.get(url, headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        });
        if (resp.statusCode == 401) {
          await _disconnectOnAuthError();
          return 0;
        }
        if (resp.statusCode != 200) {
          debugPrint('GCALSYNC dedupe list ${resp.statusCode}: ${resp.body}');
          break;
        }
        final data = jsonDecode(resp.body);
        for (final it in (data['items'] as List? ?? [])) {
          if (it['eventType'] == 'birthday') continue;
          if (it['recurringEventId'] != null) continue; // легитимна серия
          final id = it['id'] as String?;
          final summary = (it['summary'] ?? '').toString().trim().toLowerCase();
          if (id == null || summary.isEmpty) continue;
          final start = it['start'];
          final s = start?['dateTime'] ?? start?['date'];
          if (s == null) continue;
          DateTime dt;
          try {
            dt = DateTime.parse(s);
          } catch (_) {
            continue;
          }
          byTitle.putIfAbsent(summary, () => []).add(MapEntry(id, dt));
        }
        pageToken = data['nextPageToken'] as String?;
      } while (pageToken != null);

      // За всяко заглавие: пази клъстер от запазени дати; всичко в рамките на
      // ±tolerance дни от вече запазена дата е дубликат.
      final toDelete = <String>[];
      for (final list in byTitle.values) {
        if (list.length < 2) continue;
        list.sort((a, b) => a.value.compareTo(b.value));
        final kept = <DateTime>[];
        for (final e in list) {
          final isDup = kept.any(
              (k) => e.value.difference(k).inHours.abs() <= dayTolerance * 24);
          if (isDup) {
            toDelete.add(e.key);
          } else {
            kept.add(e.value);
          }
        }
      }

      debugPrint('GCALSYNC dedupe: found ${toDelete.length} duplicates to delete');
      int deleted = 0;
      for (final id in toDelete) {
        bool ok = false;
        // Retry при временни мрежови грешки (socket abort и т.н.).
        for (int attempt = 0; attempt < 3 && !ok; attempt++) {
          ok = await deleteCalendarEvent(id, interactive: false);
          if (!ok) await Future.delayed(const Duration(milliseconds: 500));
        }
        if (ok) deleted++;
        // Лека пауза, за да не претоварваме връзката/квотата.
        await Future.delayed(const Duration(milliseconds: 120));
      }
      debugPrint('GCALSYNC dedupe: deleted $deleted of ${toDelete.length}');
      return deleted;
    } catch (e) {
      debugPrint('GCALSYNC dedupe exception: $e');
      return 0;
    }
  }

  /// === GOOGLE TASKS API ===

  Future<List<Map<String, dynamic>>> getTaskLists({bool interactive = false}) async {
    try {
      final token = await _getAccessToken(interactive: interactive);
      if (token == null) {
        debugPrint('No access token for tasks');
        return [];
      }

      final url = Uri.parse(
        'https://tasks.googleapis.com/tasks/v1/users/@me/lists',
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        return items.map((item) => {
          'id': item['id'],
          'title': item['title'],
        }).toList();
      } else if (response.statusCode == 401) {
        await _disconnectOnAuthError();
        return [];
      } else {
        debugPrint('Get task lists error: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching task lists: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTasksFromList(String listId, {bool interactive = false}) async {
    try {
      final token = await _getAccessToken(interactive: interactive);
      if (token == null) return [];

      final url = Uri.parse(
        'https://tasks.googleapis.com/tasks/v1/lists/$listId/tasks',
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];

        return items.map((item) {
          return {
            'id': item['id'],
            'title': item['title'],
            'notes': item['notes'],
            'due': item['due'],
            'status': item['status'],
            'updated': item['updated'],
          };
        }).toList();
      } else {
        debugPrint('Get tasks error for list $listId: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching tasks from list $listId: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllGoogleTasks({bool interactive = false}) async {
    try {
      final taskLists = await getTaskLists(interactive: interactive);
      if (taskLists.isEmpty) {
        debugPrint('No task lists found');
        return [];
      }

      final allTasks = <Map<String, dynamic>>[];

      for (final taskList in taskLists) {
        final listId = taskList['id'] as String;
        final tasks = await getTasksFromList(listId, interactive: interactive);

        for (final task in tasks) {
          task['listTitle'] = taskList['title'];
          allTasks.add(task);
        }
      }

      return allTasks;
    } catch (e) {
      debugPrint('Error fetching all Google tasks: $e');
      return [];
    }
  }
}
