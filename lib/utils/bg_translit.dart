/// Локална нормализация и латинизация на български лични имена за съвпадане
/// на контакти с именни дни. ВСИЧКО е on-device — нито едно име не напуска
/// устройството; този файл прави само текстови трансформации, без I/O.
///
/// Стратегията НЕ е транслитерация латиница→кирилица (многозначна и
/// ненадеждна: Yordan/Iordan/Jordan, Tsvetan/Cvetan, Hristo/Christo). Вместо
/// това привеждаме ДВЕТЕ страни до обща сравнима форма:
///   • [canonCyrillic] — за кирилица↔кирилица сравнение;
///   • [canonLatin] — фонетичен „скелет" за латиница, който слива проблемните
///     звуци (ts↔c, ch↔h, ya↔ia, yu↔iu, y↔i↔j…), за да хване
///     Tsvetan=Cvetan, Christo=Hristo, Iordan=Yordan=Jordan.
///
/// [keysFor] връща и двата ключа за дадена дума — еднакъв код се ползва и при
/// индексиране на контактите, и при заявка по име от dataset-а, така че
/// съвпадането е симетрично (кирилски контакт ↔ кирилско име, латински контакт
/// ↔ латинската форма на кирилското име).
library;

class BgTranslit {
  BgTranslit._();

  /// Официална българска транслитерация (Закон за транслитерацията, 2009)
  /// кирилица → латиница. Прилага се за кирилските имена, за да получим
  /// латинската им форма, която сравняваме с латински контакти.
  static const Map<String, String> _cyrToLat = {
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ж': 'zh',
    'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n',
    'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u', 'ф': 'f',
    'х': 'h', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'sht', 'ъ': 'a',
    'ь': 'y', 'ю': 'yu', 'я': 'ya', 'ё': 'yo',
  };

  /// Диакритика → базова латинска буква (по групи, за да е независимо от
  /// дължина на низа). Покрива най-честите букви в имена.
  static const Map<String, String> _diacriticGroups = {
    'a': 'àáâãäåāăą',
    'c': 'çćč',
    'd': 'ďđ',
    'e': 'èéêëēĕėęě',
    'g': 'ğ',
    'i': 'ìíîïĩīĭįı',
    'n': 'ñńňņ',
    'o': 'òóôõöøōŏő',
    'r': 'ŕř',
    's': 'śšşș',
    't': 'ťțţ',
    'u': 'ùúûüũūŭůűų',
    'y': 'ýÿ',
    'z': 'źżž',
  };

  static final Map<String, String> _diacriticMap = _buildDiacriticMap();

  static Map<String, String> _buildDiacriticMap() {
    final m = <String, String>{};
    _diacriticGroups.forEach((base, chars) {
      for (final ch in chars.split('')) {
        m[ch] = base;
      }
    });
    return m;
  }

  static String _stripDiacritics(String s) {
    final sb = StringBuffer();
    for (final ch in s.split('')) {
      sb.write(_diacriticMap[ch] ?? ch);
    }
    return sb.toString();
  }

  /// Обща нормализация: lowercase + сваляне на диакритика + collapse интервали.
  static String normalize(String s) {
    var r = s.toLowerCase().trim();
    r = _stripDiacritics(r);
    r = r.replaceAll(RegExp(r'\s+'), ' ').trim();
    return r;
  }

  static final RegExp _cyrillicChar = RegExp(r'[а-яё]');

  /// Транслитерира кирилски низ към официална латиница (буква по буква).
  static String toLatin(String input) {
    final s = input.toLowerCase();
    final sb = StringBuffer();
    for (final ch in s.split('')) {
      sb.write(_cyrToLat[ch] ?? ch);
    }
    return sb.toString();
  }

  /// Нормализирана кирилска форма: само кирилските букви на думата.
  /// За чисто латинска дума връща празно (тогава ползвай [canonLatin]).
  static String canonCyrillic(String word) {
    return normalize(word).replaceAll(RegExp(r'[^а-яё]'), '');
  }

  /// Фонетичен „скелет" на латиница. Кирилицата първо се латинизира; после
  /// проблемните диграфи се сливат, за да съвпаднат алтернативните изписвания.
  static String canonLatin(String word) {
    var s = word.toLowerCase();
    if (_cyrillicChar.hasMatch(s)) s = toLatin(s);
    s = _stripDiacritics(s);
    s = s.replaceAll(RegExp(r'[^a-z]'), '');
    if (s.isEmpty) return '';
    // Ред има значение — по-дългите диграфи първи.
    s = s.replaceAll('sht', '1'); // щ
    s = s.replaceAll('sh', '2'); // ш
    s = s.replaceAll('ch', 'h'); // ч ↔ h (Christo = Hristo)
    s = s.replaceAll('kh', 'h'); // алт. изписване на х
    s = s.replaceAll('zh', 'z'); // ж → z (слива)
    s = s.replaceAll('ts', 'c'); // ц ↔ c (Tsvetan = Cvetan)
    s = s.replaceAll('ya', 'ia');
    s = s.replaceAll('yu', 'iu');
    s = s.replaceAll('yo', 'io');
    s = s.replaceAll('y', 'i'); // й → i
    s = s.replaceAll('j', 'i'); // Jordan → iordan
    s = s.replaceAll('w', 'v');
    s = s.replaceAll('x', 'ks');
    // Събаряне на повтарящи се букви (anna → ana).
    s = s.replaceAll(RegExp(r'(.)\1+'), r'$1');
    return s;
  }

  /// Връща ключовете за дума: кирилски (`c:`) и/или латински скелет (`l:`).
  /// Празните се пропускат. Ползва се симетрично при индекс и при заявка.
  static Set<String> keysFor(String word) {
    final keys = <String>{};
    final c = canonCyrillic(word);
    if (c.isNotEmpty) keys.add('c:$c');
    final l = canonLatin(word);
    if (l.isNotEmpty) keys.add('l:$l');
    return keys;
  }
}
