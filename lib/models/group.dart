import 'package:cloud_firestore/cloud_firestore.dart';

import 'task.dart';
import '../utils/subtask_format.dart';

/// Минимална информация за член на група (за екрана „Членове").
/// Пазим само онова, което Auth ни дава и е нужно за показване — без излишни лични данни.
class GroupMember {
  final String uid;
  final String? name;
  final String? email;

  const GroupMember({required this.uid, this.name, this.email});

  /// Името за показване: displayName → имейл → съкратен uid.
  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    if (email != null && email!.trim().isNotEmpty) return email!.trim();
    return uid.length > 6 ? '${uid.substring(0, 6)}…' : uid;
  }

  /// Инициали за компактния индикатор „завършена от …".
  String get initials {
    final base = displayName;
    final parts = base.split(RegExp(r'[\s@.]+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Map<String, dynamic> toMap() => {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
      };
}

/// Споделена група (контейнер). Споделя се ГРУПАТА, не отделна задача —
/// всички членове виждат и редактират всичко в нея.
class Group {
  final String id;
  final String name;
  final String ownerId;
  final List<String> members;
  final Map<String, GroupMember> memberInfo;
  final String? inviteCode;

  const Group({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.members,
    required this.memberInfo,
    this.inviteCode,
  });

  bool isOwner(String uid) => uid == ownerId;

  int get memberCount => members.length;

  GroupMember memberFor(String uid) =>
      memberInfo[uid] ?? GroupMember(uid: uid);

  List<GroupMember> get sortedMembers {
    final list = members.map(memberFor).toList();
    // Owner-ът първи, после по име.
    list.sort((a, b) {
      if (a.uid == ownerId) return -1;
      if (b.uid == ownerId) return 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return list;
  }

  factory Group.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawInfo = (data['memberInfo'] as Map<String, dynamic>?) ?? {};
    final info = <String, GroupMember>{};
    rawInfo.forEach((uid, value) {
      final m = (value as Map<String, dynamic>?) ?? {};
      info[uid] = GroupMember(
        uid: uid,
        name: m['name'] as String?,
        email: m['email'] as String?,
      );
    });
    return Group(
      id: doc.id,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String)
          : '—',
      ownerId: data['ownerId'] as String? ?? '',
      members: (data['members'] as List<dynamic>?)?.cast<String>() ?? const [],
      memberInfo: info,
      inviteCode: data['inviteCode'] as String?,
    );
  }
}

/// Един продукт в споделен „Списък за пазаруване" (точка 1, v1.0.72).
///
/// ★Пази се като MAP по id върху документа на задачата (`items.<id>`), НЕ в
/// масив★ — за да може Firestore field-path update (`items.<id>.checked`) да
/// merge-ва едновременни отметки на РАЗЛИЧНИ продукти от различни членове без
/// overwrite. Масив би изисквал презапис на целия списък → загуба на отметки.
class ShoppingItem {
  final String id;
  final String text;
  final bool checked;
  final String? checkedBy; // uid на отметналия — за „Купено от X"
  final DateTime? checkedAt;
  final int qty;
  final int order; // map не пази ред → подреждаме по това поле

  const ShoppingItem({
    required this.id,
    required this.text,
    this.checked = false,
    this.checkedBy,
    this.checkedAt,
    this.qty = 1,
    this.order = 0,
  });

  factory ShoppingItem.fromMap(String id, Map<String, dynamic> m) {
    return ShoppingItem(
      id: id,
      text: m['text'] as String? ?? '',
      checked: m['checked'] as bool? ?? false,
      checkedBy: m['checkedBy'] as String?,
      checkedAt: GroupTask._ts(m['checkedAt']),
      qty: (m['qty'] as num?)?.toInt() ?? 1,
      order: (m['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'text': text,
        'checked': checked,
        'checkedBy': checkedBy,
        'checkedAt': checkedAt?.toIso8601String(),
        'qty': qty,
        'order': order,
      };
}

/// Една задача в споделена група. Живее само във Firestore (без Hive).
/// Категорията се пази като ТЕКСТ (`categoryName`) — категориите са лични за
/// всеки потребител, затова без реф. и без цветова гаранция между членовете.
class GroupTask {
  final String id;
  final String title;
  final DateTime dueDate;
  final String? categoryName;
  final int priority;
  final String? recurrence;
  final List<String>? reminders;
  final List<String>? subtasks;
  final String? notes;
  final bool isCompleted;
  final String? completedBy; // uid
  final DateTime? completedAt;
  final String? createdBy; // uid
  final DateTime? updatedAt; // сървърен timestamp
  final bool deleted;
  final DateTime? deletedAt;

  /// Вид на задачата: null = нормална; 'shopping' = списък за пазаруване
  /// (продуктите са в [items], а не в [subtasks]).
  final String? template;

  /// Продуктите на shopping списък (map по id). null за нормална задача.
  /// Подреден по `order` в [fromDoc].
  final List<ShoppingItem>? items;

  /// Кой е ЗАДАЛ напомнянията (uid). Напомнянето звъни ЛОКАЛНО само на неговото
  /// устройство (точка 3, v1.0.72), освен ако [remindAll] е true.
  final String? reminderSetBy;

  /// true = напомнянето да звъни на ВСИЧКИ членове (опция на задачата).
  final bool remindAll;

  const GroupTask({
    required this.id,
    required this.title,
    required this.dueDate,
    this.categoryName,
    this.priority = 1,
    this.recurrence,
    this.reminders,
    this.subtasks,
    this.notes,
    this.isCompleted = false,
    this.completedBy,
    this.completedAt,
    this.createdBy,
    this.updatedAt,
    this.deleted = false,
    this.deletedAt,
    this.template,
    this.items,
    this.reminderSetBy,
    this.remindAll = false,
  });

  bool get isShopping => template == 'shopping';

  /// Има ли реален map с продукти (стари shopping задачи без `items` → false
  /// → показваме ги като нормална карта, не празен списък — изискване 1.0.72).
  bool get hasItems => items != null && items!.isNotEmpty;

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static List<ShoppingItem>? _parseItems(dynamic raw) {
    if (raw is! Map) return null;
    final list = <ShoppingItem>[];
    raw.forEach((key, value) {
      if (value is Map) {
        list.add(ShoppingItem.fromMap(
            key.toString(), Map<String, dynamic>.from(value)));
      }
    });
    // Подреждаме по order, после по текст — map не гарантира ред.
    list.sort((a, b) {
      final c = a.order.compareTo(b.order);
      return c != 0 ? c : a.text.toLowerCase().compareTo(b.text.toLowerCase());
    });
    return list;
  }

  factory GroupTask.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return GroupTask(
      id: doc.id,
      title: data['title'] as String? ?? '',
      dueDate: _ts(data['dueDate']) ?? DateTime.now(),
      categoryName: data['categoryName'] as String?,
      priority: data['priority'] as int? ?? 1,
      recurrence: data['recurrence'] as String?,
      reminders: (data['reminders'] as List<dynamic>?)?.cast<String>(),
      subtasks: (data['subtasks'] as List<dynamic>?)?.cast<String>(),
      notes: data['notes'] as String?,
      isCompleted: data['isCompleted'] as bool? ?? false,
      completedBy: data['completedBy'] as String?,
      completedAt: _ts(data['completedAt']),
      createdBy: data['createdBy'] as String?,
      updatedAt: _ts(data['updatedAt']),
      deleted: data['deleted'] as bool? ?? false,
      deletedAt: _ts(data['deletedAt']),
      template: data['template'] as String?,
      items: _parseItems(data['items']),
      reminderSetBy: data['reminderSetBy'] as String?,
      remindAll: data['remindAll'] as bool? ?? false,
    );
  }

  int get checkedItemsCount =>
      items?.where((i) => i.checked).length ?? 0;
  int get totalItemsCount => items?.length ?? 0;

  /// Транзитен [Task] обект само за визуализация през `TaskCardView`
  /// (преизползва съществуващите карти, вкл. „Билети" темата). НЕ се пази в Hive.
  /// `categoryId` нарочно е неутрален ('shared') — да не задейства shopping
  /// bottom-sheet поведението на личните карти.
  Task toDisplayTask() {
    // За shopping задача с продукти показваме прогреса на продуктите в картата
    // (прогрес-лента „отметнати/общо") чрез subtasks на транзитния Task.
    final displaySubtasks = hasItems
        ? items!
            .map((i) => SubtaskCodec.format(
                done: i.checked, qty: i.qty, text: i.text))
            .toList()
        : subtasks;
    final t = Task(
      title: title,
      dueDate: dueDate,
      categoryId: 'shared',
      priority: priority,
      recurrence: recurrence,
      reminders: reminders,
      subtasks: displaySubtasks,
      notes: notes,
      id: id,
      updatedAt: updatedAt,
    );
    t.isCompleted = isCompleted;
    t.completedAt = completedAt;
    return t;
  }
}
