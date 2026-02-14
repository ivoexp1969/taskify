import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import '../models/task.dart';

class GoogleCalendarService {
  static final GoogleCalendarService _instance = GoogleCalendarService._internal();
  factory GoogleCalendarService() => _instance;
  GoogleCalendarService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '929046134968-m6ffgsd8dsoatabi7lvkjdsqfnlm041n.apps.googleusercontent.com',
    scopes: [
      'https://www.googleapis.com/auth/calendar',
      'https://www.googleapis.com/auth/calendar.events',
    ],
  );

  http.Client? _authClient;
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(false);
  Completer<void>? _initCompleter;
  bool _initializationSucceeded = false;
  bool get isConnected => isConnectedNotifier.value;

  Future<void> initialize() async {
    if (_initializationSucceeded) return;
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      return _initCompleter!.future;
    }
    _initCompleter = Completer<void>();
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        _authClient = await _googleSignIn.authenticatedClient();
        isConnectedNotifier.value = _authClient != null;
      } else {
        isConnectedNotifier.value = false;
      }
      _initializationSucceeded = true;
      _initCompleter!.complete();
    } catch (e) {
      print('GoogleCalendarService initialize error: $e');
      isConnectedNotifier.value = false;
      _initCompleter!.complete();
    }
    return _initCompleter!.future;
  }

  Future<bool> connect() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        isConnectedNotifier.value = false;
        return false;
      }
      _authClient = await _googleSignIn.authenticatedClient();
      isConnectedNotifier.value = _authClient != null;
      if (isConnectedNotifier.value) {
        _initializationSucceeded = true;
      }
      return isConnectedNotifier.value;
    } catch (e) {
      print('Google Calendar connect error: $e');
      isConnectedNotifier.value = false;
      return false;
    }
  }

  Future<void> disconnect() async {
    await _googleSignIn.signOut();
    _authClient = null;
    isConnectedNotifier.value = false;
  }

  Future<String?> addTaskToCalendar(Task task) async {
    if (!isConnectedNotifier.value || _authClient == null) return null;
    try {
      final startTime = task.dueDate.toIso8601String();
      final endTime = task.dueDate.add(const Duration(hours: 1)).toIso8601String();
      final event = {
        'summary': task.title,
        'description': task.notes ?? '',
        'start': {'dateTime': startTime, 'timeZone': 'Europe/Sofia'},
        'end': {'dateTime': endTime, 'timeZone': 'Europe/Sofia'},
      };
      final response = await _authClient!.post(
        Uri.parse('https://www.googleapis.com/calendar/v3/calendars/primary/events'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(event),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['id'] as String?;
      }
      print('Add event error: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      print('Add to calendar error: $e');
      return null;
    }
  }

  Future<bool> updateCalendarEvent(String eventId, Task task) async {
    if (!isConnectedNotifier.value || _authClient == null) return false;
    try {
      final startTime = task.dueDate.toIso8601String();
      final endTime = task.dueDate.add(const Duration(hours: 1)).toIso8601String();
      final event = {
        'summary': task.title,
        'description': task.notes ?? '',
        'start': {'dateTime': startTime, 'timeZone': 'Europe/Sofia'},
        'end': {'dateTime': endTime, 'timeZone': 'Europe/Sofia'},
      };
      final response = await _authClient!.put(
        Uri.parse('https://www.googleapis.com/calendar/v3/calendars/primary/events/$eventId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(event),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Update calendar error: $e');
      return false;
    }
  }

  Future<bool> deleteCalendarEvent(String eventId) async {
    if (!isConnectedNotifier.value || _authClient == null) return false;
    try {
      final response = await _authClient!.delete(
        Uri.parse('https://www.googleapis.com/calendar/v3/calendars/primary/events/$eventId'),
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      print('Delete calendar error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getCalendarEvent(String eventId) async {
    if (!isConnectedNotifier.value || _authClient == null) return null;
    try {
      final response = await _authClient!.get(
        Uri.parse('https://www.googleapis.com/calendar/v3/calendars/primary/events/$eventId'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Get calendar event error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getUpcomingEvents({int days = 365}) async {
    if (!isConnectedNotifier.value || _authClient == null) return [];
    try {
      final now = DateTime.now().toUtc();
      final timeMin = now.subtract(const Duration(days: 365)).toIso8601String();
      final timeMax = now.add(Duration(days: days)).toIso8601String();
      final response = await _authClient!.get(
        Uri.parse('https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=$timeMin&timeMax=$timeMax&singleEvents=true&orderBy=startTime&maxResults=2500'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];
        return items.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Get events error: $e');
      return [];
    }
  }
}
