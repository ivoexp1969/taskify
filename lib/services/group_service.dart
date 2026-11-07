import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/group.dart';
import '../utils/uuid.dart';
import 'auth_service.dart';

/// Кодове за грешки → UI ги локализира (виж AppText.groupError...).
class GroupException implements Exception {
  final String code;
  GroupException(this.code);
  @override
  String toString() => 'GroupException($code)';
}

/// Меки лимити срещу злоупотреба (проверяват се и тук, и в firestore.rules).
class GroupLimits {
  static const int maxGroupsAsOwner = 10;
  static const int maxMembers = 20;
  static const int maxActiveTasks = 500;
  static const int inviteCodeLength = 8;
}

/// Слой за СПОДЕЛЕНИ групи — отделен от личния merge sync (sync_service.dart).
/// Живее само във Firestore (real-time snapshots + вградена offline persistence),
/// БЕЗ Hive дублиране. Server timestamps (часовниците на членовете не са доверени).
class GroupService {
  GroupService._internal();
  static final GroupService _instance = GroupService._internal();
  factory GroupService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');
  CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection('invites');
  CollectionReference<Map<String, dynamic>> _tasksRef(String groupId) =>
      _groups.doc(groupId).collection('tasks');

  // Crockford base32 без двусмислени знаци (без I, L, O, U).
  static const String _codeAlphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  final Random _rng = Random.secure();

  String _genCode() {
    final buf = StringBuffer();
    for (var i = 0; i < GroupLimits.inviteCodeLength; i++) {
      buf.write(_codeAlphabet[_rng.nextInt(_codeAlphabet.length)]);
    }
    return buf.toString();
  }

  /// Минимална member-информация за текущия потребител (от Auth).
  Map<String, dynamic> _selfInfo() {
    final u = _auth.currentUser;
    return {
      if (u?.displayName != null && u!.displayName!.trim().isNotEmpty)
        'name': u.displayName,
      if (u?.email != null) 'email': u!.email,
    };
  }

  // ─────────────────────────── ЧЕТЕНЕ (REAL-TIME) ───────────────────────────

  /// Групите, в които текущият потребител членува — на живо.
  Stream<List<Group>> watchMyGroups() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _groups
        .where('members', arrayContains: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(Group.fromDoc).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  /// Една група на живо (за заглавие/членове, докато сме вътре).
  Stream<Group?> watchGroup(String groupId) {
    return _groups.doc(groupId).snapshots().map(
          (doc) => doc.exists ? Group.fromDoc(doc) : null,
        );
  }

  /// Задачите на групата — на живо. Tombstone-ите (deleted==true) се пазят в
  /// облака, но се филтрират тук. Подредба: незавършени първи, после по срок.
  Stream<List<GroupTask>> watchTasks(String groupId) {
    return _tasksRef(groupId).snapshots().map((snap) {
      final list = snap.docs
          .map(GroupTask.fromDoc)
          .where((t) => !t.deleted)
          .toList();
      list.sort((a, b) {
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        return a.dueDate.compareTo(b.dueDate);
      });
      return list;
    });
  }

  /// Проверка за реална връзка със сървъра (за преместване — точка 2: личната
  /// задача се трие САМО след сървърно потвърждение). `Source.server` хвърля
  /// `unavailable` при офлайн (за разлика от обикновен `.get()`, който връща кеш).
  Future<void> pingServerForGroup(String groupId) async {
    await _groups.doc(groupId).get(const GetOptions(source: Source.server));
  }

  /// Една задача на живо (за груповия „Списък за пазаруване" екран). Връща null,
  /// ако документът е изтрит или tombstone-нат (друг член го е махнал).
  Stream<GroupTask?> watchTask(String groupId, String taskId) {
    return _tasksRef(groupId).doc(taskId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final t = GroupTask.fromDoc(doc);
      return t.deleted ? null : t;
    });
  }

  // ─────────────────────────── ГРУПИ: ЖИЗНЕН ЦИКЪЛ ──────────────────────────

  /// Създава група (PREMIUM gating е в UI). Връща новата група с inviteCode.
  Future<Group> createGroup(String name) async {
    final uid = _uid;
    if (uid == null) throw GroupException('not-signed-in');

    // Лимит: макс. групи като owner. ВАЖНО: rules пускат четене на групи само по
    // `members` (не по `ownerId`) → заявка where('ownerId'==uid) би дала
    // permission-denied. Затова четем моите групи (members arrayContains) и
    // броим клиентски тези, на които съм owner.
    final mine = await _groups.where('members', arrayContains: uid).get();
    final ownedCount =
        mine.docs.where((d) => d.data()['ownerId'] == uid).length;
    if (ownedCount >= GroupLimits.maxGroupsAsOwner) {
      throw GroupException('owner-limit');
    }

    // Уникален код (ретрай при колизия).
    String code = _genCode();
    for (var attempt = 0; attempt < 5; attempt++) {
      final exists = await _invites.doc(code).get();
      if (!exists.exists) break;
      code = _genCode();
    }

    final groupRef = _groups.doc();
    final batch = _db.batch();
    batch.set(groupRef, {
      'name': name.trim(),
      'ownerId': uid,
      'members': [uid],
      'memberInfo': {uid: _selfInfo()},
      'inviteCode': code,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_invites.doc(code), {
      'groupId': groupRef.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    return Group(
      id: groupRef.id,
      name: name.trim(),
      ownerId: uid,
      members: [uid],
      memberInfo: {uid: GroupMember(uid: uid, name: _auth.currentUser?.displayName, email: _auth.currentUser?.email)},
      inviteCode: code,
    );
  }

  /// Присъединяване с код (БЕЗПЛАТНО за всеки логнат). Връща името на групата.
  Future<String> joinByCode(String rawCode) async {
    final uid = _uid;
    if (uid == null) throw GroupException('not-signed-in');

    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) throw GroupException('invalid-code');

    final inviteDoc = await _invites.doc(code).get();
    if (!inviteDoc.exists) throw GroupException('invalid-code');
    final groupId = inviteDoc.data()?['groupId'] as String?;
    if (groupId == null) throw GroupException('invalid-code');

    final groupRef = _groups.doc(groupId);
    try {
      // Не-член НЕ може да чете групата, но МОЖЕ да се добави сам (rules:
      // addsOnlySelf). Лимитът за членове се налага от rules → permission-denied.
      await groupRef.update({
        'members': FieldValue.arrayUnion([uid]),
        'memberInfo.$uid': _selfInfo(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Най-вероятно лимитът за членове е достигнат.
        throw GroupException('member-limit');
      }
      rethrow;
    }

    // Вече сме член → можем да прочетем името.
    final group = await groupRef.get();
    return (group.data()?['name'] as String?)?.trim() ?? '';
  }

  /// Обновява `memberInfo` (име/имейл) на текущия потребител във ВСИЧКИ негови групи —
  /// напр. след смяна на името за показване в Настройки. Безопасно е, ако няма групи.
  Future<void> syncMyMemberInfo() async {
    final uid = _uid;
    if (uid == null) return;
    final snap = await _groups.where('members', arrayContains: uid).get();
    for (final d in snap.docs) {
      try {
        await d.reference.update({
          'memberInfo.$uid': _selfInfo(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {/* напр. permission — пропусни тихо */}
    }
  }

  /// Член напуска групата сам (без изтриване на групата).
  Future<void> leaveGroup(String groupId) async {
    final uid = _uid;
    if (uid == null) throw GroupException('not-signed-in');
    await _groups.doc(groupId).update({
      'members': FieldValue.arrayRemove([uid]),
      'memberInfo.$uid': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Owner изтрива групата — заедно с всичките ѝ задачи и поканата.
  Future<void> deleteGroup(String groupId) async {
    final uid = _uid;
    if (uid == null) throw GroupException('not-signed-in');

    final groupRef = _groups.doc(groupId);
    final groupDoc = await groupRef.get();
    final code = groupDoc.data()?['inviteCode'] as String?;

    // Изтрий задачите на партиди (Firestore batch ≤ 500).
    while (true) {
      final snap = await _tasksRef(groupId).limit(400).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      if (snap.docs.length < 400) break;
    }

    final batch = _db.batch();
    if (code != null) batch.delete(_invites.doc(code));
    batch.delete(groupRef);
    await batch.commit();
  }

  // ─────────────────────────── ЗАДАЧИ: CRUD ─────────────────────────────────

  Map<String, dynamic> _taskToMap(GroupTask t) => {
        'title': t.title,
        'dueDate': t.dueDate.toIso8601String(),
        'categoryName': t.categoryName,
        'priority': t.priority,
        'recurrence': t.recurrence,
        'reminders': t.reminders,
        'subtasks': t.subtasks,
        'notes': t.notes,
        'isCompleted': t.isCompleted,
        'template': t.template,
        'reminderSetBy': t.reminderSetBy,
        'remindAll': t.remindAll,
      };

  /// Сериализира продуктите към map по id (за shopping задачи при създаване).
  Map<String, dynamic> _itemsToMap(List<ShoppingItem> items) {
    final m = <String, dynamic>{};
    for (final it in items) {
      m[it.id] = it.toMap();
    }
    return m;
  }

  /// Добавя нова задача към групата. Лимит: макс. активни задачи. Ако задачата е
  /// shopping с продукти ([GroupTask.items]), записва и map-а `items`.
  ///
  /// ВАЖНО (точка 2, преместване): Firestore write Future-ите се resolve-ват чак
  /// при СЪРВЪРНО потвърждение (офлайн увисват) → викащият може да `await` този
  /// метод и чак при успех да трие личната задача. Викащият подсигурява онлайн
  /// чрез пред-проверка + timeout.
  Future<String> addTask(String groupId, GroupTask t) async {
    final uid = _uid;
    if (uid == null) throw GroupException('not-signed-in');

    final active = await _tasksRef(groupId)
        .where('deleted', isEqualTo: false)
        .count()
        .get();
    if ((active.count ?? 0) >= GroupLimits.maxActiveTasks) {
      throw GroupException('task-limit');
    }

    final ref = await _tasksRef(groupId).add({
      ..._taskToMap(t),
      if (t.items != null) 'items': _itemsToMap(t.items!),
      'createdBy': uid,
      'completedBy': null,
      'completedAt': null,
      'deleted': false,
      'deletedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Редакция на съществуваща задача. НЕ пипа `deleted` (delete бие edit) и НЕ
  /// пипа `items` (те се менажират през item-операциите по-долу → редакция на
  /// заглавие/дата/напомняне не трие продуктите).
  Future<void> updateTask(String groupId, String taskId, GroupTask t) async {
    await _tasksRef(groupId).doc(taskId).update({
      ..._taskToMap(t),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ───────────────── SHOPPING ПРОДУКТИ (map по id, field-path) ───────────────
  // Всяка операция пипа САМО своето вложено поле (`items.<id>...`) → едновременни
  // отметки на различни продукти от различни членове се merge-ват без overwrite.

  /// Отмята/размаркира продукт. Пази КОЙ го е отметнал (за „Купено от X").
  Future<void> toggleItem(
      String groupId, String taskId, String itemId, bool checked) async {
    final uid = _uid;
    await _tasksRef(groupId).doc(taskId).update({
      'items.$itemId.checked': checked,
      'items.$itemId.checkedBy': checked ? uid : null,
      'items.$itemId.checkedAt':
          checked ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Добавя нов продукт. Връща новото id. `order` = текущо време (край на списъка).
  Future<String> addItem(String groupId, String taskId, String text,
      {int qty = 1}) async {
    final id = Uuid.v4();
    await _tasksRef(groupId).doc(taskId).update({
      'items.$id.text': text.trim(),
      'items.$id.checked': false,
      'items.$id.checkedBy': null,
      'items.$id.checkedAt': null,
      'items.$id.qty': qty,
      'items.$id.order': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  /// Трие продукт (цялото вложено поле `items.<id>`).
  Future<void> removeItem(
      String groupId, String taskId, String itemId) async {
    await _tasksRef(groupId).doc(taskId).update({
      'items.$itemId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Трие всички отметнати продукти наведнъж (едно update с няколко delete-а).
  Future<void> clearCheckedItems(
      String groupId, String taskId, List<String> checkedIds) async {
    if (checkedIds.isEmpty) return;
    final patch = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    for (final id in checkedIds) {
      patch['items.$id'] = FieldValue.delete();
    }
    await _tasksRef(groupId).doc(taskId).update(patch);
  }

  /// Маркира/размаркира завършена. Пази КОЙ я е завършил (за индикатора).
  Future<void> toggleComplete(
      String groupId, String taskId, bool completed) async {
    final uid = _uid;
    await _tasksRef(groupId).doc(taskId).update({
      'isCompleted': completed,
      'completedBy': completed ? uid : null,
      'completedAt': completed ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Tombstone изтриване — записът се пази (deleted=true), за да не „възкръсва"
  /// и изтриването да бие конкурентна редакция.
  Future<void> deleteTask(String groupId, String taskId) async {
    await _tasksRef(groupId).doc(taskId).update({
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Текст за споделяне на поканата (виж share_plus в UI).
  static String shareText(String groupName, String code, String lang) {
    // Лендингът — официалният домейн на Taskify.
    const landing = 'https://taskify1969.com';
    final templates = <String, String>{
      'en': "Join the list '$groupName' in Taskify with code: $code\n$landing", 'nl': 'Word lid van de lijst \'$groupName\' in Taskify met code: $code\n$landing', 'uk': 'Приєднайтесь до списку «$groupName» у Taskify за кодом: $code\n$landing',
      'bg': "Присъедини се към списъка '$groupName' в Taskify с код: $code\n$landing",
      'de': "Tritt der Liste '$groupName' in Taskify bei mit Code: $code\n$landing",
      'fr': "Rejoins la liste '$groupName' dans Taskify avec le code : $code\n$landing",
      'it': "Unisciti alla lista '$groupName' in Taskify con il codice: $code\n$landing",
      'el': "Μπες στη λίστα '$groupName' στο Taskify με τον κωδικό: $code\n$landing",
      'es': "Únete a la lista '$groupName' en Taskify con el código: $code\n$landing",
      'pt': "Junta-te à lista '$groupName' no Taskify com o código: $code\n$landing",
      'ru': "Присоединяйся к списку '$groupName' в Taskify по коду: $code\n$landing",
      'tr': "Taskify'da '$groupName' listesine şu kodla katıl: $code\n$landing",
      'ja': "Taskifyのリスト「$groupName」にコードで参加：$code\n$landing",
    };
    return templates[lang] ?? templates['en']!;
  }
}
