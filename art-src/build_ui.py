"""Build item icons, town NPCs, UI frames and the title background.

python3 -I art-src/build_ui.py <repo_root>

Inputs (see docs/assets.md):
  art-src/gen/item-icons-sheet.png  8 item icons on magenta (4x2)
  art-src/gen/npcs-sheet.png        shopkeeper row, blacksmith rows, on magenta
  art-src/gen/ui-kit-sheet.png      panel frame, slot frame, heart, coin
  art-src/gen/title-bg.png          title screen background
Outputs:
  game/assets/items/<id>.png              16x16
  game/assets/characters/npc_shopkeeper.png, npc_blacksmith.png  48x24 (2 idle frames)
  game/assets/ui/panel.png (64x40, 9-slice margin 4), slot.png (20x20, margin 3),
    heart.png (9x8), coin.png (8x8), title_bg.png (320x180)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

from artlib import key_magenta, magenta_level  # noqa: E402

COLORS = 32

# Boxes in the source sheets (x0, y0, x1, y1), picked from frames() and by eye.
ITEMS = {
    "heavy_blade": (46, 63, 654, 694),
    "light_boots": (753, 139, 1335, 636),
    "stone_heart": (1452, 107, 1971, 625),
    "fang": (2214, 142, 2604, 625),
    "wind_cape": (57, 853, 631, 1439),
    "cracked_hourglass": (813, 854, 1227, 1450),
    "spark": (1525, 866, 1914, 1416),
    "glass_shield": (2110, 854, 2706, 1450),
}
NPCS = {
    "npc_shopkeeper": (102, 112, 482, 759),
    "npc_blacksmith": (563, 912, 963, 1507),
}
UI = {
    "panel": ((111, 125, 1940, 1256), (64, 40)),
    "slot": ((114, 1452, 588, 1950), (20, 20)),
    "heart": ((737, 1563, 1055, 1834), (9, 8)),
    "coin": ((1208, 1537, 1479, 1829), (8, 8)),
}


def quantize(img, n=COLORS):
    """Median cut on the opaque pixels, no dither, alpha kept binary."""
    alpha = img.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    rgb = img.convert("RGB")
    q = rgb.quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out = q.convert("RGBA")
    out.putalpha(alpha)
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if px[x, y][3] == 0:
                px[x, y] = (0, 0, 0, 0)
    return out


def key_strong(img):
    """Magenta key that also drops the pink haze around the UI kit's row 2."""
    img = key_magenta(img)
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a and magenta_level(r, g, b) > 35:
                px[x, y] = (0, 0, 0, 0)
    return img


def fit(src, w, h):
    """Trim to content, pad to the target aspect (bottom-centre), downscale."""
    box = src.getbbox()
    src = src.crop(box)
    sw, sh = src.size
    k = max(sw / w, sh / h)
    cw, ch = round(w * k), round(h * k)
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    canvas.alpha_composite(src, ((cw - sw) // 2, ch - sh))
    small = canvas.resize((w, h), Image.BOX)
    small.putalpha(small.getchannel("A").point(lambda v: 255 if v >= 110 else 0))
    return small


GOLD = [(70, 40, 20), (170, 105, 30), (235, 175, 50), (255, 235, 140)]


def gold_ramp(img):
    """The generated coin came out salmon; remap its luminance to a gold ramp,
    with the edge pixels as the dark outline."""
    out = img.copy()
    px = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if not a:
                continue
            edge = any(
                not (0 <= x + dx < w and 0 <= y + dy < h) or px[x + dx, y + dy][3] == 0
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            lum = (r * 3 + g * 6 + b) / 10
            i = 0 if edge else min(3, 1 + int(max(lum - 120, 0) / 45))
            px[x, y] = GOLD[i] + (255,)
    return out


def breathe(frame):
    """Idle frame 2: everything above the waist drops one pixel."""
    w, h = frame.size
    waist = h * 3 // 5
    out = frame.copy()
    top = frame.crop((0, 0, w, waist))
    out.paste(Image.new("RGBA", (w, waist), (0, 0, 0, 0)), (0, 0))
    out.alpha_composite(top, (0, 1))
    return out


def main():
    root = sys.argv[1]
    gen = os.path.join(root, "art-src", "gen")
    assets = os.path.join(root, "game", "assets")
    for d in ("items", "ui", "characters"):
        os.makedirs(os.path.join(assets, d), exist_ok=True)

    items = key_magenta(Image.open(os.path.join(gen, "item-icons-sheet.png")))
    # A stray mini climber sits between the boots and the heart.
    items.paste(Image.new("RGBA", (205, 200), (0, 0, 0, 0)), (1255, 580))
    for name, box in ITEMS.items():
        icon = fit(items.crop(box), 14, 14)
        cell = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        cell.alpha_composite(icon, (1, 1))
        quantize(cell).save(os.path.join(assets, "items", name + ".png"))

    npcs = key_magenta(Image.open(os.path.join(gen, "npcs-sheet.png")))
    for name, box in NPCS.items():
        body = fit(npcs.crop(box), 16, 23)
        frame = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
        frame.alpha_composite(body, (4, 1))
        sheet = Image.new("RGBA", (48, 24), (0, 0, 0, 0))
        sheet.alpha_composite(frame, (0, 0))
        sheet.alpha_composite(breathe(frame), (24, 0))
        quantize(sheet).save(os.path.join(assets, "characters", name + ".png"))

    kit = key_strong(Image.open(os.path.join(gen, "ui-kit-sheet.png")))
    for name, (box, size) in UI.items():
        part = kit.crop(box)
        part = part.crop(part.getbbox()).resize(size, Image.BOX)
        part.putalpha(part.getchannel("A").point(lambda v: 255 if v >= 110 else 0))
        if name == "coin":
            part = gold_ramp(part)
        quantize(part).save(os.path.join(assets, "ui", name + ".png"))

    bg = Image.open(os.path.join(gen, "title-bg.png")).convert("RGBA")
    w, h = bg.size
    ch = round(w * 180 / 320)
    bg = bg.crop((0, (h - ch) // 2, w, (h - ch) // 2 + ch)) if ch <= h else bg
    bg = bg.resize((320, 180), Image.BOX)
    quantize(bg).save(os.path.join(assets, "ui", "title_bg.png"))


if __name__ == "__main__":
    main()
