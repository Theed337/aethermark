#!/usr/bin/env python3
"""Erzeugt nahtlose Texturen (Albedo-Graustufen/Farbe + Höhe) prozedural. Aufruf: python3 tools/gen_textures.py"""
import numpy as np
from PIL import Image
import os
N = 512
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
rng = np.random.default_rng(7)

def fbm(n=N, octaves=6, base=4, persistence=0.5, seed=0, aniso=(1, 1)):
    """Nahtloses Rauschen über Frequenzraum-Filterung (periodisch)."""
    r = np.random.default_rng(seed)
    out = np.zeros((n, n))
    amp = 1.0
    for o in range(octaves):
        f = base * 2 ** o
        fx, fy = max(int(f * aniso[0]), 1), max(int(f * aniso[1]), 1)
        g = r.random((fy, fx))
        # bikubisch-ähnlich: Fourier-Upsampling, periodisch
        G = np.fft.fft2(g)
        pad = np.zeros((n, n), dtype=complex)
        hy, hx = min(fy, n) // 2, min(fx, n) // 2
        pad[:hy, :hx] = G[:hy, :hx]; pad[-hy:, :hx] = G[-hy:, :hx]
        pad[:hy, -hx:] = G[:hy, -hx:]; pad[-hy:, -hx:] = G[-hy:, -hx:]
        layer = np.real(np.fft.ifft2(pad))
        layer = (layer - layer.min()) / (np.ptp(layer) + 1e-9)
        out += layer * amp
        amp *= persistence
    out = (out - out.min()) / (np.ptp(out) + 1e-9)
    return out

def worley(n=N, cells=10, seed=0):
    r = np.random.default_rng(seed)
    pts = r.random((cells * cells, 2)) * n
    yy, xx = np.mgrid[0:n, 0:n]
    d1 = np.full((n, n), 1e9)
    for px, py in pts:
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                d = np.hypot(xx - (px + ox), yy - (py + oy))
                d1 = np.minimum(d1, d)
    return np.clip(d1 / (n / cells * 0.9), 0, 1)

def ramp(v, stops):
    v = np.clip(v, 0, 1)
    xs = [s[0] for s in stops]
    cols = np.array([s[1] for s in stops], dtype=float)
    out = np.stack([np.interp(v, xs, cols[:, i]) for i in range(3)], -1)
    return out

def save(name, rgb, h=None):
    Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).save(os.path.join(OUT, name + ".png"))
    if h is not None:
        Image.fromarray((np.clip(h, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, name + "_h.png"))

# Gras: feine Halm-Streifung + Flecken
n1 = fbm(seed=1, base=6); n2 = fbm(seed=2, base=40, octaves=3, aniso=(1, 0.25)); n3 = fbm(seed=3, base=3, octaves=3)
h = 0.5 * n1 + 0.5 * n2
c = ramp(h, [(0, (38, 78, 30)), (0.5, (74, 124, 44)), (1, (126, 168, 66))])
c *= (0.82 + 0.36 * n3)[..., None]
save("grass", c, h)
# Erde/Pfad: Kiesel + Maserung
w = worley(seed=4, cells=18); n = fbm(seed=5, base=8)
h = 0.6 * n + 0.4 * (1 - w)
c = ramp(h, [(0, (70, 52, 36)), (0.55, (122, 94, 64)), (1, (170, 140, 102))])
save("dirt", c, h)
# Fels: Risse (Ridged-Rauschen) und Schichten
n = fbm(seed=7, base=4, octaves=7); r1 = 1 - np.abs(fbm(seed=20, base=5, octaves=5) * 2 - 1)
layers = fbm(seed=21, base=3, octaves=3, aniso=(0.3, 3.0))
h = np.clip(0.45 * n + 0.4 * r1 ** 2 + 0.15 * layers, 0, 1)
c = ramp(h, [(0, (98, 100, 108)), (0.5, (134, 136, 142)), (1, (176, 176, 178))])
crack = np.clip((0.35 - np.abs(fbm(seed=22, base=6, octaves=4) - 0.5)) * 6, 0, 1)
c *= (1 - 0.3 * crack)[..., None]
save("rock", c, h)
# Rinde: senkrechte Furchen
n = fbm(seed=8, base=5, octaves=6, aniso=(3.0, 0.25)); m = fbm(seed=9, base=3, octaves=3)
h = np.clip(n * 0.8 + m * 0.2, 0, 1)
c = ramp(h, [(0, (36, 24, 16)), (0.5, (88, 62, 40)), (1, (140, 104, 70))])
save("bark", c, h)
# Laub: Blattflecken
w = worley(seed=10, cells=26); n = fbm(seed=11, base=9, octaves=4)
h = 0.5 * n + 0.5 * w
c = ramp(h, [(0, (30, 66, 30)), (0.5, (62, 118, 50)), (1, (112, 170, 70))])
save("leaves", c, h)
# Stoff: Gewebe
yy, xx = np.mgrid[0:N, 0:N]
weave = (np.sin(xx * 2 * np.pi / 4) * np.sin(yy * 2 * np.pi / 4)) * 0.5 + 0.5
n = fbm(seed=12, base=10, octaves=4)
h = 0.55 * weave + 0.45 * n
c = ramp(h, [(0, (150, 150, 150)), (1, (235, 235, 235))])
save("cloth", c, h)
# Leder/Haut: feine Poren
w = worley(seed=13, cells=40); n = fbm(seed=14, base=12, octaves=4)
h = 0.6 * n + 0.4 * w
c = ramp(h, [(0, (170, 170, 170)), (1, (245, 245, 245))])
save("leather", c, h)
# Metall: gebürstet
n = fbm(seed=15, base=3, octaves=5, aniso=(6.0, 0.1)); s = fbm(seed=16, base=14, octaves=3)
h = 0.7 * n + 0.3 * s
c = ramp(h, [(0, (150, 152, 160)), (1, (235, 238, 245))])
save("metal", c, h)
# Mauerwerk/Ruinen
bw, bh = 128, 64
h = np.zeros((N, N)); idx = np.zeros((N, N))
for row in range(N // bh):
    off = (row % 2) * bw // 2
    for col in range(N // bw + 1):
        x0 = col * bw - off; shade = rng.random()
        for y in range(row * bh, (row + 1) * bh):
            for x in range(x0, x0 + bw):
                xx_ = x % N
                edge = min(x - x0, x0 + bw - 1 - x, y - row * bh, (row + 1) * bh - 1 - y)
                h[y, xx_] = min(edge / 5, 1) * 0.6 + shade * 0.1
                idx[y, xx_] = shade
n = fbm(seed=17, base=12)
h = np.clip(h + n * 0.3, 0, 1)
c = ramp(h, [(0, (46, 46, 52)), (0.5, (128, 122, 114)), (1, (176, 168, 156))])
c *= (0.85 + 0.3 * idx)[..., None]
save("bricks", c, h)
print("fertig:", sorted(os.listdir(OUT)))
