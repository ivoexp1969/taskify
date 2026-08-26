import 'package:flutter/material.dart';

/// Малки presentational helper-и, споделяни от редактора на задачи и екрана
/// със статистики. Изнесени от `task_screen.dart` без промяна на поведение
/// (чисти функции, само параметри — без състояние).

Widget taskSectionLabel(String label, IconData icon, ThemeData theme) {
  return Row(
    children: [
      Icon(
        icon,
        size: 18,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          letterSpacing: 0.5,
        ),
      ),
    ],
  );
}

Widget taskPriorityButton({
  required String label,
  required int value,
  required bool selected,
  required Color color,
  required VoidCallback onTap,
}) {
  return Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flag_rounded,
              size: 18,
              color: selected ? color : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget taskDropdownTile({
  required String value,
  required Map<String, String> items,
  required ThemeData theme,
  required Function(String) onChanged,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: theme.colorScheme.outline.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        items: items.entries.map((entry) {
          return DropdownMenuItem<String>(
            value: entry.key,
            child: Text(entry.value),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) onChanged(val);
        },
      ),
    ),
  );
}

Widget taskStatCard({
  required String label,
  required int value,
  required bool selected,
  required VoidCallback onTap,
  required Color color,
  required IconData icon,
  required ThemeData theme,
}) {
  return Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.5) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: selected ? [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: selected ? color : theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 4),
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: selected ? color : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? color.withValues(alpha: 0.8)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Акцентен цвят по шаблон на задача (билетен стил и др.).
Color? templateAccentColor(String? template) {
  switch (template) {
    case 'shopping': return const Color(0xFF00E5A0);
    case 'birthday': return const Color(0xFFFF6FA8);
    case 'meeting':  return const Color(0xFF4DB8FF);
    case 'workout':  return const Color(0xFFFFB347);
    case 'payment':  return const Color(0xFF8AE000);
    case 'travel':   return const Color(0xFFA78BFF);
    case 'gift':     return const Color(0xFFFF7043);
    default: return null;
  }
}
