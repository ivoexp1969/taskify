#!/usr/bin/env python3
"""Генератор на страници „Картички" за taskify1969.com.

Прави:
  /kartichki/       — хъб с избор: 🎉 Имен ден  /  🎂 Рожден ден
  /rozhden-den/     — client-side canvas генератор на картичка „Честит рожден ден"
                      (име + незадължителна възраст + избор на фон)

Фоновете се преизползват от /imen-den/backgrounds/bg-01..18.jpg (същия домейн →
без CORS tainting при toBlob). Изход: ~/Desktop/taskify_cards/

ДЕПЛОЙ (Cloudflare Pages, Direct Upload, източник на PC):
  копирай папките `kartichki/` и `rozhden-den/` в Desktop/taskify-site-deploy/
  → npx wrangler pages deploy . --project-name=taskify
"""
import os, html

OUT = os.path.expanduser("~/Desktop/taskify_cards")
APP_STORE = "https://apps.apple.com/app/id6768345070"
PLAY = "https://play.google.com/store/apps/details?id=com.ivoexp.taskify"


def esc(s):
    return html.escape(s, quote=True)


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
.crumbs{font-size:.85em;color:#777;margin-bottom:6px}
.lead{font-size:1.1em;color:#4a4568}
.cta{display:block;background:var(--g);color:#fff;text-align:center;padding:16px;border-radius:14px;
font-weight:700;font-size:1.1em;margin:26px 0 10px}
.stores{display:flex;gap:12px;justify-content:center;flex-wrap:wrap;margin:12px 0}
.stores a{background:#1a1730;color:#fff;padding:12px 22px;border-radius:12px;font-weight:600}
footer{background:#1a1730;color:#cbc7dd;text-align:center;padding:26px 20px;font-size:.9em}
footer a{color:var(--glt)}
.choices{display:flex;gap:16px;flex-wrap:wrap;margin:22px 0}
.choice{flex:1 1 260px;display:block;background:#fff;border:1px solid #e9e6f5;border-radius:18px;
padding:30px 22px;text-align:center;box-shadow:0 4px 18px rgba(74,40,170,.08);transition:transform .15s,box-shadow .15s}
.choice:hover{transform:translateY(-3px);box-shadow:0 10px 28px rgba(74,40,170,.16);text-decoration:none}
.choice .emo{font-size:3em;display:block;margin-bottom:8px}
.choice .t{font-size:1.3em;font-weight:800;color:var(--pd)}
.choice .d{color:#6b6685;font-size:.95em;margin-top:6px}
.cardgen{background:#fff;border:1px solid #e9e6f5;border-radius:16px;padding:22px;margin:22px 0;text-align:center}
.cardgen h2{margin-top:0}
.cardgen .row{display:flex;gap:10px;justify-content:center;flex-wrap:wrap}
.cardgen input{padding:12px 16px;border:2px solid #e4e0f3;border-radius:12px;font-size:1em;margin:6px 0 16px;text-align:center}
.cardgen input#cgName{width:100%;max-width:300px}
.cardgen input#cgAge{width:120px}
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

CTA_BLOCK = f"""
<a class="cta" href="https://taskify1969.com">Свали Taskify — напомня ти за всеки рожден и имен ден</a>
<div class="stores"><a href="{APP_STORE}">App Store</a><a href="{PLAY}">Google Play</a></div>
"""


def page(title, desc, canonical, body):
    return f"""<!DOCTYPE html><html lang="bg"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{esc(title)}</title>
<meta name="description" content="{esc(desc)}">
<link rel="canonical" href="{canonical}">
<meta property="og:type" content="website"><meta property="og:title" content="{esc(title)}">
<meta property="og:description" content="{esc(desc)}"><meta property="og:url" content="{canonical}">
<meta property="og:site_name" content="Taskify"><meta name="robots" content="index,follow">
<style>{CSS}</style></head><body>
<header><div class="brand">Taskify</div></header><div class="wrap">{body}</div>
<footer>Направено с любов от <a href="https://taskify1969.com">Taskify</a> —
българското приложение за задачи с рождени и имени дни, празници и напомняния.</footer></body></html>"""


# ---- Client-side canvas генератор „Честит рожден ден" ----
BDAY_CARD = """
<div class="cardgen">
<h2>🎂 Направи картичка „Честит рожден ден"</h2>
<p>Напиши име (и по желание години) и си свали готова картичка за Messenger, Viber или Instagram.</p>
<div class="row">
<input id="cgName" type="text" value="" placeholder="Име" maxlength="20">
<input id="cgAge" type="number" min="1" max="130" placeholder="Години (по желание)">
</div>
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
 var cv=document.getElementById('cgCanvas'),ctx=cv.getContext('2d');
 var inp=document.getElementById('cgName'),age=document.getElementById('cgAge');
 var picker=document.getElementById('cgPicker');
 // Име от URL (?name=…) — приложението може да отвори сайта с попълнено име на контакта.
 try{var _qn=new URLSearchParams(location.search).get('name');if(_qn){inp.value=_qn.slice(0,20);}}catch(e){}
 var W=1080,H=1350;
 // Реални снимки-фонове (преизползвани от /imen-den/backgrounds/, същия домейн → без CORS tainting).
 var FILES=[];for(var k=1;k<=18;k++){FILES.push('bg-'+(k<10?'0':'')+k);}
 var imgs=[],slots=[],bgIx=-1;
 function selectBg(ix){bgIx=ix;draw();
   for(var i=0;i<slots.length;i++){slots[i].el.className=(slots[i].ix===ix)?'cg-th sel':'cg-th';}}
 FILES.forEach(function(n){var im=new Image();
   im.onload=function(){
     var ix=imgs.length;imgs.push(im);
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
  var a=parseInt(age.value,10);var hasAge=(!isNaN(a)&&a>=1&&a<=130);
  var r=hash(name)||1;
  function rnd(){r=(r*1103515245+12345)&0x7fffffff;return r/0x7fffffff;}
  // ФОН: избраната реална снимка (cover) ако има заредена, иначе градиент (fallback).
  if(imgs.length&&bgIx>=0){cover(imgs[bgIx%imgs.length]);}else{grad();}
  ctx.fillStyle='rgba(0,0,0,0.42)';ctx.fillRect(0,0,W,H);
  // Дискретно конфети само върху градиента (за да не цапа снимката).
  if(!imgs.length){var cols=['#0AA674','#2EC494','#FFD23F','#FF6B6B','#4ECDC4','#ffffff'];
   for(var i=0;i<55;i++){ctx.save();ctx.translate(rnd()*W,rnd()*H);ctx.rotate(rnd()*Math.PI);ctx.globalAlpha=.8;ctx.fillStyle=cols[i%cols.length];ctx.fillRect(0,0,14,24);ctx.restore();}ctx.globalAlpha=1;}
  ctx.fillStyle='rgba(0,0,0,0.28)';rr(70,470,W-140,470,40);ctx.fill();
  ctx.textAlign='center';
  ctx.save();
  ctx.shadowColor='rgba(0,0,0,0.75)';ctx.shadowBlur=22;ctx.lineJoin='round';
  ctx.font='130px "Segoe UI Emoji","Apple Color Emoji",sans-serif';ctx.fillStyle='#fff';ctx.fillText('🎂',W/2,300);
  ctx.font='700 50px sans-serif';ctx.fillStyle='#FFD23F';ctx.fillText('ЧЕСТИТ РОЖДЕН ДЕН',W/2,430);
  var fs=158;
  do{fs-=4;ctx.font='800 '+fs+'px sans-serif';}while(ctx.measureText(name).width>W-220&&fs>44);
  ctx.strokeStyle='rgba(0,0,0,0.55)';ctx.lineWidth=Math.max(6,fs*0.05);ctx.strokeText(name,W/2,690);
  ctx.fillStyle='#fff';ctx.fillText(name,W/2,690);
  if(hasAge){var lbl='\\ud83c\\udf82 '+a+' '+(a===1?'\\u0433\\u043e\\u0434\\u0438\\u043d\\u0430':'\\u0433\\u043e\\u0434\\u0438\\u043d\\u0438');
   ctx.font='700 54px "Segoe UI Emoji","Apple Color Emoji",sans-serif';ctx.fillStyle='#FFD23F';ctx.fillText(lbl,W/2,850);}
  ctx.font='700 42px sans-serif';ctx.fillStyle='rgba(255,255,255,.97)';
  ctx.fillText('\\u2705 Taskify \\u00b7 taskify1969.com',W/2,H-72);
  ctx.restore();
 }
 function fname(){return 'chestit-rozhden-den-'+((inp.value||'ime').trim().toLowerCase().replace(/[^a-zа-я0-9]+/gi,'-')||'ime')+'.png';}
 inp.addEventListener('input',draw);age.addEventListener('input',draw);
 document.getElementById('cgDown').addEventListener('click',function(){cv.toBlob(function(b){var a=document.createElement('a');a.href=URL.createObjectURL(b);a.download=fname();a.click();setTimeout(function(){URL.revokeObjectURL(a.href);},1500);});});
 document.getElementById('cgShare').addEventListener('click',function(){cv.toBlob(function(b){var f=new File([b],fname(),{type:'image/png'});if(navigator.canShare&&navigator.canShare({files:[f]})){navigator.share({files:[f],title:'Честит рожден ден',text:'Честит рожден ден! 🎂 taskify1969.com'}).catch(function(){});}else{var a=document.createElement('a');a.href=URL.createObjectURL(b);a.download=fname();a.click();}});});
 var cp=document.getElementById('cgCopy');
 cp.addEventListener('click',function(){var u=location.href;function ok(){var t=cp.textContent;cp.textContent='Копирано ✓';setTimeout(function(){cp.textContent=t;},1600);}if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(u).then(ok,function(){window.prompt('Копирай линка:',u);});}else{window.prompt('Копирай линка:',u);}});
 draw();
})();
</script>
"""


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
""" + CTA_BLOCK
    write(os.path.join(OUT, "kartichki", "index.html"),
          page("Безплатни картички — имен ден и рожден ден | Taskify",
               "Направи и свали безплатна картичка за имен ден или рожден ден. Напиши име, избери фон и сподели. От Taskify.",
               "https://taskify1969.com/kartichki/", hub_body))

    # ---- Генератор /rozhden-den/ ----
    bday_body = """<div class="crumbs"><a href="https://taskify1969.com/kartichki/">Картички</a> › Рожден ден</div>
<h1>Картичка „Честит рожден ден" 🎂</h1>
<p class="lead">Напиши име (и по желание години), избери фон и си свали готова картичка.
Безплатно, без регистрация.</p>
""" + BDAY_CARD + CTA_BLOCK + """
<h2>Не пропускай нито един рожден ден</h2>
<p>Taskify е българското приложение за задачи, което помни рождените и имените дни на близките ти
и ти напомня навреме. Пиши задачите на естествен език, а AI ги разпознава. Работи на iPhone и Android.</p>"""
    write(os.path.join(OUT, "rozhden-den", "index.html"),
          page("Картичка „Честит рожден ден“ — безплатно | Taskify",
               "Направи безплатна картичка „Честит рожден ден“ с име и години. Избери фон и сподели в Messenger, Viber или Instagram. От Taskify.",
               "https://taskify1969.com/rozhden-den/", bday_body))

    print(f"OUT: {OUT}")
    print("Страници: 2  (/kartichki/, /rozhden-den/)")


if __name__ == "__main__":
    main()
