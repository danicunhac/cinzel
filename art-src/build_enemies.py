"""Build the enemy sheets from the generated single sprites.

python3 -I art-src/build_enemies.py <repo_root>

Inputs (magenta background, AI generator, see docs/assets.md):
  art-src/gen/enemy-crawler.png  slime
  art-src/gen/enemies-sheet.png  hooded caster (shooter)
  art-src/gen/enemy-charger-v2.png  armored beetle-boar
Output: game/assets/enemies/{crawler,shooter,charger}.png, 4 cols x 4 rows of
16x16 (rows idle, move, attack, death; 4 frames each).

Each frame is a transform of the one generated pose done at full resolution
(squash, offset, tilt, red flash, sink), then box-downscaled with the same
scale, outlined, rim-lit on the top edge and quantized to one palette per
sheet. One pose keeps every frame on-model.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image, ImageEnhance  # noqa: E402

from artlib import OUTLINE, frames, key_magenta  # noqa: E402

E = 16
# Colours per sheet: the charger shell turns to noise with more.
COLORS = {"crawler": 20, "shooter": 20, "charger": 12}


def source(root, rel):
    img = key_magenta(Image.open(os.path.join(root, "art-src", rel)))
    box = frames(img)[0][0]
    return img.crop(box)


def squash(img, sx, sy):
    w, h = img.size
    return img.resize((max(1, round(w * sx)), max(1, round(h * sy))), Image.LANCZOS)


def tint(img, rgb, amount):
    """Blend opaque pixels toward rgb (alpha untouched)."""
    over = Image.new("RGBA", img.size, rgb + (255,))
    mixed = Image.blend(img, over, amount)
    mixed.putalpha(img.getchannel("A"))
    return mixed


def darken(img, k):
    out = ImageEnhance.Brightness(img.convert("RGBA")).enhance(k)
    out.putalpha(img.getchannel("A"))
    return out


def fade(img, k):
    a = img.getchannel("A").point(lambda v: int(v * k))
    out = img.copy()
    out.putalpha(a)
    return out


def frame(src, scale, dx=0.0, dy=0.0, sx=1.0, sy=1.0, rot=0.0, fx=None):
    """Downscale one transformed pose into a 16x16 cell, bottom-centred."""
    img = src
    if sx != 1.0 or sy != 1.0:
        img = squash(img, sx, sy)
    if rot:
        img = img.rotate(rot, resample=Image.BICUBIC, expand=True)
    if fx:
        img = fx(img)
    w, h = img.size
    small = img.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.BOX)
    small.putalpha(small.getchannel("A").point(lambda v: 255 if v >= 110 else 0))
    cell = Image.new("RGBA", (E, E), (0, 0, 0, 0))
    ox = round((E - small.width) / 2 + dx)
    oy = round(E - small.height + dy)
    cell.alpha_composite(small, (max(ox, 0), max(oy, 0)), (max(-ox, 0), max(-oy, 0)))
    return cell


def finish(cell):
    """Dark 1 px outline on the silhouette, then a light rim on the top edge
    so the sprite reads on the dark floor."""
    a = cell.getchannel("A").load()
    out = cell.copy()
    px = out.load()
    src = cell.load()
    for y in range(E):
        for x in range(E):
            if not a[x, y]:
                continue
            open_up = y == 0 or not a[x, y - 1]
            edge = any(
                not (0 <= x + dx < E and 0 <= y + dy < E) or not a[x + dx, y + dy]
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
            )
            if open_up:
                r, g, b, _ = src[x, y]
                px[x, y] = (min(255, r + 90), min(255, g + 80), min(255, b + 80), 255)
            elif edge:
                px[x, y] = OUTLINE
    return out


def quantize(cells, n):
    colors = []
    for c in cells:
        colors.extend(p[:3] for p in c.get_flattened_data() if p[3])
    sample = Image.new("RGB", (len(colors), 1))
    sample.putdata(colors)
    q = sample.quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = q.getpalette()[: n * 3]
    palette = [tuple(pal[i:i + 3]) for i in range(0, len(pal), 3)]
    out = []
    for c in cells:
        c = c.copy()
        px = c.load()
        for y in range(E):
            for x in range(E):
                p = px[x, y]
                if p[3]:
                    best = min(palette, key=lambda k: sum((k[i] - p[i]) ** 2 for i in range(3)))
                    px[x, y] = best + (255,)
        out.append(c)
    return out


RED = (255, 40, 30)


def crawler(src):
    s = 14 / src.width
    f = lambda **k: frame(src, s, **k)  # noqa: E731
    return [
        [f(), f(sx=1.06, sy=0.92), f(), f(sx=0.95, sy=1.06)],
        [f(sx=1.1, sy=0.85), f(sy=1.08, sx=0.92, dy=-2), f(dy=-3), f(sx=1.08, sy=0.9)],
        [f(sx=1.12, sy=0.8), f(sx=0.88, sy=1.15, dy=-2, fx=lambda i: tint(i, RED, 0.25)),
         f(sx=1.1, sy=0.95, fx=lambda i: tint(i, RED, 0.4)), f(sx=1.05, sy=0.9)],
        [f(sx=1.1, sy=0.75, fx=lambda i: darken(i, 0.85)), f(sx=1.2, sy=0.5, fx=lambda i: darken(i, 0.7)),
         f(sx=1.3, sy=0.3, fx=lambda i: darken(i, 0.55)), f(sx=1.35, sy=0.18, fx=lambda i: fade(darken(i, 0.45), 0.9))],
    ]


def shooter(src):
    # The generated caster is near-black; lift it so it reads on the floor.
    src = ImageEnhance.Brightness(src).enhance(1.45)
    s = 15 / src.height
    f = lambda **k: frame(src, s, **k)  # noqa: E731
    glow = lambda k: (lambda i: tint(i, RED, k))  # noqa: E731
    return [
        [f(), f(dy=1, sy=0.97), f(), f(dy=1, sy=0.97)],
        [f(dx=-1), f(dy=-1), f(dx=1), f(dy=-1)],
        [f(sy=1.03, dy=-1), f(dy=-2, fx=glow(0.15)), f(dy=-2, fx=glow(0.3)), f(dy=-1)],
        [f(rot=-8, fx=lambda i: darken(i, 0.8)), f(rot=-20, sy=0.85, fx=lambda i: darken(i, 0.65)),
         f(rot=-60, sy=0.7, fx=lambda i: darken(i, 0.5)), f(rot=-90, sy=0.6, fx=lambda i: fade(darken(i, 0.4), 0.9))],
    ]


def charger(src):
    src = ImageEnhance.Contrast(src).enhance(1.25)
    s = 16 / src.width
    f = lambda **k: frame(src, s, **k)  # noqa: E731
    return [
        [f(), f(sy=0.96), f(), f(sy=0.96)],
        [f(dy=-1), f(rot=-4), f(dy=-1), f(rot=4)],
        [f(rot=8, dx=-1), f(rot=12, dx=-1, fx=lambda i: tint(i, RED, 0.3)),
         f(rot=-6, dx=1, fx=lambda i: tint(i, RED, 0.3)), f(rot=-3)],
        [f(rot=8, fx=lambda i: darken(i, 0.8)), f(rot=25, sy=0.85, fx=lambda i: darken(i, 0.65)),
         f(rot=170, sy=0.8, fx=lambda i: darken(i, 0.5)), f(rot=180, sy=0.6, fx=lambda i: fade(darken(i, 0.4), 0.9))],
    ]


def main():
    root = sys.argv[1]
    jobs = {
        "crawler": (crawler, "gen/enemy-crawler.png"),
        "shooter": (shooter, "gen/enemies-sheet.png"),
        "charger": (charger, "gen/enemy-charger-v2.png"),
    }
    for name, (fn, rel) in jobs.items():
        grid = fn(source(root, rel))
        cells = quantize([finish(c) for row in grid for c in row], COLORS[name])
        sheet = Image.new("RGBA", (E * 4, E * 4), (0, 0, 0, 0))
        for k, c in enumerate(cells):
            sheet.alpha_composite(c, ((k % 4) * E, (k // 4) * E))
        sheet.save(os.path.join(root, "game/assets/enemies", name + ".png"))


if __name__ == "__main__":
    main()
