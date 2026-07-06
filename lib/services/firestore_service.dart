import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

import '../models/task.dart';
import '../models/category.dart';
import 'auth_service.dart';

class FirestoreService {
  FirestoreService._internal();

  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();

  // Анонимните сесии (само за affiliate-attribution лог) НЕ докосват личните
  // облачни данни → третираме ги като „не-логнат".
  String? get _userId {
    final u = _auth.currentUser;
    if (u == null || u.isAnonymous) return null;
    return u.uid;
  }

  CollectionReference<Map<String, dynamic>>? get _tasksRef {
    if (_userId == null) return null;
    return _db.collection('users').doc(_userId).collection('tasks');
  }

  CollectionReference<Map<String, dynamic>>? get _categoriesRef {
    if (_userId == null) return null;
    return _db.collection('users').doc(_userId).collection('categories');
  }


  Future<({bool success, String? error, int tasksCount, int categoriesCount})> uploadToCloud() async {
    if (_userId == null) {
      return (success: false, error: 'Не си влязъл в акаунта', tasksCount: 0, categoriesCount: 0);
    }

    try {
      final taskBox = Hive.box<Task>('tasks');
      final categoryBox = Hive.box<Category>('categories');

      final existingTasks = await _tasksRef!.get();
      for (final doc in existingTasks.docs) {
        await doc.reference.delete();
      }

      final existingCategories = await _categoriesRef!.get();
      for (final doc in existingCategories.docs) {
        await doc.reference.delete();
      }

      int categoriesCount = 0;
      for (final category in categoryBox.values) {
        await _categoriesRef!.doc(category.id).set({
          'id': category.id,
          'name': category.name,
          'colorValue': category.colorValue,
          'isDefault': category.isDefault,
        });
        categoriesCount++;
      }

      int tasksCount = 0;
      for (final task in taskBox.values) {
        await _tasksRef!.add({
          'title': task.title,
          'dueDate': task.dueDate.toIso8601String(),
          'categoryId': task.categoryId,
          'priority': task.priority,
          'isCompleted': task.isCompleted,
          'recurrence': task.recurrence,
          'reminder': task.reminder,
          'reminders': task.reminders,
          'subtasks': task.subtasks,
          'notes': task.notes,
          'completedAt': task.completedAt?.toIso8601String(),
          'isArchived': task.isArchived,
          'archivedAt': task.archivedAt?.toIso8601String(),
          'durationMinutes': task.durationMinutes,
          'template': task.template,
          'googleCalendarEventId': task.googleCalendarEventId,
          'importedFromCalendar': task.importedFromCalendar,
          'uploadedAt': FieldValue.serverTimestamp(),
        });
        tasksCount++;
      }

      // Документите вече са обикновени задачи (template 'document') → качват се по
      // нормалната task писта. Отделната `documents` подколекция е изоставена.

      return (success: true, error: null, tasksCount: tasksCount, categoriesCount: categoriesCount);
    } catch (e) {
      return (success: false, error: e.toString(), tasksCount: 0, categoriesCount: 0);
    }
  }

  Future<({bool success, String? error, int tasksCount, int categoriesCount})> downloadFromCloud() async {
    if (_userId == null) {
      return (success: false, error: 'Не си влязъл в акаунта', tasksCount: 0, categoriesCount: 0);
    }

    try {
      final taskBox = Hive.box<Task>('tasks');
      final categoryBox = Hive.box<Category>('categories');

      await taskBox.clear();
      await categoryBox.clear();

      int categoriesCount = 0;
      final categoriesSnapshot = await _categoriesRef!.get();
      for (final doc in categoriesSnapshot.docs) {
        final data = doc.data();
        final category = Category(
          id: data['id'] as String,
          name: data['name'] as String,
          colorValue: data['colorValue'] as int,
          isDefault: data['isDefault'] as bool? ?? false,
        );
        await categoryBox.put(category.id, category);
        categoriesCount++;
      }

      int tasksCount = 0;
      final tasksSnapshot = await _tasksRef!.get();
      for (final doc in tasksSnapshot.docs) {
        final data = doc.data();
        DateTime? parseDate(dynamic v) =>
            v is String ? DateTime.tryParse(v) : null;
        final task = Task(
          title: data['title'] as String,
          dueDate: DateTime.parse(data['dueDate'] as String),
          categoryId: data['categoryId'] as String,
          priority: data['priority'] as int? ?? 1,
          recurrence: data['recurrence'] as String?,
          reminder: data['reminder'] as String?,
          reminders: (data['reminders'] as List<dynamic>?)?.cast<String>(),
          subtasks: (data['subtasks'] as List<dynamic>?)?.cast<String>(),
          notes: data['notes'] as String?,
          completedAt: parseDate(data['completedAt']),
          isArchived: data['isArchived'] as bool? ?? false,
          archivedAt: parseDate(data['archivedAt']),
          durationMinutes: data['durationMinutes'] as int?,
          template: data['template'] as String?,
          googleCalendarEventId: data['googleCalendarEventId'] as String?,
          importedFromCalendar: data['importedFromCalendar'] as bool?,
        );
        task.isCompleted = data['isCompleted'] as bool? ?? false;
        await taskBox.add(task);
        tasksCount++;
      }

      // Документите вече са обикновени задачи → свалят се по нормалната task писта.
      // Старата `documents` подколекция не се чете повече.

      return (success: true, error: null, tasksCount: tasksCount, categoriesCount: categoriesCount);
    } catch (e) {
      return (success: false, error: e.toString(), tasksCount: 0, categoriesCount: 0);
    }
  }

  Future<({int tasks, int categories})> getCloudDataCount() async {
    if (_userId == null) return (tasks: 0, categories: 0);

    try {
      final tasksSnapshot = await _tasksRef!.get();
      final categoriesSnapshot = await _categoriesRef!.get();
      return (tasks: tasksSnapshot.docs.length, categories: categoriesSnapshot.docs.length);
    } catch (e) {
      return (tasks: 0, categories: 0);
    }
  }
}
