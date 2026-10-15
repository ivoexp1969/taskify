import 'package:flutter/foundation.dart';

/// Временни развойни override-и за ръчно тестване на изтичане на trial/промо и
/// на имен-ден логиката за конкретна дата (напр. 8 ноември).
///
/// ★ АКТИВНИ САМО в debug билд (`kDebugMode`).★ В release всеки getter връща
/// реалните стойности, а всеки setter е no-op — панелът няма абсолютно никакъв
/// ефект върху крайните потребители, затова е безопасно да остане в кода.
class DebugOverrides {
  DebugOverrides._();

  static DateTime? _fakeNow;
  static bool _forceTrialExpired = false;

  /// Текущият момент с приложен override. В release = `DateTime.now()`.
  static DateTime now() =>
      (kDebugMode && _fakeNow != null) ? _fakeNow! : DateTime.now();

  /// true → trial се смята за изтекъл независимо от записаната начална дата.
  static bool get forceTrialExpired => kDebugMode && _forceTrialExpired;

  /// Фалшивото „днес" (или null, ако не е зададено). В release винаги null.
  static DateTime? get fakeNow => kDebugMode ? _fakeNow : null;

  static set fakeNow(DateTime? value) {
    if (kDebugMode) _fakeNow = value;
  }

  static set forceTrialExpired(bool value) {
    if (kDebugMode) _forceTrialExpired = value;
  }

  /// Има ли изобщо активен override (за видим индикатор в debug UI).
  static bool get isActive =>
      kDebugMode && (_fakeNow != null || _forceTrialExpired);
}
