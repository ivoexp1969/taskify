import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class GoogleCalendarService {
  static final GoogleCalendarService _instance = GoogleCalendarService._internal();
  factory GoogleCalendarService() => _instance;
  GoogleCalendarService._internal();

  GoogleSignIn? _googleSignIn;
  bool _isConnected = false;

  // Scopes за Calendar Events и Tasks
  static const List<String> scopes = [
    'https://www.googleapis.com/auth/calendar',
    'https://www.googleapis.com/auth/tasks.readonly', // За Google Tasks
  ];

  bool get isConnected => _isConnected;

  GoogleSignIn _getGoogleSignIn() {
    _googleSignIn ??= GoogleSignIn(
      scopes: scopes,
      // Web използва Web Client ID; mobile — четат от google-services.json / GoogleService-Info.plist
      serverClientId: kIsWeb
          ? '929046134968-m6ffgsd8dsotabi7ivkjdsqfnlm041n.apps.googleusercontent.com'
          : null,
    );
    return _googleSignIn!;
  }

  /// Опитва silent reconnect при стартиране на app-а
  Future<void> tryReconnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasConnected = prefs.getBool('google_calendar_connected') ?? false;
      if (!wasConnected) return;

      final gsi = _getGoogleSignIn();
      final account = await gsi.signInSilently();
      if (account != null) {
        final auth = await gsi.authenticatedClient();
        if (auth != null) {
          _isConnected = true;
          debugPrint('Google Calendar reconnected silently');
          return;
        }
      }
      // Silent fail — само in-memory, не трием prefs (може да е временна мрежова грешка)
      _isConnected = false;
    } catch (e) {
      debugPrint('Silent reconnect failed: $e');
      _isConnected = false;
    }
  }

  /// Свързваме се с Google Calendar чрез Google Sign In
  Future<bool> connect() async {
    try {
      final gsi = _getGoogleSignIn();
      final account = await gsi.signIn();
      if (account == null) {
        return false;
      }

      final auth = await gsi.authenticatedClient();
      if (auth == null) {
        return false;
      }

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

  /// Разкачаме Google Calendar
  Future<void> disconnect() async {
    try {
      await _googleSignIn?.signOut();
      _isConnected = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('google_calendar_connected', false);
    } catch (e) {
      debugPrint('Error disconnecting from Google Calendar: $e');
    }
  }

  /// Взимаме access token за API заявки
  Future<String?> _getAccessToken() async {
    try {
      final auth = await _googleSignIn?.authenticatedClient();
      if (auth == null) {
        return null;
      }

      // Вземаме credentials
      var account = _googleSignIn?.currentUser;
      if (account == null) {
        // Опитваме silent sign-in ако токенът е изтекъл
        account = await _googleSignIn?.signInSilently();
        if (account == null) {
          _isConnected = false;
          return null;
        }
      }

      final authHeaders = await account.authHeaders;
      final authorization = authHeaders['Authorization'];
      if (authorization == null) {
        return null;
      }

      // Authorization header е във формат "Bearer TOKEN"
      return authorization.replaceFirst('Bearer ', '');
    } catch (e) {
      debugPrint('Error getting access token: $e');
      return null;
    }
  }

  /// === CALENDAR EVENTS API ===

  /// Взима предстоящите събития от Calendar
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
            'eventType': item['eventType'], // birthday, default, etc.
          };
        }).toList();
      } else {
        debugPrint('Get events error: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching events: $e');
      return [];
    }
  }

  /// Взима конкретно събитие по ID
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

  /// Добавя задача към Calendar като събитие
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
      }

      debugPrint('Error adding event: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Error adding task to calendar: $e');
      return null;
    }
  }

  /// Изтрива събитие от Calendar
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

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting event: $e');
      return false;
    }
  }

  /// === GOOGLE TASKS API ===

  /// Взима всички task lists на потребителя
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
      } else {
        debugPrint('Get task lists error: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching task lists: $e');
      return [];
    }
  }

  /// Взима tasks от конкретен list
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
            'due': item['due'], // ISO 8601 format or null
            'status': item['status'], // "needsAction" or "completed"
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

  /// Взима всички Google Tasks от всички lists
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
        
        // Добавяме listTitle към всеки task за reference
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

