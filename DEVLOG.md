# DEVLOG

Shared session log across machines (PC = Android, Mac = iOS). **Newest first.**
One short entry per session: date · machine · what · version · key commits.
Pull before you start, push (incl. this file) when you finish. See `CLAUDE.md` → Cross-Machine Workflow.

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
