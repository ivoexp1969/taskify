import 'package:flutter/material.dart';

import '../../models/school_calendar.dart';
import '../../models/university.dart';
import '../../services/school_calendar_service.dart';
import '../../services/university_service.dart';
import '../../utils/localization.dart';

/// Локализирани етикети за видовете студентски ключови дати (ползвани от
/// списъка, диалога за добавяне и картата за обратно броене).
const Map<StudentDateKind, Map<String, String>> kStudentDateKindLabels = {
  StudentDateKind.schoolYearStart: {
    'en': 'Start of school year', 'bg': 'Начало на учебната година',
    'de': 'Schuljahresbeginn', 'fr': "Début de l'année scolaire",
    'it': "Inizio dell'anno scolastico", 'el': 'Έναρξη σχολικής χρονιάς',
    'es': 'Inicio del año escolar', 'pt': 'Início do ano letivo',
    'ru': 'Начало учебного года', 'tr': 'Öğretim yılı başı', 'ja': '学年開始',
  },
  StudentDateKind.termStart: {
    'en': 'Start of term', 'bg': 'Начало на срок', 'de': 'Beginn des Halbjahres',
    'fr': 'Début du trimestre', 'it': 'Inizio del trimestre', 'el': 'Έναρξη τριμήνου',
    'es': 'Inicio del trimestre', 'pt': 'Início do período', 'ru': 'Начало четверти',
    'tr': 'Dönem başı', 'ja': '学期開始',
  },
  StudentDateKind.vacation: {
    'en': 'Vacation', 'bg': 'Ваканция', 'de': 'Ferien', 'fr': 'Vacances',
    'it': 'Vacanze', 'el': 'Διακοπές', 'es': 'Vacaciones', 'pt': 'Férias',
    'ru': 'Каникулы', 'tr': 'Tatil', 'ja': '休み',
  },
  StudentDateKind.semesterStart: {
    'en': 'Semester start', 'bg': 'Начало на семестър', 'de': 'Semesterbeginn',
    'fr': 'Début de semestre', 'it': 'Inizio semestre', 'el': 'Έναρξη εξαμήνου',
    'es': 'Inicio de semestre', 'pt': 'Início do semestre', 'ru': 'Начало семестра',
    'tr': 'Dönem başı', 'ja': '学期開始',
  },
  StudentDateKind.semesterEnd: {
    'en': 'Semester end', 'bg': 'Край на семестър', 'de': 'Semesterende',
    'fr': 'Fin de semestre', 'it': 'Fine semestre', 'el': 'Λήξη εξαμήνου',
    'es': 'Fin de semestre', 'pt': 'Fim do semestre', 'ru': 'Конец семестра',
    'tr': 'Dönem sonu', 'ja': '学期終了',
  },
  StudentDateKind.sessionStart: {
    'en': 'Exam session', 'bg': 'Начало на сесия', 'de': 'Prüfungszeit',
    'fr': "Session d'examens", 'it': "Sessione d'esami", 'el': 'Εξεταστική',
    'es': 'Periodo de exámenes', 'pt': 'Época de exames', 'ru': 'Начало сессии',
    'tr': 'Sınav dönemi', 'ja': '試験期間',
  },
  StudentDateKind.exam: {
    'en': 'Exam', 'bg': 'Изпит', 'de': 'Prüfung', 'fr': 'Examen', 'it': 'Esame',
    'el': 'Εξέταση', 'es': 'Examen', 'pt': 'Exame', 'ru': 'Экзамен',
    'tr': 'Sınav', 'ja': '試験',
  },
  StudentDateKind.other: {
    'en': 'Other', 'bg': 'Друго', 'de': 'Sonstiges', 'fr': 'Autre', 'it': 'Altro',
    'el': 'Άλλο', 'es': 'Otro', 'pt': 'Outro', 'ru': 'Другое', 'tr': 'Diğer',
    'ja': 'その他',
  },
};

/// Обединено събитие за списъка (ученическо или студентско).
class _Event {
  final DateTime date;
  final String title;
  final String emoji;
  final String? studentDateId; // != null → може да се трие (студентска дата)
  const _Event({
    required this.date,
    required this.title,
    required this.emoji,
    this.studentDateId,
  });
}

/// Пълен списък с предстоящи учебни събития (ваканции, край на година, НВО/ДЗИ
/// за Ученик + ръчните ключови дати за Студент). Отваря се при тап на картата за
/// обратно броене. За студенти позволява добавяне/триене на ключови дати.
class StudyEventsScreen extends StatefulWidget {
  const StudyEventsScreen({super.key});

  @override
  State<StudyEventsScreen> createState() => _StudyEventsScreenState();
}

class _StudyEventsScreenState extends State<StudyEventsScreen> {
  final _school = SchoolCalendarService();
  final _uni = UniversityService();

  static String _t(Map<String, String> m, String lang) => m[lang] ?? m['en']!;

  static const _title = {
    'en': 'Upcoming', 'bg': 'Предстоящи', 'de': 'Anstehend', 'fr': 'À venir',
    'it': 'In arrivo', 'el': 'Επόμενα', 'es': 'Próximos', 'pt': 'Próximos',
    'ru': 'Предстоящие', 'tr': 'Yaklaşan', 'ja': '予定',
  };
  static const _empty = {
    'en': 'No upcoming events yet.', 'bg': 'Още няма предстоящи събития.',
    'de': 'Noch keine anstehenden Ereignisse.', 'fr': 'Aucun événement à venir.',
    'it': 'Nessun evento in arrivo.', 'el': 'Δεν υπάρχουν επόμενα γεγονότα.',
    'es': 'Aún no hay eventos próximos.', 'pt': 'Ainda não há eventos.',
    'ru': 'Пока нет предстоящих событий.', 'tr': 'Henüz yaklaşan etkinlik yok.',
    'ja': '予定はまだありません。',
  };
  static const _addDate = {
    'en': 'Add key date', 'bg': 'Добави ключова дата', 'de': 'Termin hinzufügen',
    'fr': 'Ajouter une date', 'it': 'Aggiungi data', 'el': 'Προσθήκη ημερομηνίας',
    'es': 'Añadir fecha', 'pt': 'Adicionar data', 'ru': 'Добавить дату',
    'tr': 'Tarih ekle', 'ja': '日付を追加',
  };
  static const _todayWord = {
    'en': 'Today', 'bg': 'Днес', 'de': 'Heute', 'fr': "Aujourd'hui",
    'it': 'Oggi', 'el': 'Σήμερα', 'es': 'Hoy', 'pt': 'Hoje', 'ru': 'Сегодня',
    'tr': 'Bugün', 'ja': '今日',
  };
  static const _inDays = {
    'en': 'in {n} days', 'bg': 'след {n} дни', 'de': 'in {n} Tagen',
    'fr': 'dans {n} jours', 'it': 'tra {n} giorni', 'el': 'σε {n} μέρες',
    'es': 'en {n} días', 'pt': 'em {n} dias', 'ru': 'через {n} дн.',
    'tr': '{n} gün sonra', 'ja': 'あと{n}日',
  };
  static const _tomorrow = {
    'en': 'Tomorrow', 'bg': 'Утре', 'de': 'Morgen', 'fr': 'Demain',
    'it': 'Domani', 'el': 'Αύριο', 'es': 'Mañana', 'pt': 'Amanhã',
    'ru': 'Завтра', 'tr': 'Yarın', 'ja': '明日',
  };

  List<_Event> _collect() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final out = <_Event>[];

    // ── Ученик ──
    if (_school.enabled && _school.grade != null) {
      final g = _school.grade!;
      final year = _school.currentYear;
      if (year != null) {
        for (final v in year.vacationsFor(g)) {
          if (!v.start.isBefore(today)) {
            out.add(_Event(date: v.start, title: v.name, emoji: '🏖️'));
          }
        }
        final eoy = year.endOfYearFor(g);
        if (eoy != null && !eoy.isBefore(today)) {
          out.add(_Event(date: eoy, title: _summerLabel, emoji: '☀️'));
        }
        for (final e in year.upcomingExamsFor(g, today)) {
          out.add(_Event(date: e.date, title: e.name, emoji: '📝'));
        }
      }
    }

    // ── Ръчни ключови дати (общи за Ученик и Студент) ──
    for (final d in _uni.upcomingKeyDates(today)) {
      out.add(_Event(
        date: d.date,
        title: d.title.isNotEmpty ? d.title : _kindLabel(d.kind),
        emoji: _kindEmoji(d.kind),
        studentDateId: d.id,
      ));
    }

    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  String get _summerLabel {
    // Локализира се от картата; тук просто етикет по подразбиране.
    const m = {
      'en': 'Summer break', 'bg': 'Лятна ваканция', 'de': 'Sommerferien',
      'fr': "Vacances d'été", 'it': 'Vacanze estive', 'el': 'Καλοκαιρινές διακοπές',
      'es': 'Vacaciones de verano', 'pt': 'Férias de verão', 'ru': 'Летние каникулы',
      'tr': 'Yaz tatili', 'ja': '夏休み',
    };
    final lang = LanguageScope.of(context).locale.languageCode;
    return _t(m, lang);
  }

  String _kindEmoji(StudentDateKind k) {
    switch (k) {
      case StudentDateKind.schoolYearStart:
        return '🎒';
      case StudentDateKind.termStart:
        return '📅';
      case StudentDateKind.vacation:
        return '🏖️';
      case StudentDateKind.semesterStart:
        return '📅';
      case StudentDateKind.semesterEnd:
        return '🏁';
      case StudentDateKind.sessionStart:
        return '📚';
      case StudentDateKind.exam:
        return '📝';
      case StudentDateKind.other:
        return '⭐';
    }
  }

  String _kindLabel(StudentDateKind k) {
    final lang = LanguageScope.of(context).locale.languageCode;
    return _t(kStudentDateKindLabels[k]!, lang);
  }

  String _relative(String lang, DateTime date) {
    final n = daysBetween(DateTime.now(), date);
    if (n <= 0) return _t(_todayWord, lang);
    if (n == 1) return _t(_tomorrow, lang);
    return _t(_inDays, lang).replaceAll('{n}', '$n');
  }

  Future<void> _addKeyDate(String lang) async {
    final result = await showStudentKeyDateDialog(context, lang);
    if (result == null) return;
    await _uni.addKeyDate(
      title: result.title,
      date: result.date,
      kind: result.kind,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageScope.of(context).locale.languageCode;
    return AnimatedBuilder(
      animation: Listenable.merge([
        SchoolCalendarService.revision,
        UniversityService.revision,
      ]),
      builder: (context, _) {
        final events = _collect();
        final months = _months[lang] ?? _months['en']!;
        return Scaffold(
          appBar: AppBar(title: Text(_t(_title, lang))),
          floatingActionButton: (_school.enabled || _uni.enabled)
              ? FloatingActionButton.extended(
                  onPressed: () => _addKeyDate(lang),
                  icon: const Icon(Icons.add),
                  label: Text(_t(_addDate, lang)),
                )
              : null,
          body: events.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(_t(_empty, lang),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = events[i];
                    final dateStr =
                        '${e.date.day} ${months[e.date.month - 1]}';
                    return ListTile(
                      leading:
                          Text(e.emoji, style: const TextStyle(fontSize: 24)),
                      title: Text(e.title),
                      subtitle: Text('$dateStr · ${_relative(lang, e.date)}'),
                      trailing: e.studentDateId != null
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                await _uni.removeKeyDate(e.studentDateId!);
                                if (mounted) setState(() {});
                              },
                            )
                          : null,
                    );
                  },
                ),
        );
      },
    );
  }

  static const Map<String, List<String>> _months = {
    'en': ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'],
    'bg': ['яну','фев','мар','апр','май','юни','юли','авг','сеп','окт','ное','дек'],
    'de': ['Jan','Feb','März','Apr','Mai','Jun','Jul','Aug','Sep','Okt','Nov','Dez'],
    'fr': ['janv','févr','mars','avr','mai','juin','juil','août','sept','oct','nov','déc'],
    'it': ['gen','feb','mar','apr','mag','giu','lug','ago','set','ott','nov','dic'],
    'el': ['Ιαν','Φεβ','Μαρ','Απρ','Μαϊ','Ιουν','Ιουλ','Αυγ','Σεπ','Οκτ','Νοε','Δεκ'],
    'es': ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'],
    'pt': ['jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez'],
    'ru': ['янв','фев','мар','апр','мая','июн','июл','авг','сен','окт','ноя','дек'],
    'tr': ['Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'],
    'ja': ['1月','2月','3月','4月','5月','6月','7月','8月','9月','10月','11月','12月'],
  };
}

/// Резултат от диалога за добавяне на студентска ключова дата.
class StudentKeyDateInput {
  final String title;
  final DateTime date;
  final StudentDateKind kind;
  const StudentKeyDateInput(
      {required this.title, required this.date, required this.kind});
}

/// Диалог за добавяне на студентска ключова дата (тип + заглавие + дата).
Future<StudentKeyDateInput?> showStudentKeyDateDialog(
    BuildContext context, String lang) {
  String t(Map<String, String> m) => m[lang] ?? m['en']!;
  StudentDateKind kind = StudentDateKind.exam;
  final titleCtrl = TextEditingController();
  DateTime? date;

  const titleLabel = {
    'en': 'Title (optional)', 'bg': 'Заглавие (по избор)', 'de': 'Titel (optional)',
    'fr': 'Titre (facultatif)', 'it': 'Titolo (facoltativo)', 'el': 'Τίτλος (προαιρετικό)',
    'es': 'Título (opcional)', 'pt': 'Título (opcional)', 'ru': 'Название (необязательно)',
    'tr': 'Başlık (isteğe bağlı)', 'ja': 'タイトル（任意）',
  };
  const typeLabel = {
    'en': 'Type', 'bg': 'Тип', 'de': 'Typ', 'fr': 'Type', 'it': 'Tipo',
    'el': 'Τύπος', 'es': 'Tipo', 'pt': 'Tipo', 'ru': 'Тип', 'tr': 'Tür', 'ja': '種類',
  };
  const pickDate = {
    'en': 'Pick a date', 'bg': 'Избери дата', 'de': 'Datum wählen',
    'fr': 'Choisir une date', 'it': 'Scegli data', 'el': 'Επίλεξε ημερομηνία',
    'es': 'Elige fecha', 'pt': 'Escolhe data', 'ru': 'Выбери дату', 'tr': 'Tarih seç',
    'ja': '日付を選択',
  };
  const cancel = {
    'en': 'Cancel', 'bg': 'Отказ', 'de': 'Abbrechen', 'fr': 'Annuler',
    'it': 'Annulla', 'el': 'Άκυρο', 'es': 'Cancelar', 'pt': 'Cancelar',
    'ru': 'Отмена', 'tr': 'İptal', 'ja': 'キャンセル',
  };
  const add = {
    'en': 'Add', 'bg': 'Добави', 'de': 'Hinzufügen', 'fr': 'Ajouter',
    'it': 'Aggiungi', 'el': 'Προσθήκη', 'es': 'Añadir', 'pt': 'Adicionar',
    'ru': 'Добавить', 'tr': 'Ekle', 'ja': '追加',
  };

  return showDialog<StudentKeyDateInput>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setD) {
          final months = _StudyEventsScreenState._months[lang] ??
              _StudyEventsScreenState._months['en']!;
          final dateStr = date == null
              ? t(pickDate)
              : '${date!.day} ${months[date!.month - 1]} ${date!.year}';
          return AlertDialog(
            title: Text(t(_StudyEventsScreenState._addDate)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t(typeLabel),
                      style: Theme.of(ctx).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final k in StudentDateKind.values)
                        ChoiceChip(
                          label: Text(t(kStudentDateKindLabels[k]!)),
                          selected: kind == k,
                          onSelected: (_) => setD(() => kind = k),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: titleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: t(titleLabel),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(dateStr),
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date ?? now,
                        firstDate: DateTime(now.year - 1),
                        lastDate: DateTime(now.year + 3),
                      );
                      if (picked != null) setD(() => date = picked);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t(cancel)),
              ),
              FilledButton(
                onPressed: date == null
                    ? null
                    : () => Navigator.pop(
                          ctx,
                          StudentKeyDateInput(
                            title: titleCtrl.text.trim(),
                            date: date!,
                            kind: kind,
                          ),
                        ),
                child: Text(t(add)),
              ),
            ],
          );
        },
      );
    },
  );
}
