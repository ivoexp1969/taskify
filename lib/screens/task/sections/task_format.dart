import 'package:flutter/material.dart';

import '../../../models/category.dart';
import '../../../utils/localization.dart';

/// Чисти форматиращи helper-и, споделяни от списъка със задачи (`task_screen`)
/// и редактора (`TaskEditorSheet`). Изнесени verbatim от `task_screen.dart`.

String formatDate(DateTime d) {
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  final year = d.year.toString();
  return '$day.$month.$year';
}

String formatTime(TimeOfDay? t) {
  if (t == null) return '--:--';
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String localizedCategoryName(Category? c, AppText t) {
  if (c == null) return '';
  // Календарната категория не е „default", но id-то е фиксирано → локализира се винаги.
  if (c.id == 'cal_events') return t.catCalendarEvents;
  if (c.id == 'documents') return t.catDocuments;
  if (c.isDefault) {
    return {
          'work': t.work,
          'personal': t.personal,
          'shopping': t.shopping,
          'birthday': t.catBirthdays,
          'meeting': t.catMeeting,
          'workout': t.catWorkout,
          'payment': t.catPayment,
          'travel': t.catTravel,
          'gift': t.catGift,
        }[c.id] ??
        c.name;
  }
  return c.name;
}

/// Етикет „Училище" на 11 езика (за синтетичния чип „🎒 Училище").
const Map<String, String> schoolLabel = {
  'en': 'School', 'bg': 'Училище', 'de': 'Schule', 'fr': 'École',
  'it': 'Scuola', 'el': 'Σχολείο', 'es': 'Escuela', 'pt': 'Escola',
  'ru': 'Школа', 'tr': 'Okul', 'ja': '学校',
};
