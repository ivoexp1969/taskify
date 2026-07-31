import 'package:flutter/material.dart';

import '../models/weekly_schedule.dart';
import '../models/school_calendar.dart';
import '../services/weekly_schedule_service.dart';
import '../services/school_calendar_service.dart';
import '../screens/modes/weekly_schedule_screen.dart';
import '../utils/localization.dart';

/// Карта „Днес — [ден]" (таб Обучение). Показва часовете за днешния ден от
/// текущия срок/семестър, като маркира кой е „в момента" и кой е „следващ".
///
/// Всичко е чист Dart + SharedPreferences (през [WeeklyScheduleService]) →
/// еднакво на Android и iOS, реактивно през [WeeklyScheduleService.revision].
class TodayScheduleCard extends StatefulWidget {
  const TodayScheduleCard({super.key});

  @override
  State<TodayScheduleCard> createState() => _TodayScheduleCardState();
}

class _TodayScheduleCardState extends State<TodayScheduleCard> {
  final _svc = WeeklyScheduleService();

  @override
  void initState() {
    super.initState();
    // Идемпотентно — ако вече е зареден, връща веднага.
    _svc.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  static String _t(Map<String, String> m, String lang) => m[lang] ?? m['en']!;

  static const _todayWord = {
    'en': 'Today', 'bg': 'Днес', 'de': 'Heute', 'fr': "Aujourd'hui",
    'it': 'Oggi', 'el': 'Σήμερα', 'es': 'Hoy', 'pt': 'Hoje',
    'ru': 'Сегодня', 'tr': 'Bugün', 'ja': '今日',
  };
  static const _noLessons = {
    'en': 'No classes today ☕', 'bg': 'Днес нямаш часове ☕',
    'de': 'Heute keine Stunden ☕', 'fr': 'Pas de cours aujourd\'hui ☕',
    'it': 'Nessuna lezione oggi ☕', 'el': 'Κανένα μάθημα σήμερα ☕',
    'es': 'Hoy no hay clases ☕', 'pt': 'Hoje sem aulas ☕',
    'ru': 'Сегодня нет занятий ☕', 'tr': 'Bugün ders yok ☕',
    'ja': '今日は授業なし ☕',
  };
  static const _enjoyDay = {
    'en': 'Enjoy your day! 🌴', 'bg': 'Приятен ден! 🌴',
    'de': 'Schönen Tag! 🌴', 'fr': 'Bonne journée ! 🌴',
    'it': 'Buona giornata! 🌴', 'el': 'Καλή σου μέρα! 🌴',
    'es': '¡Buen día! 🌴', 'pt': 'Bom dia! 🌴',
    'ru': 'Хорошего дня! 🌴', 'tr': 'İyi günler! 🌴', 'ja': '良い一日を！🌴',
  };
  static const _addSchedule = {
    'en': 'Add your schedule →', 'bg': 'Въведи разписанието си →',
    'de': 'Stundenplan hinzufügen →', 'fr': 'Ajoute ton emploi du temps →',
    'it': 'Aggiungi il tuo orario →', 'el': 'Πρόσθεσε το πρόγραμμά σου →',
    'es': 'Añade tu horario →', 'pt': 'Adiciona o teu horário →',
    'ru': 'Добавь расписание →', 'tr': 'Programını ekle →',
    'ja': '時間割を追加 →',
  };
  static const _seeWeek = {
    'en': 'See full week', 'bg': 'Виж цялата седмица',
    'de': 'Ganze Woche', 'fr': 'Voir la semaine', 'it': 'Vedi la settimana',
    'el': 'Όλη η εβδομάδα', 'es': 'Ver la semana', 'pt': 'Ver a semana',
    'ru': 'Вся неделя', 'tr': 'Tüm hafta', 'ja': '週間を見る',
  };
  static const _now = {
    'en': 'now', 'bg': 'сега', 'de': 'jetzt', 'fr': 'maintenant',
    'it': 'ora', 'el': 'τώρα', 'es': 'ahora', 'pt': 'agora',
    'ru': 'сейчас', 'tr': 'şimdi', 'ja': '今',
  };

  static const _dayNames = {
    'en': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
    'bg': ['Понеделник', 'Вторник', 'Сряда', 'Четвъртък', 'Петък', 'Събота', 'Неделя'],
    'de': ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'],
    'fr': ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'],
    'it': ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'],
    'el': ['Δευτέρα', 'Τρίτη', 'Τετάρτη', 'Πέμπτη', 'Παρασκευή', 'Σάββατο', 'Κυριακή'],
    'es': ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'],
    'pt': ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'],
    'ru': ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'],
    'tr': ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'],
    'ja': ['月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日', '日曜日'],
  };

  String _dayName(String lang, int weekday) {
    final list = _dayNames[lang] ?? _dayNames['en']!;
    return list[(weekday - 1).clamp(0, 6)];
  }

  /// „след X мин" / „след Xч" до началото на следващия час.
  String _inLabel(String lang, int minutes) {
    if (minutes < 60) {
      switch (lang) {
        case 'bg': return 'след $minutes мин';
        case 'de': return 'in $minutes Min';
        case 'fr': return 'dans $minutes min';
        case 'it': return 'tra $minutes min';
        case 'el': return 'σε $minutes λεπτά';
        case 'es': return 'en $minutes min';
        case 'pt': return 'em $minutes min';
        case 'ru': return 'через $minutes мин';
        case 'tr': return '$minutes dk sonra';
        case 'ja': return 'あと$minutes分';
        default: return 'in $minutes min';
      }
    }
    final h = minutes ~/ 60;
    switch (lang) {
      case 'bg': return 'след $hч';
      case 'de': return 'in $h Std';
      case 'fr': return 'dans $h h';
      case 'it': return 'tra $h h';
      case 'el': return 'σε $h ώρες';
      case 'es': return 'en $h h';
      case 'pt': return 'em $h h';
      case 'ru': return 'через $h ч';
      case 'tr': return '$h sa sonra';
      case 'ja': return 'あと$h時間';
      default: return 'in ${h}h';
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageScope.of(context).locale.languageCode;
    return AnimatedBuilder(
      animation: WeeklyScheduleService.revision,
      builder: (context, _) {
        final theme = Theme.of(context);
        final now = DateTime.now();
        final weekday = now.weekday; // 1..7
        final slots = _svc.forDay(weekday); // текущ срок, сортирани
        final nowMin = now.hour * 60 + now.minute;

        // Изцяло празно разписание → подкана за въвеждане.
        if (_svc.isEmpty) {
          return Card(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: ListTile(
              leading: const Text('📅', style: TextStyle(fontSize: 24)),
              title: Text(_t(_addSchedule, lang),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openWeek,
            ),
          );
        }

        // Индекс на „следващия" час (първият с начало след сегашния момент).
        int nextIdx = -1;
        for (var i = 0; i < slots.length; i++) {
          if (slots[i].fromMinutes > nowMin) {
            nextIdx = i;
            break;
          }
        }

        return Card(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📅 ${_t(_todayWord, lang)} — ${_dayName(lang, weekday)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: theme.colorScheme.primary)),
                const SizedBox(height: 8),
                if (slots.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(_emptyTodayText(lang, weekday),
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant)),
                  )
                else
                  for (var i = 0; i < slots.length; i++)
                    _slotRow(theme, lang, slots[i], nowMin, i == nextIdx),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    onPressed: _openWeek,
                    icon: const Icon(Icons.calendar_view_week, size: 16),
                    label: Text(_t(_seeWeek, lang)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _emptyTodayText(String lang, int weekday) {
    // Ученик във ваканция → пожелание; иначе неутрално.
    final phase = SchoolCalendarService().countdown().phase;
    if (weekday == 7 ||
        phase == SchoolPhase.inVacation ||
        phase == SchoolPhase.summerBreak) {
      return _t(_enjoyDay, lang);
    }
    return _t(_noLessons, lang);
  }

  Widget _slotRow(ThemeData theme, String lang, ScheduleSlot s, int nowMin,
      bool isNext) {
    final isCurrent = s.fromMinutes <= nowMin && nowMin < s.toMinutes;
    final isPast = s.toMinutes <= nowMin;

    final Color barColor = isCurrent
        ? theme.colorScheme.primary
        : (isPast
            ? theme.colorScheme.outlineVariant
            : theme.colorScheme.primary.withValues(alpha: 0.4));
    final double opacity = isPast ? 0.5 : 1.0;

    Widget trailing = const SizedBox.shrink();
    if (isCurrent) {
      trailing = _chip(theme, _t(_now, lang), theme.colorScheme.primary);
    } else if (isNext) {
      final mins = s.fromMinutes - nowMin;
      trailing = _chip(theme, _inLabel(lang, mins),
          theme.colorScheme.tertiary);
    }

    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: isCurrent
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 34,
              decoration: BoxDecoration(
                  color: barColor, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 96,
              child: Text('${s.fromLabel}–${s.toLabel}',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant)),
            ),
            Expanded(
              child: Text(
                s.subject.isNotEmpty ? s.subject : '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _chip(ThemeData theme, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );

  void _openWeek() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WeeklyScheduleScreen()),
    );
  }
}
