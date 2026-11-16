"""Build the extra layers of the title scene (drawn by script, no generation).

python3 -I art-src/build_title.py <repo_root> [--force]

Outputs in game/assets/ui/title/:
  parapet.png  foreground stone parapet silhouette, 496x32 (drawn at half
               size and doubled, like the hero standing on it)
  fog.png      tiling fog band, 512x32 (period 512, doubled pixels)
  glow.png     warm radial light in hard bands, 24x24 (additive in Godot)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

from artlib import parse_args, save_guarded, upscale  # noqa: E402

DARK = (18, 12, 24, 255)
BRICK = (34, 24, 40, 255)
RIM = (120, 70, 56, 255)
RIM_HOT = (196, 112, 60, 255)


def parapet():
    w, h = 248, 16
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    base_top = 6
    for x in range(w):
        merlon = (x % 22) < 12
        top = 1 if merlon else base_top
        for y in range(top, h):
            px[x, y] = DARK
        # Warm rim on the top edge (torch light from the tower side, right).
        px[x, top] = RIM_HOT if x > 150 and (x * 7) % 5 else RIM
    # Brick joints.
    for y in range(base_top + 3, h, 4):
        for x in range(w):
            px[x, y] = BRICK
    for row, y0 in enumerate(range(base_top + 3, h, 4)):
        for x in range((row % 2) * 5, w, 10):
            for y in range(y0, min(y0 + 4, h)):
                px[x, y] = BRICK
    for x in range(w):
        if (x % 22) < 12:
            for y in (4,):
                px[x, y] = BRICK
    return upscale(img, 2)


def fog():
    w, h = 256, 16
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for x in range(w):
        t = x / w * 2 * math.pi
        edge = 7 + 2.5 * math.sin(t * 3) + 1.5 * math.sin(t * 7 + 1.3) + math.sin(t * 13 + 0.4)
        for y in range(h):
            d = y - edge
            if d < 0:
                continue
            a = 46 if d < 2 else (70 if d < 5 else 90)
            # Fade out at the bottom so the band has no hard lower edge.
            if y >= h - 3:
                a = 40 if y == h - 3 else (24 if y == h - 2 else 12)
            px[x, y] = (150, 128, 186, a)
    return upscale(img, 2)


def glow():
    s = 24
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    px = img.load()
    c = (s - 1) / 2
    for y in range(s):
        for x in range(s):
            d = math.hypot(x - c, y - c) / c
            if d < 0.35:
                px[x, y] = (255, 196, 110, 150)
            elif d < 0.65:
                px[x, y] = (255, 150, 70, 80)
            elif d < 1.0:
                px[x, y] = (255, 120, 50, 32)
    return img


def main():
    root, force = parse_args(sys.argv)
    out = os.path.join(root, "game", "assets", "ui", "title")
    os.makedirs(out, exist_ok=True)
    save_guarded(parapet(), os.path.join(out, "parapet.png"), force)
    save_guarded(fog(), os.path.join(out, "fog.png"), force)
    save_guarded(glow(), os.path.join(out, "glow.png"), force)


if __name__ == "__main__":
    main()
