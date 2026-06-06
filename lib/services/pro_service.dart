import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Условен import - stub за web, реален пакет за mobile
import 'purchases_stub.dart' if (dart.library.io) 'package:purchases_flutter/purchases_flutter.dart';

// Localized promo/status messages
const _proMsg = {
  'notAvailableWeb': {'en': 'Not available on web', 'bg': 'Не е налично на web', 'de': 'Nicht im Web verfügbar', 'fr': 'Non disponible sur le web', 'it': 'Non disponibile sul web', 'el': 'Δεν είναι διαθέσιμο στο web', 'es': 'No disponible en la web', 'pt': 'Não disponível na web', 'ru': 'Недоступно в вебе', 'tr': 'Web\'de kullanılamaz', 'ja': 'ウェブでは利用できません'},
  'invalidCode': {'en': 'Invalid code', 'bg': 'Невалиден код', 'de': 'Ungültiger Code', 'fr': 'Code invalide', 'it': 'Codice non valido', 'el': 'Μη έγκυρος κωδικός', 'es': 'Código inválido', 'pt': 'Código inválido', 'ru': 'Неверный код', 'tr': 'Geçersiz kod', 'ja': '無効なコード'},
  'codeInactive': {'en': 'Code is not active', 'bg': 'Кодът не е активен', 'de': 'Code ist nicht aktiv', 'fr': 'Code non actif', 'it': 'Codice non attivo', 'el': 'Ο κωδικός δεν είναι ενεργός', 'es': 'El código no está activo', 'pt': 'Código não está ativo', 'ru': 'Код не активен', 'tr': 'Kod aktif değil', 'ja': 'コードは無効です'},
  'codeExpired': {'en': 'Code has expired', 'bg': 'Кодът е изтекъл', 'de': 'Code ist abgelaufen', 'fr': 'Code expiré', 'it': 'Codice scaduto', 'el': 'Ο κωδικός έχει λήξει', 'es': 'El código ha expirado', 'pt': 'Código expirado', 'ru': 'Код истёк', 'tr': 'Kodun süresi dolmuş', 'ja': 'コードの有効期限が切れています'},
  'codeUsedUp': {'en': 'Code is used up', 'bg': 'Кодът е изчерпан', 'de': 'Code aufgebraucht', 'fr': 'Code épuisé', 'it': 'Codice esaurito', 'el': 'Ο κωδικός εξαντλήθηκε', 'es': 'Código agotado', 'pt': 'Código esgotado', 'ru': 'Код исчерпан', 'tr': 'Kod tükendi', 'ja': 'コードは使い切られています'},
  'alreadyUsed': {'en': 'You already used this code', 'bg': 'Вече си използвал този код', 'de': 'Du hast diesen Code bereits verwendet', 'fr': 'Vous avez déjà utilisé ce code', 'it': 'Hai già usato questo codice', 'el': 'Έχετε ήδη χρησιμοποιήσει αυτόν τον κωδικό', 'es': 'Ya usaste este código', 'pt': 'Você já usou este código', 'ru': 'Вы уже использовали этот код', 'tr': 'Bu kodu zaten kullandınız', 'ja': 'このコードはすでに使用済みです'},
  'proReactivated': {'en': 'Pro reactivated!', 'bg': 'Pro активиран отново!', 'de': 'Pro reaktiviert!', 'fr': 'Pro réactivé!', 'it': 'Pro riattivato!', 'el': 'Pro επανενεργοποιήθηκε!', 'es': '¡Pro reactivado!', 'pt': 'Pro reativado!', 'ru': 'Pro активирован повторно!', 'tr': 'Pro yeniden etkinleştirildi!', 'ja': 'Proを再有効化しました！'},
  'proLifetime': {'en': 'Congratulations! You have Pro forever!', 'bg': 'Поздравления! Имаш Pro завинаги!', 'de': 'Glückwunsch! Du hast Pro für immer!', 'fr': 'Félicitations! Vous avez Pro à vie!', 'it': 'Congratulazioni! Hai Pro per sempre!', 'el': 'Συγχαρητήρια! Έχετε Pro για πάντα!', 'es': '¡Felicidades! ¡Tienes Pro para siempre!', 'pt': 'Parabéns! Você tem Pro para sempre!', 'ru': 'Поздравляем! У вас Pro навсегда!', 'tr': 'Tebrikler! Sonsuza kadar Pro\'sunuz!', 'ja': 'おめでとうございます！Proを永久にご利用いただけます！'},
  'error': {'en': 'Error', 'bg': 'Грешка', 'de': 'Fehler', 'fr': 'Erreur', 'it': 'Errore', 'el': 'Σφάλμα', 'es': 'Error', 'pt': 'Erro', 'ru': 'Ошибка', 'tr': 'Hata', 'ja': 'エラー'},
  'webVersion': {'en': 'Web version', 'bg': 'Web версия', 'de': 'Web-Version', 'fr': 'Version web', 'it': 'Versione web', 'el': 'Έκδοση web', 'es': 'Versión web', 'pt': 'Versão web', 'ru': 'Веб-версия', 'tr': 'Web sürümü', 'ja': 'ウェブ版'},
  'proPaid': {'en': 'Pro (paid)', 'bg': 'Pro (платен)', 'de': 'Pro (bezahlt)', 'fr': 'Pro (payé)', 'it': 'Pro (pagato)', 'el': 'Pro (πληρωμένο)', 'es': 'Pro (pagado)', 'pt': 'Pro (pago)', 'ru': 'Pro (оплачено)', 'tr': 'Pro (ücretli)', 'ja': 'Pro（有料）'},
  'proPromoLifetime': {'en': 'Pro (promo - lifetime)', 'bg': 'Pro (промо код - завинаги)', 'de': 'Pro (Promo - lebenslang)', 'fr': 'Pro (promo - à vie)', 'it': 'Pro (promo - a vita)', 'el': 'Pro (προσφορά - εφ\' όρου ζωής)', 'es': 'Pro (promo - de por vida)', 'pt': 'Pro (promo - vitalício)', 'ru': 'Pro (промо - навсегда)', 'tr': 'Pro (promosyon - ömür boyu)', 'ja': 'Pro（プロモ - 買い切り）'},
  'free': {'en': 'Free', 'bg': 'Безплатен', 'de': 'Kostenlos', 'fr': 'Gratuit', 'it': 'Gratuito', 'el': 'Δωρεάν', 'es': 'Gratis', 'pt': 'Grátis', 'ru': 'Бесплатно', 'tr': 'Ücretsiz', 'ja': '無料'},
};

String _pm(String key, String lang) => _proMsg[key]?[lang] ?? _proMsg[key]?['en'] ?? '';

String _proForDays(int days, String lang) {
  const m = {'en': 'Congratulations! You have Pro for DAYS days!', 'bg': 'Поздравления! Имаш Pro за DAYS дни!', 'de': 'Glückwunsch! Du hast Pro für DAYS Tage!', 'fr': 'Félicitations! Vous avez Pro pour DAYS jours!', 'it': 'Congratulazioni! Hai Pro per DAYS giorni!', 'el': 'Συγχαρητήρια! Έχετε Pro για DAYS ημέρες!', 'es': '¡Felicidades! ¡Tienes Pro por DAYS días!', 'pt': 'Parabéns! Você tem Pro por DAYS dias!', 'ru': 'Поздравляем! У вас Pro на DAYS дней!', 'tr': 'Tebrikler! DAYS gün Pro\'sunuz!', 'ja': 'おめでとうございます！Proを残りDAYS日間ご利用いただけます！'};
  return (m[lang] ?? m['en']!).replaceAll('DAYS', '$days');
}

String _proPromoDays(int days, String lang) {
  const m = {'en': 'Pro (promo - DAYS days)', 'bg': 'Pro (промо код - DAYS дни)', 'de': 'Pro (Promo - DAYS Tage)', 'fr': 'Pro (promo - DAYS jours)', 'it': 'Pro (promo - DAYS giorni)', 'el': 'Pro (προσφορά - DAYS ημέρες)', 'es': 'Pro (promo - DAYS días)', 'pt': 'Pro (promo - DAYS dias)', 'ru': 'Pro (промо - DAYS дней)', 'tr': 'Pro (promosyon - DAYS gün)', 'ja': 'Pro（プロモ - DAYS日）'};
  return (m[lang] ?? m['en']!).replaceAll('DAYS', '$days');
}

String _proTrialDays(int days, String lang) {
  const m = {'en': 'Pro (trial - DAYS days)', 'bg': 'Pro (пробен период - DAYS дни)', 'de': 'Pro (Test - DAYS Tage)', 'fr': 'Pro (essai - DAYS jours)', 'it': 'Pro (prova - DAYS giorni)', 'el': 'Pro (δοκιμή - DAYS ημέρες)', 'es': 'Pro (prueba - DAYS días)', 'pt': 'Pro (teste - DAYS dias)', 'ru': 'Pro (пробный - DAYS дней)', 'tr': 'Pro (deneme - DAYS gün)', 'ja': 'Pro（トライアル - DAYS日）'};
  return (m[lang] ?? m['en']!).replaceAll('DAYS', '$days');
}

/// Лимити за безплатната версия
class FreeLimits {
  static const int maxTasks = 50;
  static const int maxCategories = 10;
  static const int maxRemindersPerTask = 3;
  static const bool canUseRecurrence = true;
  static const bool canUseCalendar = false;
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

class ProService extends ChangeNotifier {
  ProService._internal();

  static final ProService _instance = ProService._internal();
  factory ProService() => _instance;

  bool _isPro = false;
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isTrial = false;
  bool _isPromoCode = false;
  String? _activeSubscription;
  DateTime? _trialEndDate;
  DateTime? _promoEndDate;
  String? _appliedPromoCode;

  bool get isPro => kIsWeb ? true : (_isPro || _isTrial || _isPromoCode);
  bool get isPaid => _isPro;
  bool get isInitialized => _isInitialized;
  bool get isTrial => kIsWeb ? false : _isTrial;
  bool get isPromoCode => kIsWeb ? false : _isPromoCode;
  String? get activeSubscription => _activeSubscription;
  DateTime? get trialEndDate => _trialEndDate;
  DateTime? get promoEndDate => _promoEndDate;
  int get trialDaysLeft => _trialEndDate != null
      ? _trialEndDate!.difference(DateTime.now()).inDays
      : 0;
  int get promoDaysLeft => _promoEndDate != null
      ? _promoEndDate!.difference(DateTime.now()).inDays
      : 0;

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

    try {
      // RevenueCat API ключове — различни за Android и iOS
      const _rcAndroidKey = 'goog_OgZMwPkNQbGIxgAGLLDTUmaLTqT';
      const _rcIosKey = 'appl_heswwmmvxFfwDEtUhxkdArbHupS';
      final rcKey = (defaultTargetPlatform == TargetPlatform.iOS) ? _rcIosKey : _rcAndroidKey;
      await Purchases.configure(PurchasesConfiguration(rcKey));

      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _updateProStatus(customerInfo);
      });

      final customerInfo = await Purchases.getCustomerInfo();
      _updateProStatus(customerInfo);

      // Проверка за trial период
      await _checkTrialStatus();

      // Проверка за промо код
      await _checkPromoCodeStatus();

      _isInitialized = true;
      _isInitializing = false;
      notifyListeners();
    } catch (e) {
      debugPrint('ProService init error: $e');
      await _loadFromCache();
      await _checkTrialStatus();
      await _checkPromoCodeStatus();
      _isInitialized = true;
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// Проверява и стартира trial период
  Future<void> _checkTrialStatus() async {
    if (kIsWeb) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final trialStartStr = prefs.getString('trial_start_date');

      if (trialStartStr == null) {
        final now = DateTime.now();
        await prefs.setString('trial_start_date', now.toIso8601String());
        _trialEndDate = now.add(const Duration(days: trialPeriodDays));
        _isTrial = true;
        debugPrint('Trial started, ends: $_trialEndDate');
      } else {
        final trialStart = DateTime.parse(trialStartStr);
        _trialEndDate = trialStart.add(const Duration(days: trialPeriodDays));

        if (DateTime.now().isBefore(_trialEndDate!)) {
          _isTrial = true;
          debugPrint('Trial active, days left: $trialDaysLeft');
        } else {
          _isTrial = false;
          debugPrint('Trial expired');
        }
      }
    } catch (e) {
      debugPrint('Trial check error: $e');
      _isTrial = false;
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
        _isPromoCode = true;
        _promoEndDate = null;
        debugPrint('Lifetime promo active');
      } else if (promoEndStr != null) {
        _promoEndDate = DateTime.parse(promoEndStr);

        if (DateTime.now().isBefore(_promoEndDate!)) {
          _isPromoCode = true;
          debugPrint('Promo active, days left: $promoDaysLeft');
        } else {
          _isPromoCode = false;
          debugPrint('Promo expired');
        }
      }
    } catch (e) {
      debugPrint('Promo check error: $e');
      _isPromoCode = false;
    }
  }

  /// Прилага промо код (cloud_firestore временно изключен за iOS)
  Future<({bool success, String message})> applyPromoCode(String code) async {
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
          _isPromoCode = true;
          _promoEndDate = null;
          _appliedPromoCode = codeUpper;
          notifyListeners();
          return (success: true, message: _pm('proReactivated', lang));
        }
        return (success: false, message: _pm('alreadyUsed', lang));
      }

      final days = data['days'] as int? ?? 0;

      await prefs.setString('applied_promo_code', codeUpper);
      await prefs.setString('promo_type', type);

      if (type == 'lifetime') {
        _isPromoCode = true;
        _promoEndDate = null;
        await prefs.remove('promo_end_date');
      } else if (type == 'days' && days > 0) {
        final endDate = DateTime.now().add(Duration(days: days));
        _promoEndDate = endDate;
        _isPromoCode = true;
        await prefs.setString('promo_end_date', endDate.toIso8601String());
      }

      _appliedPromoCode = codeUpper;

      await docRef.update({
        'usedCount': FieldValue.increment(1),
        if (userId != null) 'usedBy': FieldValue.arrayUnion([userId]),
      });

      notifyListeners();

      if (type == 'lifetime') {
        return (success: true, message: _pm('proLifetime', lang));
      } else {
        return (success: true, message: _proForDays(days, lang));
      }
    } catch (e) {
      debugPrint('Apply promo code error: $e');
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('app_language') ?? 'en';
      return (success: false, message: '${_pm('error', lang)}: $e');
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

    _saveToCache();

    if (wasPro != _isPro) {
      notifyListeners();
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
      
      // Сортираме: Monthly, Yearly, Lifetime
      final packages = List<Package>.from(currentOffering.availablePackages);
      packages.sort((a, b) {
        final order = {'monthly': 0, 'annual': 1, 'yearly': 1, 'lifetime': 2};
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
      final customerInfo = await Purchases.purchasePackage(package);
      _updateProStatus(customerInfo);
      return _isPro;
    } catch (e) {
      debugPrint('ProService purchasePackage error: $e');
      return false;
    }
  }

  Future<bool> purchase(dynamic product) async {
    if (kIsWeb) return false;
    
    try {
      final customerInfo = await Purchases.purchaseStoreProduct(product);
      _updateProStatus(customerInfo);
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
    } else if (_isPromoCode && _promoEndDate == null) {
      return _pm('proPromoLifetime', lang);
    } else if (_isPromoCode && _promoEndDate != null) {
      return _proPromoDays(promoDaysLeft, lang);
    } else if (_isTrial) {
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
