/// Почиства бележките на задача за показване в КАЛЕНДАРНО събитие (Apple/Google).
///
/// Шаблонните задачи (документ, пътуване, среща, подарък, плащане, тренировка…)
/// кодират вътрешни метаданни в `notes` като редове `ключ:стойност`
/// (`doctype:passport`, `dest:London`, `with:Иван`, `amount:50`…). Тези редове
/// са технически и НЕ бива да изтичат в текста на календарното събитие.
///
/// Връща само свободния текст на потребителя (редовете без известен префикс).
/// За чисто шаблонна задача обикновено връща празен низ (заглавието вече носи
/// смисъла), вместо да показва суровите метаданни.
library;

/// Известните вътрешни префикси, използвани от шаблонните диалози.
const Set<String> _metaPrefixes = {
  'doctype:', 'label:', // document
  'dest:', 'return:', // travel
  'with:', 'place:', // meeting
  'for:', 'occasion:', 'budget:', // gift
  'what:', 'amount:', // payment
  'type:', 'duration:', // workout
};

/// Маха редовете с вътрешни метаданни, оставя свободния текст на потребителя.
String cleanCalendarNotes(String? notes) {
  if (notes == null || notes.trim().isEmpty) return '';
  final kept = notes.split('\n').where((line) {
    final l = line.trimLeft();
    return !_metaPrefixes.any((p) => l.startsWith(p));
  });
  return kept.join('\n').trim();
}
