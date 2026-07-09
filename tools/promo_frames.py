#!/usr/bin/env python3
"""Taskify — генератор на вертикални промо PNG кадри (1080x1920) за Reels/TikTok/Shorts.
Бранд: лилаво #6A3DE8 + зелен чек #0AA674 (от реалната app икона). Кирилица: Arial Unicode.
Емоджита: Apple Color Emoji (композирани отделно). Само текстови кадри — без фалшив UI."""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1080, 1920
MARGIN = 110  # безопасно поле от ръбовете
OUT = os.path.expanduser("~/Desktop/taskify_promo")
os.makedirs(OUT, exist_ok=True)

# ---- Бранд палитра (от реалната икона) ----
PURPLE = (106, 61, 232)      # #6A3DE8
PURPLE_DK = (74, 40, 170)    # по-тъмно за градиент
GREEN = (10, 166, 116)       # #0AA674
GREEN_LT = (46, 196, 148)
WHITE = (255, 255, 255)
INK = (24, 20, 48)

FONT = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
EMOJI = "/System/Library/Fonts/Apple Color Emoji.ttc"
EMOJI_STRIKE = 160  # Apple Color Emoji има фиксиран strike; рендираме и мащабираме


def font(size):
    return ImageFont.truetype(FONT, size)


def emoji_img(ch, target):
    """Рендира едно емоджи с Apple Color Emoji и го мащабира до target px."""
    ef = ImageFont.truetype(EMOJI, EMOJI_STRIKE)
    tmp = Image.new("RGBA", (EMOJI_STRIKE + 40, EMOJI_STRIKE + 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(tmp)
    d.text((20, 10), ch, font=ef, embedded_color=True)
    bbox = tmp.getbbox()
    if bbox:
        tmp = tmp.crop(bbox)
    scale = target / max(tmp.size)
    return tmp.resize((int(tmp.width * scale), int(tmp.height * scale)), Image.LANCZOS)


def bg():
    """Вертикален лилав градиент + лек винетен фон."""
    img = Image.new("RGB", (W, H), PURPLE)
    top, bot = PURPLE, PURPLE_DK
    px = img.load()
    for y in range(H):
        t = y / H
        r = int(top[0] * (1 - t) + bot[0] * t)
        g = int(top[1] * (1 - t) + bot[1] * t)
        b = int(top[2] * (1 - t) + bot[2] * t)
        for x in range(W):
            px[x, y] = (r, g, b)
    return img


def fit_font(draw, text, max_w, start, min_size=54):
    """Намалява размера, докато най-дългата дума се събира в max_w."""
    size = start
    while size > min_size:
        f = font(size)
        longest = max(text.split(), key=len)
        if draw.textlength(longest, font=f) <= max_w:
            break
        size -= 4
    return font(size)


def wrap(draw, text, f, max_w):
    words, lines, cur = text.split(), [], ""
    for w in words:
        test = (cur + " " + w).strip()
        if draw.textlength(test, font=f) <= max_w:
            cur = test
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def draw_heading(img, text, size=104, y_center=None, color=WHITE, weight=2):
    """Центрирано многоредово заглавие (bold чрез stroke)."""
    d = ImageDraw.Draw(img)
    f = fit_font(d, text, W - 2 * MARGIN, size)
    lines = wrap(d, text, f, W - 2 * MARGIN)
    asc, desc = f.getmetrics()
    lh = int((asc + desc) * 1.16)
    total = lh * len(lines)
    y = (y_center if y_center is not None else H // 2) - total // 2
    for ln in lines:
        w = d.textlength(ln, font=f)
        d.text(((W - w) // 2, y), ln, font=f, fill=color,
               stroke_width=weight, stroke_fill=color)
        y += lh
    return y  # долен ръб


def wordmark(img, y=None):
    """Малък бранд знак долу: зелено квадратче с бял чек + 'Taskify'."""
    d = ImageDraw.Draw(img)
    y = y if y is not None else H - 190
    box = 96
    cx = W // 2
    label_f = font(58)
    label = "Taskify"
    lw = d.textlength(label, font=label_f)
    gap = 26
    total = box + gap + lw
    x0 = int(cx - total / 2)
    # зелено закръглено квадратче
    d.rounded_rectangle([x0, y, x0 + box, y + box], radius=26, fill=GREEN)
    # бял чек
    d.line([(x0 + 24, y + 50), (x0 + 42, y + 68), (x0 + 74, y + 30)],
           fill=WHITE, width=10, joint="curve")
    # надпис
    d.text((x0 + box + gap, y + (box - (label_f.getmetrics()[0])) // 2 - 4),
           label, font=label_f, fill=WHITE)


def pill(img, text, y, fill=GREEN, fg=WHITE, size=66):
    """Зелен CTA бутон (закръглен), центриран."""
    d = ImageDraw.Draw(img)
    f = font(size)
    tw = d.textlength(text, font=f)
    asc, desc = f.getmetrics()
    padx, pady = 68, 40
    bw, bh = tw + 2 * padx, asc + desc + 2 * pady
    x0 = (W - bw) // 2
    d.rounded_rectangle([x0, y, x0 + bw, y + bh], radius=bh // 2, fill=fill)
    d.text(((W - tw) // 2, y + pady - 4), text, font=f, fill=fg)
    return y + bh


def bio_hint(img, y, text="Линк в bio", size=52, gap=16):
    """Малък подсказващ ред под CTA бутона: „Линк в bio 👆" (текст + емоджи)."""
    d = ImageDraw.Draw(img)
    f = font(size)
    em = emoji_img("👆", int(size * 1.15))
    tw = d.textlength(text, font=f)
    total = tw + gap + em.width
    x0 = int((W - total) / 2)
    asc = f.getmetrics()[0]
    d.text((x0, y), text, font=f, fill=(255, 255, 255))
    img.paste(em, (int(x0 + tw + gap), y + (asc - em.height) // 2 - 2), em)
    return y + max(asc, em.height)


def paste_emoji(img, ch, y, size=200):
    em = emoji_img(ch, size)
    img.paste(em, ((W - em.width) // 2, y), em)
    return y + em.height


def draw_bg_flag(img, y, w=300):
    """Български трибагреник (бяло/зелено/червено) — ръчно, надеждно (флаг-емоджито
    не се рендира в Pillow). Центриран, със закръглени ъгли и лек кант."""
    d = ImageDraw.Draw(img)
    h = int(w * 0.6)
    x0 = (W - w) // 2
    stripe = h // 3
    BG_WHITE = (255, 255, 255)
    BG_GREEN = (0, 150, 110)
    BG_RED = (214, 38, 18)
    # рисуваме върху маска за закръглени ъгли
    flag = Image.new("RGB", (w, h), BG_WHITE)
    fd = ImageDraw.Draw(flag)
    fd.rectangle([0, stripe, w, 2 * stripe], fill=BG_GREEN)
    fd.rectangle([0, 2 * stripe, w, h], fill=BG_RED)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w, h], radius=22, fill=255)
    img.paste(flag, (x0, y), mask)
    d.rounded_rectangle([x0, y, x0 + w, y + h], radius=22, outline=(255, 255, 255), width=4)
    return y + h


def draw_phone(img, shot_path, top_y, screen_h=1300):
    """Вгражда РЕАЛЕН скрийншот в рамка на телефон (безел + закръглени ъгли +
    сянка). Скрийншотът е автентичен UI (не фалшив)."""
    shot = Image.open(shot_path).convert("RGB")
    sw, sh = shot.size
    screen_w = int(screen_h * sw / sh)
    shot = shot.resize((screen_w, screen_h), Image.LANCZOS)
    # закръглени ъгли на екрана
    rad = 70
    mask = Image.new("L", (screen_w, screen_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, screen_w, screen_h], radius=rad, fill=255)
    bezel = 26
    body_w, body_h = screen_w + 2 * bezel, screen_h + 2 * bezel
    body_x = (W - body_w) // 2
    # сянка
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([body_x, top_y + 18, body_x + body_w, top_y + body_h + 18],
                         radius=bezel + rad, fill=(0, 0, 0, 130))
    img.paste(Image.alpha_composite(img.convert("RGBA"),
              shadow.filter(ImageFilter.GaussianBlur(28))).convert("RGB"), (0, 0))
    # тяло (тъмен безел)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([body_x, top_y, body_x + body_w, top_y + body_h],
                        radius=bezel + rad, fill=(16, 16, 20))
    # екран
    img.paste(shot, (body_x + bezel, top_y + bezel), mask)
    return top_y + body_h


def save(img, name):
    p = os.path.join(OUT, name)
    img.save(p, "PNG")
    return p


# ============================ КАДРИ ============================
frames = []

# --- Серия A: AI разпознаване ---
img = bg(); paste_emoji(img, "😩", 470, 230)
draw_heading(img, "Мразя да въвеждам задачи ръчно", size=112, y_center=1040)
wordmark(img); frames.append(save(img, "promo_a1_ai.png"))

img = bg()
d = ImageDraw.Draw(img)
draw_heading(img, "Затова просто пиша:", size=92, y_center=760)
# репликата в зелено „облаче"
f = font(78); phrase = "лекар четвъртък 14:00"
lines = wrap(d, phrase, f, W - 2 * MARGIN - 120)
bh = int((f.getmetrics()[0] + f.getmetrics()[1]) * 1.2) * len(lines) + 80
x0, y0 = MARGIN, 980
d.rounded_rectangle([x0, y0, W - MARGIN, y0 + bh], radius=44, fill=(255, 255, 255))
yy = y0 + 40
for ln in lines:
    w = d.textlength(ln, font=f)
    d.text(((W - w) // 2, yy), ln, font=f, fill=INK)
    yy += int((f.getmetrics()[0] + f.getmetrics()[1]) * 1.2)
wordmark(img); frames.append(save(img, "promo_a2_ai.png"))

img = bg(); paste_emoji(img, "🤯", 430, 220)
draw_heading(img, "И Taskify само разбира датата, часа и категорията",
             size=88, y_center=1080)
wordmark(img); frames.append(save(img, "promo_a3_ai.png"))

img = bg()
draw_heading(img, "Taskify", size=200, y_center=680)
draw_heading(img, "безплатно, българско", size=76, y_center=900, color=GREEN_LT)
bio_hint(img, pill(img, "Свали сега", 1180) + 30)
wordmark(img, y=H - 210); frames.append(save(img, "promo_a4_cta.png"))

# --- Серия B: имени дни ---
img = bg()
draw_heading(img, "Кое приложение ти напомня за имен ден?", size=100, y_center=980)
wordmark(img); frames.append(save(img, "promo_b1_nameday.png"))

img = bg()
draw_heading(img, "Todoist? Не.", size=110, y_center=800, color=WHITE)
draw_heading(img, "Google Calendar? Не.", size=96, y_center=1050, color=WHITE)
wordmark(img); frames.append(save(img, "promo_b2_nameday.png"))

img = bg()
draw_heading(img, "Само българското", size=96, y_center=760)
draw_heading(img, "Taskify", size=170, y_center=960, color=GREEN_LT)
draw_bg_flag(img, 1170, w=320)
wordmark(img); frames.append(save(img, "promo_b3_nameday.png"))

img = bg()
draw_heading(img, "Taskify", size=190, y_center=720)
draw_heading(img, "Имени дни и празници — вградени", size=74, y_center=980, color=GREEN_LT)
bio_hint(img, pill(img, "Свали безплатно", 1250) + 30)
wordmark(img, y=H - 210); frames.append(save(img, "promo_b4_logo.png"))

# --- Серия C: скорост ---
img = bg()
draw_heading(img, "Организирай си деня за 10 секунди", size=104, y_center=960)
wordmark(img); frames.append(save(img, "promo_c1_speed.png"))

img = bg()
draw_heading(img, "Taskify", size=200, y_center=760)
bio_hint(img, pill(img, "Свали безплатно", 1120) + 30)
wordmark(img, y=H - 210); frames.append(save(img, "promo_c2_cta.png"))

# --- Серия E: споделени списъци ---
img = bg()
draw_heading(img, "Пазарувате заедно, но списъкът е в един телефон?", size=80, y_center=960)
wordmark(img); frames.append(save(img, "promo_e1_shared.png"))

img = bg()
draw_heading(img, "Сподели списък със семейството", size=92, y_center=960)
wordmark(img); frames.append(save(img, "promo_e2_shared.png"))

img = bg()
draw_heading(img, "Всеки добавя и вижда промените веднага", size=84, y_center=960, color=GREEN_LT)
wordmark(img); frames.append(save(img, "promo_e3_shared.png"))

img = bg()
draw_heading(img, "Taskify", size=190, y_center=700)
draw_heading(img, "Споделени списъци — безплатно", size=72, y_center=930, color=GREEN_LT)
bio_hint(img, pill(img, "Свали сега", 1230) + 30)
wordmark(img, y=H - 210); frames.append(save(img, "promo_e4_cta.png"))

# --- Серия F: документи и напомняния ---
img = bg()
draw_heading(img, "Изтича ли ти застраховката, винетката, книжката?",
             size=76, y_center=960)
wordmark(img); frames.append(save(img, "promo_f1_docs.png"))

img = bg()
draw_heading(img, "Taskify ти напомня навреме", size=94, y_center=960, color=GREEN_LT)
wordmark(img); frames.append(save(img, "promo_f2_docs.png"))

img = bg()
draw_heading(img, "Taskify", size=190, y_center=720)
draw_heading(img, "Всичко важно — на време", size=76, y_center=950, color=GREEN_LT)
bio_hint(img, pill(img, "Свали безплатно", 1250) + 30)
wordmark(img, y=H - 210); frames.append(save(img, "promo_f3_cta.png"))

# --- Серия D: реален скрийншот в рамка на телефон (hero) ---
SHOT = os.path.expanduser("~/Downloads/IMG_2929.PNG")
if os.path.exists(SHOT):
    img = bg()
    draw_heading(img, "Всичките ти задачи — на едно място", size=72, y_center=250)
    draw_phone(img, SHOT, top_y=420, screen_h=1300)
    frames.append(save(img, "promo_d1_phone.png"))

    img = bg()
    draw_heading(img, "Умно. Бързо. Българско.", size=84, y_center=250)
    draw_phone(img, SHOT, top_y=420, screen_h=1300)
    frames.append(save(img, "promo_d2_phone.png"))

    img = bg()
    draw_heading(img, "Организирай деня си за секунди", size=72, y_center=210)
    draw_phone(img, SHOT, top_y=340, screen_h=1080)
    bio_hint(img, pill(img, "Свали безплатно", 1560) + 24)
    frames.append(save(img, "promo_d3_phone_cta.png"))
else:
    print(f"⚠️ Скрийншот липсва: {SHOT} — серия D прескочена")

# ============================ ВЕРИФИКАЦИЯ ============================
print(f"OUT: {OUT}")
print(f"Брой кадри: {len(frames)}")
bad = 0
for p in frames:
    im = Image.open(p)
    ok = im.size == (W, H)
    if not ok:
        bad += 1
    print(f"  {os.path.basename(p):28s} {im.size[0]}x{im.size[1]} {'OK' if ok else 'BAD'}")
print("ВСИЧКИ 1080x1920:" , "ДА" if bad == 0 else f"НЕ ({bad} проблемни)")
