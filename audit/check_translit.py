# Faithful replica of lib/utils/bg_translit.dart canonCyrillic/canonLatin, to test
# whether the 6 variant pairs already match via keysFor (shared c:/l: key).
import re
CYR2LAT = {
 'а':'a','б':'b','в':'v','г':'g','д':'d','е':'e','ж':'zh','з':'z','и':'i','й':'y',
 'к':'k','л':'l','м':'m','н':'n','о':'o','п':'p','р':'r','с':'s','т':'t','у':'u',
 'ф':'f','х':'h','ц':'ts','ч':'ch','ш':'sh','щ':'sht','ъ':'a','ь':'y','ю':'yu',
 'я':'ya','ё':'yo',
}
def to_latin(s):
    s=s.lower(); return ''.join(CYR2LAT.get(ch,ch) for ch in s)
def canon_cyr(word):
    r=word.lower().strip(); r=re.sub(r'\s+',' ',r)
    return re.sub(r'[^а-яё]','',r)
def canon_lat(word):
    s=word.lower()
    if re.search(r'[а-яё]',s): s=to_latin(s)
    s=re.sub(r'[^a-z]','',s)
    if not s: return ''
    for a,b in [('sht','1'),('sh','2'),('ch','h'),('kh','h'),('zh','z'),('ts','c'),
                ('ya','ia'),('yu','iu'),('yo','io'),('y','i'),('j','i'),('w','v'),('x','ks')]:
        s=s.replace(a,b)
    s=re.sub(r'(.)\1+',r'\1',s)
    return s
def keys(word):
    k=set()
    c=canon_cyr(word)
    if c: k.add('c:'+c)
    l=canon_lat(word)
    if l: k.add('l:'+l)
    return k
pairs=[('Методи','Методий'),('Теодоси','Теодосий'),('Мариян','Мариан'),
       ('Нада','Надя'),('Стилиан','Стилиян'),('Евгени','Евгений'),
       ('Връбан','Върбан')]
for jn,sn in pairs:
    kj,ks=keys(jn),keys(sn)
    shared=kj&ks
    print('%-9s vs %-9s  match=%-5s  json=%s  src=%s' % (
        jn,sn,bool(shared),sorted(kj),sorted(ks)))
