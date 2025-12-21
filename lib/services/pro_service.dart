import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Лимити за безплатната версия
class FreeLimits {
  static const int maxTasks = 30;
  static const int maxCategories = 3;
  static const int maxRemindersPerTask = 1;
  static const bool canUseRecurrence = false;
  static const bool canUseCalendar = false;
  static const bool canUseStatistics = false;
  static const bool canUseCloudSync = false;
  static const bool canUseWidget = false;
  static const bool canUseVoiceInput = false;
  static const bool canUseExportImport = false;
  static const bool canChangeTheme = false;
  static const bool canChangeLanguage = false;
  static const bool showAds = true;
}

/// Trial период в дни
const int trialPeriodDays = 14;

/// Entitlement идентификатор в RevenueCat
const String entitlementId = 'pro';

/// Продуктови идентификатори
const String productIdLifetime = 'taskify_pro_lifetime';
const String productIdMonthly = 'taskify_pro_monthly';
const String productIdYearly = 'taskify_pro_yearly';

class ProService extends ChangeNotifier {
  ProService._internal();

  static final ProService _instance = ProService._internal();
  factory ProService() => _instance;

  bool _isPro = false;
  bool _isInitialized = false;
  bool _isTrial = false;
  bool _isPromoCode = false;
  String? _activeSubscription;
  DateTime? _trialEndDate;
  DateTime? _promoEndDate;
  String? _appliedPromoCode;

  bool get isPro => _isPro || _isTrial || _isPromoCode;
  bool get isPaid => _isPro;  // Платен Pro (не trial/promo)
  bool get isInitialized => _isInitialized;
  bool get isTrial => _isTrial;
  bool get isPromoCode => _isPromoCode;
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
    if (_isInitialized) return;

    try {
      // Конфигурация на RevenueCat
      await Purchases.configure(
        PurchasesConfiguration('test_BtyVZjVRjvrMDICrXNTixKfaGae'),
      );

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
      notifyListeners();
    } catch (e) {
      debugPrint('ProService init error: $e');
      await _loadFromCache();
      await _checkTrialStatus();
      await _checkPromoCodeStatus();
      _isInitialized = true;
    }
  }

  /// Проверява и стартира trial период
  Future<void> _checkTrialStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trialStartStr = prefs.getString('trial_start_date');
      
      if (trialStartStr == null) {
        // Първо инсталиране - стартираме trial
        final now = DateTime.now();
        await prefs.setString('trial_start_date', now.toIso8601String());
        _trialEndDate = now.add(const Duration(days: trialPeriodDays));
        _isTrial = true;
        debugPrint('Trial started, ends: $_trialEndDate');
      } else {
        // Проверяваме дали trial е изтекъл
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

  /// Прилага промо код
  Future<({bool success, String message})> applyPromoCode(String code) async {
    try {
      final codeUpper = code.toUpperCase().trim();
      
      // Търсим кода във Firestore
      final docRef = FirebaseFirestore.instance.collection('promo_codes').doc(codeUpper);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        return (success: false, message: 'Невалиден код');
      }
      
      final data = doc.data()!;
      
      // Проверки
      if (data['isActive'] != true) {
        return (success: false, message: 'Кодът не е активен');
      }
      
      // Проверка за изтичане на кода
      if (data['expiresAt'] != null) {
        final expiresAt = (data['expiresAt'] as Timestamp).toDate();
        if (DateTime.now().isAfter(expiresAt)) {
          return (success: false, message: 'Кодът е изтекъл');
        }
      }
      
      // Проверка за максимален брой използвания
      final maxUses = data['maxUses'] as int? ?? 0;
      final usedCount = data['usedCount'] as int? ?? 0;
      if (maxUses > 0 && usedCount >= maxUses) {
        return (success: false, message: 'Кодът е изчерпан');
      }
      
      // Проверка дали потребителят вече е използвал този код
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final usedBy = List<String>.from(data['usedBy'] ?? []);
      if (userId != null && usedBy.contains(userId)) {
        return (success: false, message: 'Вече си използвал този код');
      }
      
      // Прилагаме кода
      final type = data['type'] as String;
      final days = data['days'] as int? ?? 0;
      
      final prefs = await SharedPreferences.getInstance();
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
      
      // Обновяваме Firestore
      await docRef.update({
        'usedCount': FieldValue.increment(1),
        if (userId != null) 'usedBy': FieldValue.arrayUnion([userId]),
      });
      
      notifyListeners();
      
      if (type == 'lifetime') {
        return (success: true, message: 'Поздравления! Имаш Pro завинаги!');
      } else {
        return (success: true, message: 'Поздравления! Имаш Pro за $days дни!');
      }
    } catch (e) {
      debugPrint('Apply promo code error: $e');
      return (success: false, message: 'Грешка: $e');
    }
  }

  void _updateProStatus(CustomerInfo customerInfo) {
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

  Future<List<StoreProduct>> getProducts() async {
    try {
      final products = await Purchases.getProducts([
        productIdLifetime,
        productIdMonthly,
        productIdYearly,
      ]);
      return products;
    } catch (e) {
      debugPrint('ProService getProducts error: $e');
      return [];
    }
  }

  Future<bool> purchase(StoreProduct product) async {
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
    try {
      final customerInfo = await Purchases.restorePurchases();
      _updateProStatus(customerInfo);
      return _isPro;
    } catch (e) {
      debugPrint('ProService restore error: $e');
      return false;
    }
  }

  /// Връща статус текст за показване
  String getStatusText(bool isBg) {
    if (_isPro) {
      return isBg ? 'Pro (платен)' : 'Pro (paid)';
    } else if (_isPromoCode && _promoEndDate == null) {
      return isBg ? 'Pro (промо код - завинаги)' : 'Pro (promo - lifetime)';
    } else if (_isPromoCode && _promoEndDate != null) {
      return isBg ? 'Pro (промо код - $promoDaysLeft дни)' : 'Pro (promo - $promoDaysLeft days)';
    } else if (_isTrial) {
      return isBg ? 'Pro (пробен период - $trialDaysLeft дни)' : 'Pro (trial - $trialDaysLeft days)';
    } else {
      return isBg ? 'Безплатен' : 'Free';
    }
  }

  // ============ Проверки за функционалности ============

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
  bool get shouldShowAds => !isPro && FreeLimits.showAds;
}
