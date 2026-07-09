#!/usr/bin/env python3
"""Двигател за „имен ден" съдържание за Taskify (маркетинг, почти нулев бюджет).
От official-ния dataset (assets/data/bg_name_days.json) генерира за даден период:
  1) брандирана PNG картичка (1080x1350, feed формат) за всеки ден с имен ден;
  2) готов caption (текст + хаштагове) за копиране в IG/FB/TikTok.
Изход: ~/Desktop/taskify_nameday/  (+ captions.txt)
Използване:  python3 tools/nameday_posts.py [YYYY-MM-DD] [брой_дни]
"""
import os, sys, json, datetime
from PIL import Image, ImageDraw, ImageFont, ImageFilter

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(REPO, "assets/data/bg_name_days.json")
OUT = os.path.expanduser("~/Desktop/taskify_nameday")
os.makedirs(OUT, exist_ok=True)

W, H = 1080, 1350
MARGIN = 96
PURPLE, PURPLE_DK = (106, 61, 232), (74, 40, 170)
GREEN, GREEN_LT, WHITE = (10, 166, 116), (46, 196, 148), (255, 255, 255)
FONT = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
EMOJI = "/System/Library/Fonts/Apple Color Emoji.ttc"
MONTHS = ["", "януари", "февруари", "март", "април", "май", "юни", "юли",
          "август", "септември", "октомври", "ноември", "декември"]


def f(sz): return ImageFont.truetype(FONT, sz)


def emoji_img(ch, target):
    ef = ImageFont.truetype(EMOJI, 160)
    tmp = Image.new("RGBA", (200, 200), (0, 0, 0, 0))
    ImageDraw.Draw(tmp).text((20, 10), ch, font=ef, embedded_color=True)
    bb = tmp.getbbox()
    if bb: tmp = tmp.crop(bb)
    s = target / max(tmp.size)
    return tmp.resize((int(tmp.width * s), int(tmp.height * s)), Image.LANCZOS)


# ---------- Orthodox Easter (Meeus Julian + 13 дни, валидно 1900-2099) ----------
def orthodox_easter(year):
    a, b, c = year % 4, year % 7, year % 19
    d = (19 * c + 15) % 30
    e = (2 * a + 4 * b - d + 34) % 7
    month = (d + e + 114) // 31
    day = ((d + e + 114) % 31) + 1
    julian = datetime.date(year, month, day)
    return julian + datetime.timedelta(days=13)


def load():
    return json.load(open(DATA, encoding="utf-8"))


def names_for(data, date):
    """Връща (names:list, feast:str|None) за дадена дата."""
    md = date.strftime("%m-%d")
    for r in data.get("fixed", []):
        if r["date"] == md:
            return r["names"], r.get("feast")
    easter = orthodox_easter(date.year)
    off = (date - easter).days
    for r in data.get("movable", []):
        if r["offset"] == off:
            return r["names"], r.get("feast")
    return [], None


# ---------- Картичка ----------
def bg():
    img = Image.new("RGB", (W, H), PURPLE)
    px = img.load()
    for y in range(H):
        t = y / H
        px_row = tuple(int(PURPLE[i] * (1 - t) + PURPLE_DK[i] * t) for i in range(3))
        for x in range(W):
            px[x, y] = px_row
    return img


def centered(d, text, font, y, fill, stroke=0):
    w = d.textlength(text, font=font)
    d.text(((W - w) // 2, y), text, font=font, fill=fill,
           stroke_width=stroke, stroke_fill=fill)


def fit(d, text, max_w, start, mn=40):
    s = start
    while s > mn and d.textlength(max(text.split(), key=len), font=f(s)) > max_w:
        s -= 3
    return f(s)


def wrap(d, text, font, max_w):
    lines, cur = [], ""
    for w in text.split():
        t = (cur + " " + w).strip()
        if d.textlength(t, font=font) <= max_w:
            cur = t
        else:
            lines.append(cur); cur = w
    if cur: lines.append(cur)
    return lines


def card(date, names, feast, path):
    img = bg()
    d = ImageDraw.Draw(img)
    # емоджи празник
    em = emoji_img("🎉", 150)
    img.paste(em, ((W - em.width) // 2, 120), em)
    # заглавие
    centered(d, "ЧЕСТИТ ИМЕН ДЕН!", f(78), 300, WHITE, stroke=2)
    # дата (+ феаст)
    dstr = f"{date.day} {MONTHS[date.month]}"
    if feast:
        dstr += f"  ·  {feast}"
    centered(d, dstr, f(52), 410, GREEN_LT)
    # имена (централен блок)
    joined = " · ".join(names) if names else ""
    font_n = fit(d, joined, W - 2 * MARGIN, 88, mn=44)
    lines = wrap(d, joined, font_n, W - 2 * MARGIN)
    lh = int((font_n.getmetrics()[0] + font_n.getmetrics()[1]) * 1.18)
    y = 560 + (620 - lh * len(lines)) // 2
    for ln in lines:
        centered(d, ln, font_n, y, WHITE, stroke=1)
        y += lh
    # футър-бранд
    box, by = 78, H - 150
    label_f = f(48); label = "Taskify — напомня ти за всеки имен ден"
    lw = d.textlength(label, font=label_f)
    x0 = int((W - (box + 20 + lw)) / 2)
    d.rounded_rectangle([x0, by, x0 + box, by + box], radius=20, fill=GREEN)
    d.line([(x0 + 20, by + 40), (x0 + 34, by + 54), (x0 + 60, by + 24)],
           fill=WHITE, width=8, joint="curve")
    d.text((x0 + box + 20, by + (box - label_f.getmetrics()[0]) // 2 - 2),
           label, font=label_f, fill=WHITE)
    img.save(path, "PNG")


def caption(date, names, feast):
    dstr = f"{date.day} {MONTHS[date.month]}"
    head = f"🎉 Днес, {dstr}, имен ден празнуват: {', '.join(names)}. Честито!"
    if feast:
        head = f"🎉 {feast} ({dstr})! Имен ден празнуват: {', '.join(names)}. Честито!"
    body = ("\n\nЗнаеш ли кой друг има имен ден тази седмица? Taskify ти напомня "
            "за всеки — за да не пропуснеш да честитиш. Линк в bio 👇")
    tags = "\n\n#именден #честито #имениден #Taskify #българия #календар"
    # добавяме първите 2 имена като тагове
    for n in names[:2]:
        tags += f" #{n.replace(' ', '')}"
    return head + body + tags


def main():
    start = datetime.date.today()
    days = 30
    if len(sys.argv) > 1:
        start = datetime.date.fromisoformat(sys.argv[1])
    if len(sys.argv) > 2:
        days = int(sys.argv[2])
    data = load()
    caps = []
    made = 0
    for i in range(days):
        dt = start + datetime.timedelta(days=i)
        names, feast = names_for(data, dt)
        if not names:
            continue
        fn = f"nameday_{dt.isoformat()}.png"
        card(dt, names, feast, os.path.join(OUT, fn))
        caps.append(f"===== {dt.isoformat()}  ({fn}) =====\n" + caption(dt, names, feast))
        made += 1
    with open(os.path.join(OUT, "captions.txt"), "w", encoding="utf-8") as fp:
        fp.write("\n\n".join(caps))
    print(f"OUT: {OUT}")
    print(f"Период: {start.isoformat()} + {days} дни  →  {made} картички с имен ден")
    print(f"Captions: {os.path.join(OUT, 'captions.txt')}")


if __name__ == "__main__":
    main()
