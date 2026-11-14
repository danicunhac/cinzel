"""Placeholder layered character sheets (4 cols x 13 rows of 24x24 frames).

Usage: python3 -I make_placeholders.py <out_dir> [<enemies_dir>]
Writes body.png, hair.png, outfit.png, weapon.png into <out_dir>.
With <enemies_dir>, also writes crawler.png, shooter.png, charger.png
(4 cols x 4 rows of 16x16 frames: idle, move, attack, death).
"""
import os
import sys

import math
import struct
import zlib

F = 24
COLS = 4
ROWS = [
    ("idle", "down", 2), ("idle", "up", 2), ("idle", "side", 2),
    ("walk", "down", 4), ("walk", "up", 4), ("walk", "side", 4),
    ("attack", "down", 3), ("attack", "up", 3), ("attack", "side", 3),
    ("roll", "down", 4), ("roll", "up", 4), ("roll", "side", 4),
    ("death", "down", 4),
]

SKIN = (236, 190, 150, 255)
HAIR = (90, 52, 30, 255)
OUTFIT = (60, 110, 190, 255)
OUTFIT_DARK = (40, 70, 130, 255)
STEEL = (210, 214, 224, 255)
HILT = (140, 100, 50, 255)
EYE = (30, 20, 20, 255)


class Cell:
    """24x24 RGBA cell with the few draw calls the placeholders need."""

    def __init__(self, size=F):
        self.p = {}
        self.size = size

    def set(self, x, y, c):
        if 0 <= x < self.size and 0 <= y < self.size:
            self.p[(x, y)] = c

    def rectangle(self, box, fill):
        x0, y0, x1, y1 = box
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, fill)

    def line(self, pts, fill, width=1):
        x0, y0, x1, y1 = pts
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for k in range(n + 1):
            x = round(x0 + (x1 - x0) * k / n)
            y = round(y0 + (y1 - y0) * k / n)
            for ox in range(width):
                for oy in range(width):
                    self.set(x + ox, y + oy, fill)

    def ellipse(self, box, fill):
        self.pieslice(box, 0, 360, fill)

    def pieslice(self, box, a0, a1, fill):
        x0, y0, x1, y1 = box
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        rx, ry = (x1 - x0) / 2, (y1 - y0) / 2
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 > 1:
                    continue
                ang = math.degrees(math.atan2(y - cy, x - cx)) % 360
                lo, hi = a0 % 360, a1 % 360
                inside = lo <= ang <= hi if lo <= hi else (ang >= lo or ang <= hi)
                if a1 - a0 >= 360 or inside:
                    self.set(x, y, fill)


def write_png(path, w, h, pixels):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            raw.extend(pixels.get((x, y), (0, 0, 0, 0)))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    open(path, "wb").write(png)


def offsets(anim, i):
    """Return (dx, dy, leg) for frame i."""
    if anim == "idle":
        return 0, i, 0
    if anim == "walk":
        return 0, (0, -1, 0, -1)[i], (-2, 0, 2, 0)[i]
    if anim == "attack":
        return (0, 1, 0)[i], 0, 0
    return 0, 0, 0


def px(d, x, y, w, h, c):
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)


def draw_body(d, anim, face, i):
    dx, dy, leg = offsets(anim, i)
    if anim == "roll":
        r = (7, 6, 7, 6)[i]
        d.ellipse([12 - r, 14 - r, 12 + r, 14 + r], fill=SKIN)
        px(d, 12 - 1 + (i % 2) * 3 - 1, 14 - 1, 2, 2, EYE)
        return
    if anim == "death":
        k = i
        if k < 3:
            px(d, 9, 5 + k * 3, 6, 6, SKIN)
            px(d, 10, 13 + k * 2, 4, 6 - k, SKIN)
        else:
            px(d, 3, 18, 6, 6, SKIN)
        return
    px(d, 9 + dx, 4 + dy, 6, 6, SKIN)  # head
    px(d, 10 + dx - leg // 2, 16 + dy, 2, 6, SKIN)  # legs
    px(d, 12 + dx + leg // 2, 16 + dy, 2, 6, SKIN)
    if face == "down":
        px(d, 10 + dx, 7 + dy, 1, 1, EYE)
        px(d, 13 + dx, 7 + dy, 1, 1, EYE)
    elif face == "side":
        px(d, 14 + dx, 7 + dy, 1, 1, EYE)


def draw_hair(d, anim, face, i):
    dx, dy, _ = offsets(anim, i)
    if anim == "roll":
        r = (7, 6, 7, 6)[i]
        d.pieslice([12 - r, 14 - r, 12 + r, 14 + r], 180 + i * 90, 300 + i * 90, fill=HAIR)
        return
    if anim == "death":
        if i < 3:
            px(d, 9, 5 + i * 3, 6, 2, HAIR)
        else:
            px(d, 3, 18, 6, 2, HAIR)
        return
    if face == "down":
        px(d, 9 + dx, 3 + dy, 6, 3, HAIR)
    elif face == "up":
        px(d, 9 + dx, 3 + dy, 6, 7, HAIR)
    else:
        px(d, 9 + dx, 3 + dy, 6, 3, HAIR)
        px(d, 9 + dx, 6 + dy, 2, 4, HAIR)


def draw_outfit(d, anim, face, i):
    dx, dy, leg = offsets(anim, i)
    if anim == "roll":
        r = (7, 6, 7, 6)[i]
        d.pieslice([12 - r, 14 - r, 12 + r, 14 + r], 20 + i * 90, 160 + i * 90, fill=OUTFIT)
        return
    if anim == "death":
        if i < 3:
            px(d, 8, 11 + i * 3, 8, 5, OUTFIT)
        else:
            px(d, 6, 19, 10, 5, OUTFIT)
        return
    px(d, 8 + dx, 10 + dy, 8, 7, OUTFIT)  # tunic
    px(d, 8 + dx, 15 + dy, 8, 2, OUTFIT_DARK)  # belt
    if face == "up":
        px(d, 10 + dx, 11 + dy, 4, 4, OUTFIT_DARK)  # back panel cue


def draw_weapon(d, anim, face, i):
    dx, dy, _ = offsets(anim, i)
    if anim in ("roll", "death"):
        return
    if anim == "attack":
        swing = i  # 0 wind-up, 1 swing, 2 follow-through
        if face == "side":
            tips = [(14, 4), (21, 10), (19, 18)]
            hx, hy = 14, 12
            tx, ty = tips[swing]
        elif face == "down":
            tips = [(18, 8), (19, 17), (12, 22)]
            hx, hy = 16, 12
            tx, ty = tips[swing]
        else:
            tips = [(18, 14), (19, 5), (12, 1)]
            hx, hy = 16, 12
            tx, ty = tips[swing]
        d.line([hx, hy, tx, ty], fill=STEEL, width=2)
        px(d, hx - 1, hy - 1, 3, 3, HILT)
        return
    # carried sword
    if face == "side":
        d.line([15 + dx, 14 + dy, 15 + dx, 6 + dy], fill=STEEL, width=1)
        px(d, 14 + dx, 14 + dy, 3, 2, HILT)
    elif face == "down":
        d.line([17 + dx, 14 + dy, 17 + dx, 21 + dy], fill=STEEL, width=1)
        px(d, 16 + dx, 13 + dy, 3, 2, HILT)
    else:
        d.line([7 + dx, 14 + dy, 7 + dx, 8 + dy], fill=STEEL, width=1)
        px(d, 6 + dx, 14 + dy, 3, 2, HILT)


LAYERS = {"body": draw_body, "hair": draw_hair, "outfit": draw_outfit, "weapon": draw_weapon}


E = 16
E_ROWS = ("idle", "move", "attack", "death")
RED = (230, 40, 40, 255)
RED_DARK = (140, 20, 30, 255)
BLACK = (20, 14, 20, 255)


def draw_crawler(d, anim, i):
    body = (96, 70, 120, 255)
    dark = (60, 40, 80, 255)
    if anim == "death":
        h = (5, 4, 2, 1)[i]
        d.ellipse([2, 14 - h, 13, 14], fill=body)
        if i < 3:
            px(d, 5, 13 - h, 1, 1, RED_DARK)
        return
    bob = i % 2 if anim == "idle" else 0
    lx = 1 if anim == "move" and i % 2 else -1 if anim == "move" else 0
    d.ellipse([2, 6 + bob, 13, 13], fill=body)
    d.ellipse([4, 6 + bob, 11, 9 + bob], fill=dark)
    for k, x in enumerate((3, 6, 9, 12)):
        off = lx if k % 2 else -lx
        px(d, x + off, 13, 1, 2, dark)
    px(d, 4, 8 + bob, 2, 2, RED)
    px(d, 9, 8 + bob, 2, 2, RED)
    if anim == "attack":
        jaw = (1, 3, 2, 3)[i]
        px(d, 4, 11 + bob, 8, jaw, RED_DARK)
        for x in (4, 6, 8, 10):
            px(d, x, 11 + bob, 1, 1, (240, 240, 230, 255))
        px(d, 4, 11 + bob + jaw, 8, 1, dark)


def draw_shooter(d, anim, i):
    robe = (50, 70, 120, 255)
    robe_dark = (30, 44, 80, 255)
    skin = (200, 200, 220, 255)
    if anim == "death":
        k = (0, 2, 5, 7)[i]
        px(d, 3, 9 + k // 2, 10, 5 - k // 3, robe)
        px(d, 3 + k // 2, 5 + k, 5, 4 - k // 3 if k < 7 else 1, skin)
        if i < 3:
            px(d, 6 + k // 2, 7 + k, 1, 1, RED_DARK)
        return
    bob = i % 2 if anim == "idle" else 0
    sway = (0, 1, 0, -1)[i] if anim == "move" else 0
    for y in range(7, 15):
        w = 3 + (y - 7)
        px(d, 8 - w // 2 + sway, y, w, 1, robe_dark if y > 12 else robe)
    d.ellipse([5 + sway, 2 + bob, 10 + sway, 7 + bob], fill=robe_dark)
    px(d, 6 + sway, 4 + bob, 3, 2, skin)
    px(d, 7 + sway, 4 + bob, 1, 1, RED)
    if anim == "attack":
        up = (0, 2, 3, 2)[i]
        px(d, 3, 8 - up, 1, 5, robe_dark)
        px(d, 12, 8 - up, 1, 5, robe_dark)
        d.ellipse([6, 0, 9, 3], fill=RED if i >= 1 else RED_DARK)
    else:
        px(d, 12 + sway, 5 + bob, 1, 9, (120, 90, 60, 255))
        px(d, 11 + sway, 4 + bob, 3, 2, RED_DARK)


def draw_charger(d, anim, i):
    hide = (120, 76, 50, 255)
    dark = (80, 48, 34, 255)
    horn = (236, 232, 214, 255)
    if anim == "death":
        h = (7, 5, 3, 2)[i]
        d.ellipse([1, 14 - h, 14, 14], fill=hide)
        if i < 3:
            px(d, 11, 13 - h, 1, 1, RED_DARK)
        px(d, 13, 12 - h // 2, 2, 1, horn)
        return
    bob = i % 2 if anim == "idle" else 0
    lx = 1 if anim == "move" and i % 2 else -1 if anim == "move" else 0
    low = 2 if anim == "attack" else 0
    d.ellipse([1, 4 + bob + low, 12, 12 + bob], fill=hide)
    px(d, 2, 5 + bob + low, 7, 2, dark)
    d.ellipse([9, 4 + bob + low * 2, 14, 10 + bob + low], fill=hide)
    px(d, 10, 7 + bob + low, 1, 1, RED)
    px(d, 12, 7 + bob + low, 1, 1, RED)
    px(d, 9, 2 + bob + low, 1, 3, horn)
    px(d, 13, 2 + bob + low, 1, 3, horn)
    for k, x in enumerate((3, 5, 9, 11)):
        off = lx if k % 2 else -lx
        px(d, x + off, 12 + bob, 2, 3 - bob, dark)
    if anim == "attack":
        px(d, 0, 6, 1, 1, RED)
        px(d, 0, 9, 2, 1, RED)
        if i % 2:
            px(d, 9, 1, 5, 1, RED)


ENEMIES = {"crawler": draw_crawler, "shooter": draw_shooter, "charger": draw_charger}


def write_enemies(out):
    os.makedirs(out, exist_ok=True)
    for name, fn in ENEMIES.items():
        pixels = {}
        for r, anim in enumerate(E_ROWS):
            for i in range(4):
                cell = Cell(E)
                fn(cell, anim, i)
                for (x, y), c in cell.p.items():
                    pixels[(i * E + x, r * E + y)] = c
        write_png(os.path.join(out, name + ".png"), E * 4, E * 4, pixels)


def main():
    if len(sys.argv) > 2:
        write_enemies(sys.argv[2])
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for name, fn in LAYERS.items():
        pixels = {}
        for r, (anim, face, n) in enumerate(ROWS):
            for i in range(n):
                cell = Cell()
                fn(cell, anim, face, i)
                for (x, y), c in cell.p.items():
                    pixels[(i * F + x, r * F + y)] = c
        write_png(os.path.join(out, name + ".png"), F * COLS, F * len(ROWS), pixels)


if __name__ == "__main__":
    main()
