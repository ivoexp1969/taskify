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
  static const int _build = 69;

  static const String _prefKey = 'whats_new_seen_build';

  /// Точките за текущата версия, по език.
  static const Map<String, List<String>> _items = {
    'bg': [
      '🎓 Студентско разписание: въведи групата си и часове само за четни/нечетни седмици — виждаш точно тази седмица.',
      '🎨 По-подредено разписание: цветни часове по предмет, дни в табове и акцент „Сега / Следва".',
      '📅 Учебните дати (начало на семестъра, изпити…) вече се редактират с едно докосване.',
    ],
    'en': [
      '🎓 Student schedule: add your group and classes for even/odd weeks — you see exactly this week.',
      '🎨 Cleaner timetable: color-coded classes by subject, day tabs and a “Now / Next” highlight.',
      '📅 Study dates (semester start, exams…) can now be edited with a single tap.',
    ],
    'de': [
      '🎓 Studenten-Stundenplan: Gruppe eintragen und Kurse für gerade/ungerade Wochen — du siehst genau diese Woche.',
      '🎨 Übersichtlicher Plan: farbige Kurse nach Fach, Tage als Tabs und eine „Jetzt / Als Nächstes“-Hervorhebung.',
      '📅 Lern-Termine (Semesterbeginn, Prüfungen …) lassen sich jetzt mit einem Tippen bearbeiten.',
    ],
    'fr': [
      '🎓 Emploi du temps étudiant : ajoute ton groupe et tes cours pour les semaines paires/impaires — tu vois exactement cette semaine.',
      '🎨 Emploi du temps plus clair : cours colorés par matière, jours en onglets et un repère « Maintenant / À suivre ».',
      '📅 Les dates d’études (début de semestre, examens…) se modifient désormais d’un seul appui.',
    ],
    'it': [
      '🎓 Orario studente: aggiungi il tuo gruppo e le lezioni per settimane pari/dispari — vedi esattamente questa settimana.',
      '🎨 Orario più ordinato: lezioni colorate per materia, giorni a schede e un evidenziatore “Ora / Prossima”.',
      '📅 Le date di studio (inizio semestre, esami…) ora si modificano con un tocco.',
    ],
    'el': [
      '🎓 Πρόγραμμα φοιτητή: πρόσθεσε την ομάδα σου και μαθήματα για ζυγές/μονές εβδομάδες — βλέπεις ακριβώς αυτή την εβδομάδα.',
      '🎨 Πιο καθαρό πρόγραμμα: χρωματιστά μαθήματα ανά μάθημα, ημέρες σε καρτέλες και επισήμανση «Τώρα / Επόμενο».',
      '📅 Οι ημερομηνίες σπουδών (έναρξη εξαμήνου, εξετάσεις…) επεξεργάζονται πλέον με ένα άγγιγμα.',
    ],
    'es': [
      '🎓 Horario de estudiante: añade tu grupo y clases para semanas pares/impares — ves justo esta semana.',
      '🎨 Horario más claro: clases con color por asignatura, días en pestañas y un resaltado “Ahora / Siguiente”.',
      '📅 Las fechas de estudio (inicio de semestre, exámenes…) ya se editan con un toque.',
    ],
    'pt': [
      '🎓 Horário de estudante: adiciona o teu grupo e aulas para semanas pares/ímpares — vês exatamente esta semana.',
      '🎨 Horário mais claro: aulas coloridas por disciplina, dias em separadores e um destaque “Agora / A seguir”.',
      '📅 As datas de estudo (início do semestre, exames…) já se editam com um toque.',
    ],
    'ru': [
      '🎓 Студенческое расписание: укажи свою группу и занятия по чётным/нечётным неделям — видишь именно эту неделю.',
      '🎨 Понятнее расписание: занятия с цветом по предмету, дни во вкладках и подсветка «Сейчас / Далее».',
      '📅 Учебные даты (начало семестра, экзамены…) теперь редактируются одним касанием.',
    ],
    'tr': [
      '🎓 Öğrenci ders programı: grubunu ve çift/tek hafta derslerini ekle — tam bu haftayı görürsün.',
      '🎨 Daha derli toplu program: derse göre renkli dersler, sekmeli günler ve “Şimdi / Sıradaki” vurgusu.',
      '📅 Ders tarihleri (dönem başı, sınavlar…) artık tek dokunuşla düzenlenir.',
    ],
    'ja': [
      '🎓 大学生の時間割：グループと偶数/奇数週の授業を追加 — 今週の分だけが表示されます。',
      '🎨 見やすい時間割：科目ごとの色分け、日ごとのタブ、「今 / 次」のハイライト。',
      '📅 学習の日付（学期開始・試験など）がワンタップで編集できるようになりました。',
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
