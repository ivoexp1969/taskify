import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../../utils/localization.dart';

// 10-language maps for login screen
const _s = {
  'login': {'en': 'Login', 'bg': 'Вход', 'de': 'Anmelden', 'fr': 'Connexion', 'it': 'Accedi', 'el': 'Σύνδεση', 'es': 'Iniciar sesión', 'pt': 'Entrar', 'ru': 'Вход', 'tr': 'Giriş', 'ja': 'ログイン'},
  'register': {'en': 'Register', 'bg': 'Регистрация', 'de': 'Registrieren', 'fr': "S'inscrire", 'it': 'Registrati', 'el': 'Εγγραφή', 'es': 'Registrarse', 'pt': 'Registrar', 'ru': 'Регистрация', 'tr': 'Kayıt ol', 'ja': '登録'},
  'skip': {'en': 'Skip', 'bg': 'Пропусни', 'de': 'Überspringen', 'fr': 'Passer', 'it': 'Salta', 'el': 'Παράλειψη', 'es': 'Omitir', 'pt': 'Pular', 'ru': 'Пропустить', 'tr': 'Atla', 'ja': 'スキップ'},
  'signIn': {'en': 'Sign in to your account', 'bg': 'Влез в акаунта си', 'de': 'In dein Konto einloggen', 'fr': 'Connectez-vous à votre compte', 'it': 'Accedi al tuo account', 'el': 'Συνδεθείτε στον λογαριασμό σας', 'es': 'Inicia sesión en tu cuenta', 'pt': 'Entre na sua conta', 'ru': 'Войдите в свой аккаунт', 'tr': 'Hesabınıza giriş yapın', 'ja': 'アカウントにサインイン'},
  'createAccount': {'en': 'Create a new account', 'bg': 'Създай нов акаунт', 'de': 'Neues Konto erstellen', 'fr': 'Créer un nouveau compte', 'it': 'Crea un nuovo account', 'el': 'Δημιουργία νέου λογαριασμού', 'es': 'Crear una nueva cuenta', 'pt': 'Criar uma nova conta', 'ru': 'Создать новый аккаунт', 'tr': 'Yeni hesap oluştur', 'ja': '新しいアカウントを作成'},
  'email': {'en': 'Email', 'bg': 'Имейл', 'de': 'E-Mail', 'fr': 'E-mail', 'it': 'Email', 'el': 'Email', 'es': 'Correo', 'pt': 'Email', 'ru': 'Эл. почта', 'tr': 'E-posta', 'ja': 'メール'},
  'enterEmail': {'en': 'Enter email', 'bg': 'Въведи имейл', 'de': 'E-Mail eingeben', 'fr': 'Entrez votre e-mail', 'it': 'Inserisci email', 'el': 'Εισάγετε email', 'es': 'Ingrese correo', 'pt': 'Digite email', 'ru': 'Введите email', 'tr': 'E-posta girin', 'ja': 'メールを入力'},
  'invalidEmail': {'en': 'Invalid email', 'bg': 'Невалиден имейл', 'de': 'Ungültige E-Mail', 'fr': 'E-mail invalide', 'it': 'Email non valida', 'el': 'Μη έγκυρο email', 'es': 'Correo inválido', 'pt': 'Email inválido', 'ru': 'Неверный email', 'tr': 'Geçersiz e-posta', 'ja': '無効なメール'},
  'password': {'en': 'Password', 'bg': 'Парола', 'de': 'Passwort', 'fr': 'Mot de passe', 'it': 'Password', 'el': 'Κωδικός', 'es': 'Contraseña', 'pt': 'Senha', 'ru': 'Пароль', 'tr': 'Şifre', 'ja': 'パスワード'},
  'enterPassword': {'en': 'Enter password', 'bg': 'Въведи парола', 'de': 'Passwort eingeben', 'fr': 'Entrez le mot de passe', 'it': 'Inserisci password', 'el': 'Εισάγετε κωδικό', 'es': 'Ingrese contraseña', 'pt': 'Digite senha', 'ru': 'Введите пароль', 'tr': 'Şifre girin', 'ja': 'パスワードを入力'},
  'min6': {'en': 'Minimum 6 characters', 'bg': 'Минимум 6 символа', 'de': 'Mindestens 6 Zeichen', 'fr': 'Minimum 6 caractères', 'it': 'Minimo 6 caratteri', 'el': 'Τουλάχιστον 6 χαρακτήρες', 'es': 'Mínimo 6 caracteres', 'pt': 'Mínimo 6 caracteres', 'ru': 'Минимум 6 символов', 'tr': 'En az 6 karakter', 'ja': '最低6文字'},
  'forgotPassword': {'en': 'Forgot password?', 'bg': 'Забравена парола?', 'de': 'Passwort vergessen?', 'fr': 'Mot de passe oublié?', 'it': 'Password dimenticata?', 'el': 'Ξεχάσατε τον κωδικό;', 'es': '¿Olvidó su contraseña?', 'pt': 'Esqueceu a senha?', 'ru': 'Забыли пароль?', 'tr': 'Şifrenizi mi unuttunuz?', 'ja': 'パスワードをお忘れですか？'},
  'noAccount': {'en': "Don't have an account?", 'bg': 'Нямаш акаунт?', 'de': 'Kein Konto?', 'fr': "Pas de compte?", 'it': 'Non hai un account?', 'el': 'Δεν έχετε λογαριασμό;', 'es': '¿No tienes cuenta?', 'pt': 'Não tem conta?', 'ru': 'Нет аккаунта?', 'tr': 'Hesabınız yok mu?', 'ja': 'アカウントをお持ちでないですか？'},
  'hasAccount': {'en': 'Already have an account?', 'bg': 'Имаш акаунт?', 'de': 'Bereits ein Konto?', 'fr': 'Déjà un compte?', 'it': 'Hai già un account?', 'el': 'Έχετε ήδη λογαριασμό;', 'es': '¿Ya tienes cuenta?', 'pt': 'Já tem conta?', 'ru': 'Уже есть аккаунт?', 'tr': 'Zaten hesabınız var mı?', 'ja': 'すでにアカウントをお持ちですか？'},
  'registerAction': {'en': 'Register', 'bg': 'Регистрирай се', 'de': 'Registrieren', 'fr': "S'inscrire", 'it': 'Registrati', 'el': 'Εγγραφή', 'es': 'Registrarse', 'pt': 'Registrar', 'ru': 'Зарегистрироваться', 'tr': 'Kayıt ol', 'ja': '登録'},
  'loginAction': {'en': 'Login', 'bg': 'Влез', 'de': 'Anmelden', 'fr': 'Se connecter', 'it': 'Accedi', 'el': 'Σύνδεση', 'es': 'Entrar', 'pt': 'Entrar', 'ru': 'Войти', 'tr': 'Giriş', 'ja': 'ログイン'},
  'verifyEmail': {'en': 'Verify Your Email', 'bg': 'Потвърдете имейла', 'de': 'E-Mail bestätigen', 'fr': 'Vérifiez votre e-mail', 'it': 'Verifica la tua email', 'el': 'Επιβεβαιώστε το email σας', 'es': 'Verifique su correo', 'pt': 'Verifique seu email', 'ru': 'Подтвердите email', 'tr': 'E-postanızı doğrulayın', 'ja': 'メールを認証してください'},
  'verifyBody': {'en': 'Please check your inbox and click the verification link before logging in.\n\n⚠️ Check your Spam folder too!', 'bg': 'Моля, проверете пощата си и кликнете на линка за потвърждение, преди да влезете.\n\n⚠️ Проверете и папка "Спам"!', 'de': 'Bitte prüfen Sie Ihren Posteingang und klicken Sie auf den Bestätigungslink.\n\n⚠️ Prüfen Sie auch den Spam-Ordner!', 'fr': 'Veuillez vérifier votre boîte de réception et cliquer sur le lien de vérification.\n\n⚠️ Vérifiez aussi le dossier Spam!', 'it': 'Controlla la posta e clicca sul link di verifica.\n\n⚠️ Controlla anche la cartella Spam!', 'el': 'Ελέγξτε τα εισερχόμενά σας και κάντε κλικ στον σύνδεσμο επαλήθευσης.\n\n⚠️ Ελέγξτε και τον φάκελο Spam!', 'es': 'Revise su bandeja de entrada y haga clic en el enlace de verificación.\n\n⚠️ Revise también la carpeta de Spam!', 'pt': 'Verifique sua caixa de entrada e clique no link de verificação.\n\n⚠️ Verifique também a pasta Spam!', 'ru': 'Проверьте почту и нажмите на ссылку подтверждения.\n\n⚠️ Проверьте также папку Спам!', 'tr': 'Gelen kutunuzu kontrol edin ve doğrulama bağlantısına tıklayın.\n\n⚠️ Spam klasörünü de kontrol edin!', 'ja': 'ログインする前に、受信トレイを確認して認証リンクをクリックしてください。\n\n⚠️ 迷惑メールフォルダもご確認ください！'},
  'resendEmail': {'en': 'Resend Email', 'bg': 'Изпрати отново', 'de': 'Erneut senden', 'fr': 'Renvoyer', 'it': 'Reinvia', 'el': 'Επαναποστολή', 'es': 'Reenviar', 'pt': 'Reenviar', 'ru': 'Отправить снова', 'tr': 'Tekrar gönder', 'ja': 'メールを再送'},
  'emailSent': {'en': 'Verification email sent', 'bg': 'Имейлът е изпратен отново', 'de': 'Bestätigungs-E-Mail gesendet', 'fr': 'E-mail de vérification envoyé', 'it': 'Email di verifica inviata', 'el': 'Το email επαλήθευσης στάλθηκε', 'es': 'Correo de verificación enviado', 'pt': 'Email de verificação enviado', 'ru': 'Письмо отправлено', 'tr': 'Doğrulama e-postası gönderildi', 'ja': '認証メールを送信しました'},
  'ok': {'en': 'OK', 'bg': 'Добре', 'de': 'OK', 'fr': 'OK', 'it': 'OK', 'el': 'OK', 'es': 'OK', 'pt': 'OK', 'ru': 'OK', 'tr': 'Tamam', 'ja': 'OK'},
  'error': {'en': 'Error', 'bg': 'Грешка', 'de': 'Fehler', 'fr': 'Erreur', 'it': 'Errore', 'el': 'Σφάλμα', 'es': 'Error', 'pt': 'Erro', 'ru': 'Ошибка', 'tr': 'Hata', 'ja': 'エラー'},
  'checkEmail': {'en': 'Check Your Email', 'bg': 'Проверете пощата си', 'de': 'Prüfen Sie Ihre E-Mail', 'fr': 'Vérifiez votre e-mail', 'it': 'Controlla la tua email', 'el': 'Ελέγξτε το email σας', 'es': 'Revise su correo', 'pt': 'Verifique seu email', 'ru': 'Проверьте почту', 'tr': 'E-postanızı kontrol edin', 'ja': 'メールを確認してください'},
  'goToLogin': {'en': 'Go to Login', 'bg': 'Към вход', 'de': 'Zum Login', 'fr': 'Aller à la connexion', 'it': 'Vai al login', 'el': 'Μετάβαση στη σύνδεση', 'es': 'Ir al inicio de sesión', 'pt': 'Ir para login', 'ru': 'Перейти к входу', 'tr': 'Girişe git', 'ja': 'ログインへ'},
  'enterEmailAddr': {'en': 'Enter email address', 'bg': 'Въведи имейл адрес', 'de': 'E-Mail-Adresse eingeben', 'fr': "Entrez l'adresse e-mail", 'it': 'Inserisci indirizzo email', 'el': 'Εισάγετε διεύθυνση email', 'es': 'Ingrese dirección de correo', 'pt': 'Digite endereço de email', 'ru': 'Введите адрес email', 'tr': 'E-posta adresi girin', 'ja': 'メールアドレスを入力'},
  'resetSent': {'en': 'Password reset email sent', 'bg': 'Изпратен е имейл за възстановяване на паролата', 'de': 'E-Mail zum Zurücksetzen gesendet', 'fr': 'E-mail de réinitialisation envoyé', 'it': 'Email di ripristino inviata', 'el': 'Στάλθηκε email επαναφοράς', 'es': 'Correo de restablecimiento enviado', 'pt': 'Email de redefinição enviado', 'ru': 'Письмо для сброса отправлено', 'tr': 'Şifre sıfırlama e-postası gönderildi', 'ja': 'パスワード再設定メールを送信しました'},
  'cloudFound': {'en': 'Cloud data found', 'bg': 'Намерени данни в облака', 'de': 'Cloud-Daten gefunden', 'fr': 'Données cloud trouvées', 'it': 'Dati cloud trovati', 'el': 'Βρέθηκαν δεδομένα στο cloud', 'es': 'Datos en la nube encontrados', 'pt': 'Dados na nuvem encontrados', 'ru': 'Найдены данные в облаке', 'tr': 'Bulut verileri bulundu', 'ja': 'クラウドデータが見つかりました'},
  'keepLocal': {'en': 'Keep local', 'bg': 'Запази локалните', 'de': 'Lokale behalten', 'fr': 'Garder local', 'it': 'Mantieni locali', 'el': 'Διατήρηση τοπικών', 'es': 'Mantener locales', 'pt': 'Manter locais', 'ru': 'Оставить локальные', 'tr': 'Yereli koru', 'ja': 'ローカルを保持'},
  'loadCloud': {'en': 'Load from cloud', 'bg': 'Зареди от облака', 'de': 'Aus Cloud laden', 'fr': 'Charger du cloud', 'it': 'Carica dal cloud', 'el': 'Φόρτωση από cloud', 'es': 'Cargar de la nube', 'pt': 'Carregar da nuvem', 'ru': 'Загрузить из облака', 'tr': 'Buluttan yükle', 'ja': 'クラウドから読込'},
  'cloudLoaded': {'en': 'Data loaded from cloud', 'bg': 'Данните са заредени от облака', 'de': 'Daten aus Cloud geladen', 'fr': 'Données chargées du cloud', 'it': 'Dati caricati dal cloud', 'el': 'Τα δεδομένα φορτώθηκαν από το cloud', 'es': 'Datos cargados de la nube', 'pt': 'Dados carregados da nuvem', 'ru': 'Данные загружены из облака', 'tr': 'Veriler buluttan yüklendi', 'ja': 'クラウドからデータを読み込みました'},
};

String _t(String key, String lang) => _s[key]?[lang] ?? _s[key]?['en'] ?? '';

String _regSuccessBody(String email, String lang) {
  const m = {
    'en': 'We sent a verification link to EMAIL.\n\nPlease click the link to activate your account.\n\n⚠️ Check your Spam folder if you don\'t see the email!',
    'bg': 'Изпратихме линк за потвърждение на EMAIL.\n\nМоля, кликнете на линка, за да активирате акаунта си.\n\n⚠️ Проверете и папка "Спам" ако не виждате имейла!',
    'de': 'Wir haben einen Bestätigungslink an EMAIL gesendet.\n\nBitte klicken Sie auf den Link.\n\n⚠️ Prüfen Sie auch den Spam-Ordner!',
    'fr': 'Nous avons envoyé un lien de vérification à EMAIL.\n\nCliquez sur le lien pour activer votre compte.\n\n⚠️ Vérifiez aussi le dossier Spam!',
    'it': 'Abbiamo inviato un link di verifica a EMAIL.\n\nClicca sul link per attivare il tuo account.\n\n⚠️ Controlla anche la cartella Spam!',
    'el': 'Στείλαμε σύνδεσμο επαλήθευσης στο EMAIL.\n\nΚάντε κλικ στον σύνδεσμο για να ενεργοποιήσετε τον λογαριασμό σας.\n\n⚠️ Ελέγξτε και τον φάκελο Spam!',
    'es': 'Enviamos un enlace de verificación a EMAIL.\n\nHaga clic en el enlace para activar su cuenta.\n\n⚠️ Revise también la carpeta de Spam!',
    'pt': 'Enviamos um link de verificação para EMAIL.\n\nClique no link para ativar sua conta.\n\n⚠️ Verifique também a pasta Spam!',
    'ru': 'Мы отправили ссылку для подтверждения на EMAIL.\n\nНажмите на ссылку, чтобы активировать аккаунт.\n\n⚠️ Проверьте также папку Спам!',
    'tr': 'EMAIL adresine doğrulama bağlantısı gönderdik.\n\nHesabınızı etkinleştirmek için bağlantıya tıklayın.\n\n⚠️ Spam klasörünü de kontrol edin!', 'ja': 'EMAILに認証リンクを送信しました。\n\nリンクをクリックしてアカウントを有効化してください。\n\n⚠️ メールが見つからない場合は迷惑メールフォルダをご確認ください！',
  };
  return (m[lang] ?? m['en']!).replaceAll('EMAIL', email);
}

class LoginScreen extends StatefulWidget {
  final VoidCallback? onSkip;
  
  const LoginScreen({super.key, this.onSkip});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _lang => LanguageScope.of(context).locale.languageCode;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isLogin) {
      final result = await _authService.login(email: email, password: password, languageCode: _lang);
      
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.success) {
        await _autoLoadFromCloud();
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else if (result.needsVerification) {
        _showVerificationDialog();
      } else {
        setState(() => _errorMessage = result.error);
      }
    } else {
      final result = await _authService.register(email: email, password: password, languageCode: _lang);
      
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.success) {
        _showRegistrationSuccessDialog();
      } else {
        setState(() => _errorMessage = result.error);
      }
    }
  }

  /// След успешен вход — слива локалните и облачните данни (merge, ФАЗА 2).
  /// Вече НЕ трие нищо и не пита „локални срещу облачни" — merge обединява двете
  /// по стабилен id, без загуба на данни в нито посока.
  Future<void> _autoLoadFromCloud() async {
    final lang = _lang;
    try {
      setState(() => _isLoading = true);
      final result = await SyncService().mergeWithCloud();
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (result.success &&
          (result.downloaded > 0 || result.uploaded > 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('cloudLoaded', lang)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      // Тихо — неуспешният merge не бива да блокира входа.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showVerificationDialog() {
    final lang = _lang;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('verifyEmail', lang)),
        content: Text(_t('verifyBody', lang)),
        actions: [
          TextButton(
            onPressed: () async {
              final result = await _authService.resendVerificationEmail();
              if (!mounted) return;
              Navigator.pop(ctx);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result.success
                        ? _t('emailSent', lang)
                        : (result.error ?? _t('error', lang)),
                  ),
                  backgroundColor: result.success ? Colors.green : Colors.red,
                ),
              );
            },
            child: Text(_t('resendEmail', lang)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('ok', lang)),
          ),
        ],
      ),
    );
  }

  void _showRegistrationSuccessDialog() {
    final lang = _lang;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.mark_email_read, size: 48, color: Colors.green),
        title: Text(_t('checkEmail', lang)),
        content: Text(_regSuccessBody(_emailController.text.trim(), lang)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _isLogin = true;
                _errorMessage = null;
              });
            },
            child: Text(_t('goToLogin', lang)),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword() async {
    final lang = _lang;
    
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      setState(() => _errorMessage = _t('enterEmailAddr', lang));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.resetPassword(email);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('resetSent', lang)),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() => _errorMessage = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = _lang;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? _t('login', lang) : _t('register', lang)),
        actions: [
          if (widget.onSkip != null)
            TextButton(
              onPressed: widget.onSkip,
              child: Text(_t('skip', lang)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.task_alt_rounded,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              
              Text(
                'Taskify',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              Text(
                _isLogin ? _t('signIn', lang) : _t('createAccount', lang),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: _t('email', lang),
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return _t('enterEmail', lang);
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return _t('invalidEmail', lang);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: _t('password', lang),
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword 
                          ? Icons.visibility_outlined 
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return _t('enterPassword', lang);
                  }
                  if (!_isLogin && value.length < 6) {
                    return _t('min6', lang);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    child: Text(_t('forgotPassword', lang)),
                  ),
                ),
              const SizedBox(height: 24),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isLogin ? _t('login', lang) : _t('register', lang),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin ? _t('noAccount', lang) : _t('hasAccount', lang),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isLogin = !_isLogin;
                              _errorMessage = null;
                            });
                          },
                    child: Text(
                      _isLogin ? _t('registerAction', lang) : _t('loginAction', lang),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
