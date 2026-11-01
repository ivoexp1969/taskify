# Taskify — пълно описание на функционалността

> Съставено **само от кода** (клон `free-tier-v2`), чрез четене, без промени в приложението.
> Всяка функция носи препратка `файл:ред`. Маркери: **[НЕДОВЪРШЕНО]**, **[СКРИТО]**, **[ДЕБЪГ]**.
> Където 1.0.70 се различава от production 1.0.69 (клон `main`) — отбелязано с **[Δ 1.0.70]**.
>
> ⚠️ Версия в `pubspec.yaml:4` = **1.0.69+79** (bump до 1.0.70+80 предстои при релийз). Тоест
> „1.0.70" тук = наличните в клона промени, още без вдигнат номер.

---

## 1. Обзор

- **Какво е:** приложение за управление на задачи (to-do) с календар, документи с изтичащ срок,
  споделени списъци, AI помощник, именни дни/празници и училищен/студентски режим.
- **Платформи:** Android, iOS и Web (един Flutter код).
  - Android: `minSdk = 26` (Android 8.0), `targetSdk = 36`, `compileSdk = 36` — `android/app/build.gradle:34,35,19`.
  - iOS: deployment target **15.0** — `ios/Podfile:1`, `ios/Runner.xcodeproj/project.pbxproj:607`.
  - Web: при `kIsWeb` приложението е **винаги Pro** и без реклами/известия — `pro_service.dart:174`, `pro_service.dart:208`.
- **Езици (13), от `utils/localization.dart:8-20`:** en (по подразбиране), bg, de, fr, it, el, es, pt,
  ru, tr, ja, nl, uk. Езикът се избира ръчно; по подразбиране `en` (`localization.dart:63,70`).
  Низовете са inline `_t({...})` карти, не `.arb`.
- **Съхранение:** Hive (задачи/категории, локално), SharedPreferences (настройки), Firebase
  Firestore (групи, промокодове, облачен sync, училищен календар), flutter_secure_storage (`pubspec.yaml`).
- **Монетизация:** RevenueCat (`purchases_flutter ^10.8.0`), AdMob (`google_mobile_ads ^5.2.0`),
  промокодове през Firestore. Entitlement = `Taskify 1969 Pro` (`pro_service.dart:99`); продукти
  `premium_monthly:monthly` / `premium_yearly:yearly` / `premium_lifetime` (`pro_service.dart:102-104`);
  пробен период **14 дни** (`pro_service.dart:96`).

---

## 2. Модули (по екрани)

### 2.1 Задачи (`screens/task/task_screen.dart`)
- **Какво прави потребителят → какво става:** създава/редактира/отмята/трие задачи; горе има
  лента със статистики (Общо/Предстоящи/Просрочени/Завършени). Бутон „+" (FAB) отваря редактор.
- Карта на задача = `ExpandableTaskCard` (notes преглед, тониране на просрочени, анимирани
  чекбоксове, точки за приоритет, прогрес-лента за подзадачи) — стандартният widget.
- Задача с категория **„Пазаруване" (`shopping`)** се отваря директно в bottom sheet списък,
  без разгъване — `task_screen.dart:1008`, `task_screen.dart:1055` → `ShoppingListScreen`.
- **Матрица на Айзенхауер** — иконка в AppBar (не отделен таб).
- **Споделени** — секция най-отгоре в списъка с групови задачи от всички групи (виж 2.5).
- **Гласово въвеждане** и **AI умно добавяне** (виж 2.6) са достъпни от редактора.
- **Лимити:** Free до **50 задачи** (`canAddTask` → `pro_service.dart:991-994`,
  `FreeLimits.maxTasks=50` `:80`); Free до **10 категории** (`canAddCategory` `:996-999`,
  `maxCategories=10` `:81`); при надхвърляне → paywall. Pro = неограничено.
- **Приоритет:** поле `priority` (int) — `models/task.dart:25`.

### 2.2 Календар (`screens/calendar/calendar_screen.dart`)
- Месечен/седмичен/дневен изглед (`table_calendar`), задачи по ден, добавяне от календара.
- Карта „Имен ден" за деня (виж 2.7); карти/действия за имен ден и рожден ден.
- **Free** (изгледът на календара) — **[Δ 1.0.70]** `FreeLimits.canUseCalendar = true`
  (`pro_service.dart:84`, коментар „v1.0.70: Календар (изглед) безплатен"). Самостоятелната
  синхронизация с Google/Apple е в „Облачна синхронизация" (виж 2.14).

### 2.3 Документи с изтичащ срок (`screens/documents/documents_screen.dart`, `screens/task/document_dialog.dart`)
- Проследяване на документи: типове `id_card, passport, license, insurance, inspection, vignette,
  other` (`document_dialog.dart:22-24`). Документът се пази като обикновена `Task` с
  `template == 'document'` (`document_dialog.dart:209,217`) → получава наготово Календар, „Днес",
  напомняния, облачен sync и статистики.
- Дълги изпреварвания за напомняния: 1 месец / 2 седмици / 1 седмица / 3 дни / 1 ден
  (`document_dialog.dart:27-29`); опционално „годишно подновяване".
- **Лимит Free = 3 активни документа** (`document_dialog.dart:34`, `freeLimit = 3`); СЪЗДАВАНЕ на
  4-ти → paywall (source `documents_limit`, `document_dialog.dart:62-68`). Редакция и триене на
  съществуващи са винаги разрешени (гейтът е само при създаване). **[Δ 1.0.70]** документите са
  безплатни до 3 (коментар в кода).

### 2.4 Списъци за пазаруване (`screens/task/shopping_list_screen.dart`)
- Задача от категория/шаблон „shopping" отваря bottom sheet списък директно (`task_screen.dart:1008`).
  Не е отделен модул — надстройка над задачите.

### 2.5 Споделени / групи (`services/group_service.dart`, `screens/shared/*`)
- Отделен слой във Firestore (real-time), независим от личния Hive. Групи с покани (invite codes),
  членове, групови задачи.
- **Лимити:** собственик до **10 групи** (`maxGroupsAsOwner=10`), до **20 членове** (`maxMembers=20`),
  до **500 активни задачи** на група (`maxActiveTasks=500`) — `group_service.dart:18-20`.
- **Гейт:** създаване на група = **Pro**; присъединяване = **безплатно** (виж списъка Free по-долу).
- Завършване на групова задача е author-gated (`toggleComplete`). Виж и **Известни проблеми** (6).

### 2.6 AI (`services/ai_service.dart`, `services/ai_usage_service.dart`)
- Сървър: Cloudflare Worker (извън това repo). Функции: **умно добавяне** (свободен текст → задача),
  **разбиване на стъпки/подзадачи**, **планиране**. Гласовото въвеждане подава текст към AI.
- **Лимит Free = 3 употреби на ден** (`ai_usage_service.dart:19` `dailyLimit = 3`; проверка
  `canUse`/`remainingToday` `:53-58`). Pro = неограничено (`:55`). Броячът се показва в
  „AI настройки" (`ai_settings_screen.dart:119`).

### 2.7 Имени дни и празници (`services/name_days_service.dart`, `services/holidays_service.dart`)
- Български именник от `assets/data/bg_name_days.json`. Карта „Имен ден" в Календара + известия.
- **[Δ 1.0.70]** Настройката се казва **„Имени дни (български)"** и **следва държавата**:
  `applyFirstRunDefault(country)` (`name_days_service.dart:150`) я включва по подразбиране само за
  BG; държавата е `holidays_country` (`holidays_service.dart:22,44`); ръчното изключване е траен
  opt-out (`name_days_manual_off`, `name_days_service.dart:116`).
- **Контакти с имен ден — [Δ 1.0.70: БЕЗПЛАТНО]:** on-device съвпадение (`flutter_contacts`,
  Android `READ_CONTACTS`), фонетична латиница. Контактите са free **навсякъде** (настройка,
  календар, известия): известието ползва пълния текст с имената за ВСИЧКИ потребители, без катинар
  (`_ndBodyFor`, `name_days_service.dart`); toggle-ът няма Pro гейт (`bulgaria_section.dart:154`);
  календарът показва списъка при включена функция, без isPro (`calendar_screen.dart:2101`). Старият
  заключен тийзър `NameDayTeaserCard` **вече не се ползва** (`task_screen.dart:840`). Нищо не напуска
  устройството.
- Известия за имен ден: макс. 20 насрочени напред (`name_days_service.dart:258`).
- Празници по държава — `holidays_service.dart`.

### 2.8 Ученически/студентски режим (`services/school_calendar_service.dart`, `services/university_service.dart`, `models/weekly_schedule.dart`)
- Режими **Ученик/Студент** (Профил → „Активирай режим"). Обратно броене до следваща ваканция;
  седмично разписание (четна/нечетна седмица, група); предстоящи изпити; таб „Обучение".
- Данните за учебната година идват от Firestore (`school_calendar/bg_YYYY_YYYY`) + вграден fallback.
- **Безплатно** (виралната кука движи инсталации).

### 2.9 Напомняния/известия (`services/notification_service.dart`, `flutter_local_notifications`)
- Токени за изпреварване: `minus_5m, minus_15m, minus_30m, minus_1h, minus_2h, minus_1d` +
  дълги `minus_3d, minus_1w, minus_2w, minus_1mo, minus_2mo` (`widgets/reminder_selector.dart:25-80`).
- Full-screen известия за аларми на Android 14+/API 36 (`USE_FULL_SCREEN_INTENT` в манифеста —
  задължително за релийз билд, виж CLAUDE.md).
- **Лимит Free = 3 напомняния на задача** (`FreeLimits.maxRemindersPerTask=3` `pro_service.dart:82`,
  `canAddReminder` `:1001-1004`).

### 2.10 Повторения (`models/task.dart:31`)
- `daily`, `weekly`, `monthly`, `yearly` или null. **Безплатно** (`FreeLimits.canUseRecurrence=true`).
- Триене на повтаряща се задача → диалог „текущата" / „всички бъдещи".

### 2.11 Категории и приоритети
- Готови категории: `documents, cal_events, work, personal, shopping, birthday, …`
  (`task_screen.dart:215`, дефиниции около `:187`). Потребителски категории до 10 (Free).
- Приоритет — поле `priority` (int), точки в картата.

### 2.12 Статистика (`screens/settings/statistics_screen.dart`, `fl_chart`)
- Графики за продуктивност. **Само Pro** (`FreeLimits.canUseStatistics=false` `pro_service.dart:85`).

### 2.13 Widgets (Android home-screen; `android/app/src/main/res/xml/*`)
- 3 размера: **2×1** (`task_widget_info.xml`), **3×1** (`task_widget_large_info.xml`), **4×2**
  (`task_widget_medium_info.xml`).
- Бутон „+" за бързо добавяне; локален контекст в widget-а (изтичащ документ > имен ден > празник).
- **Само Pro** (`FreeLimits.canUseWidget=false` `pro_service.dart:87`).

### 2.14 Синхронизация (`services/sync_service.dart`, `services/prefs_sync_service.dart`, `services/google_calendar_service.dart`)
- **Собствен облак (Firestore):** `users/{uid}/tasks` + `categories`, merge last-write-wins
  (`SyncService`). **Само Pro** (`FreeLimits.canUseCloudSync=false` `pro_service.dart:86`).
- **Разписание/профили:** `PrefsSyncService` — 3 документа `users/{uid}/prefs/{weekly_schedule,
  student_context,pupil_profile}`, whole-doc LWW; гейт = логнат не-анонимен акаунт.
- **Google Calendar — двупосочно:** push (`addTaskToCalendar` `google_calendar_service.dart:422`,
  `updateCalendarEvent` `:462`, `deleteCalendarEvent` `:547`) + импорт (`services/calendar_import_service.dart`)
  + „Премахни дубликати" (`:580`). OAuth чрез `google_sign_in`; статус в SharedPreferences
  (`google_calendar_connected`, `cloud_sync_section.dart:87`). Управлява се от „Облачна синхронизация"
  в Настройки. ⚠️ Дали самата връзка е Pro-гейтната — не е потвърдено с явен `isPro` гейт в
  `cloud_sync_section.dart`; собственият облачен sync обаче е Pro (горе).
- **Apple Calendar:** `device_calendar` (merge архитектура; iOS).

### 2.15 Профил / вход (`services/auth_service.dart`, `screens/profile/profile_screen.dart`, `screens/login_screen.dart`)
- **Методи:** имейл/парола — вход (`signInWithEmailAndPassword` `auth_service.dart:57,166`),
  регистрация (`createUserWithEmailAndPassword` `:137`), и **анонимна** сесия (`signInAnonymously`
  `:106`, за affiliate-attribution/локална работа).
- **Вход изисква потвърден имейл** — при невалидиран имейл се показва „Verify Your Email" и входът
  се спира (наблюдавано при тест в тази сесия). 20-сек таймаут на вход/регистрация
  (`auth_service.dart`, `dart:async`).
- Google Sign-In се ползва **само за Google Calendar OAuth**, не за вход в акаунта.
- Профил карта „Абонамент": статус (Pro/пробен/промо/безплатен) + оставащи дни
  (`profile_screen.dart:417`). **[Δ 1.0.70 / този клон]** подзаглавието вече не показва „оставащи
  дни" при lifetime промо/платец (поправен приоритет, `profile_screen.dart:425-435`).

### 2.16 Промокодове (`services/pro_service.dart:598+`, Firestore `promo_codes`)
- Прилагат се от paywall (поле „Имаш промо код?"). Типове: `lifetime` и `days`.
- **Входът е задължителен преди прилагане** (анонимната сесия не се брои; `paywall_screen.dart:287-297`).
- Pro следва акаунта: `usedBy[]` + `redemptions.{uid}` + огледало `users/{uid}/promo/current`
  (`pro_service.dart:724-752`), възстановяване при нов вход (`_restoreAccountPromo` `:474`).
- **[Δ 1.0.70 / този клон]:**
  - **Трупане** — `_promoStackBase()` = max(сега, край на trial, текущ край на промо); промо-дните
    лягат отгоре, не от „сега" (`pro_service.dart`, days-redeem път).
  - **Екран „Промокодът ти изтече"** — отделен флаг `promo_expired_dialog_shown` (нулиран при нов
    код), текст ×13, със списък Free/Pro (`home_screen.dart` `_maybeShowPromoExpiredDialog`).
  - **Analytics** `promo_redeemed` / `promo_expired`.
- ⚠️ **Изтичане се проверява по часовника на телефона** (`DateTime.now().isAfter(expiresAt)`,
  `pro_service.dart:623`); деплойнатите Firestore rules НЕ проверяват `expiresAt`. Планирано
  към сървър в 1.0.71 (виж `DEVLOG.md`, Known issues).

### 2.17 Настройки (`screens/settings/*`)
- Секции: **Профил**; **Език и регион**; **Външен вид** (теми, стилове карти, вкл. „Билетен"
  стил — Pro); **Задачи и AI**; **Облачна синхронизация**; **Morning Briefing**; **Локални данни**
  (износ/внос = Pro, `FreeLimits.canUseExportImport=false` `pro_service.dart:89`); **„България"**
  (имени дни, училищен режим); **За приложението** (динамична версия чрез `package_info_plus`);
  секция **„Още от 1969"** (кръстосана промоция към приложението „Навици", `com.ivoexp.habits`).
- „Стани Pro" карта (`go_pro_card.dart`) + „Възстанови покупки" — показват се **само за не-Pro**.
- **Pomodoro:** реален 25-мин таймер (`widgets/pomodoro_timer_sheet.dart`), стартира се от задача
  (`task_list_tile.dart`), споменат и в онбординга.

---

## 3. Таблица Free / Premium (1.0.70)

Източник: `pro_service.dart` клас `FreeLimits:80-93` + гейт-getters `:1006-1014`, `ai_usage_service.dart:19`,
`document_dialog.dart:34`, `group_service.dart:18-20`.

| Функция | Free | Pro |
|---|---|---|
| Задачи | до **50** (`maxTasks=50`) | неограничено |
| Категории | до **10** (`maxCategories=10`) | неограничено |
| Напомняния на задача | до **3** (`maxRemindersPerTask=3`) | неограничено |
| Документи (активни) | до **3** (4-ти → paywall) | неограничено |
| AI (умно добавяне/разбиване) | **3 / ден** (`dailyLimit=3`) | неограничено |
| Повторения | ✅ (`canUseRecurrence`) | ✅ |
| Календар (изглед) | ✅ **[Δ 1.0.70]** (`canUseCalendar=true`) | ✅ |
| Гласово въвеждане | ✅ (`canUseVoiceInput`) | ✅ |
| Теми / език | ✅ (`canChangeTheme`/`canChangeLanguage`) | ✅ |
| Имени дни + празници (вкл. контакти) | ✅ **[Δ 1.0.70]** (контактите вече са free, без катинар) | ✅ |
| Присъединяване към споделен списък | ✅ | ✅ |
| Създаване на споделен списък/група | ❌ → paywall | ✅ |
| Статистика | ❌ (`canUseStatistics=false`) | ✅ |
| Облачна синхронизация | ❌ (`canUseCloudSync=false`) | ✅ |
| Widgets (Android) | ❌ (`canUseWidget=false`) | ✅ |
| Износ/внос на данни | ❌ (`canUseExportImport=false`) | ✅ |
| Реклами | **да** (`showAds=true`) | не |

- **Пробен период:** 14 дни (`trialPeriodDays=14`). Trial банер на home — само в последните
  ≈4 дни (`trialDaysLeft` 0–4) и ако не е затворен за деня (`home_screen.dart` `_showTrialBannerNow`);
  ден 1 се покрива от welcome диалога. Статус в Профил: „Pro (пробен период - N дни)".
- **Реклами:** един **banner** (AdMob) най-долу в home scaffold-а (`home_screen.dart:850`,
  `BannerAdWidget`), виден на всички табове за Free. **Не са намерени interstitial реклами** в кода.

---

## 4. Платформени разлики (Android ↔ iOS)

| | Android | iOS | Web |
|---|---|---|---|
| Реклами (AdMob) | ✅ | ✅ | ❌ (kIsWeb) |
| Home widgets | ✅ (2×1/3×1/4×2) | ❌ (няма Android widget-и) | ❌ |
| Pro статус | реален (RevenueCat/trial/промо) | реален | **винаги Pro** (`pro_service.dart:174`) |
| Известия | local notifications + full-screen intent | local notifications | ❌ |
| Детекция на „Навици" | `installed_apps` (Android-only плъгин) | URL scheme `taskify://` (`Info.plist`) | — |
| In-app update | `in_app_update` (Android-only) | App Store | — |
| Контакти | `READ_CONTACTS` | `NSContactsUsageDescription` | — |
| Мин. версия | Android 8.0 (SDK 26) | iOS 15.0 | — |

- Гласово въвеждане: `speech_to_text` се ползва на `task_screen`/редактора/home.

---

## 5. Известни проблеми / пропуски (видими в кода)

1. **Напомнянията на споделени (групови) задачи не пораждат локални известия.** Груповите задачи
   пазят поле `reminders` (`group_tasks_screen.dart:243,276,332,350`; `group_service.dart:255`), но в
   груповия слой **няма извикване на** `NotificationService().scheduleForTask(...)` → зададените
   напомняния на споделена задача не звънят локално (за разлика от личните задачи).
2. **Промокод изтичане е клиентско (по часовника на телефона)** — `pro_service.dart:623`
   (`DateTime.now().isAfter(expiresAt)`), а деплойнатите rules не валидират `expiresAt`. Назад-наместен
   часовник може да заобиколи. Планирано сървърно в **1.0.71** (`DEVLOG.md`, TODO).
3. **Екранът „Промокодът ти изтече" зависи от повторна проверка при resume**, защото
   `ProService().initialize()` е извикан с `.then()` (не awaited) в `main.dart:160` → при студен старт
   кешираният `is_pro` може временно да е true. Добавена е повторна проверка при resume
   (`home_screen.dart` `_maybeShowLateTransition`) — иначе екранът можеше да се пропусне.
4. **Личните задачи нямат действие „сподели в група"** (само отделен групов слой; виж `DEVLOG.md`).
   > Бел.: `dayName()/dayShort()` **покриват всички 13 езика, вкл. `ja`** (`localization.dart:538-577`)
   > — предишно твърдение за липсващ японски беше невярно и е премахнато.
5. **[ДЕБЪГ]** На Login екрана има дребно layout препълване („RIGHT OVERFLOWED BY 4.2 PIXELS" върху
   бутона „Регистрация") — видимо само в debug билд.
6. **[ДЕБЪГ]** `utils/debug_overrides.dart` — само в `kDebugMode` (fake „сега", forceTrialExpired);
   не влияе на release.

---

## 6. Analytics събития (`services/analytics_service.dart`)

**Събития** (`_log(...)`): `app_first_open`, `day_2_active`, `onboarding_started`,
`onboarding_completed`, `first_task_created`, `task_created`, `task_completed`,
`first_mode_activated`, `mode_changed`, `locked_feature_tap`, `paywall_shown`, `paywall_view`,
`paywall_select`, `purchase_start`, `purchase_success`, `purchase_fail`, `restore`,
`promo_login_required`, `promo_login_completed`, `promo_redeemed` (type, days, source),
`promo_expired` (promo_type), `trial_start`, `trial_end`, `trial_banner_shown`,
`trial_banner_dismissed`, `companion_app_shown`, `companion_app_clicked`, `companion_app_dismissed`.

**User properties:** `pro_state` ∈ {paid, promo, trial, free} (`:276`), `active_mode` ∈
{pupil, student, none} (`:196`), `app_locale` (езиков код, `:202`).

Телеметрията е тиха при грешка и **no-op на web** (`analytics_service.dart`). Нула лични данни
(`task_created` носи само `task_type`, не съдържание; bulk restore е изключен).
