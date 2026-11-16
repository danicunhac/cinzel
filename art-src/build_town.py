"""Build the town sprites and the town ground from the generated sources.

python3 -I art-src/build_town.py <repo_root> [--force]
Existing output files are kept unless --force is passed.

Inputs (see docs/assets.md), all on flat magenta:
  art-src/gen/town-shop.png       hero shop
  art-src/gen/town-forge.png      forge
  art-src/gen/town-houses.png     house A (timber, ivy)
  art-src/gen/town-houses-b.png   house B (stone), house C (timber, bench)
  art-src/gen/town-crystal.png    crystal on dais
  art-src/gen/town-tower-gate.png base of the tower with the open gate
  art-src/gen/town-props.png      3 trees / lamp, well, planter, flower bed /
                                  fence, post, barrel, crates, sack
  art-src/gen/town-ground.png     ground painted over town-ground-guide.png
  art-src/gen/town-base-decals.png  4x3 ground decals: grass tufts, moss,
                                  loose foundation stones
Outputs in game/assets/town/:
  ground.png 480x270 (opaque, 32 colours)
  one PNG per sprite (SPRITES below). Each sprite is keyed, downscaled to its
  width (or height), quantised to <= 32 colours, outlined with 1 px OUTLINE and
  given a baked ground shadow. The building base line (where the wall meets the
  ground) sits PAD px above the bottom of the image, so the scene puts the
  sprite origin at (w / 2, h - PAD). The canvas has MARGIN px free on both
  sides, so the sprite stays centred.
  Grounding (so pieces sit in the ground instead of floating): the outline is
  dropped along the base, the bottom rows where the object meets the ground
  are darkened (contact occlusion), and the shadow is the silhouette squashed
  onto the ground below the base and leaned right (light from the upper left,
  as in the key art), darker in the 2 rows next to the base.
  crystal_glow.png 48x48 soft blue glow (drawn here, additive in the scene).
  decals.png strip of DECAL px cells (12: 4 grass, 4 moss, 4 stones), each
  decal bottom-centred, dark outline swapped for a dark ground tone so it
  blends into the ground. The scene lays them along building and prop bases.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

from artlib import OUTLINE, count_colors, frames, parse_args, save_guarded  # noqa: E402

COLORS = 32
PAD = 8
MARGIN = 4
SHADOW = (20, 12, 24)
# Shadow length per px of object height, its lean right per px of length,
# and the alphas of the contact rows and of the rest.
SHADOW_LEN = 0.14
SHADOW_LEAN = 0.6
SHADOW_ALPHA = (150, 96)
DECAL = 16
DECAL_SIZES = (14, 12, 10, 8)
DECAL_EDGE = (62, 52, 46, 255)
# Rows above the bottom that count as "on the ground" (base zone).
BASE_ZONE = 3

# name -> (source file, (row, col) in the frames() grid of the keyed source,
#          ("w" or "h", size in px), shadow length scale (0 = no shadow))
SPRITES = {
    "shop": ("town-shop.png", (0, 0), ("w", 104), 1.0),
    "forge": ("town-forge.png", (0, 0), ("w", 104), 1.0),
    "house_a": ("town-houses.png", (0, 0), ("h", 80), 1.0),
    "house_b": ("town-houses-b.png", (0, 0), ("w", 74), 1.0),
    "house_c": ("town-houses-b.png", (0, 1), ("w", 62), 1.0),
    "crystal": ("town-crystal.png", (0, 0), ("h", 60), 1.0),
    "tower_gate": ("town-tower-gate.png", (0, 0), ("h", 88), 1.0),
    # The props sheet rows touch, so its cells are boxes (x0, y0, x1, y1)
    # around each object; the object is the opaque bbox inside the box.
    "tree_a": ("town-props.png", (190, 10, 400, 214), ("w", 54), 1.0),
    "tree_b": ("town-props.png", (460, 40, 620, 212), ("w", 40), 1.0),
    "tree_c": ("town-props.png", (690, 30, 860, 212), ("w", 46), 1.0),
    "lamp": ("town-props.png", (140, 214, 250, 410), ("h", 38), 0.5),
    "well": ("town-props.png", (325, 225, 485, 410), ("w", 34), 1.0),
    "planter": ("town-props.png", (550, 255, 720, 400), ("w", 30), 1.0),
    "flowerbed": ("town-props.png", (785, 265, 945, 400), ("w", 30), 1.0),
    "fence": ("town-props.png", (90, 440, 330, 570), ("w", 40), 0.6),
    "fence_post": ("town-props.png", (370, 440, 450, 570), ("h", 22), 0.6),
    "barrel": ("town-props.png", (510, 440, 610, 570), ("w", 14), 1.0),
    "crates": ("town-props.png", (670, 430, 790, 575), ("w", 18), 1.0),
    "sack": ("town-props.png", (860, 440, 960, 570), ("w", 14), 1.0),
}


def key(img, warm=False):
    """Magenta and the purple shadow the model blends into it -> transparent."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            m = min(r, b) - g
            if m > 40 and abs(r - b) < 70:
                px[x, y] = (0, 0, 0, 0)
            elif m > 22 and max(r, b) < 110 and abs(r - b) < 40:
                # dark purple: the shadow the model painted on magenta
                px[x, y] = (0, 0, 0, 0)
            elif warm and r > 150 and b > 90 and g < r - 60:
                # lamp halo blended with magenta -> warm lamp light
                px[x, y] = (255, 196, 90, 255)
    return img


def shrink(img, size):
    axis, n = size
    if axis == "w":
        w, h = n, max(1, round(img.height * n / img.width))
    else:
        w, h = max(1, round(img.width * n / img.height)), n
    small = img.resize((w, h), Image.BOX)
    small.putalpha(small.getchannel("A").point(lambda v: 255 if v >= 128 else 0))
    return small


def quantize(img, colors):
    alpha = img.getchannel("A")
    q = img.convert("RGB").quantize(colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out = q.convert("RGB").convert("RGBA")
    out.putalpha(alpha)
    return out


def outline(img):
    """1 px OUTLINE ring around the opaque shape (the canvas grows by 1)."""
    w, h = img.size
    out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    out.paste(img, (1, 1))
    a = out.getchannel("A").load()
    px = out.load()
    ring = []
    for y in range(h + 2):
        for x in range(w + 2):
            if a[x, y]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w + 2 and 0 <= ny < h + 2 and a[nx, ny]:
                    ring.append((x, y))
                    break
    for x, y in ring:
        px[x, y] = OUTLINE
    return out


def ground_contact(img):
    """Darken the 2 bottom pixels of every column that reaches the base zone:
    the contact occlusion where a wall or a foot meets the ground."""
    w, h = img.size
    a = img.getchannel("A").load()
    px = img.load()
    for x in range(w):
        bottom = next((y for y in range(h - 1, -1, -1) if a[x, y]), None)
        if bottom is None or bottom < h - BASE_ZONE:
            continue
        for y, k in ((bottom, 0.62), (bottom - 1, 0.8)):
            if y >= 0 and a[x, y]:
                r, g, b, al = px[x, y]
                px[x, y] = (int(r * k), int(g * k), int(b * k), al)
    return img


def drop_base_outline(img):
    """Outline pixels under the object in the base zone -> transparent, so the
    base meets the shadow instead of a hard dark line."""
    w, h = img.size
    px = img.load()
    for y in range(h - BASE_ZONE, h):
        for x in range(w):
            if px[x, y] == OUTLINE and y > 0 and px[x, y - 1][3] and px[x, y - 1] != OUTLINE:
                px[x, y] = (0, 0, 0, 0)
    return img


def with_shadow(img, scale):
    """Canvas with MARGIN px on the sides and PAD px below the base; under the
    sprite, its silhouette squashed onto the ground and leaned right."""
    w, h = img.size
    out = Image.new("RGBA", (w + 2 * MARGIN, h + PAD), (0, 0, 0, 0))
    if scale > 0:
        a = img.getchannel("A").load()
        base = h - 1
        k = min(SHADOW_LEN * scale, (PAD - 1) / float(h))
        depth = {}
        for y in range(h):
            for x in range(w):
                if not a[x, y]:
                    continue
                d = base - y
                sy = base + int(round(d * k))
                sx = x + MARGIN + int(round((sy - base) * SHADOW_LEAN))
                if 0 <= sx < w + 2 * MARGIN:
                    depth[(sx, sy)] = True
        px = out.load()
        for (x, y) in depth:
            alpha = SHADOW_ALPHA[0] if y - base <= 1 else SHADOW_ALPHA[1]
            px[x, y] = SHADOW + (alpha,)
    out.alpha_composite(img, (MARGIN, 0))
    return out


def sprite(src, cell, size, frac, warm=False):
    keyed = key(src, warm)
    if len(cell) == 4:
        part = keyed.crop(cell)
        obj = part.crop(part.getchannel("A").getbbox())
    else:
        r, c = cell
        obj = keyed.crop(frames(keyed, min_gap=20)[r][c])
    small = quantize(ground_contact(shrink(obj, size)), COLORS - 3)
    return with_shadow(drop_base_outline(outline(small)), frac)


def decals(src):
    """12 ground decals in one strip of DECAL x DECAL cells, <= COLORS colours."""
    keyed = key(src)
    grid = frames(keyed, min_gap=20)
    out = Image.new("RGBA", (DECAL * 12, DECAL), (0, 0, 0, 0))
    i = 0
    for row in grid[:3]:
        for c, box in enumerate(row[:4]):
            small = shrink(keyed.crop(box), ("w", DECAL_SIZES[c]))
            small = small.crop((0, 0, small.width, min(small.height, DECAL)))
            out.alpha_composite(small, (i * DECAL + (DECAL - small.width) // 2, DECAL - small.height))
            i += 1
    assert i == 12, "decal sheet has %d cells" % i
    out = quantize(out, COLORS - 1)
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a and r + g + b < 120:
                px[x, y] = DECAL_EDGE
    return out


def crystal_glow(n=48):
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = img.load()
    c = (n - 1) / 2.0
    for y in range(n):
        for x in range(n):
            d = math.hypot(x - c, y - c) / (n / 2.0)
            if d < 1.0:
                # Stepped falloff keeps it pixel-art (4 bands).
                a = [150, 100, 60, 28][min(3, int(d * 4))]
                px[x, y] = (110, 200, 255, a)
    return img


def ground(src):
    img = src.convert("RGB").resize((480, 270), Image.BOX)
    q = img.quantize(COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return q.convert("RGBA")


def main(argv):
    root, force = parse_args(argv)
    gen = os.path.join(root, "art-src", "gen")
    out_dir = os.path.join(root, "game", "assets", "town")
    os.makedirs(out_dir, exist_ok=True)
    cache = {}
    for name, (fname, cell, size, frac) in SPRITES.items():
        if fname not in cache:
            cache[fname] = Image.open(os.path.join(gen, fname))
        img = sprite(cache[fname], cell, size, frac, name == "lamp")
        n = count_colors(img)
        assert n <= COLORS, "%s has %d colours" % (name, n)
        save_guarded(img, os.path.join(out_dir, name + ".png"), force)
    save_guarded(crystal_glow(), os.path.join(out_dir, "crystal_glow.png"), force)
    d = decals(Image.open(os.path.join(gen, "town-base-decals.png")))
    assert count_colors(d) <= COLORS, "decals have %d colours" % count_colors(d)
    save_guarded(d, os.path.join(out_dir, "decals.png"), force)
    g = ground(Image.open(os.path.join(gen, "town-ground.png")))
    save_guarded(g, os.path.join(out_dir, "ground.png"), force)


if __name__ == "__main__":
    main(sys.argv)
