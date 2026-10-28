# -*- coding: utf-8 -*-
"""Deterministic old-vs-new diff of generated name-day pages (all pages, not just sitemap).
Old dataset comes from git HEAD; new is the working copy. Does NOT write any site files."""
import os, sys, json, hashlib, datetime, subprocess

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO, 'tools'))
import nameday_seo as seo

today = datetime.date.today()

# new (working-copy dataset)
seo.DATA = os.path.join(REPO, 'assets/data/bg_name_days.json')
new = seo.build(today)

# old (git HEAD dataset) -> temp file
old_json = subprocess.check_output(['git', '-C', REPO, 'show', 'HEAD:assets/data/bg_name_days.json'])
tmp = os.path.join(REPO, 'audit', '_old_dataset.json')
open(tmp, 'wb').write(old_json)
seo.DATA = tmp
old = seo.build(today)
os.remove(tmp)

def sha(h): return hashlib.sha256(h.encode('utf-8')).hexdigest()
newset, oldset = set(new), set(old)
added = sorted(newset - oldset)
removed = sorted(oldset - newset)
changed = sorted(u for u in (newset & oldset) if sha(new[u][1]) != sha(old[u][1]))
unchanged = len((newset & oldset)) - len(changed)

def kind(u):
    if '/ime/' in u: return 'name'
    if '/mesec/' in u: return 'month'
    if '/podvizhni' in u: return 'podvizhni'
    if u.rstrip('/').endswith('/imen-den'): return 'hub'
    return 'date'
def idxof(d, u): return d[u][2]

print('TOTAL pages: old=%d new=%d' % (len(old), len(new)))
print('NEW (added) : %d' % len(added))
print('CHANGED     : %d' % len(changed))
print('REMOVED     : %d' % len(removed))
print('UNCHANGED   : %d' % unchanged)

from collections import Counter
print('\nNEW by type   :', dict(Counter(kind(u) for u in added)))
print('CHANGED by typ:', dict(Counter(kind(u) for u in changed)))
print('NEW indexable :', sum(1 for u in added if idxof(new, u)),
      '| CHANGED indexable:', sum(1 for u in changed if idxof(new, u)))

print('\n--- NEW date pages (14 нови дати) ---')
for u in added:
    if kind(u) == 'date':
        print(' ', u)
print('\n--- CHANGED date pages (sample up to 20) ---')
cd = [u for u in changed if kind(u) == 'date']
print('  count:', len(cd))
for u in cd[:20]:
    print(' ', u)
print('\n--- CHANGED name pages: %d (sample) ---' % sum(1 for u in changed if kind(u)=='name'))
for u in [u for u in changed if kind(u)=='name'][:15]:
    print(' ', u)
if removed:
    print('\n--- REMOVED ---')
    for u in removed: print(' ', u)
