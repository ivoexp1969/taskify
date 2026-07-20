import 'package:flutter/material.dart';

import '../models/school_calendar.dart';
import '../services/school_calendar_service.dart';
import '../utils/localization.dart';

/// Картата „обратно броене до ваканция" — ядрото на Училищния режим.
///
/// Показва се само при включен режим. Реактивна: слуша `enabledNotifier` и
/// `revision`, така че смяна на toggle-а/класа или ново теглене от Firestore я
/// обновяват без рестарт. При липса на данни показва честно празно състояние
/// (не гадае дати).
///
/// Чист Dart → еднакво на Android и iOS.
class SchoolCountdownCard extends StatelessWidget {
  const SchoolCountdownCard({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = SchoolCalendarService();
    return ValueListenableBuilder<bool>(
      valueListenable: SchoolCalendarService.enabledNotifier,
      builder: (context, enabled, _) {
        if (!enabled) return const SizedBox.shrink();
        return ValueListenableBuilder<int>(
          valueListenable: SchoolCalendarService.revision,
          builder: (context, _, __) {
            final lang = LanguageScope.of(context).locale.languageCode;
            final cd = svc.countdown();
            final exams = svc.upcomingExams();
            return _buildCard(context, lang, cd, exams);
          },
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, String lang, SchoolCountdown cd,
      List<SchoolExam> exams) {
    // Празно състояние (клас не е избран ИЛИ няма данни за годината) — честно.
    if (cd.phase == SchoolPhase.noData) {
      return _emptyState(context, lang);
    }

    final spec = _spec(cd);
    final emoji = spec.emoji;
    final gradient = spec.gradient;
    final headline = _headline(lang, cd, spec);
    final sub = _subline(context, lang, cd);

    // Следващ изпит (НВО/ДЗИ) — само ако класът съвпада и има предстоящ.
    Widget? examLine;
    if (exams.isNotEmpty) {
      final e = exams.first;
      final d = daysBetween(DateTime.now(), e.date);
      examLine = Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            const Text('📝', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _examText(lang, e.name, d),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.15,
                        ),
                      ),
                      if (sub != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (examLine != null) examLine,
          ],
        ),
      ),
    );
  }

  // ── Празно състояние ──────────────────────────────────────────────────────

  Widget _emptyState(BuildContext context, String lang) {
    final theme = Theme.of(context);
    const msg = {
      'en': 'The dates for this school year haven\'t been published yet.',
      'bg': 'Датите за тази учебна година още не са публикувани.',
      'de': 'Die Termine für dieses Schuljahr sind noch nicht veröffentlicht.',
      'fr': 'Les dates de cette année scolaire ne sont pas encore publiées.',
      'it': 'Le date di quest\'anno scolastico non sono ancora pubblicate.',
      'el': 'Οι ημερομηνίες για αυτή τη σχολική χρονιά δεν έχουν ανακοινωθεί ακόμη.',
      'es': 'Las fechas de este curso escolar aún no se han publicado.',
      'pt': 'As datas deste ano letivo ainda não foram publicadas.',
      'ru': 'Даты этого учебного года ещё не опубликованы.',
      'tr': 'Bu öğretim yılının tarihleri henüz yayımlanmadı.',
      'ja': 'この学年の日程はまだ公開されていません。',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.school_outlined,
                size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg[lang] ?? msg['en']!,
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Визуален спец по фаза/ваканция ────────────────────────────────────────

  _CardSpec _spec(SchoolCountdown cd) {
    switch (cd.phase) {
      case SchoolPhase.inVacation:
      case SchoolPhase.toVacation:
        switch (cd.vacationKey) {
          case 'autumn':
            return const _CardSpec('🍂', [Color(0xFFE67E22), Color(0xFFC0392B)]);
          case 'winter':
            return const _CardSpec('🎄', [Color(0xFF16A085), Color(0xFF2C3E50)]);
          case 'midterm':
            return const _CardSpec('❄️', [Color(0xFF3498DB), Color(0xFF2980B9)]);
          case 'spring':
            return const _CardSpec('🌸', [Color(0xFFE84393), Color(0xFF6C5CE7)]);
          default:
            return const _CardSpec('🎒', [Color(0xFF7B2FF7), Color(0xFF2196F3)]);
        }
      case SchoolPhase.toSummer:
      case SchoolPhase.summerBreak:
        return const _CardSpec('☀️', [Color(0xFFF39C12), Color(0xFFE67E22)]);
      case SchoolPhase.beforeStart:
        return const _CardSpec('📚', [Color(0xFF8E44AD), Color(0xFF2980B9)]);
      case SchoolPhase.noData:
        return const _CardSpec('🎒', [Color(0xFF7B2FF7), Color(0xFF2196F3)]);
    }
  }

  // ── Текстове ──────────────────────────────────────────────────────────────

  /// Локализирано име на ваканцията по ключ (fallback към името от данните).
  String _vacationName(String lang, SchoolCountdown cd) {
    const names = {
      'autumn': {
        'en': 'autumn break', 'bg': 'Есенната ваканция', 'de': 'die Herbstferien',
        'fr': 'les vacances d\'automne', 'it': 'le vacanze autunnali',
        'el': 'τις φθινοπωρινές διακοπές', 'es': 'las vacaciones de otoño',
        'pt': 'as férias de outono', 'ru': 'осенних каникул',
        'tr': 'sonbahar tatili', 'ja': '秋休み',
      },
      'winter': {
        'en': 'winter break', 'bg': 'Коледната ваканция', 'de': 'die Weihnachtsferien',
        'fr': 'les vacances de Noël', 'it': 'le vacanze di Natale',
        'el': 'τις χριστουγεννιάτικες διακοπές', 'es': 'las vacaciones de Navidad',
        'pt': 'as férias de Natal', 'ru': 'зимних каникул',
        'tr': 'kış tatili', 'ja': '冬休み',
      },
      'midterm': {
        'en': 'the mid-term break', 'bg': 'Междусрочната ваканция',
        'de': 'die Halbjahresferien', 'fr': 'les vacances de mi-trimestre',
        'it': 'la pausa di metà anno', 'el': 'τις ενδιάμεσες διακοπές',
        'es': 'las vacaciones de mitad de curso', 'pt': 'as férias de meio de ano',
        'ru': 'межсеместровых каникул', 'tr': 'yarıyıl tatili', 'ja': '学期間の休み',
      },
      'spring': {
        'en': 'spring break', 'bg': 'Пролетната ваканция', 'de': 'die Osterferien',
        'fr': 'les vacances de printemps', 'it': 'le vacanze di primavera',
        'el': 'τις ανοιξιάτικες διακοπές', 'es': 'las vacaciones de primavera',
        'pt': 'as férias da primavera', 'ru': 'весенних каникул',
        'tr': 'ilkbahar tatili', 'ja': '春休み',
      },
    };
    final m = names[cd.vacationKey];
    if (m != null) return m[lang] ?? m['en']!;
    return cd.label ?? '';
  }

  String _headline(String lang, SchoolCountdown cd, _CardSpec spec) {
    switch (cd.phase) {
      case SchoolPhase.toVacation:
        final name = _vacationName(lang, cd);
        if (cd.days == 0) return _startsToday(lang, name);
        return _untilText(lang, cd.days, name);
      case SchoolPhase.inVacation:
        return _inVacationText(lang, cd.days);
      case SchoolPhase.toSummer:
        final summer = _summerName(lang);
        if (cd.days == 0) return _startsToday(lang, summer);
        return _untilText(lang, cd.days, summer);
      case SchoolPhase.summerBreak:
        return _summerBreakText(lang);
      case SchoolPhase.beforeStart:
        return _beforeStartText(lang, cd.days);
      case SchoolPhase.noData:
        return '';
    }
  }

  String _summerName(String lang) {
    const m = {
      'en': 'summer break', 'bg': 'лятната ваканция', 'de': 'die Sommerferien',
      'fr': 'les vacances d\'été', 'it': 'le vacanze estive',
      'el': 'τις καλοκαιρινές διακοπές', 'es': 'las vacaciones de verano',
      'pt': 'as férias de verão', 'ru': 'летних каникул', 'tr': 'yaz tatili',
      'ja': '夏休み',
    };
    return m[lang] ?? m['en']!;
  }

  /// „Още {n} {дни} до {name}" — с правилна форма за деня.
  String _untilText(String lang, int n, String name) {
    final d = _dayWord(lang, n);
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
        return '$name kadar $n $d';
      case 'ja':
        return '$nameまであと$n$d';
      default:
        return '$n $d until $name';
    }
  }

  String _startsToday(String lang, String name) {
    // Начална буква нагоре при нужда (BG имената идват с главна).
    const m = {
      'en': '{name} starts today!', 'bg': '{name} започва днес!',
      'de': '{name} beginnt heute!', 'fr': '{name} commence aujourd\'hui !',
      'it': '{name} inizia oggi!', 'el': '{name} ξεκινά σήμερα!',
      'es': '¡{name} empieza hoy!', 'pt': '{name} começa hoje!',
      'ru': '{name} начинается сегодня!', 'tr': '{name} bugün başlıyor!',
      'ja': '今日から{name}！',
    };
    return (m[lang] ?? m['en']!).replaceAll('{name}', name);
  }

  String _inVacationText(String lang, int daysLeft) {
    if (daysLeft <= 0) {
      const m = {
        'en': 'Vacation! Last day of the break 🎉',
        'bg': 'Ваканция! Последен ден почивка 🎉',
        'de': 'Ferien! Letzter freier Tag 🎉',
        'fr': 'Vacances ! Dernier jour de repos 🎉',
        'it': 'Vacanza! Ultimo giorno di pausa 🎉',
        'el': 'Διακοπές! Τελευταία μέρα ξεκούρασης 🎉',
        'es': '¡Vacaciones! Último día de descanso 🎉',
        'pt': 'Férias! Último dia de descanso 🎉',
        'ru': 'Каникулы! Последний день отдыха 🎉',
        'tr': 'Tatil! Molanın son günü 🎉',
        'ja': '休み！休暇最終日 🎉',
      };
      return m[lang] ?? m['en']!;
    }
    final d = _dayWord(lang, daysLeft);
    switch (lang) {
      case 'bg':
        return 'Ваканция! 🎉 Още $daysLeft $d почивка';
      case 'de':
        return 'Ferien! 🎉 Noch $daysLeft $d frei';
      case 'fr':
        return 'Vacances ! 🎉 Encore $daysLeft $d de repos';
      case 'it':
        return 'Vacanza! 🎉 Ancora $daysLeft $d di pausa';
      case 'el':
        return 'Διακοπές! 🎉 Ακόμα $daysLeft $d ξεκούρασης';
      case 'es':
        return '¡Vacaciones! 🎉 $daysLeft $d de descanso';
      case 'pt':
        return 'Férias! 🎉 Mais $daysLeft $d de descanso';
      case 'ru':
        return 'Каникулы! 🎉 Ещё $daysLeft $d отдыха';
      case 'tr':
        return 'Tatil! 🎉 $daysLeft $d mola daha';
      case 'ja':
        return '休み！🎉 あと$daysLeft$d';
      default:
        return 'Vacation! 🎉 $daysLeft $d of break left';
    }
  }

  String _summerBreakText(String lang) {
    const m = {
      'en': 'Summer break! Enjoy ☀️', 'bg': 'Лятна ваканция! Почивай ☀️',
      'de': 'Sommerferien! Genieß es ☀️', 'fr': 'Vacances d\'été ! Profite ☀️',
      'it': 'Vacanze estive! Goditele ☀️', 'el': 'Καλοκαιρινές διακοπές! ☀️',
      'es': '¡Vacaciones de verano! ☀️', 'pt': 'Férias de verão! ☀️',
      'ru': 'Летние каникулы! Отдыхай ☀️', 'tr': 'Yaz tatili! Keyfini çıkar ☀️',
      'ja': '夏休み！楽しんで ☀️',
    };
    return m[lang] ?? m['en']!;
  }

  String _beforeStartText(String lang, int n) {
    const first = {
      'en': 'first day of school', 'bg': 'първия учебен ден',
      'de': 'zum Schulanfang', 'fr': 'la rentrée', 'it': 'il primo giorno di scuola',
      'el': 'την πρώτη μέρα σχολείου', 'es': 'el primer día de clases',
      'pt': 'o primeiro dia de aulas', 'ru': 'первого учебного дня',
      'tr': 'ilk okul günü', 'ja': '始業日',
    };
    final name = first[lang] ?? first['en']!;
    if (n == 0) {
      const today = {
        'en': 'School starts today! 📚', 'bg': 'Училището започва днес! 📚',
        'de': 'Die Schule beginnt heute! 📚', 'fr': 'L\'école commence aujourd\'hui ! 📚',
        'it': 'La scuola inizia oggi! 📚', 'el': 'Το σχολείο ξεκινά σήμερα! 📚',
        'es': '¡La escuela empieza hoy! 📚', 'pt': 'A escola começa hoje! 📚',
        'ru': 'Школа начинается сегодня! 📚', 'tr': 'Okul bugün başlıyor! 📚',
        'ja': '今日から学校！📚',
      };
      return today[lang] ?? today['en']!;
    }
    return '${_untilText(lang, n, name)} 📚';
  }

  String _examText(String lang, String examName, int n) {
    if (n <= 0) {
      const m = {
        'en': '{e} is today', 'bg': '{e} е днес', 'de': '{e} ist heute',
        'fr': '{e} c\'est aujourd\'hui', 'it': '{e} è oggi', 'el': '{e} είναι σήμερα',
        'es': '{e} es hoy', 'pt': '{e} é hoje', 'ru': '{e} — сегодня',
        'tr': '{e} bugün', 'ja': '{e}は今日',
      };
      return (m[lang] ?? m['en']!).replaceAll('{e}', examName);
    }
    final d = _dayWord(lang, n);
    const tpl = {
      'en': '{n} {d} until {e}', 'bg': 'Още {n} {d} до {e}',
      'de': 'Noch {n} {d} bis {e}', 'fr': 'Encore {n} {d} avant {e}',
      'it': 'Ancora {n} {d} a {e}', 'el': 'Ακόμα {n} {d} για {e}',
      'es': '{n} {d} para {e}', 'pt': '{n} {d} para {e}',
      'ru': 'Ещё {n} {d} до {e}', 'tr': '{e} kadar {n} {d}',
      'ja': '{e}まであと{n}{d}',
    };
    return (tpl[lang] ?? tpl['en']!)
        .replaceAll('{n}', '$n')
        .replaceAll('{d}', d)
        .replaceAll('{e}', examName);
  }

  /// Правилната дума за „ден/дни" според езика и числото (вкл. руските 3 форми).
  String _dayWord(String lang, int n) {
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
        return _ruDays(n);
      case 'tr':
        return 'gün'; // турски: без множествено число след число
      case 'ja':
        return '日';
      default:
        return n == 1 ? 'day' : 'days';
    }
  }

  /// Руски: 1 день, 2–4 дня, 5+ дней (с изключенията 11–14 → дней).
  String _ruDays(int n) {
    final mod100 = n % 100;
    final mod10 = n % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'дней';
    if (mod10 == 1) return 'день';
    if (mod10 >= 2 && mod10 <= 4) return 'дня';
    return 'дней';
  }

  /// Втори ред: датата на целта (когато е налична).
  String? _subline(BuildContext context, String lang, SchoolCountdown cd) {
    final d = cd.targetDate;
    if (d == null) return null;
    if (cd.phase == SchoolPhase.summerBreak) return null;
    final months = _months[lang] ?? _months['en']!;
    return '${d.day} ${months[d.month - 1]}';
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

class _CardSpec {
  final String emoji;
  final List<Color> gradient;
  const _CardSpec(this.emoji, this.gradient);
}
