import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/task.dart';
import '../../services/notification_service.dart';
import '../../services/tombstone_service.dart';
import '../../utils/localization.dart';
import '../../widgets/renewal_cta.dart';
import '../task/document_dialog.dart';

/// Универсален раздел „Документи" — изтичащи документи (лична карта, паспорт,
/// книжка, застраховка, тех. преглед и др.). Чете задачите с template `document`
/// (НЕ отделно хранилище) → едни данни с Календар/„Днес"/облак.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late final Box<Task> taskBox;

  @override
  void initState() {
    super.initState();
    taskBox = Hive.box<Task>('tasks');
  }

  String get _lang => LanguageScope.of(context).locale.languageCode;

  List<Task> _documents() {
    final list = taskBox.values
        .where((t) => t.template == 'document' && !t.isArchived)
        .toList();
    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  String _docType(Task t) {
    final notes = t.notes;
    if (notes != null) {
      for (final line in notes.split('\n')) {
        if (line.startsWith('doctype:')) return line.replaceFirst('doctype:', '').trim();
      }
    }
    return 'other';
  }

  int _daysLeft(Task t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
    return exp.difference(today).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppText.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.documents)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => DocumentDialog.show(context),
        icon: const Icon(Icons.add),
        label: Text(t.addDocument),
      ),
      body: ValueListenableBuilder(
        valueListenable: taskBox.listenable(),
        builder: (context, _, __) {
          final docs = _documents();
          if (docs.isEmpty) return _buildEmpty(theme, t);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: docs.length,
            itemBuilder: (_, i) => _buildCard(docs[i], theme, t),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme, AppText t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.badge_outlined,
                size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              t.documentsEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Task task, ThemeData theme, AppText t) {
    final daysLeft = _daysLeft(task);
    final urgencyColor = daysLeft < 0
        ? Colors.red
        : daysLeft <= 7
            ? Colors.orange
            : daysLeft <= 30
                ? Colors.amber.shade700
                : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: urgencyColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_iconFor(_docType(task)), color: urgencyColor),
            ),
            title: Text(task.title),
            subtitle: Text(
              _statusLine(task, daysLeft),
              style: TextStyle(fontSize: 12, color: urgencyColor, fontWeight: FontWeight.w500),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') DocumentDialog.show(context, existing: task);
                if (v == 'delete') _confirmDelete(task, t);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(t.edit)),
                PopupMenuItem(value: 'delete', child: Text(t.delete)),
              ],
            ),
            onTap: () => DocumentDialog.show(context, existing: task),
          ),
          // „Поднови сега" — само близо до/след изтичане; сам се скрива, ако
          // няма партньорска оферта за този тип документ и държава (Идея 1).
          if (daysLeft <= 30)
            RenewalCta(doctype: _docType(task), lang: _lang),
        ],
      ),
    );
  }

  String _statusLine(Task task, int d) {
    final e = task.dueDate;
    final dateStr =
        '${e.day.toString().padLeft(2, '0')}.${e.month.toString().padLeft(2, '0')}.${e.year}';
    if (d < 0) return '${_tr(_expiredOn)} $dateStr';
    if (d == 0) return _tr(_expiresToday);
    return '${_tr(_expiresInPrefix).replaceAll('{days}', '$d')} · $dateStr';
  }

  Future<void> _confirmDelete(Task task, AppText t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.delete),
        content: Text(task.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.delete)),
        ],
      ),
    );
    if (ok == true) {
      await NotificationService().cancelForTask(task);
      // ВАЖНО: трий през TombstoneService (не `task.delete()`), за да се запише
      // надгробен камък → изтриването се разпространява до облака и задачата НЕ
      // „възкръсва" при следващ merge sync.
      await TombstoneService().deleteTask(task);
    }
  }

  String _tr(Map<String, String> m) => m[_lang] ?? m['en']!;

  static IconData _iconFor(String type) {
    switch (type) {
      case 'vignette':
        return Icons.toll_rounded;
      case 'insurance':
        return Icons.verified_user_rounded;
      case 'inspection':
        return Icons.car_repair_rounded;
      case 'id_card':
        return Icons.badge_rounded;
      case 'passport':
        return Icons.menu_book_rounded;
      case 'license':
        return Icons.directions_car_rounded;
      default:
        return Icons.description_rounded;
    }
  }
}

// --- Локализация на статуса (същите низове като стария раздел) ---
const _expiresInPrefix = {
  'en': 'Expires in {days} days', 'bg': 'Изтича след {days} дни',
  'de': 'Läuft in {days} Tagen ab', 'fr': 'Expire dans {days} jours',
  'it': 'Scade tra {days} giorni', 'el': 'Λήγει σε {days} ημέρες',
  'es': 'Caduca en {days} días', 'pt': 'Expira em {days} dias',
  'ru': 'Истекает через {days} дней', 'tr': '{days} gün içinde doluyor', 'ja': '{days}日後に期限切れ',
};
const _expiresToday = {
  'en': 'Expires today', 'bg': 'Изтича днес', 'de': 'Läuft heute ab',
  'fr': "Expire aujourd'hui", 'it': 'Scade oggi', 'el': 'Λήγει σήμερα',
  'es': 'Caduca hoy', 'pt': 'Expira hoje', 'ru': 'Истекает сегодня',
  'tr': 'Bugün doluyor', 'ja': '本日期限切れ',
};
const _expiredOn = {
  'en': 'Expired on', 'bg': 'Изтекъл на', 'de': 'Abgelaufen am',
  'fr': 'Expiré le', 'it': 'Scaduto il', 'el': 'Έληξε στις',
  'es': 'Caducó el', 'pt': 'Expirou em', 'ru': 'Истёк', 'tr': 'Doldu:', 'ja': '有効期限',
};
