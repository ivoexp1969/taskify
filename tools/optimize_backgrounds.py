#!/usr/bin/env python3
"""Оптимизира свалени снимки за фон на имен-ден картичките.
Взима произволни изображения (Unsplash/Pexels, БЕЗ хора: цветя/свещи/празнично),
cover-crop-ва ги до платното 1080x1350 и ги записва компресирани като bg-01.jpg…
за да се сервират от taskify1969.com/imen-den/backgrounds/.

Използване:
  python3 tools/optimize_backgrounds.py [SRC_DIR] [OUT_DIR]
  (по подразбиране SRC=~/Desktop/nameday_bg_src, OUT=~/Desktop/nameday_bg_out)
Резултатът копирай в източника на сайта: taskify-site-deploy/imen-den/backgrounds/
"""
import os, sys
from PIL import Image, ImageOps

CW, CH = 1080, 1350          # платното на картичката
QUALITY = 82                 # JPG качество (баланс размер/вид)
MAX = 8                      # максимум фонове (ротацията в кода е bg-01..bg-08)

SRC = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/Desktop/nameday_bg_src")
OUT = os.path.expanduser(sys.argv[2] if len(sys.argv) > 2 else "~/Desktop/nameday_bg_out")
os.makedirs(OUT, exist_ok=True)

EXT = (".jpg", ".jpeg", ".png", ".webp", ".heic")


def main():
    if not os.path.isdir(SRC):
        print(f"❌ Няма папка {SRC}. Сложи свалените снимки там (без хора: цветя/свещи/празнично).")
        return
    files = sorted(f for f in os.listdir(SRC) if f.lower().endswith(EXT))
    if not files:
        print(f"❌ Няма изображения в {SRC}.")
        return
    if len(files) > MAX:
        print(f"⚠️ {len(files)} снимки — ползвам първите {MAX} (ротацията е bg-01..bg-{MAX:02d}).")
        files = files[:MAX]
    made = 0
    for i, fn in enumerate(files, 1):
        try:
            im = Image.open(os.path.join(SRC, fn))
            im = ImageOps.exif_transpose(im).convert("RGB")
            # cover-crop до точното съотношение на платното
            im = ImageOps.fit(im, (CW, CH), Image.LANCZOS, centering=(0.5, 0.5))
            out = os.path.join(OUT, f"bg-{i:02d}.jpg")
            im.save(out, "JPEG", quality=QUALITY, optimize=True, progressive=True)
            kb = os.path.getsize(out) // 1024
            flag = "OK" if kb <= 300 else "⚠️ голям"
            print(f"  bg-{i:02d}.jpg  {kb}KB  {flag}  (от {fn})")
            made += 1
        except Exception as e:
            print(f"  ❌ {fn}: {e}")
    print(f"\nOUT: {OUT}\nГотови: {made} фона.")
    print("Копирай ги в: taskify-site-deploy/imen-den/backgrounds/  →  wrangler pages deploy .")


if __name__ == "__main__":
    main()
