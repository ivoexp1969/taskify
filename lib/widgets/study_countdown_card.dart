import 'dart:async';

import 'package:flutter/material.dart';

import '../models/school_calendar.dart';
import '../services/school_calendar_service.dart';
import '../services/university_service.dart';
import '../screens/modes/study_events_screen.dart';
import '../utils/localization.dart';
import 'school_countdown_card.dart';

/// Обединена карта за обратно броене на началния екран (таб Задачи).
///
/// Избира какво да покаже:
/// - само Ученик активен → картата на ученика (реактивна, [SchoolCountdownCard]);
/// - само Студент активен → броене до най-близката ръчно въведена ключова дата;
/// - и двата активни → показва този с най-близкото събитие (рядко, но възможно);
/// - никой активен → нищо (сама се скрива).
///
/// Тап навсякъде → пълен списък с предстоящи събития ([StudyEventsScreen]).
/// Чист Dart → еднакво на Android и iOS.
class StudyCountdownCard extends StatelessWidget {
  const StudyCountdownCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        SchoolCalendarService.enabledNotifier,
        SchoolCalendarService.revision,
        UniversityService.enabledNotifier,
        UniversityService.revision,
      ]),
      builder: (context, _) {
        final school = SchoolCalendarService();
        final uni = UniversityService();
        final lang = LanguageScope.of(context).locale.languageCode;

        final pupilOn = school.enabled && school.grade != null;
        final studentOn = uni.enabled;
        if (!pupilOn && !studentOn) return const SizedBox.shrink();

        // Датите на най-близките събития за подредба, ако и двата са активни.
        final pupilTarget = pupilOn ? school.countdown().targetDate : null;
        // Ръчните ключови дати са общи за двата режима.
        final manualUpcoming = uni.upcomingKeyDates();
        final manualNext =
            manualUpcoming.isEmpty ? null : manualUpcoming.first.date;

        final showManual = _pickManual(
          pupilOn: pupilOn,
          studentOn: studentOn,
          pupilTarget: pupilTarget,
          manualNext: manualNext,
        );

        final Widget card = showManual
            ? _StudentCard(lang: lang)
            : const SchoolCountdownCard();

        return InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StudyEventsScreen()),
          ),
          child: card,
        );
      },
    );
  }

  /// Решава дали да покаже картата с ръчните ключови дати (иначе ученическата
  /// от Firestore). Ученик ползва Firestore; но при липса на данни там пада на
  /// ръчните дати (напр. „Начало на учебната година"), които той сам е въвел.
  static bool _pickManual({
    required bool pupilOn,
    required bool studentOn,
    required DateTime? pupilTarget,
    required DateTime? manualNext,
  }) {
    if (studentOn && !pupilOn) return true; // студент → винаги ръчни дати
    if (!pupilOn) return false;
    // Ученик активен:
    if (pupilTarget == null) return manualNext != null; // няма Firestore → ръчни
    if (manualNext == null) return false;
    return !manualNext.isAfter(pupilTarget); // по-близкото събитие печели
  }
}

/// Карта за студент — броене до най-близките ключови дати.
///
/// Ако има повече от една предстояща дата, картата ги **редува** (плавно
/// затихване на всеки няколко секунди), за да са видими най-близките събития,
/// не само първото. Тап (родителят) → пълен списък.
class _StudentCard extends StatefulWidget {
  final String lang;
  const _StudentCard({required this.lang});

  @override
  State<_StudentCard> createState() => _StudentCardState();
}

class _StudentCardState extends State<_StudentCard> {
  /// Колко от най-близките събития да се редуват.
  static const int _maxRotate = 4;

  /// През колко време сменя показаното събитие.
  static const Duration _interval = Duration(seconds: 5);

  Timer? _timer;
  int _index = 0;

  String get lang => widget.lang;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _ensureTimer(int count) {
    if (count > 1) {
      _timer ??= Timer.periodic(_interval, (_) {
        if (!mounted) return;
        setState(() => _index = (_index + 1) % count);
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  static String _t(Map<String, String> m, String lang) => m[lang] ?? m['en']!;

  static const _emptyPrompt = {
    'en': 'Add a key date to see the countdown',
    'bg': 'Добави ключова дата, за да видиш броенето',
    'de': 'Füge einen Termin hinzu, um den Countdown zu sehen',
    'fr': 'Ajoute une date clé pour voir le compte à rebours',
    'it': 'Aggiungi una data chiave per vedere il conto alla rovescia',
    'el': 'Πρόσθεσε μια βασική ημερομηνία για αντίστροφη μέτρηση',
    'es': 'Añade una fecha clave para ver la cuenta atrás',
    'pt': 'Adiciona uma data-chave para ver a contagem',
    'ru': 'Добавь ключевую дату, чтобы увидеть отсчёт',
    'tr': 'Geri sayımı görmek için bir tarih ekle',
    'ja': 'カウントダウンを見るには日付を追加',
  };
  static const _todayWord = {
    'en': 'is today!', 'bg': 'е днес!', 'de': 'ist heute!', 'fr': "c'est aujourd'hui !",
    'it': 'è oggi!', 'el': 'είναι σήμερα!', 'es': '¡es hoy!', 'pt': 'é hoje!',
    'ru': 'сегодня!', 'tr': 'bugün!', 'ja': 'は今日！',
  };

  String _dayWord(int n) {
    switch (lang) {
      case 'bg':
        return n == 1 ? 'ден' : 'дни';
      case 'de':
        return n == 1 ? 'Tag' : 'Tage';
      case 'fr':
        return n == 1 ? 'jour' : 'jours';
      case 'it':
        return n == 1 ? 'giorno' : 'giorni';
      case 'el':
        return n == 1 ? 'μέρα' : 'μέρες';
      case 'es':
        return n == 1 ? 'día' : 'días';
      case 'pt':
        return n == 1 ? 'dia' : 'dias';
      case 'ru':
        final mod100 = n % 100, mod10 = n % 10;
        if (mod100 >= 11 && mod100 <= 14) return 'дней';
        if (mod10 == 1) return 'день';
        if (mod10 >= 2 && mod10 <= 4) return 'дня';
        return 'дней';
      case 'tr':
        return 'gün';
      case 'ja':
        return '日';
      default:
        return n == 1 ? 'day' : 'days';
    }
  }

  String _untilText(int n, String name) {
    final d = _dayWord(n);
    switch (lang) {
      case 'bg':
        return 'Още $n $d до $name';
      case 'de':
        return 'Noch $n $d bis $name';
      case 'fr':
        return 'Encore $n $d avant $name';
      case 'it':
        return 'Ancora $n $d a $name';
      case 'el':
        return 'Ακόμα $n $d για $name';
      case 'es':
        return '$n $d para $name';
      case 'pt':
        return '$n $d para $name';
      case 'ru':
        return 'Ещё $n $d до $name';
      case 'tr':
        return '$name için $n $d';
      case 'ja':
        return '$nameまであと$n$d';
      default:
        return '$n $d until $name';
    }
  }

  @override
  Widget build(BuildContext context) {
    final uni = UniversityService();
    final all = uni.upcomingKeyDates();
    // Редуваме само най-близките няколко събития.
    final rotate = all.take(_maxRotate).toList();
    _ensureTimer(rotate.length);
    if (_index >= rotate.length) _index = 0;
    final next = rotate.isEmpty ? null : rotate[_index];

    // Празно състояние — честна подкана (не гадаем дати).
    if (next == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6A3DE8), Color(0xFF2980B9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Text('🎓', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _t(_emptyPrompt, lang),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.add, color: Colors.white),
            ],
          ),
        ),
      );
    }

    final n = daysBetween(DateTime.now(), next.date);
    final name = next.title.isNotEmpty
        ? next.title
        : _t(kStudentDateKindLabels[next.kind]!, lang);
    final headline = n <= 0 ? '$name ${_t(_todayWord, lang)}' : _untilText(n, name);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6A3DE8), Color(0xFF0AA674)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0AA674).withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Text('🎓', style: TextStyle(fontSize: 30)),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  headline,
                  key: ValueKey(next.id),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),
              ),
            ),
            if (rotate.length > 1) ...[
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < rotate.length; i++)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white
                            .withValues(alpha: i == _index ? 0.95 : 0.35),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
