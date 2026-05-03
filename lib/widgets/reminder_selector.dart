import 'package:flutter/material.dart';

/// Widget за избор на множество напомняния
class ReminderSelector extends StatelessWidget {
  final List<String> selectedReminders;
  final Function(List<String>) onChanged;
  final String langCode;
  final ThemeData theme;

  const ReminderSelector({
    super.key,
    required this.selectedReminders,
    required this.onChanged,
    required this.langCode,
    required this.theme,
  });

  // Подредени хронологично (от най-рано до в точното време)
  static const Map<String, Map<String, String>> reminderLabels = {
    'minus_1d': {
      'en': '1 day before', 'bg': '1 ден преди', 'de': '1 Tag vorher',
      'fr': '1 jour avant', 'it': '1 giorno prima', 'el': '1 ημέρα πριν',
      'es': '1 día antes', 'pt': '1 dia antes', 'ru': 'За 1 день', 'tr': '1 gün önce',
    },
    'minus_2h': {
      'en': '2 hours before', 'bg': '2 часа преди', 'de': '2 Stunden vorher',
      'fr': '2 heures avant', 'it': '2 ore prima', 'el': '2 ώρες πριν',
      'es': '2 horas antes', 'pt': '2 horas antes', 'ru': 'За 2 часа', 'tr': '2 saat önce',
    },
    'minus_1h': {
      'en': '1 hour before', 'bg': '1 час преди', 'de': '1 Stunde vorher',
      'fr': '1 heure avant', 'it': '1 ora prima', 'el': '1 ώρα πριν',
      'es': '1 hora antes', 'pt': '1 hora antes', 'ru': 'За 1 час', 'tr': '1 saat önce',
    },
    'minus_30m': {
      'en': '30 minutes before', 'bg': '30 минути преди', 'de': '30 Minuten vorher',
      'fr': '30 minutes avant', 'it': '30 minuti prima', 'el': '30 λεπτά πριν',
      'es': '30 minutos antes', 'pt': '30 minutos antes', 'ru': 'За 30 минут', 'tr': '30 dakika önce',
    },
    'minus_15m': {
      'en': '15 minutes before', 'bg': '15 минути преди', 'de': '15 Minuten vorher',
      'fr': '15 minutes avant', 'it': '15 minuti prima', 'el': '15 λεπτά πριν',
      'es': '15 minutos antes', 'pt': '15 minutos antes', 'ru': 'За 15 минут', 'tr': '15 dakika önce',
    },
    'minus_5m': {
      'en': '5 minutes before', 'bg': '5 минути преди', 'de': '5 Minuten vorher',
      'fr': '5 minutes avant', 'it': '5 minuti prima', 'el': '5 λεπτά πριν',
      'es': '5 minutos antes', 'pt': '5 minutos antes', 'ru': 'За 5 минут', 'tr': '5 dakika önce',
    },
    'at_time': {
      'en': 'At due time', 'bg': 'В точното време', 'de': 'Zur Fälligkeit',
      'fr': 'À l\'heure prévue', 'it': 'All\'ora prevista', 'el': 'Την ώρα',
      'es': 'A la hora', 'pt': 'Na hora', 'ru': 'В назначенное время', 'tr': 'Tam zamanında',
    },
    'same_day_8': {
      'en': 'Same day at 8:00', 'bg': 'Същия ден в 8:00', 'de': 'Am selben Tag um 8:00',
      'fr': 'Le même jour à 8h00', 'it': 'Lo stesso giorno alle 8:00', 'el': 'Την ίδια μέρα στις 8:00',
      'es': 'El mismo día a las 8:00', 'pt': 'No mesmo dia às 8:00', 'ru': 'В тот же день в 8:00', 'tr': 'Aynı gün saat 8:00',
    },
  };

  static const Map<String, String> noReminderLabels = {
    'en': 'No reminder', 'bg': 'Без напомняне', 'de': 'Keine Erinnerung',
    'fr': 'Pas de rappel', 'it': 'Nessun promemoria', 'el': 'Χωρίς υπενθύμιση',
    'es': 'Sin recordatorio', 'pt': 'Sem lembrete', 'ru': 'Без напоминания', 'tr': 'Hatırlatıcı yok',
  };

  static List<String> get reminderKeys => reminderLabels.keys.toList();

  String _getLabel(String key) {
    return reminderLabels[key]?[langCode] ?? reminderLabels[key]?['en'] ?? key;
  }

  String _getNoReminderLabel() {
    return noReminderLabels[langCode] ?? noReminderLabels['en']!;
  }

  void _toggle(String key) {
    final newList = List<String>.from(selectedReminders);
    if (newList.contains(key)) {
      newList.remove(key);
    } else {
      newList.add(key);
    }
    onChanged(newList);
  }

  void _clearAll() {
    onChanged([]);
  }

  @override
  Widget build(BuildContext context) {
    final hasAnySelected = selectedReminders.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Бутон "Без напомняне"
        GestureDetector(
          onTap: _clearAll,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: !hasAnySelected
                  ? theme.colorScheme.outline.withValues(alpha: 0.15)
                  : theme.colorScheme.outline.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: !hasAnySelected
                    ? theme.colorScheme.outline
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  size: 16,
                  color: !hasAnySelected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  _getNoReminderLabel(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: !hasAnySelected ? FontWeight.w600 : FontWeight.normal,
                    color: !hasAnySelected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Опции за напомняния
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: reminderKeys.map((key) {
            final isSelected = selectedReminders.contains(key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _toggle(key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : theme.colorScheme.outline.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        size: 16,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getLabel(key),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
