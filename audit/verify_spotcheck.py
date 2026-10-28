import re, json
def kik_day(mm, dd):
    h = open('audit/raw/kik_2026_%02d.html'%mm, encoding='utf-8', errors='replace').read()
    m = re.search(r'<a name="%d"></a>'%dd, h)
    block = h[m.end():h.find('<a name="', m.end())]
    im = re.search(r'Имени дни</span>\s*:?\s*(.*?)</div>', block, re.S)
    return re.sub(r'\s+',' ',im.group(1)).strip() if im else '(no names line)'
def imd_day(mm, dd):
    h = open('audit/raw/imenden_year.html', encoding='utf-8', errors='replace').read()
    m = re.search(r'DB\s*=\s*\{', h); i=m.end()-1; depth=0; j=i
    while j<len(h):
        if h[j]=='{':depth+=1
        elif h[j]=='}':
            depth-=1
            if depth==0: j+=1;break
        j+=1
    obj=json.loads(h[i:j]); key='%02d-%02d'%(dd,mm)
    return obj.get(key,{}).get('n','(absent)')
d=json.load(open('assets/data/bg_name_days.json',encoding='utf-8'))
jf={e['date']:e['names'] for e in d['fixed']}
for (mm,dd) in [(5,11),(12,5),(10,28),(6,14),(4,5),(11,8)]:
    k='%02d-%02d'%(mm,dd)
    print('==== %s ===='%k)
    print(' kik    :', kik_day(mm,dd))
    print(' imenden:', imd_day(mm,dd))
    print(' json   :', jf.get(k,'(no fixed entry)'))
