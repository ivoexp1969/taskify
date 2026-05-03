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

## Localization (10 languages)
bg (Bulgarian), en, de, fr, it, el (Greek), es, pt, ru, tr

**CRITICAL:** All UI strings MUST use AppLocalizations.
NEVER hardcode user-facing text in Dart files.
When adding a new string, add the key to all 10 .arb files.

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
v1.0.20 (Feb 2026)

## Recent Work
- **v1.0.20:** Localization audit — fixed 27 hardcoded strings across 5 files, added 18 new keys; redesigned ExpandableTaskCard
- **v1.11:** Google Calendar bidirectional sync (OAuth + Google Cloud Console); rotating multilingual home-widget messages with emojis; Firebase promo `IVA`
- **iOS exploration:** removed `cloud_firestore` dependency for Xcode/Firebase compatibility on native iOS build

## Working Style
- Communicate in Bulgarian
- Provide ready-to-run PowerShell commands for all file edits — user does not edit files manually
- Verify every code/script at least 3 times before delivering: (1) bracket/parenthesis count, (2) pattern match against actual file content, (3) logical correctness check
- Test PowerShell logic mentally in bash before delivering
- No assumptions, no hallucinations — only verified facts
- Keep responses concise, no filler

## Monetization Context
Actively seeking realistic revenue opportunities — assist proactively across:
- Taskify (subscriptions, ads, premium features)
- Facebook group "УМОПОМРАЧИТЕЛНИ БАЛАДИ" (197,000+ members)
