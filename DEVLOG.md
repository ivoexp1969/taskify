# DEVLOG

Shared session log across machines (PC = Android, Mac = iOS). **Newest first.**
One short entry per session: date · machine · what · version · key commits.
Pull before you start, push (incl. this file) when you finish. See `CLAUDE.md` → Cross-Machine Workflow.

---

## 2026-06-12 · PC (Android) — bugfix follow-up
- **Documents delete → resurrection bug (fixed).** `documents_screen._confirmDelete`
  called raw `task.delete()`, skipping the tombstone. Since the doc-task had been pushed
  to Firestore, the next merge sync saw it still in the cloud with no tombstone and
  re-downloaded it → it "reappeared" at the bottom of the list after every delete.
  Fix: delete via `TombstoneService().deleteTask(task)` (records tombstone → deletion
  propagates to cloud, no resurrection). Caught live on Note 9 while preparing store
  screenshots. Verified: deleted doc stays gone across force-stop + relaunch (startup sync).
- Version → **1.0.42+46**.

---

## 2026-06-12 · PC (Android)
- **"Bulgaria" tab → universal "Documents" tab** (Pro-gated for everyone, 11 languages).
  The old BG-only section was really just expiring-document tracking; name days/holidays
  already live in Calendar, so the tab is now purely Documents.
- **Architecture:** documents are ordinary `Task`s (`template == 'document'`, category
  `documents`) instead of a separate store → they inherit Calendar sync, Today, cloud
  sync and statistics with zero extra plumbing. The old `bg_documents` Hive box and the
  Firestore `documents` subcollection are abandoned (upload/download paths removed).
- **New files:** `screens/documents/documents_screen.dart` (list + urgency colors + CRUD),
  `screens/task/document_dialog.dart` (type chips, optional name, expiry, yearly renewal,
  long-lead reminders).
- **Phase 1 – longer reminders:** `ReminderSelector` gained `availableKeys` (restrict shown
  options) + `longLeadLabels` (3d/1w/2w/1mo/2mo, 11 langs); `notification_service_mobile`
  schedules them; `google_calendar_service` maps the new tokens but skips 1/2-month (over
  GCal's 28-day = 40320-min override cap).
- **Phase 4 – migration:** `migrateDocumentsToTasks` (idempotent, flag
  `documents_to_tasks_migrated_v1`). Deterministic task id `doc_<docId>` so two devices
  merge (not duplicate) the same documents; cancels old per-doc notifications; ensures
  `documents` category; clears the old box afterwards.
- Category `documents` localized by id in task/calendar/settings/statistics screens.
- **Verified live on Note 9** over WiFi adb: `flutter analyze` 0 errors, release APK
  installed no-crash, full CRUD (add ID card → green urgency card → edit/delete menu →
  confirm), and confirmed the document is a real Task (count 361→362).
- Version → **1.0.41+45**. AAB to be built for Play Console (manual upload). New store
  screenshots (EN + BG) of the Documents tab to follow.

---

## 2026-06-11 · PC (Android)
- **Tickets card theme** finalized after on-device testing (Note 9): ticket stub now uses
  the **live category color** (not the template accent) so it matches the category and
  recolors instantly when a category color changes; neutral title text; expanded action
  buttons reflowed ("Done" full-width, Edit/Delete row) so labels stop truncating; stub
  time wrapped in `FittedBox` (was cutting "06:30" → "06:…").
- **Category localization**: localized ALL categories incl. the calendar category
  (`id == 'cal_events'`) in task/calendar/statistics/settings screens; completed the
  partial map in `calendar_screen` (was only work/personal/shopping).
- **Sentence-case keyboard** added to template dialogs (workout/meeting/travel/gift/
  payment/birthday); workout duration → numeric keyboard.
- Version → **1.0.40+44**. Commits: `a8c7a82` (feat) + `1a49377` (bump). AAB built for Play Console.
- Note: rebased on top of the Mac's `1.0.39+43` Apple Calendar work that was already on
  main — clean, no conflicts. (Reminder: pull --rebase first next time.)
- **Pending idea:** the "Bulgaria" tab is really just document-expiry tracking — a
  universal feature locked to BG+premium. Plan to surface it as a universal "Documents"
  tab in all languages (name days/holidays already live in Calendar).

## ~2026-06-09 · PC (Android)
- Two-way Google Calendar dedup overhaul (re-link on import, dedup by
  `googleCalendarEventId`, skip/clean native birthdays by `categoryId=='birthday'`);
  Settings cosmetics (client-tone subtitles, 11 langs); web SW auto-update; handwritten
  widget font (Caveat). Version 1.0.38+42.
