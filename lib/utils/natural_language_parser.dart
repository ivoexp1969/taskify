import 'package:flutter/material.dart';

class NlpResult {
  final DateTime date;
  final TimeOfDay? time;
  final String label;

  const NlpResult({required this.date, this.time, required this.label});
}

class NaturalLanguageParser {
  static NlpResult? parse(String text, String lang) {
    final lower = text.toLowerCase().trim();
    if (lower.length < 3) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ── Time detection (15:30 / 5pm / 15ч / 9h / „в 9" / „at 9") ──
    final detectedTime = _detectTime(lower);

    // ── Keyword maps ──

    // Today
    if (_matches(lower, const [
      'днес', 'today', 'heute', "aujourd'hui", 'oggi',
      'σήμερα', 'hoy', 'hoje', 'сегодня', 'bugün',
      'vandaag', 'сьогодні',
    ])) {
      return NlpResult(date: today, time: detectedTime, label: _label(today, lang));
    }

    // Tomorrow
    if (_matches(lower, const [
      'утре', 'tomorrow', 'morgen', 'demain', 'domani',
      'αύριο', 'mañana', 'amanhã', 'завтра', 'yarın',
    ])) {
      final d = today.add(const Duration(days: 1));
      return NlpResult(date: d, time: detectedTime, label: _label(d, lang));
    }

    // Day after tomorrow
    if (_matches(lower, const [
      'вдругиден', 'day after tomorrow', 'übermorgen',
      'après-demain', 'dopodomani', 'μεθαύριο',
      'pasado mañana', 'depois de amanhã', 'послезавтра', 'öbür gün',
    ])) {
      final d = today.add(const Duration(days: 2));
      return NlpResult(date: d, time: detectedTime, label: _label(d, lang));
    }

    // Next week
    if (_matches(lower, const [
      'следващата седмица', 'next week', 'nächste woche',
      'semaine prochaine', 'settimana prossima', 'επόμενη εβδομάδα',
      'próxima semana', 'semana que vem', 'следующей неделе', 'gelecek hafta',
    ])) {
      final d = today.add(const Duration(days: 7));
      return NlpResult(date: d, time: detectedTime, label: _label(d, lang));
    }

    // Weekend
    if (_matches(lower, const [
      'уикенд', 'weekend', 'wochenende', 'week-end',
      'fine settimana', 'σαββατοκύριακο', 'fin de semana',
      'fim de semana', 'выходные', 'hafta sonu',
    ])) {
      int daysToSat = DateTime.saturday - today.weekday;
      if (daysToSat <= 0) daysToSat += 7;
      final d = today.add(Duration(days: daysToSat));
      return NlpResult(date: d, time: detectedTime, label: _label(d, lang));
    }

    // Day names → next occurrence (weekday: Mon=1 … Sun=7)
    const dayMap = <String, int>{
      // Monday
      'понеделник': 1, 'monday': 1, 'montag': 1, 'lundi': 1,
      'lunedì': 1, 'δευτέρα': 1, 'lunes': 1, 'segunda': 1,
      'понедельник': 1, 'pazartesi': 1,
      // Tuesday
      'вторник': 2, 'tuesday': 2, 'dienstag': 2, 'mardi': 2,
      'martedì': 2, 'τρίτη': 2, 'martes': 2, 'terça': 2,
      'salı': 2,
      // Wednesday
      'сряда': 3, 'wednesday': 3, 'mittwoch': 3, 'mercredi': 3,
      'mercoledì': 3, 'τετάρτη': 3, 'miércoles': 3, 'quarta': 3,
      'среда': 3, 'çarşamba': 3,
      // Thursday
      'четвъртък': 4, 'thursday': 4, 'donnerstag': 4, 'jeudi': 4,
      'giovedì': 4, 'πέμπτη': 4, 'jueves': 4, 'quinta': 4,
      'четверг': 4, 'perşembe': 4,
      // Friday
      'петък': 5, 'friday': 5, 'freitag': 5, 'vendredi': 5,
      'venerdì': 5, 'παρασκευή': 5, 'viernes': 5, 'sexta': 5,
      'пятница': 5, 'cuma': 5,
      // Saturday
      'събота': 6, 'saturday': 6, 'samstag': 6, 'samedi': 6,
      'sabato': 6, 'σάββατο': 6, 'sábado': 6, 'суббота': 6,
      'cumartesi': 6,
      // Sunday
      'неделя': 7, 'sunday': 7, 'sonntag': 7, 'dimanche': 7,
      'domenica': 7, 'κυριακή': 7, 'domingo': 7,
      'воскресенье': 7, 'pazar': 7,
    };

    for (final entry in dayMap.entries) {
      if (lower.contains(entry.key)) {
        int ahead = entry.value - today.weekday;
        if (ahead <= 0) ahead += 7;
        final d = today.add(Duration(days: ahead));
        return NlpResult(date: d, time: detectedTime, label: _label(d, lang));
      }
    }

    // ── Relative: „след N дни/седмици" / „in N days/weeks" (всички езици) ──
    final rel = _detectRelative(lower, today);
    if (rel != null) {
      return NlpResult(date: rel, time: detectedTime, label: _label(rel, lang));
    }

    // ── Absolute date: „12 декември", „12 дек", „Dec 12", „12.12", „3/1" ──
    final abs = _detectAbsoluteDate(lower, today);
    if (abs != null) {
      return NlpResult(date: abs, time: detectedTime, label: _label(abs, lang));
    }

    // Time only → today
    if (detectedTime != null) {
      return NlpResult(date: today, time: detectedTime, label: _label(today, lang));
    }

    return null;
  }

  // ── Time ─────────────────────────────────────────────────────────────────
  static TimeOfDay? _detectTime(String lower) {
    // 1) 12-hour am/pm: „5pm", „5:30 pm", „12am"
    final ampm = RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)').firstMatch(lower);
    if (ampm != null) {
      var h = int.tryParse(ampm.group(1)!) ?? -1;
      final m = ampm.group(2) != null ? (int.tryParse(ampm.group(2)!) ?? 0) : 0;
      final pm = ampm.group(3)!.startsWith('p');
      if (h >= 1 && h <= 12 && m <= 59) {
        if (pm && h != 12) h += 12;
        if (!pm && h == 12) h = 0;
        return TimeOfDay(hour: h, minute: m);
      }
    }
    // 2) 24-hour colon: „15:30"
    final colon = RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(lower);
    if (colon != null) {
      final h = int.tryParse(colon.group(1)!);
      final m = int.tryParse(colon.group(2)!);
      if (h != null && m != null && h <= 23 && m <= 59) {
        return TimeOfDay(hour: h, minute: m);
      }
    }
    // 3) hour + unit suffix: „17ч", „9 часа", „9h", „9 uhr", „9時".
    //    Край чрез `(?!\p{L})` — ASCII `\b` не хваща след кирилско „ч".
    final short = RegExp(r'\b(\d{1,2})\s*(?:часа?|ч|uhr|h|saat|時)(?!\p{L})', unicode: true).firstMatch(lower);
    if (short != null) {
      final h = int.tryParse(short.group(1)!);
      if (h != null && h <= 23) return TimeOfDay(hour: h, minute: 0);
    }
    // 4) bare hour after preposition — ТОЛКОВА в края на текста: „…в 9", „…at 9".
    //    Иначе „в 9 клас"/„в 2 реда" биха станали часове. `\b` се избягва пред
    //    кирилица (ASCII word-boundary не работи там).
    final prep = RegExp(
      r'(?:^|[\s@])(?:в|at|à|às|um|alle|saat|στις)\s+(\d{1,2})\s*[.!?]?\s*$',
    ).firstMatch(lower);
    if (prep != null) {
      final h = int.tryParse(prep.group(1)!);
      if (h != null && h <= 23) return TimeOfDay(hour: h, minute: 0);
    }
    return null;
  }

  // ── Relative „in N days / weeks" ───────────────────────────────────────────
  // The marker, the number and the unit must appear together, so a bare „2 дни"
  // or a day-of-month is never mistaken for a relative offset. `\b` is avoided
  // before Cyrillic/Greek (ASCII word-boundaries fail there).
  static const _relPrefix =
      r'(?:след|in|after|dans|tra|fra|σε|en|dentro de|em|daqui a|over|через|у)';
  static const _dayWords =
      r'(?:дни|дена|ден|days?|tage?n?|jours?|giorni?|giorno|μέρες|μέρα|ημέρες|ημέρα|d[ií]as?|dag(?:en)?|дн(?:я|ей|і|ів)?|gün)';
  static const _weekWords =
      r'(?:седмиц[аи]|weeks?|wochen?|semaines?|settiman[ae]|εβδομάδ[εα]ς?|semanas?|wek(?:en)?|недел[ьия]|тижн(?:і|ів)|hafta)';

  static DateTime? _detectRelative(String lower, DateTime today) {
    // Prefixed forms: „след 2 дни", „in 3 weeks", „через 5 дней".
    final pd = RegExp('$_relPrefix\\s+(\\d{1,2})\\s*$_dayWords').firstMatch(lower);
    if (pd != null) {
      final n = int.tryParse(pd.group(1)!);
      if (n != null && n >= 1 && n <= 366) return today.add(Duration(days: n));
    }
    final pw = RegExp('$_relPrefix\\s+(\\d{1,2})\\s*$_weekWords').firstMatch(lower);
    if (pw != null) {
      final n = int.tryParse(pw.group(1)!);
      if (n != null && n >= 1 && n <= 52) return today.add(Duration(days: n * 7));
    }
    // Turkish suffix form: „2 gün sonra", „3 hafta sonra".
    final td = RegExp(r'(\d{1,2})\s*gün\s+sonra').firstMatch(lower);
    if (td != null) {
      final n = int.tryParse(td.group(1)!);
      if (n != null && n >= 1 && n <= 366) return today.add(Duration(days: n));
    }
    final tw = RegExp(r'(\d{1,2})\s*hafta\s+sonra').firstMatch(lower);
    if (tw != null) {
      final n = int.tryParse(tw.group(1)!);
      if (n != null && n >= 1 && n <= 52) return today.add(Duration(days: n * 7));
    }
    return null;
  }

  // ── Absolute date (day + month name, or numeric) ───────────────────────────
  static DateTime? _detectAbsoluteDate(String lower, DateTime today) {
    // 1) Japanese: „12月12日" / „12月"
    final ja = RegExp(r'(\d{1,2})\s*月\s*(?:(\d{1,2})\s*日)?').firstMatch(lower);
    if (ja != null) {
      final mo = int.tryParse(ja.group(1)!);
      final day = ja.group(2) != null ? int.tryParse(ja.group(2)!) : 1;
      if (mo != null && day != null) {
        final dt = _makeFuture(today, day, mo);
        if (dt != null) return dt;
      }
    }

    // 2) Month-name forms (both orders) for the current language set.
    final alt = _monthAlt();
    if (alt.isNotEmpty) {
      // day + month: „12 декември", „12 дек.", „3 януари"
      final dm = RegExp('(\\d{1,2})\\s*\\.?\\s*($alt)').firstMatch(lower);
      if (dm != null) {
        final day = int.tryParse(dm.group(1)!);
        final mo = _monthOf(dm.group(2)!);
        if (day != null && mo != null) {
          final dt = _makeFuture(today, day, mo);
          if (dt != null) return dt;
        }
      }
      // month + day: „Dec 12", „декември 12"
      final md = RegExp('($alt)\\.?\\s+(\\d{1,2})').firstMatch(lower);
      if (md != null) {
        final mo = _monthOf(md.group(1)!);
        final day = int.tryParse(md.group(2)!);
        if (day != null && mo != null) {
          final dt = _makeFuture(today, day, mo);
          if (dt != null) return dt;
        }
      }
    }

    // 3) Numeric day-first: „12.12", „12.12.2026", „12/12". Разделител само „."
    //    или „/" — НЕ „-" (бърка се с резултати/диапазони: „3-1"). Отхвърля се,
    //    ако веднага след числото има валута/мярка/процент („10.05 лв", „2.5 кг",
    //    „20%") или ако пред него стои „версия/version/v" („Версия 1.0.70").
    final num = RegExp(
      r'\b(\d{1,2})[./](\d{1,2})(?:[./](\d{2,4}))?\b(?!\s*(?:кг|kg|мл|ml|см|cm|км|km|лв|лев|eur|usd|€|\$|%))',
    ).firstMatch(lower);
    if (num != null) {
      final before = lower.substring(0, num.start);
      final isVersion = RegExp(r'(?:верси\w*|version|\bv)\s*$').hasMatch(before);
      final day = int.tryParse(num.group(1)!);
      final mo = int.tryParse(num.group(2)!);
      final yRaw = num.group(3) != null ? int.tryParse(num.group(3)!) : null;
      if (!isVersion && day != null && mo != null && mo >= 1 && mo <= 12 && day >= 1 && day <= 31) {
        if (yRaw != null) {
          final year = yRaw < 100 ? 2000 + yRaw : yRaw;
          return DateTime(year, mo, day);
        }
        final dt = _makeFuture(today, day, mo);
        if (dt != null) return dt;
      }
    }
    return null;
  }

  /// Builds a date for [day]/[month] in the current year; if that day is before
  /// today, rolls to next year (so „12 декември" is always the next occurrence).
  static DateTime? _makeFuture(DateTime today, int day, int month) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    var candidate = DateTime(today.year, month, day);
    // Guard against overflow (e.g. 31 of a 30-day month → next month).
    if (candidate.month != month || candidate.day != day) return null;
    if (candidate.isBefore(today)) {
      candidate = DateTime(today.year + 1, month, day);
    }
    return candidate;
  }

  // ── Month-name tables (full + abbreviations + common inflections) ──────────
  // Index 0 = January … 11 = December. Variants are lowercase.
  static const Map<int, List<String>> _months = <int, List<String>>{
    1: ['january', 'januari', 'januar', 'janvier', 'gennaio', 'enero', 'janeiro',
        'январь', 'января', 'янв', 'ocak', 'січень', 'січня', 'ιανουάριος',
        'ιανουαρίου', 'ιαν', 'януари', 'яну', 'ян', 'jan'],
    2: ['february', 'februari', 'februar', 'février', 'fevrier', 'febbraio',
        'febrero', 'fevereiro', 'февраль', 'февраля', 'фев', 'şubat', 'subat',
        'лютий', 'лютого', 'φεβρουάριος', 'φεβρουαρίου', 'февруари', 'феб', 'feb',
        'fév', 'fev'],
    3: ['march', 'maart', 'märz', 'marz', 'mars', 'marzo', 'março', 'marco',
        'март', 'марта', 'mart', 'березень', 'березня', 'μάρτιος', 'μαρτίου',
        'мар', 'mär', 'mar'],
    4: ['april', 'avril', 'aprile', 'abril', 'апрель', 'апреля', 'nisan',
        'квітень', 'квітня', 'απρίλιος', 'απριλίου', 'април', 'апр', 'abr', 'apr'],
    5: ['may', 'mei', 'mai', 'maggio', 'mayo', 'maio', 'май', 'мая', 'mayıs',
        'mayis', 'травень', 'травня', 'μάιος', 'μαΐου', 'май', 'mag', 'maj'],
    6: ['june', 'juni', 'juin', 'giugno', 'junio', 'junho', 'июнь', 'июня',
        'haziran', 'червень', 'червня', 'ιούνιος', 'ιουνίου', 'юни', 'jun',
        'giu', 'jui'],
    7: ['july', 'juli', 'juillet', 'luglio', 'julio', 'julho', 'июль', 'июля',
        'temmuz', 'липень', 'липня', 'ιούλιος', 'ιουλίου', 'юли', 'jul', 'lug'],
    8: ['august', 'augustus', 'auguste', 'août', 'aout', 'agosto', 'август',
        'августа', 'ağustos', 'agustos', 'серпень', 'серпня', 'αύγουστος',
        'αυγούστου', 'авг', 'aug', 'aoû', 'ago', 'ağu'],
    9: ['september', 'septembre', 'settembre', 'septiembre', 'setembro',
        'сентябрь', 'сентября', 'eylül', 'eylul', 'вересень', 'вересня',
        'σεπτέμβριος', 'σεπτεμβρίου', 'септември', 'септ', 'сеп', 'set', 'sep'],
    10: ['october', 'oktober', 'octobre', 'ottobre', 'octubre', 'outubro',
         'октябрь', 'октября', 'ekim', 'жовтень', 'жовтня', 'οκτώβριος',
         'οκτωβρίου', 'октомври', 'окт', 'ott', 'oct', 'okt'],
    11: ['november', 'novembre', 'noviembre', 'novembro', 'ноябрь', 'ноября',
         'kasım', 'kasim', 'листопад', 'листопада', 'νοέμβριος', 'νοεμβρίου',
         'ноември', 'ноем', 'ное', 'nov'],
    12: ['december', 'dezember', 'décembre', 'decembre', 'dicembre', 'diciembre',
         'dezembro', 'декабрь', 'декабря', 'aralık', 'aralik', 'грудень',
         'грудня', 'δεκέμβριος', 'δεκεμβρίου', 'декември', 'дек', 'déc', 'dez',
         'dic', 'dec'],
  };

  // All month variants as one regex alternation, longest-first so that full
  // names win over their own abbreviations (e.g. „декември" before „дек").
  static String? _monthAltCache;
  static Map<String, int>? _monthLookupCache;

  static void _buildMonthIndex() {
    final lookup = <String, int>{};
    final all = <String>[];
    _months.forEach((idx, variants) {
      for (final v in variants) {
        lookup[v] = idx;
        all.add(v);
      }
    });
    all.sort((a, b) => b.length.compareTo(a.length));
    _monthAltCache = all.join('|');
    _monthLookupCache = lookup;
  }

  static String _monthAlt() {
    if (_monthAltCache == null) _buildMonthIndex();
    return _monthAltCache!;
  }

  static int? _monthOf(String variant) {
    if (_monthLookupCache == null) _buildMonthIndex();
    return _monthLookupCache![variant.toLowerCase()];
  }

  static bool _matches(String lower, List<String> keywords) {
    for (final kw in keywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

  static String _label(DateTime date, String lang) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    if (date == today) {
      const m = {'en': 'Today', 'nl': 'Vandaag', 'uk': 'Сьогодні', 'bg': 'Днес', 'de': 'Heute', 'fr': "Aujourd'hui", 'it': 'Oggi', 'el': 'Σήμερα', 'es': 'Hoy', 'pt': 'Hoje', 'ru': 'Сегодня', 'tr': 'Bugün', 'ja': '今日'};
      return m[lang] ?? m['en']!;
    }
    if (date == tomorrow) {
      const m = {'en': 'Tomorrow', 'nl': 'Morgen', 'uk': 'Завтра', 'bg': 'Утре', 'de': 'Morgen', 'fr': 'Demain', 'it': 'Domani', 'el': 'Αύριο', 'es': 'Mañana', 'pt': 'Amanhã', 'ru': 'Завтра', 'tr': 'Yarın', 'ja': '明日'};
      return m[lang] ?? m['en']!;
    }

    const weekdays = <String, List<String>>{
      'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'], 'nl': ['ma', 'di', 'wo', 'do', 'vr', 'za', 'zo'], 'uk': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'],
      'bg': ['Пон', 'Вт', 'Ср', 'Чет', 'Пет', 'Съб', 'Нед'],
      'de': ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'],
      'fr': ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'],
      'it': ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'],
      'el': ['Δευ', 'Τρι', 'Τετ', 'Πεμ', 'Παρ', 'Σαβ', 'Κυρ'],
      'es': ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'],
      'pt': ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'],
      'ru': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
      'tr': ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'],
    };
    const months = <String, List<String>>{
      'en': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'], 'nl': ['jan', 'feb', 'mrt', 'apr', 'mei', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec'], 'uk': ['січ', 'лют', 'бер', 'квіт', 'трав', 'черв', 'лип', 'серп', 'вер', 'жовт', 'лист', 'груд'],
      'bg': ['яну', 'фев', 'мар', 'апр', 'май', 'юни', 'юли', 'авг', 'сеп', 'окт', 'ное', 'дек'],
      'de': ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'],
      'fr': ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'],
      'it': ['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'],
      'el': ['Ιαν', 'Φεβ', 'Μαρ', 'Απρ', 'Μαϊ', 'Ιουν', 'Ιουλ', 'Αυγ', 'Σεπ', 'Οκτ', 'Νοε', 'Δεκ'],
      'es': ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'],
      'pt': ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'],
      'ru': ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'],
      'tr': ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'],
    };

    final wd = (weekdays[lang] ?? weekdays['en']!)[date.weekday - 1];
    final mo = (months[lang] ?? months['en']!)[date.month - 1];
    return '$wd, ${date.day} $mo';
  }
}
