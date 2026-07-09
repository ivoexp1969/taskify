#!/usr/bin/env python3
"""Сглобява промо клипчета (mp4, 1080x1920, БЕЗ звук) от PNG кадрите с плавни
crossfade преходи. Всеки клип е с фиксирана обща дължина TARGET сек (времето на
кадър се смята динамично). Накрая прави и един общ дълъг клип (всички серии).
Звук се добавя после в CapCut. Ползва ffmpeg."""
import os
import subprocess

SRC = os.path.expanduser("~/Desktop/taskify_promo")
OUT = os.path.join(SRC, "clips")
os.makedirs(OUT, exist_ok=True)

TARGET = 15.0   # секунди на клип (стандарт за Reels/TikTok/Shorts)
T = 0.6         # секунди преход
FPS = 30

CLIPS = {
    "clip_a_ai.mp4":      ["promo_a1_ai.png", "promo_a2_ai.png", "promo_a3_ai.png", "promo_a4_cta.png"],
    "clip_b_nameday.mp4": ["promo_b1_nameday.png", "promo_b2_nameday.png", "promo_b3_nameday.png", "promo_b4_logo.png"],
    "clip_c_speed.mp4":   ["promo_c1_speed.png", "promo_c2_cta.png"],
    "clip_d_phone.mp4":   ["promo_d1_phone.png", "promo_d2_phone.png", "promo_d3_phone_cta.png"],
    "clip_e_shared.mp4":  ["promo_e1_shared.png", "promo_e2_shared.png", "promo_e3_shared.png", "promo_e4_cta.png"],
    "clip_f_docs.mp4":    ["promo_f1_docs.png", "promo_f2_docs.png", "promo_f3_cta.png"],
}


def build(name, imgs, target=TARGET):
    paths = [os.path.join(SRC, i) for i in imgs]
    for p in paths:
        if not os.path.exists(p):
            print(f"⚠️ липсва {p} — {name} прескочен"); return None
    n = len(paths)
    # обща дължина = n*D - (n-1)*T = target  →  D = (target + (n-1)*T)/n
    D = (target + (n - 1) * T) / n if n > 1 else target
    cmd = ["ffmpeg", "-y"]
    for p in paths:
        cmd += ["-loop", "1", "-t", str(round(D, 3)), "-i", p]

    if n == 1:
        cmd += ["-vf", f"scale=1080:1920,fps={FPS},format=yuv420p"]
    else:
        parts = [f"[{i}:v]scale=1080:1920,fps={FPS},format=yuv420p,setsar=1[v{i}]"
                 for i in range(n)]
        prev = "v0"
        for k in range(1, n):
            off = round(k * (D - T), 3)
            out = f"x{k}" if k < n - 1 else "vout"
            parts.append(f"[{prev}][v{k}]xfade=transition=fade:duration={T}:offset={off}[{out}]")
            prev = out
        cmd += ["-filter_complex", ";".join(parts), "-map", "[vout]"]

    cmd += ["-c:v", "libx264", "-pix_fmt", "yuv420p", "-r", str(FPS),
            "-movflags", "+faststart", os.path.join(OUT, name)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"❌ {name}\n{r.stderr[-600:]}"); return None
    return os.path.join(OUT, name)


def dur(p):
    return subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", p], capture_output=True, text=True).stdout.strip()


made = []
for name, imgs in CLIPS.items():
    p = build(name, imgs)
    if p:
        made.append(p)
        print(f"  {name:22s} {dur(p)}s  {os.path.getsize(p)//1024}KB")

# --- Общ дълъг клип (всички серии, последователно) ---
if made:
    lst = os.path.join(OUT, "_concat.txt")
    with open(lst, "w") as f:
        for p in made:
            f.write(f"file '{p}'\n")
    allp = os.path.join(OUT, "clip_all.mp4")
    r = subprocess.run(
        ["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", lst,
         "-c:v", "libx264", "-pix_fmt", "yuv420p", "-r", str(FPS),
         "-movflags", "+faststart", allp],
        capture_output=True, text=True)
    os.remove(lst)
    if r.returncode == 0:
        print(f"  {'clip_all.mp4':22s} {dur(allp)}s  {os.path.getsize(allp)//1024}KB  (общ)")
    else:
        print(f"❌ clip_all\n{r.stderr[-400:]}")

print(f"\nOUT: {OUT}\nГотови клипчета: {len(made)} + общ")
