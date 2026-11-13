import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/services/sync_service.dart';

/// Pins the 1.0.72 data-loss hotfix: the content/eventId dedup must NEVER remove
/// a user-created task, and a COMPLETED task must not act as a "magnet" that
/// gets a freshly-created duplicate deleted.
typedef Entry = ({String id, String? key, bool completed, bool removable});

void main() {
  group('SyncService.dedupVictimIds', () {
    test('(a) create X → complete → create X again → new one STAYS', () {
      // The old completed "Black Friday" (magnet) + a freshly created one, same
      // signature. Both are user-created.
      final victims = SyncService.dedupVictimIds(const [
        (id: 'old', key: 'black friday|20nov|events', completed: true, removable: false),
        (id: 'new', key: 'black friday|20nov|events', completed: false, removable: false),
      ]);
      expect(victims, isEmpty, reason: 'completed is not a magnet; user task never removed');
    });

    test('two ACTIVE user duplicates are both kept (never delete user data)', () {
      final victims = SyncService.dedupVictimIds(const [
        (id: 'a', key: 'sig', completed: false, removable: false),
        (id: 'b', key: 'sig', completed: false, removable: false),
      ]);
      expect(victims, isEmpty);
    });

    test('(c) a real calendar-import duplicate IS still deduped', () {
      final victims = SyncService.dedupVictimIds(const [
        (id: 'a', key: 'sig', completed: false, removable: true), // imported/legacy
        (id: 'b', key: 'sig', completed: false, removable: true),
      ]);
      expect(victims, ['b'], reason: 'survivor=min id (a); the imported dup (b) is tombstoned');
    });

    test('imported dup of a user task → only the imported one is removed', () {
      final victims = SyncService.dedupVictimIds(const [
        (id: 'a', key: 'sig', completed: false, removable: false), // user (min id, survivor)
        (id: 'b', key: 'sig', completed: false, removable: true), // imported dup
      ]);
      expect(victims, ['b']);
    });

    test('a completed task is excluded from grouping entirely', () {
      final victims = SyncService.dedupVictimIds(const [
        (id: 'done', key: 'sig', completed: true, removable: true),
        (id: 'active', key: 'sig', completed: false, removable: false),
      ]);
      expect(victims, isEmpty);
    });

    test('null/empty key never groups', () {
      final victims = SyncService.dedupVictimIds(const [
        (id: 'a', key: null, completed: false, removable: true),
        (id: 'b', key: '', completed: false, removable: true),
      ]);
      expect(victims, isEmpty);
    });
  });

  // NOTE (b) — widget: the "a widget key must not complete a NEW task" fix needs
  // native changes (the iOS AppIntent / Android provider must write task.id, not
  // the Hive key). Reported separately; not covered by this unit test.
}
