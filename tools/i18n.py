#!/usr/bin/env python3
"""Taskify i18n tooling — extract translatable strings and inject a new language.

The app stores translations as inline Dart maps:  _t({'en': '...', 'bg': '...', ... 'tr': '...'})
plus standalone  const _x = {'en': ..., ...};  maps. This script parses those maps with a
proper Dart string/comment-aware scanner (so placeholders like {days} and comments like
// don't break it), extracts the unique English source strings, and can inject a new
language key into every translatable map.

Config maps are auto-excluded from translation (handled manually in plumbing):
  - locale-code maps (voiceLocales): all values look like 'en' / 'en-US'
  - flag maps: all values are emoji
  - the language-name map: en == 'English' and contains 'Български'

Usage:
  python tools/i18n.py extract                  -> writes tools/i18n_strings.json
  python tools/i18n.py inject <lang> <json>     -> adds '<lang>': '...' to every map
"""
import sys, json, re, glob, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, 'lib')

LOCALE_RE = re.compile(r'^[a-z]{2}(-[A-Z]{2})?$')
# Regional-indicator flags + common symbol/emoji ranges, ZWJ, variation selector.
EMOJI_RE = re.compile(
    r'^[\U0001F1E6-\U0001F1FF\U0001F000-\U0001FAFF\U00002600-\U000027BF←-⇿⬀-⯿️‍\s]+$'
)


def parse_string(s, i):
    """s[i] is a quote (' or "). Returns (inner_raw_with_escapes, index_after_closing_quote)."""
    quote = s[i]
    i += 1
    buf = []
    while i < len(s):
        c = s[i]
        if c == '\\':
            buf.append(s[i:i + 2])
            i += 2
            continue
        if c == quote:
            return ''.join(buf), i + 1
        buf.append(c)
        i += 1
    return None  # unterminated


def skip_ws(s, i):
    while i < len(s) and s[i] in ' \t\r\n':
        i += 1
    return i


def parse_map(s, i):
    """Parse a flat {'key': 'value', ...} string map starting at s[i]=='{'.
    Returns (ordered list of (key, quote, inner_raw, value_end_idx), close_brace_idx) or None
    if this brace does not open such a map."""
    if s[i] != '{':
        return None
    i += 1
    entries = []
    first = True
    while True:
        i = skip_ws(s, i)
        if i >= len(s):
            return None
        if s[i] == '}':
            if not entries:
                return None
            return entries, i
        if not first:
            # already consumed comma below; here we just continue
            pass
        if s[i] != "'":  # keys are always single-quoted
            return None
        key_res = parse_string(s, i)
        if key_res is None:
            return None
        key, i = key_res
        i = skip_ws(s, i)
        if i >= len(s) or s[i] != ':':
            return None
        i = skip_ws(s, i + 1)
        if i >= len(s) or s[i] not in ("'", '"'):
            return None  # value is not a plain string literal -> not our kind of map
        quote = s[i]
        val_res = parse_string(s, i)
        if val_res is None:
            return None
        inner, val_end = val_res
        entries.append((key, quote, inner, val_end))
        i = skip_ws(s, val_end)
        if i >= len(s):
            return None
        if s[i] == ',':
            i += 1
            first = False
            continue
        if s[i] == '}':
            return entries, i
        return None  # unexpected token


def find_maps(text):
    """Yield (start_brace_idx, entries, close_brace_idx) for every flat string map in text,
    skipping strings and comments at the top level."""
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        # skip line comment
        if c == '/' and i + 1 < n and text[i + 1] == '/':
            i += 2
            while i < n and text[i] != '\n':
                i += 1
            continue
        # skip block comment
        if c == '/' and i + 1 < n and text[i + 1] == '*':
            i += 2
            while i < n and not (text[i] == '*' and i + 1 < n and text[i + 1] == '/'):
                i += 1
            i += 2
            continue
        # skip strings
        if c in ("'", '"'):
            res = parse_string(text, i)
            if res is None:
                i += 1
            else:
                i = res[1]
            continue
        if c == '{':
            res = parse_map(text, i)
            if res is not None:
                entries, close = res
                keys = [e[0] for e in entries]
                if 'en' in keys:
                    yield (i, entries, close)
                    i = close + 1
                    continue
        i += 1


def classify(entries):
    """Return 'translatable' or a config reason string."""
    vals = {k: inner for (k, q, inner, ve) in entries}
    values = list(vals.values())
    en = vals.get('en', '')
    if all(LOCALE_RE.match(v) for v in values):
        return 'locale-codes'
    if all(EMOJI_RE.match(v) for v in values if v):
        return 'flags'
    if en == 'English' and 'Български' in values:
        return 'language-names'
    return 'translatable'


def iter_files():
    return sorted(glob.glob(os.path.join(LIB, '**', '*.dart'), recursive=True))


def cmd_extract():
    uniq = {}
    excluded = []
    total_maps = 0
    for path in iter_files():
        rel = os.path.relpath(path, ROOT).replace('\\', '/')
        if rel.endswith('main-working.dart'):
            continue
        with open(path, encoding='utf-8') as f:
            text = f.read()
        for (start, entries, close) in find_maps(text):
            total_maps += 1
            kind = classify(entries)
            en = dict((k, inner) for (k, q, inner, ve) in entries).get('en', '')
            if kind != 'translatable':
                excluded.append({'file': rel, 'kind': kind, 'en': en})
                continue
            uniq.setdefault(en, set()).add(rel)
    out = {
        'count_unique': len(uniq),
        'count_maps_total': total_maps,
        'strings': [{'en': k, 'files': sorted(v)} for k, v in sorted(uniq.items())],
        'excluded': excluded,
    }
    dst = os.path.join(ROOT, 'tools', 'i18n_strings.json')
    with open(dst, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    print(f'Unique translatable strings: {len(uniq)}')
    print(f'Total maps with en: {total_maps}')
    print(f'Excluded config maps: {len(excluded)}')
    for e in excluded:
        print(f"  [{e['kind']}] {e['file']}: en={e['en']!r}")
    print(f'Wrote {dst}')


def cmd_build(lang, array_path):
    """Pair the extracted strings (sorted order) with a same-length array of
    translations BY INDEX, and write tools/i18n_<lang>.json as {en: translation}.
    This guarantees keys match the extracted en values exactly."""
    src = os.path.join(ROOT, 'tools', 'i18n_strings.json')
    with open(src, encoding='utf-8') as f:
        strings = json.load(f)['strings']
    with open(array_path, encoding='utf-8') as f:
        arr = json.load(f)
    if len(arr) != len(strings):
        print(f'ERROR: array has {len(arr)} entries, expected {len(strings)}')
        sys.exit(1)
    tr = {}
    for s, t in zip(strings, arr):
        tr[s['en']] = t
    dst = os.path.join(ROOT, 'tools', f'i18n_{lang}.json')
    with open(dst, 'w', encoding='utf-8') as f:
        json.dump(tr, f, ensure_ascii=False, indent=2)
    print(f'Wrote {dst} ({len(tr)} entries)')


def cmd_inject(lang, json_path):
    # Values are ready-to-embed Dart single-quoted literal bodies:
    # $interpolation, {placeholders} and \n escapes are kept verbatim; any literal
    # apostrophe must already be written as \' in the value. No re-escaping here.
    with open(json_path, encoding='utf-8') as f:
        tr = json.load(f)  # { "<en inner>": "<lang inner>" }
    missing = set()
    changed_files = 0
    added = 0
    for path in iter_files():
        rel = os.path.relpath(path, ROOT).replace('\\', '/')
        if rel.endswith('main-working.dart'):
            continue
        with open(path, encoding='utf-8') as f:
            text = f.read()
        edits = []  # (insert_at_index, insert_text)
        for (start, entries, close) in find_maps(text):
            keys = [e[0] for e in entries]
            if lang in keys:
                continue
            if classify(entries) != 'translatable':
                continue
            en = dict((k, inner) for (k, q, inner, ve) in entries).get('en', '')
            if en not in tr:
                missing.add(en)
                continue
            val = tr[en]
            last_val_end = entries[-1][3]
            insert = f", '{lang}': '{val}'"
            edits.append((last_val_end, insert))
        if edits:
            # apply from the end so indices stay valid
            for idx, ins in sorted(edits, reverse=True):
                text = text[:idx] + ins + text[idx:]
            with open(path, 'w', encoding='utf-8', newline='') as f:
                f.write(text)
            changed_files += 1
            added += len(edits)
    print(f'Injected {lang}: {added} maps across {changed_files} files')
    if missing:
        print(f'WARNING: {len(missing)} en strings had no translation (skipped):')
        for m in sorted(missing):
            print(f'  {m!r}')


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    if sys.argv[1] == 'extract':
        cmd_extract()
    elif sys.argv[1] == 'build':
        cmd_build(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == 'inject':
        cmd_inject(sys.argv[2], sys.argv[3])
    else:
        print('unknown command'); sys.exit(1)
