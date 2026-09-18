# -*- coding: utf-8 -*-
"""Generate Google Play phone screenshots (1080x1920, exact 9:16) for Taskify.

Takes raw device captures (1080x2220) from the input folder and composes each
onto a branded canvas: dark vertical gradient background, a centered white bold
caption (auto-wrapped, up to 3 lines) with a short rounded accent bar beneath
it, and the raw screenshot scaled into a rounded phone frame below.

Output: store_metadata/play/screenshots_generated/<locale>/NN.png

Usage:
  python tools/play_screenshots.py --verify   # only validate inputs
  python tools/play_screenshots.py            # generate

Every input must exist and be exactly 1080x2220; otherwise the script stops
with a clear error (it never silently crops).
"""
import os
import sys
import argparse

from PIL import Image, ImageDraw, ImageFont

# ---- Paths ----
INPUT_DIR = r"C:\Users\Admin\Desktop\task_manager 10012026 GOOGLEPLAY\Screenshots 18092026"
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_BASE = os.path.join(REPO_ROOT, "store_metadata", "play", "screenshots_generated")

# ---- Canvas ----
OUT_W, OUT_H = 1080, 1920           # exact 9:16
REQ_W, REQ_H = 1080, 2220           # required raw input size

# ---- Brand palette ----
GRAD_TOP = (0x12, 0x0C, 0x20)       # #120C20
GRAD_BOTTOM = (0x08, 0x06, 0x0F)    # #08060F
# bg intentionally uses the SAME green accents as en (per request).
ACCENT_BAR = {"en": (0x0A, 0xA6, 0x74), "bg": (0x0A, 0xA6, 0x74)}   # saturated bar
ACCENT_TEXT = {"en": (0x2C, 0xD4, 0xA0), "bg": (0x2C, 0xD4, 0xA0)}  # lighter, keyword text
TEXT_COLOR = (245, 245, 250)
FRAME_BORDER = (150, 140, 175)      # thin phone-frame border

# ---- Layout ----
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

# ---- Screenshot sets (index, filename, caption, accent_phrase) ----
# accent_phrase must be a contiguous run of words inside caption; those words are
# drawn in the lighter brand accent color, the rest stays white.
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
]


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
    """Split caption into drawable units of (text, is_accent).

    The accent phrase becomes ONE unit (never broken across lines); every other
    word is its own white unit. Fails loudly if the accent phrase is not found as
    a contiguous run of words (so a typo can't silently drop the highlight).
    """
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
    """Greedy word-wrap over units; each unit stays whole. Returns list of lines,
    each a list of (text, is_accent)."""
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
    for locale, items in SETS.items():
        for idx, fname, _cap, _acc in items:
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


def compose(locale, fname, caption, accent_phrase):
    canvas = make_gradient(OUT_W, OUT_H, GRAD_TOP, GRAD_BOTTOM)
    draw = ImageDraw.Draw(canvas)

    # --- Caption: two-color (white + brand accent keyword), centered, ≤3 lines ---
    font = load_font(62)
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

    # --- Accent bar ---
    ax0 = (OUT_W - ACCENT_W) // 2
    ay0 = text_bottom + ACCENT_GAP
    draw.rounded_rectangle([ax0, ay0, ax0 + ACCENT_W, ay0 + ACCENT_H],
                           radius=ACCENT_H // 2, fill=ACCENT_BAR[locale])
    accent_bottom = ay0 + ACCENT_H

    # --- Phone image (scaled into rounded frame) ---
    raw = Image.open(os.path.join(INPUT_DIR, fname)).convert("RGB")
    phone_top = accent_bottom + PHONE_GAP
    avail_w = OUT_W - 2 * PHONE_SIDE_MARGIN
    avail_h = OUT_H - BOTTOM_MARGIN - phone_top
    scale = min(avail_w / raw.width, avail_h / raw.height)
    pw, ph = max(1, round(raw.width * scale)), max(1, round(raw.height * scale))
    phone = raw.resize((pw, ph), Image.LANCZOS)

    px = (OUT_W - pw) // 2
    py = phone_top + (avail_h - ph) // 2   # vertically centered in its region

    # rounded-corner mask
    mask = Image.new("L", (pw, ph), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, pw - 1, ph - 1],
                                           radius=FRAME_RADIUS, fill=255)
    canvas.paste(phone, (px, py), mask)

    # thin rounded border
    draw.rounded_rectangle([px, py, px + pw - 1, py + ph - 1],
                           radius=FRAME_RADIUS, outline=FRAME_BORDER,
                           width=FRAME_BORDER_W)
    return canvas


def generate():
    written = []
    for locale, items in SETS.items():
        out_dir = os.path.join(OUT_BASE, locale)
        os.makedirs(out_dir, exist_ok=True)
        for idx, fname, caption, accent in items:
            img = compose(locale, fname, caption, accent)
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
    args = ap.parse_args()

    errors = verify_inputs()
    if errors:
        print("INPUT VERIFICATION FAILED:", file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        sys.exit(1)
    print("Input verification OK: all 8 files exist and are %dx%d." % (REQ_W, REQ_H))

    if args.verify:
        return
    generate()
    print("Done. Output in:", OUT_BASE)


if __name__ == "__main__":
    main()
