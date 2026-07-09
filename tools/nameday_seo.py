#!/usr/bin/env python3
"""Генератор на SEO „именник" страници за taskify1969.com/imen-den/.
От official dataset прави статични HTML страници (чисти URL-и), таргетиращи
високо-интентни бг търсения: „кога е имен ден на [име]", „кой празнува на [дата]",
„имен ден днес". Всяка страница: уникален title/description, canonical, OG, JSON-LD
(FAQ), вътрешни връзки, CTA към стора. Изход: ~/Desktop/taskify_nameday_seo/imen-den/

ДЕПЛОЙ (сайтът е Direct Upload на Cloudflare Pages, източник на PC):
  копирай папката `imen-den/` в източника на сайта (Desktop/taskify-site-deploy/)
  → `npx wrangler pages deploy . --project-name=taskify`
"""
import os, json, datetime, re, html

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(REPO, "assets/data/bg_name_days.json")
OUT = os.path.expanduser("~/Desktop/taskify_nameday_seo/imen-den")
BASE = "https://taskify1969.com/imen-den"
APP_STORE = "https://apps.apple.com/app/id6768345070"
PLAY = "https://play.google.com/store/apps/details?id=com.ivoexp.taskify"
MONTHS = ["", "януари", "февруари", "март", "април", "май", "юни", "юли",
          "август", "септември", "октомври", "ноември", "декември"]

# ---- Транслитерация кирилица→латиница за slug (по Закон 2009) ----
TR = {'а':'a','б':'b','в':'v','г':'g','д':'d','е':'e','ж':'zh','з':'z','и':'i',
      'й':'y','к':'k','л':'l','м':'m','н':'n','о':'o','п':'p','р':'r','с':'s',
      'т':'t','у':'u','ф':'f','х':'h','ц':'ts','ч':'ch','ш':'sh','щ':'sht',
      'ъ':'a','ь':'y','ю':'yu','я':'ya'}


def slug(name):
    s = "".join(TR.get(c, c) for c in name.lower())
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s or "ime"


def esc(s):
    return html.escape(s, quote=True)


# ---- Orthodox Easter (за движими празници) ----
def orthodox_easter(year):
    a, b, c = year % 4, year % 7, year % 19
    d = (19 * c + 15) % 30
    e = (2 * a + 4 * b - d + 34) % 7
    m = (d + e + 114) // 31
    dd = ((d + e + 114) % 31) + 1
    return datetime.date(year, m, dd) + datetime.timedelta(days=13)


CSS = """
:root{--p:#6A3DE8;--pd:#4A28AA;--g:#0AA674;--glt:#2EC494}
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
color:#1a1730;background:#f6f5fb;line-height:1.6}
a{color:var(--p);text-decoration:none}a:hover{text-decoration:underline}
header{background:linear-gradient(135deg,var(--p),var(--pd));color:#fff;padding:34px 20px;text-align:center}
header .brand{font-weight:700;font-size:20px;opacity:.9}
.wrap{max-width:820px;margin:0 auto;padding:24px 20px 60px}
h1{font-size:2em;margin:18px 0 6px;color:var(--pd)}
h2{font-size:1.35em;margin:30px 0 12px;color:var(--p)}
.date{display:inline-block;background:var(--g);color:#fff;padding:8px 18px;border-radius:30px;font-weight:700;margin:8px 0}
.names,.grid{display:flex;flex-wrap:wrap;gap:8px;margin:12px 0}
.names a,.grid a{background:#fff;border:1px solid #e4e0f3;padding:8px 14px;border-radius:20px;font-weight:600}
.cta{display:block;background:var(--g);color:#fff;text-align:center;padding:16px;border-radius:14px;
font-weight:700;font-size:1.1em;margin:26px 0 10px}
.stores{display:flex;gap:12px;justify-content:center;flex-wrap:wrap;margin:12px 0}
.stores a{background:#1a1730;color:#fff;padding:12px 22px;border-radius:12px;font-weight:600}
.crumbs{font-size:.85em;color:#777;margin-bottom:6px}
.card{background:#fff;border:1px solid #e9e6f5;border-radius:16px;padding:22px;margin:16px 0}
footer{background:#1a1730;color:#cbc7dd;text-align:center;padding:26px 20px;font-size:.9em}
footer a{color:var(--glt)}
.lead{font-size:1.1em;color:#4a4568}
"""


def page(title, desc, canonical, body, jsonld=None):
    ld = f'<script type="application/ld+json">{json.dumps(jsonld, ensure_ascii=False)}</script>' if jsonld else ""
    return f"""<!DOCTYPE html><html lang="bg"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{esc(title)}</title>
<meta name="description" content="{esc(desc)}">
<link rel="canonical" href="{canonical}">
<meta property="og:type" content="website"><meta property="og:title" content="{esc(title)}">
<meta property="og:description" content="{esc(desc)}"><meta property="og:url" content="{canonical}">
<meta property="og:site_name" content="Taskify"><meta name="robots" content="index,follow">
<style>{CSS}</style>{ld}</head><body>
<header><div class="brand">Taskify</div></header><div class="wrap">{body}</div>
<footer>Направено с любов от <a href="https://taskify1969.com">Taskify</a> —
българското приложение за задачи с имени дни, празници и напомняния.<br>
Данни: Уикипедия „Имен ден" (CC BY-SA 4.0).</footer></body></html>"""


CTA_BLOCK = f"""
<a class="cta" href="https://taskify1969.com">Свали Taskify — напомня ти за всеки имен ден</a>
<div class="stores"><a href="{APP_STORE}">App Store</a><a href="{PLAY}">Google Play</a></div>
"""


def write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w", encoding="utf-8").write(content)


def main():
    data = json.load(open(DATA, encoding="utf-8"))
    year = datetime.date.today().year

    # индекс: име -> {dates:[(label, url, sortkey)], feast}
    name_dates = {}   # name -> list of (label, mmdd_or_movablekey, feast, date_obj|None)
    date_entries = []  # (date_obj, mmdd, names, feast) за fixed
    for r in data["fixed"]:
        mm, dd = map(int, r["date"].split("-"))
        d = datetime.date(year, mm, dd)
        date_entries.append((d, r["date"], r["names"], r.get("feast")))
        for n in r["names"]:
            name_dates.setdefault(n, []).append(
                (f"{dd} {MONTHS[mm]}", f"{BASE}/data/{r['date']}/", r.get("feast"), d))
    for r in data["movable"]:
        d = orthodox_easter(year) + datetime.timedelta(days=r["offset"])
        for n in r["names"]:
            name_dates.setdefault(n, []).append(
                (f"{d.day} {MONTHS[d.month]} ({year} г.)", None, r.get("feast"), d))

    # уникални slug-ове
    slugs = {}
    for n in sorted(name_dates):
        s = slug(n); base = s; i = 2
        while s in slugs.values(): s = f"{base}-{i}"; i += 1
        slugs[n] = s

    pages = 0
    # ---- Страници по ИМЕ ----
    for n, dates in sorted(name_dates.items()):
        s = slugs[n]
        url = f"{BASE}/ime/{s}/"
        labels = ", ".join(sorted({d[0] for d in dates}))
        feast = next((d[2] for d in dates if d[2]), None)
        title = f"Кога е имен ден на {n}? — {labels} | Taskify"
        desc = f"{n} празнува имен ден на {labels}." + (f" Празник: {feast}." if feast else "") + \
               f" Виж кой друг празнува и си сложи напомняне в Taskify."
        same = []
        for lab, durl, fe, dobj in dates:
            if durl:
                # имена на същата дата
                for de in date_entries:
                    if de[1] == durl.rstrip("/").split("/")[-1]:
                        same = [(x, slugs.get(x)) for x in de[2] if x != n and x in slugs]
        body = f"""<div class="crumbs"><a href="{BASE}/">Именник</a> › {esc(n)}</div>
<h1>Кога е имен ден на {esc(n)}?</h1>
<p class="lead">{esc(n)} празнува имен ден на:</p>
<div><span class="date">{esc(labels)}</span></div>
{f'<p>Църковен празник: <strong>{esc(feast)}</strong>.</p>' if feast else ''}
{CTA_BLOCK}
{('<h2>На същата дата празнуват и</h2><div class="grid">'+''.join(f'<a href="{BASE}/ime/{sl}/">{esc(x)}</a>' for x,sl in same[:40])+'</div>') if same else ''}
<h2>Не пропускай нито един имен ден</h2>
<p>Taskify е българското приложение за задачи, което помни всички имени дни, официалните
празници и ти напомня навреме — за да честитиш на близките си. Пиши задачите на естествен
език, а AI ги разпознава. Работи на iPhone и Android.</p>"""
        ld = {"@context":"https://schema.org","@type":"FAQPage","mainEntity":[{
            "@type":"Question","name":f"Кога е имен ден на {n}?",
            "acceptedAnswer":{"@type":"Answer","text":f"{n} празнува имен ден на {labels}." + (f" Църковен празник: {feast}." if feast else "")}}]}
        write(os.path.join(OUT, "ime", s, "index.html"),
              page(title, desc, url, body, ld)); pages += 1

    # ---- Страници по ДАТА ----
    for d, mmdd, names, feast in date_entries:
        url = f"{BASE}/data/{mmdd}/"
        lab = f"{d.day} {MONTHS[d.month]}"
        title = f"Кой има имен ден на {lab}? {(feast+' — ') if feast else ''}Taskify"
        desc = f"На {lab} имен ден празнуват: {', '.join(names)}." + (f" Празник: {feast}." if feast else "")
        body = f"""<div class="crumbs"><a href="{BASE}/">Именник</a> › {esc(lab)}</div>
<h1>Кой празнува имен ден на {esc(lab)}?{(' — '+esc(feast)) if feast else ''}</h1>
<div class="names">{''.join(f'<a href="{BASE}/ime/{slugs[x]}/">{esc(x)}</a>' for x in names)}</div>
{CTA_BLOCK}
<p>Taskify ти напомня за всеки имен ден и официален празник — безплатно, на български.</p>"""
        write(os.path.join(OUT, "data", mmdd, "index.html"),
              page(title, desc, url, body)); pages += 1

    # ---- HUB /imen-den/ ----
    all_names = sorted(name_dates)
    name_links = "".join(f'<a href="{BASE}/ime/{slugs[n]}/">{esc(n)}</a>' for n in all_names)
    months_html = ""
    by_month = {}
    for d, mmdd, names, feast in sorted(date_entries):
        by_month.setdefault(d.month, []).append((d, mmdd, feast))
    for m in range(1, 13):
        if m not in by_month: continue
        days = "".join(f'<a href="{BASE}/data/{mm}/">{dd.day}{(" "+fe) if fe else ""}</a>'
                       for dd, mm, fe in by_month[m])
        months_html += f"<h2>{MONTHS[m].capitalize()}</h2><div class='grid'>{days}</div>"
    # JS „днес"
    today_map = {mmdd: names for d, mmdd, names, fe in date_entries}
    hub_body = f"""<h1>Български именник — кой има имен ден днес?</h1>
<p class="lead" id="today">Зареждане…</p>
{CTA_BLOCK}
<h2>Търси по име</h2><div class="grid">{name_links}</div>
<h2>По дата</h2>{months_html}
<script>
const M=["", "януари","февруари","март","април","май","юни","юли","август","септември","октомври","ноември","декември"];
const T={json.dumps(today_map, ensure_ascii=False)};
const n=new Date();const k=String(n.getMonth()+1).padStart(2,'0')+'-'+String(n.getDate()).padStart(2,'0');
const el=document.getElementById('today');
if(T[k]){{el.innerHTML='🎉 Днес, '+n.getDate()+' '+M[n.getMonth()+1]+', имен ден празнуват: <strong>'+T[k].join(', ')+'</strong>. Честито!';}}
else{{el.textContent='Днес няма голям имен ден по календара. Разгледай по име или дата по-долу.';}}
</script>"""
    write(os.path.join(OUT, "index.html"),
          page("Български именник — имени дни по име и дата | Taskify",
               "Кой има имен ден днес? Търси имен ден по име или дата. Пълен български именник с празници. Taskify ти напомня навреме.",
               f"{BASE}/", hub_body)); pages += 1

    # ---- sitemap ----
    urls = [f"{BASE}/"] + [f"{BASE}/ime/{slugs[n]}/" for n in all_names] + \
           [f"{BASE}/data/{mmdd}/" for _, mmdd, _, _ in date_entries]
    sm = '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
    sm += "".join(f"<url><loc>{u}</loc></url>\n" for u in urls) + "</urlset>\n"
    write(os.path.join(OUT, "sitemap.xml"), sm)

    print(f"OUT: {OUT}")
    print(f"Страници: {pages}  (по име: {len(all_names)}, по дата: {len(date_entries)}, hub: 1)")
    print(f"Sitemap: {len(urls)} URL-а")


if __name__ == "__main__":
    main()
