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


# ---- Уеб генератор на картички „Честит имен ден" (client-side canvas) ----
CARD_HTML = """
<div class="cardgen">
<h2>🎨 Направи картичка „Честит имен ден"</h2>
<p>Напиши име и си свали готова картичка за Messenger, Viber или Instagram.</p>
<input id="cgName" type="text" value="__PREFILL__" placeholder="Име" maxlength="20">
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
 var picker=document.getElementById('cgPicker');
 // Име от URL (?name=…) — приложението отваря сайта с попълнено име на контакта.
 try{var _qn=new URLSearchParams(location.search).get('name');if(_qn){inp.value=_qn.slice(0,20);}}catch(e){}
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
  ctx.font='130px "Segoe UI Emoji","Apple Color Emoji",sans-serif';ctx.fillStyle='#fff';ctx.fillText('🎉',W/2,300);
  ctx.font='700 50px sans-serif';ctx.fillStyle='#FFD23F';ctx.fillText('ЧЕСТИТ ИМЕН ДЕН',W/2,430);
  var fs=158;
  do{fs-=4;ctx.font='800 '+fs+'px sans-serif';}while(ctx.measureText(name).width>W-220&&fs>44);
  ctx.strokeStyle='rgba(0,0,0,0.55)';ctx.lineWidth=Math.max(6,fs*0.05);ctx.strokeText(name,W/2,700);
  ctx.fillStyle='#fff';ctx.fillText(name,W/2,700);
  ctx.font='700 42px sans-serif';ctx.fillStyle='rgba(255,255,255,.97)';
  ctx.fillText('\\u2705 Taskify \\u00b7 taskify1969.com',W/2,H-72);
  ctx.restore();
 }
 function fname(){return 'chestit-imen-den-'+((inp.value||'ime').trim().toLowerCase().replace(/[^a-zа-я0-9]+/gi,'-')||'ime')+'.png';}
 inp.addEventListener('input',draw);
 document.getElementById('cgDown').addEventListener('click',function(){cv.toBlob(function(b){var a=document.createElement('a');a.href=URL.createObjectURL(b);a.download=fname();a.click();setTimeout(function(){URL.revokeObjectURL(a.href);},1500);});});
 document.getElementById('cgShare').addEventListener('click',function(){cv.toBlob(function(b){var f=new File([b],fname(),{type:'image/png'});if(navigator.canShare&&navigator.canShare({files:[f]})){navigator.share({files:[f],title:'Честит имен ден',text:'Честит имен ден! 🎉 taskify1969.com'}).catch(function(){});}else{var a=document.createElement('a');a.href=URL.createObjectURL(b);a.download=fname();a.click();}});});
 var cp=document.getElementById('cgCopy');
 cp.addEventListener('click',function(){var u=location.href;function ok(){var t=cp.textContent;cp.textContent='Копирано ✓';setTimeout(function(){cp.textContent=t;},1600);}if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(u).then(ok,function(){window.prompt('Копирай линка:',u);});}else{window.prompt('Копирай линка:',u);}});
 draw();
})();
</script>
"""


def card_section(prefill):
    return CARD_HTML.replace("__PREFILL__", esc(prefill))


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
{card_section(n)}
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
    sm = '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
    sm += "".join(f"<url><loc>{u}</loc></url>\n" for u in urls) + "</urlset>\n"
    write(os.path.join(OUT, "sitemap.xml"), sm)

    print(f"OUT: {OUT}")
    print(f"Страници: {pages}  (по име: {len(all_names)}, по дата: {len(date_entries)}, hub: 1)")
    print(f"Sitemap: {len(urls)} URL-а")


if __name__ == "__main__":
    main()
