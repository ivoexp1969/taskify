import 'package:flutter/material.dart';

import '../services/companion_app_service.dart';
import '../services/analytics_service.dart';
import '../utils/localization.dart';

/// Секция „Още от 1969" в Настройки — кръстосана промоция на „Навици".
///
/// • ПРОСТ линк — винаги видим (Android/iOS: отвори ако е инсталирано, иначе свали).
/// • BONUS карта — Android + iOS, при [currentTaskCount] >= 5, Навици НЕ е
///   инсталирано и не е dismiss-нато последните 30 дни.
class MoreFrom1969Section extends StatefulWidget {
  final int currentTaskCount;

  const MoreFrom1969Section({
    super.key,
    required this.currentTaskCount,
  });

  @override
  State<MoreFrom1969Section> createState() => _MoreFrom1969SectionState();
}

class _MoreFrom1969SectionState extends State<MoreFrom1969Section> {
  final _service = CompanionAppService();
  bool _installed = false;
  bool _loading = true;
  bool _showBonus = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final installed = await _service.isNaviciInstalled();
    final canShowBonus = await _service.shouldShowBonusCard();
    final hasEnoughTasks =
        widget.currentTaskCount >= CompanionAppService.minTasksForBonus;
    // Bonus картата само: НЯМА Навици + 5+ задачи + не е dismiss-нато.
    final showBonus = !installed && hasEnoughTasks && canShowBonus;

    if (!mounted) return;
    setState(() {
      _installed = installed;
      _showBonus = showBonus;
      _loading = false;
    });

    AnalyticsService().logCompanionAppShown('habits', 'simple_link');
    if (showBonus) {
      AnalyticsService().logCompanionAppShown('habits', 'bonus_card');
    }
  }

  Future<void> _handleSimpleLinkTap() async {
    AnalyticsService().logCompanionAppClicked(
      'habits',
      _installed ? 'open' : 'install',
      'simple_link',
    );
    await _service.openOrInstall(source: 'simple_link');
  }

  Future<void> _handleBonusCardTap() async {
    AnalyticsService().logCompanionAppClicked('habits', 'install', 'bonus_card');
    await _service.openOrInstall(source: 'bonus_card');
  }

  Future<void> _handleDismissBonus() async {
    AnalyticsService().logCompanionAppDismissed('habits');
    await _service.dismissBonusCard();
    if (!mounted) return;
    setState(() => _showBonus = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final t = AppText.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заглавие на секцията
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
          child: Text(
            t.moreFrom1969Title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),

        // ПРОСТ ЛИНК КЪМ НАВИЦИ — винаги видим
        Card(
          elevation: 1,
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF00E5FF),
                    Color(0xFF7C4DFF),
                    Color(0xFFFF4081),
                  ],
                ),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 22,
              ),
            ),
            title: Text(
              t.moreFrom1969NaviciTitle,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              t.moreFrom1969NaviciSubtitle,
              style: theme.textTheme.bodySmall,
            ),
            trailing: FilledButton.tonalIcon(
              onPressed: _handleSimpleLinkTap,
              icon: Icon(_installed ? Icons.launch : Icons.download, size: 16),
              label: Text(_installed ? t.open : t.download),
            ),
          ),
        ),

        // BONUS КАРТА — условно (5+ задачи, не dismissed, не installed)
        if (_showBonus) ...[
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.card_giftcard, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.companionBonusTitle,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: _handleDismissBonus,
                        tooltip: t.dismiss,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.companionBonusBody,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _handleBonusCardTap,
                      icon: const Icon(Icons.download),
                      label: Text(t.companionBonusCta),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.companionBonusFooter,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
