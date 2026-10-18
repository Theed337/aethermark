"""Erzeugt die FX-Texturen (weiche Glows, Funken, Rauch, Ringe) prozedural. Eigene Arbeit, CC0."""
import numpy as np
from PIL import Image
S = 128
y, x = np.mgrid[0:S, 0:S].astype(np.float32)
cx = cy = (S - 1) / 2
r = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / (S / 2)
ang = np.arctan2(y - cy, x - cx)

def save(name, a):
    a = np.clip(a, 0, 1)
    img = np.zeros((S, S, 4), np.uint8)
    img[..., :3] = 255
    img[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(f"assets/fx/{name}.png")

edge = np.clip(1 - r, 0, 1)
save("glow", edge ** 2.2)
save("flash", np.clip((1 - r) ** 3 * 1.6 + (np.clip(1 - np.abs((x - cx) / (S / 2) * 6), 0, 1) * np.clip(1 - np.abs(y - cy) / (S / 2), 0, 1) ** 2) * 0.9 + (np.clip(1 - np.abs((y - cy) / (S / 2) * 6), 0, 1) * np.clip(1 - np.abs(x - cx) / (S / 2), 0, 1) ** 2) * 0.9, 0, 1) * edge ** 0.4)
# Funke: schmale Raute
dx = np.abs(x - cx) / (S / 2)
dy = np.abs(y - cy) / (S / 2)
save("spark", np.clip(1 - (dx * 3.2 + dy * 0.9), 0, 1) ** 1.5 + np.clip(1 - (dx * 0.9 + dy * 3.2), 0, 1) ** 1.5 * 0.5)
# Ring
ring = np.exp(-((r - 0.78) / 0.09) ** 2) + 0.25 * np.exp(-((r - 0.6) / 0.2) ** 2)
save("ring", ring * (r < 1))
# Rauch: Mehrfach-Rauschen
rng = np.random.default_rng(3)
def noise(sz):
    n = rng.random((sz, sz)).astype(np.float32)
    return np.array(Image.fromarray((n * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC)).astype(np.float32) / 255
n = noise(6) * 0.5 + noise(12) * 0.3 + noise(24) * 0.2
save("smoke", (n * 1.2 - 0.25) * np.clip(1 - r, 0, 1) ** 0.8)
# Flamme / Tropfen
fl = np.clip(1 - (dx * 2.2 + np.where(y < cy, (cy - y) / S * 1.0, (y - cy) / S * 2.6)), 0, 1) ** 1.3
save("flame", fl)
# Strahl-Kern (für Beams, horizontal weich)
save("soft_line", np.clip(1 - dx * 2, 0, 1) ** 1.6)
print("ok")
