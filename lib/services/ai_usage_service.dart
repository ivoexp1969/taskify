import 'package:shared_preferences/shared_preferences.dart';

import 'pro_service.dart';

/// Клиентски rate limit за AI заявки + AI настройки (парсване / глас).
///
/// Пази се изцяло в SharedPreferences (НЕ Hive). Броячът се reset-ва в
/// полунощ local time чрез сравнение на запазен ден-ключ (yyyy-MM-dd) с
/// днешния — без таймери.
///
/// ФАЗА 2 (монетизация): AI е freemium. **Free** потребители имат [dailyLimit]
/// разпознавания на ден; **Pro** е неограничен (bypass в [canUse]) и НЕ
/// консумира квота ([recordUse] е no-op за Pro), така че броячът важи само за free.
class AiUsageService {
  AiUsageService._();
  static final AiUsageService instance = AiUsageService._();

  /// Дневен таван на AI заявки за FREE потребители. Pro е неограничен.
  static const int dailyLimit = 3;

  static const String _kCount = 'ai_usage_count';
  static const String _kDate = 'ai_usage_date';
  static const String _kParsingEnabled = 'ai_parsing_enabled';
  static const String _kVoiceEnabled = 'voice_input_enabled';

  /// Ден-ключ в local time, напр. "2026-06-02". Pure функция — за тестове.
  static String dateKeyFor(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// Изчислява използваните днес след reset логиката. Pure функция — за
  /// тестове: ако запазеният ден ≠ днешния → 0 (нов ден => reset).
  static int resolveUsed({
    required String? storedDate,
    required int storedCount,
    required String todayKey,
  }) {
    if (storedDate != todayKey) return 0;
    return storedCount;
  }

  Future<int> usedToday() async {
    final prefs = await SharedPreferences.getInstance();
    return resolveUsed(
      storedDate: prefs.getString(_kDate),
      storedCount: prefs.getInt(_kCount) ?? 0,
      todayKey: dateKeyFor(DateTime.now()),
    );
  }

  Future<int> remainingToday() async => dailyLimit - await usedToday();

  /// Pro → винаги true (неограничено). Free → до [dailyLimit] на ден.
  Future<bool> canUse() async {
    if (ProService().isPro) return true;
    return (await usedToday()) < dailyLimit;
  }

  /// Записва една успешна AI заявка. Reset-ва брояча при нов ден.
  /// За Pro е no-op — неограничените заявки не консумират квота.
  Future<void> recordUse() async {
    if (ProService().isPro) return;
    final prefs = await SharedPreferences.getInstance();
    final todayKey = dateKeyFor(DateTime.now());
    final current = resolveUsed(
      storedDate: prefs.getString(_kDate),
      storedCount: prefs.getInt(_kCount) ?? 0,
      todayKey: todayKey,
    );
    await prefs.setString(_kDate, todayKey);
    await prefs.setInt(_kCount, current + 1);
  }

  Future<bool> isParsingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kParsingEnabled) ?? true;
  }

  Future<void> setParsingEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kParsingEnabled, value);
  }

  Future<bool> isVoiceEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kVoiceEnabled) ?? true;
  }

  Future<void> setVoiceEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVoiceEnabled, value);
  }
}
