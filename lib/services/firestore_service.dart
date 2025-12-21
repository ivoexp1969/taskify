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

  // Получаване на user ID
  String? get _userId => _auth.currentUser?.uid;

  // Референция към колекциите на потребителя
  CollectionReference<Map<String, dynamic>>? get _tasksRef {
    if (_userId == null) return null;
    return _db.collection('users').doc(_userId).collection('tasks');
  }

  CollectionReference<Map<String, dynamic>>? get _categoriesRef {
    if (_userId == null) return null;
    return _db.collection('users').doc(_userId).collection('categories');
  }

  // Качване на всички локални данни в облака
  Future<({bool success, String? error, int tasksCount, int categoriesCount})> uploadToCloud() async {
    if (_userId == null) {
      return (success: false, error: 'Не си влязъл в акаунта', tasksCount: 0, categoriesCount: 0);
    }

    try {
      final taskBox = Hive.box<Task>('tasks');
      final categoryBox = Hive.box<Category>('categories');

      // Изтриваме старите данни в облака
      final existingTasks = await _tasksRef!.get();
      for (final doc in existingTasks.docs) {
        await doc.reference.delete();
      }

      final existingCategories = await _categoriesRef!.get();
      for (final doc in existingCategories.docs) {
        await doc.reference.delete();
      }

      // Качваме категориите
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

      // Качваме задачите
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
          'subtasks': task.subtasks,
          'uploadedAt': FieldValue.serverTimestamp(),
        });
        tasksCount++;
      }

      return (success: true, error: null, tasksCount: tasksCount, categoriesCount: categoriesCount);
    } catch (e) {
      return (success: false, error: e.toString(), tasksCount: 0, categoriesCount: 0);
    }
  }

  // Сваляне на данни от облака
  Future<({bool success, String? error, int tasksCount, int categoriesCount})> downloadFromCloud() async {
    if (_userId == null) {
      return (success: false, error: 'Не си влязъл в акаунта', tasksCount: 0, categoriesCount: 0);
    }

    try {
      final taskBox = Hive.box<Task>('tasks');
      final categoryBox = Hive.box<Category>('categories');

      // Изтриваме локалните данни
      await taskBox.clear();
      await categoryBox.clear();

      // Сваляме категориите
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

      // Сваляме задачите
      int tasksCount = 0;
      final tasksSnapshot = await _tasksRef!.get();
      for (final doc in tasksSnapshot.docs) {
        final data = doc.data();
        final task = Task(
          title: data['title'] as String,
          dueDate: DateTime.parse(data['dueDate'] as String),
          categoryId: data['categoryId'] as String,
          priority: data['priority'] as int? ?? 1,
          recurrence: data['recurrence'] as String?,
          reminder: data['reminder'] as String?,
          subtasks: (data['subtasks'] as List<dynamic>?)?.cast<String>(),
        );
        task.isCompleted = data['isCompleted'] as bool? ?? false;
        await taskBox.add(task);
        tasksCount++;
      }

      return (success: true, error: null, tasksCount: tasksCount, categoriesCount: categoriesCount);
    } catch (e) {
      return (success: false, error: e.toString(), tasksCount: 0, categoriesCount: 0);
    }
  }

  // Проверка дали има данни в облака
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