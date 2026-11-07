import 'package:flutter/material.dart';

import '../../models/group.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../utils/localization.dart';
import '../../widgets/reminder_selector.dart';

/// Споделен „Списък за пазаруване" в група (v1.0.72, точка 1).
///
/// Продуктите са map по id върху документа на задачата (`items.<id>`) →
/// отметките са field-path update-и (`items.<id>.checked`), така че едновременни
/// отметки на различни продукти от различни членове се merge-ват без overwrite.
/// Real-time (Firestore snapshots) + „Купено от X". Офлайн отметка се опашква и
/// се синхронизира при връщане на мрежата (вградената offline persistence).
class GroupShoppingListScreen extends StatefulWidget {
  final Group group;
  final String taskId;
  const GroupShoppingListScreen(
      {super.key, required this.group, required this.taskId});

  static Future<void> show(BuildContext context, Group group, String taskId) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GroupShoppingListScreen(group: group, taskId: taskId),
      ),
    );
  }

  @override
  State<GroupShoppingListScreen> createState() =>
      _GroupShoppingListScreenState();
}

class _GroupShoppingListScreenState extends State<GroupShoppingListScreen> {
  final GroupService _service = GroupService();
  final TextEditingController _addController = TextEditingController();
  final FocusNode _addFocus = FocusNode();

  @override
  void dispose() {
    _addController.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _addItem(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _addController.clear();
    _addFocus.requestFocus();
    try {
      await _service.addItem(widget.group.id, widget.taskId, trimmed);
    } catch (_) {/* snapshot-ите ще коригират UI */}
  }

  /// Отмята продукт + авто-завършва/размаркира задачата, ако всички са отметнати.
  Future<void> _toggleItem(GroupTask gt, ShoppingItem item) async {
    final newChecked = !item.checked;
    try {
      await _service.toggleItem(
          widget.group.id, widget.taskId, item.id, newChecked);
      // Авто-завършване: пресмятаме спрямо новото състояние (локално, без да
      // чакаме round-trip).
      final items = gt.items ?? const <ShoppingItem>[];
      final total = items.length;
      final checked = items
              .where((i) => i.id == item.id ? newChecked : i.checked)
              .length;
      final allDone = total > 0 && checked == total;
      if (allDone != gt.isCompleted) {
        await _service.toggleComplete(
            widget.group.id, widget.taskId, allDone);
      }
    } catch (_) {}
  }

  Future<void> _deleteItem(String itemId) async {
    try {
      await _service.removeItem(widget.group.id, widget.taskId, itemId);
    } catch (_) {}
  }

  Future<void> _clearChecked(GroupTask gt) async {
    final ids = (gt.items ?? const <ShoppingItem>[])
        .where((i) => i.checked)
        .map((i) => i.id)
        .toList();
    if (ids.isEmpty) return;
    try {
      await _service.clearCheckedItems(widget.group.id, widget.taskId, ids);
      // Списъкът вече не е „всичко отметнато" → размаркирай завършена.
      if (gt.isCompleted) {
        await _service.toggleComplete(widget.group.id, widget.taskId, false);
      }
    } catch (_) {}
  }

  void _openSettings(GroupTask gt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupShoppingSettingsSheet(
        groupId: widget.group.id,
        task: gt,
      ),
    );
  }

  /// Трие целия споделен списък (tombstone). Разрешено за автора И собственика
  /// на групата (точка 3, v1.0.72); другите членове — не. Правилата позволяват
  /// на всеки член, затова ограничението е клиентско. След триене излиза от
  /// екрана; другите устройства с отворен екран авто-излизат (watchTask→null).
  Future<void> _deleteList(GroupTask gt) async {
    final t = AppText.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deletion),
        content: Text(t.deleteGroupTaskConfirm(widget.group.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final nav = Navigator.of(context);
    try {
      await _service.deleteTask(widget.group.id, widget.taskId);
    } catch (_) {/* snapshot-ите ще коригират; не блокирай изхода */}
    if (mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);

    return StreamBuilder<GroupTask?>(
      stream: _service.watchTask(widget.group.id, widget.taskId),
      builder: (context, snap) {
        // Задачата е изтрита от друг член → излез.
        if (snap.hasData && snap.data == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        final gt = snap.data;
        if (gt == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final items = gt.items ?? const <ShoppingItem>[];
        final checked = items.where((i) => i.checked).length;
        final total = items.length;
        final uid = AuthService().currentUser?.uid;
        final canDelete = gt.createdBy == null ||
            gt.createdBy == uid ||
            widget.group.isOwner(uid ?? '');

        return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gt.title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
                Text(
                  total > 0 ? '$checked / $total · ${widget.group.name}'
                      : widget.group.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            actions: [
              if (checked > 0)
                TextButton.icon(
                  onPressed: () => _clearChecked(gt),
                  icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                  label: Text(t.clearCompleted),
                  style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error),
                ),
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: t.editTask,
                onPressed: () => _openSettings(gt),
              ),
              if (canDelete)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'delete') _deleteList(gt);
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          const SizedBox(width: 12),
                          Text(t.delete,
                              style: const TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: Column(
            children: [
              if (total > 0)
                LinearProgressIndicator(
                  value: checked / total,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: checked == total
                      ? Colors.green
                      : theme.colorScheme.primary,
                  minHeight: 4,
                ),
              Expanded(
                child: total == 0
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shopping_cart_outlined,
                                size: 64,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.2)),
                            const SizedBox(height: 12),
                            Text(t.addItem,
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.4))),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 80),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final isDone = item.checked;
                          final buyer = (isDone && item.checkedBy != null)
                              ? widget.group
                                  .memberFor(item.checkedBy!)
                                  .displayName
                              : null;
                          return Dismissible(
                            key: ValueKey('g_shop_${item.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red,
                              child: const Icon(Icons.delete_outline,
                                  color: Colors.white),
                            ),
                            onDismissed: (_) => _deleteItem(item.id),
                            child: ListTile(
                              leading: GestureDetector(
                                onTap: () => _toggleItem(gt, item),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDone
                                        ? Colors.green
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isDone
                                          ? Colors.green
                                          : theme.colorScheme.outline,
                                      width: 2,
                                    ),
                                  ),
                                  child: isDone
                                      ? const Icon(Icons.check,
                                          color: Colors.white, size: 14)
                                      : null,
                                ),
                              ),
                              title: Text(
                                item.text,
                                style: TextStyle(
                                  decoration: isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isDone
                                      ? theme.colorScheme.onSurface
                                          .withValues(alpha: 0.4)
                                      : null,
                                ),
                              ),
                              subtitle: buyer != null
                                  ? Text(t.boughtByName(buyer),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                              color: theme
                                                  .colorScheme.primary
                                                  .withValues(alpha: 0.8)))
                                  : null,
                              onTap: () => _toggleItem(gt, item),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _addController,
                        focusNode: _addFocus,
                        decoration: InputDecoration(
                          hintText: t.enterItem,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: _addItem,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _addItem(_addController.text),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Настройки на груповия списък (заглавие/дата/час/напомняне+обхват) ────────

class _GroupShoppingSettingsSheet extends StatefulWidget {
  final String groupId;
  final GroupTask task;
  const _GroupShoppingSettingsSheet(
      {required this.groupId, required this.task});

  @override
  State<_GroupShoppingSettingsSheet> createState() =>
      _GroupShoppingSettingsSheetState();
}

class _GroupShoppingSettingsSheetState
    extends State<_GroupShoppingSettingsSheet> {
  final GroupService _service = GroupService();
  late TextEditingController _titleController;
  late DateTime _date;
  TimeOfDay? _time;
  late List<String> _reminders;
  late bool _remindAll;

  @override
  void initState() {
    super.initState();
    final due = widget.task.dueDate;
    _titleController = TextEditingController(text: widget.task.title);
    _date = DateTime(due.year, due.month, due.day);
    _time = (due.hour != 0 || due.minute != 0)
        ? TimeOfDay(hour: due.hour, minute: due.minute)
        : null;
    _reminders = List<String>.from(widget.task.reminders ?? const <String>[]);
    _remindAll = widget.task.remindAll;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _fmt2(int n) => n.toString().padLeft(2, '0');

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final newDate = DateTime(_date.year, _date.month, _date.day,
        _time?.hour ?? 0, _time?.minute ?? 0);
    final uid = AuthService().currentUser?.uid;
    final updated = GroupTask(
      id: widget.task.id,
      title: title,
      dueDate: newDate,
      categoryName: widget.task.categoryName,
      priority: widget.task.priority,
      recurrence: null,
      reminders: _reminders.isEmpty ? null : _reminders,
      subtasks: widget.task.subtasks,
      notes: widget.task.notes,
      isCompleted: widget.task.isCompleted,
      template: 'shopping',
      // Напомнянето звъни локално само на този, който го е задал (освен remindAll).
      reminderSetBy: _reminders.isEmpty ? null : uid,
      remindAll: _remindAll,
    );
    final nav = Navigator.of(context);
    try {
      await _service.updateTask(widget.groupId, widget.task.id, updated);
    } catch (_) {}
    if (mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final langCode = LanguageScope.of(context).locale.languageCode;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
          top: 12,
          left: 20,
          right: 20,
          bottom: bottomInset + bottomPadding + 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(t.editTask,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: t.title,
                prefixIcon: const Icon(Icons.shopping_cart_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            _Row(
              icon: Icons.calendar_today_outlined,
              label: t.dueDate,
              value: '${_fmt2(_date.day)}.${_fmt2(_date.month)}.${_date.year}',
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
              theme: theme,
            ),
            const SizedBox(height: 8),
            _Row(
              icon: Icons.access_time_rounded,
              label: t.time,
              value: _time != null
                  ? '${_fmt2(_time!.hour)}:${_fmt2(_time!.minute)}'
                  : '--:--',
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _time ?? TimeOfDay.now(),
                );
                if (picked != null) setState(() => _time = picked);
              },
              trailing: _time != null
                  ? GestureDetector(
                      onTap: () => setState(() => _time = null),
                      child: Icon(Icons.close_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4)),
                    )
                  : null,
              theme: theme,
            ),
            const SizedBox(height: 20),
            Text(t.reminders,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ReminderSelector(
              selectedReminders: _reminders,
              onChanged: (list) => setState(() => _reminders = list),
              langCode: langCode,
              theme: theme,
            ),
            // Обхват на напомнянето — само при избрани напомняния.
            if (_reminders.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(t.reminderScope,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _remindAll,
                onChanged: (v) => setState(() => _remindAll = v),
                title: Text(_remindAll ? t.remindEveryone : t.remindMeOnly),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(t.saveChanges),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;
  final ThemeData theme;

  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.theme,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
