import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../utils/localization.dart';

/// Избор на дата (падеж на задача) — локализиран TableCalendar в диалог.
/// Изнесено от `task_screen.dart` без промяна на поведение.
Future<DateTime?> pickTaskDate(
    BuildContext context, DateTime initialDate) async {
  final languageController = LanguageScope.of(context);
  final langCode = languageController.locale.languageCode;

  DateTime focusedDay =
      DateTime(initialDate.year, initialDate.month, initialDate.day);
  DateTime selectedDay = focusedDay;

  String monthLabel(DateTime day) {
    const months = {
      'en': ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
      'bg': ['януари', 'февруари', 'март', 'април', 'май', 'юни', 'юли', 'август', 'септември', 'октомври', 'ноември', 'декември'],
      'de': ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'],
      'fr': ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'],
      'it': ['gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', 'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre'],
      'el': ['Ιανουάριος', 'Φεβρουάριος', 'Μάρτιος', 'Απρίλιος', 'Μάιος', 'Ιούνιος', 'Ιούλιος', 'Αύγουστος', 'Σεπτέμβριος', 'Οκτώβριος', 'Νοέμβριος', 'Δεκέμβριος'],
      'es': ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'],
      'pt': ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'],
      'ru': ['январь', 'февраль', 'март', 'апрель', 'май', 'июнь', 'июль', 'август', 'сентябрь', 'октябрь', 'ноябрь', 'декабрь'],
      'tr': ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'],
    };
    final monthList = months[langCode] ?? months['en']!;
    final name = monthList[day.month - 1];
    return '$name ${day.year}';
  }

  String weekdayLabel(int weekday) {
    const weekdays = {
      'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      'bg': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'],
      'de': ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'],
      'fr': ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'],
      'it': ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'],
      'el': ['Δευ', 'Τρί', 'Τετ', 'Πέμ', 'Παρ', 'Σάβ', 'Κυρ'],
      'es': ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'],
      'pt': ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'],
      'ru': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
      'tr': ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'],
    };
    final dayList = weekdays[langCode] ?? weekdays['en']!;
    final idx = weekday - 1;
    return dayList[idx];
  }

  final t = AppText.of(context);

  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(t.dueDate),
        content: StatefulBuilder(
          builder: (innerContext, setState) {
            return SizedBox(
              width: 320,
              height: 320,
              child: Column(
                children: [
                  Text(
                    monthLabel(focusedDay),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TableCalendar(
                      firstDay: DateTime(2020, 1, 1),
                      lastDay: DateTime(2100, 12, 31),
                      focusedDay: focusedDay,
                      headerVisible: false,
                      calendarFormat: CalendarFormat.month,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      selectedDayPredicate: (day) =>
                          isSameDay(selectedDay, day),
                      onDaySelected: (sel, foc) {
                        setState(() {
                          selectedDay =
                              DateTime(sel.year, sel.month, sel.day);
                          focusedDay = foc;
                        });
                      },
                      onPageChanged: (newFocusedDay) {
                        setState(() {
                          focusedDay = newFocusedDay;
                        });
                      },
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle: TextStyle(fontSize: 11),
                        weekendStyle: TextStyle(fontSize: 11),
                      ),
                      calendarStyle: CalendarStyle(
                        defaultTextStyle: const TextStyle(fontSize: 12),
                        weekendTextStyle: const TextStyle(
                          fontSize: 12,
                          color: Colors.redAccent,
                        ),
                        outsideTextStyle: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                        todayDecoration: BoxDecoration(
                          color: Theme.of(innerContext)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: TextStyle(
                          fontSize: 12,
                          color: Theme.of(innerContext)
                              .colorScheme
                              .primary,
                          fontWeight: FontWeight.w600,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: Theme.of(innerContext)
                              .colorScheme
                              .primary,
                          shape: BoxShape.circle,
                        ),
                        selectedTextStyle: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      calendarBuilders: CalendarBuilders(
                        dowBuilder: (context, day) {
                          final label = weekdayLabel(day.weekday);
                          return Center(
                            child: Text(
                              label,
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(selectedDay),
            child: Text(t.add),
          ),
        ],
      );
    },
  );
}
