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

    // ── Time detection (e.g. 15:30 / 15ч / 9h) ──
    TimeOfDay? detectedTime;
    final colonTime = RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(lower);
    final shortTime = RegExp(r'\b(\d{1,2})\s*(?:ч|h)\b').firstMatch(lower);
    if (colonTime != null) {
      final h = int.tryParse(colonTime.group(1)!);
      final m = int.tryParse(colonTime.group(2)!);
      if (h != null && m != null && h <= 23 && m <= 59) {
        detectedTime = TimeOfDay(hour: h, minute: m);
      }
    } else if (shortTime != null) {
      final h = int.tryParse(shortTime.group(1)!);
      if (h != null && h <= 23) {
        detectedTime = TimeOfDay(hour: h, minute: 0);
      }
    }

    // ── Keyword maps ──

    // Today
    if (_matches(lower, const [
      'днес', 'today', 'heute', "aujourd'hui", 'oggi',
      'σήμερα', 'hoy', 'hoje', 'сегодня', 'bugün',
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

    // Time only → today
    if (detectedTime != null) {
      return NlpResult(date: today, time: detectedTime, label: _label(today, lang));
    }

    return null;
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
      const m = {'en': 'Today', 'bg': 'Днес', 'de': 'Heute', 'fr': "Aujourd'hui", 'it': 'Oggi', 'el': 'Σήμερα', 'es': 'Hoy', 'pt': 'Hoje', 'ru': 'Сегодня', 'tr': 'Bugün'};
      return m[lang] ?? m['en']!;
    }
    if (date == tomorrow) {
      const m = {'en': 'Tomorrow', 'bg': 'Утре', 'de': 'Morgen', 'fr': 'Demain', 'it': 'Domani', 'el': 'Αύριο', 'es': 'Mañana', 'pt': 'Amanhã', 'ru': 'Завтра', 'tr': 'Yarın'};
      return m[lang] ?? m['en']!;
    }

    const weekdays = <String, List<String>>{
      'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
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
      'en': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
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
