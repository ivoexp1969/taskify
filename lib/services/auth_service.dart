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
      return (success: false, error: _getErrorMessage(e.code, languageCode ?? 'en'));
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }

  // Вход с email/парола
  Future<({bool success, String? error, bool needsVerification})> login({
    required String email,
    required String password,
    String? languageCode,
  }) async {
    final lang = languageCode ?? 'en';
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Проверяваме дали имейлът е верифициран
      if (credential.user != null && !credential.user!.emailVerified) {
        return (success: false, error: _getErrorMessage('verify-email', lang), needsVerification: true);
      }

      return (success: true, error: null, needsVerification: false);
    } on FirebaseAuthException catch (e) {
      return (success: false, error: _getErrorMessage(e.code, lang), needsVerification: false);
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
      return (success: false, error: _getErrorMessage(e.code, languageCode ?? 'en'));
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
      return (success: false, error: _getErrorMessage(e.code, languageCode ?? 'en'));
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }

  // Превод на грешки — 10 езика
  String _getErrorMessage(String code, String lang) {
    final t = _authErrors[code] ?? _authErrors['default']!;
    return (t[lang] ?? t['en'])!.replaceAll('{code}', code);
  }

  static const Map<String, Map<String, String>> _authErrors = {
    'verify-email': {
      'en': 'Please verify your email address',
      'bg': 'Моля, потвърдете имейла си',
      'de': 'Bitte bestätigen Sie Ihre E-Mail-Adresse',
      'fr': 'Veuillez vérifier votre adresse e-mail',
      'it': 'Si prega di verificare il proprio indirizzo e-mail',
      'el': 'Παρακαλώ επαληθεύστε τη διεύθυνση email σας',
      'es': 'Por favor, verifica tu dirección de correo electrónico',
      'pt': 'Por favor, verifique seu endereço de e-mail',
      'ru': 'Пожалуйста, подтвердите ваш адрес электронной почты',
      'tr': 'Lütfen e-posta adresinizi doğrulayın',
    },
    'email-already-in-use': {
      'en': 'This email is already registered',
      'bg': 'Този имейл вече е регистриран',
      'de': 'Diese E-Mail ist bereits registriert',
      'fr': 'Cet e-mail est déjà enregistré',
      'it': 'Questa email è già registrata',
      'el': 'Αυτό το email είναι ήδη καταχωρημένο',
      'es': 'Este correo ya está registrado',
      'pt': 'Este e-mail já está registrado',
      'ru': 'Этот email уже зарегистрирован',
      'tr': 'Bu e-posta zaten kayıtlı',
    },
    'invalid-email': {
      'en': 'Invalid email address',
      'bg': 'Невалиден имейл адрес',
      'de': 'Ungültige E-Mail-Adresse',
      'fr': 'Adresse e-mail invalide',
      'it': 'Indirizzo email non valido',
      'el': 'Μη έγκυρη διεύθυνση email',
      'es': 'Dirección de correo electrónico inválida',
      'pt': 'Endereço de e-mail inválido',
      'ru': 'Неверный адрес электронной почты',
      'tr': 'Geçersiz e-posta adresi',
    },
    'weak-password': {
      'en': 'Password is too weak (min. 6 characters)',
      'bg': 'Паролата е твърде слаба (мин. 6 символа)',
      'de': 'Passwort zu schwach (mind. 6 Zeichen)',
      'fr': 'Mot de passe trop faible (min. 6 caractères)',
      'it': 'Password troppo debole (min. 6 caratteri)',
      'el': 'Ο κωδικός είναι πολύ αδύναμος (ελάχ. 6 χαρακτήρες)',
      'es': 'Contraseña demasiado débil (mín. 6 caracteres)',
      'pt': 'Senha muito fraca (mín. 6 caracteres)',
      'ru': 'Пароль слишком слабый (мин. 6 символов)',
      'tr': 'Şifre çok zayıf (en az 6 karakter)',
    },
    'user-not-found': {
      'en': 'No account found with this email',
      'bg': 'Няма потребител с този имейл',
      'de': 'Kein Konto mit dieser E-Mail gefunden',
      'fr': 'Aucun compte trouvé avec cet e-mail',
      'it': 'Nessun account trovato con questa email',
      'el': 'Δεν βρέθηκε λογαριασμός με αυτό το email',
      'es': 'No se encontró ninguna cuenta con este correo',
      'pt': 'Nenhuma conta encontrada com este e-mail',
      'ru': 'Аккаунт с этим email не найден',
      'tr': 'Bu e-posta ile hesap bulunamadı',
    },
    'wrong-password': {
      'en': 'Incorrect password',
      'bg': 'Грешна парола',
      'de': 'Falsches Passwort',
      'fr': 'Mot de passe incorrect',
      'it': 'Password errata',
      'el': 'Λανθασμένος κωδικός',
      'es': 'Contraseña incorrecta',
      'pt': 'Senha incorreta',
      'ru': 'Неверный пароль',
      'tr': 'Yanlış şifre',
    },
    'invalid-credential': {
      'en': 'Incorrect email or password',
      'bg': 'Грешен имейл или парола',
      'de': 'Falsche E-Mail oder falsches Passwort',
      'fr': 'E-mail ou mot de passe incorrect',
      'it': 'Email o password errata',
      'el': 'Λανθασμένο email ή κωδικός',
      'es': 'Correo o contraseña incorrectos',
      'pt': 'E-mail ou senha incorretos',
      'ru': 'Неверный email или пароль',
      'tr': 'Yanlış e-posta veya şifre',
    },
    'too-many-requests': {
      'en': 'Too many attempts. Please try again later',
      'bg': 'Твърде много опити. Опитай по-късно',
      'de': 'Zu viele Versuche. Bitte später erneut versuchen',
      'fr': 'Trop de tentatives. Réessayez plus tard',
      'it': 'Troppi tentativi. Riprova più tardi',
      'el': 'Πολλές προσπάθειες. Δοκιμάστε αργότερα',
      'es': 'Demasiados intentos. Por favor intenta más tarde',
      'pt': 'Muitas tentativas. Por favor, tente mais tarde',
      'ru': 'Слишком много попыток. Попробуйте позже',
      'tr': 'Çok fazla deneme. Lütfen daha sonra tekrar deneyin',
    },
    'user-disabled': {
      'en': 'This account has been disabled',
      'bg': 'Акаунтът е деактивиран',
      'de': 'Dieses Konto wurde deaktiviert',
      'fr': 'Ce compte a été désactivé',
      'it': 'Questo account è stato disabilitato',
      'el': 'Αυτός ο λογαριασμός έχει απενεργοποιηθεί',
      'es': 'Esta cuenta ha sido deshabilitada',
      'pt': 'Esta conta foi desativada',
      'ru': 'Этот аккаунт заблокирован',
      'tr': 'Bu hesap devre dışı bırakıldı',
    },
    'default': {
      'en': 'Error: {code}',
      'bg': 'Грешка: {code}',
      'de': 'Fehler: {code}',
      'fr': 'Erreur: {code}',
      'it': 'Errore: {code}',
      'el': 'Σφάλμα: {code}',
      'es': 'Error: {code}',
      'pt': 'Erro: {code}',
      'ru': 'Ошибка: {code}',
      'tr': 'Hata: {code}',
    },
  };
}
