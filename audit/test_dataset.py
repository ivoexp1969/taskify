# -*- coding: utf-8 -*-
"""Tests for assets/data/bg_name_days.json after the audit changes."""
import json, datetime, sys

PATH = 'assets/data/bg_name_days.json'
fails = []
def ok(cond, msg):
    print(('PASS' if cond else 'FAIL') + ' - ' + msg)
    if not cond:
        fails.append(msg)

# 1. valid JSON
try:
    d = json.load(open(PATH, encoding='utf-8'))
    ok(True, 'valid JSON, loads')
except Exception as e:
    ok(False, 'valid JSON: %r' % e); print('ABORT'); sys.exit(1)

fixed, movable = d['fixed'], d['movable']

# 2. no duplicate fixed dates
dates = [e['date'] for e in fixed]
dups = sorted({x for x in dates if dates.count(x) > 1})
ok(not dups, 'no duplicate fixed dates (dups=%s)' % dups)

# 3. every fixed date is a real MM-DD (use leap 2028 so 02-29 allowed if present)
bad = []
for e in fixed:
    try:
        mm, dd = map(int, e['date'].split('-'))
        datetime.date(2028, mm, dd)
    except Exception:
        bad.append(e['date'])
ok(not bad, 'all fixed dates are valid calendar dates (bad=%s)' % bad)

# 4. fixed sorted ascending
ok(dates == sorted(dates), 'fixed dates sorted ascending')

# 5. no empty name lists; no intra-date duplicate names (case-insensitive)
empty = [e['date'] for e in fixed if not e['names']]
ok(not empty, 'no fixed entry with empty names (empty=%s)' % empty)
intradup = []
for e in fixed + movable:
    low = [n.strip().lower() for n in e['names']]
    if len(low) != len(set(low)):
        intradup.append(e.get('date') or e.get('key'))
ok(not intradup, 'no duplicate name within a single entry (offenders=%s)' % intradup)

# 6. movable structure + offsets + correct Gregorian dates for 2026 & 2027
def orthodox_easter(year):
    a, b, c = year % 4, year % 7, year % 19
    dd = (19*c + 15) % 30
    e = (2*a + 4*b - dd + 34) % 7
    month = (dd + e + 114) // 31
    day = ((dd + e + 114) % 31) + 1
    return datetime.date(year, month, day) + datetime.timedelta(days=13)

ok(len(movable) == 6, 'movable count == 6')
keys = {e['key'] for e in movable}
ok(keys == {'lazarovden','tsvetnitsa','todorovden','velikden','spasovden','vsi_bg_svetii'},
   'movable keys as expected')

# expected offsets and the authoritative dates we verified vs kik-info
EXPECT = {
 'lazarovden': (-8,  '2026-04-04', '2027-04-24'),
 'tsvetnitsa': (-7,  '2026-04-05', '2027-04-25'),
 'todorovden': (-43, '2026-02-28', '2027-03-20'),
 'velikden':   (0,   '2026-04-12', '2027-05-02'),
 'spasovden':  (39,  '2026-05-21', '2027-06-10'),
 'vsi_bg_svetii': (63,'2026-06-14', '2027-07-04'),
}
E26, E27 = orthodox_easter(2026), orthodox_easter(2027)
ok(str(E26) == '2026-04-12' and str(E27) == '2027-05-02', 'Orthodox Easter 2026/2027 correct')
for e in movable:
    exp_off, d26, d27 = EXPECT[e['key']]
    ok(e['offset'] == exp_off, '%s offset == %+d' % (e['key'], exp_off))
    got26 = E26 + datetime.timedelta(days=e['offset'])
    got27 = E27 + datetime.timedelta(days=e['offset'])
    ok(str(got26) == d26, '%s 2026 date == %s (got %s)' % (e['key'], d26, got26))
    ok(str(got27) == d27, '%s 2027 date == %s (got %s)' % (e['key'], d27, got27))

# 7. a movable feast MAY coincide with a fixed date in some years (legit real-world
#    coincidence). That is fine UNLESS the SAME name appears in both lists (double-show).
fixedmap = {e['date']: {n.strip().lower() for n in e['names']} for e in fixed}
for yr, E in ((2026, E26), (2027, E27)):
    for e in movable:
        dt = E + datetime.timedelta(days=e['offset'])
        key = '%02d-%02d' % (dt.month, dt.day)
        if key in fixedmap:
            overlap = sorted({n.strip().lower() for n in e['names']} & fixedmap[key])
            print('  info: %s %d coincides with fixed %s (name overlap=%s)'
                  % (e['key'], yr, key, overlap or 'none'))
            ok(not overlap, 'no name double-shown for %s/%s %d (overlap=%s)'
               % (e['key'], key, yr, overlap))
ok(True, 'movable/fixed coincidences checked for double-shown names')

# 8. the applied corrections are present
todor = next(e for e in movable if e['key'] == 'todorovden')['names']
ok(all(n in todor for n in ['Божидар','Божидара','Дора','Дорина','Доротея','Теодорина']),
   '02-28 names present on movable Тодоровден')
tsvet = next(e for e in movable if e['key'] == 'tsvetnitsa')['names']
ok('Върбан' in tsvet and 'Връбан' not in tsvet, "Цветница has 'Върбан', not 'Връбан'")
ok(not any(e['date'] == '02-28' for e in fixed), '02-28 is NOT a fixed entry')

print('\n%s (%d failures)' % ('ALL PASS' if not fails else 'FAILURES', len(fails)))
sys.exit(1 if fails else 0)
