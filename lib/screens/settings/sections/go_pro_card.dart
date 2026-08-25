import 'package:flutter/material.dart';

import '../../../utils/localization.dart';
import '../../paywall/paywall_screen.dart';

/// „Стани Pro" карта — постоянен вход към paywall (показва се само за не-Pro на
/// mobile). Изнесена 1:1 от [SettingsScreen] (`_buildGoProCard`). Действието
/// „Възстанови покупки" остава в екрана и се подава през [onRestore].
class GoProCard extends StatelessWidget {
  const GoProCard({super.key, required this.onRestore});

  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageScope.of(context).locale.languageCode;
    String tr(Map<String, String> m) => m[lang] ?? m['en']!;

    const title = {
      'en': 'Get Taskify Pro', 'bg': 'Стани Pro', 'de': 'Taskify Pro holen',
      'fr': 'Passer à Pro', 'it': 'Passa a Pro', 'el': 'Απόκτησε το Pro',
      'es': 'Hazte Pro', 'pt': 'Seja Pro', 'ru': 'Стать Pro',
      'tr': 'Pro\'ya geç', 'ja': 'Taskify Pro にアップグレード',
    };
    const subtitle = {
      'en': 'Calendar, AI, cloud sync, no ads and more',
      'bg': 'Календар, AI, облак, без реклами и още',
      'de': 'Kalender, KI, Cloud-Sync, keine Werbung und mehr',
      'fr': 'Calendrier, IA, sync cloud, sans pubs et plus',
      'it': 'Calendario, IA, sync cloud, niente pubblicità e altro',
      'el': 'Ημερολόγιο, AI, συγχρονισμός cloud, χωρίς διαφημίσεις και άλλα',
      'es': 'Calendario, IA, sync en la nube, sin anuncios y más',
      'pt': 'Calendário, IA, sync na nuvem, sem anúncios e mais',
      'ru': 'Календарь, ИИ, облако, без рекламы и другое',
      'tr': 'Takvim, AI, bulut senkronizasyonu, reklamsız ve daha fazlası',
      'ja': 'カレンダー、AI、クラウド同期、広告なしなど',
    };
    const getButton = {
      'en': 'Get Pro', 'bg': 'Вземи Pro', 'de': 'Pro holen',
      'fr': 'Obtenir Pro', 'it': 'Ottieni Pro', 'el': 'Απόκτηση Pro',
      'es': 'Obtener Pro', 'pt': 'Obter Pro', 'ru': 'Получить Pro',
      'tr': 'Pro al', 'ja': 'Pro を入手',
    };
    const restoreButton = {
      'en': 'Restore purchases', 'bg': 'Възстанови покупки',
      'de': 'Käufe wiederherstellen', 'fr': 'Restaurer les achats',
      'it': 'Ripristina acquisti', 'el': 'Επαναφορά αγορών',
      'es': 'Restaurar compras', 'pt': 'Restaurar compras',
      'ru': 'Восстановить покупки', 'tr': 'Satın alımları geri yükle',
      'ja': '購入を復元',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.workspace_premium,
                        color: Colors.white, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(title),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr(subtitle),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFE65100),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const PaywallScreen()),
                          );
                        },
                        child: Text(
                          tr(getButton),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onRestore,
                      child: Text(tr(restoreButton)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
