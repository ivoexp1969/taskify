import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/renewal_service.dart';

/// „Поднови сега" / „Как да подновя?" — CTA под картата на изтичащ документ.
///
/// Само данни от [RenewalService]: ако няма активна оферта за този doctype +
/// държава, вдига `SizedBox.shrink()` (нищо не се показва). При commercial
/// оферта първият клик минава през еднократен disclosure sheet.
///
/// ФАЗА 1 (монетизация, Идея 1). [lang] служи и като proxy за държава — офертите
/// днес са държавно-скоупнати (напр. `['bg']`), а bg език ⇒ bg пазар.
class RenewalCta extends StatefulWidget {
  final String doctype;
  final String lang;

  const RenewalCta({super.key, required this.doctype, required this.lang});

  @override
  State<RenewalCta> createState() => _RenewalCtaState();
}

class _RenewalCtaState extends State<RenewalCta> {
  static const String _kDisclosureShown = 'renewal_disclosure_shown';

  RenewalOffer? _offer;
  bool _ready = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Пре-оценка щом офертите се сменят (фоново теглене от Firestore) → бутонът
    // лъсва без рестарт.
    RenewalService.revision.addListener(_resolve);
    _init();
  }

  @override
  void dispose() {
    RenewalService.revision.removeListener(_resolve);
    super.dispose();
  }

  Future<void> _init() async {
    await RenewalService().load();
    _resolve();
  }

  void _resolve() {
    if (!mounted) return;
    setState(() {
      _offer = RenewalService()
          .offerFor(doctype: widget.doctype, country: widget.lang);
      _ready = true;
    });
  }

  Future<void> _onTap() async {
    final offer = _offer;
    if (offer == null || _busy) return;
    setState(() => _busy = true);
    try {
      // Disclosure само за commercial оферти и само първия път.
      if (offer.commercial) {
        final ok = await _ensureDisclosure();
        if (!ok) return;
      }
      final url = await RenewalService().registerClickAndBuildUrl(offer);
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Показва disclosure еднократно. Връща true = потребителят продължава.
  Future<bool> _ensureDisclosure() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kDisclosureShown) ?? false) return true;
    if (!mounted) return false;

    final proceed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DisclosureSheet(lang: widget.lang),
    );
    if (proceed == true) {
      await prefs.setBool(_kDisclosureShown, true);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _offer == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final offer = _offer!;
    final label = _tr(offer.labelKey == 'howToRenew' ? _howToRenew : _renewNow,
        widget.lang);

    final child = _busy
        ? const SizedBox(
            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        : Text(label);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: offer.commercial
            ? FilledButton.tonalIcon(
                onPressed: _busy ? null : _onTap,
                icon: const Icon(Icons.autorenew_rounded, size: 18),
                label: child,
              )
            : TextButton.icon(
                onPressed: _busy ? null : _onTap,
                icon: Icon(Icons.info_outline_rounded,
                    size: 18, color: theme.colorScheme.primary),
                label: child,
              ),
      ),
    );
  }
}

/// Еднократен disclosure за партньорски линкове.
class _DisclosureSheet extends StatelessWidget {
  final String lang;
  const _DisclosureSheet({required this.lang});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF13131f) : theme.colorScheme.surface;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            Row(children: [
              Icon(Icons.handshake_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_tr(_disclosureTitle, lang),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 12),
            Text(_tr(_disclosureBody, lang),
                style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8))),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(_tr(_cancel, lang)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(_tr(_continue, lang)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

String _tr(Map<String, String> m, String lang) => m[lang] ?? m['en']!;

const _renewNow = {
  'en': 'Renew now', 'bg': 'Поднови сега', 'de': 'Jetzt verlängern',
  'fr': 'Renouveler', 'it': 'Rinnova ora', 'el': 'Ανανέωση τώρα',
  'es': 'Renovar ahora', 'pt': 'Renovar agora', 'ru': 'Продлить',
  'tr': 'Şimdi yenile', 'ja': '今すぐ更新',
};
const _howToRenew = {
  'en': 'How to renew?', 'bg': 'Как да подновя?', 'de': 'Wie verlängern?',
  'fr': 'Comment renouveler ?', 'it': 'Come rinnovare?', 'el': 'Πώς να ανανεώσω;',
  'es': '¿Cómo renovar?', 'pt': 'Como renovar?', 'ru': 'Как продлить?',
  'tr': 'Nasıl yenilenir?', 'ja': '更新方法は？',
};
const _disclosureTitle = {
  'en': 'Partner link', 'bg': 'Партньорска препратка', 'de': 'Partnerlink',
  'fr': 'Lien partenaire', 'it': 'Link partner', 'el': 'Σύνδεσμος συνεργάτη',
  'es': 'Enlace de socio', 'pt': 'Link de parceiro', 'ru': 'Партнёрская ссылка',
  'tr': 'Ortak bağlantısı', 'ja': 'パートナーリンク',
};
const _disclosureBody = {
  'en': 'This is a partner link. Taskify may earn a commission — at no extra cost to you. Your data stays on your device.',
  'bg': 'Това е партньорски линк. Taskify може да получи комисиона, без това да те оскъпява. Данните ти остават на устройството.',
  'de': 'Dies ist ein Partnerlink. Taskify erhält evtl. eine Provision – ohne Mehrkosten für dich. Deine Daten bleiben auf dem Gerät.',
  'fr': 'Ceci est un lien partenaire. Taskify peut percevoir une commission, sans frais pour vous. Vos données restent sur l\'appareil.',
  'it': 'Questo è un link partner. Taskify può ricevere una commissione, senza costi per te. I tuoi dati restano sul dispositivo.',
  'el': 'Αυτός είναι σύνδεσμος συνεργάτη. Το Taskify μπορεί να λάβει προμήθεια, χωρίς επιπλέον κόστος για εσάς. Τα δεδομένα σας μένουν στη συσκευή.',
  'es': 'Este es un enlace de socio. Taskify puede recibir una comisión, sin coste adicional para ti. Tus datos permanecen en tu dispositivo.',
  'pt': 'Este é um link de parceiro. O Taskify pode receber uma comissão, sem custo extra para você. Seus dados ficam no dispositivo.',
  'ru': 'Это партнёрская ссылка. Taskify может получить комиссию — без дополнительных затрат для вас. Ваши данные остаются на устройстве.',
  'tr': 'Bu bir ortak bağlantısıdır. Taskify komisyon alabilir — size ek maliyet olmadan. Verileriniz cihazınızda kalır.',
  'ja': 'これはパートナーリンクです。Taskifyは手数料を得る場合がありますが、追加費用はかかりません。データは端末内に留まります。',
};
const _continue = {
  'en': 'Continue', 'bg': 'Продължи', 'de': 'Weiter', 'fr': 'Continuer',
  'it': 'Continua', 'el': 'Συνέχεια', 'es': 'Continuar', 'pt': 'Continuar',
  'ru': 'Продолжить', 'tr': 'Devam', 'ja': '続ける',
};
const _cancel = {
  'en': 'Cancel', 'bg': 'Отказ', 'de': 'Abbrechen', 'fr': 'Annuler',
  'it': 'Annulla', 'el': 'Άκυρο', 'es': 'Cancelar', 'pt': 'Cancelar',
  'ru': 'Отмена', 'tr': 'İptal', 'ja': 'キャンセル',
};
