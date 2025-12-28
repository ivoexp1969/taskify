import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui' as ui;

class AuthService {
  AuthService._internal();
  
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Текущ потребител
  User? get currentUser => _auth.currentUser;
  
  // Дали е логнат
  bool get isLoggedIn => _auth.currentUser != null;
  
  // Дали имейлът е верифициран
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;
  
  // Stream за промени в auth състоянието
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Задава езика за Firebase имейли
  void _setEmailLanguage([String? languageCode]) {
    final code = languageCode ?? ui.PlatformDispatcher.instance.locale.languageCode;
    _auth.setLanguageCode(code);
  }
  
  // Регистрация с email/парола
  Future<({bool success, String? error})> register({
    required String email,
    required String password,
    String? languageCode,
  }) async {
    try {
      // Задаваме езика преди регистрация
      _setEmailLanguage(languageCode);
      
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Изпращаме верификационен имейл
      await credential.user?.sendEmailVerification();
      
      return (success: true, error: null);
    } on FirebaseAuthException catch (e) {
      return (success: false, error: _getErrorMessage(e.code));
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }
  
  // Вход с email/парола
  Future<({bool success, String? error, bool needsVerification})> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Проверяваме дали имейлът е верифициран
      if (credential.user != null && !credential.user!.emailVerified) {
        return (success: false, error: 'Моля, потвърдете имейла си', needsVerification: true);
      }
      
      return (success: true, error: null, needsVerification: false);
    } on FirebaseAuthException catch (e) {
      return (success: false, error: _getErrorMessage(e.code), needsVerification: false);
    } catch (e) {
      return (success: false, error: e.toString(), needsVerification: false);
    }
  }
  
  // Повторно изпращане на верификационен имейл
  Future<({bool success, String? error})> resendVerificationEmail([String? languageCode]) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return (success: false, error: 'Няма логнат потребител');
      }
      
      if (user.emailVerified) {
        return (success: false, error: 'Имейлът вече е потвърден');
      }
      
      // Задаваме езика преди изпращане
      _setEmailLanguage(languageCode);
      
      await user.sendEmailVerification();
      return (success: true, error: null);
    } on FirebaseAuthException catch (e) {
      return (success: false, error: _getErrorMessage(e.code));
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }
  
  // Проверка дали имейлът е верифициран (с reload)
  Future<bool> checkEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }
  
  // Изход
  Future<void> logout() async {
    await _auth.signOut();
  }
  
  // Забравена парола
  Future<({bool success, String? error})> resetPassword(String email, [String? languageCode]) async {
    try {
      // Задаваме езика преди изпращане
      _setEmailLanguage(languageCode);
      
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
