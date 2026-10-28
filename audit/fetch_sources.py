"""Download raw source pages into audit/raw/ with >=1s pause + caching.
imenden.eu = single full-year page (already cached). kik-info = 12 monthly pages (2026)."""
import os, time, urllib.request

RAW = 'audit/raw'
UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36'
os.makedirs(RAW, exist_ok=True)


def get(url, dest):
    if os.path.exists(dest) and os.path.getsize(dest) > 2000:
        print('cached ', dest)
        return
    req = urllib.request.Request(url, headers={'User-Agent': UA, 'Accept-Language': 'bg,en;q=0.8'})
    try:
        with urllib.request.urlopen(req, timeout=40) as r:
            data = r.read()
        with open(dest, 'wb') as f:
            f.write(data)
        print('OK     %s  (%d bytes)' % (dest, len(data)))
    except Exception as e:
        print('FAIL   %s  -> %r' % (url, e))
    time.sleep(1.2)


# imenden full year (cache if missing)
get('https://imenden.eu/', os.path.join(RAW, 'imenden_year.html'))
# kik-info monthly pages 2026
for mm in range(1, 13):
    get('https://kik-info.com/spravochnik/calendar/2026/%02d/' % mm,
        os.path.join(RAW, 'kik_2026_%02d.html' % mm))
print('done')
