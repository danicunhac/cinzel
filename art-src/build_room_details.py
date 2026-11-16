"""Room detail art: breakable props and the small floor / wall decals that
game/world/decor_layout.gd scatters along the walls of detailed rooms.

python3 -I art-src/build_room_details.py <repo_root> [--force]

Inputs (see docs/assets.md):
  art-src/gen/breakables-sheet.png  3x2 on magenta: pot intact, cracked,
    smashed; crate intact, cracked, smashed.
  art-src/gen/floor-decals-sheet.png  4x4 on magenta (order = DECALS).
Outputs:
  game/assets/rooms/breakables.png  3 columns (intact, cracked, broken) x 2
    rows (pot, crate) of 24x24, bottom-centred; one scale per row so the three
    frames of a prop match.
  game/assets/rooms/details.png  one row of 24x24 frames in DECALS order
    (wall pieces bottom-centred, floor decals centred).
Both <= 48 colours, binary alpha.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

from artlib import count_colors, key_magenta, parse_args, save_guarded  # noqa: E402

BREAK_SRC = "art-src/gen/breakables-sheet.png"
BREAK_OUT = "game/assets/rooms/breakables.png"
DECAL_SRC = "art-src/gen/floor-decals-sheet.png"
DECAL_OUT = "game/assets/rooms/details.png"
CELL = 24
COLORS = 48
# Height of the intact prop of each breakables row (px).
BREAK_H = {"pot": 14, "crate": 15}
# Sheet order (4 columns x 4 rows): name, box the decal is reduced into, and
# whether it is kept (None = not used: the sheet's wall crack and soot carry
# their own bricks, which do not match the painted walls).
DECALS = [
    ("crack", (20, 16)), ("crack_zig", (12, 16)), ("chips", (13, 9)), ("grime", (20, 14)),
    ("puddle", (17, 9)), ("puddle_small", (10, 6)), ("moss", (14, 10)), ("pebbles", (12, 8)),
    ("arrow", (18, 18)), ("arrows", (16, 16)), ("bones", (15, 10)), ("leaves", (15, 11)),
    (None, None), ("chain", (6, 17)), ("shelf", (17, 13)), (None, None),
]
WALL = {"chain", "shelf"}
# Objects get a 1 px dark outline after the reduction (flat stains do not).
OUTLINED = {"shelf"}
OUTLINE = (28, 18, 22, 255)
# Share of a source block that must be opaque for the reduced pixel to be
# opaque: low for thin line art (cracks, arrows) so lines stay connected.
THIN = {"crack", "crack_zig", "arrow", "arrows", "chain", "leaves"}
# Stains become one flat colour (the sheet dithers them, which reads as noise).
FLAT = {"grime"}
# Cracks take the darkest source pixels of a block (a dark hairline).
DARK = {"crack", "crack_zig"}


def reduce(img, size, cover, dark=False):
    """Area reduction that keeps thin lines: a target pixel is opaque when at
    least `cover` of its source block is, coloured by the mean of the opaque
    source pixels only (no blending with the background)."""
    a = np.asarray(img.convert("RGBA"), dtype=np.float32)
    h, w = a.shape[:2]
    out = np.zeros((size[1], size[0], 4), dtype=np.uint8)
    ys = np.linspace(0, h, size[1] + 1).astype(int)
    xs = np.linspace(0, w, size[0] + 1).astype(int)
    for j in range(size[1]):
        for i in range(size[0]):
            blk = a[ys[j]:max(ys[j + 1], ys[j] + 1), xs[i]:max(xs[i + 1], xs[i] + 1)].reshape(-1, 4)
            on = blk[blk[:, 3] > 127]
            if len(on) and len(on) >= cover * len(blk):
                if dark:
                    on = on[np.argsort(on[:, :3].sum(1))][:max(1, len(on) // 3)]
                out[j, i, :3] = on[:, :3].mean(0)
                out[j, i, 3] = 255
    return Image.fromarray(out, "RGBA")


def flat(img):
    """Every opaque pixel in the mean opaque colour, darkened a little."""
    a = np.asarray(img, dtype=np.float32).copy()
    on = a[..., 3] > 0
    if on.any():
        a[on, :3] = a[on, :3].mean(0) * 0.8
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def outline(img, x0, y0, w, h):
    """1 px dark outline around the opaque pixels inside the box."""
    px = img.load()
    add = []
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if x0 <= nx < x0 + w and y0 <= ny < y0 + h and px[nx, ny][3] and px[nx, ny] != OUTLINE:
                    add.append((x, y))
                    break
    for p in add:
        px[p] = OUTLINE


def cells(src, cols, rows):
    cw, ch = src.width // cols, src.height // rows
    for i in range(cols * rows):
        c = src.crop(((i % cols) * cw, (i // cols) * ch, (i % cols + 1) * cw, (i // cols + 1) * ch))
        yield i, c.crop(c.getbbox())


def finish(img):
    alpha = img.getchannel("A").point(lambda v: 255 if v >= 110 else 0)
    q = img.quantize(colors=COLORS, method=Image.Quantize.FASTOCTREE, kmeans=4, dither=Image.Dither.NONE)
    out = q.convert("RGBA")
    out.putalpha(alpha)
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if px[x, y][3] == 0:
                px[x, y] = (0, 0, 0, 0)
    return out


def build_breakables(root, force):
    src = key_magenta(Image.open(os.path.join(root, BREAK_SRC)))
    parts = dict(cells(src, 3, 2))
    sheet = Image.new("RGBA", (CELL * 3, CELL * 2), (0, 0, 0, 0))
    for row, name in enumerate(("pot", "crate")):
        k = BREAK_H[name] / parts[row * 3].height
        for col in range(3):
            c = parts[row * 3 + col]
            size = (max(1, round(c.width * k)), max(1, round(c.height * k)))
            size = (min(size[0], CELL - 2), min(size[1], CELL - 1))
            small = reduce(c, size, 0.5)
            sheet.paste(small, (col * CELL + (CELL - size[0]) // 2, row * CELL + CELL - 1 - size[1]), small)
            print("%-6s %d %s" % (name, col, size))
    out = finish(sheet)
    for i in range(6):
        outline(out, (i % 3) * CELL, (i // 3) * CELL, CELL, CELL)
    print("breakables colours:", count_colors(out))
    save_guarded(out, os.path.join(root, BREAK_OUT), force)


def build_decals(root, force):
    src = key_magenta(Image.open(os.path.join(root, DECAL_SRC)))
    kept = [(i, n, b) for i, (n, b) in enumerate(DECALS) if n]
    strip = Image.new("RGBA", (CELL * len(kept), CELL), (0, 0, 0, 0))
    parts = dict(cells(src, 4, 4))
    for j, (i, name, box) in enumerate(kept):
        c = parts[i]
        k = min(box[0] / c.width, box[1] / c.height)
        size = (max(1, round(c.width * k)), max(1, round(c.height * k)))
        small = reduce(c, size, 0.2 if name in THIN else (0.3 if name in FLAT else 0.5), name in DARK)
        if name in FLAT:
            small = flat(small)
        y = CELL - 1 - size[1] if name in WALL else (CELL - size[1]) // 2
        strip.paste(small, (j * CELL + (CELL - size[0]) // 2, y), small)
        print("%-12s %s" % (name, size))
    out = finish(strip)
    for j, (_i, name, _b) in enumerate(kept):
        if name in OUTLINED:
            outline(out, j * CELL, 0, CELL, CELL)
    print("details colours:", count_colors(out))
    save_guarded(out, os.path.join(root, DECAL_OUT), force)


def main(argv):
    root, force = parse_args(argv)
    build_breakables(root, force)
    build_decals(root, force)


if __name__ == "__main__":
    main(sys.argv)
