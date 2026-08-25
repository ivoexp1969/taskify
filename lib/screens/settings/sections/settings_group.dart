import 'package:flutter/material.dart';

/// Падаща (сгъваема) група в Настройки — намалява претрупването. Логиката на
/// всяка секция остава непокътната; тук само я обгръщаме визуално.
///
/// Изнесено 1:1 от [SettingsScreen] (`_settingsGroup`) без промяна на поведение.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // Скрий стандартните разделители на ExpansionTile за по-чист вид.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(title,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.2,
              )),
          initiallyExpanded: initiallyExpanded,
          shape: const Border(),
          collapsedShape: const Border(),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          children: children,
        ),
      ),
    );
  }
}
