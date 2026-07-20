import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// „Какво ново" — изскачащ прозорец, който се показва ВЕДНЪЖ след ъпдейт до
/// нова версия (и на Android, и на iOS). Потребителите не четат release notes
/// в магазина → ако не го обявим вътре в приложението, новите функции остават
/// неоткрити.
///
/// ★ПРИ ВСЕКИ РЕЛИЙЗ★ (преди `flutter build appbundle` / Xcode archive):
///   1) вдигни [_build] на новия versionCode от `pubspec.yaml`;
///   2) подмени [_items] с точките за новата версия (11 езика).
///
/// Нови инсталации НЕ го виждат (те виждат welcome диалога).
class WhatsNewDialog {
  /// Билдът, за който са точките по-долу (= `pubspec.yaml` build number).
  static const int _build = 64;

  static const String _prefKey = 'whats_new_seen_build';

  /// Точките за текущата версия, по език.
  static const Map<String, List<String>> _items = {
    'bg': [
      '🎒 Нов Училищен режим: обратно броене до следващата ваканция направо на началния екран.',
      'Избери класа си и добави учебните предмети — стават категории за домашните.',
      'За 7. и 12. клас — броене и до НВО и матурите.',
    ],
    'en': [
      '🎒 New School mode: a countdown to the next school vacation right on your home screen.',
      'Pick your grade and add your subjects — they become categories for homework.',
      'For grades 7 and 12 — a countdown to the NEO and matriculation exams too.',
    ],
    'de': [
      '🎒 Neuer Schulmodus: ein Countdown bis zu den nächsten Ferien auf dem Startbildschirm.',
      'Wähle deine Klasse und füge deine Fächer hinzu — sie werden zu Kategorien.',
      'Für Klasse 7 und 12 — auch ein Countdown bis zu den Prüfungen.',
    ],
    'fr': [
      "🎒 Nouveau Mode école : un compte à rebours des prochaines vacances sur l'accueil.",
      'Choisis ta classe et ajoute tes matières — elles deviennent des catégories.',
      'Pour la 7e et la terminale — aussi un compte à rebours des examens.',
    ],
    'it': [
      '🎒 Nuova Modalità scuola: un conto alla rovescia per le prossime vacanze in home.',
      'Scegli la classe e aggiungi le materie — diventano categorie per i compiti.',
      'Per la 7ª e la 12ª — anche un conto alla rovescia degli esami.',
    ],
    'el': [
      '🎒 Νέα Λειτουργία σχολείου: αντίστροφη μέτρηση για τις επόμενες διακοπές στην αρχική.',
      'Διάλεξε τάξη και πρόσθεσε μαθήματα — γίνονται κατηγορίες για τις εργασίες.',
      'Για 7η και 12η — και μέτρηση για τις εξετάσεις.',
    ],
    'es': [
      '🎒 Nuevo Modo escolar: una cuenta atrás para las próximas vacaciones en el inicio.',
      'Elige tu grado y añade tus asignaturas — se vuelven categorías para las tareas.',
      'Para 7.º y 12.º — también una cuenta atrás para los exámenes.',
    ],
    'pt': [
      '🎒 Novo Modo escolar: uma contagem para as próximas férias no ecrã inicial.',
      'Escolhe o teu ano e adiciona as disciplinas — viram categorias para os trabalhos.',
      'Para o 7.º e o 12.º — também uma contagem para os exames.',
    ],
    'ru': [
      '🎒 Новый Школьный режим: обратный отсчёт до ближайших каникул на главном экране.',
      'Выбери класс и добавь предметы — они станут категориями для домашних заданий.',
      'Для 7 и 12 класса — отсчёт и до экзаменов.',
    ],
    'tr': [
      '🎒 Yeni Okul modu: ana ekranda bir sonraki tatile geri sayım.',
      'Sınıfını seç ve derslerini ekle — ödevler için kategoriye dönüşür.',
      '7. ve 12. sınıf için — sınavlara da geri sayım.',
    ],
    'ja': [
      '🎒 新しい学校モード：次の休みまでのカウントダウンをホーム画面に表示。',
      '学年を選んで教科を追加 — 宿題用のカテゴリになります。',
      '7年生・12年生には試験までのカウントダウンも。',
    ],
  };

  static const Map<String, String> _title = {
    'en': "What's new", 'bg': 'Какво ново', 'de': 'Was ist neu',
    'fr': 'Quoi de neuf', 'it': 'Novità', 'el': 'Τι νέο υπάρχει',
    'es': 'Novedades', 'pt': 'Novidades', 'ru': 'Что нового',
    'tr': 'Yenilikler', 'ja': '新着情報',
  };

  static const Map<String, String> _button = {
    'en': 'Got it!', 'bg': 'Супер!', 'de': 'Super!', 'fr': 'Compris!',
    'it': 'Ottimo!', 'el': 'Τέλεια!', 'es': '¡Genial!', 'pt': 'Ótimo!',
    'ru': 'Отлично!', 'tr': 'Harika!', 'ja': '了解！',
  };

  /// Показва диалога веднъж за текущия билд. Безопасно при повторно извикване.
  static Future<void> maybeShow(BuildContext context, String lang) async {
    if (kIsWeb) return;

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getInt(_prefKey) ?? 0;
    if (seen >= _build) return;

    // Нова инсталация (никога не е стигала до welcome диалога) → само отбелязваме
    // билда; тя няма „ново", тя е нова.
    final freshInstall =
        seen == 0 && !(prefs.getBool('taskify_welcome_shown_v2') ?? false);
    await prefs.setInt(_prefKey, _build);
    if (freshInstall) return;

    String version = '';
    try {
      version = (await PackageInfo.fromPlatform()).version;
    } catch (_) {/* без версия в заглавието */}

    if (!context.mounted) return;

    final items = _items[lang] ?? _items['en']!;
    final title = _title[lang] ?? _title['en']!;
    final button = _button[lang] ?? _button['en']!;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.auto_awesome, size: 44, color: Colors.amber),
        title: Text(version.isEmpty ? title : '$title — $version'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3, right: 8),
                        child: Icon(Icons.check_circle, size: 18,
                            color: Colors.green),
                      ),
                      Expanded(child: Text(item)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(button),
          ),
        ],
      ),
    );
  }
}
