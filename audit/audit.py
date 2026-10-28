# -*- coding: utf-8 -*-
"""Audit bg_name_days.json against kik-info.com (2026) and imenden.eu.
Read-only: never modifies the JSON. Writes audit/report.md."""
import json, re, os, datetime, html as htmlmod

RAW = 'audit/raw'
JSONPATH = 'assets/data/bg_name_days.json'

MONTH_BG = {'януари':1,'февруари':2,'март':3,'април':4,'май':5,'юни':6,'юли':7,
            'август':8,'септември':9,'октомври':10,'ноември':11,'декември':12}

# ---------- normalization ----------
DESCRIPTOR_TOKENS = {
    'и производните','и производни','производни','производните','и др','и други',
    'и всички производни','и производните им','както и производните',
}
def clean_name(n):
    n = htmlmod.unescape(n)
    n = n.replace('ё','е').replace(' ',' ')
    n = re.sub(r'\(.*?\)', '', n)          # drop parentheticals
    n = re.sub(r'\s+', ' ', n).strip().strip('.;,')
    return n
def canon(n):
    return clean_name(n).lower()
def split_names(seg):
    # names separated by comma or semicolon; also handle ' и ' as separator at token level cautiously
    parts = re.split(r'[,;]', seg)
    out = []
    for p in parts:
        c = clean_name(p)
        if not c:
            continue
        if c.lower() in DESCRIPTOR_TOKENS:
            continue
        # strip a leading/trailing 'и производните' glued form
        c = re.sub(r'\s+и\s+производни(те)?$', '', c, flags=re.I).strip()
        if not c or c.lower() in DESCRIPTOR_TOKENS:
            continue
        out.append(c)
    return out

# ---------- parse JSON ----------
def load_json():
    d = json.load(open(JSONPATH, encoding='utf-8'))
    fixed = {}   # 'MM-DD' -> {'names':[...], 'feast':...}
    for e in d['fixed']:
        fixed[e['date']] = {'names': e['names'], 'feast': e.get('feast','')}
    return d, fixed

# ---------- Orthodox Easter (Gregorian date) ----------
def orthodox_easter(year):
    a = year % 4; b = year % 7; c = year % 19
    dd = (19*c + 15) % 30
    e = (2*a + 4*b - dd + 34) % 7
    month = (dd + e + 114) // 31
    day = ((dd + e + 114) % 31) + 1
    julian = datetime.date(year, month, day)
    return julian + datetime.timedelta(days=13)  # Julian->Gregorian offset for 1900-2099

# ---------- parse kik-info monthly page ----------
def parse_kik(path, month):
    h = open(path, encoding='utf-8', errors='replace').read()
    res = {}
    # split into day cards by '<a name="D">'
    for m in re.finditer(r'<a name="(\d{1,2})"></a>', h):
        day = int(m.group(1))
        start = m.end()
        nxt = h.find('<a name="', start)
        block = h[start: nxt if nxt != -1 else start+4000]
        im = re.search(r'Имени дни</span>\s*:?\s*(.*?)</div>', block, re.S)
        names = split_names(im.group(1)) if im else []
        if names:
            res['%02d-%02d' % (month, day)] = names
    return res

def load_kik(year, months):
    out = {}
    for mm in months:
        p = os.path.join(RAW, 'kik_%d_%02d.html' % (year, mm))
        if os.path.exists(p):
            out.update(parse_kik(p, mm))
    return out

# ---------- parse imenden.eu DB ----------
def load_imenden():
    h = open(os.path.join(RAW, 'imenden_year.html'), encoding='utf-8', errors='replace').read()
    m = re.search(r'DB\s*=\s*\{', h)
    i = m.end()-1
    depth = 0; j = i
    while j < len(h):
        ch = h[j]
        if ch == '{': depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                j += 1; break
        j += 1
    obj = json.loads(h[i:j])
    res = {}   # 'MM-DD' -> names
    feast = {}
    for k, v in obj.items():       # k is 'DD-MM'
        dd, mm = k.split('-')
        key = '%s-%s' % (mm, dd)
        res[key] = [clean_name(x) for x in v.get('n', []) if clean_name(x)]
        feast[key] = v.get('h','')
    return res, feast

# ---------- main ----------
def main():
    d, fixed = load_json()
    kik = load_kik(2026, range(1,13))
    imd, imd_feast = load_imenden()

    EASTER = {2026: orthodox_easter(2026), 2027: orthodox_easter(2027)}
    # movable 2026 dates folded into json coverage
    movable = d['movable']
    PENTECOST_OFFSET = 49
    mov_dates = {}  # year -> {key(MM-DD): (feastname, names)}
    for yr in (2026, 2027):
        mov_dates[yr] = {}
        for e in movable:
            dt = EASTER[yr] + datetime.timedelta(days=e['offset'])
            mov_dates[yr]['%02d-%02d' % (dt.month, dt.day)] = (e['feast'], e['names'])

    # effective json coverage for 2026 source comparison = fixed + movable@2026
    jcov = {}  # MM-DD -> set(canon)
    jdisp = {} # MM-DD -> {canon:display}
    for k, v in fixed.items():
        jcov.setdefault(k, set());
        for n in v['names']:
            jcov[k].add(canon(n)); jdisp.setdefault(k,{})[canon(n)] = n
    for k,(f,names) in mov_dates[2026].items():
        jcov.setdefault(k, set())
        for n in names:
            jcov[k].add(canon(n)); jdisp.setdefault(k,{})[canon(n)] = n

    # build source canon maps + display
    def to_canon(dic):
        c={}; disp={}
        for k,names in dic.items():
            c[k]=set();
            for n in names:
                cn=canon(n)
                if cn: c[k].add(cn); disp.setdefault(k,{})[cn]=n
        return c,disp
    kc,kdisp = to_canon(kik)
    ic,idisp = to_canon(imd)

    all_dates = set(kc)|set(ic)|set(jcov)
    # iterate chronologically over real 2026 days
    def allkeys():
        base=datetime.date(2026,1,1)
        for i in range(365):
            dt=base+datetime.timedelta(days=i)
            yield '%02d-%02d'%(dt.month,dt.day)

    catA=[]  # date missing in json entirely, >=2 sources have names
    catB=[]  # names in >=2 sources, missing from json
    catC=[]  # names in json, in NO source for that date (possible wrong date)
    catD=[]  # names in exactly 1 source, missing from json

    for k in allkeys():
        ks=kc.get(k,set()); is_=ic.get(k,set()); js=jcov.get(k,set())
        src_has = [s for s in (ks,is_) if s]
        union=ks|is_
        both=ks&is_
        # name->count
        def cnt(cn): return (1 if cn in ks else 0)+(1 if cn in is_ else 0)
        in_json_at_all = k in jcov
        # A
        if (not js) and len(src_has)>=2:
            names2=sorted(both, key=lambda c:(idisp.get(k,{}).get(c) or kdisp.get(k,{}).get(c)))
            disp=[ (idisp.get(k,{}).get(c) or kdisp.get(k,{}).get(c)) for c in names2]
            catA.append((k,disp,sorted(union)))
        # B: names present in both sources, not in json (json date exists in coverage)
        if js is not None:
            missing_both=[c for c in both if c not in js]
            if missing_both:
                disp=[ (idisp.get(k,{}).get(c) or kdisp.get(k,{}).get(c)) for c in sorted(missing_both)]
                catB.append((k,disp))
        # D: names in exactly one source, missing from json
        only1=[c for c in union if cnt(c)==1 and c not in js]
        if only1:
            disp=[]
            for c in sorted(only1):
                src = 'kik' if c in ks else 'imenden'
                nm = kdisp.get(k,{}).get(c) or idisp.get(k,{}).get(c)
                disp.append('%s [%s]'%(nm,src))
            catD.append((k,disp))
        # C: json names absent from both sources
        if in_json_at_all:
            jd=jdisp.get(k,{})
            absent=[c for c in js if (c not in ks and c not in is_)]
            if absent:
                # only meaningful where at least one source HAS data for that date
                has_src = bool(ks or is_)
                disp=[jd.get(c,c) for c in sorted(absent)]
                catC.append((k,disp,has_src))

    # ----- movable report -----
    mov_lines=[]
    def fmt(dt): return dt.strftime('%d.%m.%Y')
    for yr in (2026,2027):
        mov_lines.append('\n### Пасхален център %d: православен Великден = %s\n'%(yr,fmt(EASTER[yr])))
        mov_lines.append('| Празник | offset | дата (%d) | в източник? |'%yr)
        mov_lines.append('|---|---|---|---|')
        for e in movable:
            dt=EASTER[yr]+datetime.timedelta(days=e['offset'])
            key='%02d-%02d'%(dt.month,dt.day)
            if yr==2026:
                src = kik.get(key); srci = imd.get(key)
                note=[]
                if src is not None: note.append('kik:да')
                else: note.append('kik:—')
                if srci is not None: note.append('imenden:да')
                else: note.append('imenden:—')
                note=' '.join(note)
            else:
                k27=load_kik(2027,[dt.month])
                src=k27.get(key)
                note='kik2027:'+('да' if src is not None else '—')
            mov_lines.append('| %s | %+d | %s | %s |'%(e['feast'],e['offset'],fmt(dt),note))
    # pentecost not in json
    for yr in (2026,2027):
        dt=EASTER[yr]+datetime.timedelta(days=PENTECOST_OFFSET)
        mov_lines.append('\n_Петдесетница %d = %s (offset +49) — НЕ присъства в JSON._'%(yr,fmt(dt)))

    # ----- write report -----
    out=[]
    out.append('# Одит на bg_name_days.json срещу независими източници\n')
    out.append('Дата на одита: %s. Година на справка: 2026 (+ подвижни за 2027).\n'%datetime.date.today())
    out.append('**Източници:** kik-info.com (12 месечни страници 2026), imenden.eu (целогодишна). '
               'Actualno.com: без стабилна справочна URL страница за имен ден (новинарски сайт) → изключен, виж бележка.\n')
    out.append('С 2 надеждни източника „≥2 източника" означава „и двата" (kik + imenden); „1 източник" = само в единия.\n')
    out.append('JSON покритие за 2026 = 120 фиксирани дати + 6 подвижни (сгънати по датите им за 2026), за да няма фалшиви несъответствия.\n')

    out.append('\n## Обобщение (броячи)\n')
    out.append('| Категория | Брой дати | Брой имена |')
    out.append('|---|---|---|')
    out.append('| A. Дати без запис в JSON, но с имена в двата източника | %d | %d |'%(len(catA),sum(len(x[1]) for x in catA)))
    out.append('| B. Имена в двата източника, липсващи в JSON за датата | %d | %d |'%(len(catB),sum(len(x[1]) for x in catB)))
    cC_src=[x for x in catC if x[2]]
    out.append('| C. Имена в JSON, липсващи в двата източника (възможна грешна дата) | %d | %d |'%(len(cC_src),sum(len(x[1]) for x in cC_src)))
    out.append('| D. Имена само в 1 източник, липсващи в JSON (за решение) | %d | %d |'%(len(catD),sum(len(x[1]) for x in catD)))

    def section(title, rows, render):
        out.append('\n## '+title+'\n')
        if not rows:
            out.append('_Няма._'); return
        for r in rows:
            out.append(render(r))

    section('A. Дати напълно липсващи в JSON, но с имена и в kik, и в imenden',
            catA, lambda r:'- **%s** — общо и в двата: %s  _(обединение: %s)_'%(r[0],', '.join(x for x in r[1] if x) or '—', ', '.join(r[2])))
    section('B. Имена, присъстващи в ДВАТА източника, но липсващи в JSON за тази дата',
            catB, lambda r:'- **%s**: %s'%(r[0], ', '.join(x for x in r[1] if x)))
    section('C. Имена в JSON, които НЕ са в нито един източник за датата (възможна грешна дата)',
            cC_src, lambda r:'- **%s**: %s'%(r[0], ', '.join(r[1])))
    # C where no source data at all (can't judge)
    cC_nosrc=[x for x in catC if not x[2]]
    section('C2. Имена в JSON за дати, за които НИТО един източник няма данни (не може да се прецени)',
            cC_nosrc, lambda r:'- **%s**: %s'%(r[0], ', '.join(r[1])))
    section('D. Имена само в ЕДИН източник, липсващи в JSON (за твое решение)',
            catD, lambda r:'- **%s**: %s'%(r[0], ', '.join(r[1])))

    out.append('\n## Подвижни празници\n')
    out.extend(mov_lines)

    os.makedirs('audit', exist_ok=True)
    open('audit/report.md','w',encoding='utf-8').write('\n'.join(out)+'\n')
    # console summary
    print('kik 2026 dates:',len(kik),'| imenden dates:',len(imd),'| json fixed:',len(fixed))
    print('A=%d B=%d C(src)=%d C2=%d D=%d'%(len(catA),len(catB),len(cC_src),len(cC_nosrc),len(catD)))
    print('Easter 2026',EASTER[2026],'| 2027',EASTER[2027])
    print('report -> audit/report.md')

if __name__=='__main__':
    main()
