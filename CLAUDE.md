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

## Release Rule (ЗАДЪЛЖИТЕЛНО)
**Преди ВСЯКО качване в Google Play / App Store — изскачащ „Какво ново" диалог**, който излиза на
потребителите след ъпдейта (и Android, и iOS). Механизъм: `lib/widgets/whats_new_dialog.dart`
(`WhatsNewDialog.maybeShow`, flag `whats_new_seen_build`, веднъж за нов билд, НЕ за нови инсталации,
11 езика). **При всеки релийз: вдигни `_build` до новия build number + подмени точките `_items`**
(същите точки като `release_notes/<version>.md`). Потребителите не четат release notes в магазина —
без този диалог новите функции остават неоткрити.

## Current Version
**v1.0.57+67 (2026-08-07) — Споделените (групови) задачи в основния списък (Mac). iOS 1.0.57(67) е
`WAITING_FOR_REVIEW` (обновено и App Store **описание** EN+BG). Android 1.0.56+66 остава ЖИВА в Play
Production. Ново `widgets/shared_tasks_section.dart` (`SharedTasksSection`): обособена секция „Споделени"
НАЙ-ОТГОРЕ в `task_screen` (ListView index 0), показва днешните+просрочените (и завършени днес) групови
задачи от ВСИЧКИ групи наведнъж, всяка с етикет на групата; real-time (комбинира
`GroupService.watchMyGroups`→`watchTasks` per група, ръчен combineLatest с коректен dispose). Завършване=
`toggleComplete` (author-gated), отваряне→`GroupTasksScreen`. ★Моделите РАЗДЕЛЕНИ★ (лични Task/Hive vs
GroupTask/Firestore). Скрива се, ако няма групи/задачи. `analyze` 0, web+iOS build ✅.**
ПРЕДИШНО:
**v1.0.56+66 (2026-07-31) — Пакет 1: плътен таб Обучение. ★Android ЖИВА в Google Play Production 100%★
(качено 07-31 от PC чрез `tools/play_upload.py`, versionCode 66, заменя 1.0.54(64)). iOS 1.0.56(66) мина
ревю → READY_FOR_SALE. Реорганизиран `ModesScreen`: компактна Профил карта, countdown карта, „Днес"
разписание, днешни учебни задачи, предстоящи изпити. Уеднаквен термин → „Моето разписание". **PC добави:**
бутон „+" на всеки ден в `weekly_schedule_screen` + работна седмица Пн–Пт + умни начални часове. `analyze`
0, тестове 11 ✅. Note 9 без краш.**
### ⚠️ ANDROID TODO (PC) — за да настигне iOS 1.0.57 (Пакет 1 + Споделени в списъка):
1. `git pull --rebase origin main` — взима Пакет 1 + Споделени секция + вече bump-натата версия.
   **НЕ bump-вай пак** (`pubspec.yaml` вече е `1.0.57+67`; `whats_new_dialog._build`=`67`, 4 точки×11 ез.).
   Всичко е **чист cross-platform Dart** → важи 1:1 за Android без промени.
2. `flutter clean` — **ЗАДЪЛЖИТЕЛНО** (ръчен AndroidManifest, USE_FULL_SCREEN_INTENT; иначе кеширан merge).
3. `flutter pub get` → `flutter build appbundle --release` (JDK 17, targetSdk/compileSdk 36).
4. Провери merged manifest съдържа USE_FULL_SCREEN_INTENT (`build/app/intermediates/merged_manifests/`).
5. Качи AAB → **Play Console Production** (`tools/play_upload.py`), после `tools/play_promote.py`.
   Заменя живата 1.0.54(64). `release_notes/1.0.57.md` е готов. (Забележка: iOS 1.0.56 вече е READY_FOR_SALE.)
ПРЕДИШНО:
**v1.0.55+65 (July 2026) — Довършени 3-те отворени TODO по режим „Обучение": (1) валидация на
разписанието (без припокриващи се часове — `ScheduleSlot.overlaps`/`hasValidRange`, service
`firstConflict`, inline грешка в диалога, 11 ез.); (2) „Учебна програма" **по срокове (Ученик)/
семестри (Студент)** — ново поле `ScheduleSlot.term` (SharedPreferences JSON, БЕЗ Hive bump),
`SegmentedButton` в `weekly_schedule_screen`, вход = карта в таб Обучение; (3) ротатор на картата за
броене (Студент) — `_StudentCard` StatefulWidget, редува 4 най-близки дати (Timer 5s + AnimatedSwitcher
+ точки). Тестове **11 ✅**, analyze **0**. „Какво ново" `_build=65` + `release_notes/1.0.55.md`.
AAB билднат. ★Чист Dart → iOS=само Mac билд.★ ОСТАВА: качване в Play Console + Firestore НВО/ДЗИ дати.**
ПРЕДИШНО:
**v1.0.54+64 (July 2026) — Режими Обучение V1 (Ученик/Студент) + категория „🎒 Училище" (Mac,
качено production 100%, заменя 1.0.52). ПРЕДИШНО:
v1.0.52+62 — ЖИВА в Google Play Production (100%). ★КРАШ FIX★: `AndroidManifest.xml`
декларираше компоненти на `android_alarm_manager_plus` (AlarmService/AlarmBroadcastReceiver/
RebootBroadcastReceiver), а плъгинът НЕ е зависимост → липсващи класове → `ClassNotFoundException` при
`BOOT_COMPLETED` (5 потребители, билдове 54/55/57). Махнати. Крашовете се четат с нов
`tools/play_vitals.py` (Play Developer Reporting API).** ПРЕДИШНО:
**v1.0.51+61 (July 2026) — Widget „+" бързо добавяне + локален
контекст в widget-а (диференциаторът): изтичащ документ > имен ден > празник; при празен списък
контекстът заменя закачливата фраза. Уважава Pro + toggle-ите. Нов „Какво ново" диалог след ъпдейт
(11 ез.). Тествано на живо на Note 9. Качване: `tools/play_upload.py` (draft) + нов
`tools/play_promote.py` (промотира вече качен versionCode → 100% или staged). iOS остава на 1.0.50.**
ПРЕДИШНО:
**v1.0.50+60 (July 2026) — Картички за имен ден И рожден ден: бутон „Направи картичка" на картите отваря
уеб генератора с попълнено име — рожден ден → `/rozhden-den/` (с поле за години), имен ден → `/imen-den/`.
Един източник `nameday_seo.py` CARD_HTML (`?type` превключва вярната картичка). Уеб хъб `/kartichki/` +
nav бутон „Картички". Android AAB vc60 качен DRAFT в production (чака rollout; 1.0.49/57 остава жива);
iOS 1.0.50(60) submitted (Mac, път Б).** ПРЕДИШНО:
v1.0.49+57 — ★ПРИХОДЕН FIX★ Pro статус + видим „Стани Pro" + плавен преход. ЖИВА в Google Play Production
(публ. 10.07 17:28, заменя 1.0.48/56).
RevenueCat показваше $0 MRR при 116 users: след изтичане на trial isPro оставаше true от кеша (init
catch → `_loadFromCache`) → никой не падаше на free/реклами/платежен път. ЧАСТ 1: RevenueCat = истината
за `_isPro` (retry 3× backoff вместо сляп кеш; кешът само оптимистичен; downgrade детекция). ЧАСТ 2:
постоянна карта „Стани Pro" в Настройки + „Възстанови покупки" (задължит. iOS) + дискретна лента на home
за не-trial/не-Pro; Pro не вижда бутони; paywall през RC offering. ЧАСТ 3: еднократен топъл преходен
диалог (free vs Pro, данните непокътнати, жест „7 дни Pro подарък" през promo-days машинарията). analyze
0 грешки, web+APK билд ✅. Локализация 11 езика. Release notes: `release_notes/1.0.49.md`. **ВСИЧКО е чист
cross-platform Dart — НЯМА нови pubspec deps/native/assets/permissions → iOS = само Mac билд.** ПРЕДИШНО:
v1.0.48+56 (July 2026) — бърза опция „Изпрати цветя/подарък" за рождени/имени
дни (soft-launch „Очаквайте скоро" + демонд лог) + скролируем имен-ден календар + рожден-ден нотификация с
action бутон. Release notes: `release_notes/1.0.48.md`. **iOS все още на 1.0.47 — за Mac билд: `git pull` →
`flutter pub get` → `pod install` → Xcode archive.** Целият Dart WIP (AI дневен лимит UI + conversion функел,
`conversion_service.dart` + `ai_limit.dart`) е ВЕЧЕ КОМИТНАТ (78719bd) → чист клон билдва. ПРЕДИШНО:
v1.0.47+55 (June 2026) — **Контакти с имен ден** (on-device match с латиница, изскачащ списък,
Обаждане/SMS/WhatsApp/Viber + готова PNG картичка). AAB качен чрез **service account**
(`~/keys/play-service-account.json` + `tools/play_upload.py` androidpublisher API — НЕ ръчно!).
**Android: ЖИВА в Production** (rollout мина 100%, заменя 54). **iOS: 1.0.47 (55) подадена в App Store
→ WAITING_FOR_REVIEW** (инсталирана на Toto). READ_CONTACTS се оказа БЕЗ нужда от декларация (Data
safety вече Complete, контактите on-device → не се събират; не е SMS/Call-Log). Privacy политика
коригирана (чете телефони само при изрично действие). Release notes: `release_notes/1.0.47.md`.
**TODO (не спешно):** edge-to-edge fix (Android 15) + сайт taskify1969.com/privacy (стар, Cloudflare
Direct Upload — източникът вероятно на PC). ПРЕДИШНО:
v1.0.46+54 — Пълен именен dataset (~769 имена) + секция „За приложението" (динамична версия,
„Как се ползва", лиценз) + fix групови AI подзадачи + интерактивни подзадачи в картата.
**Android: качен в Play Console → Production** (rollout). **iOS: 1.0.46 (54) в App Store ревю**
(1.0.45 е READY_FOR_SALE). **Web deploy-нат** (Cloudflare Pages). И трите платформи на 1.0.46. Виж DEVLOG

## Recent Work
Keep this current — it is the shared cross-machine context (see Cross-Machine Workflow). Newest first.
- **★Споделените задачи в основния списък → v1.0.57(67) App Store ревю (Mac, 2026-08-07):** ново
  `widgets/shared_tasks_section.dart` (`SharedTasksSection`) — обособена секция „Споделени" НАЙ-ОТГОРЕ в
  `task_screen` (ListView index 0). Днешните+просрочените (и завършени днес) групови задачи от ВСИЧКИ групи,
  всяка с етикет; real-time (ръчен combineLatest `watchMyGroups`→`watchTasks`, чист dispose). Завършване
  `toggleComplete` (author-gated), отваряне→`GroupTasksScreen`. Модели РАЗДЕЛЕНИ (Task/Hive vs GroupTask/
  Firestore). Скрива се без групи. `analyze` 0, web+iOS ✅, Toto. App Store: 1.0.56 се одобри → нова версия
  **1.0.57(67)** + обновено **описание** (EN+BG, добави Споделени+Обучение) → WAITING_FOR_REVIEW. Android TODO в PC.
- **Firebase Analytics Фаза 1 (retention + onboarding funnel) (PC, 2026-08-04, БЕЗ app bump):** минимална
  телеметрия за 2 бизнес въпроса — retention D1/D7/D30 + onboarding funnel до първа задача/режим. Нов
  `firebase_analytics: ^11.3.0` + нов слой `services/analytics_service.dart` (singleton като `ProService`,
  тиха при грешка, no-op на web, Hive кутия `analytics_flags` за „first" маркерите). Закачени 10 events +
  2 user props + `FirebaseAnalyticsObserver`: `app_first_open`/`day_2_active` (main.dart преди runApp),
  `onboarding_started`/`_completed`, хелпер `logTaskCreated` на **11-те реални точки** за създаване (→
  `task_created`+`first_task_created`, само `task_type` НЕ съдържание; ★ИЗКЛЮЧЕН bulk JSON restore в
  settings★), `task_completed` (task/calendar/group), `first_mode_activated`/`mode_changed`+`active_mode`
  вътре в `setEnabled` на school+university service, `app_locale` в `LanguageController`. Нула лични данни,
  IDFA/Google signals default off, iOS без нов ATT prompt (ATT вече заради AdMob). `analyze` **0 грешки**,
  release APK ✅ (73.7MB). Чист Dart + config файлове налични → iOS=само Mac билд. ОСТАВА за Иво (Фаза 4):
  Privacy секция (готови BG/EN текстове) + DebugView проверка в Firebase Console.
- **★Android настигна iOS → v1.0.56+66 ЖИВА в Play Production 100% (PC, 2026-07-31):** `git pull --rebase`
  взе Пакет 1 (Mac) + bump-натата версия. **PC добавка (комит преди pull):** в `weekly_schedule_screen.dart`
  бутон „+" на всеки ден (`_addForDay`), работна седмица **Пн–Пт** (дни 1–5), умни начални часове (нов час =
  15 мин след края на последния, копира продължителността; празен ден→08:00–08:45; уикенд→понеделник);
  празен ден вече е тапваем ред „Няма часове — натисни". Rebase чист (Mac бе пипал само `_title`). `analyze`
  0 грешки, тестове **11 ✅**. `flutter clean`→AAB (61MB, merged manifest пази USE_FULL_SCREEN_INTENT)+APK
  (73.4MB). APK инсталиран+пуснат на Note 9 (SM-N960F) без краш. AAB качен **Production 100%** през
  `tools/play_upload.py --status completed` (versionCode 66, заменя 1.0.54). ★КАПАН: Play лимит release
  notes = **500 знака** (`release_notes/1.0.56.md` бе 598 → commit 403); съкратени EN(346)+BG(488) в
  scratchpad. Иво поиска и Facebook пост (готов в чата). НЕ bump-нато повторно.
- **★Пакет 1 — плътен таб Обучение (Mac, 2026-07-31, инсталиран на Toto, НЕ bump-нат):** реорганизация на
  `ModesScreen` в плътен екран. Фаза 0 → **преизползваме съществуващите модели** (Ученик Firestore
  `SchoolYear`; Студент ръчни `StudentKeyDate`), БЕЗ нови модели. 4 нови/пренаредени секции: **Ф7**
  компактна Профил карта (`_compactProfile`; тап→grade sheet/`StudentOnboardingScreen`); **Ф2** готовата
  `StudyCountdownCard`; **Ф3** ново `widgets/today_schedule_card.dart` (`TodayScheduleCard` — часовете за
  деня, маркира „сега"/„следваща (след X мин)"/минали; празно→„☕"/ваканция→„🌴"/изцяло празно→подкана);
  **Ф5** ново `widgets/study_today_tasks_card.dart` (`StudyTodayTasksCard` — до 4 задачи
  `taskKind∈homework/essay/coursework` срок днес+3дни; бутон→таб Задачи през нов `ModesScreen.onOpenTasks`);
  **Ф6** Ученик `ExamHelperCard` + Студент „🎯 Предстоящи изпити" (`_studentExams`, дати `kind==exam`).
  Махнат мъртъв код (`_off`/`_setUp`/`_modeCard`). **Уеднаквен термин** „Учебна програма"/„разписание"/
  „Моето разписание" → **„Моето разписание"** навсякъде (11 ез.). `analyze` **0**. НЕ направено (по избор
  на Иво): филтър „само Обучение" за Ф5; махане на countdown от таб Задачи. **Чист Dart → важи и за Android.**
  ОСТАВА: bump версия + „Какво ново" + качване.
- **★Обучение — 3-те TODO довършени → v1.0.55+65 (PC, 2026-07-27):** затворих отворените TODO от Mac (07-23).
  **(1) Валидация разписание:** `ScheduleSlot.hasValidRange` (край>начало) + `overlaps` (същ ден И срок;
  долепени НЕ припокриват), service `firstConflict`; диалогът за слот (`weekly_schedule_screen.dart`)
  валидира при Запази → inline червена грешка с предмет+час на конфликта (11 ез. `badRange`/`overlapMsg`).
  **(2) „Учебна програма" по срокове/семестри:** ново поле `ScheduleSlot.term` (1/2; стари слотове→1; БЕЗ
  Hive bump, чисто SharedPreferences JSON); service `_currentTerm`+`setCurrentTerm`(persist)+`forDay(term:)`+
  `isEmptyForTerm`; екран = `SegmentedButton` (Ученик→I/II срок, Студент→зимен/летен през
  `UniversityService().enabled`), филтрира по текущ срок; вход = карта „📅 Учебна програма" в таб Обучение
  (`modes_screen`). **(3) Ротатор карта за броене (Студент):** `_StudentCard`→StatefulWidget, редува
  `upcomingKeyDates().take(4)` (`Timer.periodic(5s)` само при >1; AnimatedSwitcher 400ms + точки; спира в
  dispose). Тестове **11 ✅** (`test/weekly_schedule_test.dart`), analyze **0**. Bump 1.0.54+64→1.0.55+65,
  „Какво ново" `_build=65` (3 точки×11 ез.), `release_notes/1.0.55.md`. AAB билднат (flutter clean). **Чист
  cross-platform Dart — iOS=само Mac билд.** ОСТАВА за Иво: качване AAB в Play Console + Firestore НВО/ДЗИ дати.
- **⏳ TODO за Mac (Иво, 2026-07-20):** категория **„Училище"**, която при избор отваря избраните
  предмети на ученика (вместо плосък списък от `subj_*` категории). Пълна спецификация в **DEVLOG.md**
  (най-горе, „TODO / HANDOFF → Mac"). Чист Dart → важи и за двете платформи.
- **★Училищен режим★ (българска учебна година + обратно броене до ваканция) (PC, 2026-07-20, БЕЗ app bump):**
  Нова функция за ученици; ядрото = **обратно броене до следваща ваканция** („Още N дни до Коледната
  ваканция 🎄"). Диференциатор: приложението знае БГ учебната година (ваканции/срокове/НВО/ДЗИ).
  Архитектура = **1:1 копие на `renewal_offers`**: Firestore колекция `school_calendar` (документ по
  учебна година `bg_YYYY_YYYY`) + вграден JSON fallback + 24ч кеш + `revision` ValueNotifier. ★Датите
  НЕ са хардкоднати★ — Иво пълни един Firestore документ веднъж годишно по заповед на МОН, без нов билд;
  при липса → **честно празно състояние, НЕ гадаем**. Нови: `models/school_calendar.dart` (чиста
  тествана логика `computeCountdown`/`gradeMatches`), `services/school_calendar_service.dart`,
  `widgets/school_countdown_card.dart` (реактивна карта, 11 ез.), `assets/data/school_calendar_bg.json`
  (seed 2025/2026 `official:false`+TODO), `test/school_calendar_test.dart` (**14 теста ✅**). Краят на
  годината е РАЗЛИЧЕН по клас (I–III/IV–VI/VII–XI/XII) → потребителят избира клас при включване. Карта
  в Tasks под productivity банера (скрива се при изкл.); toggle+клас+„Добави предмети" (предметите=
  обикновени категории) в BG секцията на Настройки; `firestore.rules` ново read правило за
  `school_calendar`. Режимът е **БЕЗПЛАТЕН** (виралната кука движи инсталации). **Чист Dart → iOS=само
  Mac билд** (Firestore вече в Podfile). analyze 0 issues. ОСТАВА за Иво: попълни реалните дати в
  Firestore Console (`school_calendar/bg_2026_2027`, `official:true`) + `firebase deploy --only
  firestore:rules`. Опц. пропусната: AI „домашно по математика" (server-side worker).
- **Именник SEO: значения на имена + og:image/breadcrumb/lastmod (PC, 2026-07-15, само уеб, БЕЗ app bump):**
  Задачата „SEO страници за имена дни" — ★системата ВЕЧЕ съществуваше и е жива★: `tools/nameday_seo.py`
  (от 2026-07-11) генерира **821 статични страници** от `assets/data/bg_name_days.json` (700 по име
  `/imen-den/ime/{slug}/`, 120 по дата, хъб, sitemap; плаващи празници = православен Великден + offset,
  динамично). Единствената дупка = **тънки/еднакви страници**. Добавено (само `nameday_seo.py`):
  (1) `MEANINGS` — **40 популярни имена** с авторски текст за значението/произхода → H2 „Какво означава
  името X?" + втори FAQ въпрос; (2) изрична бележка за **46-те плаващи имена**; (3) бързи SEO:
  `og:image`+Twitter Card (споделяне с картинка), **BreadcrumbList** JSON-LD, `<lastmod>` в sitemap.
  Всички 821 title-а уникални; JSON-LD валиден. Deploy `wrangler pages deploy . --project-name=taskify`
  (★сайт=`taskify`, app=`taskify-app`; хостинг = **Cloudflare Pages**, Namecheap само домейн★).
  Разширяване: добавяш имена в `MEANINGS` → run → copy → deploy. iOS/Android НЕ засегнати (само уеб).
- **Widget „+" + локален контекст + „Какво ново" диалог → v1.0.51+61 (PC, 2026-07-13):**
  (1) **„+" в трите размера widget** → `WidgetActions.kt` (`PendingIntent.getActivity`, action
  `ACTION_NEW_TASK`, уникална data → `onNewIntent`); `MainActivity` пази `pendingWidgetAction` и го дава
  на Dart през канал-метод `consumeWidgetAction`; `home_screen` го консумира (cold start + resume) →
  таб „Задачи" + `TaskEditorBridge.openNewSelfManaged()`. Drawable `widget_add_btn_bg.xml` беше в
  `res/xml/` (мъртъв — `@drawable/` не го вижда) → в `res/drawable/`. (2) **Локален контекст:**
  `WidgetService._syncContextToPrefs` пише `widget_context` JSON (готови текстове, 11 ез.):
  `docExpiry` (`template=='document'`, ≤14 дни), `nameDay`, `holiday` (нов `HolidaysService.hasData`);
  `WidgetContext.kt` избира **документ > имен ден > празник**; ред в medium/large + при празен списък
  заменя фразата (нов `empty_context` TextView, четим bold шрифт — Caveat autosize беше нечетим).
  Само при `ProService().isPro` + включени toggle-и (иначе ключът се трие); `main.dart` пресинхронизира
  widget-а след Pro init. Чекването е недокоснато. (3) **`whats_new_dialog.dart`** — виж „Release Rule".
  Тествано на живо на Note 9. Release notes: `release_notes/1.0.51.md`.
- **★ПРИХОДЕН FIX★ Pro статус + видим paywall вход + плавен преход → v1.0.49+57 (PC, 2026-07-10):**
  RevenueCat = $0 MRR при 116 users, защото след 14-дневния trial isPro оставаше true. Root cause:
  `pro_service.dart initialize()` catch блок → `_loadFromCache()` връщаше стар `is_pro` БЕЗ сверка с RC;
  освен това реалният масов Pro идва от **локалния `_isTrial`** (14 дни без покупка), който изтичаше, но
  нямаше видим път до покупка. **ЧАСТ 1 (`pro_service.dart`):** слушателят се закача ВЕДНАГА след
  `configure()` (преди getCustomerInfo → коригира при връщане на мрежата); нов `_getCustomerInfoWithRetry`
  (3 опита, backoff 1s/2s) вместо сляп кеш; кешът е само оптимистичен, RC отговорът го бие; `_isPro=false`
  при provably неактивен entitlement; нов флаг `_wasDowngradedFromCache` (кеш=Pro/RC=inactive) + `_logProSource`.
  **ЧАСТ 2 (`settings_screen.dart` + `home_screen.dart`):** постоянна amber карта „Стани Pro" НАЙ-ГОРЕ в
  Настройки (само `!isPro`, mobile; `workspace_premium`) → `PaywallScreen`; „Възстанови покупки"
  (`restorePurchases`, задължит. за iOS); дискретна лента `_buildGoProStrip` на home за не-trial/не-Pro
  (там нямаше нищо след края на trial); Pro НЕ вижда бутони; ProService listener в двата екрана. Paywall
  вече зарежда през RC offering (`getOfferings`, има „Няма продукти" fallback → провери offering-а в RC
  Dashboard + entitlement `Taskify 1969 Pro`). **ЧАСТ 3 (`home_screen.dart`):** еднократен топъл преходен
  диалог `_maybeShowDowngradeDialog` (flag `downgrade_dialog_shown`) за стари users (бивш кеш-Pro ИЛИ
  изтекъл локален trial); ясно free vs Pro, данните непокътнати; жест **„7 дни Pro подарък"**
  (`ProService.grantEarlySupporterGrace(7)` през тестваната **promo-days** машинария → изтича чисто).
  Добавяне над free лимит (50 задачи) остава блокирано с paywall (`canAddTask`, нищо не се трие). analyze
  **0 грешки**, web build ✅, APK release ✅. Локализация на 11 езика. **iOS: чист Dart, само Mac билд.**
- **Монетизация: „Очаквайте скоро" + слой „цветя/подарък" (PC, 2026-07-08, commit `c788723`):** докато чакаме
  реални affiliate линкове, бутонът „Поднови сега" вече показва диалог „Очаквайте скоро!" (флаг
  `kRenewalComingSoon` в `renewal_cta.dart`) вместо тестовия Boleron URL — но кликът пак се логва. Нов
  intent-based слой „**Изпрати цветя/подарък**" (`lib/widgets/gift_cta.dart`, флаг `kGiftComingSoon`): бутон
  на **рожден-ден картата** (`task_card_styles.dart`, двата стила) + действие в **списъка имен-ден контакти**
  (`calendar_screen._showContactActions`); и двете показват „Очаквайте скоро" + логват интерес
  (`RenewalService.logInterest` → `renewal_clicks` `type:'interest'`). **iOS (Mac) handoff: ВСИЧКО е чист
  cross-platform Dart — НЯМА нови pubspec deps, native код, assets или permissions.** Firestore вече е в iOS
  Podfile (FirebaseFirestore 11.15.0), Anonymous Auth е включен project-wide → `logInterest` работи и на iOS
  без промени. Coming-soon пътят не пуска нищо (без нови URL схеми/`LSApplicationQueriesSchemes`). Mac: само
  `git pull` → `flutter pub get` → `pod install` (no-op за pods) → билд. analyze 0 нови грешки. Виж DEVLOG.
- **v1.0.47+55 ЖИВА на двете платформи (Android Production / iOS в ревю):** Android 1.0.47 (55) **публикувана
  на 100% в Production** (rollout мина; 177 държави) — READ_CONTACTS не изиска блокираща декларация (on-device
  → „не се събира"). iOS 1.0.47 (55) (Mac) **подадена в App Store → WAITING_FOR_REVIEW**, инсталирана на Toto.
  Privacy политика коригирана (`privacy-policy.html` + `docs/`) — функцията чете телефони само при изрично
  действие (Обаждане/SMS/WA/Viber), on-device, без съхранение/предаване. **TODO (не спешно):** edge-to-edge
  fix (оттеглени API, Android 15) за следващ билд; сайт taskify1969.com/privacy е стар (Cloudflare Direct
  Upload без Git, източникът вероятно на PC) → добави раздел „Contacts" + `wrangler pages deploy`. Виж DEVLOG.
- **Контакти с имен ден — on-device, с латиница (PC, нова работа в същата v1.0.46+54 — НЕ качена):**
  Нова опционална premium функция. В банера за имен ден (Календар) се показва „От твоите контакти: …"
  с контактите, които празнуват ДНЕС + чип-бутон „Честит имен ден!" (share_plus, ръчно споделяне).
  **100% on-device — нито едно име не напуска телефона**, нищо в облак/Firestore. Toggle в Настройки →
  „България" → **„Контакти с имен ден"** (по подразбиране ИЗКЛ.; иска разрешение само при вкл.; вижда се
  само ако именните дни са вкл. и НЕ на web). Латиница: нов `utils/bg_translit.dart` — официална бг
  транслитерация (Закон 2009, кирилица→латиница) + фонетичен скелет `canonLatin`, който слива проблемните
  звуци (ts↔c, ch↔h, ya↔ia, yu↔iu, y↔i↔j, kh→h, zh→z) → НЕ транслитерира латиница→кирилица (многозначно).
  Така Ivan=Иван, Tsvetan=Cvetan=Цветан, Iordan=Yordan=Jordan, Christo=Hristo. Симетричен `keysFor()`
  (`c:`/`l:` ключове) се ползва и при индекс, и при заявка. `services/contact_name_index.dart`
  (`flutter_contacts`) гради ЕДНОКРАТЕН локален индекс (ключ→display names), кешира в Hive box
  `bg_contact_index`; **при изключване кешът се трие**. Заявката е синхронна (1000+ контакта не блокират
  UI). Думите се чистят от инициали/числа; match-ва ВСЯКА дума (Иван Петров / Петров Иван / „Иван и Мария").
  Нов dep `flutter_contacts ^1.1.9`; Android `READ_CONTACTS` + iOS `NSContactsUsageDescription`;
  Privacy Policy (root + `docs/`) с нов раздел „1.3 Contacts". 13/13 unit match теста ✅, analyze 0 нови
  грешки, **release APK билднат ✅ (71.4MB)**, инсталиран на Note 9 (WiFi adb 192.168.0.117:5555),
  стартира без краш. ⚠️ Play Console ще иска **декларация за чувствително разрешение (READ_CONTACTS)**
  при следващото качване на AAB. **UX итерация (същия ден):** списъкът на празнуващите контакти вече е в
  **изскачащ прозорец** (`_showNameDayContacts`, побира много контакти без да чупи банера — банерът показва
  само бутон „От твоите контакти: N"); натискане на контакт отваря bottom sheet с **Обаждане/SMS/WhatsApp/
  Viber + „Сподели честитка"** (`url_launcher`; телефонът се тегли ПРИ НУЖДА през `phonesForContact`, НЕ се
  кешира; индексът вече пази contactId, не само име). Messenger няма phone-таргет (Facebook) → махнат по
  избор на потребителя. Android `<queries>` за tel/sms/https/viber. **Поправки след тест на живо:**
  (1) ★БЪГ★ списъкът беше празен след reinstall — смененият кеш ключ (`index`→`index_v2`) + липса на
  авто-rebuild → нов `revision` ValueNotifier + `ensureLoaded` авто-преизгражда при празен индекс веднъж
  на сесия (банерът слуша revision). (2) Viber `chat?number=` гърмеше → `viber://forward?text=`. (3)
  WhatsApp да отваря APP-а: `whatsapp://send?phone=&text=` + fallback `wa.me` + `<package>` видимост
  (com.whatsapp/.w4b/com.viber.voip). (4) Нова **готова картичка** „Честит имен ден" (`utils/name_day_card.dart`)
  — преглед в диалог + споделяне като PNG (RepaintBoundary→toImage→`shareXFiles`); 7 градиента по
  hash на името, Caveat шрифт (google_fonts), конфети, феаст, воден знак Taskify. Виж DEVLOG.
- **Интерактивни подзадачи в разгъната карта (PC, в същата v1.0.46+54 — още НЕ качена в конзолата):**
  при разгъване на карта с подзадачи вече се показва списък с **чекбокс на всеки ред** (отмятане
  завършена/не), на трите екрана — Задачи, Календар, Споделени. Нови споделени widget-и в
  `task_card_styles.dart`: `_SubtaskChecklist` + `_MiniCheck`; нов optional callback `onToggleSubtask(index)`
  на `TaskCardView`/`ExpandableTaskCard`/`TicketTaskCard` (запазва се прогрес-лентата като header).
  Имплементиран на 3-те екрана: лични (Hive `setSubtasks`+`save`), календар (същото), групови
  (`group_tasks_screen._toggleSubtask` → `SubtaskCodec` + `_service.updateTask`, живо към Firestore).
  AAB+web rebuild-нати (същата версия), web deploy-нат, APK тестван на Note 9 (стартира без крашове).
- **Именен dataset + „За приложението" + групови подзадачи fix → release v1.0.46+54 (PC):**
  Bump 1.0.45+53 → **1.0.46+54**; AAB build-нат за Play Console (ръчно качване → Production);
  **web deploy-нат** (Cloudflare Pages чрез `npx wrangler pages deploy build/web --project-name=taskify-app`).
  iOS: всичко е в repo-то (cross-platform Dart + assets) → остава само Mac билд + App Store.
  (1) `assets/data/bg_name_days.json` заменен с пълния Wikipedia извлек (CC BY-SA 4.0) — **120 фикс. +
  6 подвижни, ~769 имена** (Доротея 6 фев, и др.); новият формат ползва `offset` →
  `name_days_service.dart` приема и `offset`, и стария `offsetFromOrthodoxEaster`; `_full.json` изтрит.
  (2) Нова секция **„За приложението"** най-долу в Настройки (11 ез., inline `tr()`): динамична версия/билд
  чрез **`package_info_plus`** (нов pubspec dep); подекран **„Как се ползва"** (`how_to_use_screen.dart`,
  6 точки); линкове Поверителност/Условия + лиценз на именните дни (Уикипедия). (3) **Fix групови
  подзадачи:** AI breakdown пазеше сурови заглавия без префикс → счупен UI/брояч; нов общ helper
  `utils/subtask_format.dart` (`SubtaskCodec`), ползван от `Task` и от `group_tasks_screen` (нормализира
  към `0:1:title`). analyze 0 нови грешки; web+APK билд ✅; APK инсталиран и стартиран на Note 9. Виж DEVLOG.
- **iOS widget — ръкописен шрифт (Mac):** home-screen widget-ът вече ползва **Caveat** за празното
  състояние, като Android. `caveat.ttf`→`ios/TaskifyWidget/Caveat.ttf`, рег. в widget `Info.plist`
  (`UIAppFonts`) + Copy Bundle Resources на TaskifyWidget таргета (внимание: file ref path = само
  `Caveat.ttf`, иначе удвоен път). `TaskifyWidget.swift`: фразата е `Font.custom("Caveat-Regular",
  size: small?24:32)` + `lineLimit(3)` + `minimumScaleFactor(0.4)` → макс. едър, свива се по дължина,
  без съкращения. Заглавията остават обикновен шрифт. Build Xcode 26 + `devicectl` install на Toto
  (device only, без App Store). Виж DEVLOG.
- **Споделени списъци — Android в Production (PC):** v1.0.44+50 (умен редактор, build 50) build-нат
  на PC (JDK 17) и **качен ръчно в Play Console → Production** (rollout стартиран). APK тестван само
  колкото да стартира на Note 9 (signature mismatch → деинсталиран Play билд, сложен локален release);
  ПЪЛният live тест на групите чака потребителя. Backend общ → без Android-специфична настройка.
  Проучено авто-качване през Play Developer API (service account/JSON) — отложено; има готов GCP
  проект `taskmasteruploader` (RevenueCat SA) за преизползване. Виж DEVLOG.
- **Споделени групи / групови задачи — MVP (Mac):** Нов ОТДЕЛЕН слой за споделени
  списъци между потребители; личният Hive/merge sync е НЕДОКОСНАТ. Живее само във Firestore (real-time
  snapshots + вграден offline кеш, БЕЗ Hive). Структура: `groups/{id}` (ownerId, members[], memberInfo,
  inviteCode, server timestamps), `groups/{id}/tasks/{taskId}` (Task полета + categoryName като ТЕКСТ,
  createdBy/completedBy, `deleted` tombstone, server updatedAt), `invites/{code}→{groupId}`. НОВ
  `firestore.rules` (рег. в firebase.json) — сигурностна граница: само членове четат/пишат; join добавя
  само СЕБЕ СИ; само owner трие; invites get-only. ⚠️ **rules НЕ са деплойнати още** —
  `firebase deploy --only firestore:rules`. Нов таб **„Споделени"** замени „Матрица" долу; Матрицата →
  иконка в AppBar-а на Задачи. Нов код: `models/group.dart`, `services/group_service.dart`,
  `screens/shared/*`. Gating: създаване=Pro, присъединяване=безплатно. analyze 0 грешки, web build ✅;
  Android APK не тестван на Mac (виж DEVLOG).
- **AI anti-Russian hardening (PC, no app bump):** реши Mac-овия TODO — breakdown понякога връщаше
  руски повелителни форми. В worker-а (`Desktop/taskify-ai/`): (1) few-shot контрастен промпт за
  `lang==='bg'` (ПРАВИЛНО бг vs ЗАБРАНЕНО ру примери) + забрана на ы/э/ё в parse/schedule;
  (2) server-side `looksRussian()` детекция + `runAI()` авто-retry с подсилен промпт при засечен
  руски (за всеки не-руски език). Внимание: думи валидни и на бг (задача, отправ, ваш…) изключени
  от детекцията. Тествано bg ×12 → 0 руски. Server-side. Deploy `npx wrangler deploy`.
- **AI worker model fix (PC, no app bump):** AI parsing/breakdown/schedule бяха мъртви —
  Cloudflare спря стария Workers AI модел (`llama-3.1-8b-instruct`, 502 deprecated). Worker-ът
  (`Desktop/taskify-ai/`, отделно НЕ-git репо) качен на **`@cf/meta/llama-3.3-70b-instruct-fp8-fast`**
  (по-чист български). 70B връща OpenAI-style отговор (`response` = ВЕЧЕ обект, не низ) → нов helper
  `modelJSON()` нормализира shape-овете за parse/breakdown/schedule. Server-side фикс, endpoint
  непроменен → НЯМА нужда от app rebuild. Деплой: `cd Desktop/taskify-ai && npx wrangler deploy`.
- **v1.0.43+48 (Mac):** iOS brought to feature parity (Documents/Tickets pulled & verified on device). New `utils/calendar_notes.dart` strips internal `key:value` metadata (`doctype:`/`dest:`/`with:`…) from calendar event descriptions on BOTH Apple & Google. Unified the 3 duplicated category-color palettes into shared `utils/category_colors.dart` + added ~17 bright/vivid colors. Submitted to App Store (live was 1.0.39).
- **v1.0.43+47:** Documents (`template == 'document'`) are now excluded from the main Tasks list + its stat counts (`_computeTasks`) and from the Eisenhower matrix — they have far-future expiry dates and their own "Documents" tab (+ Calendar + reminders), so they no longer clutter the daily task list.
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

<!-- BUILD-NOTES-ANDROID -->
## Android release build — задължителни стъпки

Преди ВСЕКИ release билд (aab/apk за Google Play):

1. `flutter clean` — ЗАДЪЛЖИТЕЛНО. AndroidManifest.xml е променян ръчно (16.07.2026, добавен USE_FULL_SCREEN_INTENT). Без clean merge-натият manifest може да остане кеширан.
2. targetSdk = 36 / compileSdk = 36 — изискване на Google Play (нови submissions след 31.08.2026). НЕ понижавай.
3. USE_FULL_SCREEN_INTENT в `android/app/src/main/AndroidManifest.xml` — НЕ премахвай. Нужно е за full-screen нотификации на алармите на Android 14+/API 36; без него алармите не се задействат на цял екран.

След билд: провери че merged manifest съдържа USE_FULL_SCREEN_INTENT (build/app/intermediates/merged_manifests/).
<!-- /BUILD-NOTES-ANDROID -->
