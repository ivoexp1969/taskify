import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:url_launcher/url_launcher.dart';

/// Кръстосана промоция на другото приложение на 1969 — „Навици".
///
/// Секцията „Още от 1969" в Настройки показва:
///   • ПРОСТ линк — винаги видим (Android: отваря приложението, ако е
///     инсталирано, иначе Play Store; iOS: App Store, без детекция);
///   • BONUS карта — САМО Android, при 5+ задачи, Навици НЕ е инсталирано
///     и картата не е dismiss-ната последните 30 дни.
///
/// Детекцията ползва `InstalledApps.isAppInstalled(pkg)` + `<package>` в
/// `<queries>` на манифеста — БЕЗ `QUERY_ALL_PACKAGES` (чувствително за Play).
///
/// Singleton (като [ProService] / [AnalyticsService]).
class CompanionAppService {
  static final CompanionAppService _instance = CompanionAppService._();
  factory CompanionAppService() => _instance;
  CompanionAppService._();

  static const String naviciAndroidPackage = 'com.ivoexp.habits';
  static const String naviciIOSAppId = '6806278691';
  static const String hiveBoxName = 'companion_app_state';
  static const String bonusDismissedKey = 'navici_bonus_dismissed_until';
  static const int bonusDismissDays = 30;
  static const int minTasksForBonus = 5;

  Box? _box;

  Future<void> _ensureBox() async {
    _box ??= await Hive.openBox(hiveBoxName);
  }

  /// Проверява дали Навици е инсталирано.
  /// Android: `InstalledApps.isAppInstalled` (+ `<queries>` в манифеста).
  /// iOS: `canLaunchUrl('navici://')` — Навици декларира схемата, Taskify я
  /// listва в `LSApplicationQueriesSchemes`. Web винаги false.
  Future<bool> isNaviciInstalled() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      try {
        final installed =
            await InstalledApps.isAppInstalled(naviciAndroidPackage);
        return installed ?? false;
      } catch (e) {
        debugPrint('CompanionAppService.isNaviciInstalled failed: $e');
        return false;
      }
    }
    if (Platform.isIOS) {
      try {
        return await canLaunchUrl(Uri.parse('navici://'));
      } catch (e) {
        debugPrint('CompanionAppService.isNaviciInstalled (iOS) failed: $e');
        return false;
      }
    }
    return false;
  }

  /// Дали BONUS КАРТАТА може да се показва (обикновеният линк се показва
  /// винаги). Android + iOS, стига да не е dismiss-нат последните 30 дни.
  /// Извикващият проверява отделно броя задачи (>=5) и че Навици НЕ е инсталирано.
  Future<bool> shouldShowBonusCard() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return false;
    await _ensureBox();
    final dismissedUntilMillis = _box?.get(bonusDismissedKey) as int?;
    if (dismissedUntilMillis != null) {
      final dismissedUntil =
          DateTime.fromMillisecondsSinceEpoch(dismissedUntilMillis);
      if (DateTime.now().isBefore(dismissedUntil)) {
        return false;
      }
    }
    return true;
  }

  /// Записва dismiss-a — bonus картата няма да се показва 30 дни.
  Future<void> dismissBonusCard() async {
    await _ensureBox();
    final until = DateTime.now().add(const Duration(days: bonusDismissDays));
    await _box?.put(bonusDismissedKey, until.millisecondsSinceEpoch);
  }

  /// Отваря Навици ако е инсталирано (Android), иначе съответния магазин.
  /// [source] ("simple_link"/"bonus_card") влиза в Play referrer за UTM.
  Future<void> openOrInstall({required String source}) async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      final installed = await isNaviciInstalled();
      if (installed) {
        try {
          final ok = await InstalledApps.startApp(naviciAndroidPackage);
          if (ok == true) return;
        } catch (_) {
          // пропада към Play Store по-долу
        }
      }
      await _openPlayStore(source);
    } else if (Platform.isIOS) {
      // iOS: само линк към App Store (детекция идва в отделен промпт по-късно).
      await _openAppStore();
    }
  }

  Future<void> _openPlayStore(String source) async {
    final url =
        'https://play.google.com/store/apps/details?id=$naviciAndroidPackage'
        '&referrer=utm_source%3Dtaskify%26utm_medium%3Din_app%26utm_campaign%3D$source';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('CompanionAppService._openPlayStore failed: $e');
    }
  }

  Future<void> _openAppStore() async {
    const url = 'https://apps.apple.com/app/id$naviciIOSAppId';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('CompanionAppService._openAppStore failed: $e');
    }
  }
}
