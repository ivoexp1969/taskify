# -*- coding: utf-8 -*-
"""Apply approved proposal (+ user corrections) to assets/data/bg_name_days.json.
Corrections: (1) 02-28 names -> movable Тодоровден; (2) 'Връбан'->'Върбан' on Цветница;
(3) category C untouched. Writes the REAL dataset file."""
import json, re

def canon(n):
    return re.sub(r'\s+', ' ', n.replace('ё', 'е')).strip().lower()

p = json.load(open('audit/proposal.json', encoding='utf-8'))

# (1) add the 6 held names to movable Тодоровден
TODOR_ADD = ['Божидар', 'Божидара', 'Дора', 'Дорина', 'Доротея', 'Теодорина']
for e in p['movable']:
    if e['key'] == 'todorovden':
        have = {canon(x) for x in e['names']}
        for n in TODOR_ADD:
            if canon(n) not in have:
                e['names'].append(n); have.add(canon(n))
    if e['key'] == 'tsvetnitsa':
        # (2) 'Връбан' -> 'Върбан' (Върбан already present -> drop the misspelling)
        e['names'] = [n for n in e['names'] if n != 'Връбан']
        if 'Върбан' not in e['names']:
            # safety: if the correct form wasn't there, rename in place
            e['names'] = ['Върбан' if n == 'Връбан' else n for n in e['names']]

# _meta: drop proposal marker, refresh counts, record the audit addition
meta = p['_meta']
meta.pop('phase2_note', None)
meta['fixed_count'] = len(p['fixed'])
meta['movable_count'] = len(p['movable'])
meta['manual_additions'] = (
    meta.get('manual_additions', '').rstrip('. ') +
    '. Audit 2026-10-28 (vs kik-info.com + imenden.eu, cross-checked bg.wikipedia): '
    'added 14 new dates (category A) + names present in BOTH independent sources (category B), '
    'excluding spelling variants; 02-28 names (Божидар/Божидара/Дора/Дорина/Доротея/Теодорина) '
    'placed on movable Тодоровден (confirmed on kik-info Тодоровден 2027, 20.03.2027); '
    "fixed 'Връбан'->'Върбан' on Цветница. Category C/D left unchanged."
)

# keep fixed sorted by date
p['fixed'].sort(key=lambda e: e['date'])

json.dump(p, open('assets/data/bg_name_days.json', 'w', encoding='utf-8'),
          ensure_ascii=False, indent=1)
print('WROTE assets/data/bg_name_days.json')
print('fixed:', len(p['fixed']), '| movable:', len(p['movable']))
for e in p['movable']:
    if e['key'] in ('todorovden', 'tsvetnitsa'):
        print(' ', e['key'], len(e['names']), e['names'])
