import sys

def norm(s):
    return s.replace('\r\n', '\n')

with open('lib/models/task.dart', 'r', encoding='utf-8') as f:
    content = norm(f.read())

old_task = "  List<Map<String, dynamic>> get subtasksList {\n    if (subtasks == null || subtasks!.isEmpty) return [];\n    return subtasks!.map((s) {\n      final parts = s.split(':');\n      final done = parts[0] == '1';\n      final text = parts.length > 1 ? parts.sublist(1).join(':') : '';\n      return {'done': done, 'text': text};\n    }).toList();\n  }\n\n  void setSubtasks(List<Map<String, dynamic>> list) {\n    subtasks = list.map((item) {\n      final done = item['done'] == true ? '1' : '0';\n      final text = item['text'] ?? '';\n      return '$done:$text';\n    }).toList();\n  }"
new_task = "  List<Map<String, dynamic>> get subtasksList {\n    if (subtasks == null || subtasks!.isEmpty) return [];\n    return subtasks!.map((s) {\n      final parts = s.split(':');\n      final done = parts[0] == '1';\n      int qty = 1;\n      String text = '';\n      if (parts.length >= 3) {\n        qty = int.tryParse(parts[1]) ?? 1;\n        text = parts.sublist(2).join(':');\n      } else if (parts.length == 2) {\n        text = parts[1];\n      }\n      return {'done': done, 'text': text, 'qty': qty};\n    }).toList();\n  }\n\n  void setSubtasks(List<Map<String, dynamic>> list) {\n    subtasks = list.map((item) {\n      final done = item['done'] == true ? '1' : '0';\n      final qty = (item['qty'] as int?) ?? 1;\n      final text = item['text'] ?? '';\n      return '$done:$qty:$text';\n    }).toList();\n  }"

print('task.dart match:', content.count(old_task))
if content.count(old_task) == 1:
    content = content.replace(old_task, new_task)
    with open('lib/models/task.dart', 'w', encoding='utf-8', newline='\n') as f:
        f.write(content)
    print('task.dart: FIXED')
else:
    sys.exit(1)

with open('lib/screens/task/task_screen.dart', 'r', encoding='utf-8') as f:
    content = norm(f.read())

old1 = "                          onTap: () {\n                            // Shopping List \u0441\u043f\u0435\u0446\u0438\u0430\u043b\u0435\u043d \u0435\u043a\u0440\u0430\u043d\n                            if (task.template == 'shopping') {\n                              Navigator.push(context, MaterialPageRoute(\n                                builder: (_) => ShoppingListScreen(task: task),\n                              )).then((_) => setState(() {}));\n                              return;\n                            }\n                          },"
new1 = "                          onTap: () {\n                            // Shopping List \u0441\u043f\u0435\u0446\u0438\u0430\u043b\u0435\u043d \u0435\u043a\u0440\u0430\u043d\n                            if (task.template == 'shopping') {\n                              ShoppingListScreen.show(context, task).then((_) => setState(() {}));\n                              return;\n                            }\n                          },"
old2 = "                                  if (task.template == 'shopping') {\n                                    Navigator.push(context, MaterialPageRoute(\n                                      builder: (_) => ShoppingListScreen(task: task),\n                                    )).then((_) => setState(() {}));\n                                  } else {"
new2 = "                                  if (task.template == 'shopping') {\n                                    ShoppingListScreen.show(context, task).then((_) => setState(() {}));\n                                  } else {"

c1, c2 = content.count(old1), content.count(old2)
print('task_screen match1:', c1, 'match2:', c2)
if c1 == 1 and c2 == 1:
    content = content.replace(old1, new1).replace(old2, new2)
    with open('lib/screens/task/task_screen.dart', 'w', encoding='utf-8', newline='\n') as f:
        f.write(content)
    print('task_screen.dart: FIXED')
else:
    sys.exit(1)

print('ALL DONE')
