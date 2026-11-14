"""Build the final boss sheet from the generated pose.

python3 -I art-src/build_boss.py <repo_root>

Input: art-src/gen/boss-final.png (magenta background, AI generator
`cinzel-boss-final`, see docs/assets.md).
Output: game/assets/enemies/boss_final.png, 4 cols x 4 rows of 32x32 (rows
idle, move, attack, death; 4 frames each). Same frame recipe as
build_enemies.py (one pose, transformed, downscaled, outlined, quantized),
with 32 px cells.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import ImageEnhance  # noqa: E402

import build_enemies as be  # noqa: E402

be.E = 32
COLORS = 32


def despeckle(cell):
    """Drop opaque pixels with at most one opaque neighbour (cloak fringe)."""
    E = be.E
    a = cell.getchannel("A").load()
    out = cell.copy()
    px = out.load()
    for y in range(E):
        for x in range(E):
            if a[x, y]:
                n = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                        if 0 <= x + dx < E and 0 <= y + dy < E and a[x + dx, y + dy])
                if n <= 1:
                    px[x, y] = (0, 0, 0, 0)
    return out


def finish(cell):
    """1 px dark outline plus a soft top rim (the shared one is too hot here)."""
    E = be.E
    a = cell.getchannel("A").load()
    out = cell.copy()
    px = out.load()
    src = cell.load()
    for y in range(E):
        for x in range(E):
            if not a[x, y]:
                continue
            edge = any(not (0 <= x + dx < E and 0 <= y + dy < E) or not a[x + dx, y + dy]
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if y > 0 and not a[x, y - 1] and y < 8:
                r, g, b, _ = src[x, y]
                px[x, y] = (min(255, r + 45), min(255, g + 40), min(255, b + 45), 255)
            elif edge:
                px[x, y] = be.OUTLINE
    return out


def boss(src):
    # Charcoal armour vanishes on the dark floor; lift it, keep the ember red.
    src = ImageEnhance.Brightness(src).enhance(1.5)
    src = ImageEnhance.Contrast(src).enhance(1.2)
    s = 30 / src.height
    f = lambda **k: be.frame(src, s, **k)  # noqa: E731
    glow = lambda k: (lambda i: be.tint(i, be.RED, k))  # noqa: E731
    dark = lambda k: (lambda i: be.darken(i, k))  # noqa: E731
    return [
        [f(), f(sy=0.98, dy=1), f(), f(sy=0.98, dy=1)],
        [f(dx=-1, rot=2), f(dy=-1), f(dx=1, rot=-2), f(dy=-1)],
        [f(rot=6, dx=-1, fx=glow(0.08)), f(rot=10, dx=-2, sy=1.03, fx=glow(0.18)),
         f(rot=-8, dx=2, fx=glow(0.18)), f(rot=-3, fx=glow(0.05))],
        [f(rot=-6, fx=dark(0.8)), f(rot=-18, sy=0.88, fx=dark(0.65)),
         f(rot=-55, sy=0.72, fx=dark(0.5)), f(rot=-90, sy=0.6, fx=lambda i: be.fade(be.darken(i, 0.4), 0.9))],
    ]


def main():
    root = sys.argv[1]
    grid = boss(be.source(root, "gen/boss-final.png"))
    cells = be.quantize([finish(despeckle(c)) for row in grid for c in row], COLORS)
    E = be.E
    sheet = be.Image.new("RGBA", (E * 4, E * 4), (0, 0, 0, 0))
    for k, c in enumerate(cells):
        sheet.alpha_composite(c, ((k % 4) * E, (k // 4) * E))
    sheet.save(os.path.join(root, "game/assets/enemies/boss_final.png"))


if __name__ == "__main__":
    main()
