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
"""


OG_IMAGE = "https://taskify1969.com/assets/og-image.png"


def page(title, desc, canonical, body, jsonld=None):
    # jsonld може да е един dict или списък от dict-ове (напр. FAQPage + BreadcrumbList).
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
<meta property="og:site_name" content="Taskify"><meta name="robots" content="index,follow">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{esc(title)}"><meta name="twitter:description" content="{esc(desc)}">
<meta name="twitter:image" content="{OG_IMAGE}">
<style>{CSS}</style>{ld}</head><body>
<header><div class="brand">Taskify</div></header><div class="wrap">{body}</div>
<footer>Направено с любов от <a href="https://taskify1969.com">Taskify</a> —
българското приложение за задачи с имени дни, празници и напомняния.<br>
Данни: Уикипедия „Имен ден" (CC BY-SA 4.0).</footer></body></html>"""


CTA_BLOCK = f"""
<a class="cta" href="https://taskify1969.com">Свали Taskify — напомня ти за всеки имен ден</a>
<div class="stores"><a href="{APP_STORE}">App Store</a><a href="{PLAY}">Google Play</a></div>
"""


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
 // Синхронизирай видимото заглавие + покажи възрастта само за рожден ден.
 if(OCC==='birthday'){ageEl.style.display='';
   var _h2=document.getElementById('cgH2'),_pp=document.getElementById('cgP');
   if(_h2){_h2.textContent='🎂 Направи картичка „Честит рожден ден"';}
   if(_pp){_pp.textContent='Напиши име (и по желание години) и си свали готова картичка за Messenger, Viber или Instagram.';}}
 var W=1080,H=1350;
 // Реални снимки-фонове (локални, същия домейн → без CORS tainting при toBlob).
 // Само наличните се ползват; при 0 заредени → fallback към градиента.
 var FILES=[];for(var k=1;k<=18;k++){FILES.push('bg-'+(k<10?'0':'')+k);}
 var imgs=[],slots=[],bgIx=-1;
 function selectBg(ix){bgIx=ix;draw();
   for(var i=0;i<slots.length;i++){slots[i].el.className=(slots[i].ix===ix)?'cg-th sel':'cg-th';}}
 FILES.forEach(function(n){var im=new Image();
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
  ctx.font='130px "Segoe UI Emoji","Apple Color Emoji",sans-serif';ctx.fillStyle='#fff';ctx.fillText(EMO,W/2,300);
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
 document.getElementById('cgShare').addEventListener('click',function(){cv.toBlob(function(b){var f=new File([b],fname(),{type:'image/png'});if(navigator.canShare&&navigator.canShare({files:[f]})){navigator.share({files:[f],title:WISH,text:WISH+'! '+EMO+' taskify1969.com'}).catch(function(){});}else{var a=document.createElement('a');a.href=URL.createObjectURL(b);a.download=fname();a.click();}});});
 var cp=document.getElementById('cgCopy');
 cp.addEventListener('click',function(){var u=location.href;function ok(){var t=cp.textContent;cp.textContent='Копирано ✓';setTimeout(function(){cp.textContent=t;},1600);}if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(u).then(ok,function(){window.prompt('Копирай линка:',u);});}else{window.prompt('Копирай линка:',u);}});
 draw();
})();
</script>
"""


def card_section(prefill, occ="nameday"):
    return CARD_HTML.replace("__PREFILL__", esc(prefill)).replace("__DEFAULTOCC__", occ)


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
        movable = any(d[1] is None for d in dates)  # плаващ празник (обвързан с Великден)
        for lab, durl, fe, dobj in dates:
            if durl:
                # имена на същата дата
                for de in date_entries:
                    if de[1] == durl.rstrip("/").split("/")[-1]:
                        same = [(x, slugs.get(x)) for x in de[2] if x != n and x in slugs]
        # За плаващите празници датата се мени всяка година → казваме го изрично,
        # за да не изглежда {year} г. като фиксирана дата (виж РИСК 2).
        movable_note = (f'<p><em>Това е <strong>подвижен празник</strong> — датата се определя спрямо '
                        f'Великден и се мени всяка година. Показаната дата е за {year} г.</em></p>') if movable else ''
        body = f"""<div class="crumbs"><a href="{BASE}/">Именник</a> › {esc(n)}</div>
<h1>Кога е имен ден на {esc(n)}?</h1>
<p class="lead">{esc(n)} празнува имен ден на:</p>
<div><span class="date">{esc(labels)}</span></div>
{movable_note}
{f'<p>Църковен празник: <strong>{esc(feast)}</strong>.</p>' if feast else ''}
{meaning_block(n)}
{card_section(n)}
{CTA_BLOCK}
{('<h2>На същата дата празнуват и</h2><div class="grid">'+''.join(f'<a href="{BASE}/ime/{sl}/">{esc(x)}</a>' for x,sl in same[:40])+'</div>') if same else ''}
<h2>Не пропускай нито един имен ден</h2>
<p>Taskify е българското приложение за задачи, което помни всички имени дни, официалните
празници и ти напомня навреме — за да честитиш на близките си. Пиши задачите на естествен
език, а AI ги разпознава. Работи на iPhone и Android.</p>"""
        faq = [{
            "@type":"Question","name":f"Кога е имен ден на {n}?",
            "acceptedAnswer":{"@type":"Answer","text":f"{n} празнува имен ден на {labels}." + (f" Църковен празник: {feast}." if feast else "")}}]
        if n in MEANINGS:
            faq.append({"@type":"Question","name":f"Какво означава името {n}?",
                        "acceptedAnswer":{"@type":"Answer","text":MEANINGS[n]}})
        crumb = {"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[
            {"@type":"ListItem","position":1,"name":"Именник","item":f"{BASE}/"},
            {"@type":"ListItem","position":2,"name":n,"item":url}]}
        ld = [{"@context":"https://schema.org","@type":"FAQPage","mainEntity":faq}, crumb]
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
        crumb = {"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[
            {"@type":"ListItem","position":1,"name":"Именник","item":f"{BASE}/"},
            {"@type":"ListItem","position":2,"name":lab,"item":url}]}
        write(os.path.join(OUT, "data", mmdd, "index.html"),
              page(title, desc, url, body, crumb)); pages += 1

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
{card_section('')}
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
    today = datetime.date.today().isoformat()
    sm = '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
    sm += "".join(f"<url><loc>{u}</loc><lastmod>{today}</lastmod></url>\n" for u in urls) + "</urlset>\n"
    write(os.path.join(OUT, "sitemap.xml"), sm)

    print(f"OUT: {OUT}")
    print(f"Страници: {pages}  (по име: {len(all_names)}, по дата: {len(date_entries)}, hub: 1)")
    print(f"Sitemap: {len(urls)} URL-а")


if __name__ == "__main__":
    main()
