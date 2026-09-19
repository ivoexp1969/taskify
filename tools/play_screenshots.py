# -*- coding: utf-8 -*-
"""Generate branded store screenshots for Taskify.

Two output modes, ONE visual style (dark vertical gradient, centered white bold
caption with an accent keyword + a short rounded accent bar beneath it, and the
raw device capture scaled into a rounded phone frame):

  Google Play (default): 1080x1920 (exact 9:16) -> store_metadata/play/screenshots_generated/<locale>/NN.png
  App Store  (--ios)   : 1290x2796 (iPhone 6.9")  -> store_metadata/appstore/en-US/NN.png (EN only)

The iOS layout constants are the Play constants scaled by COEF = 2796/1920
(≈1.456) so the vertical rhythm/frame stay in the same proportions on the taller,
narrower iOS canvas (computed, not hand-tuned).

Usage:
  python tools/play_screenshots.py --verify        # validate Play inputs
  python tools/play_screenshots.py                 # generate Play (1080x1920)
  python tools/play_screenshots.py --ios --verify  # validate iOS (EN) inputs
  python tools/play_screenshots.py --ios           # generate App Store (1290x2796)

Every input must exist and be exactly 1080x2220; otherwise the script stops with
a clear error (it never silently crops).
"""
import os
import sys
import argparse

from PIL import Image, ImageDraw, ImageFont

# ---- Paths ----
INPUT_DIR = r"C:\Users\Admin\Desktop\task_manager 10012026 GOOGLEPLAY\Screenshots 18092026"
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_BASE_PLAY = os.path.join(REPO_ROOT, "store_metadata", "play", "screenshots_generated")
OUT_BASE_APPSTORE = os.path.join(REPO_ROOT, "store_metadata", "appstore")

# ---- Canvas (Play defaults; overridden by configure(ios=True)) ----
OUT_W, OUT_H = 1080, 1920           # exact 9:16
REQ_W, REQ_H = 1080, 2220           # required raw input size (both modes)

# ---- iOS scale factor (taller/narrower 1290x2796 canvas) ----
IOS_W, IOS_H = 1290, 2796           # iPhone 6.9" required App Store size
COEF = IOS_H / 1920                 # ≈1.45625 — scale Play layout up to iOS height

# ---- Brand palette (identical in both modes) ----
GRAD_TOP = (0x12, 0x0C, 0x20)       # #120C20
GRAD_BOTTOM = (0x08, 0x06, 0x0F)    # #08060F
ACCENT_BAR = {"en": (0x0A, 0xA6, 0x74), "bg": (0x0A, 0xA6, 0x74)}   # #0AA674 saturated bar
ACCENT_TEXT = {"en": (0x2C, 0xD4, 0xA0), "bg": (0x2C, 0xD4, 0xA0)}  # #2CD4A0 keyword text
TEXT_COLOR = (245, 245, 250)
FRAME_BORDER = (150, 140, 175)      # thin phone-frame border

# ---- Layout (Play values; scaled by COEF in configure(ios=True)) ----
SIDE_MARGIN = 80                    # text wrap margin
TEXT_TOP = 110                      # caption baseline start
LINE_SPACING = 12
ACCENT_W, ACCENT_H = 150, 12
ACCENT_GAP = 46                     # gap text -> accent bar
PHONE_GAP = 60                      # gap accent bar -> phone
PHONE_SIDE_MARGIN = 95              # min side margin for the phone image
BOTTOM_MARGIN = 80
FRAME_RADIUS = 60
FRAME_BORDER_W = 3
FONT_SIZE = 62

# ---- Output routing (set by configure) ----
OUT_BASE = OUT_BASE_PLAY
ACTIVE_LOCALES = ("en", "bg")       # Play does both; iOS overrides to ("en",)
LOCALE_DIR = {"en": "en", "bg": "bg"}  # iOS overrides en -> "en-US"

# ---- Screenshot sets (index, filename, caption, accent_phrase) ----
SETS = {
    "en": [
        (1, "Screenshot_20260918-172359.jpg", "Your tasks and calendar, together", "together"),
        (2, "Screenshot_20260918-171553.jpg", "Every task, organised by day", "by day"),
        (3, "Screenshot_20260918-172420.jpg", "Syncs with Google Calendar", "Google Calendar"),
        (4, "Screenshot_20260918-171508.jpg", "Never miss an expiring document", "Never miss"),
    ],
    "bg": [
        (1, "Screenshot_20260918-165406.jpg", "Задачите и календарът — заедно", "заедно"),
        (2, "Screenshot_20260918-170657.jpg", "Всяка задача, подредена по дни", "по дни"),
        (3, "Screenshot_20260918-170454.jpg", "Синхронизация с Google Календар", "Google Календар"),
        (4, "Screenshot_20260918-165413.jpg", "Не пропускай изтичащ документ", "Не пропускай"),
    ],
}

FONT_CANDIDATES = [
    r"C:\Windows\Fonts\arialbd.ttf",
    r"C:\Windows\Fonts\seguisb.ttf",
    r"C:\Windows\Fonts\arial.ttf",
    # macOS fallbacks (so a preview can render on the Mac too):
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/Library/Fonts/Arial Bold.ttf",
]


def configure(ios):
    """Switch all canvas/layout/output globals between Play and iOS modes.

    iOS scales every Play layout constant by COEF so the composition keeps the
    same visual proportions on the taller 1290x2796 canvas (computed from the
    coefficient, not hand-picked)."""
    global OUT_W, OUT_H, SIDE_MARGIN, TEXT_TOP, LINE_SPACING, ACCENT_W, ACCENT_H
    global ACCENT_GAP, PHONE_GAP, PHONE_SIDE_MARGIN, BOTTOM_MARGIN, FRAME_RADIUS
    global FRAME_BORDER_W, FONT_SIZE, OUT_BASE, ACTIVE_LOCALES, LOCALE_DIR
    if not ios:
        return
    s = lambda v: int(round(v * COEF))
    OUT_W, OUT_H = IOS_W, IOS_H
    SIDE_MARGIN = s(80)
    TEXT_TOP = s(110)
    LINE_SPACING = s(12)
    ACCENT_W, ACCENT_H = s(150), s(12)
    ACCENT_GAP = s(46)
    PHONE_GAP = s(60)
    PHONE_SIDE_MARGIN = s(95)
    BOTTOM_MARGIN = s(80)
    FRAME_RADIUS = s(60)
    FRAME_BORDER_W = max(1, s(3))
    FONT_SIZE = s(62)
    OUT_BASE = OUT_BASE_APPSTORE
    ACTIVE_LOCALES = ("en",)
    LOCALE_DIR = {"en": "en-US"}


def load_font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    raise SystemExit("No usable font found among: " + ", ".join(FONT_CANDIDATES))


def make_gradient(w, h, top, bottom):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        r = round(top[0] + (bottom[0] - top[0]) * t)
        g = round(top[1] + (bottom[1] - top[1]) * t)
        b = round(top[2] + (bottom[2] - top[2]) * t)
        for x in range(w):
            px[x, y] = (r, g, b)
    return img


def build_units(caption, accent_phrase):
    """Split caption into drawable units of (text, is_accent). The accent phrase
    is ONE unit (never broken across lines); fails loudly if not found."""
    words = caption.split()
    acc = accent_phrase.split()
    start = -1
    for i in range(len(words) - len(acc) + 1):
        if words[i:i + len(acc)] == acc:
            start = i
            break
    if start < 0:
        raise SystemExit("Accent phrase %r not found in caption %r"
                         % (accent_phrase, caption))
    units = []
    i = 0
    while i < len(words):
        if i == start:
            units.append((" ".join(acc), True))
            i += len(acc)
        else:
            units.append((words[i], False))
            i += 1
    return units


def wrap_units(draw, units, font, max_width, max_lines=3):
    space_w = draw.textlength(" ", font=font)
    lines, cur, cur_w = [], [], 0.0
    for unit in units:
        uw = draw.textlength(unit[0], font=font)
        add_w = uw if not cur else space_w + uw
        if cur and cur_w + add_w > max_width:
            lines.append(cur)
            cur, cur_w = [unit], uw
        else:
            cur.append(unit)
            cur_w += add_w
    if cur:
        lines.append(cur)
    return lines[:max_lines]


def verify_inputs():
    errors = []
    for locale in ACTIVE_LOCALES:
        for idx, fname, _cap, _acc in SETS[locale]:
            path = os.path.join(INPUT_DIR, fname)
            if not os.path.exists(path):
                errors.append("%s #%02d: MISSING file %s" % (locale, idx, path))
                continue
            try:
                with Image.open(path) as im:
                    if (im.width, im.height) != (REQ_W, REQ_H):
                        errors.append("%s #%02d: %s is %dx%d, expected %dx%d"
                                      % (locale, idx, fname, im.width, im.height,
                                         REQ_W, REQ_H))
            except Exception as e:
                errors.append("%s #%02d: cannot open %s (%s)" % (locale, idx, fname, e))
    return errors


def compose(locale, raw, caption, accent_phrase):
    """Compose one branded screenshot. [raw] is an already-open RGB Image at the
    raw capture size (so callers can supply a placeholder for previews)."""
    canvas = make_gradient(OUT_W, OUT_H, GRAD_TOP, GRAD_BOTTOM)
    draw = ImageDraw.Draw(canvas)

    font = load_font(FONT_SIZE)
    max_text_w = OUT_W - 2 * SIDE_MARGIN
    units = build_units(caption, accent_phrase)
    lines = wrap_units(draw, units, font, max_text_w, max_lines=3)
    space_w = draw.textlength(" ", font=font)
    ascent, descent = font.getmetrics()
    line_h = ascent + descent
    y = TEXT_TOP
    for line in lines:
        widths = [draw.textlength(u[0], font=font) for u in line]
        total = sum(widths) + space_w * (len(line) - 1)
        x = (OUT_W - total) / 2
        for j, u in enumerate(line):
            color = ACCENT_TEXT[locale] if u[1] else TEXT_COLOR
            draw.text((x, y), u[0], font=font, fill=color)
            x += widths[j] + (space_w if j < len(line) - 1 else 0)
        y += line_h + LINE_SPACING
    text_bottom = y - LINE_SPACING

    ax0 = (OUT_W - ACCENT_W) // 2
    ay0 = text_bottom + ACCENT_GAP
    draw.rounded_rectangle([ax0, ay0, ax0 + ACCENT_W, ay0 + ACCENT_H],
                           radius=ACCENT_H // 2, fill=ACCENT_BAR[locale])
    accent_bottom = ay0 + ACCENT_H

    raw = raw.convert("RGB")
    phone_top = accent_bottom + PHONE_GAP
    avail_w = OUT_W - 2 * PHONE_SIDE_MARGIN
    avail_h = OUT_H - BOTTOM_MARGIN - phone_top
    scale = min(avail_w / raw.width, avail_h / raw.height)
    pw, ph = max(1, round(raw.width * scale)), max(1, round(raw.height * scale))
    phone = raw.resize((pw, ph), Image.LANCZOS)

    px = (OUT_W - pw) // 2
    py = phone_top + (avail_h - ph) // 2

    mask = Image.new("L", (pw, ph), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, pw - 1, ph - 1],
                                           radius=FRAME_RADIUS, fill=255)
    canvas.paste(phone, (px, py), mask)

    draw.rounded_rectangle([px, py, px + pw - 1, py + ph - 1],
                           radius=FRAME_RADIUS, outline=FRAME_BORDER,
                           width=FRAME_BORDER_W)
    return canvas


def generate():
    written = []
    for locale in ACTIVE_LOCALES:
        out_dir = os.path.join(OUT_BASE, LOCALE_DIR[locale])
        os.makedirs(out_dir, exist_ok=True)
        for idx, fname, caption, accent in SETS[locale]:
            raw = Image.open(os.path.join(INPUT_DIR, fname))
            img = compose(locale, raw, caption, accent)
            if (img.width, img.height) != (OUT_W, OUT_H):
                raise SystemExit("Composed size wrong: %dx%d" % (img.width, img.height))
            out_path = os.path.join(out_dir, "%02d.png" % idx)
            img.save(out_path, "PNG")
            written.append((locale, out_path, img.width, img.height))
            print("wrote %s (%dx%d)" % (out_path, img.width, img.height))
    return written


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--verify", action="store_true",
                    help="Only validate inputs (existence + exact 1080x2220).")
    ap.add_argument("--ios", action="store_true",
                    help="App Store mode: 1290x2796 (iPhone 6.9''), EN only.")
    args = ap.parse_args()
    configure(ios=args.ios)

    errors = verify_inputs()
    if errors:
        print("INPUT VERIFICATION FAILED:", file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        sys.exit(1)
    n = sum(len(SETS[l]) for l in ACTIVE_LOCALES)
    print("Input verification OK: all %d files exist and are %dx%d." % (n, REQ_W, REQ_H))

    if args.verify:
        return
    generate()
    print("Done. Output in:", OUT_BASE)


if __name__ == "__main__":
    main()
