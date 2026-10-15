import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ненатрапчива подкана за обновяване — НИКОГА не блокира приложението.
///
/// Android: Google Play **flexible** in-app update (сваля на заден план, после
/// предлага рестарт). Проверка най-много веднъж на ден.
/// iOS: iTunes lookup (bundleId `com.ivoexp.taskify`, country `bg`) сравнява
/// версията в App Store с текущата (package_info_plus). При по-нова → дискретен
/// диалог; „Не сега" отлага 3 дни.
class UpdatePromptService {
  UpdatePromptService._();
  static final UpdatePromptService instance = UpdatePromptService._();

  static const String _kAndroidDaily = 'update_check_android_ms';
  static const String _kIosDaily = 'update_check_ios_ms';
  static const String _kIosSnooze = 'update_snooze_ios_until_ms';
  static const String _bundleId = 'com.ivoexp.taskify';

  static const _oneDayMs = 24 * 60 * 60 * 1000;
  static const _threeDaysMs = 3 * _oneDayMs;

  bool _checkedThisSession = false;

  /// Главна входна точка — викай веднъж при старт (след другите диалози).
  Future<void> maybePrompt(BuildContext context, String lang) async {
    if (kIsWeb || _checkedThisSession) return;
    _checkedThisSession = true;
    try {
      if (Platform.isAndroid) {
        await _androidFlexible();
      } else if (Platform.isIOS) {
        if (context.mounted) await _iosItunesCheck(context, lang);
      }
    } catch (e) {
      debugPrint('UpdatePromptService error: $e');
    }
  }

  Future<void> _androidFlexible() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (prefs.getInt(_kAndroidDaily) ?? 0) < _oneDayMs) return;
    await prefs.setInt(_kAndroidDaily, now);

    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability == UpdateAvailability.updateAvailable &&
        info.flexibleUpdateAllowed) {
      // Flexible = сваля на заден план, потребителят продължава да ползва app-а.
      await InAppUpdate.startFlexibleUpdate();
      await InAppUpdate.completeFlexibleUpdate();
    }
  }

  Future<void> _iosItunesCheck(BuildContext context, String lang) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    // 3-дневно отлагане след „Не сега".
    if (now < (prefs.getInt(_kIosSnooze) ?? 0)) return;
    // И дневен гейт, за да не питаме мрежата при всеки старт.
    if (now - (prefs.getInt(_kIosDaily) ?? 0) < _oneDayMs) return;
    await prefs.setInt(_kIosDaily, now);

    final pkg = await PackageInfo.fromPlatform();
    final resp = await http.get(Uri.parse(
        'https://itunes.apple.com/lookup?bundleId=$_bundleId&country=bg'));
    if (resp.statusCode != 200) return;
    final data = json.decode(resp.body) as Map<String, dynamic>;
    final results = data['results'] as List?;
    if (results == null || results.isEmpty) return;
    final first = results.first as Map<String, dynamic>;
    final storeVersion = first['version'] as String?;
    final trackUrl = first['trackViewUrl'] as String?;
    if (storeVersion == null || !_isNewer(storeVersion, pkg.version)) return;

    if (!context.mounted) return;
    await _showIosDialog(context, lang, trackUrl);
  }

  Future<void> _showIosDialog(
      BuildContext context, String lang, String? trackUrl) async {
    const title = {
      'en': 'Update available', 'nl': 'Update beschikbaar', 'uk': 'Доступне оновлення', 'bg': 'Налична е нова версия',
      'de': 'Update verfügbar', 'fr': 'Mise à jour disponible', 'it': 'Aggiornamento disponibile',
      'el': 'Διαθέσιμη ενημέρωση', 'es': 'Actualización disponible', 'pt': 'Atualização disponível',
      'ru': 'Доступно обновление', 'tr': 'Güncelleme mevcut', 'ja': 'アップデートがあります',
    };
    const body = {
      'en': 'A new version of Taskify is available with the latest improvements.', 'nl': 'Er is een nieuwe versie van Taskify met de nieuwste verbeteringen.', 'uk': 'Доступна нова версія Taskify з останніми покращеннями.',
      'bg': 'Налична е нова версия на Taskify с последните подобрения.',
      'de': 'Eine neue Version von Taskify mit den neuesten Verbesserungen ist verfügbar.',
      'fr': 'Une nouvelle version de Taskify est disponible avec les dernières améliorations.',
      'it': 'È disponibile una nuova versione di Taskify con gli ultimi miglioramenti.',
      'el': 'Διαθέσιμη νέα έκδοση του Taskify με τις τελευταίες βελτιώσεις.',
      'es': 'Hay una nueva versión de Taskify con las últimas mejoras.',
      'pt': 'Está disponível uma nova versão do Taskify com as últimas melhorias.',
      'ru': 'Доступна новая версия Taskify с последними улучшениями.',
      'tr': "En son iyileştirmelerle Taskify'ın yeni sürümü mevcut.", 'ja': '最新の改善を含むTaskifyの新しいバージョンがあります。',
    };
    const update = {
      'en': 'Update', 'nl': 'Bijwerken', 'uk': 'Оновити', 'bg': 'Обнови', 'de': 'Aktualisieren', 'fr': 'Mettre à jour',
      'it': 'Aggiorna', 'el': 'Ενημέρωση', 'es': 'Actualizar', 'pt': 'Atualizar', 'ru': 'Обновить', 'tr': 'Güncelle', 'ja': '更新',
    };
    const later = {
      'en': 'Not now', 'nl': 'Niet nu', 'uk': 'Не зараз', 'bg': 'Не сега', 'de': 'Später', 'fr': 'Plus tard',
      'it': 'Non ora', 'el': 'Όχι τώρα', 'es': 'Ahora no', 'pt': 'Agora não', 'ru': 'Не сейчас', 'tr': 'Şimdi değil', 'ja': '後で',
    };
    String tr(Map<String, String> m) => m[lang] ?? m['en']!;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.system_update_rounded),
        title: Text(tr(title)),
        content: Text(tr(body)),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // „Не сега" → 3-дневно отлагане.
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt(_kIosSnooze,
                  DateTime.now().millisecondsSinceEpoch + _threeDaysMs);
            },
            child: Text(tr(later)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (trackUrl != null) {
                final uri = Uri.parse(trackUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
            child: Text(tr(update)),
          ),
        ],
      ),
    );
  }

  /// true ако `store` е по-нова версия от `current` (сравнение по сегменти).
  bool _isNewer(String store, String current) {
    final a = _segments(store);
    final b = _segments(current);
    final n = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  List<int> _segments(String v) => v
      .split('.')
      .map((s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
}
