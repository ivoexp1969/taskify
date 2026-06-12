# DEVLOG

Shared session log across machines (PC = Android, Mac = iOS). **Newest first.**
One short entry per session: date · machine · what · version · key commits.
Pull before you start, push (incl. this file) when you finish. See `CLAUDE.md` → Cross-Machine Workflow.

---

## 2026-06-12 · Mac (iOS) — feature parity + App Store 1.0.43
- **Pulled PC work** (Documents tab, Tickets card theme, doc-out-of-list) and brought iOS to
  parity — all shared Dart, built & verified on Toto (iPhone 13 Pro) over devicectl. AdMob iOS
  IDs, RevenueCat iOS key and the iOS `TaskifyWidget` extension confirmed real (old "placeholder"
  notes were stale).
- **Calendar description cleanup (BOTH platforms):** new `utils/calendar_notes.dart`
  `cleanCalendarNotes()` strips internal `key:value` metadata (`doctype:`, `dest:`, `with:`,
  `amount:`…) from `task.notes` before it's used as the Apple/Google calendar event description —
  fixes the metadata leak flagged in the previous PC entry. Wired into `ios_calendar_service`
  + `google_calendar_service`.
- **More category colors:** unified the 3 duplicated `_categoryColors` palettes (settings/
  calendar/task) into one shared `utils/category_colors.dart` (`kCategoryColors`) and added ~17
  bright/vivid (accent/neon) colors.
- **App Store:** built IPA (Xcode 26) → uploaded → version 1.0.43 created, whatsNew (en-US),
  build attached, submitted for review. Live store version was 1.0.39 (approved). Version → **1.0.43+48**.

---

## 2026-06-12 · PC → for the Mac: iOS-readiness review of the Documents feature
Pre-flight review done on Windows before the iOS update. Documents/Tickets/fixes are
all shared Dart — iOS just needs `pull --rebase` + build on the Mac. Findings:
- **Notifications ✅** — `notification_service.dart` exports `_mobile` for `dart.library.io`,
  so iOS uses the SAME file; the new long-lead tokens (`minus_3d…minus_2mo`) schedule on
  iOS too. ⚠️ Heads-up: iOS caps pending local notifications at **64** — many documents ×
  up to 5 reminders each could hit it (pre-existing concern, now heavier).
- **Cloud ✅** — `cloud_firestore` is still in `pubspec` (^5.6.0); the old "removed for iOS"
  note was only an exploration, not on main. Documents ride the normal task sync and the
  separate `documents` Firestore subcollection was REMOVED → smaller cloud surface, no new
  iOS risk. (The Firebase/CocoaPods Xcode pain is a build-env issue, unrelated to Documents.)
- **No platform guards** in the new files (`documents_screen`, `document_dialog`,
  `migration_service` additions) — fully platform-agnostic. ✅
- **Delete is iOS-safe ✅** — `TombstoneService.deleteTask` → `IosCalendarService.deleteEventFor`
  is a null-safe no-op when `appleEventId == null` (catches errors, just debugPrint).
- ⚠️ **VERIFY on device (Mac):** `IosCalendarService.syncTask` has NO template filter, so a
  document task WILL export to Apple Calendar (like Google) on its expiry date. Two notes:
  (a) the event description = `task.notes` = `"doctype:passport\nlabel:…"` → technical
  metadata leaks into the calendar event text (this ALSO happens on Android/GCal today —
  candidate cleanup for BOTH platforms: strip `doctype:`/`label:` lines from the calendar
  description). (b) `DocumentDialog` save does NOT itself call Apple/Google calendar sync
  (only `scheduleForTask` + widget) → documents reach the calendar only via the central
  merge sync; confirm they actually show up.
- Build number **47** > last iOS upload (~+37) → fine for App Store Connect.

---

## 2026-06-12 · PC (Android) — docs out of main list
- **Documents hidden from the main Tasks list + Matrix.** Expiring-document tasks have
  far-future due dates (often a year+ out), so they piled up at the bottom of the active
  task list (sorted by date) and inflated the stat counts. Now `_computeTasks` filters
  `template != 'document'` at the source (excludes from both the list and the total/
  completed/overdue/upcoming counts), and `eisenhower_screen` excludes them too.
  Documents still live in the Documents tab + Calendar + scheduled reminders.
  User decision (asked on-device). Version → **1.0.43+47**.

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
