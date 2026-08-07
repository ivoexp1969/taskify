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
  static const int _build = 67;

  static const String _prefKey = 'whats_new_seen_build';

  /// Точките за текущата версия, по език.
  static const Map<String, List<String>> _items = {
    'bg': [
      '📚 Обновен таб „Обучение": профил, обратно броене, днешно разписание, задачи и изпити — на едно място.',
      '📅 „Днес" в разписанието маркира текущия и следващия ти час.',
      '📝 Днешните учебни задачи (домашни, есета, курсови) са под ръка.',
      '👥 Споделените групови задачи вече се виждат направо в списъка — секция „Споделени" с етикет на групата.',
    ],
    'en': [
      '📚 Refreshed “Learning” tab: profile, countdown, today’s schedule, tasks and exams — all in one place.',
      '📅 “Today” highlights your current and next class.',
      '📝 Today’s study tasks (homework, essays, coursework) at a glance.',
      '👥 Shared group tasks now appear right in your list — a “Shared” section labeled by group.',
    ],
    'de': [
      '📚 Überarbeiteter „Bildung“-Tab: Profil, Countdown, heutiger Stundenplan, Aufgaben und Prüfungen — an einem Ort.',
      '📅 „Heute“ hebt deine aktuelle und nächste Stunde hervor.',
      '📝 Heutige Lernaufgaben (Hausaufgaben, Aufsätze, Hausarbeiten) auf einen Blick.',
      '👥 Geteilte Gruppenaufgaben erscheinen jetzt direkt in deiner Liste — Bereich „Geteilt“ mit Gruppenlabel.',
    ],
    'fr': [
      '📚 Onglet « Éducation » repensé : profil, compte à rebours, emploi du temps du jour, tâches et examens — au même endroit.',
      '📅 « Aujourd’hui » met en avant ton cours actuel et le suivant.',
      '📝 Les tâches d’étude du jour (devoirs, dissertations, travaux) en un coup d’œil.',
      '👥 Les tâches de groupe partagées apparaissent dans ta liste — une section « Partagé » avec le nom du groupe.',
    ],
    'it': [
      '📚 Scheda “Istruzione” rinnovata: profilo, conto alla rovescia, orario di oggi, compiti ed esami — tutto insieme.',
      '📅 “Oggi” evidenzia la lezione attuale e la prossima.',
      '📝 I compiti di studio di oggi (compiti, saggi, tesine) a portata di mano.',
      '👥 Le attività di gruppo condivise ora sono nella tua lista — sezione “Condivisi” con l’etichetta del gruppo.',
    ],
    'el': [
      '📚 Ανανεωμένη καρτέλα «Εκπαίδευση»: προφίλ, αντίστροφη μέτρηση, σημερινό πρόγραμμα, εργασίες και εξετάσεις — μαζί.',
      '📅 Το «Σήμερα» τονίζει το τρέχον και το επόμενο μάθημά σου.',
      '📝 Οι σημερινές εργασίες (ασκήσεις, δοκίμια, εργασίες) με μια ματιά.',
      '👥 Οι κοινές εργασίες ομάδας εμφανίζονται τώρα στη λίστα σου — ενότητα «Κοινά» με ετικέτα ομάδας.',
    ],
    'es': [
      '📚 Pestaña “Educación” renovada: perfil, cuenta atrás, horario de hoy, tareas y exámenes — todo junto.',
      '📅 “Hoy” resalta tu clase actual y la siguiente.',
      '📝 Las tareas de estudio de hoy (deberes, ensayos, trabajos) a mano.',
      '👥 Las tareas de grupo compartidas ahora aparecen en tu lista — sección “Compartido” con la etiqueta del grupo.',
    ],
    'pt': [
      '📚 Separador “Educação” renovado: perfil, contagem decrescente, horário de hoje, tarefas e exames — num só lugar.',
      '📅 “Hoje” destaca a tua aula atual e a seguinte.',
      '📝 As tarefas de estudo de hoje (trabalhos de casa, ensaios, trabalhos) à mão.',
      '👥 As tarefas de grupo partilhadas aparecem agora na tua lista — secção “Partilhado” com o nome do grupo.',
    ],
    'ru': [
      '📚 Обновлённая вкладка «Обучение»: профиль, обратный отсчёт, расписание на сегодня, задачи и экзамены — в одном месте.',
      '📅 «Сегодня» выделяет текущее и следующее занятие.',
      '📝 Сегодняшние учебные задачи (домашние, эссе, курсовые) под рукой.',
      '👥 Общие задачи групп теперь видны прямо в списке — раздел «Общие» с меткой группы.',
    ],
    'tr': [
      '📚 Yenilenen “Eğitim” sekmesi: profil, geri sayım, bugünkü program, görevler ve sınavlar — tek yerde.',
      '📅 “Bugün” mevcut ve sıradaki dersini vurgular.',
      '📝 Bugünkü çalışma görevleri (ödev, deneme, dönem ödevi) elinin altında.',
      '👥 Paylaşılan grup görevleri artık listende — grup etiketli “Paylaşılan” bölümü.',
    ],
    'ja': [
      '📚 「学び」タブを刷新：プロフィール、カウントダウン、今日の時間割、タスク、試験を一か所に。',
      '📅 「今日」が現在と次の授業を強調表示します。',
      '📝 今日の学習タスク（宿題・エッセイ・レポート）をすぐに確認。',
      '👥 共有グループのタスクがリストに直接表示 — グループ名付きの「共有」セクション。',
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
