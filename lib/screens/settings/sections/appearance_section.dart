import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

import '../../../utils/localization.dart';
import '../../../services/task_view_preference.dart';
import '../../../services/pro_service.dart';
import '../../paywall/paywall_screen.dart';
import 'settings_group.dart';
import 'widget_guide_tile.dart';

/// Секция „Външен вид" — избор на стил на task картите (Класически / Билети).
/// Реактивна: смяната важи веднага в целия app. „Билети" е Pro тема.
///
/// Изнесена 1:1 от [SettingsScreen] (`_buildAppearanceSection`).
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([TaskViewPreference(), ProService()]),
      builder: (context, _) {
        final pref = TaskViewPreference();
        final isPro = ProService().isPro;

        Widget styleTile({
          required IconData icon,
          required Color color,
          required String title,
          required String subtitle,
          required bool selected,
          required bool locked,
          required VoidCallback onTap,
        }) {
          return InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
                            if (locked) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.lock, size: 14, color: theme.colorScheme.primary),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle, style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          );
        }

        final themeController = ThemeScope.of(context);
        final currentMode = themeController.mode;
        final langCode = LanguageScope.of(context).locale.languageCode;
        return SettingsGroup(
          title: t.appearance,
          icon: Icons.palette_rounded,
          color: Colors.deepPurple,
          children: [
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  styleTile(
                    icon: Icons.view_agenda_rounded,
                    color: Colors.blueGrey,
                    title: t.cardStyleClassic,
                    subtitle: t.cardStyleClassicDesc,
                    selected: pref.cardStyle == CardStyle.classic,
                    locked: false,
                    onTap: () => pref.setCardStyle(CardStyle.classic),
                  ),
                  const Divider(height: 0),
                  styleTile(
                    icon: Icons.confirmation_number_outlined,
                    color: Colors.deepPurple,
                    title: t.cardStyleTicket,
                    subtitle: t.cardStyleTicketDesc,
                    selected: pref.cardStyle == CardStyle.ticket,
                    locked: !isPro,
                    onTap: () async {
                      if (!isPro) {
                        final upgraded = await showPaywallIfNeeded(
                          context,
                          isFeatureAvailable: false,
                          featureName: t.cardStyleTicket,
                        );
                        if (!upgraded) return;
                      }
                      await pref.setCardStyle(CardStyle.ticket);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Тема (light/dark/amoled) — преместена в „Външен вид" (Пакет 2).
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  RadioListTile<int>(
                    value: 0,
                    groupValue: themeController.isAmoled ? 3 : (currentMode == ThemeMode.system ? 0 : (currentMode == ThemeMode.light ? 1 : 2)),
                    title: Text(t.systemTheme),
                    onChanged: (value) => themeController.setMode(ThemeMode.system),
                  ),
                  const Divider(height: 0),
                  RadioListTile<int>(
                    value: 1,
                    groupValue: themeController.isAmoled ? 3 : (currentMode == ThemeMode.system ? 0 : (currentMode == ThemeMode.light ? 1 : 2)),
                    title: Text(t.lightTheme),
                    onChanged: (value) => themeController.setMode(ThemeMode.light),
                  ),
                  const Divider(height: 0),
                  RadioListTile<int>(
                    value: 2,
                    groupValue: themeController.isAmoled ? 3 : (currentMode == ThemeMode.system ? 0 : (currentMode == ThemeMode.light ? 1 : 2)),
                    title: Text(t.darkTheme),
                    onChanged: (value) => themeController.setMode(ThemeMode.dark),
                  ),
                  const Divider(height: 0),
                  RadioListTile<int>(
                    value: 3,
                    groupValue: themeController.isAmoled ? 3 : (currentMode == ThemeMode.system ? 0 : (currentMode == ThemeMode.light ? 1 : 2)),
                    title: Text(t.amoledTheme),
                    subtitle: Text('OLED',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                    onChanged: (value) => themeController.setAmoled(true),
                  ),
                ],
              ),
            ),
            // „Добави widget" (iOS) — преместено в „Външен вид" (Пакет 2).
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
              WidgetGuideTile(lang: langCode),
          ],
        );
      },
    );
  }
}
