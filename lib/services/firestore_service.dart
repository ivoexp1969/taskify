// cloud_firestore е временно изключен за iOS съвместимост
class FirestoreService {
  FirestoreService._internal();
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;

  Future<({bool success, String? error, int tasksCount, int categoriesCount})> uploadToCloud() async {
    return (success: false, error: 'Cloud sync not available', tasksCount: 0, categoriesCount: 0);
  }

  Future<({bool success, String? error, int tasksCount, int categoriesCount})> downloadFromCloud() async {
    return (success: false, error: 'Cloud sync not available', tasksCount: 0, categoriesCount: 0);
  }

  Future<({int tasks, int categories})> getCloudDataCount() async {
    return (tasks: 0, categories: 0);
  }
}
