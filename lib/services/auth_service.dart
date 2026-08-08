import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;

class AuthService {
  AuthService._internal();

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // На някои Android устройства (Samsung/Redmi/Honor…) firebase_auth НЕ пази
  // сесията между рестарти — известен wontfix бъг (flutterfire #17971):
  // authStateChanges emit-ва null след cold start. Затова пазим credentials в
  // Keystore-базирано сигурно хранилище и при старт правим тих повторен вход.
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kEmail = 'auth_saved_email';
  static const _kPass = 'auth_saved_password';

  Future<void> _saveCredentials(String email, String password) async {
    try {
      await _secure.write(key: _kEmail, value: email);
      await _secure.write(key: _kPass, value: password);
    } catch (e) {
      debugPrint('Save credentials failed: $e');
    }
  }

  Future<void> _clearCredentials() async {
    try {
      await _secure.delete(key: _kEmail);
      await _secure.delete(key: _kPass);
    } catch (e) {
      debugPrint('Clear credentials failed: $e');
    }
  }

  /// Публично чистене на запазените credentials (напр. при изтриване на акаунт).
  Future<void> clearSavedCredentials() => _clearCredentials();

  /// Тих повторен вход при старт, ако firebase_auth е „забравил" сесията.
  /// Не показва UI, не блокира — извиква се fire-and-forget от main().
  /// Връща true ако сесията е възстановена.
  Future<bool> tryRestoreSession() async {
    if (kIsWeb) return false;
    if (_auth.currentUser != null) return true;
    try {
      final email = await _secure.read(key: _kEmail);
      final password = await _secure.read(key: _kPass);
      if (email == null || password == null) return false;
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred.user != null;
    } catch (e) {
      debugPrint('Silent session restore failed: $e');
      return false;
    }
  }
  
  // Текущ потребител
  User? get currentUser => _auth.currentUser;

  /// Името за показване (от Auth displayName). Празно ако не е зададено.
  String get displayName => _auth.currentUser?.displayName ?? '';

  /// Задава име за показване (в Auth profile). Връща true при успех.
  Future<bool> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.updateDisplayName(name.trim());
      await user.reload();
      return true;
    } catch (e) {
      debugPrint('updateDisplayName failed: $e');
      return false;
    }
  }
  
  // Дали е логнат с РЕАЛЕН акаунт. Анонимните сесии (създадени само за да се
  // логне affiliate клик — виж [ensureAuthedForLogging]) НЕ се броят за логнати:
  // те не синхронизират лични данни и не отключват акаунт-функции.
  bool get isLoggedIn =>
      _auth.currentUser != null && !_auth.currentUser!.isAnonymous;

  /// Дали текущата сесия е анонимна (създадена за attribution лог).
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  /// Гарантира auth контекст за писане на некритичен лог (напр. affiliate
  /// клик в `renewal_clicks`, чиито правила искат `request.auth != null`).
  /// Ако вече има сесия (реална или анонимна) → нищо. Иначе прави ТИХ анонимен
  /// вход. Guard-нат: при неуспех (офлайн / изключен доставчик) връща false и
  /// извикващият просто пропуска отдалечения лог. Не се ползва на web.
  Future<bool> ensureAuthedForLogging() async {
    if (kIsWeb) return _auth.currentUser != null;
    if (_auth.currentUser != null) return true;
    try {
      final cred = await _auth.signInAnonymously();
      return cred.user != null;
    } catch (e) {
      debugPrint('Anonymous sign-in for logging failed: $e');
      return false;
    }
  }
  
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
      
      final credential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 20));

      // Изпращаме верификационен имейл
      await credential.user?.sendEmailVerification();

      return (success: true, error: null);
    } on TimeoutException {
      return (success: false, error: _getErrorMessage('timeout', languageCode ?? 'en'));
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
      // ★Таймаут★: firebase_auth понякога ВИСИ безкрайно (reCAPTCHA/Play
      // Integrity с празен токен при нерегистриран SHA, или мрежов проблем) →
      // без таймаут спинърът се върти вечно и екранът „забива". 20s е достатъчно
      // за нормален вход; иначе хвърля TimeoutException → приятелско съобщение.
      final credential = await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 20));

      // Проверяваме дали имейлът е верифициран
      if (credential.user != null && !credential.user!.emailVerified) {
        return (success: false, error: _getErrorMessage('verify-email', lang), needsVerification: true);
      }

      // Пазим credentials за тих повторен вход при старт (виж tryRestoreSession).
      await _saveCredentials(email, password);

      return (success: true, error: null, needsVerification: false);
    } on TimeoutException {
      return (success: false, error: _getErrorMessage('timeout', lang), needsVerification: false);
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
    await _clearCredentials();
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
      'tr': 'Lütfen e-posta adresinizi doğrulayın', 'ja': 'メールアドレスを認証してください',
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
      'tr': 'Bu e-posta zaten kayıtlı', 'ja': 'このメールはすでに登録されています',
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
      'tr': 'Geçersiz e-posta adresi', 'ja': '無効なメールアドレス',
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
      'tr': 'Şifre çok zayıf (en az 6 karakter)', 'ja': 'パスワードが弱すぎます（最低6文字）',
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
      'tr': 'Bu e-posta ile hesap bulunamadı', 'ja': 'このメールのアカウントが見つかりません',
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
      'tr': 'Yanlış şifre', 'ja': 'パスワードが正しくありません',
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
      'tr': 'Yanlış e-posta veya şifre', 'ja': 'メールアドレスまたはパスワードが正しくありません',
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
      'tr': 'Çok fazla deneme. Lütfen daha sonra tekrar deneyin', 'ja': '試行回数が多すぎます。後でもう一度お試しください',
    },
    // Firebase Auth понякога виси (напр. reCAPTCHA/Play Integrity с празен
    // токен при неригистриран SHA или мрежов проблем) → таймаутът връща това.
    'timeout': {
      'en': 'Sign-in is taking too long. Check your connection and try again.',
      'bg': 'Входът се бави твърде дълго. Провери връзката и опитай пак.',
      'de': 'Die Anmeldung dauert zu lange. Prüfe deine Verbindung und versuche es erneut.',
      'fr': 'La connexion prend trop de temps. Vérifiez votre connexion et réessayez.',
      'it': "L'accesso richiede troppo tempo. Controlla la connessione e riprova.",
      'el': 'Η σύνδεση αργεί πολύ. Ελέγξτε τη σύνδεσή σας και δοκιμάστε ξανά.',
      'es': 'El inicio de sesión tarda demasiado. Revisa tu conexión e inténtalo de nuevo.',
      'pt': 'O login está a demorar muito. Verifica a ligação e tenta novamente.',
      'ru': 'Вход занимает слишком много времени. Проверьте соединение и повторите.',
      'tr': 'Giriş çok uzun sürüyor. Bağlantını kontrol edip tekrar dene.',
      'ja': 'ログインに時間がかかっています。接続を確認してもう一度お試しください。',
    },
    'network-request-failed': {
      'en': 'Network error. Check your connection and try again.',
      'bg': 'Мрежова грешка. Провери връзката и опитай пак.',
      'de': 'Netzwerkfehler. Prüfe deine Verbindung und versuche es erneut.',
      'fr': 'Erreur réseau. Vérifiez votre connexion et réessayez.',
      'it': 'Errore di rete. Controlla la connessione e riprova.',
      'el': 'Σφάλμα δικτύου. Ελέγξτε τη σύνδεσή σας και δοκιμάστε ξανά.',
      'es': 'Error de red. Revisa tu conexión e inténtalo de nuevo.',
      'pt': 'Erro de rede. Verifica a ligação e tenta novamente.',
      'ru': 'Ошибка сети. Проверьте соединение и повторите.',
      'tr': 'Ağ hatası. Bağlantını kontrol edip tekrar dene.',
      'ja': 'ネットワークエラー。接続を確認してもう一度お試しください。',
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
      'tr': 'Bu hesap devre dışı bırakıldı', 'ja': 'このアカウントは無効化されています',
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
      'tr': 'Hata: {code}', 'ja': 'エラー: {code}',
    },
  };
}
