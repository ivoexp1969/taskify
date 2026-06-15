import 'package:flutter/material.dart';

import '../../utils/localization.dart';

/// Кратко, дружелюбно ръководство „Как се ползва" (подекран на Настройки →
/// „За приложението"). Тонът е на „ти", топъл и сбит — като раздела „България".
/// Стринговете са inline по език (както в settings_screen), без .arb.
class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = LanguageScope.of(context).locale.languageCode;
    final theme = Theme.of(context);

    String tr(Map<String, String> m) => m[lang] ?? m['en']!;

    const title = {
      'en': 'How to use', 'bg': 'Как се ползва', 'de': 'Anleitung',
      'fr': 'Comment ça marche', 'it': 'Come si usa', 'el': 'Πώς λειτουργεί',
      'es': 'Cómo se usa', 'pt': 'Como usar', 'ru': 'Как пользоваться',
      'tr': 'Nasıl kullanılır', 'ja': '使い方',
    };

    final items = <_HowToItem>[
      _HowToItem(
        icon: Icons.add_circle_outline,
        title: const {
          'en': 'Adding a task', 'bg': 'Добавяне на задача',
          'de': 'Aufgabe hinzufügen', 'fr': 'Ajouter une tâche',
          'it': "Aggiungere un'attività", 'el': 'Προσθήκη εργασίας',
          'es': 'Añadir una tarea', 'pt': 'Adicionar tarefa',
          'ru': 'Добавление задачи', 'tr': 'Görev ekleme', 'ja': 'タスクの追加',
        },
        body: const {
          'en':
              'Tap +, type your task. You can write in natural language too — "dentist tomorrow at 10" — and Taskify detects the date, time and category for you.',
          'bg':
              'Натисни +, напиши задачата. Можеш да пишеш и на естествен език — „зъболекар утре в 10" — и Taskify сам разпознава дата, час и категория.',
          'de':
              'Tippe auf +, schreibe deine Aufgabe. Du kannst auch in natürlicher Sprache schreiben — „Zahnarzt morgen um 10" — und Taskify erkennt Datum, Uhrzeit und Kategorie.',
          'fr':
              'Appuie sur +, écris ta tâche. Tu peux aussi écrire en langage naturel — « dentiste demain à 10h » — et Taskify détecte la date, l\'heure et la catégorie.',
          'it':
              'Tocca +, scrivi la tua attività. Puoi scrivere anche in linguaggio naturale — "dentista domani alle 10" — e Taskify riconosce data, ora e categoria.',
          'el':
              'Πάτησε +, γράψε την εργασία σου. Μπορείς να γράψεις και σε φυσική γλώσσα — «οδοντίατρος αύριο στις 10» — και το Taskify αναγνωρίζει ημερομηνία, ώρα και κατηγορία.',
          'es':
              'Toca +, escribe tu tarea. También puedes escribir en lenguaje natural — "dentista mañana a las 10" — y Taskify detecta la fecha, la hora y la categoría.',
          'pt':
              'Toca em +, escreve a tua tarefa. Também podes escrever em linguagem natural — "dentista amanhã às 10" — e o Taskify deteta a data, a hora e a categoria.',
          'ru':
              'Нажми +, напиши задачу. Можно писать и обычным языком — «зубной завтра в 10» — и Taskify сам определит дату, время и категорию.',
          'tr':
              '+ simgesine dokun, görevini yaz. Doğal dille de yazabilirsin — "yarın 10\'da dişçi" — Taskify tarihi, saati ve kategoriyi kendisi algılar.',
          'ja':
              '＋をタップしてタスクを入力します。「明日10時に歯医者」のように自然な言葉でも書け、Taskifyが日付・時刻・カテゴリを自動で認識します。',
        },
      ),
      _HowToItem(
        icon: Icons.checklist_rounded,
        title: const {
          'en': 'Subtasks & priority', 'bg': 'Подзадачи и приоритет',
          'de': 'Teilaufgaben & Priorität', 'fr': 'Sous-tâches et priorité',
          'it': 'Sotto-attività e priorità', 'el': 'Υποεργασίες & προτεραιότητα',
          'es': 'Subtareas y prioridad', 'pt': 'Subtarefas e prioridade',
          'ru': 'Подзадачи и приоритет', 'tr': 'Alt görevler ve öncelik',
          'ja': 'サブタスクと優先度',
        },
        body: const {
          'en':
              'Break a task into subtasks, set a priority, and make it repeat (daily, weekly, monthly).',
          'bg':
              'Раздели задачата на подзадачи, задай приоритет и повторение (всеки ден, седмица или месец).',
          'de':
              'Teile eine Aufgabe in Teilaufgaben, setze eine Priorität und lass sie sich wiederholen (täglich, wöchentlich, monatlich).',
          'fr':
              'Divise une tâche en sous-tâches, définis une priorité et rends-la récurrente (jour, semaine, mois).',
          'it':
              "Suddividi un'attività in sotto-attività, imposta una priorità e rendila ricorrente (giorno, settimana, mese).",
          'el':
              'Χώρισε μια εργασία σε υποεργασίες, όρισε προτεραιότητα και κάν\' την επαναλαμβανόμενη (ημέρα, εβδομάδα, μήνα).',
          'es':
              'Divide una tarea en subtareas, asigna una prioridad y hazla recurrente (diaria, semanal, mensual).',
          'pt':
              'Divide uma tarefa em subtarefas, define uma prioridade e torna-a recorrente (diária, semanal, mensal).',
          'ru':
              'Раздели задачу на подзадачи, задай приоритет и повтор (ежедневно, еженедельно, ежемесячно).',
          'tr':
              'Bir görevi alt görevlere böl, öncelik ata ve tekrarlanmasını sağla (günlük, haftalık, aylık).',
          'ja': 'タスクをサブタスクに分け、優先度を設定し、繰り返し（毎日・毎週・毎月）にできます。',
        },
      ),
      _HowToItem(
        icon: Icons.grid_view_rounded,
        title: const {
          'en': 'Eisenhower matrix', 'bg': 'Матрица на Айзенхауер',
          'de': 'Eisenhower-Matrix', 'fr': "Matrice d'Eisenhower",
          'it': 'Matrice di Eisenhower', 'el': 'Πίνακας Eisenhower',
          'es': 'Matriz de Eisenhower', 'pt': 'Matriz de Eisenhower',
          'ru': 'Матрица Эйзенхауэра', 'tr': 'Eisenhower matrisi',
          'ja': 'アイゼンハワーマトリクス',
        },
        body: const {
          'en': 'Sort your tasks by importance and urgency.',
          'bg': 'Подреди задачите по важност и спешност.',
          'de': 'Sortiere deine Aufgaben nach Wichtigkeit und Dringlichkeit.',
          'fr': 'Classe tes tâches par importance et urgence.',
          'it': 'Ordina le attività per importanza e urgenza.',
          'el': 'Ταξινόμησε τις εργασίες σου κατά σημασία και επείγον.',
          'es': 'Ordena tus tareas por importancia y urgencia.',
          'pt': 'Organiza as tuas tarefas por importância e urgência.',
          'ru': 'Сортируй задачи по важности и срочности.',
          'tr': 'Görevlerini önem ve aciliyete göre sırala.',
          'ja': 'タスクを重要度と緊急度で整理できます。',
        },
      ),
      _HowToItem(
        icon: Icons.event_rounded,
        title: const {
          'en': 'Calendar & sync', 'bg': 'Календар и синхронизация',
          'de': 'Kalender & Synchronisierung',
          'fr': 'Calendrier et synchronisation',
          'it': 'Calendario e sincronizzazione', 'el': 'Ημερολόγιο & συγχρονισμός',
          'es': 'Calendario y sincronización', 'pt': 'Calendário e sincronização',
          'ru': 'Календарь и синхронизация', 'tr': 'Takvim ve eşitleme',
          'ja': 'カレンダーと同期',
        },
        body: const {
          'en':
              'See everything in the calendar and connect Google Calendar with a single switch.',
          'bg':
              'Виж всичко в календара и свържи Google Calendar с един превключвател.',
          'de':
              'Sieh alles im Kalender und verbinde Google Kalender mit einem einzigen Schalter.',
          'fr':
              'Vois tout dans le calendrier et connecte Google Agenda avec un seul interrupteur.',
          'it':
              'Vedi tutto nel calendario e collega Google Calendar con un solo interruttore.',
          'el':
              'Δες τα πάντα στο ημερολόγιο και σύνδεσε το Google Calendar με έναν διακόπτη.',
          'es':
              'Ve todo en el calendario y conecta Google Calendar con un solo interruptor.',
          'pt':
              'Vê tudo no calendário e liga o Google Calendar com um único interruptor.',
          'ru':
              'Смотри всё в календаре и подключи Google Календарь одним переключателем.',
          'tr':
              "Her şeyi takvimde gör ve tek bir düğmeyle Google Takvim'i bağla.",
          'ja': 'すべてをカレンダーで確認でき、スイッチひとつでGoogleカレンダーと連携できます。',
        },
      ),
      _HowToItem(
        icon: Icons.flag_rounded,
        title: const {
          'en': 'Holidays, name days & documents',
          'bg': 'Празници, именни дни и документи',
          'de': 'Feiertage, Namenstage & Dokumente',
          'fr': 'Jours fériés, fêtes & documents',
          'it': 'Festività, onomastici e documenti',
          'el': 'Αργίες, ονομαστικές & έγγραφα',
          'es': 'Festivos, onomásticas y documentos',
          'pt': 'Feriados, dias do nome e documentos',
          'ru': 'Праздники, именины и документы',
          'tr': 'Tatiller, isim günleri ve belgeler',
          'ja': '祝日・聖名祝日・書類',
        },
        body: const {
          'en':
              'Official holidays, Bulgarian name days, and reminders for expiring documents.',
          'bg':
              'Официални празници, български именни дни и напомняния за изтичащи документи.',
          'de':
              'Offizielle Feiertage, bulgarische Namenstage und Erinnerungen für ablaufende Dokumente.',
          'fr':
              'Jours fériés officiels, fêtes des prénoms bulgares et rappels pour les documents qui expirent.',
          'it':
              'Festività ufficiali, onomastici bulgari e promemoria per i documenti in scadenza.',
          'el':
              'Επίσημες αργίες, βουλγαρικές ονομαστικές εορτές και υπενθυμίσεις για έγγραφα που λήγουν.',
          'es':
              'Festivos oficiales, onomásticas búlgaras y recordatorios de documentos que caducan.',
          'pt':
              'Feriados oficiais, dias do nome búlgaros e lembretes de documentos a expirar.',
          'ru':
              'Официальные праздники, болгарские именины и напоминания об истекающих документах.',
          'tr':
              'Resmi tatiller, Bulgar isim günleri ve süresi dolan belgeler için hatırlatmalar.',
          'ja': '公式の祝日、ブルガリアの聖名祝日、期限切れ書類のリマインダー。',
        },
      ),
      _HowToItem(
        icon: Icons.groups_rounded,
        title: const {
          'en': 'Shared lists', 'bg': 'Споделени списъци', 'de': 'Geteilte Listen',
          'fr': 'Listes partagées', 'it': 'Liste condivise',
          'el': 'Κοινόχρηστες λίστες', 'es': 'Listas compartidas',
          'pt': 'Listas partilhadas', 'ru': 'Общие списки',
          'tr': 'Paylaşılan listeler', 'ja': '共有リスト',
        },
        body: const {
          'en': 'Create a group and invite your family with a code.',
          'bg': 'Създай група и покани близките си с код.',
          'de': 'Erstelle eine Gruppe und lade deine Liebsten mit einem Code ein.',
          'fr': 'Crée un groupe et invite tes proches avec un code.',
          'it': 'Crea un gruppo e invita i tuoi cari con un codice.',
          'el': 'Δημιούργησε ομάδα και κάλεσε τους δικούς σου με έναν κωδικό.',
          'es': 'Crea un grupo e invita a tus seres queridos con un código.',
          'pt': 'Cria um grupo e convida os teus com um código.',
          'ru': 'Создай группу и пригласи близких по коду.',
          'tr': 'Bir grup oluştur ve sevdiklerini bir kodla davet et.',
          'ja': 'グループを作成し、コードで家族を招待できます。',
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(tr(title))),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final item = items[i];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item.icon, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(item.title),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr(item.body),
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HowToItem {
  final IconData icon;
  final Map<String, String> title;
  final Map<String, String> body;
  const _HowToItem({
    required this.icon,
    required this.title,
    required this.body,
  });
}
