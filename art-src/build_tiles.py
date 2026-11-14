"""Build the 16x16 tilesets from the generated tile sheets.

python3 -I art-src/build_tiles.py <repo_root> [--force]
Existing output files are kept unless --force is passed.

Inputs (see docs/assets.md):
  art-src/gen/tiles-floor1-sheet.png  4x4 dungeon tiles on magenta
  art-src/gen/tiles-props-sheet.png   pillar, crate, chest, open chest, torch
  art-src/gen/tiles-town-sheet.png    4x4 town tiles on magenta
Outputs:
  game/assets/tiles/floor1.png, floor2.png, floor3.png  8x2 tiles, layout of
    TILES in make_placeholders.py / world/room_tiles.gd
  game/assets/tiles/town.png  8x2 tiles, layout in TOWN below and docs/assets.md

Floors 2 and 3 are floor 1 with the stone (low saturation pixels) re-hued:
floor 2 cold blue, floor 3 dark red ember. Wood, gold, fire and the red lock
keep their colours.
"""
import colorsys
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

from artlib import frames, key_magenta, parse_args, save_guarded  # noqa: E402

T = 16
COLORS = 32

# Grid cells of the generated 4x4 sheets: (x0, x1) per column, (y0, y1) per row.
FLOOR_COLS = [(7, 250), (263, 506), (518, 761), (774, 1017)]
FLOOR_ROWS = [(7, 248), (260, 504), (515, 759), (770, 1015)]
TOWN_COLS = [(8, 250), (263, 505), (519, 761), (775, 1017)]
TOWN_ROWS = [(7, 250), (261, 505), (517, 761), (772, 1016)]

# Town atlas (col, row) -> (name, source cell (col, row), crop) ; crop is the
# fraction of the source cell kept (centre-left-top anchored), smaller keeps
# bigger texture features.
TOWN = {
    (0, 0): ("cobble_a", (0, 0), 0.5),
    (1, 0): ("cobble_b", (1, 0), 0.5),
    (2, 0): ("grass", (2, 0), 0.5),
    (3, 0): ("grass_flowers", (3, 0), 0.5),
    (4, 0): ("wood_planks", (0, 1), 0.5),
    (5, 0): ("dirt", (1, 1), 0.5),
    (6, 0): ("roof", (2, 1), 0.5),
    (7, 0): ("wall_face", (3, 1), 0.55),
    (0, 1): ("awning", (0, 2), 1.0),
    (1, 1): ("awning_edge", (1, 2), 1.0),
    (2, 1): ("house_wall", (2, 2), 1.0),
    (3, 1): ("house_door", (3, 2), 1.0),
    (4, 1): ("house_window", (0, 3), 1.0),
    (5, 1): ("banner", (1, 3), 1.0),
    (6, 1): ("wall_top", (2, 3), 1.0),
    (7, 1): ("water", (3, 3), 0.5),
}


def cell(img, cols, rows, c, r, frac=1.0, inset=0):
    x0, x1 = cols[c]
    y0, y1 = rows[r]
    x0, y0, x1, y1 = x0 + inset, y0 + inset, x1 - inset, y1 - inset
    side = min(x1 - x0, y1 - y0)
    k = round(side * frac)
    return img.crop((x0, y0, x0 + k, y0 + k))


def down(img, w=T, h=T):
    small = img.resize((w, h), Image.BOX)
    if small.mode == "RGBA":
        small.putalpha(small.getchannel("A").point(lambda v: 255 if v >= 110 else 0))
    return small


FLOOR_MEAN = (84, 72, 60)


def normalize(tile, mean, contrast):
    """Move the tile's mean colour to `mean` and scale contrast around it."""
    px = tile.load()
    pts = [px[x, y] for y in range(tile.height) for x in range(tile.width)]
    m = [sum(p[i] for p in pts) / len(pts) for i in range(3)]
    for y in range(tile.height):
        for x in range(tile.width):
            p = px[x, y]
            px[x, y] = tuple(
                max(0, min(255, int(mean[i] + (p[i] - m[i]) * contrast))) for i in range(3)
            ) + (p[3],)
    return tile


def mortar(tile, k=0.62):
    """Darken the top row and left column: a flagstone grid when tiled."""
    px = tile.load()
    for i in range(T):
        for x, y in ((i, 0), (0, i)):
            r, g, b, a = px[x, y]
            px[x, y] = (int(r * k), int(g * k), int(b * k), a)
    return tile


def prop(src, box, w, h):
    return down(src.crop(box), w, h)


def on(base, sprite, x, y, shadow=True):
    out = base.copy()
    if shadow:
        sh = Image.new("RGBA", sprite.size, (14, 10, 14, 150))
        sh.putalpha(sprite.getchannel("A").point(lambda v: 130 if v else 0))
        out.alpha_composite(sh, (x + 1, y + 1))
    out.alpha_composite(sprite, (x, y))
    return out


def floor_tiles(root):
    sheet = key_magenta(Image.open(os.path.join(root, "art-src/gen/tiles-floor1-sheet.png")))
    props_img = key_magenta(Image.open(os.path.join(root, "art-src/gen/tiles-props-sheet.png")))
    pb = frames(props_img)[0]  # pillar, crate, chest, chest open, torch

    def flag(c, r):
        # Inner flagstone, without the ring of small bricks the model drew.
        # Same mean colour and softer contrast for every variant, so the
        # floor does not read as a checkerboard when variants are mixed.
        tile = down(cell(sheet, FLOOR_COLS, FLOOR_ROWS, c, r, inset=34))
        return mortar(normalize(tile, FLOOR_MEAN, 0.7), 0.75)

    floor_a = flag(0, 0)
    wall = down(cell(sheet, FLOOR_COLS, FLOOR_ROWS, 0, 1, frac=0.55))
    tiles = {
        "floor_a": floor_a,
        "floor_b": flag(1, 0),
        "floor_crack": flag(2, 0),
        "floor_moss": flag(3, 0),
        "wall_face": wall,
        "wall_top": normalize(down(cell(sheet, FLOOR_COLS, FLOOR_ROWS, 1, 1, frac=0.5, inset=20)), (28, 25, 32), 0.4),
        "pillar": on(floor_a, desat(prop(props_img, pb[0], 12, 15), 0.35), 2, 0),
        "crate": on(floor_a, prop(props_img, pb[1], 13, 14), 1, 1),
        "door_locked": down(cell(sheet, FLOOR_COLS, FLOOR_ROWS, 0, 2, inset=12)),
        "door_open": down(cell(sheet, FLOOR_COLS, FLOOR_ROWS, 1, 2, inset=12)),
        "door_shut": down(cell(sheet, FLOOR_COLS, FLOOR_ROWS, 2, 2, inset=12)),
        "chest_closed": centre(prop(props_img, pb[2], 14, 12), 1),
        "chest_open": centre(prop(props_img, pb[3], 13, 15), 0),
        "wall_torch": on(wall, prop(props_img, pb[4], 6, 13), 5, 1, shadow=False),
    }
    # The lock is the "locked" signal; make it readable at 16 px.
    px = tiles["door_locked"].load()
    for x, y in ((7, 7), (8, 7), (7, 8), (8, 8)):
        px[x, y] = (236, 44, 36, 255)
    px[7, 7] = (255, 140, 110, 255)
    return tiles


def desat(img, k):
    """Pull saturation down (the generated pillar's torch rim read as gold)."""
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            r2, g2, b2 = colorsys.hsv_to_rgb(h, s * k, v)
            px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return out


def centre(sprite, y):
    out = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    out.alpha_composite(sprite, ((T - sprite.width) // 2, y))
    return out


FLOOR_LAYOUT = {
    (0, 0): "floor_a", (1, 0): "floor_b", (2, 0): "floor_crack", (3, 0): "floor_moss",
    (4, 0): "wall_face", (5, 0): "wall_top", (6, 0): "pillar", (7, 0): "crate",
    (0, 1): "door_locked", (1, 1): "door_open", (2, 1): "door_shut", (3, 1): "chest_closed",
    (4, 1): "chest_open", (5, 1): "wall_torch",
}


def assemble(layout, tiles):
    out = Image.new("RGBA", (T * 8, T * 2), (0, 0, 0, 0))
    for (c, r), name in layout.items():
        out.alpha_composite(tiles[name].convert("RGBA"), (c * T, r * T))
    return out


RESERVED = [(236, 44, 36), (255, 140, 110)]  # lock red, lock highlight


def quantize(img, n=COLORS):
    """Median cut over a sample where saturated pixels (moss, lock, flame,
    gold) count 6x and the light/dark extremes 3x, so small accents keep
    their own palette entries, then nearest-colour mapping without dither."""
    opaque = [p[:3] for p in img.get_flattened_data() if p[3]]
    sample = []
    for p in opaque:
        h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in p))
        k = 6 if s > 0.45 and v > 0.3 else (3 if v > 0.6 or v < 0.12 else 1)
        sample.extend([p] * k)
    simg = Image.new("RGB", (len(sample), 1))
    simg.putdata(sample)
    m = n - len(RESERVED)
    q = simg.quantize(colors=m, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE, kmeans=4)
    pal = q.getpalette()[: m * 3]
    palette = [tuple(pal[i:i + 3]) for i in range(0, len(pal), 3)] + RESERVED
    cache = {}
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if not p[3]:
                px[x, y] = (0, 0, 0, 0)
                continue
            c = p[:3]
            if c not in cache:
                cache[c] = min(palette, key=lambda k: sum((k[i] - c[i]) ** 2 for i in range(3)))
            px[x, y] = cache[c] + (255,)
    return out


def rehue(img, hue, sat, bright):
    """Re-hue the stone: pixels with low saturation get the new hue."""
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if not a:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if s < 0.42:
                s2 = min(1.0, s * 0.5 + sat)
                r2, g2, b2 = colorsys.hsv_to_rgb(hue, s2, min(1.0, v * bright))
                px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return out


def town_tiles(root):
    sheet = key_magenta(Image.open(os.path.join(root, "art-src/gen/tiles-town-sheet.png")))
    tiles = {}
    layout = {}
    for pos, (name, (c, r), frac) in TOWN.items():
        tiles[name] = down(cell(sheet, TOWN_COLS, TOWN_ROWS, c, r, frac=frac))
        layout[pos] = name
    return assemble(layout, tiles)


def main():
    root, force = parse_args(sys.argv)
    out_dir = os.path.join(root, "game/assets/tiles")
    raw = assemble(FLOOR_LAYOUT, floor_tiles(root))
    outputs = {
        "floor1.png": quantize(raw),
        "floor2.png": quantize(rehue(raw, 0.6, 0.16, 0.95)),
        "floor3.png": quantize(rehue(raw, 0.01, 0.22, 0.85)),
        "town.png": quantize(town_tiles(root)),
    }
    for name, img in outputs.items():
        save_guarded(img, os.path.join(out_dir, name), force)


if __name__ == "__main__":
    main()
