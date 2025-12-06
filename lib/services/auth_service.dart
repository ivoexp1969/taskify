import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._internal();
  
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Текущ потребител
  User? get currentUser => _auth.currentUser;
  
  // Дали е логнат
  bool get isLoggedIn => _auth.currentUser != null;
  
  // Stream за промени в auth състоянието
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Регистрация с email/парола
  Future<({bool success, String? error})> register({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return (success: true, error: null);
    } on FirebaseAuthException catch (e) {
      return (success: false, error: _getErrorMessage(e.code));
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }
  
  // Вход с email/парола
  Future<({bool success, String? error})> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return (success: true, error: null);
    } on FirebaseAuthException catch (e) {
      return (success: false, error: _getErrorMessage(e.code));
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }
  
  // Изход
  Future<void> logout() async {
    await _auth.signOut();
  }
  
  // Забравена парола
  Future<({bool success, String? error})> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return (success: true, error: null);
    } on FirebaseAuthException catch (e) {
      return (success: false, error: _getErrorMessage(e.code));
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }
  
  // Превод на грешки
  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Този имейл вече е регистриран';
      case 'invalid-email':
        return 'Невалиден имейл адрес';
      case 'weak-password':
        return 'Паролата е твърде слаба (мин. 6 символа)';
      case 'user-not-found':
        return 'Няма потребител с този имейл';
      case 'wrong-password':
        return 'Грешна парола';
      case 'invalid-credential':
        return 'Грешен имейл или парола';
      case 'too-many-requests':
        return 'Твърде много опити. Опитай по-късно';
      case 'user-disabled':
        return 'Акаунтът е деактивиран';
      default:
        return 'Грешка: $code';
    }
  }
}