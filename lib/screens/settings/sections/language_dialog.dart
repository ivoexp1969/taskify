import 'package:flutter/material.dart';

import '../../../utils/localization.dart';

/// Диалог за избор на език. Изнесено от `settings_screen.dart` без промяна
/// на поведение.
void showLanguageDialog(BuildContext context,
    LanguageController languageController, Locale currentLocale) {
  final theme = Theme.of(context);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        height: MediaQuery.of(ctx).size.height * 0.7,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.language_rounded,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    AppText.of(context).language,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Списък с езици - SCROLLABLE
            Expanded(
              child: ListView.builder(
                itemCount: SupportedLocales.all.length,
                itemBuilder: (context, index) {
                  final locale = SupportedLocales.all[index];
                  final isSelected = currentLocale.languageCode == locale.languageCode;
                  return ListTile(
                    leading: Text(
                      SupportedLocales.flags[locale.languageCode] ?? '🌐',
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(
                      SupportedLocales.names[locale.languageCode] ?? locale.languageCode,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                        : null,
                    onTap: () {
                      languageController.setLocale(locale);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
