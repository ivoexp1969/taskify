#!/usr/bin/env python3
"""Генератор на SEO „именник" страници за taskify1969.com/imen-den/.
От official dataset прави статични HTML страници (чисти URL-и), таргетиращи
високо-интентни бг търсения: „кога е имен ден на [име]", „кой празнува на [дата]",
„имен ден днес". Всяка страница: уникален title/description, canonical, OG, JSON-LD
(FAQ), вътрешни връзки, CTA към стора. Изход: ~/Desktop/taskify_nameday_seo/imen-den/

Индексируеми (index + sitemap): TOP_NAMES (150 имена) + всички дати + 12 месеца
(/mesec/{месец}/) + /podvizhni/ + хъба. Останалите имена: noindex,follow, извън sitemap-а.
lastmod идва от tools/nameday_seo_lastmod.json (хеш на съдържанието) — комитвай го след run.

ДЕПЛОЙ (сайтът е Direct Upload на Cloudflare Pages, източник на PC):
  1. python tools/nameday_seo.py            (комитни tools/nameday_seo_lastmod.json)
  2. python tools/nameday_seo.py --root-sitemap <taskify-site-deploy>/sitemap.xml [--fix]
     → главният sitemap НЕ трябва да съдържа noindex имената (--fix ги маха, пази .bak)
  3. копирай папката `imen-den/` в източника на сайта (Desktop/taskify-site-deploy/)
     → `npx wrangler pages deploy . --project-name=taskify`
"""
import os, json, datetime, re, html, hashlib, argparse

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(REPO, "assets/data/bg_name_days.json")
OUT = os.path.expanduser("~/Desktop/taskify_nameday_seo/imen-den")
BASE = "https://taskify1969.com/imen-den"
APP_STORE = "https://apps.apple.com/app/id6768345070"
PLAY = "https://play.google.com/store/apps/details?id=com.ivoexp.taskify"
# App Store campaign provider token (App Store Connect → App Analytics → Sources → Campaigns →
# „Generate a Campaign Link"). Празен → обикновен линк без pt/ct.
APPSTORE_PT = ""
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
.cardgen{background:#fff;border:1px solid #e9e6f5;border-radius:16px;padding:22px;margin:22px 0;text-align:center}
.cardgen h2{margin-top:0}
.cardgen input{width:100%;max-width:360px;padding:12px 16px;border:2px solid #e4e0f3;border-radius:12px;font-size:1em;margin:6px 0 16px;text-align:center}
.cardgen canvas{width:100%;max-width:340px;height:auto;border-radius:16px;box-shadow:0 6px 24px rgba(74,40,170,.25);display:block;margin:0 auto}
.cg-hint{margin:14px 0 6px;font-weight:600;color:#4a4568}
.cg-picker{display:flex;gap:8px;overflow-x:auto;padding:6px 2px 10px;scroll-snap-type:x proximity}
.cg-th{flex:0 0 auto;width:64px;height:80px;object-fit:cover;border-radius:10px;cursor:pointer;
border:3px solid transparent;opacity:.85;transition:opacity .15s;scroll-snap-align:start}
.cg-th:hover{opacity:1}
.cg-th.sel{border-color:var(--g);opacity:1}
.cg-btns{display:flex;gap:10px;justify-content:center;flex-wrap:wrap;margin-top:16px}
.cg-btns button{background:var(--g);color:#fff;border:0;padding:13px 24px;border-radius:12px;font-weight:700;font-size:1em;cursor:pointer}
.cg-btns button.sec{background:var(--p)}
.cardgen input#cgAge{max-width:220px}
.choices{display:flex;gap:16px;flex-wrap:wrap;margin:22px 0}
.choice{flex:1 1 260px;display:block;background:#fff;border:1px solid #e9e6f5;border-radius:18px;
padding:30px 22px;text-align:center;box-shadow:0 4px 18px rgba(74,40,170,.08);transition:transform .15s,box-shadow .15s}
.choice:hover{transform:translateY(-3px);box-shadow:0 10px 28px rgba(74,40,170,.16);text-decoration:none}
.choice .emo{font-size:3em;display:block;margin-bottom:8px}
.choice .t{font-size:1.3em;font-weight:800;color:var(--pd)}
.choice .d{color:#6b6685;font-size:.95em;margin-top:6px}
.pnav{display:flex;justify-content:space-between;gap:12px;margin:22px 0;font-weight:600}
.dlinks{margin:10px 0;font-weight:600}
.upcoming{margin:8px 0 8px 20px}.upcoming li{margin:4px 0}
.card h2{margin-top:0}
.cta-box{background:#fff;border:2px solid var(--g);border-radius:16px;padding:20px;margin:22px 0;text-align:center}
.cta-box .cta{margin:12px 0 6px}.cta-text{font-weight:600;color:#1a1730}
.cta-sub{font-size:.9em;color:#6b6685;margin-top:8px}
.cta-line{background:#eefaf5;border-radius:12px;padding:10px 14px;margin:12px 0;font-weight:600}
html[data-dev=android] .cta-box .stores,html[data-dev=ios] .cta-box .stores{display:none}
html[data-dev=desktop] .cta-auto{display:none}
"""


OG_IMAGE = "https://taskify1969.com/assets/og-image.png"


def page(title, desc, canonical, body, jsonld=None, indexable=True):
    # jsonld може да е един dict или списък от dict-ове (напр. FAQPage + BreadcrumbList).
    # indexable=False → noindex,follow (редките имена: файлът съществува, линковете пренасят
    # тежест, но страницата не се индексира и НЕ влиза в sitemap-а).
    robots = "index,follow" if indexable else "noindex,follow"
    blocks = [] if jsonld is None else (jsonld if isinstance(jsonld, list) else [jsonld])
    ld = "".join(f'<script type="application/ld+json">{json.dumps(b, ensure_ascii=False)}</script>'
                 for b in blocks)
    return f"""<!DOCTYPE html><html lang="bg"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{esc(title)}</title>
<meta name="description" content="{esc(desc)}">
<link rel="canonical" href="{canonical}">
<meta property="og:type" content="website"><meta property="og:title" content="{esc(title)}">
<meta property="og:description" content="{esc(desc)}"><meta property="og:url" content="{canonical}">
<meta property="og:image" content="{OG_IMAGE}"><meta property="og:locale" content="bg_BG">
<meta property="og:site_name" content="Taskify"><meta name="robots" content="{robots}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{esc(title)}"><meta name="twitter:description" content="{esc(desc)}">
<meta name="twitter:image" content="{OG_IMAGE}">
<style>{CSS}</style>{ld}</head><body>
<header><div class="brand">Taskify</div></header><div class="wrap">{body}</div>{DEVICE_JS if 'cta-auto' in body else ''}
<footer>Направено с любов от <a href="https://taskify1969.com">Taskify</a> —
българското приложение за задачи с имени дни, празници и напомняния.<br>
Данни: Уикипедия „Имен ден" (CC BY-SA 4.0).</footer></body></html>"""


CTA_BLOCK = f"""
<a class="cta" href="https://taskify1969.com">Свали Taskify — напомня ти за всеки имен ден</a>
<div class="stores"><a href="{APP_STORE}">App Store</a><a href="{PLAY}">Google Play</a></div>
"""  # стар общ блок — ползва го само birthday_cards.py (/rozhden-den/, /kartichki/)


# ---- Призив към Taskify по тип страница (ime / data / mesec / podvizhni / hub) ----
CTA_MAIN = ("Всяка сутрин в 8:00 Taskify ти казва кой има имен ден — а в календара виждаш кои от "
            "твоите контакти празнуват и им честитиш с едно докосване.")
CTA_SUB = "Безплатно 14 дни · Android и iPhone"


def play_url(kind):
    return (f"{PLAY}&referrer=utm_source%3Dimen-den%26utm_medium%3Dweb%26utm_campaign%3D{kind}")


def appstore_url(kind):
    if not APPSTORE_PT:
        return APP_STORE
    return (f"https://apps.apple.com/app/apple-store/id6768345070"
            f"?pt={APPSTORE_PT}&ct=imen-den-{kind}&mt=8")


def join_bg(items):
    items = list(items)
    return items[0] if len(items) == 1 else ", ".join(items[:-1]) + " и " + items[-1]


def cta_block(kind, text=CTA_MAIN, anchor=False):
    """Вграден призив (без изскачащ прозорец). Насочване по устройство само чрез
    показване/скриване (DEVICE_JS + CSS): Android → Play, iPhone → App Store, компютър → и двата.
    Без JS (вкл. Googlebot) се виждат всички бутони."""
    pu, iu = esc(play_url(kind)), esc(appstore_url(kind))
    aid = ' id="vzemi-taskify"' if anchor else ''
    return f"""<div class="cta-box"{aid}>
<p class="cta-text">{esc(text)}</p>
<a class="cta cta-auto" href="{pu}" data-play="{pu}" data-ios="{iu}">Свали Taskify безплатно</a>
<div class="stores"><a class="st-ios" href="{iu}">App Store</a><a class="st-play" href="{pu}">Google Play</a></div>
<p class="cta-sub">{esc(CTA_SUB)}</p>
</div>"""


# Определя устройството и сочи зеления бутон към правилния магазин (без пренасочване).
DEVICE_JS = """<script>(function(){var u=navigator.userAgent||'';
var ios=/iPhone|iPad|iPod/.test(u)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1);
var d=ios?'ios':(/Android/i.test(u)?'android':'desktop');
document.documentElement.setAttribute('data-dev',d);
var a=document.querySelectorAll('.cta-auto');for(var i=0;i<a.length;i++){
if(d==='ios'){a[i].href=a[i].getAttribute('data-ios');}else if(d==='android'){a[i].href=a[i].getAttribute('data-play');}}
})();</script>"""


# ---- Оригинален текст за значението/произхода на популярните имена ----
# Всеки текст е авторски преформулиран (НЕ копиран от Уикипедия/други сайтове), 2-3 изречения.
# Етимологиите са проверени; датите/празниците идват от dataset-а и се показват отделно.
# Разширявай постепенно — целта е тези страници да НЕ са „тънки" (thin content).
MEANINGS = {
    "Иван": "Иван произлиза от старинното еврейско име Йоан (Йоханан), което означава „Бог е милостив“. У нас се разпространява чрез култа към свети Йоан Кръстител и вече столетия наред е сред най-често срещаните български мъжки имена. Смята се за име, което носи благодат и покровителство.",
    "Георги": "Името Георги идва от гръцкото Георгиос — буквално „земеделец“, „онзи, който обработва земята“ (от ge — земя, и ergon — труд). Свързва се със свети Георги Победоносец, покровител на пастирите и войните, а Гергьовден е един от най-обичаните български празници.",
    "Мария": "Мария има древен староеврейски корен (Мириам) и през вековете е тълкувано по различни начини — „обичана“, „господарка“, дори „горчива“. Дължи почитта си на Дева Мария, майката на Христос, и е сред най-разпространените женски имена в целия християнски свят.",
    "Димитър": "Димитър произлиза от гръцкото Деметриос — „посветен на Деметра“, богинята на плодородието и земеделието. В България името се свързва със свети Димитър Солунски, а Димитровден бележи символичния край на топлия стопански сезон.",
    "Николай": "Николай е от гръцки произход и означава „победа на народа“ (nike — победа, laos — народ). Носи се в чест на свети Николай Чудотворец, закрилник на моряците и пътниците, а Никулден е сред най-тачените семейни празници у нас.",
    "Елена": "Елена е старинно гръцко име, свързвано със светлината — с представата за факел, сияние и слънчев лъч. Почита се заради света Елена, майката на император Константин, за която преданието разказва, че открила Кръста Господен.",
    "Петър": "Петър идва от гръцката дума petros — „камък“, „скала“. Името носи символиката на апостол Петър, когото Христос нарекъл канарата, върху която ще изгради Църквата си, откъдето идва и представата за твърдост и опора.",
    "Анна": "Анна произхожда от староеврейското Хана и означава „благодат“, „милост“. Свързва се със света Анна, майката на Дева Мария, и открай време се възприема като име на грижовност и семейна топлина.",
    "Стефан": "Стефан е от гръцки произход и означава „венец“, „корона“ (stephanos). Носи се в памет на свети първомъченик Стефан и традиционно се свързва с достойнство и почит.",
    "Йордан": "Йордан носи името на реката Йордан, в чиито води според Евангелието е кръстен Христос; на еврейски коренът се тълкува като „течащ надолу“. Празникът се пада на Богоявление и е свързан с обичая за хвърляне на кръста в ледената вода.",
    "Тодор": "Тодор е народната българска форма на Теодор и означава „Божи дар“ (от гръцките theos — Бог, и doron — дар). Тодоровден е подвижен празник в началото на Великите пости, известен с конните надбягвания — кушиите.",
    "Васил": "Васил произлиза от гръцкото basileios — „царски“, „царствен“ (basileus — цар). Свързва се със свети Василий Велики, а Васильовден съвпада с първия ден на новата година и с обичая сурвакане.",
    "Христо": "Христо произлиза направо от Христос — от гръцкото Christos, „помазаник“. Името се дава в чест на Рождество Христово и се възприема като благословено, носещо близост до вярата.",
    "Александър": "Александър е старинно гръцко име със значение „защитник на хората“ (alexo — защитавам, andros — мъж, човек). Прославено е от Александър Велики и открай време се свързва с воля, водачество и сила на духа.",
    "Виктория": "Виктория идва от латинската дума victoria — „победа“. У римляните така се наричала и богинята на победата, затова името носи усещане за успех, устрем и триумф.",
    "Мартин": "Мартин е с латински корен и се свързва с Марс — бога на войната, откъдето идва тълкуванието „войнствен“, „посветен на Марс“. Почита се заради свети Мартин, епископ, останал в паметта като закрилник на бедните.",
    "Борис": "Борис е старинно име със славянски и прабългарски корени; най-често се тълкува като „борец“, а някои го свързват с думата за снежен леопард — символ на сила. В българската история то е неразделно свързано с княз Борис I Покръстител.",
    "Ирина": "Ирина произлиза от гръцкото eirene — „мир“, „спокойствие“. Името носи светъл, ведър заряд и открай време се възприема като пожелание за хармония и вътрешен покой.",
    "Гергана": "Гергана е чисто българско женско име, производно на Георги, и се празнува на Гергьовден. В народните песни то е символ на хубавата, работлива девойка и звучи топло и родно.",
    "Даниел": "Даниел е с еврейски произход и означава „Бог е мой съдия“. Носи се в памет на пророк Даниил и се свързва с мъдрост, справедливост и твърда вяра.",
    "Илия": "Илия произлиза от еврейското Елияху — „Господ е мой Бог“. Свързва се с пророк Илия, когото народната традиция е направила повелител на гръмотевиците и небесния огън; Илинден е сред най-почитаните летни празници.",
    "Атанас": "Атанас идва от гръцкото athanasios — „безсмъртен“ (a — не, thanatos — смърт). Носи се в чест на свети Атанасий Велики и се празнува посред зима, на Атанасовден.",
    "Валентин": "Валентин има латински корен от valens — „силен“, „здрав“, „могъщ“. Възприема се като име с топъл, сърдечен характер и се свързва с представата за вярност и обич.",
    "Цветан": "Цветан е българско име, родено от думата „цвете“ и от пролетния цъфтеж. Празнува се на подвижния празник Цветница (Връбница), седмица преди Великден, когато природата разцъфтява.",
    "Симеон": "Симеон произлиза от еврейското Шимон — „чул“, „послушал Бога“. Носи се в чест на свети Симеон, а в българската история звучи и с блясъка на цар Симеон Велики от Златния век.",
    "Никола": "Никола е кратката, по-родна форма на Николай и означава „победа на народа“. Празнува се на Никулден, свързан със свети Николай — закрилник на рибарите и семейното огнище.",
    "Калоян": "Калоян съчетава гръцкото kalos — „хубав“, „добър“ — с името Йоан, тоест „добрият Йоан“. В историята то носи името на цар Калоян, а звученето му е величествено и българско.",
    "Емилия": "Емилия е с латински произход, от древноримския род Емилий; тълкува се като „усърдна“, „старателна“, „съперничеща“. Името звучи мелодично и открай време се възприема като нежно и изящно.",
    "Теодора": "Теодора е женската форма на Теодор и означава „Божи дар“ (theos — Бог, doron — дар). Празнува се на подвижния Тодоровден в началото на Великите пости.",
    "Кристина": "Кристина е с латински корен и означава „християнка“, „посветена на Христос“. Носи светла, чиста символика и се свързва с вярата и добротата.",
    "Магдалена": "Магдалена означава „от Магдала“ — селище край Галилейското езеро. Свързва се със света Мария Магдалена и се възприема като име с дълбока духовна дълбочина.",
    "Владимир": "Владимир е старинно славянско име, съставено от „владея“ и „мир/свят“ — тоест „владетел на мира“ или „господар на света“. Носи достолепно, силно звучене с дълбоки славянски корени.",
    "София": "София идва от гръцкото sophia — „мъдрост“. Носи се в чест на света София и трите ѝ дъщери — Вяра, Надежда и Любов — а е и името на българската столица.",
    "Стоян": "Стоян е чисто българско име от глагола „стоя“ — давано като пожелание детето да „устои“, да порасне здраво и да живее дълго. Такива защитни имена са дълбока част от народната ни традиция.",
    "Наталия": "Наталия произлиза от латинското natalis — „рождена“, свързана с деня на раждането (Dies Natalis, Рождество). Името носи топлотата на новия живот и на празничното начало.",
    "Огнян": "Огнян е българско име, родено от думата „огън“ — тоест „огнен“, „пламенен“. Възприема се като име на човек с жив дух, топлина и вътрешен плам.",
    "Галина": "Галина е с гръцки произход, от galene — „тишина“, „спокойствие“, „морско затишие“. Носи усещане за ведрина, кротост и душевен покой.",
    "Марина": "Марина има латински корен от marinus — „морска“, свързана с морето (mare). Името звучи свежо и открай време навява представа за простор и синева.",
    "Виолета": "Виолета идва от латинската дума viola — теменужка, нежното пролетно цвете. Празнува се на подвижния празник Цветница и носи цялата свежест на разцъфтяващата природа.",
    "Спас": "Спас е българско име, свързано със „спасение“ и със Спасителя. Празнува се на подвижния Спасовден (Възнесение Господне), четиридесет дни след Великден.",
}


def meaning_block(n):
    """H2 + оригинален абзац за значението, ако имаме текст за това име."""
    m = MEANINGS.get(n)
    if not m:
        return ""
    return f'<h2>Какво означава името {esc(n)}?</h2>\n<p>{esc(m)}</p>'


# ---- Уеб генератор на картички „Честит имен ден" (client-side canvas) ----
CARD_HTML = """
<div class="cardgen">
<h2 id="cgH2">🎨 Направи картичка „Честит имен ден"</h2>
<p id="cgP">Напиши име и си свали готова картичка за Messenger, Viber или Instagram.</p>
<input id="cgName" type="text" value="__PREFILL__" placeholder="Име" maxlength="20">
<input id="cgAge" type="number" min="1" max="130" placeholder="Години (по желание)" style="display:none">
<canvas id="cgCanvas" width="1080" height="1350"></canvas>
<p class="cg-hint">🖼️ Избери фон:</p>
<div id="cgPicker" class="cg-picker"></div>
<div class="cg-btns">
<button id="cgDown">⬇ Свали картичка</button>
<button id="cgShare" class="sec">Сподели</button>
<button id="cgCopy" class="sec">🔗 Копирай линк</button>
</div>
</div>
<script>
(function(){
 var cv=document.getElementById('cgCanvas'),ctx=cv.getContext('2d'),inp=document.getElementById('cgName');
 var picker=document.getElementById('cgPicker'),ageEl=document.getElementById('cgAge');
 // Вид повод: подразбиране от страницата (__DEFAULTOCC__), но ?type= в URL го надделява
 // (приложението отваря /imen-den/?name=…&type=birthday или type=nameday).
 var OCC='__DEFAULTOCC__';
 try{var _p=new URLSearchParams(location.search);var _qn=_p.get('name');if(_qn){inp.value=_qn.slice(0,20);}
   var _t=_p.get('type');if(_t==='birthday'){OCC='birthday';}else if(_t==='nameday'){OCC='nameday';}}catch(e){}
 var TITLE=(OCC==='birthday')?'ЧЕСТИТ РОЖДЕН ДЕН':'ЧЕСТИТ ИМЕН ДЕН';
 var EMO=(OCC==='birthday')?'🎂':'🎉';
 var KIND='__KIND__';
 function shareUrl(){var c=document.querySelector('link[rel=canonical]');
  var base=c?c.href:('https://taskify1969.com'+location.pathname);
  var q='utm_source=share&utm_medium=card&utm_campaign='+encodeURIComponent(KIND);
  try{var sp=new URLSearchParams(location.search);['name','type'].forEach(function(k){var v=sp.get(k);if(v){q=k+'='+encodeURIComponent(v)+'&'+q;}});}catch(e){}
  return base+(base.indexOf('?')<0?'?':'&')+q;}
 // Синхронизирай видимото заглавие + покажи възрастта само за рожден ден.
 if(OCC==='birthday'){ageEl.style.display='';
   var _h2=document.getElementById('cgH2'),_pp=document.getElementById('cgP');
   if(_h2){_h2.textContent='🎂 Направи картичка „Честит рожден ден"';}
   if(_pp){_pp.textContent='Напиши име (и по желание години) и си свали готова картичка за Messenger, Viber или Instagram.';}}
 var W=1080,H=1350;
 // Реални снимки-фонове (локални, същия домейн → без CORS tainting при toBlob).
 // Само наличните се ползват; при 0 заредени → fallback към градиента.
 var FILES=[];for(var k=1;k<=30;k++){FILES.push('bg-'+(k<10?'0':'')+k);}
 var imgs=[],slots=[],bgIx=-1;
 function selectBg(ix){bgIx=ix;draw();
   for(var i=0;i<slots.length;i++){slots[i].el.className=(slots[i].ix===ix)?'cg-th sel':'cg-th';}}
 FILES.forEach(function(n){var im=new Image();im._bg=parseInt(n.slice(3),10);
   im.onload=function(){
     var ix=imgs.length;imgs.push(im);
     // миниатюра за избор
     var t=document.createElement('img');t.src=im.src;t.className='cg-th';t.alt='фон';
     t.addEventListener('click',function(){selectBg(ix);});
     picker.appendChild(t);slots.push({el:t,ix:ix});
     if(bgIx<0){selectBg(ix);}else{draw();}
   };
   im.onerror=function(){};
   im.src='/imen-den/backgrounds/'+n+'.jpg';});
 function rr(x,y,w,h,r){ctx.beginPath();ctx.moveTo(x+r,y);ctx.arcTo(x+w,y,x+w,y+h,r);ctx.arcTo(x+w,y+h,x,y+h,r);ctx.arcTo(x,y+h,x,y,r);ctx.arcTo(x,y,x+w,y,r);ctx.closePath();}
 function hash(s){var h=0;for(var i=0;i<s.length;i++){h=(h*31+s.charCodeAt(i))&0x7fffffff;}return h;}
 function cover(im){var s=Math.max(W/im.width,H/im.height);var nw=im.width*s,nh=im.height*s;ctx.drawImage(im,(W-nw)/2,(H-nh)/2,nw,nh);}
 function grad(){var g=ctx.createLinearGradient(0,0,0,H);g.addColorStop(0,'#6A3DE8');g.addColorStop(1,'#4A28AA');ctx.fillStyle=g;ctx.fillRect(0,0,W,H);}
 // ── Орнамент вместо емоджи: малък златен глиф според темата на избрания фон ──
 var ORN=__ORNMAP__,GOLD='#FFD23F';
 function ornFor(){var b=(imgs.length&&bgIx>=0&&imgs[bgIx])?imgs[bgIx]._bg:0;return ORN[b]||'star';}
 function oStar(cx,cy,R){ctx.beginPath();for(var i=0;i<10;i++){var a=-Math.PI/2+i*Math.PI/5,r=(i%2===0)?R:R*0.42,x=cx+r*Math.cos(a),y=cy+r*Math.sin(a);if(i)ctx.lineTo(x,y);else ctx.moveTo(x,y);}ctx.closePath();ctx.fill();}
 function oSnow(cx,cy,R){ctx.lineWidth=4;for(var k=0;k<6;k++){var a=k*Math.PI/3;ctx.beginPath();ctx.moveTo(cx,cy);ctx.lineTo(cx+R*Math.cos(a),cy+R*Math.sin(a));ctx.stroke();var fb=[[0.55,0.28],[0.78,0.2]];for(var j=0;j<2;j++){var bx=cx+R*fb[j][0]*Math.cos(a),by=cy+R*fb[j][0]*Math.sin(a);for(var s=-1;s<=1;s+=2){var a2=a+s*Math.PI/4;ctx.beginPath();ctx.moveTo(bx,by);ctx.lineTo(bx+R*fb[j][1]*Math.cos(a2),by+R*fb[j][1]*Math.sin(a2));ctx.stroke();}}}}
 function oLeaf(cx,cy,R){var i,s,w;ctx.beginPath();for(i=0;i<=24;i++){s=-1+2*i/24;w=R*0.52*(1-s*s);if(i)ctx.lineTo(cx-w,cy+s*R);else ctx.moveTo(cx-w,cy+s*R);}for(i=0;i<=24;i++){s=1-2*i/24;w=R*0.52*(1-s*s);ctx.lineTo(cx+w,cy+s*R);}ctx.closePath();ctx.fill();ctx.lineWidth=3;ctx.beginPath();ctx.moveTo(cx,cy-R*0.9);ctx.lineTo(cx,cy+R*0.9);ctx.stroke();}
 function oFlower(cx,cy,R){for(var k=0;k<5;k++){var a=-Math.PI/2+k*2*Math.PI/5,px=cx+R*0.5*Math.cos(a),py=cy+R*0.5*Math.sin(a);ctx.beginPath();ctx.arc(px,py,R*0.42,0,2*Math.PI);ctx.fill();}ctx.save();ctx.fillStyle='#B48C1E';ctx.beginPath();ctx.arc(cx,cy,R*0.2,0,2*Math.PI);ctx.fill();ctx.restore();}
 function oFlame(cx,cy,R){var i,t,x,y;ctx.beginPath();for(i=0;i<=30;i++){t=i/30*Math.PI;x=cx+R*0.5*Math.sin(t)*(0.6+0.4*Math.sin(t));y=cy-R*Math.cos(t);if(i)ctx.lineTo(x,y);else ctx.moveTo(x,y);}for(i=0;i<=30;i++){t=Math.PI-i/30*Math.PI;x=cx-R*0.5*Math.sin(t)*(0.6+0.4*Math.sin(t));y=cy-R*Math.cos(t);ctx.lineTo(x,y);}ctx.closePath();ctx.fill();}
 function oNeutral(cx,cy,R){ctx.beginPath();ctx.moveTo(cx,cy-R*0.5);ctx.lineTo(cx+R*0.5,cy);ctx.lineTo(cx,cy+R*0.5);ctx.lineTo(cx-R*0.5,cy);ctx.closePath();ctx.fill();ctx.lineWidth=3;for(var s=-1;s<=1;s+=2){ctx.beginPath();ctx.moveTo(cx+s*R*0.6,cy);ctx.lineTo(cx+s*R*1.1,cy);ctx.stroke();ctx.beginPath();ctx.arc(cx+s*R*1.25,cy,5,0,2*Math.PI);ctx.fill();}}
 function drawOrn(cx,cy,R){var ty=ornFor();ctx.save();ctx.fillStyle=GOLD;ctx.strokeStyle=GOLD;ctx.lineJoin='round';ctx.lineCap='round';if(ty==='star')oStar(cx,cy,R);else if(ty==='snow')oSnow(cx,cy,R);else if(ty==='leaf')oLeaf(cx,cy,R);else if(ty==='flower')oFlower(cx,cy,R);else if(ty==='flame')oFlame(cx,cy,R);else oNeutral(cx,cy,R);ctx.restore();}
 function draw(){
  var name=(inp.value||'').trim()||'Име';
  var r=hash(name)||1;
  function rnd(){r=(r*1103515245+12345)&0x7fffffff;return r/0x7fffffff;}
  // ФОН: избраната реална снимка (cover) ако има заредена, иначе градиент (fallback).
  if(imgs.length&&bgIx>=0){cover(imgs[bgIx%imgs.length]);}else{grad();}
  // Тъмен overlay → гарантира контраст на светла И тъмна снимка.
  ctx.fillStyle='rgba(0,0,0,0.42)';ctx.fillRect(0,0,W,H);
  // Дискретно конфети (само върху градиента, за да не цапа снимката).
  if(!imgs.length){var cols=['#0AA674','#2EC494','#FFD23F','#FF6B6B','#4ECDC4','#ffffff'];
   for(var i=0;i<55;i++){ctx.save();ctx.translate(rnd()*W,rnd()*H);ctx.rotate(rnd()*Math.PI);ctx.globalAlpha=.8;ctx.fillStyle=cols[i%cols.length];ctx.fillRect(0,0,14,24);ctx.restore();}ctx.globalAlpha=1;}
  // Полупрозрачен панел зад текста (допълнителна четимост при шарени снимки).
  ctx.fillStyle='rgba(0,0,0,0.28)';rr(70,470,W-140,470,40);ctx.fill();
  ctx.textAlign='center';
  // Текст: бял, със сянка + тъмен контур → четим на всякаква снимка.
  ctx.save();
  ctx.shadowColor='rgba(0,0,0,0.75)';ctx.shadowBlur=22;ctx.lineJoin='round';
  drawOrn(W/2,238,58);
  ctx.font='700 50px sans-serif';ctx.fillStyle='#FFD23F';ctx.fillText(TITLE,W/2,430);
  var fs=158;
  do{fs-=4;ctx.font='800 '+fs+'px sans-serif';}while(ctx.measureText(name).width>W-220&&fs>44);
  ctx.strokeStyle='rgba(0,0,0,0.55)';ctx.lineWidth=Math.max(6,fs*0.05);ctx.strokeText(name,W/2,700);
  ctx.fillStyle='#fff';ctx.fillText(name,W/2,700);
  // Възраст (само рожден ден, ако е попълнена валидно): „🎂 N години".
  if(OCC==='birthday'){var _a=parseInt(ageEl.value,10);if(!isNaN(_a)&&_a>=1&&_a<=130){
    ctx.font='700 54px "Segoe UI Emoji","Apple Color Emoji",sans-serif';ctx.fillStyle='#FFD23F';
    ctx.fillText('\\ud83c\\udf82 '+_a+' '+(_a===1?'\\u0433\\u043e\\u0434\\u0438\\u043d\\u0430':'\\u0433\\u043e\\u0434\\u0438\\u043d\\u0438'),W/2,858);}}
  ctx.font='700 42px sans-serif';ctx.fillStyle='rgba(255,255,255,.97)';
  ctx.fillText('\\u2705 Taskify \\u00b7 taskify1969.com',W/2,H-72);
  ctx.restore();
 }
 var SLUG=(OCC==='birthday')?'chestit-rojden-den':'chestit-imen-den';
 var WISH=(OCC==='birthday')?'Честит рожден ден':'Честит имен ден';
 function fname(){return SLUG+'-'+((inp.value||'ime').trim().toLowerCase().replace(/[^a-zа-я0-9]+/gi,'-')||'ime')+'.png';}
 inp.addEventListener('input',draw);ageEl.addEventListener('input',draw);
 document.getElementById('cgDown').addEventListener('click',function(){cv.toBlob(function(b){var a=document.createElement('a');a.href=URL.createObjectURL(b);a.download=fname();a.click();setTimeout(function(){URL.revokeObjectURL(a.href);},1500);});});
 document.getElementById('cgShare').addEventListener('click',function(){cv.toBlob(function(b){var f=new File([b],fname(),{type:'image/png'});if(navigator.canShare&&navigator.canShare({files:[f]})){navigator.share({files:[f],title:WISH,text:WISH+'! '+EMO+' '+(KIND?shareUrl():'taskify1969.com')}).catch(function(){});}else{var a=document.createElement('a');a.href=URL.createObjectURL(b);a.download=fname();a.click();}});});
 var cp=document.getElementById('cgCopy');
 cp.addEventListener('click',function(){var u=KIND?shareUrl():location.href;function ok(){var t=cp.textContent;cp.textContent='Копирано ✓';setTimeout(function(){cp.textContent=t;},1600);}if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(u).then(ok,function(){window.prompt('Копирай линка:',u);});}else{window.prompt('Копирай линка:',u);}});
 draw();
})();
</script>
"""


# Фон (bg-01..30) → тема на орнамента върху картичката (вариант „тематичен орнамент").
# flower=цвят, star=звезда, flame=пламък, snow=снежинка, leaf=листо, neutral=неутрален ромб.
ORN_THEME = {
    1: "flower", 2: "flower", 3: "neutral", 4: "flower", 5: "star", 6: "snow",
    7: "flower", 8: "flower", 9: "flower", 10: "flower", 11: "neutral", 12: "neutral",
    13: "neutral", 14: "neutral", 15: "flower", 16: "flower", 17: "star", 18: "neutral",
    19: "flame", 20: "flame", 21: "flame", 22: "star", 23: "star", 24: "star",
    25: "leaf", 26: "leaf", 27: "snow", 28: "snow", 29: "snow", 30: "neutral",
}
ORN_MAP_JSON = json.dumps(ORN_THEME, ensure_ascii=False)


def card_section(prefill, occ="nameday", kind=""):
    # kind ≠ "" → „Сподели"/„Копирай линк" дават адреса на ТЕКУЩАТА страница + UTM (imen-den);
    # kind == "" → старото поведение (birthday_cards.py).
    return (CARD_HTML.replace("__PREFILL__", esc(prefill)).replace("__KIND__", kind)
            .replace("__DEFAULTOCC__", occ)
            .replace("__ORNMAP__", ORN_MAP_JSON))


def write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w", encoding="utf-8").write(content)


# ---- Топ 154 популярни имена → само те от имената са индексируеми (index + sitemap) ----
# Ръчен списък (в dataset-а няма поле за популярност; Search Console още няма данни).
# Популярни пълни форми, ТОЧНО както са в bg_name_days.json. Останалите ~550 имена имат
# собствени страници, но с noindex,follow и извън sitemap-а (тънко съдържание сваля
# приоритета на цялата секция в Google). Генераторът гърми, ако име липсва в данните.
TOP_NAMES = (
    # мъжки (65) — без галени форми, чиято пълна форма е в списъка (Сашо/Митко)
    "Георги Иван Димитър Петър Христо Николай Тодор Стефан Йордан Васил Атанас Александър "
    "Стоян Никола Мартин Красимир Пламен Валентин Илия Борис Даниел Емил Любомир Асен "
    "Владимир Симеон Цветан Веселин Калоян Ивайло Виктор Марин Константин Костадин Павел "
    "Благой Методи Трифон Андрей Лазар Спас Теодор Радослав Светослав Огнян Райко Захари "
    "Евгени Филип Матей Йоан Мирослав Антон Петко Иво Румен Милен Добромир Богдан Милан "
    "Бойко Кирил Михаил Ангел Станислав "
    # женски (80)
    "Мария Иванка Елена Йорданка Виолета Даниела Цветанка Валентина Галина Надежда Анна Петя "
    "Гергана Теодора Николета Габриела Виктория Александра София Екатерина Стефка Снежана "
    "Красимира Емилия Кристина Антоанета Милена Татяна Златка Ивелина Надка Светла Райна "
    "Магдалена Ирина Марина Невена Ваня Ива Йоана Никол Стефани Михаела Симона Деница Боряна "
    "Цветелина Вяра Любов Василка Тодорка Димитрина Петранка Христина Анастасия Албена Таня "
    "Яна Евгения Катерина Ангелина Калина Борислава Илияна Доротея Марта Маргарита Миглена "
    "Мира Камелия Цвета Зоя Мирослава Весела Жана Ивета Николина Нели Пламена Галя "
    # добавени до 150 (9)
    "Светлана Силвия Румяна Ралица Биляна Ивана Радостина Боян Тихомир"
).split()

# lastmod по хеш на съдържанието: датата се мени САМО при реална промяна на страницата.
# Файлът е в git → PC и Mac дават един и същ резултат. (Google игнорира lastmod, който
# се мени при всяко регенериране.)
LASTMOD_FILE = os.path.join(REPO, "tools", "nameday_seo_lastmod.json")


def nav_html(prev, nxt):
    """Навигация ← предишна / следваща → (prev/nxt = (url, label) или None)."""
    a = f'<a href="{prev[0]}" rel="prev">← {esc(prev[1])}</a>' if prev else '<span></span>'
    b = f'<a href="{nxt[0]}" rel="next">{esc(nxt[1])} →</a>' if nxt else '<span></span>'
    return f'<div class="pnav">{a}{b}</div>'


def crumb_ld(items):
    return {"@context": "https://schema.org", "@type": "BreadcrumbList", "itemListElement": [
        {"@type": "ListItem", "position": i + 1, "name": nm, "item": u}
        for i, (nm, u) in enumerate(items)]}


def build(today):
    """Генерира всички страници. Връща {url: (relpath, html, indexable)}."""
    data = json.load(open(DATA, encoding="utf-8"))
    year = today.year

    missing = [n for n in TOP_NAMES if not any(n in r["names"] for r in data["fixed"] + data["movable"])]
    if missing or len(set(TOP_NAMES)) != len(TOP_NAMES):
        raise SystemExit(f"TOP_NAMES: липсват в данните {missing} или има дубликати")
    top = set(TOP_NAMES)

    name_dates = {}    # име -> [(етикет, url на дата/подвижни, празник, date)]
    date_entries = []  # (date, mmdd, names, feast) — фиксирани, сортирани по mmdd
    for r in sorted(data["fixed"], key=lambda r: r["date"]):
        mm, dd = map(int, r["date"].split("-"))
        d = datetime.date(year, mm, dd)
        date_entries.append((d, r["date"], r["names"], r.get("feast")))
        for n in r["names"]:
            name_dates.setdefault(n, []).append(
                (f"{dd} {MONTHS[mm]}", f"{BASE}/data/{r['date']}/", r.get("feast"), d))
    movables = []      # (offset, feast, names, date тази година, date догодина)
    for r in sorted(data["movable"], key=lambda r: r["offset"]):
        d = orthodox_easter(year) + datetime.timedelta(days=r["offset"])
        d2 = orthodox_easter(year + 1) + datetime.timedelta(days=r["offset"])
        movables.append((r["offset"], r.get("feast"), r["names"], d, d2))
        for n in r["names"]:
            name_dates.setdefault(n, []).append(
                (f"{d.day} {MONTHS[d.month]} ({year} г.)", f"{BASE}/podvizhni/", r.get("feast"), d))

    slugs = {}
    for n in sorted(name_dates):
        s = slug(n); base = s; i = 2
        while s in slugs.values(): s = f"{base}-{i}"; i += 1
        slugs[n] = s

    def nlink(x):
        return f'<a href="{BASE}/ime/{slugs[x]}/">{esc(x)}</a>'

    def month_url(m):
        return f"{BASE}/mesec/{slug(MONTHS[m])}/"

    out = {}

    def add(url, html_, indexable=True):
        rel = url[len(BASE):].strip("/")
        out[url] = (os.path.join(rel, "index.html") if rel else "index.html", html_, indexable)

    # ---- Страници по ИМЕ ----
    for n, dates in sorted(name_dates.items()):
        url = f"{BASE}/ime/{slugs[n]}/"
        labels = ", ".join(sorted({d[0] for d in dates}))
        feast = next((d[2] for d in dates if d[2]), None)
        title = f"Кога е имен ден на {n}? — {labels} | Taskify"
        desc = f"{n} празнува имен ден на {labels}." + (f" Празник: {feast}." if feast else "") + \
               f" Виж кой друг празнува и си сложи напомняне в Taskify."
        movable = any(d[1] == f"{BASE}/podvizhni/" for d in dates)
        # Реални линкове към страницата на всяка дата (подвижните → /podvizhni/).
        seen, date_links = set(), []
        for lab, durl, fe, dobj in sorted(dates, key=lambda d: (d[3].month, d[3].day)):
            if durl in seen: continue
            seen.add(durl)
            if durl.endswith("/podvizhni/"):
                date_links.append(f'<a href="{durl}">Виж всички подвижни имени дни →</a>')
            else:
                date_links.append(f'<a href="{durl}">Виж всички, които празнуват на {esc(lab)} →</a>')
        # Имена на същата/същите дати (обединено за всички фиксирани дати на името).
        same = []
        for lab, durl, fe, dobj in dates:
            for de in date_entries:
                if durl == f"{BASE}/data/{de[1]}/":
                    same += [x for x in de[2] if x != n and x not in same]
        when = join_bg(sorted({d[0] for d in dates}, key=lambda lab: next(
            (x[3].month, x[3].day) for x in dates if x[0] == lab)))
        movable_note = (f'<p><em>Това е <strong>подвижен празник</strong> — датата се определя спрямо '
                        f'Великден и се мени всяка година. Показаната дата е за {year} г.</em></p>') if movable else ''
        body = f"""<div class="crumbs"><a href="{BASE}/">Именник</a> › {esc(n)}</div>
<h1>Кога е имен ден на {esc(n)}?</h1>
<p class="lead">{esc(n)} празнува имен ден на:</p>
<div><span class="date">{esc(labels)}</span></div>
<p class="dlinks">{'<br>'.join(date_links)}</p>
<p class="cta-line">📲 Taskify ще ти напомни на {esc(when)} сутринта. <a href="#vzemi-taskify">Свали безплатно ↓</a></p>
{movable_note}
{f'<p>Църковен празник: <strong>{esc(feast)}</strong>.</p>' if feast else ''}
{meaning_block(n)}
{card_section(n, kind="ime")}
{cta_block("ime", f"Имаш познат {n}? Taskify ще ти напомни на {when} сутринта.", anchor=True)}
{('<h2>На същата дата празнуват и</h2><div class="grid">'+''.join(nlink(x) for x in same[:40])+'</div>') if same else ''}
<h2>Не пропускай нито един имен ден</h2>
<p>Taskify е българското приложение за задачи, което помни всички имени дни, официалните
празници и ти напомня навреме — за да честитиш на близките си. Пиши задачите на естествен
език, а AI ги разпознава. Работи на iPhone и Android.</p>"""
        faq = [{
            "@type": "Question", "name": f"Кога е имен ден на {n}?",
            "acceptedAnswer": {"@type": "Answer", "text": f"{n} празнува имен ден на {labels}." + (f" Църковен празник: {feast}." if feast else "")}}]
        if n in MEANINGS:
            faq.append({"@type": "Question", "name": f"Какво означава името {n}?",
                        "acceptedAnswer": {"@type": "Answer", "text": MEANINGS[n]}})
        ld = [{"@context": "https://schema.org", "@type": "FAQPage", "mainEntity": faq},
              crumb_ld([("Именник", f"{BASE}/"), (n, url)])]
        add(url, page(title, desc, url, body, ld, indexable=n in top), indexable=n in top)

    # ---- Страници по ДАТА (с ← предишен / следващ → , кръгово 31.12 → 1.01) ----
    for i, (d, mmdd, names, feast) in enumerate(date_entries):
        url = f"{BASE}/data/{mmdd}/"
        lab = f"{d.day} {MONTHS[d.month]}"
        pd_, nd_ = date_entries[i - 1], date_entries[(i + 1) % len(date_entries)]
        nav = nav_html((f"{BASE}/data/{pd_[1]}/", f"{pd_[0].day} {MONTHS[pd_[0].month]}"),
                       (f"{BASE}/data/{nd_[1]}/", f"{nd_[0].day} {MONTHS[nd_[0].month]}"))
        title = f"Кой има имен ден на {lab}? {(feast+' — ') if feast else ''}Taskify"
        desc = f"На {lab} имен ден празнуват: {', '.join(names)}." + (f" Празник: {feast}." if feast else "")
        body = f"""<div class="crumbs"><a href="{BASE}/">Именник</a> › <a href="{month_url(d.month)}">{MONTHS[d.month].capitalize()}</a> › {esc(lab)}</div>
<h1>Кой празнува имен ден на {esc(lab)}?{(' — '+esc(feast)) if feast else ''}</h1>
<div class="names">{''.join(nlink(x) for x in names)}</div>
{cta_block("data")}
{nav}
<p>Taskify ти напомня за всеки имен ден и официален празник — безплатно, на български.</p>
<p><a href="{month_url(d.month)}">Всички имени дни през {MONTHS[d.month]} →</a></p>"""
        ld = crumb_ld([("Именник", f"{BASE}/"), (MONTHS[d.month].capitalize(), month_url(d.month)), (lab, url)])
        add(url, page(title, desc, url, body, ld))

    # ---- 12 МЕСЕЧНИ подхъба /mesec/{месец}/ ----
    by_month = {}
    for e in date_entries:
        by_month.setdefault(e[0].month, []).append(e)
    for m in range(1, 13):
        url = month_url(m)
        mn = MONTHS[m]
        cards = [
            f'<div class="card"><h2><a href="{BASE}/data/{mmdd}/">{d.day} {mn}{(" — "+esc(fe)) if fe else ""}</a></h2>'
            f'<div class="names">{"".join(nlink(x) for x in names)}</div></div>'
            for d, mmdd, names, fe in by_month.get(m, [])]
        blocks = "".join(cards[:3]) + (cta_block("mesec") + "".join(cards[3:]) if len(cards) > 3 else "")
        pm, nm = (m - 2) % 12 + 1, m % 12 + 1
        nav = nav_html((month_url(pm), MONTHS[pm].capitalize()), (month_url(nm), MONTHS[nm].capitalize()))
        cnt = sum(len(e[2]) for e in by_month.get(m, []))
        title = f"Имени дни през {mn} — кой празнува и кога | Taskify"
        desc = (f"Всички имени дни през {mn}: {len(by_month.get(m, []))} дати и {cnt} имена с празниците им. "
                f"Taskify ти напомня навреме.")
        body = f"""<div class="crumbs"><a href="{BASE}/">Именник</a> › {mn.capitalize()}</div>
<h1>Имени дни през {mn}</h1>
<p class="lead">Кой празнува имен ден през {mn} — по дати, с църковните празници.</p>
{blocks or '<p>През този месец няма имени дни по календара.</p>'}
{nav}
{cta_block("mesec")}"""
        ld = crumb_ld([("Именник", f"{BASE}/"), (mn.capitalize(), url)])
        add(url, page(title, desc, url, body, ld))

    # ---- /podvizhni/ — 6-те подвижни празника (спрямо православния Великден) ----
    url = f"{BASE}/podvizhni/"
    cards = [
        f'<div class="card"><h2>{esc(fe or "")}</h2>'
        f'<p>{d.day} {MONTHS[d.month]} {year} г. · {d2.day} {MONTHS[d2.month]} {year + 1} г.</p>'
        f'<div class="names">{"".join(nlink(x) for x in names)}</div></div>'
        for off, fe, names, d, d2 in movables]
    blocks = "".join(cards[:3]) + (cta_block("podvizhni") + "".join(cards[3:]) if len(cards) > 3 else "")
    body = f"""<div class="crumbs"><a href="{BASE}/">Именник</a> › Подвижни празници</div>
<h1>Подвижни имени дни — {year} и {year + 1} г.</h1>
<p class="lead">Тези празници се определят спрямо православния Великден, затова датата им се мени всяка година.</p>
{blocks}
{cta_block("podvizhni")}"""
    add(url, page(f"Подвижни имени дни {year} — Цветница, Лазаровден, Спасовден | Taskify",
                  f"Кога са подвижните имени дни през {year} и {year + 1} г.: Тодоровден, Лазаровден, "
                  f"Цветница, Великден, Спасовден и Всички български светии — и кой празнува.",
                  url, body, crumb_ld([("Именник", f"{BASE}/"), ("Подвижни празници", url)])))

    # ---- HUB /imen-den/ ----
    # Статичен блок „Предстоящи имени дни" (следващите 10 дати от деня на генериране) —
    # реални <a> за Google; JS „днес" отгоре е само за посетителите.
    upcoming = sorted(date_entries, key=lambda e: (e[1] < today.strftime("%m-%d"), e[1]))[:10]
    up_html = "".join(
        f'<li><a href="{BASE}/data/{mmdd}/">{d.day} {MONTHS[d.month]}{(" — "+esc(fe)) if fe else ""}</a>: '
        f'{", ".join(esc(x) for x in names[:6])}{"…" if len(names) > 6 else ""}</li>'
        for d, mmdd, names, fe in upcoming)
    months_html = "".join(f'<a href="{month_url(m)}">{MONTHS[m].capitalize()}</a>' for m in range(1, 13))
    top_html = "".join(nlink(n) for n in sorted(top))
    today_map = {mmdd: names for d, mmdd, names, fe in date_entries}
    hub_body = f"""<h1>Български именник — кой има имен ден днес?</h1>
<p class="lead" id="today">Разгледай имените дни по месеци, дати или име.</p>
<h2>Предстоящи имени дни</h2><ul class="upcoming">{up_html}</ul>
{cta_block("hub")}
{card_section('', kind="hub")}
<h2>По месеци</h2><div class="grid">{months_html}</div>
<p><a href="{BASE}/podvizhni/">Подвижни имени дни (Цветница, Лазаровден, Спасовден…) →</a></p>
<h2>Популярни имена</h2><div class="grid">{top_html}</div>
<script>
const M=["", "януари","февруари","март","април","май","юни","юли","август","септември","октомври","ноември","декември"];
const T={json.dumps(today_map, ensure_ascii=False)};
const n=new Date();const k=String(n.getMonth()+1).padStart(2,'0')+'-'+String(n.getDate()).padStart(2,'0');
const el=document.getElementById('today');
if(T[k]){{el.innerHTML='🎉 Днес, '+n.getDate()+' '+M[n.getMonth()+1]+', имен ден празнуват: <strong>'+T[k].join(', ')+'</strong>. Честито!';}}
else{{el.textContent='Днес няма голям имен ден по календара. Разгледай по месец, дата или име по-долу.';}}
</script>"""
    add(f"{BASE}/", page("Български именник — имени дни по име и дата | Taskify",
                         "Кой има имен ден днес? Търси имен ден по име или дата. Пълен български именник с празници. Taskify ти напомня навреме.",
                         f"{BASE}/", hub_body))
    return out


def stamp_lastmod(out, today):
    """lastmod по SHA-256 на съдържанието; пази стария, ако страницата не е променена."""
    try:
        old = json.load(open(LASTMOD_FILE, encoding="utf-8"))
    except FileNotFoundError:
        old = {}
    new = {}
    for url, (rel, html_, idx) in out.items():
        if not idx: continue
        h = hashlib.sha256(html_.encode("utf-8")).hexdigest()[:16]
        prev = old.get(url)
        new[url] = prev if prev and prev["h"] == h else {"h": h, "d": today.isoformat()}
    with open(LASTMOD_FILE, "w", encoding="utf-8", newline="\n") as f:
        json.dump(dict(sorted(new.items())), f, ensure_ascii=False, indent=1)
        f.write("\n")
    return new


def check_root_sitemap(path, out, fix):
    """Главният sitemap на сайта НЕ трябва да съдържа noindex страници от именника."""
    sm = open(path, encoding="utf-8").read()
    blocks = re.findall(r"<url>.*?</url>\s*", sm, flags=re.S)
    bad = [b for b in blocks
           if (m := re.search(r"<loc>\s*(\S+?)\s*</loc>", b)) and m.group(1) in out and not out[m.group(1)][2]]
    ours = [b for b in blocks if BASE in b]
    print(f"Главен sitemap: {len(blocks)} URL-а, от тях {len(ours)} от /imen-den/, noindex сред тях: {len(bad)}")
    if bad and fix:
        open(path + ".bak", "w", encoding="utf-8").write(sm)
        for b in bad:
            sm = sm.replace(b, "", 1)
        open(path, "w", encoding="utf-8").write(sm)
        print(f"Махнати {len(bad)} noindex URL-а (резервно копие: {path}.bak)")
    elif bad:
        print("Пусни отново с --fix, за да ги махнеш.")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root-sitemap", help="път до ГЛАВНИЯ sitemap.xml на сайта за проверка")
    ap.add_argument("--fix", action="store_true", help="махни noindex URL-ите от главния sitemap")
    args = ap.parse_args()

    today = datetime.date.today()
    out = build(today)
    if args.root_sitemap:
        check_root_sitemap(args.root_sitemap, out, args.fix)
        return
    lm = stamp_lastmod(out, today)
    for url, (rel, html_, idx) in out.items():
        write(os.path.join(OUT, rel), html_)

    # sitemap: САМО индексируемите (топ имена + дати + месеци + подвижни + хъб)
    urls = [u for u, v in out.items() if v[2]]
    sm = '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
    sm += "".join(f"<url><loc>{u}</loc><lastmod>{lm[u]['d']}</lastmod></url>\n" for u in urls) + "</urlset>\n"
    write(os.path.join(OUT, "sitemap.xml"), sm)

    n_name = sum(1 for u in out if "/ime/" in u)
    print(f"OUT: {OUT}")
    print(f"Страници: {len(out)}  (по име: {n_name}, от тях индексируеми: {sum(1 for u, v in out.items() if '/ime/' in u and v[2])}, "
          f"noindex: {sum(1 for v in out.values() if not v[2])})")
    print(f"Sitemap: {len(urls)} URL-а")


if __name__ == "__main__":
    main()
