import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../services/pro_service.dart';
import '../services/name_days_service.dart';
import '../utils/debug_overrides.dart';

/// ★ВРЕМЕНЕН развоен панел★ — виждан САМО в debug билд (`kDebugMode`). В release
/// връща празно и нищо не прави (DebugOverrides setter-ите също са no-op), затова
/// е безопасен да остане в кода. Позволява ръчна симулация на:
///   • изтекъл trial (приложението се държи като free);
///   • „днес" = 8 ноември (за имен-ден логиката).
class DebugOverridesPanel extends StatefulWidget {
  const DebugOverridesPanel({super.key});

  @override
  State<DebugOverridesPanel> createState() => _DebugOverridesPanelState();
}

class _DebugOverridesPanelState extends State<DebugOverridesPanel> {
  // 8 ноември (Архангеловден) — голям български имен ден, удобен за тест.
  static final DateTime _nov8 = DateTime(DateTime.now().year, 11, 8, 9, 0);

  void _refresh() {
    // Pro статусът се смята при четене → карай ProService да преизчисли + уведоми.
    ProService().onAppResumed();
    // Именните известия зависят от датата/Pro → препланирай.
    final lang = Localizations.localeOf(context).languageCode;
    NameDaysService().refreshNotificationsFromPrefs(lang);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: Colors.deepOrange.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.deepOrange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.bug_report_rounded,
                    color: Colors.deepOrange, size: 20),
                const SizedBox(width: 8),
                Text('DEBUG · само dev билд',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          SwitchListTile(
            dense: true,
            title: const Text('Симулирай изтекъл trial'),
            subtitle: const Text('Приложението се държи като безплатно'),
            value: DebugOverrides.forceTrialExpired,
            onChanged: (v) {
              DebugOverrides.forceTrialExpired = v;
              _refresh();
            },
          ),
          SwitchListTile(
            dense: true,
            title: const Text('Симулирай дата 8 ноември'),
            subtitle: Text(DebugOverrides.fakeNow != null
                ? 'Активно: ${DebugOverrides.fakeNow}'
                : 'Реална дата'),
            value: DebugOverrides.fakeNow != null,
            onChanged: (v) {
              DebugOverrides.fakeNow = v ? _nov8 : null;
              _refresh();
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
