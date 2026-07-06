# DEVLOG

Shared session log across machines (PC = Android, Mac = iOS). **Newest first.**
One short entry per session: date · machine · what · version · key commits.
Pull before you start, push (incl. this file) when you finish. See `CLAUDE.md` → Cross-Machine Workflow.

---

## 2026-07-06 · PC — Монетизация „Идея 1": affiliate слой „Поднови сега" върху Документи (Фаза 0+1, rules ЖИВИ)
Нова приходна линия, независима от абонамента: при изтичащ документ (ГО/винетка/тех.преглед…) показваме
партньорска препратка „Поднови сега" → комисиона. Приложението вече знае точната дата на изтичане на
скъпи повтарящи се покупки. Държавните документи (лична карта/паспорт/книжка) получават неутрален инфо
линк (`commercial:false`), не affiliate — пази доверието.
- **Обосновка от кода:** живите Документи са `Task` с `template=='document'` + `doctype:` в notes (НЕ
  `ExpiringDocument`/`DocumentsService` — те са паралелен неизползван код). Документите са Pro-gated
  (`home_screen.dart:255`) → Фаза 3 предлага разгейтване за free с лимит, за да расте affiliate обхватът.
- **Фаза 0 (данни):** нов `services/renewal_service.dart` (+`RenewalOffer`); `assets/data/renewal_offers.json`
  (fallback, всички `enabled:false`, placeholder URL-и); remote config през Firestore `renewal_offers` +
  24ч кеш + вграден fallback; анонимен `renewal_anon_id` → `subid=anon-doctype-epoch` за атрибуция.
  Pure функции (`resolveOffer`/`buildUrl`/`makeSubid`/`parseOffers`/`normalizeCountry`) + `test/renewal_service_test.dart`
  **20/20 ✅**.
- **Фаза 1 (UI):** нов `widgets/renewal_cta.dart` — self-hiding `RenewalCta` (SizedBox.shrink при липса на
  оферта), закачен в `documents_screen.dart` `_buildCard` при `daysLeft<=30`. Еднократен disclosure sheet
  (prefs `renewal_disclosure_shown`, 11 езика) за commercial оферти; `registerClickAndBuildUrl` логва клик в
  Firestore `renewal_clicks` (guard-нат) + локален брояч, после `launchUrl` external. `lang` = proxy за държава.
- **Firestore rules (ЖИВИ, деплойнати днес):** нови блокове след `promo_codes` — `renewal_offers` (публичен
  read, без клиентски write) + `renewal_clicks` (само create от логнат, append-only). `firebase deploy
  --only firestore:rules --project taskify-1969` → compiled + released ✅.
- **Верификация:** `flutter analyze` цял проект → **0 error** (само заварени info/warning); тестове 20/20.
  Нищо не се вижда в приложението още — всички оферти са `enabled:false`.
- **Anonymous Auth (за да се логват и анонимните кликове):** нов `AuthService.ensureAuthedForLogging()` —
  ЛЕНИВ тих анонимен вход, извикван САМО при клик на affiliate CTA от нелогнат потребител (не при старт).
  За да НЕ протекат лични данни в облака, анонимните сесии са изключени навсякъде: `isLoggedIn` вече
  = `currentUser != null && !isAnonymous`; `_userId` в `sync_service` + `firestore_service` връща null за
  анонимни (→ `mergeWithCloud` дава „not-signed-in", нула sync); настройки показват вход, не профил
  (guard на `user`); `pro_service` промо-listener пропуска анонимни. `flutter analyze` → 0 error; тестове 20/20.
  ⚠️ **Trябва ръчно да се включи доставчик „Anonymous"** в Firebase Console → Authentication (кодът е
  безопасен и без това — `signInAnonymously` пада тихо → само локален брояч).
- **Фаза 2 (нотификация → deep-link):** напомнянията за document-задачи вече носят payload `renew:<doctype>`
  и Android action **„🔄 Поднови"** (вместо безсмисления „+30 мин" snooze — документите имат дълъг хоризонт).
  `_buildNotificationDetails` приема `renewDoctype`; `scheduleForTask` вади doctype от notes
  (`_doctypeFromNotes`) и подава payload. Тап (warm) → нов callback `setRenewTapCallback` (рег. в `main.dart`)
  → отваря `DocumentsScreen` (там е partner CTA-то). Cold-start (убито приложение) → `init()` пази
  `renew_pending_route`, `home_screen._consumePendingConversionRoute` го консумира след първия кадър →
  push DocumentsScreen. Само Pro имат документи → без gating конфликт. Stub (web) получи no-op
  `setRenewTapCallback`. `flutter analyze` цял проект → **0 error**; тестове 20/20.
- **Фаза 3 (разгейтване за free с лимит):** „Документи" вече е достъпен и за free — премахнат paywall
  гейтът на входа на таба (`home_screen._onDestinationSelected`; изтрит и вече мъртвият `_documentsIndex`).
  Лимитът се пренесе на БРОЯ документи при СЪЗДАВАНЕ: `DocumentDialog.freeLimit = 2` (Pro неограничено);
  при `existing==null && !isPro && count>=2` → paywall (редакция на съществуващ винаги позволена; на web
  isPro=true → без гейт). Така partner CTA-то „Поднови сега" стига до цялата база, а Pro стимулът остава.
  `flutter analyze` цял проект → **0 error**; тестове 20/20.
- **ТЕСТ НА ЖИВО (Note 9, release APK):** Anonymous доставчик включен в конзолата; създадена тестова
  оферта в `renewal_offers` (`doctype:insurance`, `countries:[bg]`, `enabled:true`, тестов URL
  boleron.bg). Добавен документ „Гражданска отговорност" (изтича след 9 дни) → **бутонът „Поднови сега"
  се показа и линкът се отвори ✅** (потвърден целият поток с реални данни).
- **★БЪГ намерен и фикснат (Фаза 1.1):** бутонът НЕ се появяваше при първото отваряне — само след рестарт.
  `RenewalCta` оценяваше офертата веднъж в `initState`, а Firestore тегленето е фоново СЛЕД това. Фикс:
  `RenewalService.revision` (ValueNotifier, като `DocumentsService.revision`) се бумва в `refreshFromRemote`
  щом офертите дойдат; `RenewalCta` слуша го и се пре-оценява (`_resolve`) → бутонът лъсва без рестарт.
  0 analyze грешки; тестове 20/20.
- ★TODO за go-live★: (1) ✓ Anonymous включен; (2) замени тестовия boleron.bg URL с реален affiliate линк
  (`{subid}` остава буквално). Опция Фаза 3.1: rewarded реклама за +1 документ над лимита.

## 2026-06-30 · Android — 1.0.47 (55) ЖИВА в Production + iOS статус
- **Android:** Play Console „Стандартен канал" → **Активни, най-нова публикувана версия 1.0.47**, 177
  държави, 26 инсталирания. Тоест **build 55 (1.0.47) е публикуван на 100%** — rollout-ът мина (драфтът
  от 06-29 е пуснат). Нищо не е блокирано/прекратено.
- **Data safety / Permissions (READ_CONTACTS):** НЕ изискаха блокираща декларация — публикува се чисто.
  Контактите са on-device → „не се събират" (consistent с iOS App Privacy, където махнахме „Contacts").
- ★TODO (бъдеща версия, не спешно):★ Play показва 2 препоръчителни действия за **edge-to-edge показване**
  (оттеглени API, Android 15) — козметично, код-промяна за следващ билд, НЕ свързано с контактите.
- **iOS:** 1.0.47 (55) все още WAITING_FOR_REVIEW (виж по-долу). Сайтът taskify1969.com/privacy — пак
  отложен (виж предходния запис).

## 2026-06-30 · Mac — iOS 1.0.47 (55) подадена в App Store + Toto + privacy fix
`git pull` → взе PC-работата „Контакти с имен ден" (1.0.47+55). Анализ преди действие: `flutter analyze`
0 грешки; iOS `NSContactsUsageDescription` налично; `flutter_contacts ^1.1.9` в pubspec; ASC чист
(1.0.46 READY_FOR_SALE). После публикувах:
- `flutter build ipa --release` (Xcode 26, pod install за flutter_contacts) → `altool` UPLOAD SUCCEEDED.
- ASC (/tmp/asc44.py, VERSION=1.0.47/BUILD=55): създадена версия 1.0.47 (id 2ceed936…), whatsNew en-US
  (EN+BG, БЕЗ емоджита, от `release_notes/1.0.47.md`); build 55 (VALID) закачен (204) → подаден →
  **WAITING_FOR_REVIEW**.
- **Toto:** `flutter build ios --release` → `devicectl install` (Toto се появи „connected (no DDI)" след
  няколко опита) → потвърден **1.0.47 (55)**, стартиран на чисто.
- ★PRIVACY FIX★: политиката твърдеше „we do not access phone numbers", но функцията ЧЕТЕ телефони (при
  тап → Обаждане/SMS/WA/Viber, on-device, при изрично действие). Коригирах `privacy-policy.html` +
  `docs/privacy-policy.html` (GitHub Pages, paywall линка) → точен текст. Commit 4dfc84f.
- **ОСТАВА за потребителя (ръчно):** (1) App Store App Privacy — ✅ ГОТОВО (потребителят махна „Contacts"
  → 11 типа, коректно, on-device не се декларира); (2) Play Data safety + Permissions Declaration
  (READ_CONTACTS) + Start rollout (55).
- **САЙТЪТ taskify1969.com/privacy — ОТЛОЖЕН (TODO, най-добре от PC):** липсва раздел за функцията с
  контактите (стар е). Проектът `taskify` в Cloudflare е **Direct Upload (без Git)**, многостраничен
  (EN+BG: /privacy /terms + /bg/* + /bg/vs/{microsoft-to-do,ticktick,todoist} SEO стр.). **Източникът НЕ
  е на Mac** (вероятно на PC). НЕ блокира ревюто (ASC сочи към github.io, който е коректен). Когато се
  стигне: редактирай `privacy.html` + `bg/privacy.html` в ИЗТОЧНИКА (добави раздел „Contacts": имена за
  match + телефон само при изрично действие, on-device, без съхранение/предаване — текстът е в
  `docs/privacy-policy.html` на това repo) → `wrangler pages deploy <dir> --project-name=taskify`.
  Унифицирай и двата линка в приложението (Настройки→taskify1969.com, paywall→github.io) към един.

## 2026-06-29 · PC — v1.0.47+55 качен в Play Console (Production **draft**) през service account
Довърших handoff-а от 06-28: bump-ът 1.0.47+55 беше некомитнат + AAB от снощи с двусмислена версия.
- **Ребилд** на чист AAB → `flutter build appbundle --release` = **1.0.47+55, 57.7MB**.
- ★Първо авто-качване през Play Developer API★ (вече има service account — паметта от 06-28 беше остаряла,
  че няма). Ключ `~/keys/play-service-account.json` (`play-upload@taskify-1969.iam.gserviceaccount.com`,
  проект `taskify-1969`). Python `google-api-python-client` + `google.oauth2` вече инсталирани.
- Нов **`tools/play_upload.py`** (androidpublisher v3: edits.insert→bundles.upload→tracks.update→commit;
  чете release notes от файл за да не чупи кирилица в shell args; `--dry-run` показва текущия track; status
  по подразбиране **`draft`** = НЕ пуска rollout). Качено в **Production track като draft**, versionCode 55,
  release notes BG+EN (от `release_notes/1.0.47.md`). Живата версия остава 54; 55 чака ръчно пускане.
- ★КАПАН★ (документиран на потребителя): **Data safety + Permissions Declaration НЯМАТ публичен API** —
  попълват се само ръчно в Console. Дадох му стъпки. За **Contacts**: четат се само on-device и НЕ напускат
  телефона → по дефиницията на Google („collected" = изпратено извън устройството) → **НЕ се събира/споделя**
  в Data safety (честно, защото е 100% on-device). Обосновка за READ_CONTACTS (ако Console я поиска) +
  App access инструкция (функцията е зад Pro → промо код IVA) — текстовете са в чата.
- Commit **4f4719a** push-нат (pubspec +55, CLAUDE.md, release_notes/1.0.47.md, tools/play_upload.py).
- **ОСТАВА за потребителя (ръчно в Console):** Data safety Complete → (евент. Permissions declaration) →
  Release → Production → Edit/Review → Start rollout. После iOS на Mac (1.0.47 за паритет).

## 2026-06-28 · PC — Контакти с имен ден (on-device, латиница) · v1.0.46+54 (нова работа, НЕ качена)
Нова опционална premium функция: в банера за имен ден (Календар) се показва кои от контактите празнуват
днес + бутон „Честит имен ден!" (share_plus). **100% on-device** — нищо не напуска телефона, нищо в облака.
- **Match с латиница без транслитерация лат→кир** (многозначно): нов `lib/utils/bg_translit.dart` дава
  официална бг транслитерация (кир→лат) + фонетичен скелет `canonLatin` (слива ts↔c, ch↔h, ya↔ia, yu↔iu,
  y↔i↔j, kh→h, zh→z) + симетричен `keysFor()` (`c:`/`l:`). Ivan=Иван, Tsvetan=Cvetan=Цветан,
  Iordan=Yordan=Jordan, Christo=Hristo. 13/13 unit match теста OK (вкл. без фалшиви: Петров, Hristo↛Иван).
- **Индекс/кеш:** `lib/services/contact_name_index.dart` (`flutter_contacts`) гради ЕДНОКРАТНО локален
  индекс ключ→display names, кешира в Hive box `bg_contact_index`; заявката е синхронна (1000+ контакта не
  блокират UI). По подразбиране ИЗКЛ.; разрешение се иска само при вкл.; при изкл. кешът се ТРИЕ.
- **UI:** toggle Настройки → „България" → „Контакти с имен ден" (premium, само мобилни, само ако именните
  дни са вкл.) + бутон „Опресни контактите". Банер в Календара „От твоите контакти:" с чипове.
- **Permissions/privacy:** нов dep `flutter_contacts ^1.1.9`; Android `READ_CONTACTS`; iOS
  `NSContactsUsageDescription`; Privacy Policy (root + `docs/`) → нов раздел „1.3 Contacts".
- **Верификация:** analyze 0 нови грешки; **release APK билднат OK (71.4MB)**. Телефонът НЕ беше свързан
  по adb → живият тест (реален адресник, разрешение, share) ОСТАВА за потребителя. **НЕ committ-нато още.**
- ⚠️ **Play Console:** `READ_CONTACTS` е чувствително разрешение → при следващо качване ще трябва
  Permissions Declaration / Data safety ъпдейт (контакти се ползват само on-device, не се споделят).
- **UX итерация (същия ден, инсталирано на Note 9 по WiFi adb):** Красимир/Красимира НЕ беше dataset
  пропуск (и двете са на 1 юли), а overflow — старият вграден списък не се събираше при >2 контакта.
  Решено: списъкът вече е в **изскачащ прозорец** (`_showNameDayContacts`); банерът показва само бутон
  „От твоите контакти: N". Натискане на контакт → bottom sheet с **Обаждане/SMS/WhatsApp/Viber +
  „Сподели честитка"** (`url_launcher`). Телефонът се **тегли при нужда** (`ContactNameIndex.phonesForContact`,
  чрез `flutter_contacts getContact withProperties`), НЕ се кешира (индексът пази contactId+display name,
  ключове `index_v2`/`names_v2`). Norm. на номера към межд. формат за WA/Viber (BG `0…`→`359…`).
  **Messenger махнат** (Facebook няма phone-таргет). Android `<queries>` tel/sms/https/viber. analyze 0
  нови грешки; APK билд+install OK, стартира без краж. Живият тест с реален Красимира контакт + Pro чака.
- **Поправки след жив тест на Note 9 (Петровден 29 юни — Петър/Павел):**
  (1) ★БЪГ★ списъкът с контакти беше празен → причина: смених кеш ключа `index`→`index_v2` при
  reinstall + НЯМАШЕ авто-rebuild на стартиране. Fix: нов `revision` `ValueNotifier` (банерът слуша) +
  `ensureLoaded` авто-преизгражда индекса при празен кеш ВЕДНЪЖ на сесия (`_autoRebuildTried`). Потребителят
  потвърди, че проработи (бе ползвал ръчния „Опресни").
  (2) **Viber** `viber://chat?number=` даваше грешка → сменено на `viber://forward?text=` (отваря Viber
  picker с готова честитка). (3) **WhatsApp** да отваря APP-а, не сайта: `whatsapp://send?phone=&text=`
  първо, после fallback `https://wa.me/`; `<package>` видимост com.whatsapp/.w4b/com.viber.voip + whatsapp
  схема в `<queries>`. (4) **Готова картичка** „Честит имен ден" (`lib/utils/name_day_card.dart`): преглед
  в диалог + споделяне като PNG (RepaintBoundary→`toImage` pixelRatio 3→temp файл→`Share.shareXFiles`); 7
  градиента (избор по hash на името = „оригинална"), Caveat (google_fonts), конфети, феаст, воден знак.
  Нов бутон „Картичка" в action sheet-а на контакта. analyze 0 грешки; APK 71.6MB install+launch OK на Note 9.

## 2026-06-15 · Android — AAB качен в Play Console → Production · v1.0.46+54
Потребителят качи ръчно готовия AAB (1.0.46+54) в Play Console → Production (rollout). С това и трите
платформи са на 1.0.46: **Android в Production**, **iOS 1.0.46 (54) в App Store ревю**, **web деплойнат**.

## 2026-06-15 · Mac — iOS подаване в App Store + install на Toto · v1.0.46 (54)
`git pull` (dfdc1f4) → взе PC-работата (интерактивни подзадачи, именен dataset, „За приложението",
групови подзадачи fix). iOS публикуване:
- 1.0.45 вече е **READY_FOR_SALE** (одобрена) → нова версия **1.0.46**. `flutter build ipa --release`
  (Xcode 26; pod install хвана новия `package_info_plus`) → `altool` UPLOAD SUCCEEDED.
- ASC (/tmp/asc44.py, VERSION=1.0.46/BUILD=54): създадена версия 1.0.46 (id 2502c888…), whatsNew en-US
  (EN+BG, БЕЗ емоджита) → акцент върху **отмятане на подзадачи в картата** + именен календар + „За
  приложението"; build 54 (PROCESSING→VALID) закачен (204) → подаден → **WAITING_FOR_REVIEW**.
- **Toto:** `flutter build ios --release` → `devicectl install` → потвърден **1.0.46 (54)** (1-ви опит
  падна с „Connection reset", 2-ри мина). Relaunch чакаше отключване на телефона — отваря се ръчно.
- Android прод си остава 1.0.44+50 (PC има готов AAB 1.0.46+54 за ръчно качване).

## 2026-06-15 · PC — Интерактивни подзадачи в разгъната карта · v1.0.46+54 (без нов bump)
Заявка: при тап/разгъване на карта с подзадачи да се виждат подзадачите с чекбокс за отмятане —
на трите екрана (Задачи, Календар, Споделени). Реализация в `task_card_styles.dart`: нов optional
callback `onToggleSubtask(index)` на `TaskCardView` (предаван към `ExpandableTaskCard` и `TicketTaskCard`)
+ нови widget-и `_SubtaskChecklist` (ред с `_MiniCheck` + текст, strike-through при завършена) — показва
се под прогрес-лентата при разгъване, само ако callback-ът е подаден. Call sites: `task_screen` и
`calendar_screen` (Hive: `subtasksList`→flip→`setSubtasks`→`save`→widget refresh); `group_tasks_screen`
(`_toggleSubtask` → `SubtaskCodec.parse/format` → `_service.updateTask`, живо синхронизиране към другите
членове). Версията остава 1.0.46+54 (потребителят: още не е качена в конзолата → ползвай същия номер).
AAB+web rebuild ✅, web deploy-нат (b7a69cc4), APK тестван на Note 9 (без крашове). analyze 0 нови грешки.

## 2026-06-15 · PC — Release bump + AAB + web deploy · v1.0.46+54
След теста на Note 9: bump **1.0.45+53 → 1.0.46+54**. `flutter build appbundle --release` → AAB 57.5MB
(чака ръчно качване в Play Console → Production). `flutter build web --release` → `npx wrangler pages
deploy build/web --project-name=taskify-app` → ✨ Deployment complete (62af210b.taskify-app.pages.dev →
app.taskify1969.com). **iOS:** всичко е cross-platform Dart + споделени assets → на Mac остава само
`git pull` → `flutter build ipa` (pod install за package_info_plus) → качване в App Store. Release notes
(Какво е новото) подготвени BG+EN — виж commit message / по-долу.

## 2026-06-15 · PC (Android) — Именен dataset + „За приложението" + групови подзадачи fix · v1.0.45+53
Три независими задачи, без version bump (тестов билд):
- **Част 1 — разширен именен dataset:** `assets/data/bg_name_days.json` заменен с пълния
  Wikipedia извлек (CC BY-SA 4.0): **120 фиксирани + 6 подвижни, ~769 имена** (старо: 26 дати,
  ~141). Доротея (6 фев), Никулден (6 дек) и стотици други вече присъстват. Новият формат ползва
  поле `offset` (старо беше `offsetFromOrthodoxEaster`) → `name_days_service.dart` приема и двете.
  `_full.json` изтрит (избягваме двоен asset в `assets/data/`). Тест `orthodox_easter_test.dart`
  минава (Великден 2026=12.4, Тодоровден 28.2 = offset -43 ✓).
- **Част 2 — секция „За приложението"** (най-долу в Настройки, 11 езика, inline `tr()` карти):
  динамична **Версия/билд чрез `package_info_plus`** (добавено в pubspec `^8.0.0`); подекран
  **„Как се ползва"** (`how_to_use_screen.dart`, 6 дружелюбни точки на „ти": добавяне на задача/NL,
  подзадачи+приоритет+повторение, Матрица, Календар+GCal, празници/именни дни/документи, споделени
  списъци); линкове Поверителност/Условия (`url_launcher`) + ред за лиценза на именните дни
  (Уикипедия CC BY-SA, линк към статията).
- **Част 3 — групови подзадачи fix:** AI breakdown за СПОДЕЛЕНА задача пазеше сурови заглавия без
  префикс → UI/броячът „X/Y" се чупеха. Нов общ helper `utils/subtask_format.dart` (`SubtaskCodec`
  parse/format/normalize за формата `"done:qty:text"`, толерира и legacy без префикс). `Task.subtasksList/
  setSubtasks/completedSubtasksCount` минават през него; `group_tasks_screen._breakdown` нормализира
  новите заглавия към `0:1:title`. Лични задачи непроменени.
- VERIFY: `flutter analyze` (само предходни info/deprecation, 0 нови грешки); web build ✅; Android
  APK ✅ (71MB); инсталиран по WiFi adb на **Note 9** (192.168.0.117:5555) и стартиран без крашове.
  (Потребителят каза „качи на Тото за тест" → достъпен беше само Note 9 на познатия WiFi adb адрес.)

## 2026-06-14 · PC — Web redeploy (Cloudflare Pages) · v1.0.45+53
`git pull --rebase` → already up to date (repo чист, без code промени). `flutter build web --release`
(142s, Wasm dry-run warnings само от `flutter_secure_storage_web` — игнорирани, ползваме JS build) →
`npx wrangler pages deploy build/web --project-name=taskify-app` → ✨ Deployment complete
(https://99c31342.taskify-app.pages.dev, live = app.taskify1969.com). Web сега носи целия споделен
Dart код от 1.0.45 (Споделени списъци + днешните фиксове).

## 2026-06-14 · PC (Android) — изравнен с iOS · v1.0.45+53
Целта: **Android и iOS на едно ниво.** Прод-ът беше 1.0.44+50 (build-нат ПРЕДИ днешните Mac фиксове);
Dart кодът е споделен → след `git pull` (824e095) всички фиксове са в repo-то, оставаше само нов
Android build.
- `flutter analyze` → 0 грешки (само стари info/warning). `flutter build apk --release` (71 MB) +
  `flutter build appbundle --release` (57.5 MB), версия от pubspec = **1.0.45+53** (build 53 > 50 прод
  → монотонно, валидно за Play).
- APK инсталиран на **Note 9** (adb WiFi 192.168.0.117:5555, `adb` извън PATH →
  `…/AppData/Local/Android/Sdk/platform-tools/adb.exe`), стартира чисто, без signature конфликт.
- Сега Android носи всички днешни споделени фиксове: „Разбий на стъпки" на груповата карта,
  реален цвят+локализирано име на категориите, AI breakdown в редактора, локал на датите, Pro следва
  акаунта (промо вкл. days-type).
- ОСТАВА: **ръчно качване на AAB в Play Console → Production** + live тест на групите от потребителя.

## 2026-06-14 · Mac — iOS подаване в App Store · v1.0.45 (53)
Цялата работа от деня (Споделени списъци + ръкописен widget + фиксове) подадена за ревю в App Store.
- **ВАЖНО:** 1.0.44 вече е **READY_FOR_SALE** на iOS (train затворен) → altool 409 „train 1.0.44 closed".
  Затова маркетинг версията е вдигната на **1.0.45** (+53). (Android прод си остава 1.0.44+50.)
- Build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer flutter build ipa --release
  --export-options-plist=ExportOptions.plist` (Xcode 26) → `xcrun altool --upload-app -t ios
  -f build/ios/ipa/Taskify.ipa --apiKey R342BR6F85 --apiIssuer 3f2713b7-...` → UPLOAD SUCCEEDED.
- ASC API (JWT ES256, /tmp/asc44.py): създадена версия **1.0.45** (id 7f62279c…), whatsNew en-US
  (EN+BG, БЕЗ емоджита) → „Shared lists" акцент + widget подобрения; build 53 закачен (PROCESSING→VALID);
  подаден за ревю.
- App ID 6768345070. Предходни: 1.0.44, 1.0.43 — READY_FOR_SALE. Виж [[ios-build-appstore]].

## 2026-06-14 · Mac — „Разбий на стъпки" на СПОДЕЛЕНАТА КАРТА (вярната диагноза) · v1.0.44+**52**
Скрийншоти от Toto разкриха истинския проблем: потребителят имаше предвид бутона **върху картата**
(разгъната задача), не в редактора. Личната карта (`ExpandableTaskCard`) показва „Разбий на стъпки"
през `onBreakdown`; груповата (`TaskCardView`, който ГО ПОДДЪРЖА) просто не получаваше callback-а.
- `group_tasks_screen`: подаден `onBreakdown: () => _breakdown(gt)`. Нов `_breakdown()` — Pro/лимит
  проверки → `AiService.breakdownTask` → loader → диалог за преглед → запис във **Firestore** през
  `_service.updateTask` (merge на подзадачите; `_taskToMap` не пипа completedBy/createdBy). Показва се
  само при 0 подзадачи (като личните карти). Добавени импорти: ProService/AiService/AiUsageService/paywall.
- Редакторският breakdown бутон (от +51) остава — допълва картата при редакция.
- Build +52, потвърден на Toto, нов процес стартиран на чисто (`process launch --terminate-existing`).

## 2026-06-14 · Mac — Поправки на 2-та фикса (breakdown бутон + цвят на живо) · v1.0.44+**51**
Потребителят тества на Toto: breakdown бутонът липсваше в споделените задачи + цветът не се
обновяваше. Двата ми фикса имаха реални дефекти — поправени:
- **Breakdown бутон.** Беше зад `if (aiParsingEnabled)` → при изключено AI парсване изчезваше.
  Сега е **ВИНАГИ видим** в секция Подзадачи (личният breakdown на картата също е безусловен);
  Pro/лимит проверките остават вътре в `runAiBreakdown`.
- **Цвят на категория на живо.** `group_tasks_screen` НЕ слушаше `categoryBox` (само Firestore
  stream-а) → смяна на цвят не пречертаваше. Добавен `Box.watch()` listener (initState/dispose) →
  `setState` при промяна на категория → `_accentFor` re-резолвва реалния цвят веднага.
- **Build номер вдигнат на +51.** Урок: дотук всички билдове бяха +50 → `devicectl ... info apps`
  показваше „50" независимо кой код е инсталиран → не можеше да се потвърди обновяване. Вече при всеки
  device тест ще вдигаме build номера, за да е проверимо. Toto потвърден на **1.0.44 (51)**.

## 2026-06-14 · Mac — Бъгове по „Споделени списъци" (TODO-то от 13.06) · v1.0.44+50
Минах TODO-то по ред. Важно: при одит се оказа, че **#1 и #3 вече бяха решени** в кода —
не фабрикувах фикс, поправих само реалните дефекти.
- **#1 Локализация — основно ОК.** Всички надписи в `screens/shared/*` + share текста
  (`group_service.dart`) минават през `AppText`/`_t`; валидирах всичките **477 `_t` мапа → 0 с
  липсващ език**; `LanguageScope` обвива `MaterialApp`. РЕАЛНИЯТ дефект беше **датите**:
  `group_tasks_screen._dateStr` ползваше `DateFormat.MMMd()/yMMMd()/Hm()` БЕЗ локал → английски
  имена на месеци сред друг език. Сменено на числов `dd.MM.yyyy · HH:mm` (като личния екран/календара,
  езиково неутрален); махнат `intl` import.
- **#2 Цветове на категориите.** Груповата карта оцветяваше по ХЕШ на името + показваше суровия
  текст. Нов `_categoryFor` резолвва потребителската категория по име → `_accentFor` връща РЕАЛНИЯ
  `colorValue` (реагира на промяна в „Управление на категории"); `_categoryDisplay` +
  `_localizedCategoryName` (вградените по id) → името е на текущия език. Fallback: чужда категория →
  стабилен цвят по име от палитрата; без категория → по приоритет.
- **#3 AI в редактиране → реално „разбиване на подзадачи в СПОДЕЛЕНИТЕ".** AI parse вече работеше в
  редактора (обединеният `TaskEditorBridge`). Липсваше breakdown: `_showAiBreakdownSheet` се вика само
  от личния списък и пише в Hive (`task.save()`) → неприложимо за Firestore GroupTask. Добавих **бутон
  „AI разбиване" ВЪТРЕ в редактора** (`runAiBreakdown` пълни `tempSubtasks`); при запис onSave връща
  draft-а с `setSubtasks(tempSubtasks)` → груповият onSave пише `task.subtasks` във Firestore. Работи и
  за лични, и за споделени.
- **#4 Pro следва акаунта.** Нов `ProService._restoreAccountPromo()` — Firestore
  `promo_codes where usedBy arrayContains uid` → авто-възстановяване при init/login (offline-safe,
  try/catch). Закачен `authStateChanges` слушател за бъдещ вход. **Lifetime** = приоритет.
  **Days-type СЕ възстановява вече**: при изкупуване пазим `redemptions.{uid}` = крайна дата (Timestamp)
  в Firestore (правилото `promo_codes allow update: if signedIn` го позволява), а restore-ът взима
  days-промото с най-далечна валидна дата. Повторно въвеждане на собствен валиден days код също го
  възстановява (вместо „вече използван"). Стари days-redemptions без полето → остават както досега.
- **Абонаменти (месечен/годишен) — проверени, БЕЗ промяна.** RevenueCat ги обработва: при старт
  `getCustomerInfo()` + `addCustomerInfoUpdateListener` авто-възстановяват активен абонамент на същия
  магазинен (Apple/Google) акаунт; има и ръчен бутон „Възстанови" в paywall-а (`restorePurchases()`).
  Entitlement `'Taskify 1969 Pro'`. Работи → не пипаме. (Само промо-кодовете бяха дупка — оправена.)
  Забележка: абонаментите следват МАГАЗИННИЯ акаунт, не Taskify/Firebase логина (няма `Purchases.logIn`)
  — cross-platform (Android→iOS със същия Taskify акаунт) НЕ се споделя; засега ОК по решение на потребителя.
- analyze: 0 грешки. Build Xcode 26 + install на Toto.

## 2026-06-14 · Mac (iOS) — Ръкописен шрифт за widget-а (като Android) · v1.0.44+50
iOS home-screen widget-ът вече ползва **Caveat** (ръкописен) за празното състояние, точно като Android.
- Шрифтът `caveat.ttf` копиран от Android в `ios/TaskifyWidget/Caveat.ttf`; регистриран в widget
  `Info.plist` (`UIAppFonts`) и добавен в Copy Bundle Resources на TaskifyWidget таргета
  (`add_widget_target.rb` излиза рано → ръчно през xcodeproj ruby; внимание: file ref path трябва да е
  само `Caveat.ttf`, не `TaskifyWidget/Caveat.ttf` — иначе удвоен път → CpResource fail).
- `TaskifyWidget.swift`: празната фраза е `Font.custom("Caveat-Regular", size: small?24:32)` +
  `.lineLimit(3)` + `.minimumScaleFactor(0.4)` → макс. едър ръкописен шрифт, който се **свива според
  дължината** и се събира без съкращения (аналог на Android `autoSizeText` 9–17/10–20sp). Яркост 0.92.
  Заглавията на задачите остават обикновен шрифт (1 ред) — пак като Android.
- **Верификация:** изолиран `xcodebuild -target TaskifyWidget` (симулатор) → BUILD SUCCEEDED; `.appex`
  съдържа `Caveat.ttf` + `UIAppFonts`. Визуален preview през еднократно SwiftUI host-app в симулатора
  (рендира 1:1 празното състояние) — изглежда коректно (дълга bg фраза пада на 3 реда, без отрязване).
- Build с Xcode 26 (DEVELOPER_DIR) и инсталиран на **Toto** през `devicectl`
  (UUID `2A76A482-7995-5D46-9567-3C7379343835`). НЕ App Store upload — само device install.
- **Допълнение:** iOS празните фрази бяха само 6 (bg/de/ru/en). Сега `WidgetPhrases.byLang` в
  `TaskifyWidget.swift` е огледало на Android `WidgetPhrases.kt` — **10 езика × 18 фрази** (ja→en
  fallback). Изборът остава „по час" (`msgs[h % count]`, нова фраза всеки час, цикъл през пълния
  списък) — за разлика от Android, който е случаен. Втори build + reinstall на Toto.

## 2026-06-13 · PC (Android) — Споделени списъци пуснати в Play Store · v1.0.44+50 PRODUCTION
Изпълних Android-задачата от Mac entry-то по-долу (Споделени списъци v1.0.44).
- `git pull --rebase` → взе целия групов код + version **1.0.44+50** (умен редактор, build 50).
- JDK 17 ✅; `flutter clean && flutter pub get` ✅; analyze няма нови грешки.
- **APK release билднат** (71.0 MB) и инсталиран на Note 9 по WiFi adb (192.168.0.117:5555).
  Старата инсталация беше Play-подписана → signature mismatch → деинсталирах и сложих локалния
  release (данните са в облака, връщат се при вход). Стартира чисто (onboarding). ⚠️ Пълният
  live тест на групите (вход + 2-ри акаунт + create/join/завършена-от/негативен) НЕ е правен —
  чака потребителя.
- **AAB release билднат** (57.4 MB) → `build/app/outputs/bundle/release/app-release.aab`.
- **Качен РЪЧНО в Play Console → Production** (rollout стартиран от потребителя). Release notes
  bg+en (Споделени списъци). Backend общ → НЯМА Android-специфична настройка (Firestore rules вече
  деплойнати от Mac; cloud_firestore + Auth + google-services.json на място).
- **Бонус (отложено):** проучихме автоматично качване през Google Play Developer API (service account
  + JSON ключ). Python 3.14 + `google-api-python-client`/`google-auth` инсталирани. Настройката иска
  интерактивни стъпки на потребителя (GCP service account + права в Play Console → Users & permissions).
  ВАЖНО: вече има GCP проект **`taskmasteruploader`** с RevenueCat service account (`revenuecat-
  integration@taskmasteruploader.iam.gserviceaccount.com`) → бъдеща автоматизация може да преизползва
  СЪЩИЯ проект (нов ключ + Releases права), без проект от нула. Засега качването остава ръчно.

### 🐞 TODO ЗА УТРЕ (бъгове по Споделени списъци — важат за ОБЕ версии, Android И iOS)
1. **Локализация на таб „Споделени" — СЧУПЕНА.** Надписите НЕ са на избрания език (смесена бъркотия
   от езици). Всички низове в `screens/shared/*` (shared_groups_screen, group_tasks_screen,
   group_invite_screen) + share текста в `group_service.dart` да минат през `AppText`/`_t({...})`
   на избрания език (11 езика), НЕ хардкоднат текст. (CLAUDE.md правило: никога hardcode.)
2. **Цветове на категориите в групите — НЕ се спазват/обновяват.** Груповите карти оцветяват по
   ХЕШ на името на категорията (`kCategoryColors` hash в `task_card_styles.dart`), не по реалния
   потребителски цвят → не съвпада с личните карти и НЕ се променя при редакция в „Управление на
   категории". Fix: вземай реалния цвят на категорията по име от потребителските категории и
   реагирай на промяна.
3. **AI-парсване в режим РЕДАКТИРАНЕ — липсва.** При редакция на задача (груповия редактор/моста)
   да има AI парсване, както при създаване на нова. Сега го има само при нова задача.
4. **(подобрение, дизайнирано днес) Pro да следва акаунта.** Промо-Pro сега е локален SharedPreferences
   флаг → губи се при реинсталация (трябва пак промо код въпреки логин). Fix: `ProService` нов
   `_restoreAccountPromo()` — Firestore заявка `promo_codes where usedBy arrayContains uid` →
   възстановява lifetime промо автоматично при init/login; try/catch, offline-safe. Lifetime (IVA)
   работи напълно; days-type иска допълнително пазене на redemption дата (облакът пази само usedBy[]).

## 2026-06-13 · Mac — Споделени групи (групови задачи), MVP · още НЕ е release
Нов **отделен** слой за споделени списъци между потребители — личният Hive/merge sync е
НЕДОКОСНАТ. Живее само във Firestore (real-time snapshots + вграден offline кеш, без Hive дублиране).
- **Firestore:** `groups/{id}` (name, ownerId, members[], memberInfo{uid:{name,email}}, inviteCode,
  server `createdAt/updatedAt`); `groups/{id}/tasks/{taskId}` (Task полета + categoryName като ТЕКСТ,
  createdBy/completedBy/completedAt, server updatedAt, `deleted` tombstone); `invites/{code}→{groupId}`.
- **firestore.rules (НОВ файл, рег. в firebase.json):** не-член не чете/пише; присъединяване само
  добавя СЕБЕ СИ (`addsOnlySelf`), напускане маха СЕБЕ СИ; само owner трие; `invites` get-only (list:false,
  без enumerate). ✅ **ДЕПЛОЙНАТ** в продукция (taskify-1969) — слят с existing rules (users + promo_codes
  ЗАПАЗЕНИ). Качен ръчно през Firebase Console (Rules editor), защото firebase login е интерактивен.
- **Код:** `models/group.dart`, `services/group_service.dart` (watchMyGroups/watchTasks, create/join/leave/
  delete, CRUD, лимити 10 групи/owner·20 члена·500 задачи, Crockford base32 код, share текст).
- **UI:** нов таб **„Споделени"** ЗАМЕНИ „Матрица" в долната навигация; Матрицата вече е иконка
  (`grid_view`) в AppBar-а на Задачи. Нови екрани `screens/shared/` (списък+create/join, задачи на живо
  с `TaskCardView` вкл. Билети тема + индикатор „завършена от…", покана+Share, членове).
- **Gating:** създаване = Pro; присъединяване = безплатно (viral loop). Локализация: ~28 низа × 11 езика.
- **Фиксове по време на теста:** (1) owner-лимитът броеше с `where('ownerId'==uid)` → rules забраняват
  тази заявка (четене само по `members`) → create-ът падаше ТИХО → сменено да брои моите групи по members
  клиентски; (2) UI вече показва и Firebase грешки (не само GroupException); (3) видими бутони „Нова група"/
  „Присъедини се с код" в празното състояние (AppBar иконите бяха незабележими).

- **ДЕПЛОЙ СТАТУС (всичко на най-новия код):**
  - **Web app = app.taskify1969.com** → Cloudflare **Pages проект `taskify-app`** (НЕ Firebase!). Деплой:
    `wrangler pages deploy build/web --project-name=taskify-app`. (taskify-1969.web.app на Firebase също обновен, но е резервен.)
  - **Лендинг = taskify1969.com** → отделен Cloudflare Pages проект **`taskify`** (статичен маркетинг сайт, НЕ в това репо).
  - **iOS Toto** → release билд (Xcode 26) инсталиран през `devicectl` (вж [[ios-build-appstore]]).
  - На този Mac СЕГА са логнати: **firebase CLI (ivoexp@gmail.com)** и **wrangler (Cloudflare)** → бъдещи
    деплои на rules/web стават директно оттук без Console.
  - ⚠️ Flutter web кешира агресивно (service worker + icon font) — след нов deploy ТРЯБВА hard clear
    (DevTools → Application → Unregister SW + Clear site data), иначе се вижда стар билд/празни икони.

- **Проверка:** analyze 0 грешки; web build ✅; live тест: създаване+присъединяване с код РАБОТИ (група „Семейство", 2 члена).
  Android APK НЕ е тестван (Mac няма Android SDK → провери на PC). iOS нативно непроменено.

- **РЕШЕНО при теста:**
  - ✅ **Двата „+" на екрана на групата** — „Покани" преместена в ⋮ менюто (с „Членове"/„Изтрий"), остава само FAB +. (commit 27ae3c2)
  - ✅ **„Липсващите" икони на web (Споделени/Документи)** — НЕ е код бъг. Деплойнатият MaterialIcons шрифт е
    ПЪЛНИЯТ (1,645,184 B, проверено на live). В **Safari иконите се виждат**. Беше **само Chrome service-worker
    кеш** (стар орязан шрифт от ерата „България"). Поука: след web deploy → hard clear (Unregister SW + Clear site
    data + Cmd+Q) ИЛИ тествай в друг браузър. НЕ пипай иконите в кода.

- **ДОВЪРШЕНО (2-ра част от сесията):**
  - ✅ **Богат диалог за задача в групата** (`_addOrEditTask`) — вече има **Подзадачи** (добавяне/чек/триене),
    повторение, категория (текст), бележки + досегашните приоритет/дата. Подзадачите се пазят като "0:text"/"1:text".
  - ✅ **Тема „Билети" по-наситена** — купончето alpha 0.14→0.22 (светла)/0.22→0.34 (тъмна) в `task_card_styles.dart`.
    Груповите карти получават ЦВЯТ по категория от `kCategoryColors` (хеш по име), не сив primary. По искане „като макета".
  - ✅ **Име за показване** — Настройки→Акаунт нов ред „Име" → Auth `displayName` + `GroupService.syncMyMemberInfo()`
    разпространява към `memberInfo` на всички мои групи. Показване: име→имейл→кратък id. Целта: да не се виждат имейли.
    **Rules обновени и РЕ-деплойнати** (`firebase deploy --only firestore:rules`, CLI логнат): нова `memberSafeUpdate()`
    — член може да обнови собственото си memberInfo/name БЕЗ да пипа members/ownerId.
  - **Deploy:** web (Cloudflare taskify-app) + iOS Toto (1.0.43+48) обновени с целия код. Commits до `cba4769`.

- **3-та част:** ✅ Груповият редактор стана богат, после — **ТОЧНО СЪЩИЯТ като таб „Задачи"** (умен мост,
  БЕЗ дублиране на 1100 реда и БЕЗ риск за продукцията):
  - Личният `_openTaskDialog` получи опционален `onSave` callback → при него **прескача Hive/календар/
    нотификации**, само връща готовата `Task`. Личният път (else) е НЕПРОМЕНЕН.
  - Нов публичен `TaskEditorBridge` (в `task_screen.dart`): TaskScreen регистрира `_current` (живее винаги в
    IndexedStack) → други екрани викат `TaskEditorBridge.open(existing:, onSave:)` и отварят СЪЩИЯ диалог.
  - `group_tasks_screen._addOrEditTask` вече само вика моста; onSave конвертира `Task ↔ GroupTask`
    (категория ↔ ИМЕ по личните категории) и пише във Firestore. → групите имат глас, NLP, AI, категории,
    напомняния, повторение, подзадачи, бележки — 1:1 като личния екран.
- ✅ **Версия 1.0.44** в App Store: build 49 (по-прост редактор) подаден, после потребителят го МАХНА от ревю;
  build **50** (умен редактор) билднат (Xcode 26), качен с altool (ключ R342BR6F85) и **подаден за ревю**
  (whatsNew EN+BG — **БЕЗ емоджи**, Apple ги отхвърля!). VID версия = `ba4f4353-...`. Скриптове: `/tmp/asc_50.py`.
- Web (Cloudflare taskify-app) + iOS Toto обновени с умния редактор. Commits до `3d673cd` (+ bump 50).

- **🤖 ANDROID (PC) — пускане на v1.0.44 със Споделени списъци:**
  Backend-ът е общ → НЯМА нужда от Android-специфична настройка за групите (cloud_firestore + Firebase Auth
  вече са конфигурирани; `google-services.json` е на място; **Firestore rules вече са деплойнати** от Mac —
  важат и за Android). Стъпки на PC:
  1. `git pull --rebase origin main` (вземи целия групов код + version **1.0.44+50**).
  2. JDK 17, после: `flutter clean && flutter pub get`.
  3. `flutter build appbundle --release` (за Play Store) или `flutter build apk --release` (за adb тест на Note 9).
     ⚠️ Android release се билдва САМО на PC — Mac-ът няма Android SDK НИТО release keystore (`android/key.properties`).
  4. Инсталирай на Note 9 по WiFi/adb и тествай:
     - вход → таб **„Споделени"** → Нова група (Pro) → код → присъединяване с 2-ри акаунт → задача на живо.
     - „+" отваря **СЪЩИЯ редактор като таб Задачи** (глас/AI/категории/напомняния/повторение/подзадачи/бележки);
       „завършена от [име]"; изтриване да не възкръсва.
     - **негативен тест:** не-член НЕ чете групата (permission-denied).
  5. Качи `app-release.aab` в Play Console → нов release, whatsNew (Споделени списъци).
  Бележки: табът „Споделени" замени „Матрица" (Матрицата е иконка в AppBar-а на Задачи). Премиум: създаване
  на група = Pro; присъединяване с код = безплатно. Лимити: 10 групи/owner, 20 члена, 500 задачи/група.

- **ОТВОРЕНИ TODO:**
  1. Тест на живо: изтриване (да не възкръсва) + негативен (не-член); Android build на PC (горе).
  2. (по желание) reminders/нотификации за групови задачи — извън MVP (per-device логика, Cloud Functions).

## 2026-06-12 · PC — anti-Russian мерки в worker-а (✅ решава Mac TODO-то)
Адресирано искането „нула руски" + Mac-овия TODO (breakdown понякога връщаше руски
повелителни форми: „Пригласи гостей", „Закажи место"). Двупластова защита в `Desktop/taskify-ai/`:
- **(1) Few-shot контрастен промпт** — `BREAKDOWN_SYSTEM(langName, lang)`; при `lang==='bg'`
  дава изрични примери ПРАВИЛНО (бг) vs ЗАБРАНЕНО (ру): „Покани гостите/Резервирай място"
  NOT „Пригласи гостей/Закажи место". Подсилени и parse/schedule промптите (забрана на ы,э,ё).
- **(2) Server-side детекция + авто-retry** — нов helper `runAI()` обвива `env.AI.run`; при
  не-руски език сканира изхода с `looksRussian()` (руски букви ы/э/ё; инфинитиви -ть/-ться/-тся,
  които българският няма; руски основи приглас/закаж/заказ/сдела/подарок/гостей/друзей; чисто
  руски думи). При засичане → ЕДИН retry с подсилен system („CRITICAL OVERRIDE… write only in BG").
  Внимание към фалшиви положителни: думи валидни и на български (задача, необходимо, ваш, отправ)
  СА ИЗКЛЮЧЕНИ от детекцията. Ползва се в parse, breakdown И schedule.
- **Тествано:** breakdown bg ×12 (рожден ден/ремонт/преместване) → чист български, 0 руски;
  parse bg/en + breakdown de непокътнати. Server-side, без app build. Deploy `npx wrangler deploy`.

---

## 2026-06-12 · Mac (iOS) — TODO за PC: руско изтичане в breakdown
- Тестван живият worker след PC фикса: parse чист, но **breakdown на bg понякога връща руски**
  думи вместо български (напр. „Пригласи гости" вм. „Покани гостите", „Закажи местонахождение"
  вм. „Резервирай място"). Функционално работи, чисто косметично.
- **ЗА ПC (worker е само там, `Desktop/taskify-ai/`):** в клона `mode === 'breakdown'`, в
  system/user промпта добави строго езиково ограничение (ползвай вече подаваната `${lang}`,
  за да важи за всичките 11 езика):
  `Write EVERY subtask strictly in the user's language (code: ${lang}). Do NOT use Russian or`
  `any other language. Bulgarian example: "Покани гостите"/"Резервирай място" — NOT the Russian`
  `"Пригласи гости"/"Закажи местонахождение".`
  parse промпта НЕ го пипай (чист е). Деплой: `cd Desktop/taskify-ai && npx wrangler deploy`.
  Тест: `curl -X POST <endpoint> -d '{"text":"организирай рожден ден","mode":"breakdown","lang":"bg"}'`
  → чист български, без руски. Потвърди и че parse още работи.

---

## 2026-06-12 · PC — AI worker model fix (parsing was dead)
- **Symptom:** AI Smart Parse / Breakdown / Schedule всички връщаха нищо — Cloudflare спря
  стария Workers AI модел `@cf/meta/llama-3.1-8b-instruct` (502 `AiError 5028 deprecated`,
  спрян 2026-05-30). По-рано в сесията сменено на `@cf/meta/llama-3.1-8b-instruct-fp8`
  (работеше, но тромав български).
- **Този ход:** качен на **`@cf/meta/llama-3.3-70b-instruct-fp8-fast`** — много по-чист
  български (breakdown вече дава нормални императиви: „купете подарък, поръчайте торта…").
- **Засечен капан:** 70B връща **OpenAI-style** отговор — `aiResp.response` е ВЕЧЕ ПАРСНАТ
  ОБЕКТ (+ `choices[0].message.content` като низ), докато 8B връщаше низ. Старият код
  `extractJSON(aiResp.response)` гърмеше с `text.match is not a function` (1101). Добавен
  helper **`modelJSON(aiResp)`** в worker-а — нормализира двата shape-а (обект / json-низ /
  choices fallback), ползван и в parse, и в breakdown, и в schedule. + top-level try/catch
  предпазна мрежа (връща stack при бъдеща смяна на модел).
- **Worker репо:** `Desktop/taskify-ai/` (НЕ е git, отделно от app репото) → деплой с
  `npx wrangler deploy`. Endpoint непроменен (`taskify-ai.cbndkbr92h.workers.dev`).
- **Server-side фикс — НЯМА нужда от нов app build/bump.** `lib/services/ai_service.dart`
  сочи същия endpoint и схемата е същата. Тествани и 3-те режима (bg+en), 200 OK.

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
