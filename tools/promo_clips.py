#!/usr/bin/env python3
"""Taskify — генератор на вертикални промо клипове (1080x1920) за TikTok/Reels/Shorts.

Консистентен с първите 3 клипа (`promo_frames.py`, правен на Mac): същият лилав градиент
(#6A3DE8→#4A28AA), зелен бранд знак, стил на заглавията, ръчен български трибагреник.
Разлики за Windows: кирилица = Arial, емоджи = Segoe UI Emoji (цветно през Pillow).

Всеки клип = 3 кадъра (текстовете идват от структурата CLIPS, дума по дума). Кадрите се
сглобяват в MP4 с ffmpeg `xfade` крослейд (30 fps, H.264 yuv420p, БЕЗ аудио — музиката се
слага в TikTok). Тайминг: всеки кадър 4.0s, преход 0.5s → ~11s на клип.

Изход: ~/Desktop/taskify_tiktok/  (frames/ = PNG кадрите, *.mp4 = готовите клипове)
"""
import os
import re
import subprocess
from PIL import Image, ImageDraw, ImageFont
import imageio_ffmpeg

W, H = 1080, 1920
MARGIN = 110
OUT = os.path.expanduser("~/Desktop/taskify_tiktok")
FRAMES = os.path.join(OUT, "frames")
os.makedirs(FRAMES, exist_ok=True)

FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()

# ---- Бранд палитра (идентична с promo_frames.py) ----
PURPLE = (106, 61, 232)
PURPLE_DK = (74, 40, 170)
GREEN = (10, 166, 116)
GREEN_LT = (46, 196, 148)
WHITE = (255, 255, 255)
INK = (24, 20, 48)

FONT = "C:/Windows/Fonts/arial.ttf"          # кирилица (Windows)
EMOJI = "C:/Windows/Fonts/seguiemj.ttf"       # цветни емоджи (Windows)

# ---- Тайминг ----
HOLD = 4.0      # секунди на кадър
XFADE = 0.5     # секунди крослейд
FPS = 30


def font(size):
    return ImageFont.truetype(FONT, size)


def emoji_img(ch, target):
    """Рендира едно емоджи (Segoe UI Emoji, цветно) и го мащабира до target px."""
    ef = ImageFont.truetype(EMOJI, target)
    tmp = Image.new("RGBA", (target * 2, target * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(tmp)
    d.text((target // 2, target // 3), ch, font=ef, embedded_color=True)
    bbox = tmp.getbbox()
    if bbox:
        tmp = tmp.crop(bbox)
    if max(tmp.size) != target:
        s = target / max(tmp.size)
        tmp = tmp.resize((int(tmp.width * s), int(tmp.height * s)), Image.LANCZOS)
    return tmp


def bg():
    """Вертикален лилав градиент (идентичен с оригинала)."""
    img = Image.new("RGB", (W, H), PURPLE)
    px = img.load()
    for y in range(H):
        t = y / H
        r = int(PURPLE[0] * (1 - t) + PURPLE_DK[0] * t)
        g = int(PURPLE[1] * (1 - t) + PURPLE_DK[1] * t)
        b = int(PURPLE[2] * (1 - t) + PURPLE_DK[2] * t)
        for x in range(W):
            px[x, y] = (r, g, b)
    return img


def fit_font(draw, text, max_w, start, min_size=54):
    size = start
    while size > min_size:
        f = font(size)
        longest = max(text.split(), key=len) if text.split() else text
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
    return y


def wordmark(img, y=None):
    """Зелено квадратче с бял чек + 'Taskify' (идентичен на оригинала)."""
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
    d.rounded_rectangle([x0, y, x0 + box, y + box], radius=26, fill=GREEN)
    d.line([(x0 + 24, y + 50), (x0 + 42, y + 68), (x0 + 74, y + 30)],
           fill=WHITE, width=10, joint="curve")
    d.text((x0 + box + gap, y + (box - (label_f.getmetrics()[0])) // 2 - 4),
           label, font=label_f, fill=WHITE)


def paste_emoji(img, ch, y, size=200):
    em = emoji_img(ch, size)
    img.paste(em, ((W - em.width) // 2, y), em)
    return y + em.height


def draw_bg_flag(img, y, w=300):
    """Български трибагреник ръчно (флаг-емоджито не се рендира). Идентичен на оригинала."""
    d = ImageDraw.Draw(img)
    h = int(w * 0.6)
    x0 = (W - w) // 2
    stripe = h // 3
    flag = Image.new("RGB", (w, h), (255, 255, 255))
    fd = ImageDraw.Draw(flag)
    fd.rectangle([0, stripe, w, 2 * stripe], fill=(0, 150, 110))
    fd.rectangle([0, 2 * stripe, w, h], fill=(214, 38, 18))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w, h], radius=22, fill=255)
    img.paste(flag, (x0, y), mask)
    d.rounded_rectangle([x0, y, x0 + w, y + h], radius=22, outline=(255, 255, 255), width=4)
    return y + h


# ---- Разделяне на текст ↔ емоджи ----
_EMOJI_RE = re.compile(
    "[\U0001F000-\U0001FAFF\U00002600-\U000027BF\U00002B00-\U00002BFF]"
)


def parse_line(text):
    """Връща (чист_текст, [емоджи], has_bg_flag). БГ флагът се рисува ръчно."""
    has_flag = "\U0001F1E7\U0001F1EC" in text  # 🇧🇬
    text = text.replace("\U0001F1E7\U0001F1EC", "")
    emojis, out = [], []
    for ch in text:
        o = ord(ch)
        if o in (0xFE0F, 0x200D) or 0x1F1E6 <= o <= 0x1F1FF:
            continue  # variation selector / ZWJ / други regional indicators
        if _EMOJI_RE.match(ch):
            emojis.append(ch)
        else:
            out.append(ch)
    clean = re.sub(r"\s+", " ", "".join(out)).strip()
    return clean, emojis, has_flag


# ============================ КЛИПОВЕ ============================
# Текстовете са дума по дума от брифа. Всеки клип = 3 кадъра.
CLIPS = [
    ("klip_04_imen_den", [
        "Забравих имен ден на кръстницата 😬",
        "Сега приложението ми напомня само",
        "Taskify — с всички имени дни и празници 🇧🇬",
    ]),
    ("klip_05_sravnenie", [
        "Todoist: 40 лв/година, без имени дни",
        "Taskify: безплатно, с имени дни и наши празници",
        "И е българско 🇧🇬 Търси Taskify",
    ]),
    ("klip_06_pazaruvane", [
        "Пак забравих млякото 🥛",
        "Затова пиша списъка тук",
        "Отмятам в магазина. Готово.",
    ]),
    ("klip_07_smetki", [
        "Всеки месец забравям сметките 📄",
        "Задавам го веднъж — повтаря се само",
        "Приложението помни вместо мен ✅",
    ]),
    ("klip_08_sutrin", [
        "Сутрин, преди кафето ☕",
        "Виждам целия си ден на един екран",
        "И знам точно какво следва",
    ]),
    ("klip_09_widget", [
        "Не отварям приложението изобщо 🤔",
        "Задачите ми са точно тук",
        "Един поглед и знам всичко",
    ]),
    ("klip_10_praznici", [
        "Кога е следващият празник? 🇧🇬",
        "Всички наши празници са вградени",
        "Планирам почивките предварително",
    ]),
]


def render_frame(text, is_last, path):
    """Един кадър: hero емоджи (горе) + заглавие (горна-средна трета) + флаг + wordmark."""
    clean, emojis, has_flag = parse_line(text)
    img = bg()
    # hero емоджи горе (ако има)
    if emojis:
        paste_emoji(img, emojis[0], 360, size=200)
        head_y = 830
    else:
        head_y = 720
    color = GREEN_LT if is_last else WHITE
    bottom = draw_heading(img, clean, size=104, y_center=head_y, color=color)
    # български трибагреник като акцент под текста (ако е споменат)
    if has_flag:
        draw_bg_flag(img, max(bottom + 60, 1120), w=300)
    wordmark(img)
    img.save(path, "PNG")
    return path


def build_mp4(png_paths, out_path):
    """Сглобява PNG кадрите в MP4 с xfade крослейд (30fps, H.264, без аудио)."""
    n = len(png_paths)
    inputs = []
    for p in png_paths:
        inputs += ["-loop", "1", "-t", f"{HOLD}", "-i", p]
    # верига от xfade
    filt = []
    prev = "0"
    for i in range(1, n):
        offset = HOLD * i - XFADE * i  # (HOLD-XFADE) стъпка
        label = f"v{i}" if i < n - 1 else "v"
        filt.append(
            f"[{prev}][{i}]xfade=transition=fade:duration={XFADE}:offset={offset:.3f}[{label}]"
        )
        prev = label
    cmd = [FFMPEG, "-y", *inputs,
           "-filter_complex", ";".join(filt),
           "-map", "[v]", "-r", str(FPS),
           "-pix_fmt", "yuv420p", "-c:v", "libx264", "-profile:v", "high",
           "-crf", "20", "-movflags", "+faststart", "-an", out_path]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print("FFMPEG ERR:", r.stderr[-800:])
        raise SystemExit(1)


def main():
    made = []
    for name, texts in CLIPS:
        pngs = []
        for i, t in enumerate(texts):
            p = os.path.join(FRAMES, f"{name}_{i+1}.png")
            render_frame(t, is_last=(i == len(texts) - 1), path=p)
            pngs.append(p)
        mp4 = os.path.join(OUT, f"{name}.mp4")
        build_mp4(pngs, mp4)
        made.append(mp4)
        print(f"  ✓ {name}.mp4  ({len(pngs)} кадъра)")

    # ---- Верификация ----
    print(f"\nOUT: {OUT}")
    print(f"Готови клипове: {len(made)}")
    for mp4 in made:
        r = subprocess.run([FFMPEG, "-i", mp4], capture_output=True, text=True)
        info = next((l.strip() for l in r.stderr.splitlines() if "Video:" in l), "?")
        dur = next((l.strip() for l in r.stderr.splitlines() if "Duration" in l), "?")
        res_ok = "1080x1920" in info
        print(f"  {os.path.basename(mp4):26s} {'1080x1920 OK' if res_ok else 'BAD RES'} | {dur.split(',')[0]}")


if __name__ == "__main__":
    main()
