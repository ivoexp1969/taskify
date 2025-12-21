import 'package:flutter/material.dart';

/// Widget за избор на множество напомняния
class ReminderSelector extends StatelessWidget {
  final List<String> selectedReminders;
  final Function(List<String>) onChanged;
  final bool isBg;
  final ThemeData theme;

  const ReminderSelector({
    super.key,
    required this.selectedReminders,
    required this.onChanged,
    required this.isBg,
    required this.theme,
  });

  // Подредени хронологично (от най-рано до в точното време)
  static const List<MapEntry<String, Map<String, String>>> reminderOptions = [
    MapEntry('minus_1d', {'bg': '1 ден преди', 'en': '1 day before'}),
    MapEntry('minus_2h', {'bg': '2 часа преди', 'en': '2 hours before'}),
    MapEntry('minus_1h', {'bg': '1 час преди', 'en': '1 hour before'}),
    MapEntry('minus_30m', {'bg': '30 минути преди', 'en': '30 minutes before'}),
    MapEntry('minus_15m', {'bg': '15 минути преди', 'en': '15 minutes before'}),
    MapEntry('minus_5m', {'bg': '5 минути преди', 'en': '5 minutes before'}),
    MapEntry('at_time', {'bg': 'В точното време', 'en': 'At due time'}),
    MapEntry('same_day_8', {'bg': 'Същия ден в 8:00', 'en': 'Same day at 8:00'}),
  ];

  String _getLabel(String key) {
    for (final entry in reminderOptions) {
      if (entry.key == key) {
        return entry.value[isBg ? 'bg' : 'en'] ?? key;
      }
    }
    return key;
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
                  ? theme.colorScheme.outline.withOpacity(0.15)
                  : theme.colorScheme.outline.withOpacity(0.08),
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
                      : theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  isBg ? 'Без напомняне' : 'No reminder',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: !hasAnySelected ? FontWeight.w600 : FontWeight.normal,
                    color: !hasAnySelected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withOpacity(0.7),
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
          children: reminderOptions.map((entry) {
            final key = entry.key;
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
                        ? theme.colorScheme.primary.withOpacity(0.15)
                        : theme.colorScheme.outline.withOpacity(0.08),
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
                            : theme.colorScheme.onSurface.withOpacity(0.5),
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