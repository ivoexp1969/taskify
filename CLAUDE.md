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
**v1.0.49+57 (July 2026) — ★ПРИХОДЕН FIX★ Pro статус + видим „Стани Pro" + плавен преход.**
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
