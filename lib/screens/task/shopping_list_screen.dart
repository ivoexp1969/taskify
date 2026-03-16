import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../models/task.dart';
import '../../utils/localization.dart';

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
    final task = Task(
      title: t.shoppingList,
      dueDate: DateTime.now(),
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
    _items = List<Map<String, dynamic>>.from(widget.task.subtasksList);
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
      _items.add({'done': false, 'text': trimmed});
    });
    _addController.clear();
    _save();
  }

  void _toggleItem(int index) {
    setState(() {
      _items[index]['done'] = !(_items[index]['done'] as bool);
    });
    _save();
  }

  void _deleteItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
    _save();
  }

  void _clearCompleted() {
    setState(() {
      _items.removeWhere((item) => item['done'] == true);
    });
    _save();
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
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
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
        ],
      ),
      body: Column(
        children: [
          // Лента за прогрес
          if (total > 0)
            LinearProgressIndicator(
              value: total == 0 ? 0 : checked / total,
              backgroundColor: theme.colorScheme.surfaceVariant,
              color: Colors.green,
              minHeight: 4,
            ),

          // Списък с артикули
          Expanded(
            child: total == 0
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurface.withOpacity(0.2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t.addItem,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
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
                      return Dismissible(
                        key: ValueKey('item_${index}_${item['text']}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        onDismissed: (_) => _deleteItem(index),
                        child: ListTile(
                          key: ValueKey('tile_${index}_${item['text']}'),
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
                                  ? theme.colorScheme.onSurface.withOpacity(0.4)
                                  : null,
                            ),
                          ),
                          trailing: const Icon(Icons.drag_handle, color: Colors.grey),
                        ),
                      );
                    },
                  ),
          ),

          // Поле за добавяне
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
                  color: Colors.black.withOpacity(0.06),
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
                      fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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