import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Готова картичка „Честит имен ден" — рендира се на екрана (преглед) и при
/// „Сподели" се заснема като PNG и се споделя през системния лист. Цветовата
/// палитра се избира по името → всеки получава различна, „оригинална" картичка.
class NameDayCardUtil {
  NameDayCardUtil._();

  // Празнични градиенти (горе-ляво → долу-дясно).
  static const List<List<Color>> _palettes = [
    [Color(0xFF8E24AA), Color(0xFFD81B60)],
    [Color(0xFFF06292), Color(0xFFBA68C8)],
    [Color(0xFF5C6BC0), Color(0xFF7E57C2)],
    [Color(0xFFEC407A), Color(0xFFFF7043)],
    [Color(0xFF26A69A), Color(0xFF66BB6A)],
    [Color(0xFFFFB300), Color(0xFFF4511E)],
    [Color(0xFF42A5F5), Color(0xFF26C6DA)],
  ];

  static const Map<String, String> _greeting = {
    'en': 'Happy name day!', 'bg': 'Честит имен ден!',
    'de': 'Alles Gute zum Namenstag!', 'fr': 'Bonne fête !',
    'it': 'Buon onomastico!', 'el': 'Χρόνια πολλά!',
    'es': '¡Feliz santo!', 'pt': 'Feliz dia do nome!',
    'ru': 'С именинами!', 'tr': 'İsim günün kutlu olsun!',
    'ja': '聖名祝日おめでとう！',
  };
  static const Map<String, String> _shareLbl = {
    'en': 'Share', 'bg': 'Сподели', 'de': 'Teilen', 'fr': 'Partager',
    'it': 'Condividi', 'el': 'Κοινοποίηση', 'es': 'Compartir',
    'pt': 'Partilhar', 'ru': 'Поделиться', 'tr': 'Paylaş', 'ja': '共有',
  };
  static const Map<String, String> _closeLbl = {
    'en': 'Close', 'bg': 'Затвори', 'de': 'Schließen', 'fr': 'Fermer',
    'it': 'Chiudi', 'el': 'Κλείσιμο', 'es': 'Cerrar', 'pt': 'Fechar',
    'ru': 'Закрыть', 'tr': 'Kapat', 'ja': '閉じる',
  };

  /// Показва преглед на картичката + бутон „Сподели".
  static Future<void> show({
    required BuildContext context,
    required String name,
    required String feast,
    required String wish,
    required String lang,
  }) async {
    final boundaryKey = GlobalKey();
    final palette = _palettes[name.hashCode.abs() % _palettes.length];
    final greeting = _greeting[lang] ?? _greeting['en']!;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: boundaryKey,
              child: _NameDayCard(
                  name: name, feast: feast, greeting: greeting, colors: palette),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.share_rounded),
                  label: Text(_shareLbl[lang] ?? _shareLbl['en']!),
                  onPressed: () => _captureAndShare(ctx, boundaryKey, wish),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(_closeLbl[lang] ?? _closeLbl['en']!),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _captureAndShare(
      BuildContext context, GlobalKey key, String wish) async {
    try {
      // Малко изчакване — да са готови шрифтовете (Caveat) при първо отваряне.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data?.buffer.asUint8List();
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/nameday_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      if (!context.mounted) return;
      // iOS popover anchor.
      final box = context.findRenderObject() as RenderBox?;
      final size = MediaQuery.of(context).size;
      final origin = (box != null && box.hasSize)
          ? box.localToGlobal(Offset.zero) & box.size
          : Rect.fromCenter(
              center: Offset(size.width / 2, size.height / 2),
              width: 1,
              height: 1);
      await Share.shareXFiles([XFile(file.path)],
          text: wish, sharePositionOrigin: origin);
    } catch (_) {
      // тих fail
    }
  }
}

class _NameDayCard extends StatelessWidget {
  final String name;
  final String feast;
  final String greeting;
  final List<Color> colors;
  const _NameDayCard({
    required this.name,
    required this.feast,
    required this.greeting,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: 320,
        height: 400,
        child: Stack(
          children: [
            // Градиент фон.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                ),
              ),
            ),
            // Декоративни конфети-кръгчета.
            ..._confetti(),
            // Тънка вътрешна рамка.
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.55)),
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            // Съдържание.
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 30, 26, 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 46)),
                  const SizedBox(height: 10),
                  Text(
                    greeting,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.caveat(
                      fontSize: 34,
                      height: 1.0,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.caveat(
                      fontSize: 56,
                      height: 1.0,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                            blurRadius: 8,
                            color: Colors.black26,
                            offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      feast,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text('🌸   🌷   🌹', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
            // Воден знак.
            Positioned(
              bottom: 10,
              right: 16,
              child: Text(
                'Taskify',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _confetti() {
    Widget dot(double l, double t, double s, double a) => Positioned(
          left: l,
          top: t,
          child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: a),
              shape: BoxShape.circle,
            ),
          ),
        );
    return [
      dot(28, 40, 14, 0.18),
      dot(270, 70, 22, 0.14),
      dot(60, 320, 18, 0.16),
      dot(250, 330, 12, 0.20),
      dot(160, 30, 9, 0.22),
      dot(300, 250, 10, 0.18),
      dot(16, 200, 8, 0.20),
    ];
  }
}
