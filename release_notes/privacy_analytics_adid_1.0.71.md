# Analytics без рекламен ID (AAID/IDFA) + privacy текстове — 1.0.71

Контекст: v1.0.71 добавя opt-out „Анонимна статистика" в приложението. Privacy
политиката (taskify1969.com) трябва да се обнови поетапно. Проверено на 2026-11-03:
Firebase Analytics СЪБИРАШЕ рекламния ID по подразбиране (AdMob наличен, нямаше
изключване), затова твърдението „IDFA — изключен" беше махнато от live privacy.

## Състояние
- ✅ **Live сайт (2026-11-03):** махнат САМО редът „IDFA — изключен" (EN+BG). Opt-out
  параграфът остава старият (имейл), датата остава 30 юни 2026 — превключвателят още
  не е пуснат.
- ✅ **Android (клон `empty-state-first-task`):** добавен в `AndroidManifest.xml`:
  `google_analytics_adid_collection_enabled` = `false` (спира AAID за Analytics;
  AdMob рекламите ползват ad ID отделно). Проверка при release билда: merged manifest
  да съдържа флага.
- ⏳ **iOS (ЗА MAC — НЕ пипано на PC):** за да спре FirebaseAnalytics да ползва IDFA
  през CocoaPods, добави в НАЧАЛОТО на `ios/Podfile` (преди `target 'Runner'`, напр.
  след реда с `ENV['COCOAPODS_DISABLE_STATS']`):

      $FirebaseAnalyticsWithoutAdIdSupport = true

  После `cd ios && pod install` (при нужда `pod update FirebaseAnalytics`). Това сменя
  `GoogleAppMeasurement` → `GoogleAppMeasurement/WithoutAdIdSupport` в Podfile.lock.
  ⚠️ **Mac да ПРОВЕРИ:** (1) Podfile.lock реално резолвва WithoutAdIdSupport; (2) няма
  конфликт с `google_mobile_ads` (AdMob) — ако AdMob налага ad-id варианта, iOS
  декларацията „без рекламен ID" може да НЕ важи за iOS → тогава point 4 текстът да е
  Android-only или със забележка. (3) Приложението билдва и стартира.

## Point 2 — резервиран текст за ДЕНЯ на 1.0.71 (когато билдът излезе)
Секция 10, opt-out параграф (замества стария „имейл" параграф). + вдигни датата на
деня на релийза (EN „Last updated" / BG „Последна актуализация").

**EN:**
```html
<p>Analytics collection is enabled by default to improve the product. You can turn it
off at any time in the app — <strong>Settings → About → "Anonymous statistics"</strong>.
The change takes effect immediately. As an alternative, you can also email us at
<a href="mailto:ivoexp@yahoo.com">ivoexp@yahoo.com</a>. Data is processed by Google under
the <a href="https://firebase.google.com/support/privacy" target="_blank" rel="noopener">Google Analytics for Firebase Privacy Policy</a>.</p>
```

**BG:**
```html
<p>Analytics събирането е активно по подразбиране за подобряване на продукта. Можеш да
го изключиш по всяко време в приложението — <strong>Настройки → За приложението →
„Анонимна статистика“</strong>. Промяната действа веднага. Като алтернатива можеш да ни
пишеш и на <a href="mailto:ivoexp@yahoo.com">ivoexp@yahoo.com</a>. Данните се обработват
от Google съгласно <a href="https://firebase.google.com/support/privacy" target="_blank" rel="noopener">Google Analytics for Firebase политиката за поверителност</a>.</p>
```

## Point 4 — СЛЕД като 1.0.71 излезе на ДВЕТЕ платформи
Добави в секция 10 (напр. нов ред в „Какво НЕ събираме" ИЛИ изречение в параграфа).
⚠️ Само ако iOS WithoutAdIdSupport е потвърден (виж iOS caveat); иначе формулирай
Android-only.

- **EN:** `Analytics does not use an advertising identifier (since v1.0.71); advertising is described in section 6.`
- **BG:** `Анализите не използват рекламен идентификатор (от версия 1.0.71); рекламите са описани в секция 6.`

Деплой на сайта: `cd ~/Desktop/taskify-site-deploy && wrangler pages deploy . --project-name=taskify`
(wrangler е логнат с OAuth; `backgrounds/` е под `imen-den/`, не в корена).
