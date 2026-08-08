import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// „Какво ново" — изскачащ прозорец, който се показва ВЕДНЪЖ след ъпдейт до
/// нова версия (и на Android, и на iOS). Потребителите не четат release notes
/// в магазина → ако не го обявим вътре в приложението, новите функции остават
/// неоткрити.
///
/// ★ПРИ ВСЕКИ РЕЛИЙЗ★ (преди `flutter build appbundle` / Xcode archive):
///   1) вдигни [_build] на новия versionCode от `pubspec.yaml`;
///   2) подмени [_items] с точките за новата версия (11 езика).
///
/// Нови инсталации НЕ го виждат (те виждат welcome диалога).
class WhatsNewDialog {
  /// Билдът, за който са точките по-долу (= `pubspec.yaml` build number).
  static const int _build = 68;

  static const String _prefKey = 'whats_new_seen_build';

  /// Точките за текущата версия, по език.
  static const Map<String, List<String>> _items = {
    'bg': [
      '✅ Отметнеш ли всички подзадачи, задачата се завършва автоматично — и при личните, и при споделените.',
      '👥 Завършените споделени задачи вече изчезват от секцията „Споделени".',
      '🔑 Върнат вход с имейл и парола в Профил + вече не забива при бавна връзка.',
    ],
    'en': [
      '✅ Check off all subtasks and the task auto-completes — for personal and shared tasks alike.',
      '👥 Completed shared tasks now leave the “Shared” section.',
      '🔑 Email & password sign-in is back in Profile — and no longer freezes on a slow connection.',
    ],
    'de': [
      '✅ Alle Unteraufgaben abgehakt → die Aufgabe wird automatisch erledigt — bei eigenen und geteilten.',
      '👥 Erledigte geteilte Aufgaben verlassen jetzt den Bereich „Geteilt“.',
      '🔑 Anmeldung mit E-Mail und Passwort ist zurück im Profil — und friert bei langsamer Verbindung nicht mehr ein.',
    ],
    'fr': [
      '✅ Coche toutes les sous-tâches et la tâche se termine automatiquement — pour les tâches perso et partagées.',
      '👥 Les tâches partagées terminées quittent désormais la section « Partagé ».',
      '🔑 La connexion par e-mail et mot de passe est de retour dans le Profil — et ne se fige plus sur une connexion lente.',
    ],
    'it': [
      '✅ Spunta tutte le attività secondarie e l’attività si completa da sola — sia personali che condivise.',
      '👥 Le attività condivise completate ora lasciano la sezione “Condivisi”.',
      '🔑 L’accesso con email e password è tornato nel Profilo — e non si blocca più con una connessione lenta.',
    ],
    'el': [
      '✅ Τσέκαρε όλες τις υποεργασίες και η εργασία ολοκληρώνεται αυτόματα — σε προσωπικές και κοινές.',
      '👥 Οι ολοκληρωμένες κοινές εργασίες φεύγουν πλέον από την ενότητα «Κοινά».',
      '🔑 Η σύνδεση με email και κωδικό επέστρεψε στο Προφίλ — και δεν κολλάει πια σε αργή σύνδεση.',
    ],
    'es': [
      '✅ Marca todas las subtareas y la tarea se completa sola — tanto en personales como compartidas.',
      '👥 Las tareas compartidas completadas ahora salen de la sección “Compartido”.',
      '🔑 El inicio de sesión con correo y contraseña vuelve al Perfil — y ya no se congela con conexión lenta.',
    ],
    'pt': [
      '✅ Marca todas as subtarefas e a tarefa conclui-se sozinha — nas pessoais e nas partilhadas.',
      '👥 As tarefas partilhadas concluídas saem agora da secção “Partilhado”.',
      '🔑 O início de sessão com email e palavra-passe voltou ao Perfil — e já não bloqueia com ligação lenta.',
    ],
    'ru': [
      '✅ Отметьте все подзадачи — и задача завершится автоматически, как в личных, так и в общих.',
      '👥 Завершённые общие задачи теперь исчезают из раздела «Общие».',
      '🔑 Вход по email и паролю вернулся в Профиль — и больше не зависает при медленном соединении.',
    ],
    'tr': [
      '✅ Tüm alt görevleri işaretle, görev otomatik tamamlansın — kişisel ve paylaşılan görevlerde.',
      '👥 Tamamlanan paylaşılan görevler artık “Paylaşılan” bölümünden ayrılıyor.',
      '🔑 E-posta ve şifre ile giriş Profil’e geri döndü — ve yavaş bağlantıda artık donmuyor.',
    ],
    'ja': [
      '✅ すべてのサブタスクにチェックを入れると、タスクが自動的に完了します（個人・共有どちらも）。',
      '👥 完了した共有タスクが「共有」セクションから消えるようになりました。',
      '🔑 メールとパスワードでのサインインがプロフィールに復活 — 低速回線でも固まらなくなりました。',
    ],
  };

  static const Map<String, String> _title = {
    'en': "What's new", 'bg': 'Какво ново', 'de': 'Was ist neu',
    'fr': 'Quoi de neuf', 'it': 'Novità', 'el': 'Τι νέο υπάρχει',
    'es': 'Novedades', 'pt': 'Novidades', 'ru': 'Что нового',
    'tr': 'Yenilikler', 'ja': '新着情報',
  };

  static const Map<String, String> _button = {
    'en': 'Got it!', 'bg': 'Супер!', 'de': 'Super!', 'fr': 'Compris!',
    'it': 'Ottimo!', 'el': 'Τέλεια!', 'es': '¡Genial!', 'pt': 'Ótimo!',
    'ru': 'Отлично!', 'tr': 'Harika!', 'ja': '了解！',
  };

  /// Показва диалога веднъж за текущия билд. Безопасно при повторно извикване.
  static Future<void> maybeShow(BuildContext context, String lang) async {
    if (kIsWeb) return;

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getInt(_prefKey) ?? 0;
    if (seen >= _build) return;

    // Нова инсталация (никога не е стигала до welcome диалога) → само отбелязваме
    // билда; тя няма „ново", тя е нова.
    final freshInstall =
        seen == 0 && !(prefs.getBool('taskify_welcome_shown_v2') ?? false);
    await prefs.setInt(_prefKey, _build);
    if (freshInstall) return;

    String version = '';
    try {
      version = (await PackageInfo.fromPlatform()).version;
    } catch (_) {/* без версия в заглавието */}

    if (!context.mounted) return;

    final items = _items[lang] ?? _items['en']!;
    final title = _title[lang] ?? _title['en']!;
    final button = _button[lang] ?? _button['en']!;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.auto_awesome, size: 44, color: Colors.amber),
        title: Text(version.isEmpty ? title : '$title — $version'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3, right: 8),
                        child: Icon(Icons.check_circle, size: 18,
                            color: Colors.green),
                      ),
                      Expanded(child: Text(item)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(button),
          ),
        ],
      ),
    );
  }
}
