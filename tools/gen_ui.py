"""Erzeugt die UI-Texturen (Fantasy-Stein mit Goldrahmen) für Aethermark. Selbst entworfen, CC0."""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import os, sys
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)

def noise(w, h, scale=1.0, amp=10):
    n = rng.normal(0, amp, (h, w))
    img = Image.fromarray(np.clip(n + 128, 0, 255).astype("uint8")).filter(ImageFilter.GaussianBlur(scale))
    return (np.asarray(img).astype(float) - 128)

def stone(w, h, base, amp=7):
    arr = np.zeros((h, w, 3), float)
    n = noise(w, h, 1.2, amp * 3) + noise(w, h, 0.4, amp)
    # leichter Vertikalverlauf
    grad = np.linspace(8, -10, h)[:, None]
    for i in range(3):
        arr[..., i] = base[i] + n + grad
    return arr

def to_img(a):
    return Image.fromarray(np.clip(a, 0, 255).astype("uint8"), "RGB").convert("RGBA")

def frame(w, h, base, gold, radius, bw, studs=True, alpha=255):
    a = stone(w, h, base)
    im = to_img(a)
    d = ImageDraw.Draw(im)
    g1 = tuple(int(c * 1.0) for c in gold)
    gd = tuple(int(c * 0.45) for c in gold)
    gl = tuple(min(255, int(c * 1.25)) for c in gold)
    # äußerer dunkler Rand, Goldrahmen mit Fase, innere Linie
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius, outline=(8, 6, 4, 255), width=2)
    d.rounded_rectangle([2, 2, w - 3, h - 3], radius - 1, outline=gd, width=bw)
    d.rounded_rectangle([2 + bw, 2 + bw, w - 3 - bw, h - 3 - bw], radius - 2, outline=g1, width=max(1, bw - 1))
    d.rounded_rectangle([3, 3, w - 4, h - 4], radius - 1, outline=gl + (90,) if False else gl, width=1)
    ii = 4 + bw + 2
    d.rounded_rectangle([ii, ii, w - 1 - ii, h - 1 - ii], max(1, radius - 5), outline=(0, 0, 0, 110), width=1)
    if studs:
        for cx, cy in [(radius, radius), (w - 1 - radius, radius), (radius, h - 1 - radius), (w - 1 - radius, h - 1 - radius)]:
            d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=gd, outline=(10, 8, 4, 255))
            d.ellipse([cx - 2, cy - 2, cx + 1, cy + 1], fill=gl)
    # Alpha-Maske mit abgerundeten Ecken
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], radius, fill=alpha)
    im.putalpha(m)
    return im

GOLD = (214, 170, 72)
frame(96, 96, (22, 36, 52), GOLD, 12, 3).save(f"{OUT}/panel.png")
frame(96, 96, (14, 24, 36), (150, 120, 60), 10, 2, studs=False, alpha=235).save(f"{OUT}/panel_dark.png")
frame(64, 64, (30, 50, 72), (120, 96, 52), 9, 2, studs=False).save(f"{OUT}/btn_normal.png")
frame(64, 64, (44, 78, 108), (236, 196, 96), 9, 2, studs=False).save(f"{OUT}/btn_hover.png")
frame(64, 64, (16, 30, 46), (255, 214, 110), 9, 2, studs=False).save(f"{OUT}/btn_pressed.png")
frame(64, 64, (22, 30, 38), (70, 62, 46), 9, 2, studs=False).save(f"{OUT}/btn_disabled.png")
frame(64, 64, (12, 20, 30), (110, 90, 50), 7, 2, studs=False).save(f"{OUT}/field.png")

# Trennlinie mit Raute
w, h = 256, 12
im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
for x in range(w):
    t = 1 - abs(x - w / 2) / (w / 2)
    d.point((x, h // 2), fill=(214, 170, 72, int(255 * t)))
    d.point((x, h // 2 + 1), fill=(60, 40, 10, int(160 * t)))
d.polygon([(w // 2, 1), (w // 2 + 6, h // 2), (w // 2, h - 2), (w // 2 - 6, h // 2)], fill=(240, 200, 100, 255), outline=(60, 40, 10, 255))
im.save(f"{OUT}/divider.png")

# Leistenfüllung (Verlauf mit Glanz) – wird gestreckt
def bar_fill(name, top, bottom):
    h = 24
    a = np.zeros((h, 8, 4), float)
    for y in range(h):
        t = y / (h - 1)
        c = [top[i] * (1 - t) + bottom[i] * t for i in range(3)]
        shine = 40 * max(0, 1 - abs(t - 0.28) / 0.22)
        a[y, :, :3] = np.array(c) + shine
        a[y, :, 3] = 255
    Image.fromarray(np.clip(a, 0, 255).astype("uint8"), "RGBA").save(f"{OUT}/{name}.png")
bar_fill("bar_red", (240, 90, 70), (140, 24, 24))
bar_fill("bar_gold", (255, 220, 110), (170, 120, 30))
bar_fill("bar_teal", (110, 230, 215), (30, 120, 130))
bar_fill("bar_blue", (110, 170, 255), (30, 60, 150))
print("ok", os.listdir(OUT))
