import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/debug_overrides.dart';
import 'analytics_service.dart';

// Условен import - stub за web, реален пакет за mobile
import 'purchases_stub.dart' if (dart.library.io) 'package:purchases_flutter/purchases_flutter.dart';

// Localized promo/status messages
const _proMsg = {
  'notAvailableWeb': {'en': 'Not available on web', 'nl': 'Niet beschikbaar op web', 'uk': 'Недоступно у веб-версії', 'bg': 'Не е налично на web', 'de': 'Nicht im Web verfügbar', 'fr': 'Non disponible sur le web', 'it': 'Non disponibile sul web', 'el': 'Δεν είναι διαθέσιμο στο web', 'es': 'No disponible en la web', 'pt': 'Não disponível na web', 'ru': 'Недоступно в вебе', 'tr': 'Web\'de kullanılamaz', 'ja': 'ウェブでは利用できません'},
  'invalidCode': {'en': 'Invalid code', 'nl': 'Ongeldige code', 'uk': 'Недійсний код', 'bg': 'Невалиден код', 'de': 'Ungültiger Code', 'fr': 'Code invalide', 'it': 'Codice non valido', 'el': 'Μη έγκυρος κωδικός', 'es': 'Código inválido', 'pt': 'Código inválido', 'ru': 'Неверный код', 'tr': 'Geçersiz kod', 'ja': '無効なコード'},
  'codeInactive': {'en': 'Code is not active', 'nl': 'Code is niet actief', 'uk': 'Код неактивний', 'bg': 'Кодът не е активен', 'de': 'Code ist nicht aktiv', 'fr': 'Code non actif', 'it': 'Codice non attivo', 'el': 'Ο κωδικός δεν είναι ενεργός', 'es': 'El código no está activo', 'pt': 'Código não está ativo', 'ru': 'Код не активен', 'tr': 'Kod aktif değil', 'ja': 'コードは無効です'},
  'codeExpired': {'en': 'Code has expired', 'nl': 'Code is verlopen', 'uk': 'Термін дії коду минув', 'bg': 'Кодът е изтекъл', 'de': 'Code ist abgelaufen', 'fr': 'Code expiré', 'it': 'Codice scaduto', 'el': 'Ο κωδικός έχει λήξει', 'es': 'El código ha expirado', 'pt': 'Código expirado', 'ru': 'Код истёк', 'tr': 'Kodun süresi dolmuş', 'ja': 'コードの有効期限が切れています'},
  'codeUsedUp': {'en': 'Code is used up', 'nl': 'Code is opgebruikt', 'uk': 'Код вичерпано', 'bg': 'Кодът е изчерпан', 'de': 'Code aufgebraucht', 'fr': 'Code épuisé', 'it': 'Codice esaurito', 'el': 'Ο κωδικός εξαντλήθηκε', 'es': 'Código agotado', 'pt': 'Código esgotado', 'ru': 'Код исчерпан', 'tr': 'Kod tükendi', 'ja': 'コードは使い切られています'},
  'alreadyUsed': {'en': 'You already used this code', 'nl': 'Je hebt deze code al gebruikt', 'uk': 'Ви вже використали цей код', 'bg': 'Вече си използвал този код', 'de': 'Du hast diesen Code bereits verwendet', 'fr': 'Vous avez déjà utilisé ce code', 'it': 'Hai già usato questo codice', 'el': 'Έχετε ήδη χρησιμοποιήσει αυτόν τον κωδικό', 'es': 'Ya usaste este código', 'pt': 'Você já usou este código', 'ru': 'Вы уже использовали этот код', 'tr': 'Bu kodu zaten kullandınız', 'ja': 'このコードはすでに使用済みです'},
  'proReactivated': {'en': 'Pro reactivated!', 'nl': 'Pro opnieuw geactiveerd!', 'uk': 'Pro знову активовано!', 'bg': 'Pro активиран отново!', 'de': 'Pro reaktiviert!', 'fr': 'Pro réactivé!', 'it': 'Pro riattivato!', 'el': 'Pro επανενεργοποιήθηκε!', 'es': '¡Pro reactivado!', 'pt': 'Pro reativado!', 'ru': 'Pro активирован повторно!', 'tr': 'Pro yeniden etkinleştirildi!', 'ja': 'Proを再有効化しました！'},
  'proLifetime': {'en': 'Congratulations! You have Pro forever!', 'nl': 'Gefeliciteerd! Je hebt Pro voor altijd!', 'uk': 'Вітаємо! У вас Pro назавжди!', 'bg': 'Поздравления! Имаш Pro завинаги!', 'de': 'Glückwunsch! Du hast Pro für immer!', 'fr': 'Félicitations! Vous avez Pro à vie!', 'it': 'Congratulazioni! Hai Pro per sempre!', 'el': 'Συγχαρητήρια! Έχετε Pro για πάντα!', 'es': '¡Felicidades! ¡Tienes Pro para siempre!', 'pt': 'Parabéns! Você tem Pro para sempre!', 'ru': 'Поздравляем! У вас Pro навсегда!', 'tr': 'Tebrikler! Sonsuza kadar Pro\'sunuz!', 'ja': 'おめでとうございます！Proを永久にご利用いただけます！'},
  'error': {'en': 'Error', 'nl': 'Fout', 'uk': 'Помилка', 'bg': 'Грешка', 'de': 'Fehler', 'fr': 'Erreur', 'it': 'Errore', 'el': 'Σφάλμα', 'es': 'Error', 'pt': 'Erro', 'ru': 'Ошибка', 'tr': 'Hata', 'ja': 'エラー'},
  // Приятелско съобщение при неочаквана грешка — БЕЗ суров exception текст.
  'genericError': {'en': 'Something went wrong. Check your connection and try again.', 'nl': 'Er ging iets mis. Controleer je verbinding en probeer opnieuw.', 'uk': 'Щось пішло не так. Перевірте з\'єднання та спробуйте ще раз.', 'bg': 'Нещо се обърка. Провери връзката и опитай пак.', 'de': 'Etwas ist schiefgelaufen. Prüfe deine Verbindung und versuche es erneut.', 'fr': 'Un problème est survenu. Vérifie ta connexion et réessaie.', 'it': 'Qualcosa è andato storto. Controlla la connessione e riprova.', 'el': 'Κάτι πήγε στραβά. Έλεγξε τη σύνδεσή σου και δοκίμασε ξανά.', 'es': 'Algo salió mal. Revisa tu conexión e inténtalo de nuevo.', 'pt': 'Algo correu mal. Verifica a tua ligação e tenta novamente.', 'ru': 'Что-то пошло не так. Проверь соединение и попробуй снова.', 'tr': 'Bir şeyler ters gitti. Bağlantını kontrol edip tekrar dene.', 'ja': '問題が発生しました。接続を確認してもう一度お試しください。'},
  'webVersion': {'en': 'Web version', 'nl': 'Webversie', 'uk': 'Веб-версія', 'bg': 'Web версия', 'de': 'Web-Version', 'fr': 'Version web', 'it': 'Versione web', 'el': 'Έκδοση web', 'es': 'Versión web', 'pt': 'Versão web', 'ru': 'Веб-версия', 'tr': 'Web sürümü', 'ja': 'ウェブ版'},
  'proPaid': {'en': 'Pro (paid)', 'nl': 'Pro (betaald)', 'uk': 'Pro (платно)', 'bg': 'Pro (платен)', 'de': 'Pro (bezahlt)', 'fr': 'Pro (payé)', 'it': 'Pro (pagato)', 'el': 'Pro (πληρωμένο)', 'es': 'Pro (pagado)', 'pt': 'Pro (pago)', 'ru': 'Pro (оплачено)', 'tr': 'Pro (ücretli)', 'ja': 'Pro（有料）'},
  'proPromoLifetime': {'en': 'Pro (promo - lifetime)', 'nl': 'Pro (promo - levenslang)', 'uk': 'Pro (промо - довічно)', 'bg': 'Pro (промо код - завинаги)', 'de': 'Pro (Promo - lebenslang)', 'fr': 'Pro (promo - à vie)', 'it': 'Pro (promo - a vita)', 'el': 'Pro (προσφορά - εφ\' όρου ζωής)', 'es': 'Pro (promo - de por vida)', 'pt': 'Pro (promo - vitalício)', 'ru': 'Pro (промо - навсегда)', 'tr': 'Pro (promosyon - ömür boyu)', 'ja': 'Pro（プロモ - 買い切り）'},
  'free': {'en': 'Free', 'nl': 'Gratis', 'uk': 'Безкоштовно', 'bg': 'Безплатен', 'de': 'Kostenlos', 'fr': 'Gratuit', 'it': 'Gratuito', 'el': 'Δωρεάν', 'es': 'Gratis', 'pt': 'Grátis', 'ru': 'Бесплатно', 'tr': 'Ücretsiz', 'ja': '無料'},
};

String _pm(String key, String lang) => _proMsg[key]?[lang] ?? _proMsg[key]?['en'] ?? '';

String _proForDays(int days, String lang) {
  const m = {'en': 'Congratulations! You have Pro for DAYS days!', 'nl': 'Gefeliciteerd! Je hebt Pro voor DAYS dagen!', 'uk': 'Вітаємо! У вас Pro на DAYS днів!', 'bg': 'Поздравления! Имаш Pro за DAYS дни!', 'de': 'Glückwunsch! Du hast Pro für DAYS Tage!', 'fr': 'Félicitations! Vous avez Pro pour DAYS jours!', 'it': 'Congratulazioni! Hai Pro per DAYS giorni!', 'el': 'Συγχαρητήρια! Έχετε Pro για DAYS ημέρες!', 'es': '¡Felicidades! ¡Tienes Pro por DAYS días!', 'pt': 'Parabéns! Você tem Pro por DAYS dias!', 'ru': 'Поздравляем! У вас Pro на DAYS дней!', 'tr': 'Tebrikler! DAYS gün Pro\'sunuz!', 'ja': 'おめでとうございます！Proを残りDAYS日間ご利用いただけます！'};
  return (m[lang] ?? m['en']!).replaceAll('DAYS', '$days');
}

/// Правилна форма на думата „ден" за броя [n] на езика [lang] (огледало на
/// AppText.dayNoun — тук е нужна извън контекст на widget).
String _dayWord(int n, String lang) {
  int m10 = n % 10, m100 = n % 100;
  switch (lang) {
    case 'bg': return n == 1 ? 'ден' : 'дни';
    case 'de': return n == 1 ? 'Tag' : 'Tage';
    case 'nl': return n == 1 ? 'dag' : 'dagen';
    case 'fr': return n == 1 ? 'jour' : 'jours';
    case 'it': return n == 1 ? 'giorno' : 'giorni';
    case 'el': return n == 1 ? 'ημέρα' : 'ημέρες';
    case 'es': return n == 1 ? 'día' : 'días';
    case 'pt': return n == 1 ? 'dia' : 'dias';
    case 'tr': return 'gün';
    case 'ja': return '日';
    case 'ru':
      if (m10 == 1 && m100 != 11) return 'день';
      if (m10 >= 2 && m10 <= 4 && !(m100 >= 12 && m100 <= 14)) return 'дня';
      return 'дней';
    case 'uk':
      if (m10 == 1 && m100 != 11) return 'день';
      if (m10 >= 2 && m10 <= 4 && !(m100 >= 12 && m100 <= 14)) return 'дні';
      return 'днів';
    case 'en':
    default: return n == 1 ? 'day' : 'days';
  }
}

String _proPromoDays(int days, String lang) {
  const m = {'en': 'Pro (promo - DAYS {D})', 'nl': 'Pro (promo - DAYS {D})', 'uk': 'Pro (промо - DAYS {D})', 'bg': 'Pro (промо код - DAYS {D})', 'de': 'Pro (Promo - DAYS {D})', 'fr': 'Pro (promo - DAYS {D})', 'it': 'Pro (promo - DAYS {D})', 'el': 'Pro (προσφορά - DAYS {D})', 'es': 'Pro (promo - DAYS {D})', 'pt': 'Pro (promo - DAYS {D})', 'ru': 'Pro (промо - DAYS {D})', 'tr': 'Pro (promosyon - DAYS {D})', 'ja': 'Pro（プロモ - DAYS{D}）'};
  return (m[lang] ?? m['en']!).replaceAll('DAYS', '$days').replaceAll('{D}', _dayWord(days, lang));
}

String _proTrialDays(int days, String lang) {
  const m = {'en': 'Pro (trial - DAYS {D})', 'nl': 'Pro (proef - DAYS {D})', 'uk': 'Pro (пробний - DAYS {D})', 'bg': 'Pro (пробен период - DAYS {D})', 'de': 'Pro (Test - DAYS {D})', 'fr': 'Pro (essai - DAYS {D})', 'it': 'Pro (prova - DAYS {D})', 'el': 'Pro (δοκιμή - DAYS {D})', 'es': 'Pro (prueba - DAYS {D})', 'pt': 'Pro (teste - DAYS {D})', 'ru': 'Pro (пробный - DAYS {D})', 'tr': 'Pro (deneme - DAYS {D})', 'ja': 'Pro（トライアル - DAYS{D}）'};
  return (m[lang] ?? m['en']!).replaceAll('DAYS', '$days').replaceAll('{D}', _dayWord(days, lang));
}

/// Лимити за безплатната версия
class FreeLimits {
  static const int maxTasks = 50;
  static const int maxCategories = 10;
  static const int maxRemindersPerTask = 3;
  static const bool canUseRecurrence = true;
  static const bool canUseCalendar = true; // v1.0.70: Календар (изглед) безплатен
  static const bool canUseStatistics = false;
  static const bool canUseCloudSync = false;
  static const bool canUseWidget = false;
  static const bool canUseVoiceInput = true;
  static const bool canUseExportImport = false;
  static const bool canChangeTheme = true;
  static const bool canChangeLanguage = true;
  static const bool showAds = true;
}

/// Trial период в дни
const int trialPeriodDays = 14;

/// Entitlement идентификатор в RevenueCat (ТРЯБВА да съвпада с RevenueCat Dashboard!)
const String entitlementId = 'Taskify 1969 Pro';

/// Продуктови идентификатори (от Google Play Console)
const String productIdMonthly = 'premium_monthly:monthly';
const String productIdYearly = 'premium_yearly:yearly';
const String productIdLifetime = 'premium_lifetime';

/// Чиста (без странични ефекти) решаваща функция: Pro ли е потребителят СПРЯМО
/// подадения момент `now`? Държи цялата логика на едно място, за да е покрита с
/// unit тестове БЕЗ нужда от native RevenueCat/Firebase инициализация.
///
/// НИКОГА не заключва при: активен entitlement / офлайн платец (`paidOrCached`),
/// lifetime покупка или lifetime промо (`promoType == 'lifetime'`), активно
/// промо за дни, активен trial. Заключва само когато ВСИЧКИ причини са отпаднали
/// (изтекъл trial/промо и без платен статус).
@visibleForTesting
bool proActive({
  required bool paidOrCached,
  DateTime? trialEnd,
  String? promoType, // 'lifetime' | 'days' | null
  DateTime? promoEnd,
  required DateTime now,
  bool forceTrialExpired = false,
}) {
  if (paidOrCached) return true; // платец / офлайн платец (кеш) / активен entitlement
  if (promoType == 'lifetime') return true; // lifetime промо = завинаги
  if (promoType == 'days' && promoEnd != null && now.isBefore(promoEnd)) {
    return true; // активно промо за дни
  }
  if (!forceTrialExpired && trialEnd != null && now.isBefore(trialEnd)) {
    return true; // активен trial
  }
  return false;
}

class ProService extends ChangeNotifier {
  ProService._internal();

  static final ProService _instance = ProService._internal();
  factory ProService() => _instance;

  bool _isPro = false;
  bool _isInitialized = false;
  bool _isInitializing = false;
  // Тип промо, изведен от записаните данни: 'lifetime' | 'days' | null.
  String? _promoType;
  bool _promoListenerAttached = false;
  // true когато кешът е казвал Pro, но RevenueCat потвърди неактивен статус →
  // ползва се за еднократния „преходен" диалог към старите потребители.
  bool _wasDowngradedFromCache = false;
  String? _activeSubscription;
  DateTime? _trialEndDate;
  DateTime? _promoEndDate;
  String? _appliedPromoCode;
  // Следи следващото изтичане (trial/промо-дни) и уведомява UI в момента, в който
  // статусът падне на free, дори докато приложението е отворено.
  Timer? _expiryTimer;
  bool? _lastNotifiedPro;

  /// Текущият момент (с евентуален debug override; в release = DateTime.now()).
  DateTime _now() => DebugOverrides.now();

  /// Активен trial СПРЯМО текущата дата (смята се при четене, не при init).
  bool get _trialActive =>
      !DebugOverrides.forceTrialExpired &&
      _trialEndDate != null &&
      _now().isBefore(_trialEndDate!);

  /// Активно промо СПРЯМО текущата дата (lifetime = винаги активно).
  bool get _promoActive =>
      _promoType == 'lifetime' ||
      (_promoType == 'days' &&
          _promoEndDate != null &&
          _now().isBefore(_promoEndDate!));

  bool get isPro {
    // DEBUG-ONLY: симулирай free въпреки платец/промо (вкл. lifetime), за ръчен
    // тест на free-tier преживяването без изход от акаунта. В release връща false.
    if (!kIsWeb && DebugOverrides.forceFree) return false;
    return kIsWeb
        ? true
        : proActive(
            paidOrCached: _isPro,
            trialEnd: _trialEndDate,
            promoType: _promoType,
            promoEnd: _promoEndDate,
            now: _now(),
            forceTrialExpired: DebugOverrides.forceTrialExpired,
          );
  }
  bool get isPaid => _isPro;
  bool get isInitialized => _isInitialized;
  bool get isTrial => kIsWeb ? false : _trialActive;
  bool get isPromoCode => kIsWeb ? false : _promoActive;
  bool get wasDowngradedFromCache => _wasDowngradedFromCache;
  void clearDowngradeFlag() {
    _wasDowngradedFromCache = false;
  }
  String? get activeSubscription => _activeSubscription;
  DateTime? get trialEndDate => _trialEndDate;
  DateTime? get promoEndDate => _promoEndDate;
  int get trialDaysLeft => _trialEndDate != null
      ? _trialEndDate!.difference(_now()).inDays
      : 0;
  int get promoDaysLeft => _promoEndDate != null
      ? _promoEndDate!.difference(_now()).inDays
      : 0;

  /// 1.0.70: промо-код от тип „days" е ИЗТЕКЪЛ (беше активен, вече не е) и няма
  /// друг валиден Pro → home екранът показва еднократен „Промокодът ти изтече"
  /// (с отделен флаг `promo_expired_dialog_shown`, нулиран при нов промо код).
  bool get promoJustExpired =>
      !kIsWeb &&
      !isPro &&
      _promoType == 'days' &&
      _appliedPromoCode != null &&
      _promoEndDate != null &&
      !_now().isBefore(_promoEndDate!);

  /// Инициализира ProService
  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;

    // На web - винаги Pro, без инициализация на RevenueCat
    if (kIsWeb) {
      _isPro = true;
      _isInitialized = true;
      _isInitializing = false;
      notifyListeners();
      return;
    }

    // Кешираният is_pro служи САМО за оптимистично показване, докато RevenueCat
    // зареди. ИСТИНАТА идва от getCustomerInfo() → _updateProStatus, който БИЕ кеша.
    final cachedIsPro = await _readCachedIsPro();

    try {
      // RevenueCat API ключове — различни за Android и iOS
      const _rcAndroidKey = 'goog_OgZMwPkNQbGIxgAGLLDTUmaLTqT';
      const _rcIosKey = 'appl_heswwmmvxFfwDEtUhxkdArbHupS';
      final rcKey = (defaultTargetPlatform == TargetPlatform.iOS) ? _rcIosKey : _rcAndroidKey;
      await Purchases.configure(PurchasesConfiguration(rcKey));

      // Закачаме слушателя ВЕДНАГА (преди getCustomerInfo). Ако заявката гръмне
      // сега, слушателят пак ще коригира статуса щом RevenueCat се върне (интернет).
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _updateProStatus(customerInfo);
      });

      // RevenueCat отговорът БИЕ кеша. Retry с backoff при временен мрежов проблем —
      // НЕ падаме сляпо на кеша още при първи неуспех.
      final customerInfo = await _getCustomerInfoWithRetry();
      if (customerInfo != null) {
        _updateProStatus(customerInfo);
        // Detected downgrade: кешът казваше Pro, RC потвърди неактивен → маркирай
        // за еднократния преходен диалог (само ако няма друга валидна Pro причина).
        if (cachedIsPro && !_isPro && !_trialActive && !_promoActive) {
          _wasDowngradedFromCache = true;
          debugPrint('ProService: downgrade detected (cache=Pro, RC=inactive)');
        }
      } else {
        // След всички retries няма отговор → запази последния ИЗВЕСТЕН статус
        // (кеша) като временно състояние. НЕ удължаваме Pro безкрайно — слушателят
        // ще коригира при следващо успешно зареждане.
        await _loadFromCache();
        debugPrint('ProService: getCustomerInfo failed after retries → temporary cache');
      }

      // Проверка за trial период
      await _checkTrialStatus();

      // Проверка за промо код
      await _checkPromoCodeStatus();
      // Промо-Pro следва акаунта (възстановяване след реинсталация/нов телефон).
      await _restoreAccountPromo();
      _attachAccountPromoListener();

      _isInitialized = true;
      _isInitializing = false;
      _logProSource();
      _lastNotifiedPro = isPro;
      _armExpiryTimer();
      _updateAnalyticsProps();
      notifyListeners();
    } catch (e) {
      debugPrint('ProService init error: $e');
      // configure() гръмна → RevenueCat недостъпен. Кешът е временно последно
      // известно състояние (не сляпо доверие — слушателят ще коригира по-късно).
      await _loadFromCache();
      await _checkTrialStatus();
      await _checkPromoCodeStatus();
      await _restoreAccountPromo();
      _attachAccountPromoListener();
      _isInitialized = true;
      _isInitializing = false;
      _logProSource();
      _lastNotifiedPro = isPro;
      _armExpiryTimer();
      _updateAnalyticsProps();
      notifyListeners();
    }
  }

  /// (Пре)насрочва вътрешния таймер за следващото изтичане (trial или промо-дни),
  /// така че UI да падне на free точно когато изтече, без да чака рестарт/resume.
  void _armExpiryTimer() {
    _expiryTimer?.cancel();
    if (kIsWeb) return;
    // Платец или lifetime промо → няма изтичане за следене.
    if (_isPro || _promoType == 'lifetime') return;
    final now = _now();
    DateTime? next;
    if (_trialEndDate != null && _trialEndDate!.isAfter(now)) {
      next = _trialEndDate;
    }
    if (_promoType == 'days' &&
        _promoEndDate != null &&
        _promoEndDate!.isAfter(now) &&
        (next == null || _promoEndDate!.isBefore(next))) {
      next = _promoEndDate;
    }
    if (next == null) return;
    final d = next.difference(now) + const Duration(seconds: 1);
    _expiryTimer = Timer(d, () {
      _notifyProChange(); // изтекло → UI се превключва
      _armExpiryTimer(); // следващото изтичане (ако има промо след trial и т.н.)
    });
  }

  /// Уведомява слушателите САМО ако изведеният Pro статус наистина се е сменил
  /// (пести ненужни rebuild-и при resume).
  void _notifyProChange() {
    _updateAnalyticsProps();
    final p = isPro;
    if (_lastNotifiedPro != p) {
      _lastNotifiedPro = p;
      notifyListeners();
    }
  }

  /// Обновява user property `pro_state` + логва еднократно `trial_end`.
  void _updateAnalyticsProps() {
    if (kIsWeb) return;
    final state = _isPro
        ? 'paid'
        : _promoActive
            ? 'promo'
            : _trialActive
                ? 'trial'
                : 'free';
    AnalyticsService().setProState(state);
    _maybeLogTrialEnd();
  }

  /// Логва `trial_end` веднъж, щом trial-ът е изтекъл. `converted` = платец ли е.
  Future<void> _maybeLogTrialEnd() async {
    if (kIsWeb || _trialEndDate == null || _trialActive) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('trial_end_logged') ?? false) return;
      await prefs.setBool('trial_end_logged', true);
      AnalyticsService().logTrialEnd(converted: _isPro);
    } catch (_) {}
  }

  /// Извиква се при връщане на фокус към приложението (resume). Понеже trial/промо
  /// се смятат при четене, тук само пресмятаме наново спрямо текущата дата и
  /// (пре)насрочваме таймера; уведомяваме, ако статусът се е сменил.
  void onAppResumed() {
    if (kIsWeb) return;
    _armExpiryTimer();
    _notifyProChange();
  }

  /// Само за тестове: задава вътрешното състояние без native инициализация.
  @visibleForTesting
  void debugSetState({
    bool? paid,
    DateTime? trialEnd,
    String? promoType,
    DateTime? promoEnd,
  }) {
    if (paid != null) _isPro = paid;
    _trialEndDate = trialEnd;
    _promoType = promoType;
    _promoEndDate = promoEnd;
  }

  /// Взима CustomerInfo с до 3 опита (backoff 1s, 2s между опитите). Връща null
  /// само ако и трите опита се провалят.
  Future<CustomerInfo?> _getCustomerInfoWithRetry() async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        return await Purchases.getCustomerInfo();
      } catch (e) {
        debugPrint('ProService getCustomerInfo attempt $attempt failed: $e');
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt)); // 1s, 2s
        }
      }
    }
    return null;
  }

  /// Чете кеширания is_pro флаг (само за оптимистично показване при старт).
  Future<bool> _readCachedIsPro() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('is_pro') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Логва откъде идва Pro статусът (за дебъг на приходния бъг).
  void _logProSource() {
    final String src = _isPro
        ? 'entitlement'
        : _promoActive
            ? 'promo'
            : _trialActive
                ? 'trial'
                : 'none';
    debugPrint('ProService: isPro=$isPro source=$src '
        '(paid=$_isPro trial=$_trialActive promo=$_promoActive)');
  }

  /// Проверява и стартира trial период
  Future<void> _checkTrialStatus() async {
    if (kIsWeb) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final trialStartStr = prefs.getString('trial_start_date');

      if (trialStartStr == null) {
        // Началото на trial се закотвя към реалния календар (НЕ към debug now),
        // за да не променя трайно записа при симулация.
        final now = DateTime.now();
        await prefs.setString('trial_start_date', now.toIso8601String());
        _trialEndDate = now.add(const Duration(days: trialPeriodDays));
        AnalyticsService().logTrialStart();
        debugPrint('Trial started, ends: $_trialEndDate');
      } else {
        final trialStart = DateTime.parse(trialStartStr);
        _trialEndDate = trialStart.add(const Duration(days: trialPeriodDays));
        // Активността се смята при ЧЕТЕНЕ (getter `_trialActive`) спрямо датата —
        // тук само изчисляваме крайната дата.
        debugPrint('Trial end: $_trialEndDate (active=$_trialActive)');
      }
    } catch (e) {
      debugPrint('Trial check error: $e');
    }
  }

  /// Проверява статуса на промо код
  Future<void> _checkPromoCodeStatus() async {
    if (kIsWeb) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final promoEndStr = prefs.getString('promo_end_date');
      final promoType = prefs.getString('promo_type');
      _appliedPromoCode = prefs.getString('applied_promo_code');

      if (promoType == 'lifetime') {
        _promoType = 'lifetime';
        _promoEndDate = null;
        debugPrint('Lifetime promo active');
      } else if (promoEndStr != null) {
        _promoType = 'days';
        _promoEndDate = DateTime.parse(promoEndStr);
        // Активността се смята при ЧЕТЕНЕ (getter `_promoActive`) спрямо датата.
        debugPrint('Days promo end: $_promoEndDate (active=$_promoActive)');
      } else {
        _promoType = null;
        _promoEndDate = null;
      }
    } catch (e) {
      debugPrint('Promo check error: $e');
      _promoType = null;
    }
  }

  /// Възстановява промо-Pro, който следва АКАУНТА (не устройството). При
  /// реинсталация SharedPreferences се изтрива, но Firestore го пази: `usedBy[]`
  /// (кой е изкупил) + `redemptions.{uid}` (крайна дата за days-type). Питаме облака
  /// и връщаме промото автоматично — без пак да въвежда код.
  /// Offline-safe: всяка грешка се поглъща (оставаме на локалното състояние).
  /// Lifetime има приоритет; иначе взимаме days-промото с НАЙ-ДАЛЕЧНА валидна дата.
  Future<void> _restoreAccountPromo() async {
    if (kIsWeb) return;
    if (_promoActive) return; // вече активен локално → няма нужда

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // 1.0.70: ПЪРВО огледалния документ (четим само от собственика) — не чете
      // цялата колекция `promo_codes`. Старата list-заявка е fallback отдолу.
      try {
        final mine = await _accountPromoRef(userId).get();
        if (mine.exists) {
          final d = mine.data()!;
          final type = d['type'];
          final code = d['code'];
          if (type == 'lifetime' && code is String) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('applied_promo_code', code);
            await prefs.setString('promo_type', 'lifetime');
            await prefs.remove('promo_end_date');
            _promoType = 'lifetime';
            _promoEndDate = null;
            _appliedPromoCode = code;
            _armExpiryTimer();
            _notifyProChange();
            debugPrint('Account lifetime promo restored (mirror): $code');
            return;
          } else if (type == 'days' &&
              code is String &&
              d['expiresAt'] is Timestamp) {
            final end = (d['expiresAt'] as Timestamp).toDate();
            if (end.isAfter(DateTime.now())) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('applied_promo_code', code);
              await prefs.setString('promo_type', 'days');
              await prefs.setString('promo_end_date', end.toIso8601String());
              _promoType = 'days';
              _promoEndDate = end;
              _appliedPromoCode = code;
              _armExpiryTimer();
              _notifyProChange();
              debugPrint('Account days promo restored (mirror): $code until $end');
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('Account promo mirror read failed (fallback to query): $e');
      }

      final snap = await FirebaseFirestore.instance
          .collection('promo_codes')
          .where('usedBy', arrayContains: userId)
          .get();

      DateTime? bestDaysEnd;
      String? bestDaysCode;

      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['isActive'] != true) continue;
        final type = data['type'];

        if (type == 'lifetime') {
          // Lifetime = най-доброто → връщаме веднага.
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('applied_promo_code', doc.id);
          await prefs.setString('promo_type', 'lifetime');
          await prefs.remove('promo_end_date');
          _promoType = 'lifetime';
          _promoEndDate = null;
          _appliedPromoCode = doc.id;
          _armExpiryTimer();
          _notifyProChange();
          debugPrint('Account lifetime promo restored: ${doc.id}');
          return;
        } else if (type == 'days') {
          // Крайната дата за този потребител е пазена per-user при изкупуване.
          final reds = data['redemptions'];
          if (reds is Map && reds[userId] is Timestamp) {
            final end = (reds[userId] as Timestamp).toDate();
            if (end.isAfter(DateTime.now()) &&
                (bestDaysEnd == null || end.isAfter(bestDaysEnd))) {
              bestDaysEnd = end;
              bestDaysCode = doc.id;
            }
          }
        }
      }

      if (bestDaysEnd != null && bestDaysCode != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('applied_promo_code', bestDaysCode);
        await prefs.setString('promo_type', 'days');
        await prefs.setString('promo_end_date', bestDaysEnd.toIso8601String());
        _promoType = 'days';
        _promoEndDate = bestDaysEnd;
        _appliedPromoCode = bestDaysCode;
        _armExpiryTimer();
        _notifyProChange();
        debugPrint('Account days promo restored: $bestDaysCode until $bestDaysEnd');
      }
    } catch (e) {
      debugPrint('Restore account promo error: $e');
    }
  }

  /// Закача еднократен слушател: при бъдещ вход (друго устройство/реинсталация)
  /// възстановява промо-Pro, който следва акаунта. Извиква се при init.
  void _attachAccountPromoListener() {
    if (_promoListenerAttached) return;
    _promoListenerAttached = true;
    try {
      FirebaseAuth.instance.authStateChanges().listen((user) {
        // Анонимните сесии (affiliate-attribution лог) нямат промо да следват.
        if (user != null && !user.isAnonymous) _restoreAccountPromo();
      });
    } catch (e) {
      debugPrint('Account promo listener error: $e');
    }
  }

  /// 1.0.70: промо-дните се ТРУПАТ върху вече наличен Pro, вместо да започват
  /// от „сега". База за новия край = най-късното от: сега, края на активния
  /// trial и текущия край на промо-дни. Така промо по време на trial дава
  /// trial + дните, а втори код удължава след първия.
  DateTime _promoStackBase() {
    DateTime base = DateTime.now();
    if (_trialEndDate != null && _trialEndDate!.isAfter(base)) {
      base = _trialEndDate!;
    }
    if (_promoType == 'days' &&
        _promoEndDate != null &&
        _promoEndDate!.isAfter(base)) {
      base = _promoEndDate!;
    }
    return base;
  }

  /// 1.0.70: нулира флага за екрана „Промокодът ти изтече", за да се покаже
  /// ПАК при следващо изтичане (при нов/подновен промо код).
  Future<void> _resetPromoExpiredFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('promo_expired_dialog_shown');
    } catch (_) {}
  }

  /// Прилага промо код (cloud_firestore временно изключен за iOS). [source] се
  /// подава в analytics (`promo_redeemed`) — откъде е приложен кодът.
  Future<({bool success, String message})> applyPromoCode(String code,
      {String source = 'paywall'}) async {
    if (kIsWeb) {
      return (success: false, message: _pm('notAvailableWeb', 'en'));
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('app_language') ?? 'en';
      final codeUpper = code.toUpperCase().trim();

      final docRef = FirebaseFirestore.instance.collection('promo_codes').doc(codeUpper);
      final doc = await docRef.get();

      if (!doc.exists) {
        return (success: false, message: _pm('invalidCode', lang));
      }

      final data = doc.data()!;

      if (data['isActive'] != true) {
        return (success: false, message: _pm('codeInactive', lang));
      }

      if (data['expiresAt'] != null) {
        final expiresAt = (data['expiresAt'] as Timestamp).toDate();
        if (DateTime.now().isAfter(expiresAt)) {
          return (success: false, message: _pm('codeExpired', lang));
        }
      }

      final maxUses = data['maxUses'] as int? ?? 0;
      final usedCount = data['usedCount'] as int? ?? 0;
      if (maxUses > 0 && usedCount >= maxUses) {
        return (success: false, message: _pm('codeUsedUp', lang));
      }

      final userId = FirebaseAuth.instance.currentUser?.uid;
      final usedBy = List<String>.from(data['usedBy'] ?? []);
      final type = data['type'] as String;

      if (userId != null && usedBy.contains(userId)) {
        if (type == 'lifetime') {
          await prefs.setString('applied_promo_code', codeUpper);
          await prefs.setString('promo_type', 'lifetime');
          await prefs.remove('promo_end_date');
          _promoType = 'lifetime';
          _promoEndDate = null;
          _appliedPromoCode = codeUpper;
          await _writeAccountPromoMirror(code: codeUpper, type: 'lifetime');
          _armExpiryTimer();
          _notifyProChange();
          await _resetPromoExpiredFlag();
          return (success: true, message: _pm('proReactivated', lang));
        }
        // days-type: ако още е валиден (по записаната крайна дата) → възстанови го,
        // вместо да връщаме „вече използван" (Pro следва акаунта).
        final reds = data['redemptions'];
        if (reds is Map && reds[userId] is Timestamp) {
          final end = (reds[userId] as Timestamp).toDate();
          if (end.isAfter(DateTime.now())) {
            await prefs.setString('applied_promo_code', codeUpper);
            await prefs.setString('promo_type', 'days');
            await prefs.setString('promo_end_date', end.toIso8601String());
            _promoType = 'days';
            _promoEndDate = end;
            _appliedPromoCode = codeUpper;
            await _writeAccountPromoMirror(
                code: codeUpper, type: 'days', end: end);
            _armExpiryTimer();
            _notifyProChange();
            await _resetPromoExpiredFlag();
            return (success: true, message: _pm('proReactivated', lang));
          }
        }
        return (success: false, message: _pm('alreadyUsed', lang));
      }

      final days = data['days'] as int? ?? 0;
      DateTime? daysEndDate;

      await prefs.setString('applied_promo_code', codeUpper);
      await prefs.setString('promo_type', type);

      if (type == 'lifetime') {
        _promoType = 'lifetime';
        _promoEndDate = null;
        await prefs.remove('promo_end_date');
      } else if (type == 'days' && days > 0) {
        // 1.0.70: ТРУПАНЕ — дните се добавят върху вече наличен Pro (trial/друго
        // промо), а не от „сега". Базата е най-късната валидна дата.
        daysEndDate = _promoStackBase().add(Duration(days: days));
        _promoType = 'days';
        _promoEndDate = daysEndDate;
        await prefs.setString('promo_end_date', daysEndDate.toIso8601String());
      }

      _appliedPromoCode = codeUpper;

      await docRef.update({
        'usedCount': FieldValue.increment(1),
        if (userId != null) 'usedBy': FieldValue.arrayUnion([userId]),
        // Пазим КРАЙНАТА дата per-user → days-type се възстановява на нов телефон.
        if (userId != null && daysEndDate != null)
          'redemptions.$userId': Timestamp.fromDate(daysEndDate),
      });

      // Огледало към акаунта (възстановяване без list на promo_codes).
      await _writeAccountPromoMirror(
          code: codeUpper, type: type, end: daysEndDate);

      _armExpiryTimer();
      _notifyProChange();

      // 1.0.70: нов промо код → екранът „Промокодът ти изтече" да се покаже пак
      // при следващо изтичане; + analytics за изкупуването.
      await _resetPromoExpiredFlag();
      AnalyticsService().logPromoRedeemed(
          type: type, days: type == 'days' ? days : 0, source: source);

      if (type == 'lifetime') {
        return (success: true, message: _pm('proLifetime', lang));
      } else {
        return (success: true, message: _proForDays(days, lang));
      }
    } catch (e) {
      debugPrint('Apply promo code error: $e');
      String lang = 'en';
      try {
        final prefs = await SharedPreferences.getInstance();
        lang = prefs.getString('app_language') ?? 'en';
      } catch (_) {}
      // Човешко съобщение — НЕ показваме суровия exception на потребителя.
      return (success: false, message: _pm('genericError', lang));
    }
  }

  /// Документ-огледало, четим САМО от собственика (`users/{uid}/promo/current`,
  /// покрит от правилото `users/{userId}/{subcollection=**}`). Пази промо-Pro към
  /// АКАУНТА без да четем цялата колекция `promo_codes` (1.0.70 restore redesign).
  DocumentReference<Map<String, dynamic>> _accountPromoRef(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('promo')
          .doc('current');

  /// Записва огледалния документ при успешен промо код. [end] = null за lifetime.
  Future<void> _writeAccountPromoMirror({
    required String code,
    required String type,
    DateTime? end,
  }) async {
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null || u.isAnonymous) return; // само реални акаунти
      await _accountPromoRef(u.uid).set({
        'code': code,
        'type': type,
        'activatedAt': FieldValue.serverTimestamp(),
        if (end != null) 'expiresAt': Timestamp.fromDate(end),
      });
    } catch (e) {
      debugPrint('Write account promo mirror failed: $e');
    }
  }

  /// Еднократен „жест" към ранните потребители при преход към free: дава им
  /// gratis Pro за няколко дни през СЪЩАТА тествана promo-days машинария —
  /// изтича чисто чрез `_checkPromoCodeStatus` (не е безкраен Pro).
  Future<void> grantEarlySupporterGrace(int days) async {
    if (kIsWeb || days <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final end = DateTime.now().add(Duration(days: days));
      await prefs.setString('applied_promo_code', 'EARLY_SUPPORTER');
      await prefs.setString('promo_type', 'days');
      await prefs.setString('promo_end_date', end.toIso8601String());
      _promoType = 'days';
      _promoEndDate = end;
      _appliedPromoCode = 'EARLY_SUPPORTER';
      _wasDowngradedFromCache = false;
      _armExpiryTimer();
      _notifyProChange();
      await _resetPromoExpiredFlag();
      debugPrint('ProService: early-supporter grace granted for $days days');
    } catch (e) {
      debugPrint('ProService grace grant error: $e');
    }
  }

  void _updateProStatus(CustomerInfo customerInfo) {
    if (kIsWeb) return;
    
    final entitlement = customerInfo.entitlements.all[entitlementId];
    final wasPro = _isPro;

    _isPro = entitlement?.isActive ?? false;

    if (entitlement?.isActive == true) {
      _activeSubscription = entitlement?.productIdentifier;
    } else {
      _activeSubscription = null;
    }

    // Слушателят се върна с неактивен статус, след като кешът е дал Pro при старт
    // (мрежов проблем при init) → маркирай за преходния диалог.
    if (wasPro && !_isPro && !_trialActive && !_promoActive) {
      _wasDowngradedFromCache = true;
      debugPrint('ProService: downgrade detected via listener (was Pro, now inactive)');
    }

    _saveToCache();

    if (wasPro != _isPro) {
      _armExpiryTimer();
      _notifyProChange();
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPro = prefs.getBool('is_pro') ?? false;
      _activeSubscription = prefs.getString('active_subscription');
    } catch (e) {
      debugPrint('ProService cache load error: $e');
    }
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_pro', _isPro);
      if (_activeSubscription != null) {
        await prefs.setString('active_subscription', _activeSubscription!);
      } else {
        await prefs.remove('active_subscription');
      }
    } catch (e) {
      debugPrint('ProService cache save error: $e');
    }
  }

  /// Взема продукти чрез Offerings API (правилният начин!)
  Future<List<Package>> getOfferings() async {
    if (kIsWeb) return [];
    
    try {
      final offerings = await Purchases.getOfferings();
      final currentOffering = offerings.current;
      
      if (currentOffering == null) {
        debugPrint('No current offering found');
        return [];
      }
      
      debugPrint('Found offering: ${currentOffering.identifier}');
      debugPrint('Packages: ${currentOffering.availablePackages.length}');
      
      // Сортираме: Lifetime, Yearly, Monthly (редът, в който ги показва paywall-ът).
      final packages = List<Package>.from(currentOffering.availablePackages);
      packages.sort((a, b) {
        final order = {'lifetime': 0, 'annual': 1, 'yearly': 1, 'monthly': 2};
        final aOrder = order.entries
            .firstWhere((e) => a.identifier.toLowerCase().contains(e.key), 
                        orElse: () => const MapEntry('', 3))
            .value;
        final bOrder = order.entries
            .firstWhere((e) => b.identifier.toLowerCase().contains(e.key), 
                        orElse: () => const MapEntry('', 3))
            .value;
        return aOrder.compareTo(bOrder);
      });
      
      return packages;
    } catch (e) {
      debugPrint('ProService getOfferings error: $e');
      return [];
    }
  }

  /// Deprecated - използвай getOfferings() вместо това
  Future<List<dynamic>> getProducts() async {
    if (kIsWeb) return [];
    
    try {
      final packages = await getOfferings();
      return packages.map((p) => p.storeProduct).toList();
    } catch (e) {
      debugPrint('ProService getProducts error: $e');
      return [];
    }
  }

  /// Покупка чрез Package (от Offerings)
  Future<bool> purchasePackage(Package package) async {
    if (kIsWeb) return false;
    
    try {
      // purchases_flutter 9+ (Billing Library 8): покупките връщат PurchaseResult
      // (CustomerInfo + StoreTransaction), не голо CustomerInfo.
      final result = await Purchases.purchasePackage(package);
      _updateProStatus(result.customerInfo);
      return _isPro;
    } catch (e) {
      debugPrint('ProService purchasePackage error: $e');
      return false;
    }
  }

  Future<bool> purchase(dynamic product) async {
    if (kIsWeb) return false;
    
    try {
      // purchases_flutter 9+ връща PurchaseResult вместо CustomerInfo.
      final result = await Purchases.purchaseStoreProduct(product);
      _updateProStatus(result.customerInfo);
      return _isPro;
    } catch (e) {
      debugPrint('ProService purchase error: $e');
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    if (kIsWeb) return false;
    
    try {
      final customerInfo = await Purchases.restorePurchases();
      _updateProStatus(customerInfo);
      return _isPro;
    } catch (e) {
      debugPrint('ProService restore error: $e');
      return false;
    }
  }

  String getStatusText(String lang) {
    if (kIsWeb) {
      return _pm('webVersion', lang);
    }
    if (_isPro) {
      return _pm('proPaid', lang);
    } else if (_promoActive && _promoType == 'lifetime') {
      return _pm('proPromoLifetime', lang);
    } else if (_promoActive) {
      return _proPromoDays(promoDaysLeft, lang);
    } else if (_trialActive) {
      return _proTrialDays(trialDaysLeft, lang);
    } else {
      return _pm('free', lang);
    }
  }

  bool canAddTask(int currentTaskCount) {
    if (isPro) return true;
    return currentTaskCount < FreeLimits.maxTasks;
  }

  bool canAddCategory(int currentCategoryCount) {
    if (isPro) return true;
    return currentCategoryCount < FreeLimits.maxCategories;
  }

  bool canAddReminder(int currentReminderCount) {
    if (isPro) return true;
    return currentReminderCount < FreeLimits.maxRemindersPerTask;
  }

  bool get canUseRecurrence => isPro || FreeLimits.canUseRecurrence;
  bool get canUseCalendar => isPro || FreeLimits.canUseCalendar;
  bool get canUseStatistics => isPro || FreeLimits.canUseStatistics;
  bool get canUseCloudSync => isPro || FreeLimits.canUseCloudSync;
  bool get canUseWidget => isPro || FreeLimits.canUseWidget;
  bool get canUseVoiceInput => isPro || FreeLimits.canUseVoiceInput;
  bool get canUseExportImport => isPro || FreeLimits.canUseExportImport;
  bool get canChangeTheme => isPro || FreeLimits.canChangeTheme;
  bool get canChangeLanguage => isPro || FreeLimits.canChangeLanguage;
  bool get shouldShowAds => !isPro && FreeLimits.showAds && !kIsWeb;
}
