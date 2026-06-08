import 'dart:math';

/// Лек генератор на UUID v4 без външна зависимост (работи на mobile + web).
/// Използва се за стабилния `Task.id`, който е мостът на merge синхронизацията.
class Uuid {
  static final Random _rng = Random.secure();

  static String v4() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    // Версия 4 + variant bits по RFC 4122.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final s = bytes.map(hex).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}'
        '-${s.substring(16, 20)}-${s.substring(20)}';
  }
}
