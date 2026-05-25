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

      // Restore last known state immediately — don't wait for network
      _isConnected = true;

      await _ensureInitialized();
      final future = GoogleSignIn.instance.attemptLightweightAuthentication();
      if (future == null) return; // platform doesn't support silent auth; stay connected

      final account = await future;
      if (account != null) {
        _currentAccount = account;
        debugPrint('Google Calendar reconnected silently');
      }
      // If account == null: silent auth temporarily unavailable (no network, cold start).
      // DO NOT set _isConnected = false — that causes spurious auto-disconnect.
      // _getAccessToken() will retry on the next actual API call.
    } catch (e) {
      debugPrint('Silent reconnect failed: $e');
      // Do not change _isConnected — error may be transient.
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

  Future<String?> _getAccessToken() async {
    try {
      await _ensureInitialized();

      if (_currentAccount == null) {
        final future = GoogleSignIn.instance.attemptLightweightAuthentication();
        if (future == null) return null;
        final account = await future;
        if (account == null) return null; // transient — don't disconnect
        _currentAccount = account;
      }

      final authorizationClient = _currentAccount!.authorizationClient;
      final authorization = await authorizationClient.authorizeScopes(scopes);
      return authorization.accessToken;
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

  Future<List<Map<String, dynamic>>> getUpcomingEvents({int days = 30}) async {
    try {
      final token = await _getAccessToken();
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

  Future<Map<String, dynamic>?> getCalendarEvent(String eventId) async {
    try {
      final token = await _getAccessToken();
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

  Future<String?> addTaskToCalendar(Task task) async {
    try {
      final token = await _getAccessToken();
      if (token == null) return null;

      final url = Uri.parse(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events',
      );

      final event = {
        'summary': task.title,
        'description': task.notes ?? '',
        'start': {
          'dateTime': task.dueDate.toUtc().toIso8601String(),
          'timeZone': 'UTC',
        },
        'end': {
          'dateTime': task.dueDate.add(const Duration(hours: 1)).toUtc().toIso8601String(),
          'timeZone': 'UTC',
        },
      };

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(event),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['id'];
      } else if (response.statusCode == 401) {
        await _disconnectOnAuthError();
        return null;
      }

      debugPrint('Error adding event: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Error adding task to calendar: $e');
      return null;
    }
  }

  Future<bool> deleteCalendarEvent(String eventId) async {
    try {
      final token = await _getAccessToken();
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

  /// === GOOGLE TASKS API ===

  Future<List<Map<String, dynamic>>> getTaskLists() async {
    try {
      final token = await _getAccessToken();
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

  Future<List<Map<String, dynamic>>> getTasksFromList(String listId) async {
    try {
      final token = await _getAccessToken();
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

  Future<List<Map<String, dynamic>>> getAllGoogleTasks() async {
    try {
      final taskLists = await getTaskLists();
      if (taskLists.isEmpty) {
        debugPrint('No task lists found');
        return [];
      }

      final allTasks = <Map<String, dynamic>>[];

      for (final taskList in taskLists) {
        final listId = taskList['id'] as String;
        final tasks = await getTasksFromList(listId);

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
