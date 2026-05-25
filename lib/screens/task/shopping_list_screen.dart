import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../models/task.dart';
import '../../utils/localization.dart';
import '../../services/notification_service.dart';
import '../../widgets/reminder_selector.dart';

class ShoppingListScreen extends StatefulWidget {
  final Task task;
  const ShoppingListScreen({super.key, required this.task});

  static Future<void> show(BuildContext context, Task task) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ShoppingListScreen(task: task)),
    );
  }

  static Future<void> create(BuildContext context) async {
    final taskBox = Hive.box<Task>('tasks');
    final t = AppText.of(context);
    final now = DateTime.now();
    final task = Task(
      title: t.shoppingList,
      dueDate: DateTime(now.year, now.month, now.day),
      categoryId: 'shopping',
      priority: 1,
      template: 'shopping',
    );
    await taskBox.add(task);
    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ShoppingListScreen(task: task)),
      );
    }
  }

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  late List<Map<String, dynamic>> _items;
  final TextEditingController _addController = TextEditingController();
  final FocusNode _addFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _items = _loadItems();
  }

  List<Map<String, dynamic>> _loadItems() {
    int counter = 0;
    return widget.task.subtasksList.map((item) {
      return {...item, 'id': counter++};
    }).toList();
  }

  @override
  void dispose() {
    _addController.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    widget.task.setSubtasks(_items);
    await widget.task.save();
  }

  void _addItem(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _items.add({
        'done': false,
        'text': trimmed,
        'id': DateTime.now().microsecondsSinceEpoch,
      });
    });
    _addController.clear();
    _save();
  }

  Future<void> _toggleItem(int index) async {
    final newDone = !(_items[index]['done'] as bool);
    _items[index]['done'] = newDone;
    await _save();

    bool needTaskSave = false;
    if (_items.isNotEmpty && _items.every((i) => i['done'] == true)) {
      if (!widget.task.isCompleted) {
        widget.task.isCompleted = true;
        widget.task.completedAt = DateTime.now();
        needTaskSave = true;
      }
    } else if (widget.task.isCompleted) {
      widget.task.isCompleted = false;
      widget.task.completedAt = null;
      needTaskSave = true;
    }

    if (needTaskSave) await widget.task.save();
    if (mounted) setState(() {});
  }

  void _deleteItem(int id) {
    setState(() {
      _items.removeWhere((i) => i['id'] == id);
    });
    _save();
  }

  void _clearCompleted() {
    setState(() {
      _items.removeWhere((item) => item['done'] == true);
    });
    if (widget.task.isCompleted && _items.isNotEmpty) {
      widget.task.isCompleted = false;
      widget.task.completedAt = null;
    }
    _save();
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShoppingSettingsSheet(
        task: widget.task,
        onSaved: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final checked = _items.where((i) => i['done'] == true).length;
    final total = _items.length;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.task.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            if (total > 0)
              Text(
                '$checked / $total',
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
              onPressed: _clearCompleted,
              icon: const Icon(Icons.cleaning_services_outlined, size: 18),
              label: Text(t.clearCompleted),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: t.editTask,
            onPressed: _showSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          if (total > 0)
            LinearProgressIndicator(
              value: checked / total,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: checked == total ? Colors.green : theme.colorScheme.primary,
              minHeight: 4,
            ),
          Expanded(
            child: total == 0
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t.addItem,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: _items.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _items.removeAt(oldIndex);
                        _items.insert(newIndex, item);
                      });
                      _save();
                    },
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final isDone = item['done'] as bool;
                      final itemId = item['id'] as int;
                      return Dismissible(
                        key: ValueKey('shopping_$itemId'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        onDismissed: (_) => _deleteItem(itemId),
                        child: ListTile(
                          key: ValueKey('tile_$itemId'),
                          leading: GestureDetector(
                            onTap: () => _toggleItem(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDone ? Colors.green : Colors.transparent,
                                border: Border.all(
                                  color: isDone ? Colors.green : theme.colorScheme.outline,
                                  width: 2,
                                ),
                              ),
                              child: isDone
                                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                                  : null,
                            ),
                          ),
                          title: Text(
                            item['text'] as String,
                            style: TextStyle(
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              color: isDone
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                                  : null,
                            ),
                          ),
                          trailing: const Icon(Icons.drag_handle, color: Colors.grey),
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
                    onSubmitted: (val) {
                      _addItem(val);
                      _addFocus.requestFocus();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    _addItem(_addController.text);
                    _addFocus.requestFocus();
                  },
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
  }
}

// ─── Settings sheet — отделен StatefulWidget за чисто lifecycle управление ────

class _ShoppingSettingsSheet extends StatefulWidget {
  final Task task;
  final VoidCallback onSaved;

  const _ShoppingSettingsSheet({required this.task, required this.onSaved});

  @override
  State<_ShoppingSettingsSheet> createState() => _ShoppingSettingsSheetState();
}

class _ShoppingSettingsSheetState extends State<_ShoppingSettingsSheet> {
  late TextEditingController _titleController;
  late DateTime _date;
  TimeOfDay? _time;
  late List<String> _reminders;
  late String _recurrence;

  @override
  void initState() {
    super.initState();
    final due = widget.task.dueDate;
    _titleController = TextEditingController(text: widget.task.title);
    _date = DateTime(due.year, due.month, due.day);
    _time = (due.hour != 0 || due.minute != 0)
        ? TimeOfDay(hour: due.hour, minute: due.minute)
        : null;
    _reminders = List<String>.from(widget.task.remindersList);
    _recurrence = widget.task.recurrence ?? 'none';
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _fmt2(int n) => n.toString().padLeft(2, '0');

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
        bottom: bottomInset + bottomPadding + 20,
      ),
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
            Text(
              t.editTask,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Заглавие
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: t.title,
                prefixIcon: const Icon(Icons.shopping_cart_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Дата
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

            // Час
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
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    )
                  : null,
              theme: theme,
            ),
            const SizedBox(height: 16),
            Text(t.repeat, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _RecurrenceChip(label: t.none2,   value: 'none',    selected: _recurrence == 'none',    accent: theme.colorScheme.primary, onTap: () => setState(() => _recurrence = 'none')),
              _RecurrenceChip(label: t.daily,   value: 'daily',   selected: _recurrence == 'daily',   accent: theme.colorScheme.primary, onTap: () => setState(() => _recurrence = 'daily')),
              _RecurrenceChip(label: t.weekly,  value: 'weekly',  selected: _recurrence == 'weekly',  accent: theme.colorScheme.primary, onTap: () => setState(() => _recurrence = 'weekly')),
              _RecurrenceChip(label: t.monthly, value: 'monthly', selected: _recurrence == 'monthly', accent: theme.colorScheme.primary, onTap: () => setState(() => _recurrence = 'monthly')),
              _RecurrenceChip(label: t.yearly,  value: 'yearly',  selected: _recurrence == 'yearly',  accent: theme.colorScheme.primary, onTap: () => setState(() => _recurrence = 'yearly')),
            ]),
            const SizedBox(height: 20),

            // Напомняния
            Text(
              t.reminders,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            ReminderSelector(
              selectedReminders: _reminders,
              onChanged: (list) => setState(() => _reminders = list),
              langCode: langCode,
              theme: theme,
            ),
            const SizedBox(height: 24),

            // Запази
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final title = _titleController.text.trim();
                  if (title.isEmpty) return;
                  final newDate = DateTime(
                    _date.year, _date.month, _date.day,
                    _time?.hour ?? 0, _time?.minute ?? 0,
                  );
                  widget.task.title = title;
                  widget.task.dueDate = newDate;
                  widget.task.setReminders(_reminders);
                  widget.task.recurrence = _recurrence == 'none' ? null : _recurrence;
                  final nav = Navigator.of(context);
                  await widget.task.save();
                  await NotificationService().scheduleForTask(widget.task);
                  widget.onSaved();
                  if (mounted) nav.pop();
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
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

class _RecurrenceChip extends StatelessWidget {
  final String label, value; final bool selected; final Color accent; final VoidCallback onTap;
  const _RecurrenceChip({required this.label, required this.value, required this.selected, required this.accent, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: selected ? accent.withValues(alpha: 0.15) : Colors.transparent,
        border: Border.all(color: selected ? accent : Colors.grey.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
        color: selected ? accent : Colors.grey))));
}
