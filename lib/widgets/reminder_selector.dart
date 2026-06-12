import 'package:flutter/material.dart';

/// Widget за избор на множество напомняния
class ReminderSelector extends StatelessWidget {
  final List<String> selectedReminders;
  final Function(List<String>) onChanged;
  final String langCode;
  final ThemeData theme;

  /// По избор: ограничи показаните опции (напр. дълги изпреварвания за документи).
  /// Ако е null — показва стандартните [reminderKeys] (поведението не се променя).
  final List<String>? availableKeys;

  const ReminderSelector({
    super.key,
    required this.selectedReminders,
    required this.onChanged,
    required this.langCode,
    required this.theme,
    this.availableKeys,
  });

  // Подредени хронологично (от най-рано до в точното време)
  static const Map<String, Map<String, String>> reminderLabels = {
    'minus_1d': {
      'en': '1 day before', 'bg': '1 ден преди', 'de': '1 Tag vorher',
      'fr': '1 jour avant', 'it': '1 giorno prima', 'el': '1 ημέρα πριν',
      'es': '1 día antes', 'pt': '1 dia antes', 'ru': 'За 1 день', 'tr': '1 gün önce', 'ja': '1日前',
    },
    'minus_2h': {
      'en': '2 hours before', 'bg': '2 часа преди', 'de': '2 Stunden vorher',
      'fr': '2 heures avant', 'it': '2 ore prima', 'el': '2 ώρες πριν',
      'es': '2 horas antes', 'pt': '2 horas antes', 'ru': 'За 2 часа', 'tr': '2 saat önce', 'ja': '2時間前',
    },
    'minus_1h': {
      'en': '1 hour before', 'bg': '1 час преди', 'de': '1 Stunde vorher',
      'fr': '1 heure avant', 'it': '1 ora prima', 'el': '1 ώρα πριν',
      'es': '1 hora antes', 'pt': '1 hora antes', 'ru': 'За 1 час', 'tr': '1 saat önce', 'ja': '1時間前',
    },
    'minus_30m': {
      'en': '30 minutes before', 'bg': '30 минути преди', 'de': '30 Minuten vorher',
      'fr': '30 minutes avant', 'it': '30 minuti prima', 'el': '30 λεπτά πριν',
      'es': '30 minutos antes', 'pt': '30 minutos antes', 'ru': 'За 30 минут', 'tr': '30 dakika önce', 'ja': '30分前',
    },
    'minus_15m': {
      'en': '15 minutes before', 'bg': '15 минути преди', 'de': '15 Minuten vorher',
      'fr': '15 minutes avant', 'it': '15 minuti prima', 'el': '15 λεπτά πριν',
      'es': '15 minutos antes', 'pt': '15 minutos antes', 'ru': 'За 15 минут', 'tr': '15 dakika önce', 'ja': '15分前',
    },
    'minus_5m': {
      'en': '5 minutes before', 'bg': '5 минути преди', 'de': '5 Minuten vorher',
      'fr': '5 minutes avant', 'it': '5 minuti prima', 'el': '5 λεπτά πριν',
      'es': '5 minutos antes', 'pt': '5 minutos antes', 'ru': 'За 5 минут', 'tr': '5 dakika önce', 'ja': '5分前',
    },
    'at_time': {
      'en': 'At due time', 'bg': 'В точното време', 'de': 'Zur Fälligkeit',
      'fr': 'À l\'heure prévue', 'it': 'All\'ora prevista', 'el': 'Την ώρα',
      'es': 'A la hora', 'pt': 'Na hora', 'ru': 'В назначенное время', 'tr': 'Tam zamanında', 'ja': '期限の時刻に',
    },
    'same_day_8': {
      'en': 'Same day at 8:00', 'bg': 'Същия ден в 8:00', 'de': 'Am selben Tag um 8:00',
      'fr': 'Le même jour à 8h00', 'it': 'Lo stesso giorno alle 8:00', 'el': 'Την ίδια μέρα στις 8:00',
      'es': 'El mismo día a las 8:00', 'pt': 'No mesmo dia às 8:00', 'ru': 'В тот же день в 8:00', 'tr': 'Aynı gün saat 8:00', 'ja': '当日の8:00',
    },
  };

  /// Дълги изпреварвания (дни/седмици/месеци преди) — за документи и др. дългосрочни
  /// срокове. Не са в стандартния списък, за да не затрупват обикновените задачи.
  static const Map<String, Map<String, String>> longLeadLabels = {
    'minus_2mo': {
      'en': '2 months before', 'bg': '2 месеца преди', 'de': '2 Monate vorher',
      'fr': '2 mois avant', 'it': '2 mesi prima', 'el': '2 μήνες πριν',
      'es': '2 meses antes', 'pt': '2 meses antes', 'ru': 'За 2 месяца', 'tr': '2 ay önce', 'ja': '2か月前',
    },
    'minus_1mo': {
      'en': '1 month before', 'bg': '1 месец преди', 'de': '1 Monat vorher',
      'fr': '1 mois avant', 'it': '1 mese prima', 'el': '1 μήνα πριν',
      'es': '1 mes antes', 'pt': '1 mês antes', 'ru': 'За 1 месяц', 'tr': '1 ay önce', 'ja': '1か月前',
    },
    'minus_2w': {
      'en': '2 weeks before', 'bg': '2 седмици преди', 'de': '2 Wochen vorher',
      'fr': '2 semaines avant', 'it': '2 settimane prima', 'el': '2 εβδομάδες πριν',
      'es': '2 semanas antes', 'pt': '2 semanas antes', 'ru': 'За 2 недели', 'tr': '2 hafta önce', 'ja': '2週間前',
    },
    'minus_1w': {
      'en': '1 week before', 'bg': '1 седмица преди', 'de': '1 Woche vorher',
      'fr': '1 semaine avant', 'it': '1 settimana prima', 'el': '1 εβδομάδα πριν',
      'es': '1 semana antes', 'pt': '1 semana antes', 'ru': 'За 1 неделю', 'tr': '1 hafta önce', 'ja': '1週間前',
    },
    'minus_3d': {
      'en': '3 days before', 'bg': '3 дни преди', 'de': '3 Tage vorher',
      'fr': '3 jours avant', 'it': '3 giorni prima', 'el': '3 ημέρες πριν',
      'es': '3 días antes', 'pt': '3 dias antes', 'ru': 'За 3 дня', 'tr': '3 gün önce', 'ja': '3日前',
    },
  };

  static const Map<String, String> noReminderLabels = {
    'en': 'No reminder', 'bg': 'Без напомняне', 'de': 'Keine Erinnerung',
    'fr': 'Pas de rappel', 'it': 'Nessun promemoria', 'el': 'Χωρίς υπενθύμιση',
    'es': 'Sin recordatorio', 'pt': 'Sem lembrete', 'ru': 'Без напоминания', 'tr': 'Hatırlatıcı yok', 'ja': 'リマインダーなし',
  };

  static List<String> get reminderKeys => reminderLabels.keys.toList();

  String _getLabel(String key) {
    final m = reminderLabels[key] ?? longLeadLabels[key];
    return m?[langCode] ?? m?['en'] ?? key;
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
          children: (availableKeys ?? reminderKeys).map((key) {
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
