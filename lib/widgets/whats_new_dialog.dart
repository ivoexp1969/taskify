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
  static const int _build = 65;

  static const String _prefKey = 'whats_new_seen_build';

  /// Точките за текущата версия, по език.
  static const Map<String, List<String>> _items = {
    'bg': [
      '🎓 Ново „Обучение": режими Ученик и Студент — избери своя и следи важните дати.',
      '📅 Учебна програма по срокове/семестри; предупреждава при припокриващи се часове.',
      '⏳ Обратно броене до ваканции, изпити и ключови дати — на началния екран.',
    ],
    'en': [
      '🎓 New “Learning”: Pupil and Student modes — pick yours and track key dates.',
      '📅 Curriculum by term/semester; warns you about overlapping classes.',
      '⏳ Countdown to holidays, exams and key dates — right on your home screen.',
    ],
    'de': [
      '🎓 Neu „Bildung“: Modi Schüler und Student — wähle deinen und behalte Termine im Blick.',
      '📅 Lehrplan nach Halbjahr/Semester; warnt bei sich überschneidenden Stunden.',
      '⏳ Countdown bis Ferien, Prüfungen und wichtigen Terminen — auf dem Startbildschirm.',
    ],
    'fr': [
      '🎓 Nouveau « Éducation » : modes Élève et Étudiant — choisis le tien et suis tes dates.',
      '📅 Programme par trimestre/semestre ; alerte en cas de cours qui se chevauchent.',
      '⏳ Compte à rebours des vacances, examens et dates clés — sur l’accueil.',
    ],
    'it': [
      '🎓 Nuovo “Istruzione”: modalità Alunno e Studente — scegli la tua e segui le date.',
      '📅 Programma per periodo/semestre; avvisa in caso di lezioni sovrapposte.',
      '⏳ Conto alla rovescia per vacanze, esami e date chiave — nella home.',
    ],
    'el': [
      '🎓 Νέο «Εκπαίδευση»: λειτουργίες Μαθητή και Φοιτητή — διάλεξε τη δική σου.',
      '📅 Πρόγραμμα ανά τρίμηνο/εξάμηνο· προειδοποιεί για μαθήματα που επικαλύπτονται.',
      '⏳ Αντίστροφη μέτρηση για διακοπές, εξετάσεις και βασικές ημερομηνίες — στην αρχική.',
    ],
    'es': [
      '🎓 Nuevo “Educación”: modos Alumno y Estudiante — elige el tuyo y sigue las fechas.',
      '📅 Programa por trimestre/semestre; avisa de clases que se solapan.',
      '⏳ Cuenta atrás para vacaciones, exámenes y fechas clave — en el inicio.',
    ],
    'pt': [
      '🎓 Novo “Educação”: modos Aluno e Estudante — escolhe o teu e segue as datas.',
      '📅 Programa por período/semestre; avisa sobre aulas sobrepostas.',
      '⏳ Contagem para férias, exames e datas-chave — no ecrã inicial.',
    ],
    'ru': [
      '🎓 Новый «Обучение»: режимы Ученик и Студент — выбери свой и следи за датами.',
      '📅 Учебная программа по срокам/семестрам; предупреждает о накладках занятий.',
      '⏳ Обратный отсчёт до каникул, экзаменов и ключевых дат — на главном экране.',
    ],
    'tr': [
      '🎓 Yeni “Eğitim”: Öğrenci ve Üniversite modları — kendininkini seç, tarihleri takip et.',
      '📅 Döneme/yarıyıla göre ders programı; çakışan dersler için uyarır.',
      '⏳ Tatiller, sınavlar ve önemli tarihlere geri sayım — ana ekranda.',
    ],
    'ja': [
      '🎓 新しい「学び」：生徒モードと大学生モード — 自分に合った方を選んで重要な日を管理。',
      '📅 学期ごとの時間割。授業が重なると警告します。',
      '⏳ 休み・試験・重要な日までのカウントダウンをホーム画面に。',
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
