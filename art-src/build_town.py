"""Build the town sprites and the town ground from the generated sources.

python3 -I art-src/build_town.py <repo_root> [--force]
Existing output files are kept unless --force is passed.

Inputs (see docs/assets.md), all on flat magenta:
  art-src/gen/town-shop.png       hero shop
  art-src/gen/town-forge.png      forge
  art-src/gen/town-houses.png     house A (timber, ivy)
  art-src/gen/town-houses-b.png   house B (stone), house C (timber, bench)
  art-src/gen/town-crystal.png    crystal on dais
  art-src/gen/town-props.png      3 trees / lamp, well, planter, flower bed /
                                  fence, post, barrel, crates, sack
  art-src/gen/town-ground.png     ground painted over town-ground-guide.png
Outputs in game/assets/town/:
  ground.png 480x270 (opaque, 32 colours)
  one PNG per sprite (SPRITES below). Each sprite is keyed, downscaled to its
  width (or height), quantised to <= 32 colours, outlined with 1 px OUTLINE and
  given a baked soft shadow. The building base line (where the wall meets the
  ground) sits PAD px above the bottom of the image, so the scene puts the
  sprite origin at (w / 2, h - PAD).
  crystal_glow.png 48x48 soft blue glow (drawn here, additive in the scene).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

from artlib import OUTLINE, count_colors, frames, parse_args, save_guarded  # noqa: E402

COLORS = 32
PAD = 4
SHADOW = (20, 12, 24)

# name -> (source file, (row, col) in the frames() grid of the keyed source,
#          ("w" or "h", size in px), shadow width as a fraction of the sprite)
SPRITES = {
    "shop": ("town-shop.png", (0, 0), ("w", 104), 0.9),
    "forge": ("town-forge.png", (0, 0), ("w", 104), 0.9),
    "house_a": ("town-houses.png", (0, 0), ("h", 80), 0.9),
    "house_b": ("town-houses-b.png", (0, 0), ("w", 74), 0.9),
    "house_c": ("town-houses-b.png", (0, 1), ("w", 62), 0.9),
    "crystal": ("town-crystal.png", (0, 0), ("h", 60), 0.8),
    # The props sheet rows touch, so its cells are boxes (x0, y0, x1, y1)
    # around each object; the object is the opaque bbox inside the box.
    "tree_a": ("town-props.png", (190, 10, 400, 214), ("w", 54), 0.8),
    "tree_b": ("town-props.png", (460, 40, 620, 212), ("w", 40), 0.8),
    "tree_c": ("town-props.png", (690, 30, 860, 212), ("w", 46), 0.8),
    "lamp": ("town-props.png", (140, 214, 250, 410), ("h", 38), 0.6),
    "well": ("town-props.png", (325, 225, 485, 410), ("w", 34), 0.9),
    "planter": ("town-props.png", (550, 255, 720, 400), ("w", 30), 0.9),
    "flowerbed": ("town-props.png", (785, 265, 945, 400), ("w", 30), 0.9),
    "fence": ("town-props.png", (90, 440, 330, 570), ("w", 40), 0.0),
    "fence_post": ("town-props.png", (370, 440, 450, 570), ("h", 22), 0.0),
    "barrel": ("town-props.png", (510, 440, 610, 570), ("w", 14), 0.9),
    "crates": ("town-props.png", (670, 430, 790, 575), ("w", 18), 0.9),
    "sack": ("town-props.png", (860, 440, 960, 570), ("w", 14), 0.9),
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


def with_shadow(img, frac):
    """Canvas with PAD px below the base and a 2-step soft ellipse shadow."""
    w, h = img.size
    out = Image.new("RGBA", (w, h + PAD), (0, 0, 0, 0))
    if frac > 0:
        px = out.load()
        cx, cy = (w - 1) / 2.0, h - 1
        rx, ry = w * frac / 2.0, max(3.0, w * frac / 9.0)
        for y in range(h + PAD):
            for x in range(w):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if d <= 0.55:
                    px[x, y] = SHADOW + (110,)
                elif d <= 1.0:
                    px[x, y] = SHADOW + (60,)
    out.alpha_composite(img, (0, 0))
    return out


def sprite(src, cell, size, frac, warm=False):
    keyed = key(src, warm)
    if len(cell) == 4:
        part = keyed.crop(cell)
        obj = part.crop(part.getchannel("A").getbbox())
    else:
        r, c = cell
        obj = keyed.crop(frames(keyed, min_gap=20)[r][c])
    small = quantize(shrink(obj, size), COLORS - 3)
    return with_shadow(outline(small), frac)


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
    g = ground(Image.open(os.path.join(gen, "town-ground.png")))
    save_guarded(g, os.path.join(out_dir, "ground.png"), force)


if __name__ == "__main__":
    main(sys.argv)
