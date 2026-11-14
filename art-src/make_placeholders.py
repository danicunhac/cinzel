"""Placeholder layered character sheets (4 cols x 13 rows of 24x24 frames).

Usage: python3 -I make_placeholders.py <out_dir>
Writes body.png, hair.png, outfit.png, weapon.png into <out_dir>.
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

    def __init__(self):
        self.p = {}

    def set(self, x, y, c):
        if 0 <= x < F and 0 <= y < F:
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


def main():
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
