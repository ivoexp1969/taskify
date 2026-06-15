/// Единен формат за подзадачи между ЛИЧНИ и СПОДЕЛЕНИ (групови) задачи.
///
/// Подзадачите се пазят като `List<String>` в каноничния формат
/// `"done:qty:text"` (напр. `"0:1:Купи цимент"`), със стар (legacy) вариант
/// `"done:text"` (напр. `"1:Готово"`). `done` е `0` (незавършена) или `1`
/// (завършена); `qty` е количество (по подразбиране 1).
///
/// ВАЖНО: лични (`Task.subtasksList`/`setSubtasks`) и групови задачи трябва да
/// минават през ТОЗИ helper, за да не се разминават форматите. Историческа
/// грешка: AI breakdown за групови задачи пазеше суров текст без префикс, та
/// UI-ят и броячът „X/Y" се чупеха.
class SubtaskCodec {
  const SubtaskCodec._();

  /// Парсва един запис към `{'done': bool, 'qty': int, 'text': String}`.
  /// Толерира и суров текст без префикс (напр. „Купи цимент") → третира го
  /// като незавършена подзадача, а целия низ — като текст.
  static Map<String, dynamic> parse(String raw) {
    final parts = raw.split(':');
    // Валиден префикс: започва с "0" или "1" и има поне още един сегмент.
    if (parts.length >= 2 && (parts[0] == '0' || parts[0] == '1')) {
      final done = parts[0] == '1';
      // "done:qty:text" — qty трябва да е число, иначе го третираме като "done:text".
      if (parts.length >= 3 && int.tryParse(parts[1]) != null) {
        return {
          'done': done,
          'qty': int.parse(parts[1]),
          'text': parts.sublist(2).join(':'),
        };
      }
      return {'done': done, 'qty': 1, 'text': parts.sublist(1).join(':')};
    }
    // Без валиден префикс → суров текст (вкл. заглавия с „:", напр. „16:30 час").
    return {'done': false, 'qty': 1, 'text': raw};
  }

  /// Сглобява каноничния низ `"done:qty:text"`.
  static String format({bool done = false, int qty = 1, required String text}) {
    return '${done ? 1 : 0}:$qty:$text';
  }

  /// Нормализира произволен запис към каноничния формат. Суровите заглавия без
  /// префикс стават незавършени подзадачи.
  static String normalize(String raw) {
    final p = parse(raw);
    return format(
      done: p['done'] as bool,
      qty: p['qty'] as int,
      text: p['text'] as String,
    );
  }
}
