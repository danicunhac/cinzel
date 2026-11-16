"""Build the town villager sheets from the generated walk sheets.

python3 -I art-src/build_villagers.py <repo_root> [--force]

Inputs (see docs/assets.md), one per look, on flat magenta:
  art-src/gen/villager-<look>.png  3 rows x 4 walk poses: down, up, side
                                   (side faces right)
Outputs in game/assets/characters/villagers/:
  <look>.png 128x192, 4 columns x 6 rows of 32x32 cells:
    row 0-2  idle down, up, side (2 frames: stand, torso 1 px lower)
    row 3-5  walk down, up, side (4 frames)
  Feet on row 30, body centred on column 16, <= 32 colours, 1 px outline.
  One scale for every look (the tallest pose fills TALL px), so a child
  stays smaller than a guard.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

from artlib import OUTLINE, count_colors, frames, parse_args, save_guarded  # noqa: E402

LOOKS = ["oldwoman", "child", "guard", "farmer", "archer", "merchant"]
CELL = 32
FEET = 30
TALL = 30
COLORS = 32


def key(img):
    """Bright magenta -> transparent, its blended fringe -> outline. Stricter
    than artlib.key_magenta so the merchant's purple cloak survives."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            if r > 190 and b > 190 and g < 110:
                px[x, y] = (0, 0, 0, 0)
            elif min(r, b) - g > 60 and r > 150 and b > 150:
                px[x, y] = OUTLINE
    return img


def poses(path):
    """3 rows of 4 keyed poses (cropped to their opaque box)."""
    keyed = key(Image.open(path))
    grid = frames(keyed, min_gap=20)
    assert len(grid) == 3 and all(len(r) == 4 for r in grid), "%s: grid %s" % (
        path, [len(r) for r in grid])
    return [[keyed.crop(b) for b in row] for row in grid]


def shrink(img, k):
    w, h = max(1, round(img.width * k)), max(1, round(img.height * k))
    small = img.resize((w, h), Image.BOX)
    small.putalpha(small.getchannel("A").point(lambda v: 255 if v >= 140 else 0))
    return small


def body_x(img):
    """Centre column of the lower half (legs and torso), ignoring held props."""
    a = img.getchannel("A").load()
    xs = [x for y in range(img.height // 2, img.height) for x in range(img.width) if a[x, y]]
    return round(sum(xs) / len(xs)) if xs else img.width // 2


def place(img):
    """32x32 cell with the pose's feet on FEET and its body on column 16."""
    cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    bb = img.getchannel("A").getbbox()
    img = img.crop(bb)
    x = CELL // 2 - body_x(img)
    y = FEET + 1 - img.height
    cell.alpha_composite(img, (max(0, min(CELL - img.width, x)), max(0, y)))
    return cell


def bob(cell):
    """Second idle frame: everything above the feet 1 px lower."""
    out = cell.copy()
    top = cell.crop((0, 0, CELL, FEET - 4))
    out.paste((0, 0, 0, 0), (0, 0, CELL, FEET - 3))
    out.alpha_composite(top, (0, 1))
    return out


def outline(cell):
    """1 px OUTLINE on transparent pixels touching the shape (inside the cell)."""
    a = cell.getchannel("A").load()
    px = cell.load()
    ring = [(x, y) for y in range(CELL) for x in range(CELL) if not a[x, y] and any(
        0 <= x + dx < CELL and 0 <= y + dy < CELL and a[x + dx, y + dy]
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for x, y in ring:
        if y <= FEET:
            px[x, y] = OUTLINE
    return cell


def quantize(img, colors):
    alpha = img.getchannel("A")
    q = img.convert("RGB").quantize(colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out = q.convert("RGB").convert("RGBA")
    out.putalpha(alpha)
    return out


def sheet(rows, k):
    out = Image.new("RGBA", (CELL * 4, CELL * 6), (0, 0, 0, 0))
    for r, row in enumerate(rows):
        cells = [place(shrink(p, k)) for p in row]
        # Idle: the narrowest walk pose (legs together) and its bob.
        stand = min(cells, key=lambda c: c.getchannel("A").getbbox()[2] - c.getchannel("A").getbbox()[0])
        for c, img in enumerate([stand, bob(stand)]):
            out.alpha_composite(img, (c * CELL, r * CELL))
        for c, img in enumerate(cells):
            out.alpha_composite(img, (c * CELL, (r + 3) * CELL))
    out = quantize(out, COLORS - 1)
    for r in range(6):
        for c in range(4):
            box = (c * CELL, r * CELL, c * CELL + CELL, r * CELL + CELL)
            out.paste(outline(out.crop(box)), box[:2])
    return out


def main(argv):
    root, force = parse_args(argv)
    gen = os.path.join(root, "art-src", "gen")
    out_dir = os.path.join(root, "game", "assets", "characters", "villagers")
    os.makedirs(out_dir, exist_ok=True)
    all_poses = {n: poses(os.path.join(gen, "villager-%s.png" % n)) for n in LOOKS}
    tallest = max(p.height for rows in all_poses.values() for row in rows for p in row)
    k = TALL / float(tallest)
    for n in LOOKS:
        img = sheet(all_poses[n], k)
        assert count_colors(img) <= COLORS, "%s has %d colours" % (n, count_colors(img))
        save_guarded(img, os.path.join(out_dir, n + ".png"), force)


if __name__ == "__main__":
    main(sys.argv)
