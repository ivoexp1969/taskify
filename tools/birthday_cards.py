#!/usr/bin/env python3
"""Генератор на страници „Картички" за taskify1969.com.

Прави:
  /kartichki/    — хъб с избор: 🎉 Имен ден  /  🎂 Рожден ден
  /rozhden-den/  — генераторът на картички В РЕЖИМ „рожден ден" (име + незадължителна възраст)

★ЕДИН ИЗТОЧНИК★: card-генераторът (CARD_HTML/card_section) и CSS/page/CTA идват от
`nameday_seo.py` — тук НЕ се дублира client-side код. Разликата е само `occ='birthday'`
(заглавие/емоджи/възраст/име на файл/share) — същата картичка, която app-ът отваря през
`/imen-den/?type=birthday`. Фоновете се преизползват от `/imen-den/backgrounds/`.

Изход: ~/Desktop/taskify_cards/  →  копирай `kartichki/` и `rozhden-den/` в
Desktop/taskify-site-deploy/  →  npx wrangler pages deploy . --project-name=taskify
"""
import os
import nameday_seo as nd  # един източник за CSS, card_section, page, CTA, esc

OUT = os.path.expanduser("~/Desktop/taskify_cards")


def write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w", encoding="utf-8").write(content)


def main():
    # ---- ХЪБ /kartichki/ ----
    hub_body = """<div class="crumbs"><a href="https://taskify1969.com/">Taskify</a> › Картички</div>
<h1>Безплатни картички за близките ти 🎨</h1>
<p class="lead">Направи и си свали красива картичка за секунди — избери повод, напиши име,
избери фон и я сподели в Messenger, Viber или Instagram.</p>
<div class="choices">
<a class="choice" href="https://taskify1969.com/imen-den/">
<span class="emo">🎉</span><span class="t">Имен ден</span>
<span class="d">Картичка „Честит имен ден" + пълен български именник</span></a>
<a class="choice" href="https://taskify1969.com/rozhden-den/">
<span class="emo">🎂</span><span class="t">Рожден ден</span>
<span class="d">Картичка „Честит рожден ден" с име и години</span></a>
</div>
""" + nd.CTA_BLOCK
    write(os.path.join(OUT, "kartichki", "index.html"),
          nd.page("Безплатни картички — имен ден и рожден ден | Taskify",
                  "Направи и свали безплатна картичка за имен ден или рожден ден. Напиши име, избери фон и сподели. От Taskify.",
                  "https://taskify1969.com/kartichki/", hub_body))

    # ---- Генератор /rozhden-den/ (същият CARD_HTML, режим birthday) ----
    bday_body = """<div class="crumbs"><a href="https://taskify1969.com/kartichki/">Картички</a> › Рожден ден</div>
<h1>Картичка „Честит рожден ден" 🎂</h1>
<p class="lead">Напиши име (и по желание години), избери фон и си свали готова картичка.
Безплатно, без регистрация.</p>
""" + nd.card_section("", occ="birthday") + nd.CTA_BLOCK + """
<h2>Не пропускай нито един рожден ден</h2>
<p>Taskify е българското приложение за задачи, което помни рождените и имените дни на близките ти
и ти напомня навреме. Пиши задачите на естествен език, а AI ги разпознава. Работи на iPhone и Android.</p>"""
    write(os.path.join(OUT, "rozhden-den", "index.html"),
          nd.page("Картичка „Честит рожден ден“ — безплатно | Taskify",
                  "Направи безплатна картичка „Честит рожден ден“ с име и години. Избери фон и сподели в Messenger, Viber или Instagram. От Taskify.",
                  "https://taskify1969.com/rozhden-den/", bday_body))

    print(f"OUT: {OUT}")
    print("Страници: 2  (/kartichki/, /rozhden-den/)")


if __name__ == "__main__":
    main()
