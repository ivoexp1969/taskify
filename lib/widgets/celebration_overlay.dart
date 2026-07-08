import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../utils/localization.dart';
import '../services/pro_service.dart';
import '../screens/paywall/paywall_screen.dart';

// ФАЗА 4.2: дискретен Premium линк в celebration момента (вместо отделен popup —
// моментът е техен). Показва се само на free. Локализиран ×11.
const Map<String, String> _kUnlockPremium = {
  'en': 'Unlock Premium', 'bg': 'Отключи Premium', 'de': 'Premium freischalten',
  'fr': 'Débloquer Premium', 'it': 'Sblocca Premium', 'el': 'Ξεκλείδωμα Premium',
  'es': 'Desbloquear Premium', 'pt': 'Desbloquear Premium', 'ru': 'Открыть Premium',
  'tr': 'Premium\'u aç', 'ja': 'Premiumを解放',
};

String _unlockPremiumText(String lang) =>
    _kUnlockPremium[lang] ?? _kUnlockPremium['en']!;

class CelebrationOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  
  const CelebrationOverlay({
    super.key,
    required this.onComplete,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _close();
        });
      }
    });
  }

  void _close() {
    if (_isClosing || !mounted) return;
    _isClosing = true;
    Navigator.of(context).pop();
    widget.onComplete();
  }

  /// Затваря overlay-а и отваря paywall-а (ФАЗА 4.2).
  void _openPremium() {
    if (_isClosing || !mounted) return;
    _isClosing = true;
    final nav = Navigator.of(context, rootNavigator: true);
    nav.pop();
    widget.onComplete();
    nav.push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    return Material(
      color: Colors.black.withValues(alpha: 0.75),
      child: InkWell(
        onTap: _close,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lottie анимация
              SizedBox(
                width: 300,
                height: 300,
                child: Lottie.asset(
                  'assets/animations/celebration.json',
                  controller: _controller,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),
              // Мотивиращо съобщение
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _controller,
                  curve: const Interval(0.2, 0.5, curve: Curves.easeIn),
                ),
                child: Text(
                  t.allTasksCompleted,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _controller,
                  curve: const Interval(0.3, 0.6, curve: Curves.easeIn),
                ),
                child: Text(
                  t.greatJob,
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 48),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _controller,
                  curve: const Interval(0.5, 0.8, curve: Curves.easeIn),
                ),
                child: Text(
                  t.tapToContinue,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
              // ФАЗА 4.2: дискретен Premium линк — само за free потребители.
              if (!ProService().isPro)
                FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _controller,
                    curve: const Interval(0.6, 0.9, curve: Curves.easeIn),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: TextButton.icon(
                      onPressed: _openPremium,
                      icon: const Icon(Icons.workspace_premium_rounded,
                          color: Colors.white70, size: 18),
                      label: Text(
                        _unlockPremiumText(t.lang),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Показва празничния overlay
void showCelebration(BuildContext context, {VoidCallback? onComplete}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Celebration',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return CelebrationOverlay(
        onComplete: onComplete ?? () {},
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  );
}


