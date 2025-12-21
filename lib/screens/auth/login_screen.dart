import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../utils/localization.dart';

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final result = _isLogin
        ? await _authService.login(email: email, password: password)
        : await _authService.register(email: email, password: password);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _errorMessage = result.error);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Въведи имейл адрес');
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
        const SnackBar(
          content: Text('Изпратен е имейл за възстановяване на паролата'),
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
    final languageController = LanguageScope.of(context);
    final isBg = languageController.locale.languageCode == 'bg';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin 
            ? (isBg ? 'Вход' : 'Login') 
            : (isBg ? 'Регистрация' : 'Register')),
        actions: [
          if (widget.onSkip != null)
            TextButton(
              onPressed: widget.onSkip,
              child: Text(isBg ? 'Пропусни' : 'Skip'),
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
              // Икона
              Icon(
                Icons.task_alt_rounded,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              
              // Заглавие
              Text(
                'Taskify',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              Text(
                _isLogin
                    ? (isBg ? 'Влез в акаунта си' : 'Sign in to your account')
                    : (isBg ? 'Създай нов акаунт' : 'Create a new account'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Грешка
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
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

              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: isBg ? 'Имейл' : 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return isBg ? 'Въведи имейл' : 'Enter email';
                  }
                  if (!value.contains('@')) {
                    return isBg ? 'Невалиден имейл' : 'Invalid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Парола
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: isBg ? 'Парола' : 'Password',
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
                    return isBg ? 'Въведи парола' : 'Enter password';
                  }
                  if (!_isLogin && value.length < 6) {
                    return isBg ? 'Минимум 6 символа' : 'Minimum 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Забравена парола
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    child: Text(
                      isBg ? 'Забравена парола?' : 'Forgot password?',
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Бутон
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
                          _isLogin
                              ? (isBg ? 'Вход' : 'Login')
                              : (isBg ? 'Регистрация' : 'Register'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Превключване вход/регистрация
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin
                        ? (isBg ? 'Нямаш акаунт?' : "Don't have an account?")
                        : (isBg ? 'Имаш акаунт?' : 'Already have an account?'),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                      _isLogin
                          ? (isBg ? 'Регистрирай се' : 'Register')
                          : (isBg ? 'Влез' : 'Login'),
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