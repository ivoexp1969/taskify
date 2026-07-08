import 'dart:async';

import 'package:flutter/material.dart';

import '../services/renewal_service.dart';

/// „Изпрати цветя/подарък" — CTA за поводи (рожден ден, имен ден).
///
/// Докато реален партньор (онлайн магазин за цветя/подаръци) няма, при клик
/// показваме „Очаквайте скоро" вместо да отваряме линк — но ВСЕ ОЩЕ логваме
/// интереса ([RenewalService.logInterest]), за да измерим търсенето преди
/// старта (аргумент в преговорите с партньор).
///
/// Обърни [kGiftComingSoon] на `false`, щом има реална affiliate връзка.
const bool kGiftComingSoon = true;

/// Общи действия за „цветя/подарък" бутоните (карта + списък с контакти).
class GiftOffer {
  const GiftOffer._();

  /// Клик по „Изпрати цветя/подарък": логва интерес + (в coming-soon режим)
  /// показва диалог „Очаквайте скоро". [kind] разграничава повода в лога
  /// (напр. 'gift_birthday' | 'gift_nameday').
  static Future<void> tap(
    BuildContext context, {
    required String lang,
    required String kind,
  }) async {
    // Логваме интереса независимо от режима (демонд сигнал).
    unawaited(RenewalService().logInterest(kind: kind));
    if (kGiftComingSoon) {
      await _showComingSoon(context, lang);
    }
    // (Бъдеще: тук отваряме реалния affiliate URL, когато kGiftComingSoon=false.)
  }

  static Future<void> _showComingSoon(BuildContext context, String lang) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.local_florist_rounded),
        title: Text(_tr(_comingSoonTitle, lang)),
        content: Text(_tr(_comingSoonBody, lang)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_tr(_ok, lang)),
          ),
        ],
      ),
    );
  }
}

/// Пълноширок бутон „🌹 Изпрати цветя/подарък" за картата на повода.
class GiftOfferButton extends StatelessWidget {
  final String lang;
  final String kind;

  const GiftOfferButton({super.key, required this.lang, required this.kind});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF39FF14), // неоново зелен ТЕКСТ (не фон)
          side: const BorderSide(color: Color(0xFF39FF14), width: 1.5),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
        icon: const Icon(Icons.local_florist_rounded, size: 18),
        label: Text(_tr(_sendGift, lang)),
        onPressed: () => GiftOffer.tap(context, lang: lang, kind: kind),
      ),
    );
  }
}

String _tr(Map<String, String> m, String lang) => m[lang] ?? m['en']!;

const _sendGift = {
  'en': 'Send flowers / gift', 'bg': 'Изпрати цветя/подарък',
  'de': 'Blumen / Geschenk senden', 'fr': 'Envoyer fleurs / cadeau',
  'it': 'Invia fiori / regalo', 'el': 'Στείλε λουλούδια / δώρο',
  'es': 'Enviar flores / regalo', 'pt': 'Enviar flores / presente',
  'ru': 'Цветы / подарок', 'tr': 'Çiçek / hediye gönder',
  'ja': '花・ギフトを贈る',
};
const _comingSoonTitle = {
  'en': 'Coming soon!', 'bg': 'Очаквайте скоро!', 'de': 'Demnächst verfügbar!',
  'fr': 'Bientôt disponible !', 'it': 'Presto disponibile!', 'el': 'Έρχεται σύντομα!',
  'es': '¡Muy pronto!', 'pt': 'Em breve!', 'ru': 'Скоро!',
  'tr': 'Çok yakında!', 'ja': '近日公開！',
};
const _comingSoonBody = {
  'en': 'Sending flowers and gifts straight from Taskify is coming very soon. Thanks for your interest!',
  'bg': 'Скоро ще можеш да пращаш цветя и подаръци директно от Taskify. Благодарим за интереса!',
  'de': 'Blumen und Geschenke direkt aus Taskify zu senden, ist bald möglich. Danke für dein Interesse!',
  'fr': 'Envoyer des fleurs et des cadeaux directement depuis Taskify arrive bientôt. Merci de votre intérêt !',
  'it': 'Inviare fiori e regali direttamente da Taskify sarà presto possibile. Grazie per l\'interesse!',
  'el': 'Η αποστολή λουλουδιών και δώρων απευθείας από το Taskify έρχεται σύντομα. Ευχαριστούμε για το ενδιαφέρον!',
  'es': 'Enviar flores y regalos directamente desde Taskify llegará muy pronto. ¡Gracias por tu interés!',
  'pt': 'Enviar flores e presentes diretamente do Taskify chega em breve. Obrigado pelo interesse!',
  'ru': 'Отправка цветов и подарков прямо из Taskify скоро появится. Спасибо за интерес!',
  'tr': 'Taskify\'dan doğrudan çiçek ve hediye göndermek çok yakında. İlginiz için teşekkürler!',
  'ja': 'Taskifyから直接お花やギフトを贈る機能はまもなく登場します。ご関心ありがとうございます！',
};
const _ok = {
  'en': 'OK', 'bg': 'Разбрах', 'de': 'OK', 'fr': 'OK', 'it': 'OK',
  'el': 'Εντάξει', 'es': 'Vale', 'pt': 'OK', 'ru': 'Понятно',
  'tr': 'Tamam', 'ja': 'OK',
};
