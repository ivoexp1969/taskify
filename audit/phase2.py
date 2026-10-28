# -*- coding: utf-8 -*-
"""Phase 2: variants table, re-count A/B/C, build proposal.json (JSON + A + B minus variants),
cross-duplicates list, and C check vs third source (bg.wikipedia Имен ден). READ-ONLY on the JSON."""
import json, re, os, datetime, html as htmlmod, copy, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # add audit/ (trusted scripts) only
import audit  # reuse phase-1 parsers

RAW = 'audit/raw'

# ---------- variant skeleton ----------
def skel(name):
    s = audit.canon(name)              # lower, cleaned, ё->е
    s = s.replace('й', 'и')            # Йордан/Иордан, Методи/Методий
    if s:
        s = s[0] + s[1:].replace('я', 'а').replace('ю', 'у')  # non-initial only
    out = []
    for ch in s:
        if out and out[-1] == ch:
            continue
        out.append(ch)
    return ''.join(out)

# ---------- parse Wikipedia 'Имен ден' (third source) ----------
def load_wikipedia():
    h = open(os.path.join(RAW, 'wikipedia_imen_den.html'), encoding='utf-8', errors='replace').read()
    t = re.sub(r'<[^>]+>', ' ', h)
    t = htmlmod.unescape(t)
    for ch in ('ː', '∶', '：', '﹕', '׃'):  # colon look-alikes -> ':'
        t = t.replace(ch, ':')
    t = re.sub(r'[ \t ]+', ' ', t)
    months = ['Януари','Февруари','Март','Април','Май','Юни','Юли','Август',
              'Септември','Октомври','Ноември','Декември']
    mi = {m: idx+1 for idx, m in enumerate(months)}
    # locate each month's CONTENT section = 'MonthName <day>:' (header immediately followed by day 1..)
    spans = []
    for m in months:
        mm = re.search(r'(?<![А-Яа-я])%s\s+\d{1,2}\s*:' % m, t)
        if mm:
            spans.append((mm.start(), m))
    spans.sort()
    data = {}  # 'MM-DD' -> set(canon names)
    for si, (start, mname) in enumerate(spans):
        end = spans[si+1][0] if si+1 < len(spans) else len(t)
        body = t[start+len(mname):end]
        # split on ' N:' day markers
        parts = re.split(r'(?:^|\s)(\d{1,2}):', body)
        # parts[0] junk, then day, text, day, text...
        for k in range(1, len(parts)-1, 2):
            day = int(parts[k]); seg = parts[k+1]
            seg = re.sub(r'\(([^)]*(?:преди|след|Великден|седмиц|събот|неделя)[^)]*)\)', '', seg)  # drop movable notes
            seg = re.sub(r'\([^)]*\)', lambda mo: mo.group(0), seg)  # keep X(а) handled below
            mm = mi[mname]
            if not (1 <= day <= 31):
                continue
            key = '%02d-%02d' % (mm, day)
            # cut feast tail in parentheses used as feast marker: keep names before last ' ('
            # expand X(Y) -> X, XY ; handle names
            names = set()
            # remove feast parentheticals that are clearly feast names (contain 'ден' or 'св.' or 'празник')
            seg2 = re.sub(r'\(([^)]*(?:ден|св\.|празник|Господн|Богояв|Водиц|Сретение|Велик|мъчени|преподоб|апостол|патриарх|папа)[^)]*)\)', ' ', seg, flags=re.I)
            for tok in re.split(r'[,;]', seg2):
                tok = tok.strip()
                if not tok or 'и др' in tok:
                    tok = tok.replace('и др', '').strip(' .')
                mo = re.match(r'^([А-Яа-яЁё\-]+)\(([А-Яа-яЁё\-]+)\)$', tok)
                if mo:
                    base, suf = mo.group(1), mo.group(2)
                    names.add(audit.canon(base))
                    names.add(audit.canon(base + suf))
                    continue
                c = audit.canon(tok)
                if c and re.match(r'^[а-яё\-]+$', c) and len(c) >= 2:
                    names.add(c)
            if names:
                data.setdefault(key, set()).update(names)
    return data

def main():
    d, fixed = audit.load_json()
    kik = audit.load_kik(2026, range(1, 13))
    imd, imd_feast = audit.load_imenden()
    EASTER = {2026: audit.orthodox_easter(2026)}
    movable = d['movable']
    mov_date2key = {}
    mov_names_by_date = {}
    for e in movable:
        dt = EASTER[2026] + datetime.timedelta(days=e['offset'])
        key = '%02d-%02d' % (dt.month, dt.day)
        mov_date2key[key] = e['key']
        mov_names_by_date[key] = e

    # json coverage 2026 (fixed + movable folded) with display map
    jcov = {}; jdisp = {}
    for k, v in fixed.items():
        jcov.setdefault(k, set())
        for n in v['names']:
            jcov[k].add(audit.canon(n)); jdisp.setdefault(k, {})[audit.canon(n)] = n
    for k in mov_date2key:
        e = mov_names_by_date[k]
        jcov.setdefault(k, set())
        for n in e['names']:
            jcov[k].add(audit.canon(n)); jdisp.setdefault(k, {})[audit.canon(n)] = n

    def to_canon(dic):
        c = {}; disp = {}
        for k, names in dic.items():
            c[k] = set()
            for n in names:
                cn = audit.canon(n)
                if cn:
                    c[k].add(cn); disp.setdefault(k, {})[cn] = n
        return c, disp
    kc, kdisp = to_canon(kik)
    ic, idisp = to_canon(imd)

    def allkeys():
        base = datetime.date(2026, 1, 1)
        for i in range(365):
            dt = base + datetime.timedelta(days=i)
            yield '%02d-%02d' % (dt.month, dt.day)

    # ----- categories WITH variant separation -----
    variant_pairs = {}   # (json_name, src_name) -> set(dates)
    A = []               # (date, both_names_display)
    Braw = {}; Bvar = {} # date -> list
    Craw = {}; Cvar = {}
    for k in allkeys():
        ks = kc.get(k, set()); is_ = ic.get(k, set())
        js = jcov.get(k, set())
        both = ks & is_
        union = ks | is_
        srccount = lambda cn: (1 if cn in ks else 0) + (1 if cn in is_ else 0)
        # skeleton maps
        j_sk = {}
        for cn in js:
            j_sk.setdefault(skel(cn), []).append(cn)
        s_sk = {}
        for cn in union:
            s_sk.setdefault(skel(cn), []).append(cn)
        # A: no json coverage, both sources have names
        if not js and ks and is_:
            disp = [(idisp.get(k, {}).get(c) or kdisp.get(k, {}).get(c)) for c in sorted(both)]
            A.append((k, [x for x in disp if x], sorted(union)))
        # B: in both sources, not exact in json
        for c in sorted(both):
            if c in js:
                continue
            sk = skel(c)
            if sk in j_sk:   # spelling variant of an existing json name
                jn = jdisp[k][j_sk[sk][0]]
                sn = idisp.get(k, {}).get(c) or kdisp.get(k, {}).get(c)
                variant_pairs.setdefault((jn, sn), set()).add(k)
                Bvar.setdefault(k, []).append(sn)
            else:
                Braw.setdefault(k, []).append(idisp.get(k, {}).get(c) or kdisp.get(k, {}).get(c))
        # C: in json coverage, absent from both sources (only where a source has data)
        if k in jcov and (ks or is_):
            for c in sorted(js):
                if c in ks or c in is_:
                    continue
                sk = skel(c)
                if sk in s_sk:  # spelling variant of a source name
                    sn = (idisp.get(k, {}).get(s_sk[sk][0]) or kdisp.get(k, {}).get(s_sk[sk][0]))
                    jn = jdisp[k][c]
                    variant_pairs.setdefault((jn, sn), set()).add(k)
                    Cvar.setdefault(k, []).append(jn)
                else:
                    Craw.setdefault(k, []).append(jdisp[k][c])

    # ----- build proposal.json = current + A + B(non-variant) -----
    proposal = copy.deepcopy(d)
    fixed_index = {e['date']: e for e in proposal['fixed']}
    mov_index = {e['key']: e for e in proposal['movable']}
    added = {}   # 'kind:key' -> list of added names for duplicate tagging
    manual_bucket = {}  # date -> names (ambiguous fixed/movable)
    added_pairs = []  # (date, name, placement)

    def add_fixed(date, names, feast=None):
        e = fixed_index.get(date)
        if e is None:
            e = {'date': date, 'names': []}
            if feast:
                e['feast'] = feast
            proposal['fixed'].append(e); fixed_index[date] = e
        existing = {audit.canon(x) for x in e['names']}
        for n in names:
            if audit.canon(n) not in existing:
                e['names'].append(n); existing.add(audit.canon(n))
                added_pairs.append((date, n, 'fixed'))

    def add_movable(key, names):
        e = mov_index[key]
        existing = {audit.canon(x) for x in e['names']}
        for n in names:
            if audit.canon(n) not in existing:
                e['names'].append(n); existing.add(audit.canon(n))
                added_pairs.append((mov_date2key_inv[key], n, 'movable:' + key))

    mov_date2key_inv = {v: k for k, v in mov_date2key.items()}

    # A -> new fixed entries
    for (date, names, _union) in A:
        add_fixed(date, names, feast=imd_feast.get(date) or None)
    # B(non-variant) -> route
    for date, names in Braw.items():
        if date in fixed_index:
            add_fixed(date, names)
        elif date in mov_date2key:
            key = mov_date2key[date]
            if key == 'todorovden':      # 02-28: ambiguous fixed vs movable
                manual_bucket.setdefault(date, []).extend(names)
            else:
                add_movable(key, names)
        else:
            add_fixed(date, names)
    # keep proposal fixed sorted by date
    proposal['fixed'].sort(key=lambda e: e['date'])
    proposal['_meta'] = dict(proposal.get('_meta', {}))
    proposal['_meta']['phase2_note'] = ('PROPOSAL ONLY — not applied. Adds category A (new dates) + '
        'category B names present in BOTH kik-info & imenden, excluding spelling variants. '
        'Category C and D NOT touched. 02-28 B-names held for manual review (fixed vs Тодоровден).')

    os.makedirs('audit', exist_ok=True)
    json.dump(proposal, open('audit/proposal.json', 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)

    # ----- duplicates across dates in proposal -----
    name_dates = {}
    for e in proposal['fixed']:
        for n in e['names']:
            name_dates.setdefault(n, []).append(e['date'])
    for e in proposal['movable']:
        for n in e['names']:
            name_dates.setdefault(n, []).append('mov:' + e['key'])
    new_occ = {(dt, n) for (dt, n, _p) in added_pairs}
    new_occ_mov = {('mov:' + p.split(':',1)[1], n) for (dt, n, p) in added_pairs if p.startswith('movable:')}
    multi = {n: ds for n, ds in name_dates.items() if len(ds) > 1}

    # ----- C check vs Wikipedia (third source) -----
    wiki = load_wikipedia()
    C_names = []  # (date, name)
    for date, names in Craw.items():
        for n in names:
            C_names.append((date, n))
    confirmed_same = []; confirmed_other = []; not_found = []
    # build global wiki name set + name->dates
    wiki_name_dates = {}
    for k, s in wiki.items():
        for cn in s:
            wiki_name_dates.setdefault(cn, []).append(k)
    for date, n in C_names:
        cn = audit.canon(n)
        if cn in wiki.get(date, set()):
            confirmed_same.append((date, n))
        elif cn in wiki_name_dates:
            confirmed_other.append((date, n, sorted(wiki_name_dates[cn])))
        else:
            not_found.append((date, n))

    # ----- write report2.md -----
    o = []
    o.append('# Одит — Фаза 2 (предложение; JSON НЕ е променян)\n')
    o.append('Дата: %s. Трети източник за проверка на C: **bg.wikipedia.org/wiki/Имен_ден** '
             '(кеширан `audit/raw/wikipedia_imen_den.html`).\n' % datetime.date.today())
    o.append('> ⚠️ Уговорка: `_meta` на JSON сочи, че данните са ИЗВЕДЕНИ от същата статия на Уикипедия. '
             'Затова „потвърдено в Уикипедия" НЕ е напълно независимо — то означава „съвпада с оригиналния '
             'източник". По-силният сигнал е, когато име от JSON **липсва** и в Уикипедия (вероятна ръчна '
             'добавка/печатна грешка). kik-info и imenden остават двата НЕзависими източника от Фаза 1.\n')

    nB_var = sum(len(v) for v in Bvar.values())
    nC_var = sum(len(v) for v in Cvar.values())
    o.append('## 1. Правописни варианти (skeleton: й→и, не-начално я→а/ю→у, свиване на удвоени букви; '
             'родовите форми -а/-я/-consonant се ПАЗЯТ)\n')
    o.append('Намерени %d уникални двойки (варианти не се броят за B или C).\n' % len(variant_pairs))
    o.append('| Вариант в JSON | Вариант в източниците | Дати |')
    o.append('|---|---|---|')
    for (jn, sn), dates in sorted(variant_pairs.items(), key=lambda x: sorted(x[1])[0]):
        o.append('| %s | %s | %s |' % (jn, sn, ', '.join(sorted(dates))))

    o.append('\n## 2. Нови броячи СЛЕД махане на вариантите\n')
    o.append('| Категория | Фаза 1 (дати/имена) | Варианти извадени (имена) | Фаза 2 (дати/имена) |')
    o.append('|---|---|---|---|')
    nA = sum(len(x[1]) for x in A)
    nB1 = 260; nC1 = 133  # phase-1 reference
    nBraw = sum(len(v) for v in Braw.values())
    nCraw = sum(len(v) for v in Craw.values())
    o.append('| A. нови дати | %d / %d | 0 | %d / %d |' % (len(A), nA, len(A), nA))
    o.append('| B. в двата, липсват в JSON | 67 / %d | %d | %d / %d |' % (nB1, nB_var, len(Braw), nBraw))
    o.append('| C. в JSON, липсват в двата | 50 / %d | %d | %d / %d |' % (nC1, nC_var, len(Craw), nCraw))
    o.append('\n_(Числата за Фаза 1 B/C включваха вариантите; тук те са отделени.)_\n')

    o.append('\n## 3. proposal.json\n')
    o.append('Записан в `audit/proposal.json` = текущ JSON + A (нови фиксирани дати) + '
             'B без вариантите. C и D не са пипани. Добавени общо **%d** имена '
             '(%d чрез нови/съществуващи фиксирани дати, %d към подвижни празници).\n'
             % (len(added_pairs),
                sum(1 for _ in added_pairs if not _[2].startswith('movable')),
                sum(1 for _ in added_pairs if _[2].startswith('movable'))))
    if manual_bucket:
        o.append('\n**Задържани за ръчно решение (02-28 — двусмислено: фиксирана дата или Тодоровден?):**')
        for dt, ns in manual_bucket.items():
            o.append('- %s: %s' % (dt, ', '.join(ns)))

    o.append('\n## 4. Имена на повече от една дата в proposal.json (име → дати; ★ = ново от A/B)\n')
    def mark(n, ds):
        out = []
        for dd in ds:
            is_new = (dd, n) in new_occ or (dd, n) in new_occ_mov
            out.append(dd + ('★' if is_new else ''))
        return out
    # only list ones that involve a NEW occurrence OR are plain multi (split)
    multi_new = {n: ds for n, ds in multi.items() if any(((dd, n) in new_occ or (dd, n) in new_occ_mov) for dd in ds)}
    o.append('### 4а. Дубликати, въведени/засегнати от предложението (%d имена):\n' % len(multi_new))
    for n in sorted(multi_new):
        o.append('- **%s** → %s' % (n, ', '.join(mark(n, multi_new[n]))))
    others = {n: ds for n, ds in multi.items() if n not in multi_new}
    o.append('\n### 4б. Вече съществуващи дубликати в JSON (информативно, %d имена):\n' % len(others))
    for n in sorted(others):
        o.append('- %s → %s' % (n, ', '.join(sorted(others[n]))))

    o.append('\n## 5. Категория C срещу трети източник (Уикипедия)\n')
    o.append('C (без вариантите) = %d имена. Разпределение:\n' % len(C_names))
    o.append('- **Потвърдени в Уикипедия на СЪЩАТА дата:** %d' % len(confirmed_same))
    o.append('- **Намерени в Уикипедия, но на ДРУГА дата:** %d' % len(confirmed_other))
    o.append('- **Не са намерени никъде в Уикипедия:** %d\n' % len(not_found))

    o.append('### 5а. Потвърдени на същата дата (вероятно верни — просто kik/imenden ги пропускат)\n')
    byd = {}
    for dt, n in confirmed_same: byd.setdefault(dt, []).append(n)
    for dt in sorted(byd):
        o.append('- **%s**: %s' % (dt, ', '.join(byd[dt])))
    o.append('\n### 5б. Намерени на ДРУГА дата в Уикипедия (възможна грешна дата в JSON)\n')
    for dt, n, wd in sorted(confirmed_other):
        o.append('- **%s** „%s" → в Уикипедия на: %s' % (dt, n, ', '.join(wd)))
    o.append('\n### 5в. Не са намерени никъде в Уикипедия (най-съмнителни — ръчна добавка/печатна грешка?)\n')
    byd = {}
    for dt, n in not_found: byd.setdefault(dt, []).append(n)
    for dt in sorted(byd):
        o.append('- **%s**: %s' % (dt, ', '.join(byd[dt])))

    open('audit/report_phase2.md', 'w', encoding='utf-8').write('\n'.join(o) + '\n')

    # console
    print('variant pairs:', len(variant_pairs), '| B variants removed:', nB_var, '| C variants removed:', nC_var)
    print('A: %d dates / %d names' % (len(A), nA))
    print('B phase2: %d dates / %d names (was 67/260)' % (len(Braw), nBraw))
    print('C phase2: %d dates / %d names (was 50/133)' % (len(Craw), nCraw))
    print('proposal added names:', len(added_pairs), '| manual bucket:', {k: len(v) for k, v in manual_bucket.items()})
    print('duplicates affected by proposal:', len(multi_new), '| pre-existing dup names:', len(others))
    print('C vs wiki -> same:%d other:%d notfound:%d' % (len(confirmed_same), len(confirmed_other), len(not_found)))
    print('wiki dates parsed:', len(wiki))

if __name__ == '__main__':
    main()
