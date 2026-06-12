# Taskify - Flutter Task Management App

Indie Flutter app, Android-first, live on Google Play.
Repo: github.com/ivoexp1969/taskify

## Tech Stack
- Flutter (Dart)
- Hive — local database
- Firebase — backend services
- RevenueCat — subscriptions: premium_monthly, premium_yearly, premium_lifetime (14-day trial)
- AdMob — advertising
- Google Calendar API — bidirectional sync via OAuth

## Localization (11 languages)
bg (Bulgarian), en, de, fr, it, el (Greek), es, pt, ru, tr, ja (Japanese)

**CRITICAL:** Never hardcode user-facing text in Dart files.
Strings live in `lib/utils/localization.dart` as inline `AppText` getters using
`_t({'en': ..., 'bg': ..., ...})` — NOT `.arb` files. When adding a string, add all
11 language keys to the `_t({...})` map.

## UI Conventions
- `ExpandableTaskCard` is the standard task list widget (notes preview, overdue tinting, animated checkboxes, priority dots, subtask progress bars)
- Shopping-category tasks open a bottom sheet directly on tap — no card expansion
- Recurring task deletion uses a dialog: "delete current" / "delete all future"
- For Dismissible widgets, wrap state changes in `WidgetsBinding.instance.addPostFrameCallback` to avoid widget tree conflicts

## Build Environment
- JDK 17 required (Gradle)
- Android home screen widgets: 2x1 and 3x1 sizes
- Must support 16KB memory pages for Play Store

## Build Commands
```powershell
flutter clean
flutter pub get
flutter build apk --release
flutter build appbundle --release
```

## Promo Codes
- Firebase: `IVA` — lifetime access, 20-user cap

## Current Version
v1.0.42+46 (June 2026)

## Recent Work
Keep this current — it is the shared cross-machine context (see Cross-Machine Workflow). Newest first.
- **v1.0.42+46:** Bugfix — deleting a document in the Documents tab now goes through `TombstoneService().deleteTask()` instead of raw `task.delete()`; without the tombstone the merge sync re-downloaded the doc from the cloud so it "resurrected" at the bottom of the list. Caught live on Note 9. (Reminder: `TombstoneService.deleteTask` is the ONLY correct way to delete any task.)
- **v1.0.41+45:** "Bulgaria" tab replaced by a universal **"Documents"** tab (Pro-gated for everyone, all 11 languages) for expiring-document tracking (ID, passport, license, insurance, inspection, vignette, other). Documents are now ordinary tasks (`template == 'document'`, category `documents`) → they get Calendar/Today/cloud-sync/statistics for free; the separate `bg_documents` Hive box + Firestore `documents` subcollection are abandoned. New `DocumentDialog` (long-lead reminders: 3d/1w/2w/1mo/2mo, optional yearly renewal). `ReminderSelector` gained `availableKeys` + `longLeadLabels`; GCal maps the new tokens (1/2-month skipped past GCal's 28-day cap). Idempotent migration `migrateDocumentsToTasks` (deterministic `doc_<id>` for cross-device merge, cancels old doc notifications, clears old box). Category `documents` localized in task/calendar/settings/statistics. Verified live on Note 9 (full CRUD).
- **v1.0.40+44:** Optional "Tickets" task-card theme (Pro; Settings → Appearance) — `TaskCardView` switcher + `TicketTaskCard` (stub colored by the live category color, perforation, tear-to-complete). Localized ALL categories incl. calendar (`cal_events`) everywhere. Sentence-case keyboard in template dialogs.
- **v1.0.39+43 (Mac):** Apple Calendar moved to the merge architecture + unified radio source picker; Travel time/reset fixes.
- **v1.0.38+42:** Two-way Google Calendar dedup overhaul (re-link on import, dedup by `googleCalendarEventId`, skip native birthdays); Settings cosmetics; web SW auto-update; handwritten widget font (Caveat).
- **iOS exploration:** removed `cloud_firestore` dependency for Xcode/Firebase compatibility on native iOS build

## Working Style
- Communicate in Bulgarian
- **Do everything yourself, end-to-end** — edit files, build, and install wirelessly on
  the phone via adb over WiFi; don't hand the user commands to run. Only ask the user to
  run something when it genuinely requires him (interactive login, physical action, a decision).
- User edits no files manually
- Verify every code/script at least 3 times before delivering: (1) bracket/parenthesis count, (2) pattern match against actual file content, (3) logical correctness check
- No assumptions, no hallucinations — only verified facts
- Keep responses concise, no filler
- Settings persist in **SharedPreferences**, not Hive (Hive is for tasks/categories)

## Cross-Machine Workflow (two machines, one repo)
Work happens with Claude Code on **two machines via the same GitHub repo**:
- **PC (Windows)** — Android version; adb to Note 9 over WiFi.
- **Mac** — iOS version (Xcode/IPA builds).
Claude's auto-memory is **local per machine and does NOT sync** — so this repo is the
single shared source of truth across machines. Therefore:
- **Start of every session, every machine:** `git pull --rebase origin main` BEFORE doing
  anything (the other machine may have pushed — e.g. the Mac's Apple Calendar work).
- **End of every session:** commit + push.
- Keep the **Current Version**, **Recent Work** (above) and **`DEVLOG.md`** updated and
  committed — that is how the other machine's Claude learns what was done here.
- Commit messages: NO "Co-Authored-By: Claude" / no AI attribution (user's standing rule).

## Monetization Context
Actively seeking realistic revenue opportunities — assist proactively across:
- Taskify (subscriptions, ads, premium features)
- Facebook group "УМОПОМРАЧИТЕЛНИ БАЛАДИ" (197,000+ members)
