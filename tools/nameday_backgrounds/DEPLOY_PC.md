# Деплой на имен-ден фоновете (за Claude Code на PC)

## Къде са снимките
**8-те готови снимки са ТУК в repo-то:** `tools/nameday_backgrounds/bg-01.jpg … bg-08.jpg`
(Unsplash, без хора/лога, 1080×1350, компресирани <250KB. Свалени и тествани на Mac.)

## Какво прави
Уеб генераторът `tools/nameday_seo.py` (canvas картичка „Честит имен ден") вече рисува реална снимка
като фон. Снимките трябва да се сервират от `taskify1969.com/imen-den/backgrounds/bg-01..08.jpg`.
Ако папката липсва на живо → картичките ползват бранд градиента (fallback, нищо не се чупи).

## Стъпки (PC, PowerShell — нагласи пътищата към taskify-site-deploy)
```powershell
git pull

# 1) копирай снимките в източника на сайта
New-Item -ItemType Directory -Force ..\taskify-site-deploy\imen-den\backgrounds
Copy-Item tools\nameday_backgrounds\bg-0*.jpg ..\taskify-site-deploy\imen-den\backgrounds\

# 2) регенерирай 821-те страници (вече реферират backgrounds/)
python tools\nameday_seo.py
# → изход: %USERPROFILE%\Desktop\taskify_nameday_seo\imen-den\

# 3) копирай генерираните страници в източника (само imen-den/, не пипай другото)
xcopy "$env:USERPROFILE\Desktop\taskify_nameday_seo\imen-den" ..\taskify-site-deploy\imen-den /E /Y

# 4) деплой (Cloudflare Pages, Direct Upload)
cd ..\taskify-site-deploy
npx wrangler pages deploy . --project-name=taskify
```

## Проверка след деплой
- `https://taskify1969.com/imen-den/backgrounds/bg-01.jpg` → HTTP 200
- `https://taskify1969.com/imen-den/ime/ivan/` → картичката показва СНИМКА като фон + четимо име;
  бутон „🔄 Смени фон" сменя между 8-те снимки.

## Важно
- Копирай **само** папката `imen-den/` в site source — НЕ заменяй другите страници на сайта.
- Снимките са локални (същия домейн) → `canvas.toBlob` сваляне работи (без CORS tainting).
