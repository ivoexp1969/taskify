import 'package:flutter/material.dart';

import '../services/ai_usage_service.dart';
import '../services/pro_service.dart';
import '../screens/paywall/paywall_screen.dart';
import '../utils/localization.dart';

/// ФАЗА 2: мек (не наказателен) limit UI, когато FREE потребител изчерпи
/// дневната AI квота. Показва обяснение + основен CTA към paywall-а и
/// вторичен dismiss („Утре отново"). Pro никога не стига дотук.
Future<void> showAiLimitSheet(BuildContext context) async {
  final t = AppText.of(context);
  final theme = Theme.of(context);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2FF7), Color(0xFF2196F3)],
                  ),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                t.aiLimitTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                t.aiLimitBody(AiUsageService.dailyLimit),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PaywallScreen()),
                  );
                },
                icon: const Icon(Icons.workspace_premium_rounded),
                label: Text(t.aiSeePremium),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(sheetCtx).pop(),
                child: Text(t.aiTomorrowAgain),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Дискретен брояч „използвани/лимит" до AI бутона — САМО за free потребители.
/// За Pro връща нищо (неограничено). Реактивен спрямо rebuild на родителя
/// (напр. `setSheetState` след успешно разпознаване).
class AiQuotaChip extends StatelessWidget {
  const AiQuotaChip({super.key});

  @override
  Widget build(BuildContext context) {
    if (ProService().isPro) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return FutureBuilder<int>(
      future: AiUsageService.instance.usedToday(),
      builder: (context, snap) {
        final used = snap.data;
        if (used == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(
            '$used/${AiUsageService.dailyLimit}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}
